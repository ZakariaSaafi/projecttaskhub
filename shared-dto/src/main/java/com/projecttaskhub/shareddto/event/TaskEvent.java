package com.projecttaskhub.shareddto.event;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TaskEvent {
    private String eventType;
    private String taskId;
    private Long projectId;
    private String taskTitle;
    private String eventData;
    private LocalDateTime timestamp;
}
