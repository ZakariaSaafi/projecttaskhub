#!/bin/bash
# =================================================================
# 📁 Emplacement: projecttaskhub/deploy.sh
# 🚀 Script de Déploiement Intelligent ProjectTaskHub
# =================================================================

set -e  # Arrêt immédiat en cas d'erreur

# =================================================================
# CONFIGURATION ET VARIABLES
# =================================================================

# Couleurs pour l'affichage
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Configuration par défaut
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_NAME="ProjectTaskHub"
readonly COMPOSE_PROJECT_NAME="projecttaskhub"
readonly LOG_FILE="logs/deploy-$(date +%Y%m%d_%H%M%S).log"

# Timeouts (en secondes)
readonly INFRASTRUCTURE_TIMEOUT=120
readonly SERVICE_TIMEOUT=180
readonly HEALTH_CHECK_TIMEOUT=300
readonly KEYCLOAK_TIMEOUT=300

# Services et leurs ports
declare -A SERVICES=(
    ["postgresql"]="5432"
    ["mongodb"]="27017"
    ["rabbitmq"]="5672"
    ["keycloak"]="8180"
    ["config-server"]="8888"
    ["discovery-server"]="8761"
    ["project-service"]="8081"
    ["task-service"]="8082"
    ["api-gateway"]="8080"
)

# Ordre de démarrage des services
readonly INFRASTRUCTURE_SERVICES=("postgresql" "mongodb" "rabbitmq")
readonly KEYCLOAK_SERVICES=("keycloak")
readonly SPRING_SERVICES=("config-server" "discovery-server" "project-service" "task-service" "api-gateway")

# Variables globales
DOCKER_COMPOSE_CMD=""
DEPLOYMENT_START_TIME=""
VERBOSE=false
CLEAN_DEPLOY=false
SKIP_TESTS=false
PROD_MODE=false

# =================================================================
# FONCTIONS UTILITAIRES
# =================================================================

# Fonction d'affichage avec couleurs et timestamps
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} ${timestamp} - $message" | tee -a "$LOG_FILE"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} ${timestamp} - $message" | tee -a "$LOG_FILE"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} ${timestamp} - $message" | tee -a "$LOG_FILE"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} ${timestamp} - $message" | tee -a "$LOG_FILE"
            ;;
        "DEBUG")
            if [ "$VERBOSE" = true ]; then
                echo -e "${PURPLE}[DEBUG]${NC} ${timestamp} - $message" | tee -a "$LOG_FILE"
            fi
            ;;
        "STEP")
            echo -e "${CYAN}[STEP]${NC} ${timestamp} - $message" | tee -a "$LOG_FILE"
            ;;
    esac
}

