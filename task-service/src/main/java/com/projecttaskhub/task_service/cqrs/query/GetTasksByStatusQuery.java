package com.projecttaskhub.task_service.cqrs.query;

import lombok.AllArgsConstructor;
import com.projecttaskhub.shareddto.dto.TaskStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class GetTasksByStatusQuery {
    private TaskStatus status;
}