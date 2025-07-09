package com.projecttaskhub.task_service.exception;

public class TaskNotFoundException extends RuntimeException {
    public TaskNotFoundException(String id) {
        super("Tâche non trouvée avec l'ID: " + id);
    }
}
