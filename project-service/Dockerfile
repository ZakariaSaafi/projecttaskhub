FROM openjdk:17-jdk-slim

LABEL maintainer="ProjectTaskHub Team"
LABEL service="project-service"
LABEL version="1.0.0"

ENV JAVA_OPTS=""
ENV SPRING_PROFILES_ACTIVE="docker"

RUN groupadd -r projectservice && useradd -r -g projectservice projectservice

WORKDIR /app

COPY target/project-service-1.0.0.jar app.jar

RUN chown projectservice:projectservice app.jar

USER projectservice

EXPOSE 8081

HEALTHCHECK --interval=30s --timeout=10s --start-period=45s --retries=3 \
  CMD curl -f http://localhost:8081/actuator/health || exit 1

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]