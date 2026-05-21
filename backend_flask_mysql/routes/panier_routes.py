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

    return {
        key: clean_value(value)
        for key, value in row.items()
    }


def clean_rows(rows):
    return [clean_row(row) for row in rows]


def recalculate_total(cursor, panier_id):
    cursor.execute(
        """
        SELECT COALESCE(SUM(quantite * prix_unitaire), 0) AS total
        FROM panier_lignes
        WHERE panier_id = %s
        """,
        (panier_id,)
    )

    result = cursor.fetchone()
    total = result["total"] if result else 0

    cursor.execute(
        """
        UPDATE paniers
        SET total = %s
        WHERE panier_id = %s
        """,
        (total, panier_id)
    )

    return total


def fetch_panier_data(cursor, panier_id):
    cursor.execute(
        """
        SELECT 
            pn.panier_id,
            pn.patient_id,
            pn.pharmacie_id,
            pn.statut,
            pn.message_patient,
            pn.total,
            pn.cree_le,
            pn.modifie_le,
            pn.valide_le,
            p.nom AS pharmacie_nom,
            p.adresse AS pharmacie_adresse,
            p.telephone AS pharmacie_telephone
        FROM paniers pn
        JOIN pharmacies p
            ON p.pharmacie_id = pn.pharmacie_id
        WHERE pn.panier_id = %s
        """,
        (panier_id,)
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

            ap.nom AS produit_nom,
            ap.image_url,
            pp.description_perso
        FROM panier_lignes pl
        JOIN pharmacie_produits pp
            ON pp.pharmacie_produit_id = pl.pharmacie_produit_id
        JOIN admin_produits ap
            ON ap.admin_produit_id = pp.admin_produit_id
        WHERE pl.panier_id = %s
        ORDER BY pl.panier_ligne_id DESC
        """,
        (panier_id,)
    )

    lignes = cursor.fetchall()

    return {
        "panier": clean_row(panier),
        "lignes": clean_rows(lignes)
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
            (patient_id,)
        )

        panier = cursor.fetchone()

        if not panier:
            return jsonify({
                "success": True,
                "data": None
            })

        data = fetch_panier_data(cursor, panier["panier_id"])

        return jsonify({
            "success": True,
            "data": data
        })

    except Exception as e:
        print("GET PANIER ERROR:", e)
        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

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
        return jsonify({
            "success": False,
            "message": "Données invalides"
        }), 400

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
            """,
            (pharmacie_produit_id,)
        )

        produit = cursor.fetchone()

        if not produit:
            conn.rollback()
            return jsonify({
                "success": False,
                "message": "Produit introuvable"
            }), 404

        if produit["est_disponible"] != 1 or produit["est_actif"] != 1:
            conn.rollback()
            return jsonify({
                "success": False,
                "message": "Produit non disponible"
            }), 400

        if produit["pharmacie_statut"] != "approuvee":
            conn.rollback()
            return jsonify({
                "success": False,
                "message": "Pharmacie non disponible"
            }), 400

        cursor.execute(
            """
            SELECT panier_id, pharmacie_id
            FROM paniers
            WHERE patient_id = %s
            AND statut = 'brouillon'
            ORDER BY panier_id DESC
            LIMIT 1
            """,
            (patient_id,)
        )

        panier = cursor.fetchone()

        if not panier:
            cursor.execute(
                """
                INSERT INTO paniers
                (patient_id, pharmacie_id, statut, total)
                VALUES (%s, %s, 'brouillon', 0)
                """,
                (patient_id, produit["pharmacie_id"])
            )

            panier_id = cursor.lastrowid

        else:
            panier_id = panier["panier_id"]

            if panier["pharmacie_id"] != produit["pharmacie_id"]:
                conn.rollback()
                return jsonify({
                    "success": False,
                    "code": "PHARMACIE_DIFFERENTE",
                    "message": "Votre panier contient déjà des produits d’une autre pharmacie."
                }), 409

        cursor.execute(
            """
            SELECT panier_ligne_id, quantite
            FROM panier_lignes
            WHERE panier_id = %s
            AND pharmacie_produit_id = %s
            """,
            (panier_id, pharmacie_produit_id)
        )

        ligne = cursor.fetchone()

        if ligne:
            nouvelle_quantite = ligne["quantite"] + quantite

            cursor.execute(
                """
                UPDATE panier_lignes
                SET quantite = %s
                WHERE panier_ligne_id = %s
                """,
                (nouvelle_quantite, ligne["panier_ligne_id"])
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
                    produit["prix"],
                    produit["produit_nom"]
                )
            )

        recalculate_total(cursor, panier_id)

        conn.commit()

        response_data = fetch_panier_data(cursor, panier_id)

        return jsonify({
            "success": True,
            "message": "Produit ajouté au panier",
            "data": response_data
        })

    except Exception as e:
        conn.rollback()
        print("ADD PANIER ITEM ERROR:", e)
        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()


