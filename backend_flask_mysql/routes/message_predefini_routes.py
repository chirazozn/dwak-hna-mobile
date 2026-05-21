from flask import Blueprint, request, jsonify
from config.db import get_db_connection

message_predefini_bp = Blueprint("message_predefini", __name__)


@message_predefini_bp.get("/")
def get_messages_predefinis():
    type_message = request.args.get("type", "patient_demande")

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute(
            """
            SELECT 
                message_id,
                contenu,
                type
            FROM messages_predefinis
            WHERE est_actif = 1
            AND `type` = %s
            ORDER BY message_id ASC
            """,
            (type_message,)
        )

        rows = cursor.fetchall()

        return jsonify({
            "success": True,
            "data": rows
        })

    except Exception as e:
        print("GET MESSAGES PREDEFINIS ERROR:", e)
        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()