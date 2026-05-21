from flask import Blueprint, request, jsonify
from config.db import get_db_connection

pharmacie_bp = Blueprint("pharmacie", __name__)


@pharmacie_bp.get("/nearby")
def nearby_pharmacies():
    latitude = request.args.get("latitude", type=float)
    longitude = request.args.get("longitude", type=float)
    rayon_km = request.args.get("rayon_km", default=5, type=float)
    ouverte = request.args.get("ouverte")
    de_garde = request.args.get("de_garde")

    if latitude is None or longitude is None:
        return jsonify({
            "success": False,
            "message": "Latitude et longitude obligatoires"
        }), 400

    filters = """
        p.statut = 'approuvee'
        AND p.latitude IS NOT NULL
        AND p.longitude IS NOT NULL
    """

    params = [latitude, longitude, latitude]

    if ouverte == "1":
        filters += " AND p.est_ouverte = 1"

    if de_garde == "1":
        filters += " AND p.est_de_garde = 1"

    sql = f"""
        SELECT
            p.pharmacie_id,
            p.nom,
            p.email,
            p.telephone,
            p.adresse,
            p.latitude,
            p.longitude,
            p.logo_url,
            p.est_ouverte,
            p.est_de_garde,
            w.nom AS wilaya,
            c.nom AS commune,
            (
                6371 * ACOS(
                    COS(RADIANS(%s)) *
                    COS(RADIANS(p.latitude)) *
                    COS(RADIANS(p.longitude) - RADIANS(%s)) +
                    SIN(RADIANS(%s)) *
                    SIN(RADIANS(p.latitude))
                )
            ) AS distance_km
        FROM pharmacies p
        JOIN wilayas w ON w.wilaya_id = p.wilaya_id
        JOIN communes c ON c.commune_id = p.commune_id
        WHERE {filters}
        HAVING distance_km <= %s
        ORDER BY distance_km ASC
    """

    params.append(rayon_km)

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute(sql, tuple(params))
        rows = cursor.fetchall()

        return jsonify({
            "success": True,
            "data": rows
        })

    except Exception as e:
        print("NEARBY PHARMACIES ERROR:", e)
        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()