package com.projecttaskhub.task_service.cqrs.query;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class GetTasksByAssigneeQuery {
    private String assignedTo;
}