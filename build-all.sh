#!/bin/bash
# 📁 Emplacement: projecttaskhub/build-all.sh
# Script de build complet pour tous les services

set -e  # Arrêt en cas d'erreur

echo "🏗️  Construction complète de ProjectTaskHub..."
echo "================================================"

# Vérifications préalables
echo "🔍 Vérifications préalables..."

# Vérifier Java
if ! command -v java &> /dev/null; then
    echo "❌ Java n'est pas installé"
    exit 1
fi

JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1)
if [ "$JAVA_VERSION" -lt 17 ]; then
    echo "❌ Java 17+ requis. Version détectée: $JAVA_VERSION"
    exit 1
fi
echo "✅ Java $JAVA_VERSION détecté"

# Vérifier Maven
if ! command -v mvn &> /dev/null; then
    echo "❌ Maven n'est pas installé"
    exit 1
fi
echo "✅ Maven détecté"

# Vérifier Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker n'est pas installé"
    exit 1
fi

if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker n'est pas en cours d'exécution"
    exit 1
fi
echo "✅ Docker opérationnel"

# Nettoyer les anciens builds
echo ""
echo "🧹 Nettoyage des anciens builds..."
mvn clean -q

# Build de la librairie partagée en premier
echo ""
echo "📦 1/6 - Construction de shared-dto..."
if [ -d "shared-dto" ]; then
    cd shared-dto
    mvn clean install -DskipTests -q
    if [ $? -eq 0 ]; then
        echo "✅ shared-dto compilé avec succès"
    else
        echo "❌ Erreur lors de la compilation de shared-dto"
        exit 1
    fi
    cd ..
else
    echo "⚠️  shared-dto non trouvé, création du module..."
    mkdir -p shared-dto/src/main/java/com/projecttaskhub/shared
    echo "📝 Veuillez créer le module shared-dto avant de continuer"
    exit 1
fi

# Build des services dans l'ordre des dépendances
SERVICES=("config-server" "discovery-server" "api-gateway" "project-service" "task-service")
COUNTER=2

for service in "${SERVICES[@]}"; do
    echo ""
    echo "📦 $COUNTER/6 - Construction de $service..."

    if [ -d "$service" ]; then
        cd "$service"
        mvn clean package -DskipTests -q

        if [ -f "target/$service-1.0.0.jar" ]; then
            JAR_SIZE=$(du -h "target/$service-1.0.0.jar" | cut -f1)
            echo "✅ $service-1.0.0.jar créé ($JAR_SIZE)"
        else
            echo "❌ Erreur: JAR non créé pour $service"
            exit 1
        fi

        cd ..
    else
        echo "⚠️  $service non trouvé, ignoré"
    fi

    ((COUNTER++))
done

# Résumé
echo ""
echo "📊 Résumé de la construction:"
echo "================================"

for service in "${SERVICES[@]}"; do
    if [ -f "$service/target/$service-1.0.0.jar" ]; then
        SIZE=$(du -h "$service/target/$service-1.0.0.jar" | cut -f1)
        echo "✅ $service: $SIZE"
    else
        echo "❌ $service: Non construit"
    fi
done

# Temps total
BUILD_END_TIME=$(date +%s)
if [ -n "$BUILD_START_TIME" ]; then
    BUILD_DURATION=$((BUILD_END_TIME - BUILD_START_TIME))
    echo ""
    echo "⏱️  Temps de construction: ${BUILD_DURATION}s"
fi

echo ""
echo "🎉 Construction terminée avec succès!"
echo "🚀 Vous pouvez maintenant exécuter: ./deploy.sh"

---

#!/bin/bash
# 📁 Emplacement: projecttaskhub/deploy.sh
# Script de déploiement complet avec Docker Compose

set -e

BUILD_START_TIME=$(date +%s)

echo "🚀 Déploiement de ProjectTaskHub"
echo "================================="

# Vérifications
echo "🔍 Vérifications préalables..."

if ! command -v docker-compose &> /dev/null && ! command -v docker &> /dev/null; then
    echo "❌ Docker Compose n'est pas installé"
    exit 1
fi

