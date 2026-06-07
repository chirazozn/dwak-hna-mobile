from decimal import Decimal
from datetime import datetime
from flask import Blueprint, request, jsonify

from config.db import get_db_connection
from middleware.auth_middleware import auth_patient

panier_bp = Blueprint("panier", __name__)


def clean_value(value):
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, datetime):
        return value.strftime("%Y-%m-%d %H:%M:%S")
    return value


def clean_row(row):
    if row is None:
        return None
    return {key: clean_value(value) for key, value in row.items()}


def clean_rows(rows):
    return [clean_row(row) for row in rows]


def recalculate_total(cursor, panier_id):
    cursor.execute(
        """
        SELECT COALESCE(SUM(quantite * prix_unitaire), 0) AS total
        FROM panier_lignes
        WHERE panier_id = %s
        """,
        (panier_id,),
    )
    result = cursor.fetchone()
    total = result["total"] if result else 0

    cursor.execute(
        """
        UPDATE paniers
        SET total = %s
        WHERE panier_id = %s
        """,
        (total, panier_id),
    )
    return total


def get_or_create_brouillon_panier(cursor, patient_id):
    cursor.execute(
        """
        SELECT panier_id
        FROM paniers
        WHERE patient_id = %s
        AND statut = 'brouillon'
        ORDER BY panier_id DESC
        LIMIT 1
        """,
        (patient_id,),
    )
    panier = cursor.fetchone()

    if panier:
        return panier["panier_id"]

    cursor.execute(
        """
        INSERT INTO paniers (patient_id, statut, total)
        VALUES (%s, 'brouillon', 0)
        """,
        (patient_id,),
    )
    return cursor.lastrowid


def fetch_panier_data(cursor, panier_id):
    cursor.execute(
        """
        SELECT
            panier_id,
            patient_id,
            statut,
            total,
            message_patient,
            cree_le,
            modifie_le,
            valide_le
        FROM paniers
        WHERE panier_id = %s
        """,
        (panier_id,),
    )
    panier = cursor.fetchone()

    cursor.execute(
        """
        SELECT
            pl.panier_ligne_id,
            pl.panier_id,
            pl.pharmacie_produit_id,
            pl.quantite,
            pl.prix_unitaire,
            pl.nom_produit_snapshot,
            (pl.quantite * pl.prix_unitaire) AS total_ligne,

            pp.pharmacie_id,
            pp.admin_produit_id,
            pp.description_perso,
            pp.est_disponible,

            ap.nom AS produit_nom,
            ap.image_url,
            ap.type_produit,

            ph.nom AS pharmacie_nom,
            ph.adresse AS pharmacie_adresse,
            ph.telephone AS pharmacie_telephone
        FROM panier_lignes pl
        JOIN pharmacie_produits pp
            ON pp.pharmacie_produit_id = pl.pharmacie_produit_id
        JOIN admin_produits ap
            ON ap.admin_produit_id = pp.admin_produit_id
        JOIN pharmacies ph
            ON ph.pharmacie_id = pp.pharmacie_id
        WHERE pl.panier_id = %s
        ORDER BY ph.nom ASC, pl.panier_ligne_id DESC
        """,
        (panier_id,),
    )
    lignes = clean_rows(cursor.fetchall())

    grouped_map = {}
    for ligne in lignes:
        pharmacie_id = ligne.get("pharmacie_id")
        key = str(pharmacie_id)

        if key not in grouped_map:
            grouped_map[key] = {
                "pharmacie_id": pharmacie_id,
                "pharmacie_nom": ligne.get("pharmacie_nom") or "Pharmacie",
                "pharmacie_adresse": ligne.get("pharmacie_adresse") or "",
                "pharmacie_telephone": ligne.get("pharmacie_telephone") or "",
                "total": 0.0,
                "lignes": [],
            }

        total_ligne = ligne.get("total_ligne") or 0
        grouped_map[key]["total"] += float(total_ligne)
        grouped_map[key]["lignes"].append(ligne)

    groupes = list(grouped_map.values())

    return {
        "panier": clean_row(panier),
        "lignes": lignes,
        "groupes": groupes,
    }


