from decimal import Decimal
from datetime import datetime

from flask import Blueprint, request, jsonify
from config.db import get_db_connection

produit_bp = Blueprint("produit", __name__)


def clean_value(value):
    if isinstance(value, Decimal):
        return float(value)

    if isinstance(value, datetime):
        return value.strftime("%Y-%m-%d %H:%M:%S")

    return value


def clean_row(row):
    if row is None:
        return None

    item = {
        key: clean_value(value)
        for key, value in row.items()
    }

    base_url = request.host_url.rstrip("/")
    image_url = item.get("image_url")

    if image_url:
        image_url = str(image_url).strip()

        if image_url.startswith("http://") or image_url.startswith("https://"):
            item["image_url_resolved"] = image_url
        elif image_url.startswith("/"):
            item["image_url_resolved"] = f"{base_url}{image_url}"
        else:
            item["image_url_resolved"] = f"{base_url}/uploads/{image_url}"
    else:
        item["image_url_resolved"] = ""

    return item


def clean_rows(rows):
    return [clean_row(row) for row in rows]


@produit_bp.get("/")
def get_produits():
    search = request.args.get("search", "").strip()

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        params = []
        search_filter = ""

        if search:
            search_filter = """
                AND (
                    ap.nom LIKE %s
                    OR ap.description LIKE %s
                    OR pp.description_perso LIKE %s
                    OR c.nom LIKE %s
                    OR ph.nom LIKE %s
                )
            """

            like = f"%{search}%"
            params.extend([like, like, like, like, like])

        cursor.execute(
            f"""
            SELECT
                pp.pharmacie_produit_id,
                pp.pharmacie_id,
                pp.admin_produit_id,
                pp.description_perso,
                pp.prix,
                pp.est_disponible,

                ap.nom AS produit_nom,
                ap.description AS produit_description,
                ap.image_url,
                ap.type_produit,

                ph.nom AS pharmacie_nom,
                ph.adresse AS pharmacie_adresse,
                ph.telephone AS pharmacie_telephone,
                ph.latitude AS pharmacie_latitude,
                ph.longitude AS pharmacie_longitude,
                ph.est_ouverte,
                ph.est_de_garde,

                GROUP_CONCAT(DISTINCT c.nom ORDER BY c.nom SEPARATOR ', ') AS categories

            FROM pharmacie_produits pp
            JOIN admin_produits ap
                ON ap.admin_produit_id = pp.admin_produit_id
            JOIN pharmacies ph
                ON ph.pharmacie_id = pp.pharmacie_id
            LEFT JOIN produit_categories pc
                ON pc.admin_produit_id = ap.admin_produit_id
            LEFT JOIN categories c
                ON c.categorie_id = pc.categorie_id

            WHERE pp.est_disponible = 1
            AND ap.est_actif = 1
            AND ph.statut = 'approuvee'
            {search_filter}

            GROUP BY
                pp.pharmacie_produit_id,
                pp.pharmacie_id,
                pp.admin_produit_id,
                pp.description_perso,
                pp.prix,
                pp.est_disponible,
                ap.nom,
                ap.description,
                ap.image_url,
                ap.type_produit,
                ph.nom,
                ph.adresse,
                ph.telephone,
                ph.latitude,
                ph.longitude,
                ph.est_ouverte,
                ph.est_de_garde

            ORDER BY ap.nom ASC, pp.prix ASC
            """,
            tuple(params)
        )

        rows = cursor.fetchall()

        return jsonify({
            "success": True,
            "data": clean_rows(rows)
        })

    except Exception as e:
        print("GET PRODUITS ERROR:", e)
        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()


@produit_bp.get("/pharmacie/<int:pharmacie_id>")
def get_produits_by_pharmacie(pharmacie_id):
    search = request.args.get("search", "").strip()

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        params = [pharmacie_id]
        search_filter = ""

        if search:
            search_filter = """
                AND (
                    ap.nom LIKE %s
                    OR ap.description LIKE %s
                    OR pp.description_perso LIKE %s
                    OR c.nom LIKE %s
                )
            """

            like = f"%{search}%"
            params.extend([like, like, like, like])

        cursor.execute(
            f"""
            SELECT
                pp.pharmacie_produit_id,
                pp.pharmacie_id,
                pp.admin_produit_id,
                pp.description_perso,
                pp.prix,
                pp.est_disponible,

                ap.nom AS produit_nom,
                ap.description AS produit_description,
                ap.image_url,
                ap.type_produit,

                ph.nom AS pharmacie_nom,
                ph.adresse AS pharmacie_adresse,
                ph.telephone AS pharmacie_telephone,
                ph.latitude AS pharmacie_latitude,
                ph.longitude AS pharmacie_longitude,
                ph.est_ouverte,
                ph.est_de_garde,

                GROUP_CONCAT(DISTINCT c.nom ORDER BY c.nom SEPARATOR ', ') AS categories

            FROM pharmacie_produits pp
            JOIN admin_produits ap
                ON ap.admin_produit_id = pp.admin_produit_id
            JOIN pharmacies ph
                ON ph.pharmacie_id = pp.pharmacie_id
            LEFT JOIN produit_categories pc
                ON pc.admin_produit_id = ap.admin_produit_id
            LEFT JOIN categories c
                ON c.categorie_id = pc.categorie_id

            WHERE pp.pharmacie_id = %s
            AND pp.est_disponible = 1
            AND ap.est_actif = 1
            AND ph.statut = 'approuvee'
            {search_filter}

            GROUP BY
                pp.pharmacie_produit_id,
                pp.pharmacie_id,
                pp.admin_produit_id,
                pp.description_perso,
                pp.prix,
                pp.est_disponible,
                ap.nom,
                ap.description,
                ap.image_url,
                ap.type_produit,
                ph.nom,
                ph.adresse,
                ph.telephone,
                ph.latitude,
                ph.longitude,
                ph.est_ouverte,
                ph.est_de_garde

            ORDER BY ap.nom ASC
            """,
            tuple(params)
        )

        rows = cursor.fetchall()

        return jsonify({
            "success": True,
            "data": clean_rows(rows)
        })

    except Exception as e:
        print("GET PRODUITS BY PHARMACIE ERROR:", e)
        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()