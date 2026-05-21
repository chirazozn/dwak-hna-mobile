from flask import Blueprint, request, jsonify
from config.db import get_db_connection

medicament_bp = Blueprint("medicament", __name__)


@medicament_bp.get("/")
def get_medicaments():
    search = request.args.get("search", "").strip()

    # Important :
    # Si l'utilisateur n'a pas tapé au moins 2 caractères,
    # on ne renvoie rien pour éviter de charger 1000 médicaments.
    if len(search) < 2:
        return jsonify({
            "success": True,
            "data": []
        })

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute(
            """
            SELECT
                medicament_id,
                nom,
                denomination_commune,
                forme,
                dosage,
                fabricant,
                necessite_ordonnance,
                description,
                image_url
            FROM medicaments
            WHERE est_actif = 1
            AND (
                nom LIKE %s
                OR denomination_commune LIKE %s
                OR fabricant LIKE %s
            )
            ORDER BY nom ASC
            LIMIT 20
            """,
            (
                f"%{search}%",
                f"%{search}%",
                f"%{search}%"
            )
        )

        rows = cursor.fetchall()

        return jsonify({
            "success": True,
            "data": rows
        })

    except Exception as e:
        print("GET MEDICAMENTS ERROR:", e)
        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()