@panier_bp.post("/items/<int:ligne_id>/quantite")
@auth_patient
def update_ligne_quantite(ligne_id):
    patient_id = request.patient["patient_id"]
    data = request.get_json() or {}

    quantite = data.get("quantite")

    try:
        quantite = int(quantite)
    except Exception:
        return jsonify({
            "success": False,
            "message": "Quantité invalide"
        }), 400

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        conn.start_transaction()

        cursor.execute(
            """
            SELECT pl.panier_ligne_id, pl.panier_id
            FROM panier_lignes pl
            JOIN paniers pn
                ON pn.panier_id = pl.panier_id
            WHERE pl.panier_ligne_id = %s
            AND pn.patient_id = %s
            AND pn.statut = 'brouillon'
            """,
            (ligne_id, patient_id)
        )

        ligne = cursor.fetchone()

        if not ligne:
            conn.rollback()
            return jsonify({
                "success": False,
                "message": "Ligne introuvable"
            }), 404

        if quantite <= 0:
            cursor.execute(
                """
                DELETE FROM panier_lignes
                WHERE panier_ligne_id = %s
                """,
                (ligne_id,)
            )
        else:
            cursor.execute(
                """
                UPDATE panier_lignes
                SET quantite = %s
                WHERE panier_ligne_id = %s
                """,
                (quantite, ligne_id)
            )

        recalculate_total(cursor, ligne["panier_id"])

        conn.commit()

        response_data = fetch_panier_data(cursor, ligne["panier_id"])

        return jsonify({
            "success": True,
            "message": "Panier mis à jour",
            "data": response_data
        })

    except Exception as e:
        conn.rollback()
        print("UPDATE PANIER QUANTITE ERROR:", e)
        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

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
            JOIN paniers pn
                ON pn.panier_id = pl.panier_id
            WHERE pl.panier_ligne_id = %s
            AND pn.patient_id = %s
            AND pn.statut = 'brouillon'
            """,
            (ligne_id, patient_id)
        )

        ligne = cursor.fetchone()

        if not ligne:
            conn.rollback()
            return jsonify({
                "success": False,
                "message": "Ligne introuvable"
            }), 404

        panier_id = ligne["panier_id"]

        cursor.execute(
            """
            DELETE FROM panier_lignes
            WHERE panier_ligne_id = %s
            """,
            (ligne_id,)
        )

        recalculate_total(cursor, panier_id)

        conn.commit()

        response_data = fetch_panier_data(cursor, panier_id)

        return jsonify({
            "success": True,
            "message": "Produit supprimé",
            "data": response_data
        })

    except Exception as e:
        conn.rollback()
        print("DELETE PANIER ITEM ERROR:", e)
        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

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
            (patient_id,)
        )

        panier = cursor.fetchone()

        if not panier:
            conn.rollback()
            return jsonify({
                "success": False,
                "message": "Aucun panier à valider"
            }), 404

        panier_id = panier["panier_id"]

        cursor.execute(
            """
            SELECT COUNT(*) AS count_lignes
            FROM panier_lignes
            WHERE panier_id = %s
            """,
            (panier_id,)
        )

        count_result = cursor.fetchone()

        if count_result["count_lignes"] == 0:
            conn.rollback()
            return jsonify({
                "success": False,
                "message": "Votre panier est vide"
            }), 400

        recalculate_total(cursor, panier_id)

        cursor.execute(
            """
            UPDATE paniers
            SET statut = 'envoye',
                message_patient = %s,
                valide_le = NOW()
            WHERE panier_id = %s
            AND patient_id = %s
            AND statut = 'brouillon'
            """,
            (message_patient, panier_id, patient_id)
        )

        conn.commit()

        response_data = fetch_panier_data(cursor, panier_id)

        return jsonify({
            "success": True,
            "message": "Commande envoyée à la pharmacie",
            "data": response_data
        })

    except Exception as e:
        conn.rollback()
        print("VALIDER PANIER ERROR:", e)
        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()


@panier_bp.get("/historique")
@auth_patient
def historique_paniers():
    patient_id = request.patient["patient_id"]

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute(
            """
            SELECT 
                pn.panier_id,
                pn.patient_id,
                pn.pharmacie_id,
                pn.statut,
                pn.total,
                pn.message_patient,
                pn.cree_le,
                pn.valide_le,
                p.nom AS pharmacie_nom
            FROM paniers pn
            JOIN pharmacies p
                ON p.pharmacie_id = pn.pharmacie_id
            WHERE pn.patient_id = %s
            AND pn.statut <> 'brouillon'
            ORDER BY pn.panier_id DESC
            """,
            (patient_id,)
        )

        rows = cursor.fetchall()

        return jsonify({
            "success": True,
            "data": clean_rows(rows)
        })

    except Exception as e:
        print("HISTORIQUE PANIERS ERROR:", e)
        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()