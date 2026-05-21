import os

from flask import Flask, jsonify, send_from_directory
from flask_cors import CORS


def create_app():
    app = Flask(__name__)

    CORS(app)

    app.config["JSON_AS_ASCII"] = False

    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
    UPLOADS_DIR = os.path.join(BASE_DIR, "uploads")

    os.makedirs(UPLOADS_DIR, exist_ok=True)
    os.makedirs(os.path.join(UPLOADS_DIR, "patients"), exist_ok=True)

    @app.get("/")
    def index():
        return jsonify({
            "success": True,
            "message": "API Dwak Hna fonctionne"
        })

    @app.get("/api/health")
    def health():
        return jsonify({
            "success": True,
            "message": "Backend OK"
        })

    @app.route("/uploads/<path:filename>")
    def uploaded_files(filename):
        return send_from_directory(UPLOADS_DIR, filename)

    # Authentification : login + inscription
    try:
        from routes.auth_routes import auth_bp
        app.register_blueprint(auth_bp, url_prefix="/api/auth")
        print("AUTH ROUTES OK")
    except Exception as e:
        print("AUTH ROUTES WARNING:", e)

    # Patients : profil + image
    try:
        from routes.patient_routes import patient_bp
        app.register_blueprint(patient_bp, url_prefix="/api/patients")
        print("PATIENT ROUTES OK")
    except Exception as e:
        print("PATIENT ROUTES WARNING:", e)

    # Demandes
    try:
        from routes.demande_routes import demande_bp
        app.register_blueprint(demande_bp, url_prefix="/api/demandes")
        print("DEMANDE ROUTES OK")
    except Exception as e:
        print("DEMANDE ROUTES WARNING:", e)

    # Pharmacies
    try:
        from routes.pharmacie_routes import pharmacie_bp
        app.register_blueprint(pharmacie_bp, url_prefix="/api/pharmacies")
        print("PHARMACIE ROUTES OK")
    except Exception as e:
        print("PHARMACIE ROUTES WARNING:", e)

    # Produits
    try:
        from routes.produit_routes import produit_bp
        app.register_blueprint(produit_bp, url_prefix="/api/produits")
        print("PRODUIT ROUTES OK")
    except Exception as e:
        print("PRODUIT ROUTES WARNING:", e)

    # Publicités
    try:
        from routes.publicite_routes import publicite_bp
        app.register_blueprint(publicite_bp, url_prefix="/api/publicites")
        print("PUBLICITE ROUTES OK")
    except Exception as e:
        print("PUBLICITE ROUTES WARNING:", e)

    # Messages prédéfinis
    try:
        from routes.message_predefini_routes import message_predefini_bp
        app.register_blueprint(
            message_predefini_bp,
            url_prefix="/api/messages-predefinis"
        )
        print("MESSAGE PREDEFINI ROUTES OK")
    except Exception as e:
        print("MESSAGE PREDEFINI ROUTES WARNING:", e)

    # Notifications
    try:
        from routes.notification_routes import notification_bp
        app.register_blueprint(notification_bp, url_prefix="/api/notifications")
        print("NOTIFICATION ROUTES OK")
    except Exception as e:
        print("NOTIFICATION ROUTES WARNING:", e)

    # Admin produits
    try:
        from routes.admin_produit_routes import admin_produit_bp
        app.register_blueprint(admin_produit_bp, url_prefix="/api/admin-produits")
        print("ADMIN PRODUIT ROUTES OK")
    except Exception as e:
        print("ADMIN PRODUIT ROUTES WARNING:", e)

    # Produits des pharmacies
    try:
        from routes.pharmacie_produit_routes import pharmacie_produit_bp
        app.register_blueprint(
            pharmacie_produit_bp,
            url_prefix="/api/pharmacie-produits"
        )
        print("PHARMACIE PRODUIT ROUTES OK")
    except Exception as e:
        print("PHARMACIE PRODUIT ROUTES WARNING:", e)

    # Médicaments
    try:
        from routes.medicament_routes import medicament_bp
        app.register_blueprint(medicament_bp, url_prefix="/api/medicaments")
        print("MEDICAMENT ROUTES OK")
    except Exception as e:
        print("MEDICAMENT ROUTES WARNING:", e)

    # Panier
    try:
        from routes.panier_routes import panier_bp
        app.register_blueprint(panier_bp, url_prefix="/api/panier")
        print("PANIER ROUTES OK")
    except Exception as e:
        print("PANIER ROUTES WARNING:", e)

    return app


app = create_app()


if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=5001,
        debug=True
    )