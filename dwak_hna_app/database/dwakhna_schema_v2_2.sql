-- ============================================================
-- DWAK HNA - Schéma MySQL v2.2
-- Inclut panier, commandes produits et notifications produits.
-- ============================================================

DROP DATABASE IF EXISTS dwakhna_db;
CREATE DATABASE dwakhna_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE dwakhna_db;
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS commande_produit_items;
DROP TABLE IF EXISTS commandes_produits;
DROP TABLE IF EXISTS panier_items;
DROP TABLE IF EXISTS paniers;
DROP TABLE IF EXISTS publicites;
DROP TABLE IF EXISTS partenaires;
DROP TABLE IF EXISTS notifications_systeme;
DROP TABLE IF EXISTS notifications_admin;
DROP TABLE IF EXISTS demande_pharmacies;
DROP TABLE IF EXISTS demande_medicaments;
DROP TABLE IF EXISTS demande_ordonnances;
DROP TABLE IF EXISTS demandes;
DROP TABLE IF EXISTS produit_categories;
DROP TABLE IF EXISTS pharmacie_produits;
DROP TABLE IF EXISTS admin_produits;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS medicaments;
DROP TABLE IF EXISTS pharmacies;
DROP TABLE IF EXISTS administrateurs;
DROP TABLE IF EXISTS patients;
DROP TABLE IF EXISTS communes;
DROP TABLE IF EXISTS wilayas;

