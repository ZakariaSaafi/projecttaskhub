#!/bin/bash
# Script d'initialisation PostgreSQL pour ProjectTaskHub

set -e

echo "🔧 Initialisation des bases de données PostgreSQL..."

# Fonction pour créer une base de données si elle n'existe pas
create_database() {
    local database=$1
    echo "📊 Création de la base de données: $database"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        SELECT 'CREATE DATABASE $database'
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$database')\gexec
EOSQL
}

# Créer les bases de données nécessaires
create_database "keycloak"
create_database "projectdb"

echo "✅ Bases de données créées avec succès!"

# Initialiser la base projectdb avec des tables de base
echo "🏗️ Initialisation de la base projectdb..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "projectdb" <<-EOSQL
    -- Table des projets
    CREATE TABLE IF NOT EXISTS projects (
        id BIGSERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        description TEXT,
        start_date TIMESTAMP NOT NULL,
        end_date TIMESTAMP,
        status VARCHAR(50) NOT NULL,
        owner VARCHAR(255) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- Index pour améliorer les performances
    CREATE INDEX IF NOT EXISTS idx_projects_owner ON projects(owner);
    CREATE INDEX IF NOT EXISTS idx_projects_status ON projects(status);
    CREATE INDEX IF NOT EXISTS idx_projects_created_at ON projects(created_at);

    -- Données de test
    INSERT INTO projects (name, description, start_date, status, owner) 
    VALUES 
        ('Projet Demo', 'Projet de démonstration', CURRENT_TIMESTAMP, 'PLANNING', 'admin'),
        ('Projet Test', 'Projet de test', CURRENT_TIMESTAMP, 'IN_PROGRESS', 'user1')
    ON CONFLICT DO NOTHING;

    -- Afficher le résultat
    SELECT COUNT(*) as total_projects FROM projects;
EOSQL

echo "✅ Base projectdb initialisée avec succès!"
echo "🎉 Initialisation PostgreSQL terminée!"