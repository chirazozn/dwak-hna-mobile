import os
import json

import firebase_admin
from firebase_admin import credentials, messaging

from config.db import get_db_connection


def init_firebase_admin():
    if firebase_admin._apps:
        return

    firebase_json = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")

    if firebase_json:
        cred_dict = json.loads(firebase_json)
        cred = credentials.Certificate(cred_dict)
    else:
        service_account_path = os.getenv(
            "FIREBASE_SERVICE_ACCOUNT_PATH",
            os.path.join(
                os.path.dirname(os.path.abspath(__file__)),
                "firebase-service-account.json"
            )
        )
        cred = credentials.Certificate(service_account_path)

    firebase_admin.initialize_app(cred)


def get_patient_token(patient_id):
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
            return None

        return patient["firebase_token"]

    finally:
        cursor.close()
        conn.close()


def send_push_to_patient(patient_id, title, body, data=None):
    try:
        token = get_patient_token(patient_id)

        if not token:
            return False

        init_firebase_admin()

        safe_data = {
            str(key): str(value)
            for key, value in (data or {}).items()
            if value is not None
        }

        safe_data["click_action"] = "FLUTTER_NOTIFICATION_CLICK"

        message = messaging.Message(
            token=token,
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=safe_data,
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