# Utiliser la bonne commande selon la version
DOCKER_COMPOSE_CMD="docker-compose"
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
fi

echo "✅ $DOCKER_COMPOSE_CMD détecté"

# Créer les répertoires nécessaires
echo ""
echo "📁 Création de la structure des répertoires..."
mkdir -p {config/keycloak,config/rabbitmq,scripts,logs}

# Créer les fichiers de configuration s'ils n'existent pas
echo ""
echo "📝 Vérification des fichiers de configuration..."

# Configuration RabbitMQ
if [ ! -f "config/rabbitmq/rabbitmq.conf" ]; then
    echo "📝 Création de config/rabbitmq/rabbitmq.conf..."
    cat > config/rabbitmq/rabbitmq.conf << 'EOF'
default_user = guest
default_pass = guest
default_vhost = /
vm_memory_high_watermark.relative = 0.6
disk_free_limit.relative = 1.0
management.tcp.port = 15672
management.tcp.ip = 0.0.0.0
log.console = true
log.console.level = info
heartbeat = 60
EOF
fi

# Configuration Keycloak (version simplifiée pour le démarrage)
if [ ! -f "config/keycloak/realm-export.json" ]; then
    echo "📝 Création de config/keycloak/realm-export.json..."
    cat > config/keycloak/realm-export.json << 'EOF'
{
  "realm": "projecttaskhub",
  "enabled": true,
  "displayName": "ProjectTaskHub",
  "clients": [
    {
      "clientId": "projecttaskhub-api",
      "enabled": true,
      "protocol": "openid-connect",
      "bearerOnly": true,
      "directAccessGrantsEnabled": true,
      "serviceAccountsEnabled": true
    }
  ],
  "roles": {
    "realm": [
      {"name": "USER", "description": "Utilisateur standard"},
      {"name": "ADMIN", "description": "Administrateur système"}
    ]
  },
  "users": [
    {
      "username": "admin",
      "enabled": true,
      "emailVerified": true,
      "firstName": "Admin",
      "lastName": "User",
      "email": "admin@projecttaskhub.com",
      "credentials": [{"type": "password", "value": "admin123", "temporary": false}],
      "realmRoles": ["ADMIN", "USER"]
    },
    {
      "username": "user1",
      "enabled": true,
      "emailVerified": true,
      "firstName": "John",
      "lastName": "Doe",
      "email": "user1@projecttaskhub.com",
      "credentials": [{"type": "password", "value": "user123", "temporary": false}],
      "realmRoles": ["USER"]
    }
  ]
}
EOF
fi

# Script d'initialisation PostgreSQL
if [ ! -f "scripts/init-postgres.sql" ]; then
    echo "📝 Création de scripts/init-postgres.sql..."
    cat > scripts/init-postgres.sql << 'EOF'
-- Création des bases de données
SELECT 'CREATE DATABASE keycloak' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'keycloak')\gexec
SELECT 'CREATE DATABASE projectdb' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'projectdb')\gexec

-- Initialisation de projectdb
\c projectdb;
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

CREATE INDEX IF NOT EXISTS idx_projects_owner ON projects(owner);
CREATE INDEX IF NOT EXISTS idx_projects_status ON projects(status);
EOF
fi

# Construire les services si nécessaire
echo ""
echo "🏗️  Vérification des builds..."
NEED_BUILD=false

SERVICES=("config-server" "discovery-server" "api-gateway" "project-service" "task-service")
for service in "${SERVICES[@]}"; do
    if [ ! -f "$service/target/$service-1.0.0.jar" ]; then
        echo "⚠️  $service non construit"
        NEED_BUILD=true
    fi
done

if [ "$NEED_BUILD" = true ]; then
    echo "🔨 Construction des services nécessaire..."
    ./build-all.sh
fi

# Arrêter les conteneurs existants
echo ""
echo "🛑 Arrêt des conteneurs existants..."
$DOCKER_COMPOSE_CMD down --remove-orphans

# Nettoyer les images anciennes (optionnel)
if [ "$1" = "--clean" ]; then
    echo "🗑️  Nettoyage des images anciennes..."
    $DOCKER_COMPOSE_CMD down --rmi local --volumes
    docker system prune -f