@panier_bp.get("/")
@auth_patient
def get_panier_brouillon():
    patient_id = request.patient["patient_id"]

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute(
            """
            SELECT panier_id
            FROM paniers
            WHERE patient_id = %s
            AND statut = 'brouillon'
            ORDER BY panier_id DESC
            LIMIT 1
            """,
            (patient_id,),
        )
        panier = cursor.fetchone()

        if not panier:
            return jsonify({"success": True, "data": None})

        data = fetch_panier_data(cursor, panier["panier_id"])
        return jsonify({"success": True, "data": data})

    except Exception as e:
        print("GET PANIER ERROR:", e)
        return jsonify({"success": False, "message": "Erreur serveur"}), 500

    finally:
        cursor.close()
        conn.close()


@panier_bp.post("/items")
@auth_patient
def add_item_to_panier():
    patient_id = request.patient["patient_id"]
    data = request.get_json() or {}

    pharmacie_produit_id = data.get("pharmacie_produit_id")
    quantite = data.get("quantite", 1)

    try:
        pharmacie_produit_id = int(pharmacie_produit_id)
        quantite = int(quantite)
    except Exception:
        return jsonify({"success": False, "message": "Données invalides"}), 400

    if quantite < 1:
        quantite = 1

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        conn.start_transaction()

        cursor.execute(
            """
            SELECT
                pp.pharmacie_produit_id,
                pp.pharmacie_id,
                pp.admin_produit_id,
                pp.prix,
                pp.est_disponible,
                ap.nom AS produit_nom,
                ap.est_actif,
                p.statut AS pharmacie_statut
            FROM pharmacie_produits pp
            JOIN admin_produits ap
                ON ap.admin_produit_id = pp.admin_produit_id
            JOIN pharmacies p
                ON p.pharmacie_id = pp.pharmacie_id
            WHERE pp.pharmacie_produit_id = %s
            LIMIT 1
            """,
            (pharmacie_produit_id,),
        )
        produit = cursor.fetchone()

        if not produit:
            conn.rollback()
            return jsonify({"success": False, "message": "Produit introuvable"}), 404

        if produit["est_disponible"] != 1 or produit["est_actif"] != 1:
            conn.rollback()
            return jsonify({"success": False, "message": "Produit non disponible"}), 400

        if produit["pharmacie_statut"] != "approuvee":
            conn.rollback()
            return jsonify({"success": False, "message": "Pharmacie non disponible"}), 400

        panier_id = get_or_create_brouillon_panier(cursor, patient_id)

        cursor.execute(
            """
            SELECT panier_ligne_id, quantite
            FROM panier_lignes
            WHERE panier_id = %s
            AND pharmacie_produit_id = %s
            LIMIT 1
            """,
            (panier_id, pharmacie_produit_id),
        )
        ligne = cursor.fetchone()

        if ligne:
            nouvelle_quantite = int(ligne["quantite"] or 0) + quantite
            cursor.execute(
                """
                UPDATE panier_lignes
                SET quantite = %s
                WHERE panier_ligne_id = %s
                """,
                (nouvelle_quantite, ligne["panier_ligne_id"]),
            )
        else:
            cursor.execute(
                """
                INSERT INTO panier_lignes
                (panier_id, pharmacie_produit_id, quantite, prix_unitaire, nom_produit_snapshot)
                VALUES (%s, %s, %s, %s, %s)
                """,
                (
                    panier_id,
                    pharmacie_produit_id,
                    quantite,
                    produit["prix"] or 0,
                    produit["produit_nom"] or "Produit",
                ),
            )

        recalculate_total(cursor, panier_id)
        conn.commit()

        return jsonify({
            "success": True,
            "message": "Produit ajouté au panier",
            "data": fetch_panier_data(cursor, panier_id),
        })

    except Exception as e:
        conn.rollback()
        print("ADD PANIER ITEM ERROR:", e)
        return jsonify({"success": False, "message": "Erreur serveur"}), 500

    finally:
        cursor.close()
        conn.close()


