FROM openjdk:17-jdk-slim

LABEL maintainer="ProjectTaskHub Team"
LABEL service="discovery-server"
LABEL version="1.0.0"

ENV JAVA_OPTS=""
ENV SPRING_PROFILES_ACTIVE="docker"

RUN groupadd -r discoveryservice && useradd -r -g discoveryservice discoveryservice

WORKDIR /app

COPY target/discovery-server-1.0.0.jar app.jar

RUN chown discoveryservice:discoveryservice app.jar

USER discoveryservice

EXPOSE 8761

HEALTHCHECK --interval=30s --timeout=10s --start-period=45s --retries=3 \
  CMD curl -f http://localhost:8761/actuator/health || exit 1

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]