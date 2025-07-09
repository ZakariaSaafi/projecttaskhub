package com.projecttaskhub.task_service.repository;

import com.projecttaskhub.shareddto.dto.TaskPriority;
import com.projecttaskhub.shareddto.dto.TaskStatus;
import com.projecttaskhub.task_service.entity.Task;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.data.mongodb.repository.Query;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface TaskRepository extends MongoRepository<Task, String> {

    // Requêtes par propriétés
    List<Task> findByProjectId(Long projectId);

    List<Task> findByAssignedTo(String assignedTo);

    List<Task> findByStatus(TaskStatus status);

    List<Task> findByPriority(TaskPriority priority);

    // Requêtes paginées
    Page<Task> findByProjectId(Long projectId, Pageable pageable);

    Page<Task> findByAssignedTo(String assignedTo, Pageable pageable);

    // Requêtes MongoDB personnalisées
    @Query("{ 'dueDate' : { $gte: ?0, $lte: ?1 } }")
    List<Task> findTasksDueBetween(LocalDateTime start, LocalDateTime end);

    @Query("{ 'title' : { $regex: ?0, $options: 'i' } }")
    List<Task> findByTitleContainingIgnoreCase(String title);

    @Query("{ 'description' : { $regex: ?0, $options: 'i' } }")
    List<Task> findByDescriptionContainingIgnoreCase(String description);

    // Requêtes combinées
    List<Task> findByProjectIdAndAssignedTo(Long projectId, String assignedTo);

    @Query("{ 'projectId' : ?0, 'status' : ?1 }")
    List<Task> findByProjectIdAndStatus(Long projectId, TaskStatus status);

    @Query("{ 'assignedTo' : ?0, 'status' : ?1 }")
    List<Task> findByAssignedToAndStatus(String assignedTo, TaskStatus status);

    // Requêtes de comptage
    long countByProjectId(Long projectId);

    long countByAssignedTo(String assignedTo);

    long countByStatus(TaskStatus status);

    @Query(value = "{ 'projectId' : ?0, 'status' : ?1 }", count = true)
    long countByProjectIdAndStatus(Long projectId, TaskStatus status);

    // Requêtes d'existence
    boolean existsByProjectIdAndTitle(Long projectId, String title);

    // Requêtes de suppression
    void deleteByProjectId(Long projectId);
}