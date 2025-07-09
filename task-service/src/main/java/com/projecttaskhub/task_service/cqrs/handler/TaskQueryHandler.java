package com.projecttaskhub.task_service.cqrs.handler;

import com.projecttaskhub.shareddto.dto.TaskDTO;
import com.projecttaskhub.task_service.cqrs.query.*;
import com.projecttaskhub.task_service.entity.Task;
import com.projecttaskhub.task_service.mapper.TaskMapper;
import com.projecttaskhub.task_service.repository.TaskRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Component
@RequiredArgsConstructor
@Slf4j
@Transactional(readOnly = true)
public class TaskQueryHandler {

    private final TaskRepository taskRepository;
    private final TaskMapper taskMapper;

    public TaskDTO handle(GetTaskByIdQuery query) {
        log.info("Traitement de la requête GetTaskById: {}", query.getId());

        Task task = taskRepository.findById(query.getId())
                .orElseThrow(() -> new RuntimeException("Tâche non trouvée avec l'ID: " + query.getId()));

        return taskMapper.toDto(task);
    }

    public List<TaskDTO> handle(GetTasksByProjectQuery query) {
        log.info("Traitement de la requête GetTasksByProject: {}", query.getProjectId());

        List<Task> tasks = taskRepository.findByProjectId(query.getProjectId());
        return taskMapper.toDtoList(tasks);
    }

    public List<TaskDTO> handle(GetTasksByAssigneeQuery query) {
        log.info("Traitement de la requête GetTasksByAssignee: {}", query.getAssignedTo());

        List<Task> tasks = taskRepository.findByAssignedTo(query.getAssignedTo());
        return taskMapper.toDtoList(tasks);
    }

    public List<TaskDTO> handle(GetTasksByStatusQuery query) {
        log.info("Traitement de la requête GetTasksByStatus: {}", query.getStatus());

        List<Task> tasks = taskRepository.findByStatus(query.getStatus());
        return taskMapper.toDtoList(tasks);
    }

    public List<TaskDTO> handle(GetAllTasksQuery query) {
        log.info("Traitement de la requête GetAllTasks");

        List<Task> tasks = taskRepository.findAll();
        return taskMapper.toDtoList(tasks);
    }
}