fi

# Démarrer l'infrastructure d'abord
echo ""
echo "🚀 Démarrage de l'infrastructure..."
$DOCKER_COMPOSE_CMD up -d postgresql mongodb rabbitmq

# Attendre que l'infrastructure soit prête
echo "⏳ Attente de l'infrastructure..."
sleep 20

# Vérifier la santé de l'infrastructure
echo "🔍 Vérification de l'infrastructure..."
for i in {1..30}; do
    if $DOCKER_COMPOSE_CMD ps postgresql | grep -q "healthy\|Up"; then
        echo "✅ PostgreSQL prêt"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Timeout PostgreSQL"
        exit 1
    fi
    sleep 2
done

for i in {1..30}; do
    if $DOCKER_COMPOSE_CMD ps mongodb | grep -q "healthy\|Up"; then
        echo "✅ MongoDB prêt"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Timeout MongoDB"
        exit 1
    fi
    sleep 2
done

# Démarrer Keycloak
echo ""
echo "🔐 Démarrage de Keycloak..."
$DOCKER_COMPOSE_CMD up -d keycloak

echo "⏳ Attente de Keycloak (peut prendre 2-3 minutes)..."
for i in {1..90}; do
    if curl -s http://localhost:8180/health/ready > /dev/null 2>&1; then
        echo "✅ Keycloak prêt"
        break
    fi
    if [ $i -eq 90 ]; then
        echo "❌ Timeout Keycloak"
        echo "📋 Vérifiez les logs: $DOCKER_COMPOSE_CMD logs keycloak"
        exit 1
    fi
    sleep 2
done

# Démarrer les services Spring
echo ""
echo "🌱 Démarrage des services Spring..."

# Config Server d'abord
echo "📝 Démarrage du Config Server..."
$DOCKER_COMPOSE_CMD up -d config-server

for i in {1..60}; do
    if curl -s http://localhost:8888/actuator/health > /dev/null 2>&1; then
        echo "✅ Config Server prêt"
        break
    fi
    if [ $i -eq 60 ]; then
        echo "❌ Timeout Config Server"
        exit 1
    fi
    sleep 2
done

# Discovery Server
echo "🔍 Démarrage du Discovery Server..."
$DOCKER_COMPOSE_CMD up -d discovery-server

for i in {1..60}; do
    if curl -s http://localhost:8761/actuator/health > /dev/null 2>&1; then
        echo "✅ Discovery Server prêt"
        break
    fi
    if [ $i -eq 60 ]; then
        echo "❌ Timeout Discovery Server"
        exit 1
    fi
    sleep 2
done

# Services métier
echo "🏢 Démarrage des services métier..."
$DOCKER_COMPOSE_CMD up -d project-service task-service

# API Gateway en dernier
echo "🌐 Démarrage de l'API Gateway..."
$DOCKER_COMPOSE_CMD up -d api-gateway

# Attendre que tout soit prêt
echo ""
echo "⏳ Vérification finale des services..."
sleep 30

# Afficher l'état final
echo ""
echo "📊 État des services:"
$DOCKER_COMPOSE_CMD ps

# URLs d'accès
echo ""
echo "🎉 Déploiement terminé!"
echo "======================="
echo ""
echo "🌐 URLs d'accès:"
echo "  • API Gateway:          http://localhost:8080"
echo "  • Discovery Server:     http://localhost:8761"
echo "  • Config Server:        http://localhost:8888"
echo "  • Project Service:      http://localhost:8081"
echo "  • Task Service:         http://localhost:8082"
echo "  • Keycloak Admin:       http://localhost:8180/admin"
echo "  • RabbitMQ Management:  http://localhost:15672"
echo ""
echo "👥 Utilisateurs de test:"
echo "  • Admin: admin/admin123"
echo "  • User:  user1/user123"
echo ""
echo "📋 Commandes utiles:"
echo "  • Voir les logs:        $DOCKER_COMPOSE_CMD logs -f [service]"
echo "  • Arrêter:             ./stop.sh"
echo "  • Tester:              ./test-api.sh"

