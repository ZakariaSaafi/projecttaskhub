package com.projecttaskhub.task_service.cqrs.command;

import com.projecttaskhub.shareddto.dto.TaskPriority;
import com.projecttaskhub.shareddto.dto.TaskStatus;
import lombok.Data;

import java.time.LocalDateTime;

@Data
public class CreateTaskCommand {
    private String title;
    private String description;
    private Long projectId;
    private TaskStatus status;
    private TaskPriority priority;
    private String assignedTo;
    private LocalDateTime dueDate;
}
