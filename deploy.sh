#!/bin/bash
# =================================================================
# 🚀 Script de Déploiement ProjectTaskHub - Version Simplifiée
# =================================================================

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables
DOCKER_COMPOSE_CMD=""
LOG_FILE="logs/deploy-$(date +%Y%m%d_%H%M%S).log"

# Créer le répertoire logs
mkdir -p logs

# Fonctions d'affichage
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_banner() {
    echo ""
    echo -e "${BLUE}===============================================${NC}"
    echo -e "${BLUE} $1 ${NC}"
    echo -e "${BLUE}===============================================${NC}"
    echo ""
}

# Vérifier Docker
check_docker() {
    log_info "Vérification de Docker..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker n'est pas installé"
        exit 1
    fi
    
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker n'est pas en cours d'exécution"
        exit 1
    fi
    
    if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker-compose"
    elif docker compose version &> /dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker compose"
    else
        log_error "Docker Compose non disponible"
        exit 1
    fi
    
    log_success "Docker opérationnel avec $DOCKER_COMPOSE_CMD"
}

# Vérifier les JAR files
check_jar_files() {
    log_info "Vérification des fichiers JAR..."
    
    local missing_jars=()
    local services=("config-server" "discovery-server" "api-gateway" "project-service" "task-service")
    
    for service in "${services[@]}"; do
        local jar_file="${service}/target/${service}-1.0.0.jar"
        if [ ! -f "$jar_file" ]; then
            missing_jars+=("$service")
        fi
    done
    
    if [ ${#missing_jars[@]} -gt 0 ]; then
        log_warning "Services non compilés: ${missing_jars[*]}"
        log_info "Compilation des services manquants..."
        
        # Compiler shared-dto d'abord
        if [ -d "shared-dto" ]; then
            log_info "Compilation de shared-dto..."
            cd shared-dto && mvn clean install -DskipTests -q && cd ..
        fi
        
        # Compiler les services manquants
        for service in "${missing_jars[@]}"; do
            if [ -d "$service" ]; then
                log_info "Compilation de $service..."
                cd "$service" && mvn clean package -DskipTests -q && cd ..
            fi
        done
    else
        log_success "Tous les JAR sont présents"
    fi
}

# Créer les configurations nécessaires
setup_configs() {
    log_info "Configuration de l'environnement..."
    
    # Créer les répertoires
    mkdir -p {config/keycloak,config/rabbitmq,scripts,data,backups}
    
    # Script d'initialisation PostgreSQL
    if [ ! -f "scripts/init-postgres.sh" ]; then
        log_info "Création du script d'initialisation PostgreSQL..."
        cat > scripts/init-postgres.sh << 'EOF'
#!/bin/bash
set -e

echo "🔧 Initialisation des bases de données PostgreSQL..."

create_database() {
    local database=$1
    echo "📊 Création de la base de données: $database"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        SELECT 'CREATE DATABASE $database'
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$database')\gexec
EOSQL
}

create_database "keycloak"
create_database "projectdb"

echo "✅ Bases de données créées avec succès!"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "projectdb" <<-EOSQL
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

    INSERT INTO projects (name, description, start_date, status, owner) 
    VALUES 
        ('Projet Demo', 'Projet de démonstration', CURRENT_TIMESTAMP, 'PLANNING', 'admin'),
        ('Projet Test', 'Projet de test', CURRENT_TIMESTAMP, 'IN_PROGRESS', 'user1')
    ON CONFLICT DO NOTHING;
EOSQL

echo "🎉 Initialisation PostgreSQL terminée!"
EOF
        chmod +x scripts/init-postgres.sh
    fi
    
    # Configuration Keycloak basique
    if [ ! -f "config/keycloak/realm-export.json" ]; then
        log_info "Création de la configuration Keycloak..."
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
    
    log_success "Configuration terminée"
}

# Arrêter les conteneurs existants
stop_containers() {
    log_info "Arrêt des conteneurs existants..."
    $DOCKER_COMPOSE_CMD down --remove-orphans 2>/dev/null || true
    log_success "Conteneurs arrêtés"
}

# Démarrer tous les services
start_all_services() {
    log_info "Démarrage de tous les services..."
    
    # Démarrer tout d'un coup
    $DOCKER_COMPOSE_CMD up -d
    
    log_info "Attente du démarrage des services (cela peut prendre 3-5 minutes)..."
    
    # Attendre les services critiques
    local services=("postgresql:5432" "mongodb:27017" "rabbitmq:5672" "keycloak:8180" "config-server:8888" "discovery-server:8761" "project-service:8081" "task-service:8082" "api-gateway:8080")
    
    for service_port in "${services[@]}"; do
        local service=$(echo $service_port | cut -d':' -f1)
        local port=$(echo $service_port | cut -d':' -f2)
        
        log_info "Attente de $service..."
        for i in {1..60}; do
            if nc -z localhost $port 2>/dev/null; then
                log_success "$service prêt"
                break
            fi
            if [ $i -eq 60 ]; then
                log_warning "$service prend plus de temps que prévu"
            fi
            sleep 5
        done
    done
    
    log_success "Démarrage terminé"
}

# Vérifier l'état des services
verify_services() {
    log_info "Vérification des services..."
    
    echo ""
    echo -e "${BLUE}📊 État des conteneurs:${NC}"
    $DOCKER_COMPOSE_CMD ps
    
    echo ""
    echo -e "${GREEN}🌐 URLs de test:${NC}"
    
    local endpoints=(
        "config-server:8888:/actuator/health"
        "discovery-server:8761:/actuator/health"
        "project-service:8081:/actuator/health"
        "task-service:8082:/actuator/health"
        "api-gateway:8080:/actuator/health"
        "keycloak:8180:/health/ready"
    )
    
    for endpoint in "${endpoints[@]}"; do
        local service=$(echo $endpoint | cut -d':' -f1)
        local port=$(echo $endpoint | cut -d':' -f2 | cut -d'/' -f1)
        local path=$(echo $endpoint | cut -d':' -f2 | cut -d'/' -f2-)
        local url="http://localhost:$port/$path"
        
        if curl -s "$url" > /dev/null 2>&1; then
            echo "✅ $service: $url"
        else
            echo "❌ $service: $url"
        fi
    done
}

# Afficher les informations finales
show_final_info() {
    print_banner "DÉPLOIEMENT TERMINÉ !"
    
    echo -e "${GREEN}🎉 ProjectTaskHub déployé avec succès !${NC}"
    echo ""
    echo -e "${BLUE}🌐 URLs principales:${NC}"
    echo "  • API Gateway:          http://localhost:8080"
    echo "  • Discovery Server:     http://localhost:8761"
    echo "  • Keycloak Admin:       http://localhost:8180/admin"
    echo "  • RabbitMQ Management:  http://localhost:15672"
    echo ""
    echo -e "${BLUE}🔐 Credentials:${NC}"
    echo "  • Keycloak Admin: admin / admin123"
    echo "  • RabbitMQ: guest / guest"
    echo "  • PostgreSQL: postgres / postgres"
    echo "  • MongoDB: admin / admin123"
    echo ""
    echo -e "${BLUE}👥 Utilisateurs de test:${NC}"
    echo "  • Admin: admin / admin123"
    echo "  • User: user1 / user123"
    echo ""
    echo -e "${BLUE}🧪 Test rapide:${NC}"
    echo "  • Health check: curl http://localhost:8080/actuator/health"
    echo "  • Authentification: voir README.md"
    echo ""
    echo -e "${YELLOW}📋 Commandes utiles:${NC}"
    echo "  • Voir les logs: $DOCKER_COMPOSE_CMD logs -f [service]"
    echo "  • Arrêter: $DOCKER_COMPOSE_CMD down"
    echo "  • Redémarrer: $DOCKER_COMPOSE_CMD restart [service]"
    echo ""
}

# Gestion des erreurs
handle_error() {
    log_error "Une erreur s'est produite durant le déploiement"
    echo ""
    echo -e "${YELLOW}🔧 Dépannage:${NC}"
    echo "  • Logs: $DOCKER_COMPOSE_CMD logs"
    echo "  • Redémarrer Docker Desktop"
    echo "  • Nettoyer: $DOCKER_COMPOSE_CMD down && docker system prune -f"
    exit 1
}

# Fonction principale
main() {
    print_banner "DÉPLOIEMENT PROJECTTASKHUB"
    
    log_info "Démarrage du déploiement complet..."
    
    # Vérifications et préparation
    check_docker
    check_jar_files
    setup_configs
    
    # Déploiement
    stop_containers
    start_all_services
    
    # Vérification et rapport
    verify_services
    show_final_info
    
    log_success "Déploiement terminé avec succès !"
}

# Gestion du signal d'erreur
trap handle_error ERR

# Point d'entrée
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: ./deploy.sh"
    echo ""
    echo "Déploie ProjectTaskHub complet avec tous les services:"
    echo "  • Infrastructure: PostgreSQL, MongoDB, RabbitMQ, Keycloak"
    echo "  • Services Spring: Config, Discovery, Gateway, Project, Task"
    echo ""
    exit 0
fi

# Vérifier qu'on est dans le bon répertoire
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}Erreur: Exécutez ce script depuis le répertoire racine du projet${NC}"
    echo "Le fichier docker-compose.yml doit être présent"
    exit 1
fi

# Exécuter le déploiement
main "$@"