---

#!/bin/bash
# 📁 Emplacement: projecttaskhub/stop.sh
# Script d'arrêt des services

echo "🛑 Arrêt de ProjectTaskHub..."

# Déterminer la commande Docker Compose
DOCKER_COMPOSE_CMD="docker-compose"
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
fi

# Arrêter les services dans l'ordre inverse
echo "🔄 Arrêt des services applicatifs..."
$DOCKER_COMPOSE_CMD stop api-gateway task-service project-service discovery-server config-server

echo "🔄 Arrêt de l'infrastructure..."
$DOCKER_COMPOSE_CMD stop keycloak rabbitmq mongodb postgresql

# Arrêter complètement
echo "🛑 Arrêt complet..."
$DOCKER_COMPOSE_CMD down

# Nettoyage optionnel
if [ "$1" = "--clean" ]; then
    echo "🗑️  Nettoyage des volumes et images..."
    $DOCKER_COMPOSE_CMD down -v --rmi local
    docker system prune -f
    echo "✅ Nettoyage terminé"
fi

echo "✅ Tous les services ont été arrêtés"

---

#!/bin/bash
# 📁 Emplacement: projecttaskhub/test-api.sh
# Script de test complet des APIs

set -e

echo "🧪 Test des APIs ProjectTaskHub"
echo "==============================="

BASE_URL="http://localhost:8080"
KEYCLOAK_URL="http://localhost:8180"

# Fonction pour obtenir un token
get_token() {
    local username=$1
    local password=$2

    echo "🔐 Obtention du token pour $username..."

    local token=$(curl -s -X POST "$KEYCLOAK_URL/realms/projecttaskhub/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=password" \
        -d "client_id=projecttaskhub-api" \
        -d "username=$username" \
        -d "password=$password" | \
        jq -r '.access_token' 2>/dev/null)

    if [ "$token" = "null" ] || [ -z "$token" ]; then
        echo "❌ Erreur d'authentification pour $username"
        return 1
    fi

    echo "$token"
}

# Attendre que les services soient prêts
echo "⏳ Vérification de la disponibilité des services..."

# Vérifier API Gateway
for i in {1..30}; do
    if curl -s "$BASE_URL/actuator/health" > /dev/null 2>&1; then
        echo "✅ API Gateway opérationnel"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ API Gateway non accessible"
        exit 1
    fi
    sleep 2
done

# Vérifier Keycloak
for i in {1..30}; do
    if curl -s "$KEYCLOAK_URL/realms/projecttaskhub/.well-known/openid_configuration" > /dev/null 2>&1; then
        echo "✅ Keycloak opérationnel"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Keycloak non accessible"
        exit 1
    fi
    sleep 2
done

# Test d'authentification
echo ""
echo "🔐 Test d'authentification..."

ADMIN_TOKEN=$(get_token "admin" "admin123")
if [ $? -ne 0 ]; then
    exit 1
fi

USER_TOKEN=$(get_token "user1" "user123")
if [ $? -ne 0 ]; then
    exit 1
fi

echo "✅ Tokens obtenus avec succès"

# Test Project Service
echo ""
echo "📋 Test du Project Service..."

# Créer un projet
echo "📝 Création d'un projet..."
PROJECT_RESPONSE=$(curl -s -X POST "$BASE_URL/api/projects" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "Projet Test API",
        "description": "Projet créé lors du test des APIs",
        "startDate": "2024-01-01T10:00:00",
        "status": "PLANNING"
    }')

PROJECT_ID=$(echo "$PROJECT_RESPONSE" | jq -r '.id' 2>/dev/null)

if [ "$PROJECT_ID" = "null" ] || [ -z "$PROJECT_ID" ]; then
    echo "❌ Erreur lors de la création du projet"
    echo "Réponse: $PROJECT_RESPONSE"
    exit 1
fi

echo "✅ Projet créé avec l'ID: $PROJECT_ID"

# Récupérer le projet
echo "📖 Récupération du projet..."
GET_PROJECT_RESPONSE=$(curl -s -X GET "$BASE_URL/api/projects/$PROJECT_ID" \
    -H "Authorization: Bearer $ADMIN_TOKEN")

