from decimal import Decimal
from datetime import datetime

from flask import Blueprint, jsonify, request

from config.db import get_db_connection
from middleware.auth_middleware import auth_patient

try:
    from config.firebase_push import send_push_to_patient
except Exception as e:
    print("FIREBASE PUSH DISABLED:", e)

    def send_push_to_patient(patient_id, title, body, data=None):
        return False


notification_bp = Blueprint("notification", __name__)


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


def get_patient_unread_count(cursor, patient_id):
    cursor.execute(
        """
        SELECT COALESCE(SUM(total), 0) AS unread_count
        FROM (
            SELECT COUNT(*) AS total
            FROM notifications_admin na
            WHERE na.est_lue = 0
            AND (
                na.type = 'tous'
                OR (na.type = 'patient' AND na.patient_id = %s)
            )

            UNION ALL

            SELECT COUNT(*) AS total
            FROM notifications_systeme ns
            WHERE ns.est_lue = 0
            AND ns.patient_id = %s
            AND ns.type_notif IN (
                'demande_acceptee',
                'demande_refusee',
                'demande_annulee'
            )
        ) counts
        """,
        (
            patient_id,
            patient_id,
        )
    )

    row = cursor.fetchone()

    if not row:
        return 0

    return int(row.get("unread_count") or 0)


@notification_bp.get("/patient")
@auth_patient
def get_patient_notifications():
    patient_id = request.patient["patient_id"]

    try:
        limit = int(request.args.get("limit", 50))
        offset = int(request.args.get("offset", 0))
    except Exception:
        limit = 50
        offset = 0

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute(
            """
            SELECT *
            FROM (
                SELECT
                    'admin' AS source,
                    na.notif_admin_id AS notification_id,
                    na.titre,
                    na.corps,
                    na.type AS type_notif,
                    na.patient_id,
                    na.pharmacie_id,
                    NULL AS demande_id,
                    na.est_lue,
                    na.envoye_le
                FROM notifications_admin na
                WHERE na.type = 'tous'
                   OR (na.type = 'patient' AND na.patient_id = %s)

                UNION ALL

                SELECT
                    'systeme' AS source,
                    ns.notif_systeme_id AS notification_id,
                    ns.titre,
                    ns.corps,
                    ns.type_notif,
                    ns.patient_id,
                    ns.pharmacie_id,
                    ns.demande_id,
                    ns.est_lue,
                    ns.envoye_le
                FROM notifications_systeme ns
                WHERE ns.patient_id = %s
                AND ns.type_notif IN (
                    'demande_acceptee',
                    'demande_refusee',
                    'demande_annulee'
                )
            ) n
            ORDER BY n.envoye_le DESC
            LIMIT %s OFFSET %s
            """,
            (
                patient_id,
                patient_id,
                limit,
                offset,
            )
        )

        rows = cursor.fetchall()
        unread_count = get_patient_unread_count(cursor, patient_id)

        return jsonify({
            "success": True,
            "data": clean_rows(rows),
            "unread_count": unread_count,
        })

    except Exception as e:
        print("GET PATIENT NOTIFICATIONS ERROR:", e)
        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()


@notification_bp.get("/patient/unread")
@auth_patient
def get_patient_unread_notifications():
    patient_id = request.patient["patient_id"]

    try:
        limit = int(request.args.get("limit", 5))
    except Exception:
        limit = 5

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute(
            """
            SELECT *
            FROM (
                SELECT
                    'admin' AS source,
                    na.notif_admin_id AS notification_id,
                    na.titre,
                    na.corps,
                    na.type AS type_notif,
                    na.patient_id,
                    na.pharmacie_id,
                    NULL AS demande_id,
                    na.est_lue,
                    na.envoye_le
                FROM notifications_admin na
                WHERE na.est_lue = 0
                AND (
                    na.type = 'tous'
                    OR (na.type = 'patient' AND na.patient_id = %s)
                )

                UNION ALL

                SELECT
                    'systeme' AS source,
                    ns.notif_systeme_id AS notification_id,
                    ns.titre,
                    ns.corps,
                    ns.type_notif,
                    ns.patient_id,
                    ns.pharmacie_id,
                    ns.demande_id,
                    ns.est_lue,
                    ns.envoye_le
                FROM notifications_systeme ns
                WHERE ns.est_lue = 0
                AND ns.patient_id = %s
                AND ns.type_notif IN (
                    'demande_acceptee',
                    'demande_refusee',
                    'demande_annulee'
                )
            ) n
            ORDER BY n.envoye_le DESC
            LIMIT %s
            """,
            (
                patient_id,
                patient_id,
                limit,
            )
        )

        rows = cursor.fetchall()
        unread_count = get_patient_unread_count(cursor, patient_id)

        return jsonify({
            "success": True,
            "data": clean_rows(rows),
            "unread_count": unread_count,
        })

    except Exception as e:
        print("GET UNREAD NOTIFICATIONS ERROR:", e)
        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()


