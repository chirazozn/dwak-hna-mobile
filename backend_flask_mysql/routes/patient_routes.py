import os
import uuid
from decimal import Decimal
from datetime import datetime

from flask import Blueprint, jsonify, request
from werkzeug.utils import secure_filename

from config.db import get_db_connection
from middleware.auth_middleware import auth_patient

patient_bp = Blueprint("patient", __name__)

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UPLOAD_FOLDER = os.path.join(BASE_DIR, "uploads", "patients")

ALLOWED_EXTENSIONS = {"png", "jpg", "jpeg", "webp"}


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


def allowed_file(filename):
    if "." not in filename:
        return False

    extension = filename.rsplit(".", 1)[1].lower()
    return extension in ALLOWED_EXTENSIONS


def build_image_url(image_path):
    if not image_path:
        return ""

    image_path = str(image_path).strip()

    if image_path.startswith("http://") or image_path.startswith("https://"):
        return image_path

    base_url = request.host_url.rstrip("/")

    if image_path.startswith("/"):
        return f"{base_url}{image_path}"

    return f"{base_url}/{image_path}"


def save_patient_image(file, patient_id):
    if file is None or file.filename == "":
        return None

    if not allowed_file(file.filename):
        raise ValueError("Format image non autorisé")

    os.makedirs(UPLOAD_FOLDER, exist_ok=True)

    original_filename = secure_filename(file.filename)
    extension = original_filename.rsplit(".", 1)[1].lower()

    filename = f"patient_{patient_id}_{uuid.uuid4().hex}.{extension}"
    filepath = os.path.join(UPLOAD_FOLDER, filename)

    file.save(filepath)

    return f"/uploads/patients/{filename}"


@patient_bp.get("/profile")
@auth_patient
def get_patient_profile():
    patient_id = request.patient["patient_id"]

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute(
            """
            SELECT
                patient_id,
                nom,
                prenom,
                email,
                telephone,
                image,
                statut,
                email_verifie,
                cree_le,
                modifie_le
            FROM patients
            WHERE patient_id = %s
            """,
            (patient_id,)
        )

        patient = cursor.fetchone()

        if not patient:
            return jsonify({
                "success": False,
                "message": "Patient introuvable"
            }), 404

        patient = clean_row(patient)
        patient["image_url"] = build_image_url(patient.get("image"))

        return jsonify({
            "success": True,
            "data": patient
        })

    except Exception as e:
        print("GET PATIENT PROFILE ERROR:", e)
        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()


@patient_bp.put("/profile")
@auth_patient
def update_patient_profile():
    patient_id = request.patient["patient_id"]

    nom = request.form.get("nom")
    prenom = request.form.get("prenom")
    email = request.form.get("email")
    telephone = request.form.get("telephone")
    image_file = request.files.get("image")

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        conn.start_transaction()

        cursor.execute(
            """
            SELECT patient_id, email, image
            FROM patients
            WHERE patient_id = %s
            """,
            (patient_id,)
        )

        patient = cursor.fetchone()

        if not patient:
            conn.rollback()
            return jsonify({
                "success": False,
                "message": "Patient introuvable"
            }), 404

        if nom is not None:
            nom = nom.strip()

        if prenom is not None:
            prenom = prenom.strip()

        if telephone is not None:
            telephone = telephone.strip()

        if email is not None:
            email = email.strip().lower()

        if not nom:
            conn.rollback()
            return jsonify({
                "success": False,
                "message": "Nom obligatoire"
            }), 400

        if not prenom:
            conn.rollback()
            return jsonify({
                "success": False,
                "message": "Prénom obligatoire"
            }), 400

        if not email or "@" not in email:
            conn.rollback()
            return jsonify({
                "success": False,
                "message": "Email invalide"
            }), 400

        cursor.execute(
            """
            SELECT patient_id
            FROM patients
            WHERE email = %s
            AND patient_id <> %s
            LIMIT 1
            """,
            (email, patient_id)
        )

        existing = cursor.fetchone()

        if existing:
            conn.rollback()
            return jsonify({
                "success": False,
                "message": "Cet email est déjà utilisé"
            }), 400

        image_path = None

        if image_file:
            try:
                image_path = save_patient_image(image_file, patient_id)
            except ValueError as e:
                conn.rollback()
                return jsonify({
                    "success": False,
                    "message": str(e)
                }), 400

        fields = [
            "nom = %s",
            "prenom = %s",
            "email = %s",
            "telephone = %s",
        ]

        values = [
            nom,
            prenom,
            email,
            telephone if telephone else None,
        ]

        if email != patient["email"]:
            fields.append("email_verifie = 0")

        if image_path:
            fields.append("image = %s")
            values.append(image_path)

        values.append(patient_id)

        cursor.execute(
            f"""
            UPDATE patients
            SET {", ".join(fields)}
            WHERE patient_id = %s
            """,
            tuple(values)
        )

        conn.commit()

        cursor.execute(
            """
            SELECT
                patient_id,
                nom,
                prenom,
                email,
                telephone,
                image,
                statut,
                email_verifie,
                cree_le,
                modifie_le
            FROM patients
            WHERE patient_id = %s
            """,
            (patient_id,)
        )

        updated_patient = clean_row(cursor.fetchone())
        updated_patient["image_url"] = build_image_url(updated_patient.get("image"))

        return jsonify({
            "success": True,
            "message": "Profil modifié avec succès",
            "data": updated_patient
        })

    except Exception as e:
        conn.rollback()
        print("UPDATE PATIENT PROFILE ERROR:", e)

        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()