# Fonction pour afficher une bannière
print_banner() {
    local message="$1"
    local width=80
    local padding=$(( (width - ${#message}) / 2 ))

    echo ""
    echo -e "${CYAN}$(printf '=%.0s' $(seq 1 $width))${NC}"
    echo -e "${CYAN}$(printf '%*s' $padding '')${message}$(printf '%*s' $padding '')${NC}"
    echo -e "${CYAN}$(printf '=%.0s' $(seq 1 $width))${NC}"
    echo ""
}

# Fonction pour afficher l'aide
show_help() {
    cat << EOF
🚀 Script de Déploiement ProjectTaskHub

USAGE:
    ./deploy.sh [OPTIONS]

OPTIONS:
    -h, --help          Afficher cette aide
    -v, --verbose       Mode verbeux (logs détaillés)
    -c, --clean         Nettoyage complet avant déploiement
    -s, --skip-tests    Ignorer les tests automatiques
    -p, --production    Mode production (optimisations)
    --no-build          Ne pas reconstruire les services
    --only-infra        Démarrer seulement l'infrastructure
    --only-services     Démarrer seulement les services Spring

EXEMPLES:
    ./deploy.sh                    # Déploiement standard
    ./deploy.sh -v -c              # Déploiement verbeux avec nettoyage
    ./deploy.sh -p                 # Déploiement production
    ./deploy.sh --only-infra       # Infrastructure seulement

VARIABLES D'ENVIRONNEMENT:
    COMPOSE_PROJECT_NAME           Nom du projet Docker Compose
    DOCKER_BUILDKIT               Active le mode BuildKit

Pour plus d'informations, consultez README.md
EOF
}

# Fonction de nettoyage en cas d'interruption
cleanup() {
    local exit_code=$?
    log "WARNING" "Interruption détectée, nettoyage en cours..."

    if [ -n "$DEPLOYMENT_START_TIME" ]; then
        local duration=$(($(date +%s) - DEPLOYMENT_START_TIME))
        log "INFO" "Durée avant interruption: ${duration}s"
    fi

    # Sauvegarder les logs des conteneurs en cas d'erreur
    if [ $exit_code -ne 0 ]; then
        log "ERROR" "Déploiement échoué, sauvegarde des logs..."
        mkdir -p "logs/failed-deployment-$(date +%Y%m%d_%H%M%S)"
        for service in "${!SERVICES[@]}"; do
            $DOCKER_COMPOSE_CMD logs "$service" > "logs/failed-deployment-$(date +%Y%m%d_%H%M%S)/${service}.log" 2>/dev/null || true
        done
    fi

    exit $exit_code
}

# =================================================================
# FONCTIONS DE VÉRIFICATION
# =================================================================

# Vérifier les prérequis système
check_prerequisites() {
    log "STEP" "Vérification des prérequis système..."

    local errors=0

    # Vérifier Docker
    if ! command -v docker &> /dev/null; then
        log "ERROR" "Docker n'est pas installé"
        ((errors++))
    elif ! docker info > /dev/null 2>&1; then
        log "ERROR" "Docker n'est pas en cours d'exécution"
        ((errors++))
    else
        local docker_version=$(docker --version | awk '{print $3}' | cut -d',' -f1)
        log "SUCCESS" "Docker $docker_version opérationnel"
    fi

    # Vérifier Docker Compose
    if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker-compose"
        local compose_version=$(docker-compose --version | awk '{print $3}' | cut -d',' -f1)
        log "SUCCESS" "Docker Compose $compose_version détecté"
    elif command -v docker &> /dev/null && docker compose version &> /dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker compose"
        local compose_version=$(docker compose version --short)
        log "SUCCESS" "Docker Compose Plugin $compose_version détecté"
    else
        log "ERROR" "Docker Compose non disponible"
        ((errors++))
    fi

    # Vérifier l'espace disque
    local available_space=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available_space" -lt 5 ]; then
        log "WARNING" "Espace disque faible: ${available_space}GB (recommandé: 5GB+)"
    else
        log "SUCCESS" "Espace disque suffisant: ${available_space}GB"
    fi

    # Vérifier la mémoire
    if command -v free &> /dev/null; then
        local available_memory=$(free -m | awk 'NR==2{printf "%.1f", $7/1024}')
        if (( $(echo "$available_memory < 2.0" | bc -l) )); then
            log "WARNING" "Mémoire disponible faible: ${available_memory}GB (recommandé: 2GB+)"
        else
            log "SUCCESS" "Mémoire disponible: ${available_memory}GB"
        fi
    fi

    # Vérifier les ports requis
    check_ports

    if [ $errors -gt 0 ]; then
        log "ERROR" "Vérification des prérequis échouée ($errors erreurs)"
        exit 1
    fi

    log "SUCCESS" "Tous les prérequis sont satisfaits"
}

# Vérifier la disponibilité des ports
check_ports() {
    log "DEBUG" "Vérification des ports requis..."

    local ports_in_use=()
    local critical_ports=()

    for service in "${!SERVICES[@]}"; do
        local port="${SERVICES[$service]}"
        if command -v lsof &> /dev/null; then
            if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
                local process=$(lsof -Pi :$port -sTCP:LISTEN | tail -n 1 | awk '{print $1}' || echo "unknown")
                ports_in_use+=("$port:$process")

                # Vérifier si c'est notre propre conteneur
                if ! $DOCKER_COMPOSE_CMD ps | grep -q "$service.*:$port->"; then
                    critical_ports+=("$port")
                fi
            fi
        elif command -v netstat &> /dev/null; then
            if netstat -tuln 2>/dev/null | grep ":$port " > /dev/null; then
                ports_in_use+=("$port")
            fi
        fi
    done

    if [ ${#ports_in_use[@]} -gt 0 ]; then
        log "WARNING" "Ports utilisés: ${ports_in_use[*]}"
        if [ ${#critical_ports[@]} -gt 0 ]; then
            log "ERROR" "Ports critiques bloqués: ${critical_ports[*]}"
            log "INFO" "Arrêtez les processus utilisant ces ports ou utilisez --clean"
            return 1
        fi
    else
        log "SUCCESS" "Tous les ports requis sont disponibles"
    fi
}

# Vérifier la structure du projet
check_project_structure() {
    log "STEP" "Vérification de la structure du projet..."

    local missing_files=()

    # Fichiers essentiels
    local essential_files=("docker-compose.yml" "pom.xml")
    for file in "${essential_files[@]}"; do
        if [ ! -f "$file" ]; then
            missing_files+=("$file")
        fi
    done

    # Services requis
    local required_services=("config-server" "discovery-server" "api-gateway" "project-service" "task-service")
    for service in "${required_services[@]}"; do
        if [ ! -d "$service" ]; then
            missing_files+=("$service/")
        elif [ ! -f "$service/pom.xml" ]; then
            missing_files+=("$service/pom.xml")
        fi
    done

    if [ ${#missing_files[@]} -gt 0 ]; then
        log "ERROR" "Fichiers/dossiers manquants: ${missing_files[*]}"
        log "INFO" "Exécutez d'abord ./install.sh pour créer la structure"
        exit 1
    fi

    log "SUCCESS" "Structure du projet validée"
}

# =================================================================
# FONCTIONS DE CONSTRUCTION
# =================================================================

# Construire les services si nécessaire
build_services() {
    log "STEP" "Vérification des builds..."

    local need_build=false
    local missing_jars=()

    # Vérifier si tous les JAR existent
    for service in "${SPRING_SERVICES[@]}"; do
        local jar_file="${service}/target/${service}-1.0.0.jar"
        if [ ! -f "$jar_file" ]; then
            missing_jars+=("$service")
            need_build=true
        else
            local jar_age=$(stat -c %Y "$jar_file" 2>/dev/null || echo 0)
            local pom_age=$(stat -c %Y "${service}/pom.xml" 2>/dev/null || echo 0)
            if [ $pom_age -gt $jar_age ]; then
                log "DEBUG" "$service: POM plus récent que JAR, rebuild nécessaire"
                need_build=true
            fi
        fi
    done

    if [ "$need_build" = true ]; then
        if [ ${#missing_jars[@]} -gt 0 ]; then
            log "INFO" "Services manquants: ${missing_jars[*]}"
        fi

        log "INFO" "Construction des services nécessaire..."

        if [ -f "./build-all.sh" ] && [ -x "./build-all.sh" ]; then
            log "INFO" "Exécution de build-all.sh..."
            if ./build-all.sh; then
                log "SUCCESS" "Construction réussie"
            else
                log "ERROR" "Échec de la construction"
                exit 1
            fi
        else
            log "INFO" "build-all.sh non trouvé, construction manuelle..."
            build_manually
        fi
    else
        log "SUCCESS" "Tous les services sont à jour"
    fi
}

# Construction manuelle avec Maven
build_manually() {
    log "INFO" "Construction manuelle avec Maven..."

    # Construire shared-dto en premier
    if [ -d "shared-dto" ]; then
        log "INFO" "Construction de shared-dto..."
        (cd shared-dto && mvn clean install -DskipTests -q) || {
            log "ERROR" "Échec de la construction de shared-dto"
            exit 1
        }
    fi

    # Construire les services Spring
    for service in "${SPRING_SERVICES[@]}"; do
        if [ -d "$service" ]; then
            log "INFO" "Construction de $service..."
            (cd "$service" && mvn clean package -DskipTests -q) || {
                log "ERROR" "Échec de la construction de $service"
                exit 1
            }
        fi
    done

    log "SUCCESS" "Construction manuelle terminée"
}

# =================================================================
# FONCTIONS DE CONFIGURATION
# =================================================================

# Créer les répertoires et fichiers nécessaires
setup_environment() {
    log "STEP" "Préparation de l'environnement..."

    # Créer les répertoires nécessaires
    local directories=("logs" "backups" "data" "config/keycloak" "config/rabbitmq" "scripts")
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
        log "DEBUG" "Répertoire créé: $dir"
    done

    # Copier les fichiers de configuration s'ils n'existent pas
    setup_configuration_files

    # Configurer les variables d'environnement
    setup_environment_variables

    log "SUCCESS" "Environnement préparé"
}

# Créer les fichiers de configuration manquants
setup_configuration_files() {
    log "DEBUG" "Vérification des fichiers de configuration..."

    # Configuration RabbitMQ
    if [ ! -f "config/rabbitmq/rabbitmq.conf" ]; then
        log "INFO" "Création de la configuration RabbitMQ..."
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

    # Définitions RabbitMQ
    if [ ! -f "config/rabbitmq/definitions.json" ]; then
        log "INFO" "Création des définitions RabbitMQ..."
        cat > config/rabbitmq/definitions.json << 'EOF'
{
  "rabbit_version": "3.12.0",
  "users": [{"name": "guest", "password_hash": "IbqltCs/vIr2gBl4BVLWBOyIJe68eKx1JmqOzwOEooNPowNm", "hashing_algorithm": "rabbit_password_hashing_sha256", "tags": "administrator"}],
  "vhosts": [{"name": "/"}],
  "permissions": [{"user": "guest", "vhost": "/", "configure": ".*", "write": ".*", "read": ".*"}],
  "queues": [
    {"name": "project.events.queue", "vhost": "/", "durable": true, "auto_delete": false},
    {"name": "task.events.queue", "vhost": "/", "durable": true, "auto_delete": false},
    {"name": "project.events.consumer.queue", "vhost": "/", "durable": true, "auto_delete": false}
  ],
  "exchanges": [
    {"name": "project.exchange", "vhost": "/", "type": "topic", "durable": true, "auto_delete": false},
    {"name": "task.exchange", "vhost": "/", "type": "topic", "durable": true, "auto_delete": false}
  ],
  "bindings": [
    {"source": "project.exchange", "destination": "project.events.queue", "destination_type": "queue", "routing_key": "project.events"},
    {"source": "project.exchange", "destination": "project.events.consumer.queue", "destination_type": "queue", "routing_key": "project.events"},
    {"source": "task.exchange", "destination": "task.events.queue", "destination_type": "queue", "routing_key": "task.events"}
  ]
}
EOF
    fi

    # Configuration Keycloak simplifiée
    if [ ! -f "config/keycloak/realm-export.json" ]; then
        log "INFO" "Création de la configuration Keycloak..."
        create_keycloak_config
    fi

    # Script d'initialisation PostgreSQL
    if [ ! -f "scripts/init-postgres.sql" ]; then
        log "INFO" "Création du script d'initialisation PostgreSQL..."
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

-- Données de test
INSERT INTO projects (name, description, start_date, status, owner)
VALUES
    ('Projet Demo', 'Projet de démonstration', CURRENT_TIMESTAMP, 'PLANNING', 'admin'),
    ('Projet Test', 'Projet de test', CURRENT_TIMESTAMP, 'IN_PROGRESS', 'user1')
ON CONFLICT DO NOTHING;
EOF
    fi
}

# Créer la configuration Keycloak
create_keycloak_config() {
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
      "serviceAccountsEnabled": true,
      "standardFlowEnabled": true,
      "redirectUris": ["*"],
      "webOrigins": ["*"]
    },
    {
      "clientId": "projecttaskhub-frontend",
      "enabled": true,
      "protocol": "openid-connect",
      "publicClient": true,
      "standardFlowEnabled": true,
      "directAccessGrantsEnabled": true,
      "redirectUris": ["http://localhost:3000/*", "http://localhost:8080/*"],
      "webOrigins": ["http://localhost:3000", "http://localhost:8080"]
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
    },
    {
      "username": "user2",
      "enabled": true,
      "emailVerified": true,
      "firstName": "Jane",
      "lastName": "Smith",
      "email": "user2@projecttaskhub.com",
      "credentials": [{"type": "password", "value": "user123", "temporary": false}],
      "realmRoles": ["USER"]
    }
  ]
}
EOF
}

# Configurer les variables d'environnement
setup_environment_variables() {
    log "DEBUG" "Configuration des variables d'environnement..."

    # Exporter les variables pour Docker Compose
    export COMPOSE_PROJECT_NAME="$COMPOSE_PROJECT_NAME"
    export DOCKER_BUILDKIT=1

    # Mode production
    if [ "$PROD_MODE" = true ]; then
        export SPRING_PROFILES_ACTIVE="prod"
        export JAVA_OPTS="-Xmx1g -Xms512m -XX:+UseG1GC"
        log "INFO" "Mode production activé"
    else
        export SPRING_PROFILES_ACTIVE="dev"
        export JAVA_OPTS="-Xmx512m -Xms256m"
        log "INFO" "Mode développement activé"
    fi

    # Charger le fichier .env s'il existe
    if [ -f ".env" ]; then
        log "DEBUG" "Chargement du fichier .env"
        set -a
        source .env
        set +a
    fi
}

# =================================================================
# FONCTIONS DE DÉPLOIEMENT
# =================================================================

# Arrêter les conteneurs existants
stop_existing_containers() {
    log "STEP" "Arrêt des conteneurs existants..."

    if $DOCKER_COMPOSE_CMD ps -q | grep -q .; then
        log "INFO" "Arrêt des services en cours..."
        $DOCKER_COMPOSE_CMD down --remove-orphans

        if [ "$CLEAN_DEPLOY" = true ]; then
            log "INFO" "Nettoyage complet (volumes et images)..."
            $DOCKER_COMPOSE_CMD down -v --rmi local
            docker system prune -f
        fi
    else
        log "INFO" "Aucun conteneur à arrêter"
    fi

    log "SUCCESS" "Conteneurs arrêtés"
}

# Démarrer l'infrastructure de base
deploy_infrastructure() {
    log "STEP" "Démarrage de l'infrastructure..."

    # Démarrer PostgreSQL, MongoDB, RabbitMQ
    for service in "${INFRASTRUCTURE_SERVICES[@]}"; do
        log "INFO" "Démarrage de $service..."
        $DOCKER_COMPOSE_CMD up -d "$service"
    done

    # Attendre que l'infrastructure soit prête
    wait_for_infrastructure

    log "SUCCESS" "Infrastructure démarrée"
}

# Attendre que l'infrastructure soit prête
wait_for_infrastructure() {
    log "INFO" "Attente de la stabilisation de l'infrastructure..."

    local start_time=$(date +%s)
    local timeout=$INFRASTRUCTURE_TIMEOUT

    # Attendre PostgreSQL
    wait_for_service "postgresql" "$timeout" "pg_isready -U postgres"

    # Attendre MongoDB
    wait_for_service "mongodb" "$timeout" "mongosh --eval \"db.adminCommand('ping')\""

    # Attendre RabbitMQ
    wait_for_service "rabbitmq" "$timeout" "rabbitmq-diagnostics ping"

    local duration=$(($(date +%s) - start_time))
    log "SUCCESS" "Infrastructure prête en ${duration}s"
}

# Démarrer Keycloak
deploy_keycloak() {
    log "STEP" "Démarrage de Keycloak..."

    $DOCKER_COMPOSE_CMD up -d keycloak

    # Attendre Keycloak (peut prendre du temps)
    wait_for_keycloak

    log "SUCCESS" "Keycloak démarré"
}

# Attendre que Keycloak soit prêt
wait_for_keycloak() {
    log "INFO" "Attente de Keycloak (peut prendre 2-3 minutes)..."

    local start_time=$(date +%s)
    local timeout=$KEYCLOAK_TIMEOUT
    local check_interval=10

    while [ $(($(date +%s) - start_time)) -lt $timeout ]; do
        if curl -s http://localhost:8180/health/ready > /dev/null 2>&1; then
            local duration=$(($(date +%s) - start_time))
            log "SUCCESS" "Keycloak prêt en ${duration}s"
            return 0
        fi

        local elapsed=$(($(date +%s) - start_time))
        log "DEBUG" "Keycloak non prêt après ${elapsed}s, nouvelle tentative..."
        sleep $check_interval
    done

    log "ERROR" "Timeout: Keycloak non prêt après ${timeout}s"
    log "INFO" "Vérifiez les logs: $DOCKER_COMPOSE_CMD logs keycloak"
    return 1
}

# Démarrer les services Spring
deploy_spring_services() {
    log "STEP" "Démarrage des services Spring..."

    # Config Server en premier
    log "INFO" "Démarrage du Config Server..."
    $DOCKER_COMPOSE_CMD up -d config-server
    wait_for_service_health "config-server" 8888

    # Discovery Server
    log "INFO" "Démarrage du Discovery Server..."
    $DOCKER_COMPOSE_CMD up -d discovery-server
    wait_for_service_health "discovery-server" 8761

    # Services métier en parallèle
    log "INFO" "Démarrage des services métier..."
    $DOCKER_COMPOSE_CMD up -d project-service task-service

    # Attendre les services métier
    wait_for_service_health "project-service" 8081
    wait_for_service_health "task-service" 8082

    # API Gateway en dernier
    log "INFO" "Démarrage de l'API Gateway..."
    $DOCKER_COMPOSE_CMD up -d api-gateway
    wait_for_service_health "api-gateway" 8080

    log "SUCCESS" "Services Spring démarrés"
}

# Attendre qu'un service soit prêt
wait_for_service() {
    local service_name=$1
    local timeout=${2:-60}
    local health_command=${3:-"echo 'ready'"}

    log "DEBUG" "Attente de $service_name..."

    local start_time=$(date +%s)
    local check_interval=5

    while [ $(($(date +%s) - start_time)) -lt $timeout ]; do
        if $DOCKER_COMPOSE_CMD exec -T "$service_name" sh -c "$health_command" > /dev/null 2>&1; then
            local duration=$(($(date +%s) - start_time))
            log "SUCCESS" "$service_name prêt en ${duration}s"
            return 0
        fi

        sleep $check_interval
    done

    log "ERROR" "Timeout: $service_name non prêt après ${timeout}s"
    return 1
}

# Attendre qu'un service Spring soit prêt via health endpoint
wait_for_service_health() {
    local service_name=$1
    local port=$2
    local timeout=${3:-$SERVICE_TIMEOUT}

    log "DEBUG" "Attente de $service_name (health check)..."

    local start_time=$(date +%s)
    local check_interval=10
    local health_url="http://localhost:$port/actuator/health"

    while [ $(($(date +%s) - start_time)) -lt $timeout ]; do
        if curl -s "$health_url" | grep -q '"status":"UP"'; then
            local duration=$(($(date +%s) - start_time))
            log "SUCCESS" "$service_name prêt en ${duration}s"
            return 0
        fi