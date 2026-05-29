import os
import json
import uuid
from decimal import Decimal
from datetime import datetime

from flask import Blueprint, request, jsonify, current_app
from werkzeug.utils import secure_filename

from config.db import get_db_connection
from middleware.auth_middleware import auth_patient

demande_bp = Blueprint("demande", __name__)


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


def allowed_file(filename):
    if not filename:
        return False

    allowed_extensions = {"png", "jpg", "jpeg", "webp", "pdf"}

    return "." in filename and filename.rsplit(".", 1)[1].lower() in allowed_extensions


def make_upload_url(relative_path):
    """
    Transforme:
      ordonnances/xxx.jpg
    en:
      https://dwak-hna-mobile.onrender.com/uploads/ordonnances/xxx.jpg

    Render doit avoir:
      APP_URL=https://dwak-hna-mobile.onrender.com
    """
    base_url = os.getenv("APP_URL", request.host_url.rstrip("/")).rstrip("/")
    relative_path = str(relative_path).lstrip("/")
    return f"{base_url}/uploads/{relative_path}"


def get_ordonnance_file():
    """
    Accepte plusieurs noms possibles envoyés par Flutter.
    Caméra ou galerie = même logique côté backend: fichier multipart.
    """
    possible_keys = [
        "ordonnances",
        "ordonnance_image",
        "image",
        "file",
        "photo",
    ]

    for key in possible_keys:
        file = request.files.get(key)

        if file and file.filename:
            return file

    return None


def save_ordonnance_file(file):
    """
    Sauvegarde l'image/PDF dans uploads/ordonnances
    et retourne une URL complète HTTPS.
    """
    if file is None:
        return None

    if not allowed_file(file.filename):
        raise ValueError("Format fichier non autorisé")

    upload_root = current_app.config.get("UPLOAD_FOLDER", "uploads")

    if not os.path.isabs(upload_root):
        upload_root = os.path.join(current_app.root_path, upload_root)

    ordonnance_folder = os.path.join(upload_root, "ordonnances")
    os.makedirs(ordonnance_folder, exist_ok=True)

    original_name = secure_filename(file.filename)
    filename = f"{uuid.uuid4().hex}_{original_name}"

    save_path = os.path.join(ordonnance_folder, filename)
    file.save(save_path)

    relative_path = f"ordonnances/{filename}"
    public_url = make_upload_url(relative_path)

    return public_url


def get_ordonnance_form_data():
    """
    Supporte:
    - multipart/form-data avec photo caméra/galerie
    - JSON avec ordonnance_url/image_url si Flutter envoie déjà une URL
    """
    if request.content_type and request.content_type.startswith("multipart/form-data"):
        medicaments_raw = request.form.get("medicaments", "[]")

        try:
            medicaments = json.loads(medicaments_raw)
        except Exception:
            medicaments = []

        return {
            "medicaments": medicaments,
            "message_patient": request.form.get("message_patient"),
            "rayon_km": request.form.get("rayon_km", 5),
            "latitude": request.form.get("latitude"),
            "longitude": request.form.get("longitude"),
            "ordonnance_url": request.form.get("ordonnance_url") or request.form.get("image_url"),
        }

    data = request.get_json(silent=True) or {}

    return {
        "medicaments": data.get("medicaments", []),
        "message_patient": data.get("message_patient"),
        "rayon_km": data.get("rayon_km", 5),
        "latitude": data.get("latitude"),
        "longitude": data.get("longitude"),
        "ordonnance_url": data.get("ordonnance_url") or data.get("image_url"),
    }


