package com.projecttaskhub.task_service.exception;

public class ProjectValidationException extends RuntimeException {
    public ProjectValidationException(String message) {
        super(message);
    }
}