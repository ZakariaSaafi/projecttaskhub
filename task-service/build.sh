#!/bin/bash
# task-service/build.sh - Script de build pour Task Service

echo "🏗️  Construction du Task Service..."

# Vérifier que Maven est installé
if ! command -v mvn &> /dev/null; then
    echo "❌ Maven n'est pas installé"
    exit 1
fi

# Nettoyer les anciens builds
echo "🧹 Nettoyage..."
mvn clean

# Compiler et packager
echo "📦 Compilation et packaging..."
mvn package -DskipTests

# Vérifier que le JAR a été créé
if [ -f "target/task-service-1.0.0.jar" ]; then
    echo "✅ task-service-1.0.0.jar créé avec succès"
    echo "📊 Taille du JAR: $(du -h target/task-service-1.0.0.jar | cut -f1)"
else
    echo "❌ Erreur: JAR non créé"
    exit 1
fi

echo "🎉 Build terminé avec succès!"

---

#!/bin/bash
# task-service/run-local.sh - Script pour exécuter localement

echo "🚀 Démarrage du Task Service en local..."

# Vérifier que le JAR existe
if [ ! -f "target/task-service-1.0.0.jar" ]; then
    echo "❌ JAR non trouvé. Exécutez d'abord ./build.sh"
    exit 1
fi

# Variables d'environnement pour le développement local
export SPRING_PROFILES_ACTIVE=dev
export SPRING_DATA_MONGODB_URI=mongodb://localhost:27017/taskdb
export SPRING_RABBITMQ_HOST=localhost
export SPRING_RABBITMQ_PORT=5672
export SPRING_RABBITMQ_USERNAME=guest
export SPRING_RABBITMQ_PASSWORD=guest
export EUREKA_CLIENT_SERVICE_URL_DEFAULTZONE=http://localhost:8761/eureka/
export SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI=http://localhost:8180/realms/projecttaskhub

echo "🔧 Configuration:"
echo "   - Profil: $SPRING_PROFILES_ACTIVE"
echo "   - MongoDB: $SPRING_DATA_MONGODB_URI"
echo "   - RabbitMQ: $SPRING_RABBITMQ_HOST:$SPRING_RABBITMQ_PORT"
echo "   - Eureka: $EUREKA_CLIENT_SERVICE_URL_DEFAULTZONE"

# Démarrer l'application
echo "🏃‍♂️ Démarrage de l'application..."
java -jar target/task-service-1.0.0.jar

---

#!/bin/bash
# task-service/test.sh - Script de test

echo "🧪 Exécution des tests du Task Service..."

# Tests unitaires
echo "🔬 Tests unitaires..."
mvn test

# Tests d'intégration (nécessite MongoDB et RabbitMQ)
echo "🔗 Tests d'intégration..."
mvn verify -P integration-tests

echo "✅ Tests terminés!"

---

#!/bin/bash
# task-service/docker-build.sh - Script de build Docker

echo "🐳 Construction de l'image Docker pour Task Service..."

# Build Maven d'abord
./build.sh

# Build de l'image Docker
echo "🏗️  Construction de l'image Docker..."
docker build -t projecttaskhub/task-service:latest .

# Vérifier que l'image a été créée
if docker images | grep -q "projecttaskhub/task-service"; then
    echo "✅ Image Docker créée avec succès"
    docker images | grep "projecttaskhub/task-service"
else
    echo "❌ Erreur lors de la création de l'image Docker"
    exit 1
fi

echo "🎉 Image Docker prête!"

---

#!/bin/bash
# task-service/docker-run.sh - Script pour exécuter avec Docker

echo "🐳 Démarrage du Task Service avec Docker..."

# Arrêter le conteneur existant s'il existe
docker stop task-service 2>/dev/null || true
docker rm task-service 2>/dev/null || true

# Démarrer le nouveau conteneur
docker run -d \
  --name task-service \
  --network projecttaskhub-network \
  -p 8082:8082 \
  -e SPRING_DATA_MONGODB_URI=mongodb://mongodb:27017/taskdb \
  -e SPRING_RABBITMQ_HOST=rabbitmq \
  -e SPRING_RABBITMQ_PORT=5672 \
  -e SPRING_RABBITMQ_USERNAME=guest \
  -e SPRING_RABBITMQ_PASSWORD=guest \
  -e EUREKA_CLIENT_SERVICE_URL_DEFAULTZONE=http://discovery-server:8761/eureka/ \
  -e SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI=http://keycloak:8080/realms/projecttaskhub \
  projecttaskhub/task-service:latest

echo "✅ Task Service démarré avec Docker"
echo "📋 Logs: docker logs -f task-service"
echo "🌐 Health: http://localhost:8082/actuator/health"