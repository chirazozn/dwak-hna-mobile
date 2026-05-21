import os
import jwt
from functools import wraps
from flask import request, jsonify
from dotenv import load_dotenv

load_dotenv()


def auth_patient(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get("Authorization")

        if not auth_header or not auth_header.startswith("Bearer "):
            return jsonify({
                "success": False,
                "message": "Token manquant"
            }), 401

        token = auth_header.split(" ")[1]

        try:
            decoded = jwt.decode(
                token,
                os.getenv("JWT_SECRET"),
                algorithms=["HS256"]
            )
            request.patient = decoded
        except Exception:
            return jsonify({
                "success": False,
                "message": "Token invalide"
            }), 401

        return f(*args, **kwargs)

    return decorated