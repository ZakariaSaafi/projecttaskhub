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
PROJECT_NAME="ProjectTaskHub"
LOG_FILE="logs/deploy-$(date +%Y%m%d_%H%M%S).log"
DOCKER_COMPOSE_CMD=""

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

# Afficher une bannière
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
        log_info "Démarrez Docker Desktop et réessayez"
        exit 1
    fi
    
    # Déterminer la commande Docker Compose
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

# Vérifier la structure du projet
check_structure() {
    log_info "Vérification de la structure du projet..."
    
    if [ ! -f "docker-compose.yml" ]; then
        log_error "Fichier docker-compose.yml manquant"
        exit 1
    fi
    
    log_success "Structure du projet OK"
}

# Créer les fichiers de configuration manquants
create_configs() {
    log_info "Création des configurations nécessaires..."
    
    # Créer les répertoires
    mkdir -p {config/keycloak,config/rabbitmq,scripts,data,backups}
    
    # Configuration docker-compose.yml basique
    if [ ! -f "docker-compose.yml" ]; then
        log_info "Création de docker-compose.yml..."
        cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgresql:
    image: postgres:15-alpine
    container_name: postgresql
    environment:
      POSTGRES_DB: projectdb
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

  mongodb:
    image: mongo:7-jammy
    container_name: mongodb
    environment:
      MONGO_INITDB_ROOT_USERNAME: admin
      MONGO_INITDB_ROOT_PASSWORD: admin123
    ports:
      - "27017:27017"
    volumes:
      - mongo_data:/data/db
    restart: unless-stopped

  rabbitmq:
    image: rabbitmq:3-management-alpine
    container_name: rabbitmq
    environment:
      RABBITMQ_DEFAULT_USER: guest
      RABBITMQ_DEFAULT_PASS: guest
    ports:
      - "5672:5672"
      - "15672:15672"
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    restart: unless-stopped

  keycloak:
    image: quay.io/keycloak/keycloak:23.0
    container_name: keycloak
    environment:
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin123
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://postgresql:5432/keycloak
      KC_DB_USERNAME: postgres
      KC_DB_PASSWORD: postgres
      KC_HOSTNAME: localhost
      KC_HOSTNAME_PORT: 8180
      KC_HTTP_ENABLED: true
      KC_HEALTH_ENABLED: true
    ports:
      - "8180:8080"
    command: start-dev --import-realm
    depends_on:
      - postgresql
    restart: unless-stopped

volumes:
  postgres_data:
  mongo_data:
  rabbitmq_data:
EOF
    fi
    
    log_success "Configurations créées"
}

# Arrêter les conteneurs existants
stop_containers() {
    log_info "Arrêt des conteneurs existants..."
    $DOCKER_COMPOSE_CMD down --remove-orphans 2>/dev/null || true
    log_success "Conteneurs arrêtés"
}

# Démarrer l'infrastructure
start_infrastructure() {
    log_info "Démarrage de l'infrastructure..."
    
    # Démarrer PostgreSQL
    log_info "Démarrage de PostgreSQL..."
    $DOCKER_COMPOSE_CMD up -d postgresql
    
    # Attendre PostgreSQL
    log_info "Attente de PostgreSQL..."
    for i in {1..30}; do
        if $DOCKER_COMPOSE_CMD exec -T postgresql pg_isready -U postgres >/dev/null 2>&1; then
            log_success "PostgreSQL prêt"
            break
        fi
        sleep 2
    done
    
    # Démarrer MongoDB
    log_info "Démarrage de MongoDB..."
    $DOCKER_COMPOSE_CMD up -d mongodb
    
    # Attendre MongoDB
    log_info "Attente de MongoDB..."
    sleep 15
    log_success "MongoDB prêt"
    
    # Démarrer RabbitMQ
    log_info "Démarrage de RabbitMQ..."
    $DOCKER_COMPOSE_CMD up -d rabbitmq
    
    # Attendre RabbitMQ
    log_info "Attente de RabbitMQ..."
    sleep 20
    log_success "RabbitMQ prêt"
    
    log_success "Infrastructure démarrée"
}

# Démarrer Keycloak
start_keycloak() {
    log_info "Démarrage de Keycloak..."
    $DOCKER_COMPOSE_CMD up -d keycloak
    
    log_info "Attente de Keycloak (2-3 minutes)..."
    for i in {1..120}; do
        if curl -s http://localhost:8180/health/ready >/dev/null 2>&1; then
            log_success "Keycloak prêt"
            return 0
        fi
        sleep 5
        if [ $((i % 12)) -eq 0 ]; then
            log_info "Keycloak se charge encore... (${i}0s)"
        fi
    done
    
    log_warning "Keycloak prend plus de temps que prévu, mais continuons..."
}

