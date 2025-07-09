package com.projecttaskhub.task_service.controller;


import com.projecttaskhub.shareddto.dto.TaskDTO;
import com.projecttaskhub.shareddto.dto.TaskPriority;
import com.projecttaskhub.shareddto.dto.TaskStatus;
import com.projecttaskhub.task_service.cqrs.command.CreateTaskCommand;
import com.projecttaskhub.task_service.cqrs.command.DeleteTaskCommand;
import com.projecttaskhub.task_service.cqrs.command.UpdateTaskCommand;
import com.projecttaskhub.task_service.service.TaskCommandService;
import com.projecttaskhub.task_service.service.TaskQueryService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.security.Principal;
import java.time.LocalDateTime;
import java.util.List;

@RestController
@RequestMapping("/tasks")
@RequiredArgsConstructor
@Slf4j
@CrossOrigin(origins = "*")
public class TaskController {

    private final TaskCommandService commandService;
    private final TaskQueryService queryService;

    // =============== COMMANDES (CREATE, UPDATE, DELETE) ===============

    @PostMapping
    @PreAuthorize("hasRole('USER') or hasRole('ADMIN')")
    public ResponseEntity<TaskDTO> createTask(
            @Valid @RequestBody CreateTaskCommand command,
            Principal principal) {

        log.info("Création d'une tâche par l'utilisateur: {}", principal.getName());

        // Si assignedTo n'est pas spécifié, assigner à l'utilisateur connecté
        if (command.getAssignedTo() == null || command.getAssignedTo().trim().isEmpty()) {
            command.setAssignedTo(principal.getName());
        }

        TaskDTO createdTask = commandService.createTask(command);
        return ResponseEntity.status(HttpStatus.CREATED).body(createdTask);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('USER') or hasRole('ADMIN')")
    public ResponseEntity<TaskDTO> updateTask(
            @PathVariable String id,
            @Valid @RequestBody UpdateTaskCommand command) {

        log.info("Mise à jour de la tâche: {}", id);
        command.setId(id);
        TaskDTO updatedTask = commandService.updateTask(command);
        return ResponseEntity.ok(updatedTask);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Void> deleteTask(@PathVariable String id) {
        log.info("Suppression de la tâche: {}", id);

        DeleteTaskCommand command = DeleteTaskCommand.builder()
                .id(id)
                .build();

        commandService.deleteTask(command);
        return ResponseEntity.noContent().build();
    }

    // =============== REQUÊTES (READ) ===============

    @GetMapping("/{id}")
    @PreAuthorize("hasRole('USER') or hasRole('ADMIN')")
    public ResponseEntity<TaskDTO> getTask(@PathVariable String id) {
        log.info("Récupération de la tâche: {}", id);
        TaskDTO task = queryService.getTaskById(id);
        return ResponseEntity.ok(task);
    }

    @GetMapping
    @PreAuthorize("hasRole('USER') or hasRole('ADMIN')")
    public ResponseEntity<List<TaskDTO>> getAllTasks() {
        log.info("Récupération de toutes les tâches");
        List<TaskDTO> tasks = queryService.getAllTasks();
        return ResponseEntity.ok(tasks);
    }

    @GetMapping("/paginated")
    @PreAuthorize("hasRole('USER') or hasRole('ADMIN')")
    public ResponseEntity<Page<TaskDTO>> getTasksPaginated(Pageable pageable) {
        log.info("Récupération des tâches paginées: {}", pageable);
        Page<TaskDTO> tasks = queryService.getTasksPaginated(pageable);
        return ResponseEntity.ok(tasks);
    }

    // =============== REQUÊTES PAR PROJET ===============

    @GetMapping("/project/{projectId}")
    @PreAuthorize("hasRole('USER') or hasRole('ADMIN')")
    public ResponseEntity<List<TaskDTO>> getTasksByProject(@PathVariable Long projectId) {
        log.info("Récupération des tâches pour le projet: {}", projectId);
        List<TaskDTO> tasks = queryService.getTasksByProject(projectId);
        return ResponseEntity.ok(tasks);
    }

    @GetMapping("/project/{projectId}/status/{status}")
    @PreAuthorize("hasRole('USER') or hasRole('ADMIN')")
    public ResponseEntity<List<TaskDTO>> getTasksByProjectAndStatus(
            @PathVariable Long projectId,
            @PathVariable TaskStatus status) {

        log.info("Récupération des tâches pour le projet {} avec le statut {}", projectId, status);
        List<TaskDTO> tasks = queryService.getTasksByProjectAndStatus(projectId, status);
        return ResponseEntity.ok(tasks);
    }

    @GetMapping("/project/{projectId}/count")
    @PreAuthorize("hasRole('USER') or hasRole('ADMIN')")
    public ResponseEntity<Long> countTasksByProject(@PathVariable Long projectId) {
        log.info("Comptage des tâches pour le projet: {}", projectId);
        long count = queryService.countTasksByProject(projectId);
        return ResponseEntity.ok(count);
    }

    // =============== REQUÊTES PAR UTILISATEUR ===============

    @GetMapping("/my-tasks")
    @PreAuthorize("hasRole('USER') or hasRole('ADMIN')")
    public ResponseEntity<List<TaskDTO>> getMyTasks(Principal principal) {
        log.info("Récupération des tâches pour l'utilisateur: {}", principal.getName());
        List<TaskDTO> tasks = queryService.getTasksByAssignee(principal.getName());
        return ResponseEntity.ok(tasks);
    }

    @GetMapping("/assignee/{assignee}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<List<TaskDTO>> getTasksByAssignee(@PathVariable String assignee) {
        log.info("Récupération des tâches pour l'assigné: {}", assignee);
        List<TaskDTO> tasks = queryService.getTasksByAssignee(assignee);
        return ResponseEntity.ok(tasks);
    }

    @GetMapping("/assignee/{assignee}/count")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Long> countTasksByAssignee(@PathVariable String assignee) {
        log.info("Comptage des tâches pour l'assigné: {}", assignee);
        long count = queryService.countTasksByAssignee(assignee);
        return ResponseEntity.ok(count);
    }

    // =============== REQUÊTES PAR STATUT ET PRIORITÉ ===============

    @GetMapping("/status/{status}")
    @PreAuthorize("hasRole('USER') or hasRole('ADMIN')")
    public ResponseEntity<List<TaskDTO>> getTasksByStatus(@PathVariable TaskStatus status) {
        log.info("Récupération des tâches par statut: {}", status);
        List<TaskDTO> tasks = queryService.getTasksByStatus(status);
        return ResponseEntity.ok(tasks);
    }

    @GetMapping("/priority/{priority}")
    @PreAuthorize("hasRole('USER') or hasRole('ADMIN')")
    public ResponseEntity<List<TaskDTO>> getTasksByPriority(@PathVariable TaskPriority priority) {
        log.info("Récupération des tâches par priorité: {}", priority);
        List<TaskDTO> tasks = queryService.getTasksByPriority(priority);
        return ResponseEntity.ok(tasks);
    }

    // =============== RECHERCHE ===============

    @GetMapping("/search")
    @PreAuthorize("hasRole('USER') or hasRole('ADMIN')")
    public ResponseEntity<List<TaskDTO>> searchTasks(@RequestParam String title) {
        log.info("Recherche de tâches par titre: {}", title);
        List<TaskDTO> tasks = queryService.searchTasksByTitle(title);
        return ResponseEntity.ok(tasks);
    }

    @GetMapping("/due-between")
    @PreAuthorize("hasRole('USER') or hasRole('ADMIN')")
    public ResponseEntity<List<TaskDTO>> getTasksDueBetween(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime start,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime end) {

        log.info("Récupération des tâches dues entre {} et {}", start, end);
        List<TaskDTO> tasks = queryService.getTasksDueBetween(start, end);
        return ResponseEntity.ok(tasks);
    }

    // =============== ENDPOINTS UTILITAIRES ===============

    @GetMapping("/health")
    public ResponseEntity<String> health() {
        return ResponseEntity.ok("Task Service is running!");
    }
}