def insert_ordonnance_image(cursor, demande_id, image_path):
    """
    Insère l'ordonnance dans la table demande_ordonnances.

    Priorité:
      demande_ordonnances(demande_id, url)

    Puis fallback dynamique si ta BDD a un autre nom de colonne/table.
    """
    if not image_path:
        return False

    # Priorité à la table correcte
    cursor.execute("SHOW TABLES LIKE 'demande_ordonnances'")
    table_exists = cursor.fetchone()

    if table_exists:
        cursor.execute("SHOW COLUMNS FROM demande_ordonnances")
        columns = cursor.fetchall()
        column_names = [column["Field"] for column in columns]

        if "demande_id" in column_names:
            if "url" in column_names:
                cursor.execute(
                    """
                    INSERT INTO demande_ordonnances (demande_id, url)
                    VALUES (%s, %s)
                    """,
                    (demande_id, image_path)
                )
                return True

            if "image_url" in column_names:
                cursor.execute(
                    """
                    INSERT INTO demande_ordonnances (demande_id, image_url)
                    VALUES (%s, %s)
                    """,
                    (demande_id, image_path)
                )
                return True

    # Fallback dynamique pour toute table contenant "ordon"
    cursor.execute("SHOW TABLES LIKE %s", ("%ordon%",))
    tables = cursor.fetchall()

    preferred_image_columns = [
        "image_url",
        "ordonnance_url",
        "fichier_url",
        "photo_url",
        "chemin_image",
        "chemin",
        "url",
        "fichier",
    ]

    for table_row in tables:
        table_name = list(table_row.values())[0]
        safe_table_name = table_name.replace("`", "``")

        cursor.execute(f"SHOW COLUMNS FROM `{safe_table_name}`")
        columns = cursor.fetchall()

        column_names = [
            column["Field"]
            for column in columns
        ]

        if "demande_id" not in column_names:
            continue

        image_column = None

        for column in preferred_image_columns:
            if column in column_names:
                image_column = column
                break

        if image_column is None:
            continue

        insert_columns = ["demande_id", image_column]
        values = [demande_id, image_path]

        if "patient_id" in column_names:
            insert_columns.append("patient_id")
            values.append(request.patient["patient_id"])

        escaped_columns = ", ".join([f"`{column}`" for column in insert_columns])
        placeholders = ", ".join(["%s"] * len(insert_columns))

        cursor.execute(
            f"""
            INSERT INTO `{safe_table_name}`
            ({escaped_columns})
            VALUES ({placeholders})
            """,
            tuple(values)
        )

        return True

    raise Exception("Aucune table ordonnance compatible trouvée")


def normalize_ordonnance_images(rows):
    normalized = []
    base_url = os.getenv("APP_URL", request.host_url.rstrip("/")).rstrip("/")

    for row in rows:
        item = clean_row(row)
        image_url = ""

        for key, value in item.items():
            key_lower = key.lower()

            if value is None:
                continue

            if (
                "url" in key_lower
                or "image" in key_lower
                or "photo" in key_lower
                or "fichier" in key_lower
                or "chemin" in key_lower
            ):
                text = str(value).strip()

                if text:
                    if text.startswith("http://") or text.startswith("https://"):
                        image_url = text
                    elif text.startswith("/"):
                        image_url = f"{base_url}{text}"
                    else:
                        image_url = make_upload_url(text)

                    break

        item["image_url_resolved"] = image_url
        normalized.append(item)

    return normalized


def fetch_ordonnances_for_demande(cursor, demande_id):
    try:
        cursor.execute("SHOW TABLES LIKE %s", ("%ordon%",))
        tables = cursor.fetchall()

        for table_row in tables:
            table_name = list(table_row.values())[0]
            safe_table_name = table_name.replace("`", "``")

            cursor.execute(f"SHOW COLUMNS FROM `{safe_table_name}`")
            columns = cursor.fetchall()

            column_names = [
                column["Field"]
                for column in columns
            ]

            if "demande_id" not in column_names:
                continue

            cursor.execute(
                f"""
                SELECT *
                FROM `{safe_table_name}`
                WHERE demande_id = %s
                ORDER BY 1 DESC
                """,
                (demande_id,)
            )

            rows = cursor.fetchall()
            return normalize_ordonnance_images(rows)

        return []

    except Exception as e:
        print("FETCH ORDONNANCES WARNING:", e)
        return []


def attach_demande_to_nearby_pharmacies(cursor, demande_id, latitude, longitude, rayon_km):
    if latitude is None or longitude is None:
        return

    try:
        cursor.execute(
            """
            INSERT IGNORE INTO demande_pharmacies
            (demande_id, pharmacie_id, statut)
            SELECT
                %s AS demande_id,
                p.pharmacie_id,
                'en_attente' AS statut
            FROM pharmacies p
            WHERE p.latitude IS NOT NULL
            AND p.longitude IS NOT NULL
            AND p.statut = 'approuvee'
            AND (
                6371 * ACOS(
                    LEAST(
                        1,
                        GREATEST(
                            -1,
                            COS(RADIANS(%s)) *
                            COS(RADIANS(p.latitude)) *
                            COS(RADIANS(p.longitude) - RADIANS(%s)) +
                            SIN(RADIANS(%s)) *
                            SIN(RADIANS(p.latitude))
                        )
                    )
                )
            ) <= %s
            """,
            (
                demande_id,
                latitude,
                longitude,
                latitude,
                rayon_km,
            )
        )
    except Exception as e:
        print("ATTACH PHARMACIES WARNING:", e)


