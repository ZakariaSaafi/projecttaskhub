package com.projecttaskhub.task_service.service;


import com.projecttaskhub.shareddto.dto.TaskDTO;
import com.projecttaskhub.shareddto.dto.TaskPriority;
import com.projecttaskhub.shareddto.dto.TaskStatus;
import com.projecttaskhub.task_service.cqrs.handler.TaskQueryHandler;
import com.projecttaskhub.task_service.cqrs.query.*;
import com.projecttaskhub.task_service.entity.Task;
import com.projecttaskhub.task_service.mapper.TaskMapper;
import com.projecttaskhub.task_service.repository.TaskRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
@Transactional(readOnly = true)
public class TaskQueryService {

    private final TaskQueryHandler queryHandler;
    private final TaskRepository taskRepository;
    private final TaskMapper taskMapper;

    public TaskDTO getTaskById(String id) {
        GetTaskByIdQuery query = GetTaskByIdQuery.builder()
                .id(id)
                .build();
        return queryHandler.handle(query);
    }

    public List<TaskDTO> getTasksByProject(Long projectId) {
        GetTasksByProjectQuery query = GetTasksByProjectQuery.builder()
                .projectId(projectId)
                .build();
        return queryHandler.handle(query);
    }

    public List<TaskDTO> getTasksByAssignee(String assignedTo) {
        GetTasksByAssigneeQuery query = GetTasksByAssigneeQuery.builder()
                .assignedTo(assignedTo)
                .build();
        return queryHandler.handle(query);
    }

    public List<TaskDTO> getTasksByStatus(TaskStatus status) {
        GetTasksByStatusQuery query = GetTasksByStatusQuery.builder()
                .status(status)
                .build();
        return queryHandler.handle(query);
    }

    public List<TaskDTO> getAllTasks() {
        GetAllTasksQuery query = GetAllTasksQuery.builder().build();
        return queryHandler.handle(query);
    }

    // Méthodes additionnelles qui n'utilisent pas CQRS (accès direct au repository)
    public Page<TaskDTO> getTasksPaginated(Pageable pageable) {
        log.info("Service: Récupération des tâches paginées");
        Page<Task> tasks = taskRepository.findAll(pageable);
        return tasks.map(taskMapper::toDto);
    }

    public List<TaskDTO> getTasksByPriority(TaskPriority priority) {
        log.info("Service: Récupération des tâches par priorité: {}", priority);
        List<Task> tasks = taskRepository.findByPriority(priority);
        return taskMapper.toDtoList(tasks);
    }

    public List<TaskDTO> searchTasksByTitle(String title) {
        log.info("Service: Recherche de tâches par titre: {}", title);
        List<Task> tasks = taskRepository.findByTitleContainingIgnoreCase(title);
        return taskMapper.toDtoList(tasks);
    }

    public List<TaskDTO> getTasksDueBetween(LocalDateTime start, LocalDateTime end) {
        log.info("Service: Récupération des tâches dues entre {} et {}", start, end);
        List<Task> tasks = taskRepository.findTasksDueBetween(start, end);
        return taskMapper.toDtoList(tasks);
    }

    public long countTasksByProject(Long projectId) {
        log.info("Service: Comptage des tâches pour le projet: {}", projectId);
        return taskRepository.countByProjectId(projectId);
    }

    public long countTasksByAssignee(String assignedTo) {
        log.info("Service: Comptage des tâches pour l'assigné: {}", assignedTo);
        return taskRepository.countByAssignedTo(assignedTo);
    }

    public List<TaskDTO> getTasksByProjectAndStatus(Long projectId, TaskStatus status) {
        log.info("Service: Récupération des tâches pour le projet {} avec le statut {}", projectId, status);
        List<Task> tasks = taskRepository.findByProjectIdAndStatus(projectId, status);
        return taskMapper.toDtoList(tasks);
    }

}
