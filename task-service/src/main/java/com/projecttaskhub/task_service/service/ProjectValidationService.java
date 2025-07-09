package com.projecttaskhub.task_service.service;

import com.projecttaskhub.shareddto.dto.ProjectDTO;
import com.projecttaskhub.task_service.client.ProjectServiceClient;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
@Slf4j
public class ProjectValidationService {

    private final ProjectServiceClient projectServiceClient;

    public boolean validateProjectExists(Long projectId) {
        try {
            log.info("Validation de l'existence du projet: {}", projectId);
            ProjectDTO project = projectServiceClient.getProject(projectId);
            boolean exists = project != null && project.getId() != null;
            log.info("Projet {} existe: {}", projectId, exists);
            return exists;
        } catch (Exception e) {
            log.error("Erreur lors de la validation du projet {}: {}", projectId, e.getMessage());
            return false;
        }
    }

    public ProjectDTO getProjectDetails(Long projectId) {
        try {
            log.info("Récupération des détails du projet: {}", projectId);
            return projectServiceClient.getProject(projectId);
        } catch (Exception e) {
            log.error("Erreur lors de la récupération du projet {}: {}", projectId, e.getMessage());
            throw new RuntimeException("Impossible de récupérer les détails du projet: " + projectId);
        }
    }
}