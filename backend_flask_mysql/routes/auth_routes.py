from datetime import datetime, timedelta
from email.message import EmailMessage
import os
import random
import smtplib
import ssl
import jwt
from dotenv import load_dotenv
from flask import Blueprint, request, jsonify
from werkzeug.security import generate_password_hash, check_password_hash

from config.db import get_db_connection

auth_bp = Blueprint("auth", __name__)

load_dotenv()

JWT_SECRET = os.getenv("JWT_SECRET", "dwak_hna_secret_key_2026")
JWT_ALGORITHM = "HS256"

MAIL_USERNAME = os.getenv("MAIL_USERNAME", "")
MAIL_PASSWORD = os.getenv("MAIL_PASSWORD", "")
MAIL_FROM_NAME = os.getenv("MAIL_FROM_NAME", "Dwak Hna")

CODE_EXPIRES_MINUTES = 10
MAX_CODE_ATTEMPTS = 5


def create_patient_token(patient):
    payload = {
        "patient_id": patient["patient_id"],
        "email": patient["email"],
        "type": "patient",
        "exp": datetime.utcnow() + timedelta(days=30),
    }

    return jwt.encode(
        payload,
        JWT_SECRET,
        algorithm=JWT_ALGORITHM
    )


def generate_email_code():
    return str(random.SystemRandom().randint(100000, 999999))

def send_code_email(to_email, code, purpose):
    mail_username = os.getenv("MAIL_USERNAME", "").strip()
    mail_password = os.getenv("MAIL_PASSWORD", "").replace(" ", "").strip()
    mail_from_name = os.getenv("MAIL_FROM_NAME", "Dwak Hna").strip()

    if not mail_username or not mail_password:
        raise Exception("Configuration email manquante")

    subject_by_purpose = {
        "register": "Code de confirmation Dwak Hna",
        "forgot_password": "Code de réinitialisation du mot de passe",
        "change_password": "Code de modification du mot de passe",
    }

    title_by_purpose = {
        "register": "Confirmation de votre compte",
        "forgot_password": "Réinitialisation du mot de passe",
        "change_password": "Modification du mot de passe",
    }

    subject = subject_by_purpose.get(purpose, "Code Dwak Hna")
    title = title_by_purpose.get(purpose, "Code de confirmation")

    message = EmailMessage()
    message["Subject"] = subject
    message["From"] = f"{mail_from_name} <{mail_username}>"
    message["To"] = to_email

    message.set_content(
        f"""
Bonjour,

{title}

Votre code de confirmation est :

{code}

Ce code est valable pendant 10 minutes.

Si vous n'avez pas demandé ce code, ignorez cet email.

Dwak Hna
"""
    )

    try:
        context = ssl.create_default_context()

        with smtplib.SMTP("smtp.gmail.com", 587, timeout=15) as smtp:
            smtp.ehlo()
            smtp.starttls(context=context)
            smtp.ehlo()
            smtp.login(mail_username, mail_password)
            smtp.send_message(message)

        print("EMAIL CODE SENT TO:", to_email)

    except Exception as e:
        print("SEND EMAIL ERROR:", repr(e))
        raise Exception("Impossible d'envoyer le code par email")

def invalidate_old_codes(cursor, email, purpose):
    cursor.execute(
        """
        UPDATE email_verification_codes
        SET used_at = NOW()
        WHERE email = %s
        AND purpose = %s
        AND used_at IS NULL
        """,
        (email, purpose)
    )


def create_and_store_code(cursor, email, purpose, patient_id=None):
    code = generate_email_code()
    code_hash = generate_password_hash(code)

    invalidate_old_codes(cursor, email, purpose)

    cursor.execute(
        """
        INSERT INTO email_verification_codes
        (
            patient_id,
            email,
            purpose,
            code_hash,
            attempts,
            expires_at
        )
        VALUES
        (%s, %s, %s, %s, 0, DATE_ADD(NOW(), INTERVAL %s MINUTE))
        """,
        (
            patient_id,
            email,
            purpose,
            code_hash,
            CODE_EXPIRES_MINUTES,
        )
    )

    return code


