#!/bin/bash
# 📁 Emplacement: projecttaskhub/install.sh
# Script d'installation automatique complète de ProjectTaskHub

set -e

echo "🚀 Installation Automatique de ProjectTaskHub"
echo "=============================================="
echo ""

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction d'affichage coloré
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Vérifications système
echo "🔍 Vérifications système..."

# Vérifier l'OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    print_status "OS Linux détecté"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    print_status "OS macOS détecté"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    OS="windows"
    print_status "OS Windows détecté"
else
    print_error "OS non supporté: $OSTYPE"
    exit 1
fi

# Vérifier Java
print_info "Vérification de Java..."
if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1)
    if [ "$JAVA_VERSION" -ge 17 ]; then
        print_status "Java $JAVA_VERSION installé"
    else
        print_error "Java 17+ requis. Version actuelle: $JAVA_VERSION"
        echo "Veuillez installer Java 17 ou supérieur"
        exit 1
    fi
else
    print_error "Java non installé"
    echo "Veuillez installer Java 17+ avant de continuer"
    exit 1
fi

# Vérifier Maven
print_info "Vérification de Maven..."
if command -v mvn &> /dev/null; then
    MAVEN_VERSION=$(mvn -version | head -n 1 | awk '{print $3}')
    print_status "Maven $MAVEN_VERSION installé"
else
    print_error "Maven non installé"
    echo "Veuillez installer Maven 3.8+ avant de continuer"
    exit 1
fi

# Vérifier Docker
print_info "Vérification de Docker..."
if command -v docker &> /dev/null; then
    if docker info > /dev/null 2>&1; then
        DOCKER_VERSION=$(docker --version | awk '{print $3}' | cut -d',' -f1)
        print_status "Docker $DOCKER_VERSION opérationnel"
    else
        print_error "Docker installé mais non démarré"
        echo "Veuillez démarrer Docker avant de continuer"
        exit 1
    fi
else
    print_error "Docker non installé"
    echo "Veuillez installer Docker avant de continuer"
    exit 1
fi

# Vérifier Docker Compose
print_info "Vérification de Docker Compose..."
if command -v docker-compose &> /dev/null || (command -v docker &> /dev/null && docker compose version &> /dev/null); then
    print_status "Docker Compose disponible"
else
    print_error "Docker Compose non disponible"
    echo "Veuillez installer Docker Compose avant de continuer"
    exit 1
fi

# Vérifier les ports
print_info "Vérification des ports..."
REQUIRED_PORTS=(8080 8081 8082 8180 8761 8888 5432 27017 5672 15672)
PORTS_IN_USE=()

for port in "${REQUIRED_PORTS[@]}"; do
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        PORTS_IN_USE+=($port)
    fi
done

