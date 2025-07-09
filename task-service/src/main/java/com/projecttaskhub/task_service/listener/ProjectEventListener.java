package com.projecttaskhub.task_service.listener;

import com.projecttaskhub.shareddto.event.ProjectEvent;
import com.projecttaskhub.task_service.repository.TaskRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
@RequiredArgsConstructor
@Slf4j
public class ProjectEventListener {

    private final TaskRepository taskRepository;

    @RabbitListener(queues = "project.events.consumer.queue")
    @Transactional
    public void handleProjectEvent(ProjectEvent event) {
        log.info("Événement projet reçu: {} pour le projet {}",
                event.getEventType(), event.getProjectId());

        try {
            switch (event.getEventType()) {
                case "PROJECT_DELETED":
                    handleProjectDeleted(event);
                    break;
                case "PROJECT_UPDATED":
                    handleProjectUpdated(event);
                    break;
                case "PROJECT_CREATED":
                    handleProjectCreated(event);
                    break;
                default:
                    log.info("Type d'événement non géré: {}", event.getEventType());
            }
        } catch (Exception e) {
            log.error("Erreur lors du traitement de l'événement projet: {}", e.getMessage(), e);
        }
    }

    private void handleProjectDeleted(ProjectEvent event) {
        log.info("Traitement de la suppression du projet: {}", event.getProjectId());

        // Compter les tâches associées avant suppression
        long taskCount = taskRepository.countByProjectId(event.getProjectId());

        if (taskCount > 0) {
            log.info("Suppression de {} tâches associées au projet {}", taskCount, event.getProjectId());
            taskRepository.deleteByProjectId(event.getProjectId());
            log.info("Tâches supprimées avec succès pour le projet {}", event.getProjectId());
        } else {
            log.info("Aucune tâche à supprimer pour le projet {}", event.getProjectId());
        }
    }

    private void handleProjectUpdated(ProjectEvent event) {
        log.info("Traitement de la mise à jour du projet: {}", event.getProjectId());

        // Ici on pourrait implémenter la synchronisation des données du projet
        // Par exemple, mettre à jour des informations dénormalisées dans les tâches
        long taskCount = taskRepository.countByProjectId(event.getProjectId());
        log.info("Le projet {} a été mis à jour. Il contient {} tâches",
                event.getProjectId(), taskCount);
    }

    private void handleProjectCreated(ProjectEvent event) {
        log.info("Nouveau projet créé: {} - {}", event.getProjectId(), event.getProjectName());
        // On pourrait créer des tâches par défaut, envoyer des notifications, etc.
    }
}