CREATE TABLE wilayas (
    wilaya_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(3) NOT NULL UNIQUE,
    nom VARCHAR(100) NOT NULL,
    cree_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE communes (
    commune_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    wilaya_id INT UNSIGNED NOT NULL,
    nom VARCHAR(100) NOT NULL,
    cree_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_commune_wilaya FOREIGN KEY (wilaya_id) REFERENCES wilayas(wilaya_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE patients (
    patient_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(100) NOT NULL,
    prenom VARCHAR(100) NOT NULL,
    email VARCHAR(191) NOT NULL UNIQUE,
    mot_de_passe_hash VARCHAR(255) NOT NULL,
    telephone VARCHAR(20),
    firebase_token VARCHAR(512),
    image VARCHAR(512),
    statut ENUM('actif','suspendu','supprime') NOT NULL DEFAULT 'actif',
    email_verifie BOOLEAN NOT NULL DEFAULT FALSE,
    cree_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    modifie_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE administrateurs (
    admin_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(100) NOT NULL,
    email VARCHAR(191) NOT NULL UNIQUE,
    mot_de_passe_hash VARCHAR(255) NOT NULL,
    role ENUM('super_admin','admin') NOT NULL DEFAULT 'admin',
    cree_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    modifie_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE pharmacies (
    pharmacie_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(150) NOT NULL,
    email VARCHAR(191) NOT NULL UNIQUE,
    mot_de_passe_hash VARCHAR(255) NOT NULL,
    telephone VARCHAR(20),
    adresse VARCHAR(255),
    wilaya_id INT UNSIGNED NOT NULL,
    commune_id INT UNSIGNED NOT NULL,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    logo_url VARCHAR(512),
    firebase_token VARCHAR(512),
    registre_commerce VARCHAR(512),
    carte_identite VARCHAR(512),
    statut ENUM('en_attente','approuvee','suspendue','supprimee') NOT NULL DEFAULT 'en_attente',
    est_ouverte BOOLEAN NOT NULL DEFAULT FALSE,
    est_de_garde BOOLEAN NOT NULL DEFAULT FALSE,
    horaires JSON,
    cree_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    modifie_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_pharmacie_wilaya FOREIGN KEY (wilaya_id) REFERENCES wilayas(wilaya_id),
    CONSTRAINT fk_pharmacie_commune FOREIGN KEY (commune_id) REFERENCES communes(commune_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE medicaments (
    medicament_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(200) NOT NULL,
    denomination_commune VARCHAR(200),
    forme VARCHAR(100),
    dosage VARCHAR(100),
    fabricant VARCHAR(150),
    necessite_ordonnance BOOLEAN NOT NULL DEFAULT FALSE,
    description TEXT,
    image_url VARCHAR(512),
    est_actif BOOLEAN NOT NULL DEFAULT TRUE,
    cree_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    modifie_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FULLTEXT INDEX idx_recherche_medicament (nom, denomination_commune)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE categories (
    categorie_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(100) NOT NULL,
    type_produit ENUM('medicament','parapharmacie') NOT NULL,
    description TEXT,
    cree_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_categorie (nom, type_produit)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE admin_produits (
    admin_produit_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(200) NOT NULL,
    description TEXT,
    image_url VARCHAR(512),
    type_produit ENUM('medicament','parapharmacie') NOT NULL,
    est_actif BOOLEAN NOT NULL DEFAULT TRUE,
    cree_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    modifie_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE produit_categories (
    admin_produit_id INT UNSIGNED NOT NULL,
    categorie_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (admin_produit_id, categorie_id),
    CONSTRAINT fk_pc_produit FOREIGN KEY (admin_produit_id) REFERENCES admin_produits(admin_produit_id) ON DELETE CASCADE,
    CONSTRAINT fk_pc_categorie FOREIGN KEY (categorie_id) REFERENCES categories(categorie_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE pharmacie_produits (
    pharmacie_produit_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    pharmacie_id INT UNSIGNED NOT NULL,
    admin_produit_id INT UNSIGNED NOT NULL,
    description_perso TEXT,
    prix DECIMAL(10,2),
    est_disponible BOOLEAN NOT NULL DEFAULT TRUE,
    cree_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    modifie_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_pharmacie_produit (pharmacie_id, admin_produit_id),
    CONSTRAINT fk_pp_pharmacie FOREIGN KEY (pharmacie_id) REFERENCES pharmacies(pharmacie_id) ON DELETE CASCADE,
    CONSTRAINT fk_pp_produit FOREIGN KEY (admin_produit_id) REFERENCES admin_produits(admin_produit_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE demandes (
    demande_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    patient_id INT UNSIGNED NOT NULL,
    type ENUM('manuelle','ordonnance') NOT NULL,
    message_patient TEXT,
    rayon_km TINYINT UNSIGNED NOT NULL DEFAULT 5,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    etat ENUM('en_attente','reponse_recue','termine','annule') NOT NULL DEFAULT 'en_attente',
    pharmacie_choisie_id INT UNSIGNED NULL,
    note_pharmacie TINYINT UNSIGNED NULL,
    commentaire TEXT NULL,
    cree_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    modifie_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT chk_note CHECK (note_pharmacie BETWEEN 1 AND 5),
    CONSTRAINT fk_demande_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE,
    CONSTRAINT fk_demande_pharmacie FOREIGN KEY (pharmacie_choisie_id) REFERENCES pharmacies(pharmacie_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE demande_ordonnances (
    ordonnance_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    demande_id INT UNSIGNED NOT NULL,
    url VARCHAR(512) NOT NULL,
    cree_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ord_demande FOREIGN KEY (demande_id) REFERENCES demandes(demande_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE demande_medicaments (
    demande_medicament_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    demande_id INT UNSIGNED NOT NULL,
    medicament_id INT UNSIGNED NULL,
    nom_libre VARCHAR(200),
    quantite TINYINT UNSIGNED NOT NULL DEFAULT 1,
    CONSTRAINT fk_dm_demande FOREIGN KEY (demande_id) REFERENCES demandes(demande_id) ON DELETE CASCADE,
    CONSTRAINT fk_dm_medicament FOREIGN KEY (medicament_id) REFERENCES medicaments(medicament_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE demande_pharmacies (
    demande_pharmacie_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    demande_id INT UNSIGNED NOT NULL,
    pharmacie_id INT UNSIGNED NOT NULL,
    statut ENUM('en_attente','acceptee','refusee') NOT NULL DEFAULT 'en_attente',
    message TEXT,
    repondu_le TIMESTAMP NULL,
    cree_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_demande_pharmacie (demande_id, pharmacie_id),
    CONSTRAINT fk_dp_demande FOREIGN KEY (demande_id) REFERENCES demandes(demande_id) ON DELETE CASCADE,
    CONSTRAINT fk_dp_pharmacie FOREIGN KEY (pharmacie_id) REFERENCES pharmacies(pharmacie_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE paniers (
    panier_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    patient_id INT UNSIGNED NOT NULL,
    statut ENUM('actif','envoye','annule') NOT NULL DEFAULT 'actif',
    cree_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    modifie_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_panier_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE panier_items (
    panier_item_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    panier_id INT UNSIGNED NOT NULL,
    pharmacie_produit_id INT UNSIGNED NOT NULL,
    quantite TINYINT UNSIGNED NOT NULL DEFAULT 1,
    cree_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_panier_item (panier_id, pharmacie_produit_id),
    CONSTRAINT fk_item_panier FOREIGN KEY (panier_id) REFERENCES paniers(panier_id) ON DELETE CASCADE,
    CONSTRAINT fk_item_pharmacie_produit FOREIGN KEY (pharmacie_produit_id) REFERENCES pharmacie_produits(pharmacie_produit_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE commandes_produits (
    commande_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    patient_id INT UNSIGNED NOT NULL,
    pharmacie_id INT UNSIGNED NOT NULL,
    etat ENUM('envoyee','acceptee','refusee','prete','terminee','annulee') NOT NULL DEFAULT 'envoyee',
    message_patient TEXT,
    message_pharmacie TEXT,
    note_pharmacie TINYINT UNSIGNED NULL,
    commentaire TEXT NULL,
    cree_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    modifie_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT chk_note_commande CHECK (note_pharmacie BETWEEN 1 AND 5),
    CONSTRAINT fk_commande_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE,
    CONSTRAINT fk_commande_pharmacie FOREIGN KEY (pharmacie_id) REFERENCES pharmacies(pharmacie_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE commande_produit_items (
    commande_item_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    commande_id INT UNSIGNED NOT NULL,
    pharmacie_produit_id INT UNSIGNED NOT NULL,
    quantite TINYINT UNSIGNED NOT NULL DEFAULT 1,
    prix_unitaire DECIMAL(10,2),
    CONSTRAINT fk_commande_item_commande FOREIGN KEY (commande_id) REFERENCES commandes_produits(commande_id) ON DELETE CASCADE,
    CONSTRAINT fk_commande_item_produit FOREIGN KEY (pharmacie_produit_id) REFERENCES pharmacie_produits(pharmacie_produit_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE notifications_admin (
    notif_admin_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    titre VARCHAR(200) NOT NULL,
    corps TEXT NOT NULL,
    type ENUM('patient','pharmacie','tous') NOT NULL,
    patient_id INT UNSIGNED NULL,
    pharmacie_id INT UNSIGNED NULL,
    est_lue BOOLEAN NOT NULL DEFAULT FALSE,
    envoye_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_notif_admin_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE,
    CONSTRAINT fk_notif_admin_pharmacie FOREIGN KEY (pharmacie_id) REFERENCES pharmacies(pharmacie_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE notifications_systeme (
    notif_systeme_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    type_notif ENUM(
        'nouvelle_demande','demande_acceptee','demande_refusee','demande_annulee',
        'pharmacie_approuvee','pharmacie_suspendue',
        'commande_produit_envoyee','commande_produit_acceptee','commande_produit_refusee','commande_produit_prete'
    ) NOT NULL,
    titre VARCHAR(200) NOT NULL,
    corps TEXT NOT NULL,
    patient_id INT UNSIGNED NULL,
    pharmacie_id INT UNSIGNED NULL,
    demande_id INT UNSIGNED NULL,
    commande_id INT UNSIGNED NULL,
    est_lue BOOLEAN NOT NULL DEFAULT FALSE,
    envoye_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_notif_sys_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE,
    CONSTRAINT fk_notif_sys_pharmacie FOREIGN KEY (pharmacie_id) REFERENCES pharmacies(pharmacie_id) ON DELETE CASCADE,
    CONSTRAINT fk_notif_sys_demande FOREIGN KEY (demande_id) REFERENCES demandes(demande_id) ON DELETE SET NULL,
    CONSTRAINT fk_notif_sys_commande FOREIGN KEY (commande_id) REFERENCES commandes_produits(commande_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE partenaires (
    partenaire_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(150) NOT NULL,
    logo_url VARCHAR(512),
    site_web VARCHAR(512),
    description TEXT,
    est_actif BOOLEAN NOT NULL DEFAULT TRUE,
    cree_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    modifie_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE publicites (
    publicite_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    titre VARCHAR(200) NOT NULL,
    image_url VARCHAR(512) NOT NULL,
    lien_cible VARCHAR(512),
    proprietaire ENUM('plateforme','partenaire') NOT NULL DEFAULT 'plateforme',
    partenaire_id INT UNSIGNED NULL,
    position TINYINT UNSIGNED NOT NULL DEFAULT 0,
    date_debut DATE NOT NULL,
    date_fin DATE NOT NULL,
    est_active BOOLEAN NOT NULL DEFAULT TRUE,
    emplacement_pharmacie BOOLEAN NOT NULL DEFAULT FALSE,
    emplacement_patient_accueil BOOLEAN NOT NULL DEFAULT FALSE,
    emplacement_patient_store BOOLEAN NOT NULL DEFAULT FALSE,
    cree_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    modifie_le TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_pub_partenaire FOREIGN KEY (partenaire_id) REFERENCES partenaires(partenaire_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE INDEX idx_pharmacie_geo ON pharmacies (latitude, longitude);
CREATE INDEX idx_pharmacie_statut ON pharmacies (statut, est_ouverte, est_de_garde);
CREATE INDEX idx_pharmacie_wilaya ON pharmacies (wilaya_id, commune_id);
CREATE INDEX idx_demande_patient ON demandes (patient_id, etat);
CREATE INDEX idx_demande_created ON demandes (cree_le);
CREATE INDEX idx_dp_statut ON demande_pharmacies (pharmacie_id, statut);
CREATE INDEX idx_panier_patient ON paniers (patient_id, statut);
CREATE INDEX idx_commande_patient ON commandes_produits (patient_id, etat);
CREATE INDEX idx_commande_pharmacie ON commandes_produits (pharmacie_id, etat);
CREATE INDEX idx_notif_admin_patient ON notifications_admin (patient_id, est_lue);
CREATE INDEX idx_notif_admin_pharma ON notifications_admin (pharmacie_id, est_lue);
CREATE INDEX idx_notif_sys_patient ON notifications_systeme (patient_id, est_lue);
CREATE INDEX idx_notif_sys_pharma ON notifications_systeme (pharmacie_id, est_lue);
CREATE INDEX idx_pub_dates ON publicites (date_debut, date_fin, est_active);

INSERT INTO administrateurs (nom, email, mot_de_passe_hash, role) VALUES
('Super Admin', 'admin@dwakhna.dz', 'CHANGE_ME_BCRYPT_HASH', 'super_admin');

INSERT INTO wilayas (code, nom) VALUES
('16','Alger'),('31','Oran'),('25','Constantine'),('09','Blida'),('06','Béjaïa');

INSERT INTO communes (wilaya_id, nom) VALUES
(1, 'Bir Khadem'), (1, 'El Mouradia'), (1, 'Hydra'), (1, 'Kouba'), (2, 'Bir El Djir');

INSERT INTO categories (nom, type_produit) VALUES
('Antibiotiques','medicament'),('Analgésiques','medicament'),('Anti-inflammatoires','medicament'),
('Antihistaminiques','medicament'),('Vitamines & Compléments','medicament'),('Dermatologie','medicament'),
('Soins du visage','parapharmacie'),('Soins du corps','parapharmacie'),('Hygiène bucco-dentaire','parapharmacie'),
('Capillaire','parapharmacie'),('Bébé & Maternité','parapharmacie'),('Matériel médical','parapharmacie'),('Solaires','parapharmacie');

SET FOREIGN_KEY_CHECKS = 1;
-- ============================================================
-- FIN SCHEMA DWAK HNA v2.2
-- ============================================================