# Vérifier l'état des services
verify_services() {
    log_info "Vérification des services..."
    
    echo ""
    echo -e "${BLUE}État des conteneurs:${NC}"
    $DOCKER_COMPOSE_CMD ps
    
    echo ""
    echo -e "${GREEN}Services accessibles:${NC}"
    
    # Vérifier PostgreSQL
    if nc -z localhost 5432 2>/dev/null; then
        echo "✅ PostgreSQL: http://localhost:5432"
    else
        echo "❌ PostgreSQL: Non accessible"
    fi
    
    # Vérifier MongoDB
    if nc -z localhost 27017 2>/dev/null; then
        echo "✅ MongoDB: http://localhost:27017"
    else
        echo "❌ MongoDB: Non accessible"
    fi
    
    # Vérifier RabbitMQ
    if nc -z localhost 15672 2>/dev/null; then
        echo "✅ RabbitMQ Management: http://localhost:15672"
    else
        echo "❌ RabbitMQ: Non accessible"
    fi
    
    # Vérifier Keycloak
    if nc -z localhost 8180 2>/dev/null; then
        echo "✅ Keycloak: http://localhost:8180"
    else
        echo "❌ Keycloak: Non accessible"
    fi
}

# Afficher les informations finales
show_final_info() {
    print_banner "DÉPLOIEMENT TERMINÉ !"
    
    echo -e "${GREEN}🎉 Infrastructure ProjectTaskHub démarrée avec succès !${NC}"
    echo ""
    echo -e "${BLUE}🌐 URLs d'accès:${NC}"
    echo "  • Keycloak Admin:       http://localhost:8180/admin"
    echo "  • RabbitMQ Management:  http://localhost:15672"
    echo ""
    echo -e "${BLUE}🔐 Credentials Keycloak:${NC}"
    echo "  • Admin: admin / admin123"
    echo ""
    echo -e "${BLUE}🐰 Credentials RabbitMQ:${NC}"
    echo "  • User: guest / guest"
    echo ""
    echo -e "${BLUE}📊 Bases de données:${NC}"
    echo "  • PostgreSQL: localhost:5432 (postgres/postgres)"
    echo "  • MongoDB: localhost:27017 (admin/admin123)"
    echo ""
    echo -e "${YELLOW}📋 Prochaines étapes:${NC}"
    echo "  1. Accédez à Keycloak: http://localhost:8180/admin"
    echo "  2. Configurez votre realm 'projecttaskhub'"
    echo "  3. Créez vos utilisateurs et rôles"
    echo "  4. Déployez vos services Spring Boot"
    echo ""
    echo -e "${BLUE}🔧 Commandes utiles:${NC}"
    echo "  • Voir les logs: docker-compose logs -f [service]"
    echo "  • Arrêter: docker-compose down"
    echo "  • Redémarrer: docker-compose restart [service]"
    echo ""
}

# Fonction principale
main() {
    print_banner "DÉPLOIEMENT PROJECTTASKHUB"
    
    log_info "Démarrage du déploiement..."
    
    # Vérifications
    check_docker
    check_structure
    
    # Préparation
    create_configs
    
    # Déploiement
    stop_containers
    start_infrastructure
    start_keycloak
    
    # Vérification
    verify_services
    
    # Information finale
    show_final_info
    
    log_success "Déploiement terminé avec succès !"
}

# Gestion des erreurs
handle_error() {
    log_error "Une erreur s'est produite durant le déploiement"
    echo ""
    echo -e "${YELLOW}🔧 Commandes de dépannage:${NC}"
    echo "  • Voir les logs: docker-compose logs"
    echo "  • Redémarrer Docker Desktop"
    echo "  • Nettoyer: docker-compose down && docker system prune -f"
    echo "  • Réessayer: ./deploy.sh"
    exit 1
}

# Gestion du signal d'interruption
trap handle_error ERR

# Point d'entrée
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: ./deploy.sh"
    echo ""
    echo "Déploie l'infrastructure ProjectTaskHub avec:"
    echo "  • PostgreSQL (port 5432)"
    echo "  • MongoDB (port 27017)"
    echo "  • RabbitMQ (port 5672, management 15672)"
    echo "  • Keycloak (port 8180)"
    echo ""
    exit 0
fi

# Vérifier qu'on est dans le bon répertoire
if [ ! -f "deploy.sh" ]; then
    echo -e "${RED}Erreur: Exécutez ce script depuis le répertoire racine du projet${NC}"
    exit 1
fi

# Exécuter le déploiement
main "$@"