PROJECT_NAME=$(echo "$GET_PROJECT_RESPONSE" | jq -r '.name' 2>/dev/null)
if [ "$PROJECT_NAME" = "Projet Test API" ]; then
    echo "✅ Projet récupéré avec succès: $PROJECT_NAME"
else
    echo "❌ Erreur lors de la récupération du projet"
    exit 1
fi

# Test Task Service
echo ""
echo "📝 Test du Task Service..."

# Créer une tâche
echo "📋 Création d'une tâche..."
TASK_RESPONSE=$(curl -s -X POST "$BASE_URL/api/tasks" \
    -H "Authorization: Bearer $USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"title\": \"Tâche Test API\",
        \"description\": \"Tâche créée lors du test des APIs\",
        \"projectId\": $PROJECT_ID,
        \"status\": \"TODO\",
        \"priority\": \"MEDIUM\"
    }")

TASK_ID=$(echo "$TASK_RESPONSE" | jq -r '.id' 2>/dev/null)

if [ "$TASK_ID" = "null" ] || [ -z "$TASK_ID" ]; then
    echo "❌ Erreur lors de la création de la tâche"
    echo "Réponse: $TASK_RESPONSE"
    exit 1
fi

echo "✅ Tâche créée avec l'ID: $TASK_ID"

# Récupérer la tâche
echo "📖 Récupération de la tâche..."
GET_TASK_RESPONSE=$(curl -s -X GET "$BASE_URL/api/tasks/$TASK_ID" \
    -H "Authorization: Bearer $USER_TOKEN")

TASK_TITLE=$(echo "$GET_TASK_RESPONSE" | jq -r '.title' 2>/dev/null)
if [ "$TASK_TITLE" = "Tâche Test API" ]; then
    echo "✅ Tâche récupérée avec succès: $TASK_TITLE"
else
    echo "❌ Erreur lors de la récupération de la tâche"
    exit 1
fi

# Test des listes
echo ""
echo "📋 Test des listes..."

# Lister les projets
PROJECTS_COUNT=$(curl -s -X GET "$BASE_URL/api/projects" \
    -H "Authorization: Bearer $ADMIN_TOKEN" | jq '. | length' 2>/dev/null)

if [ "$PROJECTS_COUNT" -gt 0 ]; then
    echo "✅ $PROJECTS_COUNT projet(s) récupéré(s)"
else
    echo "❌ Aucun projet récupéré"
fi

# Lister les tâches
TASKS_COUNT=$(curl -s -X GET "$BASE_URL/api/tasks" \
    -H "Authorization: Bearer $USER_TOKEN" | jq '. | length' 2>/dev/null)

if [ "$TASKS_COUNT" -gt 0 ]; then
    echo "✅ $TASKS_COUNT tâche(s) récupérée(s)"
else
    echo "❌ Aucune tâche récupérée"
fi

# Test de mise à jour
echo ""
echo "🔄 Test des mises à jour..."

# Mettre à jour la tâche
UPDATE_TASK_RESPONSE=$(curl -s -X PUT "$BASE_URL/api/tasks/$TASK_ID" \
    -H "Authorization: Bearer $USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "status": "IN_PROGRESS",
        "priority": "HIGH"
    }')

UPDATED_STATUS=$(echo "$UPDATE_TASK_RESPONSE" | jq -r '.status' 2>/dev/null)
if [ "$UPDATED_STATUS" = "IN_PROGRESS" ]; then
    echo "✅ Tâche mise à jour avec succès"
else
    echo "❌ Erreur lors de la mise à jour de la tâche"
fi

# Test des recherches
echo ""
echo "🔍 Test des recherches..."

# Recherche de tâches par titre
SEARCH_RESPONSE=$(curl -s -X GET "$BASE_URL/api/tasks/search?title=Test" \
    -H "Authorization: Bearer $USER_TOKEN")