def verify_email_code(cursor, email, purpose, code):
    cursor.execute(
        """
        SELECT
            code_id,
            code_hash,
            attempts
        FROM email_verification_codes
        WHERE email = %s
        AND purpose = %s
        AND used_at IS NULL
        AND expires_at > NOW()
        ORDER BY created_at DESC
        LIMIT 1
        """,
        (email, purpose)
    )

    code_row = cursor.fetchone()

    if not code_row:
        return False, "Code invalide ou expiré"

    if int(code_row.get("attempts") or 0) >= MAX_CODE_ATTEMPTS:
        cursor.execute(
            """
            UPDATE email_verification_codes
            SET used_at = NOW()
            WHERE code_id = %s
            """,
            (code_row["code_id"],)
        )
        return False, "Trop de tentatives. Demandez un nouveau code."

    if not check_password_hash(code_row["code_hash"], code):
        cursor.execute(
            """
            UPDATE email_verification_codes
            SET attempts = attempts + 1
            WHERE code_id = %s
            """,
            (code_row["code_id"],)
        )
        return False, "Code incorrect"

    cursor.execute(
        """
        UPDATE email_verification_codes
        SET used_at = NOW()
        WHERE code_id = %s
        """,
        (code_row["code_id"],)
    )

    return True, "Code vérifié"


def get_current_patient(cursor):
    auth_header = request.headers.get("Authorization", "")
    token = auth_header.replace("Bearer ", "").strip()

    if not token:
        return None, ("Token manquant", 401)

    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except jwt.ExpiredSignatureError:
        return None, ("Session expirée. Veuillez vous reconnecter.", 401)
    except Exception:
        return None, ("Token invalide", 401)

    patient_id = payload.get("patient_id") or payload.get("id")

    if not patient_id:
        return None, ("Token invalide", 401)

    cursor.execute(
        """
        SELECT
            patient_id,
            nom,
            prenom,
            email,
            mot_de_passe_hash,
            telephone,
            image,
            statut,
            email_verifie
        FROM patients
        WHERE patient_id = %s
        LIMIT 1
        """,
        (patient_id,)
    )

    patient = cursor.fetchone()

    if not patient:
        return None, ("Patient introuvable", 404)

    return patient, None


@auth_bp.post("/register/send-code")
def send_register_code():
    data = request.get_json() or {}

    email = (data.get("email") or "").strip().lower()

    if not email or "@" not in email:
        return jsonify({
            "success": False,
            "message": "Email invalide"
        }), 400

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute(
            """
            SELECT patient_id
            FROM patients
            WHERE email = %s
            LIMIT 1
            """,
            (email,)
        )

        existing = cursor.fetchone()

        if existing:
            return jsonify({
                "success": False,
                "message": "Cet email est déjà utilisé"
            }), 400

        code = create_and_store_code(
            cursor=cursor,
            email=email,
            purpose="register",
            patient_id=None,
        )

        send_code_email(email, code, "register")

        conn.commit()

        return jsonify({
            "success": True,
            "message": "Code envoyé par email"
        })

    except Exception as e:
        conn.rollback()
        print("SEND REGISTER CODE ERROR:", e)

        return jsonify({
            "success": False,
            "message": "Erreur envoi email"
        }), 500

    finally:
        cursor.close()
        conn.close()


