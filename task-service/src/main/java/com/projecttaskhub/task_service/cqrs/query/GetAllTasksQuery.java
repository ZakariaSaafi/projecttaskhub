package com.projecttaskhub.task_service.cqrs.query;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class GetAllTasksQuery {
    // Query sans paramètres pour récupérer toutes les tâches
}