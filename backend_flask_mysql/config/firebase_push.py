import os

import firebase_admin
from firebase_admin import credentials, messaging

from config.db import get_db_connection


def init_firebase_admin():
    if firebase_admin._apps:
        return

    current_dir = os.path.dirname(os.path.abspath(__file__))
    service_account_path = os.path.join(
        current_dir,
        "firebase-service-account.json"
    )

    cred = credentials.Certificate(service_account_path)
    firebase_admin.initialize_app(cred)


def send_push_to_patient(patient_id, title, body, data=None):
    init_firebase_admin()

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute(
            """
            SELECT firebase_token
            FROM patients
            WHERE patient_id = %s
            """,
            (patient_id,)
        )

        patient = cursor.fetchone()

        if not patient or not patient.get("firebase_token"):
            print("FCM: aucun token pour patient", patient_id)
            return False

        token = patient["firebase_token"]

        message = messaging.Message(
            token=token,
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data={
                "click_action": "FLUTTER_NOTIFICATION_CLICK",
                **(data or {}),
            },
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="dwak_hna_notifications",
                    sound="default",
                ),
            ),
        )

        response = messaging.send(message)

        print("FCM SENT:", response)

        return True

    except Exception as e:
        print("FCM SEND ERROR:", e)
        return False

    finally:
        cursor.close()
        conn.close()