@auth_bp.post("/register/verify")
def verify_register_code():
    data = request.get_json() or {}

    nom = (data.get("nom") or "").strip()
    prenom = (data.get("prenom") or "").strip()
    email = (data.get("email") or "").strip().lower()
    telephone = (data.get("telephone") or "").strip()
    mot_de_passe = data.get("mot_de_passe") or data.get("password") or ""
    code = (data.get("code") or "").strip()

    if not nom:
        return jsonify({
            "success": False,
            "message": "Nom obligatoire"
        }), 400

    if not prenom:
        return jsonify({
            "success": False,
            "message": "Prénom obligatoire"
        }), 400

    if not email or "@" not in email:
        return jsonify({
            "success": False,
            "message": "Email invalide"
        }), 400

    if len(mot_de_passe) < 6:
        return jsonify({
            "success": False,
            "message": "Le mot de passe doit contenir au moins 6 caractères"
        }), 400

    if len(code) != 6:
        return jsonify({
            "success": False,
            "message": "Code invalide"
        }), 400

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute(
            """
            SELECT patient_id
            FROM patients
            WHERE email = %s
            LIMIT 1
            """,
            (email,)
        )

        existing = cursor.fetchone()

        if existing:
            return jsonify({
                "success": False,
                "message": "Cet email est déjà utilisé"
            }), 400

        ok, message = verify_email_code(
            cursor=cursor,
            email=email,
            purpose="register",
            code=code,
        )

        if not ok:
            conn.commit()
            return jsonify({
                "success": False,
                "message": message
            }), 400

        password_hash = generate_password_hash(mot_de_passe)

        cursor.execute(
            """
            INSERT INTO patients
            (
                nom,
                prenom,
                email,
                mot_de_passe_hash,
                telephone,
                statut,
                email_verifie
            )
            VALUES
            (%s, %s, %s, %s, %s, 'actif', 1)
            """,
            (
                nom,
                prenom,
                email,
                password_hash,
                telephone if telephone else None,
            )
        )

        patient_id = cursor.lastrowid

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
                email_verifie
            FROM patients
            WHERE patient_id = %s
            """,
            (patient_id,)
        )

        patient = cursor.fetchone()

        token = create_patient_token(patient)

        conn.commit()

        return jsonify({
            "success": True,
            "message": "Compte créé avec succès",
            "token": token,
            "patient": patient
        }), 201

    except Exception as e:
        conn.rollback()
        print("VERIFY REGISTER CODE ERROR:", e)

        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()


@auth_bp.post("/register")
def register_patient():
    return jsonify({
        "success": False,
        "message": "Veuillez confirmer votre email avant de créer le compte"
    }), 400


@auth_bp.post("/login")
def login_patient():
    data = request.get_json() or {}

    email = (data.get("email") or "").strip().lower()
    mot_de_passe = data.get("mot_de_passe") or data.get("password") or ""

    if not email or not mot_de_passe:
        return jsonify({
            "success": False,
            "message": "Email et mot de passe obligatoires"
        }), 400

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
                mot_de_passe_hash,
                telephone,
                image,
                statut,
                email_verifie
            FROM patients
            WHERE email = %s
            LIMIT 1
            """,
            (email,)
        )

        patient = cursor.fetchone()

        if not patient:
            return jsonify({
                "success": False,
                "message": "Email ou mot de passe incorrect"
            }), 401

        if patient["statut"] != "actif":
            return jsonify({
                "success": False,
                "message": "Compte non actif"
            }), 403

        if int(patient.get("email_verifie") or 0) != 1:
            return jsonify({
                "success": False,
                "message": "Veuillez confirmer votre email avant de vous connecter"
            }), 403

        if not check_password_hash(patient["mot_de_passe_hash"], mot_de_passe):
            return jsonify({
                "success": False,
                "message": "Email ou mot de passe incorrect"
            }), 401

        token = create_patient_token(patient)

        patient.pop("mot_de_passe_hash", None)

        return jsonify({
            "success": True,
            "message": "Connexion réussie",
            "token": token,
            "patient": patient
        })

    except Exception as e:
        print("LOGIN PATIENT ERROR:", e)

        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()


@auth_bp.post("/forgot-password/send-code")
def send_forgot_password_code():
    data = request.get_json() or {}

    email = (data.get("email") or "").strip().lower()

    if not email or "@" not in email:
        return jsonify({
            "success": False,
            "message": "Email invalide"
        }), 400

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute(
            """
            SELECT patient_id, email, statut
            FROM patients
            WHERE email = %s
            LIMIT 1
            """,
            (email,)
        )

        patient = cursor.fetchone()

        if patient and patient["statut"] == "actif":
            code = create_and_store_code(
                cursor=cursor,
                email=email,
                purpose="forgot_password",
                patient_id=patient["patient_id"],
            )

            send_code_email(email, code, "forgot_password")

        conn.commit()

        return jsonify({
            "success": True,
            "message": "Si un compte existe avec cet email, un code a été envoyé"
        })

    except Exception as e:
        conn.rollback()
        print("SEND FORGOT PASSWORD CODE ERROR:", e)

        return jsonify({
            "success": False,
            "message": "Erreur envoi email"
        }), 500

    finally:
        cursor.close()
        conn.close()


