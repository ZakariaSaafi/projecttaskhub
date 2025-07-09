package com.projecttaskhub.task_service.cqrs.command;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class DeleteTaskCommand {
    private String id;
}
