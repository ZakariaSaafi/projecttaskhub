#!/bin/bash
# 📁 Emplacement: projecttaskhub/system-check.sh
# Script de vérification système complète avant déploiement

set -e

echo "🔍 Vérification Système ProjectTaskHub"
echo "======================================"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Compteurs
CHECKS_PASSED=0
CHECKS_FAILED=0
WARNINGS=0

# Fonctions d'affichage
check_passed() {
    echo -e "${GREEN}✅ $1${NC}"
    ((CHECKS_PASSED++))
}

check_failed() {
    echo -e "${RED}❌ $1${NC}"
    ((CHECKS_FAILED++))
}

check_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    ((WARNINGS++))
}

check_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Vérification du système d'exploitation
echo ""
echo "🖥️  Système d'exploitation:"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    check_passed "Linux détecté"
    if command -v lsb_release &> /dev/null; then
        DISTRO=$(lsb_release -d | cut -f2)
        check_info "Distribution: $DISTRO"
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    check_passed "macOS détecté"
    MACOS_VERSION=$(sw_vers -productVersion)
    check_info "Version: macOS $MACOS_VERSION"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    check_passed "Windows détecté"
else
    check_failed "Système d'exploitation non supporté: $OSTYPE"
fi

# Vérification des ressources système
echo ""
echo "💾 Ressources système:"

# RAM
if command -v free &> /dev/null; then
    TOTAL_RAM=$(free -m | awk 'NR==2{printf "%.1f", $2/1024}')
    if (( $(echo "$TOTAL_RAM >= 4.0" | bc -l) )); then
        check_passed "RAM: ${TOTAL_RAM}GB (recommandé: 4GB+)"
    else
        check_warning "RAM: ${TOTAL_RAM}GB (recommandé: 4GB+)"
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    TOTAL_RAM=$(system_profiler SPHardwareDataType | grep "Memory:" | awk '{print $2, $3}')
    check_info "RAM: $TOTAL_RAM"
fi

# Espace disque
DISK_USAGE=$(df -h . | awk 'NR==2 {print $4}')
check_info "Espace disque disponible: $DISK_USAGE"

# CPU
if command -v nproc &> /dev/null; then
    CPU_CORES=$(nproc)
    check_info "Cœurs CPU: $CPU_CORES"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    CPU_CORES=$(sysctl -n hw.ncpu)
    check_info "Cœurs CPU: $CPU_CORES"
fi

# Vérification de Java
echo ""
echo "☕ Java:"
if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
    JAVA_MAJOR=$(echo $JAVA_VERSION | cut -d'.' -f1)

    if [ "$JAVA_MAJOR" -ge 17 ]; then
        check_passed "Java $JAVA_VERSION installé"
    else
        check_failed "Java $JAVA_VERSION (requis: 17+)"
    fi

    # Vérifier JAVA_HOME
    if [ -n "$JAVA_HOME" ]; then
        check_passed "JAVA_HOME défini: $JAVA_HOME"
    else
        check_warning "JAVA_HOME non défini"
    fi
else
    check_failed "Java non installé"
fi

# Vérification de Maven
echo ""
echo "🔨 Maven:"
if command -v mvn &> /dev/null; then
    MAVEN_VERSION=$(mvn -version | head -n 1 | awk '{print $3}')
    check_passed "Maven $MAVEN_VERSION installé"

    # Vérifier M2_HOME
    if [ -n "$M2_HOME" ]; then
        check_info "M2_HOME: $M2_HOME"
    fi
else
    check_failed "Maven non installé"
fi

# Vérification de Docker
echo ""
echo "🐳 Docker:"
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | cut -d',' -f1)
    check_passed "Docker $DOCKER_VERSION installé"

    # Vérifier que Docker fonctionne
    if docker info > /dev/null 2>&1; then
        check_passed "Docker démon opérationnel"

        # Vérifier les ressources Docker
        DOCKER_MEMORY=$(docker system info | grep "Total Memory" | awk '{print $3, $4}')
        if [ -n "$DOCKER_MEMORY" ]; then
            check_info "Mémoire Docker: $DOCKER_MEMORY"
        fi
    else
        check_failed "Docker démon non démarré"
    fi
else
    check_failed "Docker non installé"
fi

# Vérification de Docker Compose
echo ""
echo "🐳 Docker Compose:"
if command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version | awk '{print $3}' | cut -d',' -f1)
    check_passed "Docker Compose $COMPOSE_VERSION installé"
elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version | awk '{print $3}')
    check_passed "Docker Compose $COMPOSE_VERSION (plugin) installé"
else
    check_failed "Docker Compose non installé"
fi

# Vérification des ports
echo ""
echo "🌐 Ports requis:"
REQUIRED_PORTS=(8080 8081 8082 8180 8761 8888 5432 27017 5672 15672)
PORTS_OK=0
PORTS_BLOCKED=0

for port in "${REQUIRED_PORTS[@]}"; do
    if command -v lsof &> /dev/null; then
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            PROCESS=$(lsof -Pi :$port -sTCP:LISTEN | tail -n 1 | awk '{print $1}')
            check_warning "Port $port utilisé par $PROCESS"
            ((PORTS_BLOCKED++))
        else
            ((PORTS_OK++))
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -tuln | grep ":$port " > /dev/null; then
            check_warning "Port $port utilisé"
            ((PORTS_BLOCKED++))
        else
            ((PORTS_OK++))
        fi
    fi
done

check_info "$PORTS_OK ports libres, $PORTS_BLOCKED ports utilisés"

# Vérification de la connectivité Internet
echo ""
echo "🌍 Connectivité:"
if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
    check_passed "Connectivité Internet disponible"
else
    check_warning "Problème de connectivité Internet"
fi

# Vérification des outils supplémentaires
echo ""
echo "🔧 Outils supplémentaires:"

# curl
if command -v curl &> /dev/null; then
    check_passed "curl installé"
else
    check_warning "curl non installé (recommandé pour les tests)"
fi

# jq
if command -v jq &> /dev/null; then
    check_passed "jq installé"
else
    check_warning "jq non installé (recommandé pour les tests)"
fi

# git
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version | awk '{print $3}')
    check_passed "Git $GIT_VERSION installé"
else
    check_warning "Git non installé"
fi

# Vérification de la structure du projet
echo ""
echo "📁 Structure du projet:"

if [ -f "pom.xml" ]; then
    check_passed "POM parent trouvé"
else
    check_failed "POM parent manquant"
fi

if [ -f "docker-compose.yml" ]; then
    check_passed "docker-compose.yml trouvé"
else
    check_failed "docker-compose.yml manquant"
fi

# Vérifier les services
SERVICES=("shared-dto" "config-server" "discovery-server" "api-gateway" "project-service" "task-service")
for service in "${SERVICES[@]}"; do
    if [ -d "$service" ]; then
        if [ -f "$service/pom.xml" ]; then
            check_passed "$service: Structure OK"
        else
            check_warning "$service: POM manquant"
        fi
    else
        check_failed "$service: Répertoire manquant"
    fi
done

# Vérification des scripts
echo ""
echo "📜 Scripts de déploiement:"

SCRIPTS=("build-all.sh" "deploy.sh" "stop.sh" "test-api.sh" "monitor.sh")
for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            check_passed "$script: Disponible et exécutable"
        else
            check_warning "$script: Pas exécutable"
        fi
    else
        check_failed "$script: Manquant"
    fi
done

# Résumé final
echo ""
echo "📊 Résumé de la Vérification"
echo "============================"
echo -e "${GREEN}✅ Vérifications réussies: $CHECKS_PASSED${NC}"
if [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Avertissements: $WARNINGS${NC}"
fi
if [ $CHECKS_FAILED -gt 0 ]; then
    echo -e "${RED}❌ Vérifications échouées: $CHECKS_FAILED${NC}"
fi

echo ""
if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 Système prêt pour le déploiement de ProjectTaskHub!${NC}"

    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}💡 Quelques avertissements à considérer, mais le déploiement peut continuer.${NC}"
    fi

    echo ""
    echo "🚀 Prochaines étapes recommandées:"
    echo "1. ./build-all.sh     - Construire les services"
    echo "2. ./deploy.sh        - Déployer l'application"
    echo "3. ./test-api.sh      - Tester les APIs"

    exit 0
else
    echo -e "${RED}⚠️  Système non prêt. Veuillez corriger les erreurs avant de continuer.${NC}"

    echo ""
    echo "🔧 Actions recommandées:"
    if ! command -v java &> /dev/null; then
        echo "• Installer Java 17+"
    fi
    if ! command -v mvn &> /dev/null; then
        echo "• Installer Maven 3.8+"
    fi
    if ! command -v docker &> /dev/null; then
        echo "• Installer Docker"
    fi

    exit 1
fi