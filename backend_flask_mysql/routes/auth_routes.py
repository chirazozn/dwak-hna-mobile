from datetime import datetime, timedelta

import jwt
from flask import Blueprint, request, jsonify
from werkzeug.security import generate_password_hash, check_password_hash

from config.db import get_db_connection

auth_bp = Blueprint("auth", __name__)

import os
from dotenv import load_dotenv

load_dotenv()

JWT_SECRET = os.getenv("JWT_SECRET", "dwak_hna_secret_key_2026")
JWT_ALGORITHM = "HS256"


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


@auth_bp.post("/register")
def register_patient():
    data = request.get_json() or {}

    nom = (data.get("nom") or "").strip()
    prenom = (data.get("prenom") or "").strip()
    email = (data.get("email") or "").strip().lower()
    telephone = (data.get("telephone") or "").strip()
    mot_de_passe = data.get("mot_de_passe") or data.get("password") or ""

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

        conn.commit()

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

        return jsonify({
            "success": True,
            "message": "Compte créé avec succès",
            "token": token,
            "patient": patient
        }), 201

    except Exception as e:
        conn.rollback()
        print("REGISTER PATIENT ERROR:", e)

        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()


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