from flask import Blueprint, jsonify
from config.db import get_db_connection

publicite_bp = Blueprint("publicite", __name__)


@publicite_bp.get("/accueil")
def publicites_accueil():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute(
            """
            SELECT publicite_id, titre, image_url, lien_cible, position
            FROM publicites
            WHERE est_active = 1
            AND emplacement_patient_accueil = 1
            AND CURRENT_DATE BETWEEN date_debut AND date_fin
            ORDER BY position ASC
            """
        )
        rows = cursor.fetchall()

        return jsonify({
            "success": True,
            "data": rows
        })

    except Exception as e:
        print("ADS HOME ERROR:", e)
        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()