@demande_bp.get("/patient")
@auth_patient
def get_patient_demandes():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute(
            """
            SELECT
                d.demande_id,
                d.type,
                d.message_patient,
                d.rayon_km,
                d.etat,
                d.pharmacie_choisie_id,
                d.note_pharmacie,
                d.commentaire,
                d.cree_le,
                p.nom AS pharmacie_choisie
            FROM demandes d
            LEFT JOIN pharmacies p
                ON p.pharmacie_id = d.pharmacie_choisie_id
            WHERE d.patient_id = %s
            ORDER BY d.cree_le DESC
            """,
            (request.patient["patient_id"],)
        )

        rows = cursor.fetchall()

        return jsonify({
            "success": True,
            "data": clean_rows(rows)
        })

    except Exception as e:
        print("GET DEMANDES ERROR:", e)
        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()


@demande_bp.get("/<int:demande_id>")
@auth_patient
def get_demande_detail(demande_id):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute(
            """
            SELECT
                d.demande_id,
                d.patient_id,
                d.type,
                d.message_patient,
                d.rayon_km,
                d.latitude,
                d.longitude,
                d.etat,
                d.pharmacie_choisie_id,
                d.note_pharmacie,
                d.commentaire,
                d.cree_le,
                d.modifie_le,

                p.nom AS pharmacie_choisie,
                p.adresse AS pharmacie_choisie_adresse,
                p.telephone AS pharmacie_choisie_telephone
            FROM demandes d
            LEFT JOIN pharmacies p
                ON p.pharmacie_id = d.pharmacie_choisie_id
            WHERE d.demande_id = %s
            AND d.patient_id = %s
            """,
            (
                demande_id,
                request.patient["patient_id"],
            )
        )

        demande = cursor.fetchone()

        if not demande:
            return jsonify({
                "success": False,
                "message": "Demande introuvable"
            }), 404

        cursor.execute(
            """
            SELECT
                dm.demande_medicament_id,
                dm.demande_id,
                dm.medicament_id,
                dm.nom_libre,
                dm.quantite,
                m.nom AS medicament_nom
            FROM demande_medicaments dm
            LEFT JOIN medicaments m
                ON m.medicament_id = dm.medicament_id
            WHERE dm.demande_id = %s
            ORDER BY dm.demande_medicament_id ASC
            """,
            (demande_id,)
        )

        medicaments = cursor.fetchall()

        # Stats de toutes les pharmacies liées à la demande
        # Même les pharmacies en attente ne seront pas affichées dans la liste,
        # mais elles seront comptées ici pour afficher le message d'attente.
        cursor.execute(
            """
            SELECT
                COUNT(*) AS total,
                COALESCE(SUM(CASE WHEN statut = 'en_attente' THEN 1 ELSE 0 END), 0) AS en_attente,
                COALESCE(SUM(CASE WHEN statut = 'acceptee' THEN 1 ELSE 0 END), 0) AS acceptee,
                COALESCE(SUM(CASE WHEN statut = 'refusee' THEN 1 ELSE 0 END), 0) AS refusee,
                COALESCE(SUM(CASE WHEN statut = 'choisie' THEN 1 ELSE 0 END), 0) AS choisie
            FROM demande_pharmacies
            WHERE demande_id = %s
            """,
            (demande_id,)
        )

        pharmacie_stats = cursor.fetchone() or {
            "total": 0,
            "en_attente": 0,
            "acceptee": 0,
            "refusee": 0,
            "choisie": 0,
        }

        cursor.execute(
            """
            SELECT
                dp.demande_pharmacie_id,
                dp.demande_id,
                dp.pharmacie_id,
                dp.statut,
                dp.message,
                dp.prix_estime,
                dp.disponibilite,
                dp.repondu_le,
                dp.cree_le,
                dp.modifie_le,

                ph.nom AS pharmacie_nom,
                ph.adresse AS pharmacie_adresse,
                ph.telephone AS pharmacie_telephone,
                ph.latitude AS pharmacie_latitude,
                ph.longitude AS pharmacie_longitude,
                ph.est_ouverte,
                ph.est_de_garde,

                CASE
                    WHEN d.latitude IS NOT NULL
                    AND d.longitude IS NOT NULL
                    AND ph.latitude IS NOT NULL
                    AND ph.longitude IS NOT NULL
                    THEN ROUND(
                        6371 * ACOS(
                            LEAST(
                                1,
                                GREATEST(
                                    -1,
                                    COS(RADIANS(d.latitude)) *
                                    COS(RADIANS(ph.latitude)) *
                                    COS(RADIANS(ph.longitude) - RADIANS(d.longitude)) +
                                    SIN(RADIANS(d.latitude)) *
                                    SIN(RADIANS(ph.latitude))
                                )
                            )
                        ),
                        2
                    )
                    ELSE NULL
                END AS distance_km

            FROM demande_pharmacies dp
            JOIN pharmacies ph
                ON ph.pharmacie_id = dp.pharmacie_id
            JOIN demandes d
                ON d.demande_id = dp.demande_id
            WHERE dp.demande_id = %s
            AND dp.statut IN ('acceptee', 'refusee', 'choisie')
            ORDER BY
                CASE dp.statut
                    WHEN 'choisie' THEN 1
                    WHEN 'acceptee' THEN 2
                    WHEN 'refusee' THEN 3
                    ELSE 4
                END,
                dp.demande_pharmacie_id ASC
            """,
            (demande_id,)
        )

        pharmacies = cursor.fetchall()
        ordonnances = fetch_ordonnances_for_demande(cursor, demande_id)

        return jsonify({
            "success": True,
            "data": {
                "demande": clean_row(demande),
                "medicaments": clean_rows(medicaments),
                "pharmacies": clean_rows(pharmacies),
                "pharmacie_stats": clean_row(pharmacie_stats),
                "ordonnances": ordonnances
            }
        })

    except Exception as e:
        print("GET DEMANDE DETAIL ERROR:", e)
        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()