@panier_bp.post("/items/<int:ligne_id>/quantite")
@auth_patient
def update_ligne_quantite(ligne_id):
    patient_id = request.patient["patient_id"]
    data = request.get_json() or {}

    try:
        quantite = int(data.get("quantite"))
    except Exception:
        return jsonify({"success": False, "message": "Quantité invalide"}), 400

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        conn.start_transaction()

        cursor.execute(
            """
            SELECT pl.panier_ligne_id, pl.panier_id
            FROM panier_lignes pl
            JOIN paniers pn ON pn.panier_id = pl.panier_id
            WHERE pl.panier_ligne_id = %s
            AND pn.patient_id = %s
            AND pn.statut = 'brouillon'
            LIMIT 1
            """,
            (ligne_id, patient_id),
        )
        ligne = cursor.fetchone()

        if not ligne:
            conn.rollback()
            return jsonify({"success": False, "message": "Ligne introuvable"}), 404

        panier_id = ligne["panier_id"]

        if quantite <= 0:
            cursor.execute("DELETE FROM panier_lignes WHERE panier_ligne_id = %s", (ligne_id,))
        else:
            cursor.execute(
                "UPDATE panier_lignes SET quantite = %s WHERE panier_ligne_id = %s",
                (quantite, ligne_id),
            )

        recalculate_total(cursor, panier_id)
        conn.commit()

        return jsonify({
            "success": True,
            "message": "Panier mis à jour",
            "data": fetch_panier_data(cursor, panier_id),
        })

    except Exception as e:
        conn.rollback()
        print("UPDATE PANIER QUANTITE ERROR:", e)
        return jsonify({"success": False, "message": "Erreur serveur"}), 500

    finally:
        cursor.close()
        conn.close()


@panier_bp.post("/items/<int:ligne_id>/supprimer")
@auth_patient
def delete_ligne(ligne_id):
    patient_id = request.patient["patient_id"]

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        conn.start_transaction()

        cursor.execute(
            """
            SELECT pl.panier_ligne_id, pl.panier_id
            FROM panier_lignes pl
            JOIN paniers pn ON pn.panier_id = pl.panier_id
            WHERE pl.panier_ligne_id = %s
            AND pn.patient_id = %s
            AND pn.statut = 'brouillon'
            LIMIT 1
            """,
            (ligne_id, patient_id),
        )
        ligne = cursor.fetchone()

        if not ligne:
            conn.rollback()
            return jsonify({"success": False, "message": "Ligne introuvable"}), 404

        panier_id = ligne["panier_id"]
        cursor.execute("DELETE FROM panier_lignes WHERE panier_ligne_id = %s", (ligne_id,))
        recalculate_total(cursor, panier_id)
        conn.commit()

        return jsonify({
            "success": True,
            "message": "Produit supprimé",
            "data": fetch_panier_data(cursor, panier_id),
        })

    except Exception as e:
        conn.rollback()
        print("DELETE PANIER ITEM ERROR:", e)
        return jsonify({"success": False, "message": "Erreur serveur"}), 500

    finally:
        cursor.close()
        conn.close()


@panier_bp.post("/valider")
@auth_patient
def valider_panier():
    patient_id = request.patient["patient_id"]
    data = request.get_json() or {}
    message_patient = data.get("message_patient")

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        conn.start_transaction()

        cursor.execute(
            """
            SELECT panier_id
            FROM paniers
            WHERE patient_id = %s
            AND statut = 'brouillon'
            ORDER BY panier_id DESC
            LIMIT 1
            """,
            (patient_id,),
        )
        panier = cursor.fetchone()

        if not panier:
            conn.rollback()
            return jsonify({"success": False, "message": "Aucun panier à valider"}), 404

        panier_id = panier["panier_id"]

        cursor.execute(
            """
            SELECT
                pl.panier_ligne_id,
                pl.pharmacie_produit_id,
                pl.quantite,
                pl.prix_unitaire,
                pl.nom_produit_snapshot,
                pp.pharmacie_id,
                pp.admin_produit_id,
                pp.est_disponible,
                ap.est_actif,
                p.statut AS pharmacie_statut
            FROM panier_lignes pl
            JOIN pharmacie_produits pp
                ON pp.pharmacie_produit_id = pl.pharmacie_produit_id
            JOIN admin_produits ap
                ON ap.admin_produit_id = pp.admin_produit_id
            JOIN pharmacies p
                ON p.pharmacie_id = pp.pharmacie_id
            WHERE pl.panier_id = %s
            ORDER BY pp.pharmacie_id ASC
            """,
            (panier_id,),
        )
        lignes = cursor.fetchall()

        if not lignes:
            conn.rollback()
            return jsonify({"success": False, "message": "Votre panier est vide"}), 400

        for ligne in lignes:
            if ligne["est_disponible"] != 1 or ligne["est_actif"] != 1 or ligne["pharmacie_statut"] != "approuvee":
                conn.rollback()
                return jsonify({
                    "success": False,
                    "message": f"Produit indisponible: {ligne['nom_produit_snapshot']}",
                }), 400

        groupes = {}
        for ligne in lignes:
            pharmacie_id = ligne["pharmacie_id"]
            groupes.setdefault(pharmacie_id, []).append(ligne)

        commandes_creees = []

        for pharmacie_id, groupe_lignes in groupes.items():
            total_commande = sum(
                float(ligne["prix_unitaire"] or 0) * int(ligne["quantite"] or 0)
                for ligne in groupe_lignes
            )

            cursor.execute(
                """
                INSERT INTO commandes
                (patient_id, pharmacie_id, statut, total, message_patient)
                VALUES (%s, %s, 'en_attente', %s, %s)
                """,
                (patient_id, pharmacie_id, total_commande, message_patient),
            )
            commande_id = cursor.lastrowid
            commandes_creees.append(commande_id)

            for ligne in groupe_lignes:
                quantite = int(ligne["quantite"] or 1)
                prix_unitaire = float(ligne["prix_unitaire"] or 0)
                sous_total = quantite * prix_unitaire

                cursor.execute(
                    """
                    INSERT INTO commande_lignes
                    (commande_id, pharmacie_produit_id, admin_produit_id, nom_produit, prix_unitaire, quantite, sous_total)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    """,
                    (
                        commande_id,
                        ligne["pharmacie_produit_id"],
                        ligne["admin_produit_id"],
                        ligne["nom_produit_snapshot"],
                        prix_unitaire,
                        quantite,
                        sous_total,
                    ),
                )

        recalculate_total(cursor, panier_id)

        cursor.execute(
            """
            UPDATE paniers
            SET statut = 'valide',
                message_patient = %s,
                valide_le = NOW()
            WHERE panier_id = %s
            AND patient_id = %s
            AND statut = 'brouillon'
            """,
            (message_patient, panier_id, patient_id),
        )

        conn.commit()

        return jsonify({
            "success": True,
            "message": "Commandes envoyées aux pharmacies",
            "data": {
                "panier_id": panier_id,
                "commandes_count": len(commandes_creees),
                "commande_ids": commandes_creees,
            },
        })

    except Exception as e:
        conn.rollback()
        print("VALIDER PANIER ERROR:", e)
        return jsonify({"success": False, "message": "Erreur serveur"}), 500

    finally:
        cursor.close()
        conn.close()