@notification_bp.get("/patient/count")
@auth_patient
def get_patient_notification_count():
    patient_id = request.patient["patient_id"]

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        unread_count = get_patient_unread_count(cursor, patient_id)

        return jsonify({
            "success": True,
            "unread_count": unread_count,
        })

    except Exception as e:
        print("GET NOTIF COUNT ERROR:", e)
        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()


@notification_bp.post("/admin/<int:notif_id>/lu")
@auth_patient
def mark_admin_notification_read(notif_id):
    patient_id = request.patient["patient_id"]

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute(
            """
            UPDATE notifications_admin
            SET est_lue = 1
            WHERE notif_admin_id = %s
            AND (
                type = 'tous'
                OR (type = 'patient' AND patient_id = %s)
            )
            """,
            (
                notif_id,
                patient_id,
            )
        )

        conn.commit()

        return jsonify({
            "success": True,
            "message": "Notification marquée comme lue"
        })

    except Exception as e:
        conn.rollback()
        print("MARK ADMIN NOTIF READ ERROR:", e)
        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()


@notification_bp.post("/systeme/<int:notif_id>/lu")
@auth_patient
def mark_system_notification_read(notif_id):
    patient_id = request.patient["patient_id"]

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute(
            """
            UPDATE notifications_systeme
            SET est_lue = 1
            WHERE notif_systeme_id = %s
            AND patient_id = %s
            """,
            (
                notif_id,
                patient_id,
            )
        )

        conn.commit()

        return jsonify({
            "success": True,
            "message": "Notification marquée comme lue"
        })

    except Exception as e:
        conn.rollback()
        print("MARK SYSTEM NOTIF READ ERROR:", e)
        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()


@notification_bp.post("/tout-lu")
@auth_patient
def mark_all_notifications_read():
    patient_id = request.patient["patient_id"]

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute(
            """
            UPDATE notifications_admin
            SET est_lue = 1
            WHERE type = 'tous'
               OR (type = 'patient' AND patient_id = %s)
            """,
            (patient_id,)
        )

        cursor.execute(
            """
            UPDATE notifications_systeme
            SET est_lue = 1
            WHERE patient_id = %s
            AND type_notif IN (
                'demande_acceptee',
                'demande_refusee',
                'demande_annulee'
            )
            """,
            (patient_id,)
        )

        conn.commit()

        return jsonify({
            "success": True,
            "message": "Toutes les notifications sont lues"
        })

    except Exception as e:
        conn.rollback()
        print("MARK ALL NOTIFS READ ERROR:", e)
        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()


@notification_bp.post("/firebase-token")
@auth_patient
def save_firebase_token():
    data = request.get_json() or {}
    token = data.get("token")

    if not token:
        return jsonify({
            "success": False,
            "message": "Token Firebase obligatoire"
        }), 400

    patient_id = request.patient["patient_id"]

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute(
            """
            UPDATE patients
            SET firebase_token = %s
            WHERE patient_id = %s
            """,
            (
                token,
                patient_id,
            )
        )

        conn.commit()

        return jsonify({
            "success": True,
            "message": "Token Firebase enregistré"
        })

    except Exception as e:
        conn.rollback()
        print("SAVE FIREBASE TOKEN ERROR:", e)

        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()


@notification_bp.post("/test-push")
@auth_patient
def test_push_notification():
    patient_id = request.patient["patient_id"]

    title = "Test notification Dwak Hna"
    body = "Ceci est une notification reçue hors application."

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute(
            """
            INSERT INTO notifications_admin
            (titre, corps, type, patient_id, pharmacie_id, est_lue)
            VALUES (%s, %s, 'patient', %s, NULL, 0)
            """,
            (
                title,
                body,
                patient_id,
            )
        )

        conn.commit()

        push_sent = send_push_to_patient(
            patient_id=patient_id,
            title=title,
            body=body,
            data={
                "source": "admin",
                "type_notif": "patient",
            },
        )

        return jsonify({
            "success": True,
            "message": "Notification test créée",
            "push_sent": push_sent,
        })

    except Exception as e:
        conn.rollback()
        print("TEST PUSH ERROR:", e)

        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()