@demande_bp.post("/manuelle")
@auth_patient
def create_demande_manuelle():
    data = request.get_json() or {}

    medicaments = data.get("medicaments", [])
    message_patient = data.get("message_patient")
    rayon_km = data.get("rayon_km", 5)
    latitude = data.get("latitude")
    longitude = data.get("longitude")

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        conn.start_transaction()

        cursor.execute(
            """
            INSERT INTO demandes
            (patient_id, type, message_patient, rayon_km, latitude, longitude)
            VALUES (%s, 'manuelle', %s, %s, %s, %s)
            """,
            (
                request.patient["patient_id"],
                message_patient,
                rayon_km,
                latitude,
                longitude
            )
        )

        demande_id = cursor.lastrowid

        for med in medicaments:
            cursor.execute(
                """
                INSERT INTO demande_medicaments
                (demande_id, medicament_id, nom_libre, quantite)
                VALUES (%s, %s, %s, %s)
                """,
                (
                    demande_id,
                    med.get("medicament_id"),
                    med.get("nom_libre"),
                    med.get("quantite", 1)
                )
            )

        attach_demande_to_nearby_pharmacies(
            cursor=cursor,
            demande_id=demande_id,
            latitude=latitude,
            longitude=longitude,
            rayon_km=rayon_km,
        )

        conn.commit()

        return jsonify({
            "success": True,
            "message": "Demande créée avec succès",
            "demande_id": demande_id
        }), 201

    except Exception as e:
        conn.rollback()
        print("CREATE DEMANDE ERROR:", e)
        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()


@demande_bp.post("/ordonnance")
@auth_patient
def create_demande_ordonnance():
    form_data = get_ordonnance_form_data()

    medicaments = form_data.get("medicaments", [])
    message_patient = form_data.get("message_patient")
    rayon_km = form_data.get("rayon_km", 5)
    latitude = form_data.get("latitude")
    longitude = form_data.get("longitude")
    ordonnance_url = form_data.get("ordonnance_url")

    try:
        rayon_km = int(float(rayon_km))
    except Exception:
        rayon_km = 5

    file = get_ordonnance_file()

    print("ORDONNANCE FILE RECEIVED:", file.filename if file else "NO FILE")
    print("REQUEST CONTENT TYPE:", request.content_type)
    print("REQUEST FILE KEYS:", list(request.files.keys()))
    print("REQUEST FORM KEYS:", list(request.form.keys()))

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    saved_image_path = None

    try:
        conn.start_transaction()

        if file is not None:
            saved_image_path = save_ordonnance_file(file)

        image_to_insert = saved_image_path or ordonnance_url

        cursor.execute(
            """
            INSERT INTO demandes
            (patient_id, type, message_patient, rayon_km, latitude, longitude)
            VALUES (%s, 'ordonnance', %s, %s, %s, %s)
            """,
            (
                request.patient["patient_id"],
                message_patient,
                rayon_km,
                latitude,
                longitude,
            )
        )

        demande_id = cursor.lastrowid

        if image_to_insert:
            insert_ordonnance_image(
                cursor=cursor,
                demande_id=demande_id,
                image_path=image_to_insert,
            )

        for med in medicaments:
            cursor.execute(
                """
                INSERT INTO demande_medicaments
                (demande_id, medicament_id, nom_libre, quantite)
                VALUES (%s, %s, %s, %s)
                """,
                (
                    demande_id,
                    med.get("medicament_id"),
                    med.get("nom_libre"),
                    med.get("quantite", 1),
                )
            )

        attach_demande_to_nearby_pharmacies(
            cursor=cursor,
            demande_id=demande_id,
            latitude=latitude,
            longitude=longitude,
            rayon_km=rayon_km,
        )

        conn.commit()

        return jsonify({
            "success": True,
            "message": "Demande ordonnance créée avec succès",
            "demande_id": demande_id,
            "image_url": image_to_insert,
        }), 201

    except ValueError as e:
        conn.rollback()

        return jsonify({
            "success": False,
            "message": str(e),
        }), 400

    except Exception as e:
        conn.rollback()
        print("CREATE DEMANDE ORDONNANCE ERROR:", e)

        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()