@panier_bp.get("/count")
@auth_patient
def panier_count():
    patient_id = request.patient["patient_id"]

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute(
            """
            SELECT
                COALESCE(SUM(pl.quantite), 0) AS count
            FROM paniers pn
            JOIN panier_lignes pl
                ON pl.panier_id = pn.panier_id
            WHERE pn.patient_id = %s
            AND pn.statut = 'brouillon'
            """,
            (patient_id,),
        )

        row = cursor.fetchone() or {"count": 0}

        return jsonify({
            "success": True,
            "count": int(row["count"] or 0)
        })

    except Exception as e:
        print("PANIER COUNT ERROR:", e)
        return jsonify({"success": False, "message": "Erreur serveur"}), 500

    finally:
        cursor.close()
        conn.close()


@panier_bp.get("/commandes/count")
@auth_patient
def commandes_count():
    patient_id = request.patient["patient_id"]

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute(
            """
            SELECT COUNT(*) AS count
            FROM commandes
            WHERE patient_id = %s
            AND statut IN ('en_attente', 'acceptee')
            """,
            (patient_id,),
        )

        row = cursor.fetchone() or {"count": 0}

        return jsonify({
            "success": True,
            "count": int(row["count"] or 0)
        })

    except Exception as e:
        print("COMMANDES COUNT ERROR:", e)
        return jsonify({"success": False, "message": "Erreur serveur"}), 500

    finally:
        cursor.close()
        conn.close()


@panier_bp.get("/historique")
@auth_patient
def historique_commandes():
    patient_id = request.patient["patient_id"]

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute(
            """
            SELECT
                c.commande_id,
                c.patient_id,
                c.pharmacie_id,
                c.statut,
                c.total,
                c.message_patient,
                c.cree_le,
                c.modifie_le,
                ph.nom AS pharmacie_nom,
                ph.adresse AS pharmacie_adresse,
                ph.telephone AS pharmacie_telephone
            FROM commandes c
            JOIN pharmacies ph
                ON ph.pharmacie_id = c.pharmacie_id
            WHERE c.patient_id = %s
            ORDER BY c.commande_id DESC
            """,
            (patient_id,),
        )
        rows = cursor.fetchall()

        return jsonify({"success": True, "data": clean_rows(rows)})

    except Exception as e:
        print("HISTORIQUE COMMANDES ERROR:", e)
        return jsonify({"success": False, "message": "Erreur serveur"}), 500

    finally:
        cursor.close()
        conn.close()
