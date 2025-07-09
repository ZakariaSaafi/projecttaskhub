package com.projecttaskhub.shareddto.event;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ProjectEvent {
    private String eventType;
    private Long projectId;
    private String projectName;
    private String eventData;
    private LocalDateTime timestamp;
}