@demande_bp.post("/<int:demande_id>/choisir-pharmacie")
@auth_patient
def choisir_pharmacie(demande_id):
    data = request.get_json() or {}
    pharmacie_id = data.get("pharmacie_id")

    if pharmacie_id is None:
        return jsonify({
            "success": False,
            "message": "Pharmacie obligatoire"
        }), 400

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        conn.start_transaction()

        cursor.execute(
            """
            SELECT demande_id, patient_id, etat
            FROM demandes
            WHERE demande_id = %s
            AND patient_id = %s
            """,
            (
                demande_id,
                request.patient["patient_id"],
            )
        )

        demande = cursor.fetchone()

        if not demande:
            conn.rollback()
            return jsonify({
                "success": False,
                "message": "Demande introuvable"
            }), 404

        if demande["etat"] != "reponse_recue":
            conn.rollback()
            return jsonify({
                "success": False,
                "message": "Vous pouvez choisir une pharmacie seulement après réception d’une réponse"
            }), 400

        cursor.execute(
            """
            SELECT demande_pharmacie_id, statut
            FROM demande_pharmacies
            WHERE demande_id = %s
            AND pharmacie_id = %s
            """,
            (
                demande_id,
                pharmacie_id,
            )
        )

        demande_pharmacie = cursor.fetchone()

        if not demande_pharmacie:
            conn.rollback()
            return jsonify({
                "success": False,
                "message": "Cette pharmacie n’est pas liée à la demande"
            }), 404

        if demande_pharmacie["statut"] != "acceptee":
            conn.rollback()
            return jsonify({
                "success": False,
                "message": "Vous pouvez choisir uniquement une pharmacie qui a accepté la demande"
            }), 400

        cursor.execute(
            """
            UPDATE demandes
            SET pharmacie_choisie_id = %s,
                etat = 'pharmacie_choisie'
            WHERE demande_id = %s
            AND patient_id = %s
            """,
            (
                pharmacie_id,
                demande_id,
                request.patient["patient_id"],
            )
        )

        cursor.execute(
            """
            UPDATE demande_pharmacies
            SET statut = 'choisie'
            WHERE demande_id = %s
            AND pharmacie_id = %s
            """,
            (
                demande_id,
                pharmacie_id,
            )
        )

        conn.commit()

        return jsonify({
            "success": True,
            "message": "Pharmacie choisie avec succès"
        })

    except Exception as e:
        conn.rollback()
        print("CHOISIR PHARMACIE ERROR:", e)
        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()


@demande_bp.post("/<int:demande_id>/note")
@auth_patient
def note_demande(demande_id):
    data = request.get_json() or {}

    note = data.get("note_pharmacie")
    commentaire = data.get("commentaire")

    conn = get_db_connection()
    cursor = conn.cursor()

    try:
        cursor.execute(
            """
            UPDATE demandes
            SET note_pharmacie = %s,
                commentaire = %s,
                etat = 'termine'
            WHERE demande_id = %s
            AND patient_id = %s
            """,
            (
                note,
                commentaire,
                demande_id,
                request.patient["patient_id"]
            )
        )

        conn.commit()

        return jsonify({
            "success": True,
            "message": "Note ajoutée"
        })

    except Exception as e:
        conn.rollback()
        print("NOTE DEMANDE ERROR:", e)
        return jsonify({
            "success": False,
            "message": "Erreur serveur"
        }), 500

    finally:
        cursor.close()
        conn.close()