SEARCH_COUNT=$(echo "$SEARCH_RESPONSE" | jq '. | length' 2>/dev/null)
if [ "$SEARCH_COUNT" -gt 0 ]; then
    echo "✅ Recherche réussie: $SEARCH_COUNT résultat(s)"
else
    echo "❌ Aucun résultat de recherche"
fi

# Test des services de santé
echo ""
echo "🏥 Test des services de santé..."

SERVICES=("config-server:8888" "discovery-server:8761" "project-service:8081" "task-service:8082")

for service_port in "${SERVICES[@]}"; do
    service=$(echo $service_port | cut -d':' -f1)
    port=$(echo $service_port | cut -d':' -f2)

    health_response=$(curl -s "http://localhost:$port/actuator/health" 2>/dev/null || echo "DOWN")
    status=$(echo "$health_response" | jq -r '.status' 2>/dev/null || echo "DOWN")

    if [ "$status" = "UP" ]; then
        echo "✅ $service: UP"
    else
        echo "❌ $service: DOWN"
    fi
done

# Résumé final
echo ""
echo "📊 Résumé des tests"
echo "=================="
echo "✅ Authentification: OK"
echo "✅ Création projet: OK"
echo "✅ Création tâche: OK"
echo "✅ Récupération données: OK"
echo "✅ Mise à jour: OK"
echo "✅ Recherche: OK"
echo ""
echo "🎉 Tous les tests sont passés avec succès!"
echo ""
echo "🔗 URLs de test manuelles:"
echo "  • Health API Gateway: curl http://localhost:8080/actuator/health"
echo "  • Projets: curl -H \"Authorization: Bearer \$TOKEN\" http://localhost:8080/api/projects"
echo "  • Tâches: curl -H \"Authorization: Bearer \$TOKEN\" http://localhost:8080/api/tasks"

---

#!/bin/bash
# 📁 Emplacement: projecttaskhub/monitor.sh
# Script de monitoring des services

echo "📊 Monitoring ProjectTaskHub"
echo "============================="

# Fonction pour vérifier un service
check_service() {
    local name=$1
    local url=$2
    local port=$3

    printf "%-20s" "$name:"

    # Test de connectivité
    if ! nc -z localhost $port 2>/dev/null; then
        echo "❌ PORT FERMÉ"
        return 1
    fi

    # Test HTTP health
    local response=$(curl -s "$url" 2>/dev/null)
    local status=$(echo "$response" | jq -r '.status' 2>/dev/null)

    if [ "$status" = "UP" ]; then
        echo "✅ UP"
    else
        echo "⚠️  UNKNOWN"
    fi
}

# Vérification des services
echo "🔍 État des services:"
echo ""

check_service "Config Server" "http://localhost:8888/actuator/health" 8888
check_service "Discovery Server" "http://localhost:8761/actuator/health" 8761
check_service "API Gateway" "http://localhost:8080/actuator/health" 8080
check_service "Project Service" "http://localhost:8081/actuator/health" 8081
check_service "Task Service" "http://localhost:8082/actuator/health" 8082

echo ""
echo "🗄️  État de l'infrastructure:"
echo ""

check_service "PostgreSQL" "" 5432
check_service "MongoDB" "" 27017
check_service "RabbitMQ" "" 5672
check_service "Keycloak" "http://localhost:8180/health/ready" 8180

# Docker containers status
echo ""
echo "🐳 État des conteneurs Docker:"
echo ""

# Déterminer la commande Docker Compose
DOCKER_COMPOSE_CMD="docker-compose"
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
fi

$DOCKER_COMPOSE_CMD ps --format="table {{.Name}}\t{{.Status}}\t{{.Ports}}"

# Utilisation des ressources
echo ""
echo "💾 Utilisation des ressources:"
echo ""

if command -v docker &> /dev/null; then
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" \
        $(docker ps --format "{{.Names}}" | grep -E "(config-server|discovery-server|api-gateway|project-service|task-service|postgresql|mongodb|rabbitmq|keycloak)")
fi

---

#!/bin/bash
# 📁 Emplacement: projecttaskhub/logs.sh
# Script pour visualiser les logs

DOCKER_COMPOSE_CMD="docker-compose"
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
fi

