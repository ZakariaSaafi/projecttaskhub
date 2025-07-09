package com.projecttaskhub.task_service.cqrs.handler;


import com.projecttaskhub.shareddto.dto.TaskDTO;
import com.projecttaskhub.shareddto.event.TaskEvent;
import com.projecttaskhub.task_service.cqrs.command.CreateTaskCommand;
import com.projecttaskhub.task_service.cqrs.command.DeleteTaskCommand;
import com.projecttaskhub.task_service.cqrs.command.UpdateTaskCommand;
import com.projecttaskhub.task_service.entity.Task;
import com.projecttaskhub.task_service.mapper.TaskMapper;
import com.projecttaskhub.task_service.repository.TaskRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

@Component
@RequiredArgsConstructor
@Slf4j
public class TaskCommandHandler {

    private final TaskRepository taskRepository;
    private final TaskMapper taskMapper;
    private final RabbitTemplate rabbitTemplate;

    @Transactional
    public TaskDTO handle(CreateTaskCommand command) {
        log.info("Traitement de la commande CreateTask: {}", command.getTitle());

        // Vérifier si une tâche avec le même titre existe déjà pour ce projet
        if (taskRepository.existsByProjectIdAndTitle(command.getProjectId(), command.getTitle())) {
            throw new IllegalArgumentException(
                    "Une tâche avec ce titre existe déjà pour ce projet");
        }

        // Créer l'entité Task
        Task task = taskMapper.toEntity(command);
        task.setCreatedAt(LocalDateTime.now());
        task.setUpdatedAt(LocalDateTime.now());

        // Sauvegarder en base
        Task savedTask = taskRepository.save(task);

        // Convertir en DTO
        TaskDTO result = taskMapper.toDto(savedTask);

        // Publier l'événement
        publishTaskEvent("TASK_CREATED", result);

        log.info("Tâche créée avec succès avec l'ID: {}", savedTask.getId());
        return result;
    }

    @Transactional
    public TaskDTO handle(UpdateTaskCommand command) {
        log.info("Traitement de la commande UpdateTask: {}", command.getId());

        // Récupérer la tâche existante
        Task existingTask = taskRepository.findById(command.getId())
                .orElseThrow(() -> new RuntimeException("Tâche non trouvée avec l'ID: " + command.getId()));

        // Mettre à jour les champs non nuls
        if (command.getTitle() != null) {
            existingTask.setTitle(command.getTitle());
        }
        if (command.getDescription() != null) {
            existingTask.setDescription(command.getDescription());
        }
        if (command.getStatus() != null) {
            existingTask.setStatus(command.getStatus());
        }
        if (command.getPriority() != null) {
            existingTask.setPriority(command.getPriority());
        }
        if (command.getAssignedTo() != null) {
            existingTask.setAssignedTo(command.getAssignedTo());
        }
        if (command.getDueDate() != null) {
            existingTask.setDueDate(command.getDueDate());
        }

        existingTask.setUpdatedAt(LocalDateTime.now());

        // Sauvegarder
        Task savedTask = taskRepository.save(existingTask);
        TaskDTO result = taskMapper.toDto(savedTask);

        // Publier l'événement
        publishTaskEvent("TASK_UPDATED", result);

        log.info("Tâche mise à jour avec succès: {}", command.getId());
        return result;
    }

    @Transactional
    public void handle(DeleteTaskCommand command) {
        log.info("Traitement de la commande DeleteTask: {}", command.getId());

        // Récupérer la tâche avant suppression
        Task task = taskRepository.findById(command.getId())
                .orElseThrow(() -> new RuntimeException("Tâche non trouvée avec l'ID: " + command.getId()));

        TaskDTO taskDTO = taskMapper.toDto(task);

        // Supprimer la tâche
        taskRepository.delete(task);

        // Publier l'événement
        publishTaskEvent("TASK_DELETED", taskDTO);

        log.info("Tâche supprimée avec succès: {}", command.getId());
    }

    private void publishTaskEvent(String eventType, TaskDTO taskDTO) {
        try {
            TaskEvent event = TaskEvent.builder()
                    .eventType(eventType)
                    .taskId(taskDTO.getId())
                    .projectId(taskDTO.getProjectId())
                    .taskTitle(taskDTO.getTitle())
                    .eventData(taskDTO.toString())
                    .timestamp(LocalDateTime.now())
                    .build();

            rabbitTemplate.convertAndSend("task.exchange", "task.events", event);
            log.info("Événement publié: {} pour la tâche {}", eventType, taskDTO.getId());
        } catch (Exception e) {
            log.error("Erreur lors de la publication de l'événement: {}", e.getMessage(), e);
        }
    }
}