@auth_bp.post("/forgot-password/reset")
def reset_forgot_password():
    data = request.get_json() or {}

    email = (data.get("email") or "").strip().lower()
    code = (data.get("code") or "").strip()
    nouveau_mot_de_passe = (
        data.get("nouveau_mot_de_passe")
        or data.get("new_password")
        or data.get("password")
        or ""
    )

    if not email or "@" not in email:
        return jsonify({
            "success": False,
            "message": "Email invalide"
        }), 400

    if len(code) != 6:
        return jsonify({
            "success": False,
            "message": "Code invalide"
        }), 400

    if len(nouveau_mot_de_passe) < 6:
        return jsonify({
            "success": False,
            "message": "Le mot de passe doit contenir au moins 6 caractères"
        }), 400

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute(
            """
            SELECT patient_id
            FROM patients
            WHERE email = %s
            AND statut = 'actif'
            LIMIT 1
            """,
            (email,)
        )

        patient = cursor.fetchone()

        if not patient:
            return jsonify({
                "success": False,
                "message": "Code invalide ou expiré"
            }), 400

        ok, message = verify_email_code(
            cursor=cursor,
            email=email,
            purpose="forgot_password",
            code=code,
        )

        if not ok:
            conn.commit()
            return jsonify({
                "success": False,
                "message": message
            }), 400

        password_hash = generate_password_hash(nouveau_mot_de_passe)

        cursor.execute(
            """
            UPDATE patients
            SET mot_de_passe_hash = %s
            WHERE patient_id = %s
            """,
            (password_hash, patient["patient_id"])
        )

        conn.commit()

        return jsonify({
            "success": True,
            "message": "Mot de passe modifié avec succès"
        })

    except Exception as e:
        conn.rollback()
        print("RESET FORGOT PASSWORD ERROR:", e)

        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()


@auth_bp.post("/change-password/send-code")
def send_change_password_code():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        patient, auth_error = get_current_patient(cursor)

        if auth_error:
            message, status = auth_error
            return jsonify({
                "success": False,
                "message": message
            }), status

        if patient["statut"] != "actif":
            return jsonify({
                "success": False,
                "message": "Compte non actif"
            }), 403

        email = patient["email"]

        code = create_and_store_code(
            cursor=cursor,
            email=email,
            purpose="change_password",
            patient_id=patient["patient_id"],
        )

        send_code_email(email, code, "change_password")

        conn.commit()

        return jsonify({
            "success": True,
            "message": "Code envoyé par email"
        })

    except Exception as e:
        conn.rollback()
        print("SEND CHANGE PASSWORD CODE ERROR:", e)

        return jsonify({
            "success": False,
            "message": "Erreur envoi email"
        }), 500

    finally:
        cursor.close()
        conn.close()


@auth_bp.post("/change-password")
def change_password():
    data = request.get_json() or {}

    code = (data.get("code") or "").strip()
    nouveau_mot_de_passe = (
        data.get("nouveau_mot_de_passe")
        or data.get("new_password")
        or data.get("password")
        or ""
    )

    if len(code) != 6:
        return jsonify({
            "success": False,
            "message": "Code invalide"
        }), 400

    if len(nouveau_mot_de_passe) < 6:
        return jsonify({
            "success": False,
            "message": "Le mot de passe doit contenir au moins 6 caractères"
        }), 400

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        patient, auth_error = get_current_patient(cursor)

        if auth_error:
            message, status = auth_error
            return jsonify({
                "success": False,
                "message": message
            }), status

        email = patient["email"]

        ok, message = verify_email_code(
            cursor=cursor,
            email=email,
            purpose="change_password",
            code=code,
        )

        if not ok:
            conn.commit()
            return jsonify({
                "success": False,
                "message": message
            }), 400

        password_hash = generate_password_hash(nouveau_mot_de_passe)

        cursor.execute(
            """
            UPDATE patients
            SET mot_de_passe_hash = %s
            WHERE patient_id = %s
            """,
            (password_hash, patient["patient_id"])
        )

        conn.commit()

        return jsonify({
            "success": True,
            "message": "Mot de passe modifié avec succès"
        })

    except Exception as e:
        conn.rollback()
        print("CHANGE PASSWORD ERROR:", e)

        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()