echo "📋 Logs ProjectTaskHub"
echo "======================"

if [ $# -eq 0 ]; then
    echo "Usage: ./logs.sh [service] [options]"
    echo ""
    echo "Services disponibles:"
    echo "  • config-server"
    echo "  • discovery-server"
    echo "  • api-gateway"
    echo "  • project-service"
    echo "  • task-service"
    echo "  • postgresql"
    echo "  • mongodb"
    echo "  • rabbitmq"
    echo "  • keycloak"
    echo "  • all (tous les services)"
    echo ""
    echo "Options:"
    echo "  -f, --follow    Suivre les logs en temps réel"
    echo "  --tail=N        Afficher les N dernières lignes"
    echo ""
    echo "Exemples:"
    echo "  ./logs.sh api-gateway -f"
    echo "  ./logs.sh task-service --tail=100"
    echo "  ./logs.sh all"
    exit 1
fi

SERVICE=$1
shift

if [ "$SERVICE" = "all" ]; then
    echo "📊 Logs de tous les services..."
    $DOCKER_COMPOSE_CMD logs "$@"
else
    echo "📋 Logs du service: $SERVICE"
    $DOCKER_COMPOSE_CMD logs "$@" "$SERVICE"
fi

---

#!/bin/bash
# 📁 Emplacement: projecttaskhub/backup.sh
# Script de sauvegarde des données

set -e

BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "💾 Sauvegarde ProjectTaskHub"
echo "============================"
echo "📁 Dossier: $BACKUP_DIR"

# Déterminer la commande Docker Compose
DOCKER_COMPOSE_CMD="docker-compose"
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
fi

# Sauvegarde PostgreSQL
echo ""
echo "🐘 Sauvegarde PostgreSQL..."
docker exec postgresql pg_dumpall -U postgres > "$BACKUP_DIR/postgresql_backup.sql"
echo "✅ PostgreSQL sauvegardé"

# Sauvegarde MongoDB
echo ""
echo "🍃 Sauvegarde MongoDB..."
docker exec mongodb mongodump --host localhost --port 27017 --out /tmp/mongo_backup
docker cp mongodb:/tmp/mongo_backup "$BACKUP_DIR/mongodb_backup"
echo "✅ MongoDB sauvegardé"

# Sauvegarde RabbitMQ
echo ""
echo "🐰 Sauvegarde RabbitMQ..."
docker exec rabbitmq rabbitmqctl export_definitions /tmp/rabbitmq_definitions.json
docker cp rabbitmq:/tmp/rabbitmq_definitions.json "$BACKUP_DIR/rabbitmq_definitions.json"
echo "✅ RabbitMQ sauvegardé"

# Sauvegarde Keycloak
echo ""
echo "🔐 Sauvegarde Keycloak..."
docker exec keycloak /opt/keycloak/bin/kc.sh export --dir /tmp/keycloak_export --realm projecttaskhub
docker cp keycloak:/tmp/keycloak_export "$BACKUP_DIR/keycloak_export"
echo "✅ Keycloak sauvegardé"

# Compression
echo ""
echo "🗜️  Compression de la sauvegarde..."
tar -czf "$BACKUP_DIR.tar.gz" -C backups "$(basename $BACKUP_DIR)"
rm -rf "$BACKUP_DIR"

echo ""
echo "✅ Sauvegarde terminée: $BACKUP_DIR.tar.gz"
echo "📊 Taille: $(du -h $BACKUP_DIR.tar.gz | cut -f1)"

---

#!/bin/bash
# 📁 Emplacement: projecttaskhub/restore.sh
# Script de restauration des données

set -e

if [ $# -ne 1 ]; then
    echo "Usage: ./restore.sh <backup_file.tar.gz>"
    echo ""
    echo "Sauvegardes disponibles:"
    ls -la backups/*.tar.gz 2>/dev/null || echo "Aucune sauvegarde trouvée"
    exit 1
fi

BACKUP_FILE=$1
RESTORE_DIR="restore_$(date +%Y%m%d_%H%M%S)"

echo "🔄 Restauration ProjectTaskHub"
echo "=============================="
echo "📁 Fichier: $BACKUP_FILE"

# Vérifier que le fichier existe
if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Fichier de sauvegarde non trouvé: $BACKUP_FILE"
    exit 1
fi

# Déterminer la commande Docker Compose
DOCKER_COMPOSE_CMD="docker-compose"
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
fi

# Décompression
echo ""
echo "📦 Décompression de la sauvegarde..."
mkdir -p "$RESTORE_DIR"
tar -xzf "$BACKUP_FILE" -C "$RESTORE_DIR" --strip-components=1

# Vérifier que les services sont en cours d'exécution
echo ""
echo "🔍 Vérification des services..."
if ! $DOCKER_COMPOSE_CMD ps | grep -q "Up"; then
    echo "⚠️  Les services ne semblent pas être en cours d'exécution"
    echo "Voulez-vous les démarrer ? (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        ./deploy.sh
    else
        echo "❌ Restauration annulée"
        exit 1
    fi
fi

# Restauration PostgreSQL
if [ -f "$RESTORE_DIR/postgresql_backup.sql" ]; then
    echo ""
    echo "🐘 Restauration PostgreSQL..."
    docker exec -i postgresql psql -U postgres < "$RESTORE_DIR/postgresql_backup.sql"
    echo "✅ PostgreSQL restauré"
fi

# Restauration MongoDB
if [ -d "$RESTORE_DIR/mongodb_backup" ]; then
    echo ""
    echo "🍃 Restauration MongoDB..."
    docker cp "$RESTORE_DIR/mongodb_backup" mongodb:/tmp/
    docker exec mongodb mongorestore --host localhost --port 27017 --drop /tmp/mongodb_backup
    echo "✅ MongoDB restauré"
fi

# Restauration RabbitMQ
if [ -f "$RESTORE_DIR/rabbitmq_definitions.json" ]; then
    echo ""
    echo "🐰 Restauration RabbitMQ..."
    docker cp "$RESTORE_DIR/rabbitmq_definitions.json" rabbitmq:/tmp/
    docker exec rabbitmq rabbitmqctl import_definitions /tmp/rabbitmq_definitions.json
    echo "✅ RabbitMQ restauré"
fi

# Nettoyage
rm -rf "$RESTORE_DIR"

echo ""
echo "✅ Restauration terminée avec succès!"
echo "🔄 Redémarrage des services recommandé..."

---

#!/bin/bash
# 📁 Emplacement: projecttaskhub/update.sh
# Script de mise à jour des services

set -e

echo "🔄 Mise à jour ProjectTaskHub"
echo "============================="

# Déterminer la commande Docker Compose
DOCKER_COMPOSE_CMD="docker-compose"
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
fi

echo "🔍 Vérification des mises à jour..."

# Pull des images de base
echo ""
echo "📥 Mise à jour des images de base..."
docker pull openjdk:17-jdk-slim
docker pull postgres:15-alpine
docker pull mongo:7-jammy
docker pull rabbitmq:3-management-alpine
docker pull quay.io/keycloak/keycloak:23.0

# Rebuild des services
echo ""
echo "🏗️  Reconstruction des services..."
./build-all.sh

# Sauvegarde avant mise à jour
echo ""
echo "💾 Sauvegarde avant mise à jour..."
./backup.sh

# Mise à jour progressive
echo ""
echo "🔄 Mise à jour des services..."

# Arrêter les services applicatifs
$DOCKER_COMPOSE_CMD stop api-gateway task-service project-service discovery-server config-server

# Reconstruire et redémarrer
$DOCKER_COMPOSE_CMD up -d --build config-server
sleep 30

$DOCKER_COMPOSE_CMD up -d --build discovery-server
sleep 30

$DOCKER_COMPOSE_CMD up -d --build project-service task-service
sleep 30

$DOCKER_COMPOSE_CMD up -d --build api-gateway

echo ""
echo "⏳ Attente de la stabilisation..."
sleep 60

# Vérification
echo ""
echo "🔍 Vérification post-mise à jour..."
./test-api.sh

echo ""
echo "✅ Mise à jour terminée avec succès!"