FROM openjdk:17-jdk-slim

LABEL maintainer="ProjectTaskHub Team"
LABEL service="api-gateway"
LABEL version="1.0.0"

ENV JAVA_OPTS=""
ENV SPRING_PROFILES_ACTIVE="docker"

RUN groupadd -r gatewayservice && useradd -r -g gatewayservice gatewayservice

WORKDIR /app

COPY target/api-gateway-1.0.0.jar app.jar

RUN chown gatewayservice:gatewayservice app.jar

USER gatewayservice

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]