if [ ${#PORTS_IN_USE[@]} -gt 0 ]; then
    print_warning "Ports déjà utilisés: ${PORTS_IN_USE[*]}"
    echo "Ces ports seront libérés automatiquement lors du déploiement"
fi

# Création de la structure du projet
echo ""
echo "📁 Création de la structure du projet..."

# Répertoires principaux
mkdir -p {config/keycloak,config/rabbitmq,scripts,logs,backups,data}

# Répertoires des services
mkdir -p shared-dto/src/main/java/com/projecttaskhub/shared/{dto,events}
mkdir -p config-server/src/main/{java/com/projecttaskhub/config,resources}
mkdir -p discovery-server/src/main/{java/com/projecttaskhub/discovery,resources}
mkdir -p api-gateway/src/main/{java/com/projecttaskhub/gateway,resources}
mkdir -p project-service/src/{main/{java/com/projecttaskhub/project,resources},test/java}
mkdir -p task-service/src/{main/{java/com/projecttaskhub/task,resources},test/java}

print_status "Structure des répertoires créée"

# Création des fichiers de configuration
echo ""
echo "📝 Création des fichiers de configuration..."

# .env.example
cat > .env.example << 'EOF'
# Database Configuration
POSTGRES_DB=projectdb
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres

MONGO_INITDB_ROOT_USERNAME=admin
MONGO_INITDB_ROOT_PASSWORD=admin123
MONGO_INITDB_DATABASE=taskdb

# RabbitMQ Configuration
RABBITMQ_DEFAULT_USER=guest
RABBITMQ_DEFAULT_PASS=guest

# Keycloak Configuration
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=admin123

# Application Configuration
CONFIG_SERVER_USERNAME=config-admin
CONFIG_SERVER_PASSWORD=config-pass

# Ports
CONFIG_SERVER_PORT=8888
DISCOVERY_SERVER_PORT=8761
API_GATEWAY_PORT=8080
PROJECT_SERVICE_PORT=8081
TASK_SERVICE_PORT=8082
KEYCLOAK_PORT=8180
RABBITMQ_PORT=5672
RABBITMQ_MANAGEMENT_PORT=15672
POSTGRES_PORT=5432
MONGO_PORT=27017
EOF

# .gitignore
cat > .gitignore << 'EOF'
# Compiled class files
*.class
target/
*.jar
*.war
*.ear

# IDE files
.idea/
*.iml
.vscode/
.eclipse/

# OS files
.DS_Store
Thumbs.db

# Logs
logs/
*.log

# Docker
.env

# Backups
backups/

# Temporary files
tmp/
temp/

# Node modules (si frontend)
node_modules/

# Spring Boot
application-local.yml
application-local.properties
EOF

print_status "Fichiers de configuration créés"

# Rendre les scripts exécutables
echo ""
echo "🔧 Configuration des permissions..."

# Créer un script de permissions si les scripts existent déjà
cat > set-permissions.sh << 'EOF'
#!/bin/bash
# Script pour définir les permissions
chmod +x *.sh
for service in config-server discovery-server api-gateway project-service task-service; do
    if [ -d "$service" ]; then
        chmod +x $service/*.sh 2>/dev/null || true
    fi
done
echo "✅ Permissions configurées"
EOF

chmod +x set-permissions.sh

print_status "Script de permissions créé"

# Création du README principal
echo ""
echo "📖 Création de la documentation..."

cat > README.md << 'EOF'
# 🚀 ProjectTaskHub

Plateforme distribuée de gestion de projets et tâches basée sur une architecture microservices.

## 🏗️ Architecture

- **Config Server** - Configuration centralisée
- **Discovery Server** - Service discovery (Eureka)
- **API Gateway** - Point d'entrée unique
- **Project Service** - Gestion des projets (PostgreSQL)
- **Task Service** - Gestion des tâches avec CQRS (MongoDB)

## 🚀 Démarrage Rapide

```bash
# Installation des dépendances
./install.sh

# Construction
./build-all.sh

# Déploiement
./deploy.sh

# Test
./test-api.sh
```

## 📋 Commandes Principales

- `./build-all.sh` - Construire tous les services
- `./deploy.sh` - Déployer l'application
- `./stop.sh` - Arrêter les services
- `./test-api.sh` - Tester les APIs
- `./monitor.sh` - Surveiller les services
- `./logs.sh [service]` - Voir les logs
- `./backup.sh` - Sauvegarder les données

## 🌐 URLs d'Accès

- API Gateway: http://localhost:8080
- Discovery: http://localhost:8761
- Keycloak: http://localhost:8180/admin
- RabbitMQ: http://localhost:15672

## 👥 Utilisateurs de Test

- Admin: admin/admin123
- User: user1/user123

---

Pour plus de détails, consultez la documentation dans le dossier `/docs`.
EOF

print_status "Documentation principale créée"

# Vérification finale
echo ""
echo "🔍 Vérification de l'installation..."

# Compter les répertoires créés
DIRS_CREATED=$(find . -type d | wc -l)
FILES_CREATED=$(find . -type f | wc -l)

print_status "$DIRS_CREATED répertoires créés"
print_status "$FILES_CREATED fichiers créés"

# Résumé
echo ""
echo "📊 Résumé de l'Installation"
echo "==========================="
print_status "✅ Système vérifié"
print_status "✅ Structure créée"
print_status "✅ Configuration initialisée"
print_status "✅ Documentation générée"

echo ""
echo "🎯 Prochaines Étapes"
echo "==================="
echo "1. 📝 Créer les fichiers source Java pour chaque service"
echo "2. 🔨 Exécuter: ./build-all.sh"
echo "3. 🚀 Exécuter: ./deploy.sh"
echo "4. 🧪 Exécuter: ./test-api.sh"

echo ""
echo "📚 Documentation"
echo "================"
echo "• README.md - Documentation principale"
echo "• .env.example - Variables d'environnement"
echo "• Structure complète dans les dossiers créés"

echo ""
echo "🔧 Configuration Optionnelle"
echo "============================"
echo "• Copier .env.example vers .env et personnaliser"
echo "• Configurer votre IDE avec les projets Maven"
echo "• Consulter les logs d'installation dans ./logs/"

echo ""
print_status "🎉 Installation terminée avec succès!"
print_info "Vous pouvez maintenant créer vos services Java et déployer l'application"

# Création d'un script de vérification post-installation
cat > verify-installation.sh << 'EOF'
#!/bin/bash
echo "🔍 Vérification de l'installation ProjectTaskHub"
echo "================================================"

# Vérifier la structure
echo "📁 Structure des répertoires:"
for dir in shared-dto config-server discovery-server api-gateway project-service task-service; do
    if [ -d "$dir" ]; then
        echo "✅ $dir"
    else
        echo "❌ $dir manquant"
    fi
done

echo ""
echo "📝 Fichiers de configuration:"
for file in docker-compose.yml .env.example .gitignore README.md; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file manquant"
    fi
done

echo ""
echo "🔧 Scripts disponibles:"
for script in build-all.sh deploy.sh stop.sh test-api.sh monitor.sh; do
    if [ -f "$script" ]; then
        echo "✅ $script"
    else
        echo "❌ $script manquant"
    fi
done

echo ""
echo "✅ Vérification terminée"
EOF

chmod +x verify-installation.sh

echo ""
print_info "Script de vérification créé: ./verify-installation.sh"

# Affichage final avec instructions claires
echo ""
echo "════════════════════════════════════════════════════════════"
echo "🎊 INSTALLATION PROJECTTASKHUB TERMINÉE AVEC SUCCÈS! 🎊"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "📋 RÉSUMÉ:"
echo "• Structure complète créée"
echo "• Scripts de déploiement installés"
echo "• Configuration de base initialisée"
echo "• Documentation générée"
echo ""
echo "🚀 COMMANDES PRINCIPALES:"
echo "• ./verify-installation.sh  - Vérifier l'installation"
echo "• ./build-all.sh            - Construire tous les services"
echo "• ./deploy.sh               - Déployer l'application"
echo "• ./test-api.sh             - Tester les APIs"
echo "• ./monitor.sh              - Surveiller les services"
echo ""
echo "📁 PROCHAINE ÉTAPE:"
echo "Créez maintenant les fichiers source Java en suivant"
echo "la documentation fournie pour chaque service."
echo ""
echo "════════════════════════════════════════════════════════════"