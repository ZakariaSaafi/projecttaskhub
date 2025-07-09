package com.projecttaskhub.shareddto.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class TaskDTO {
    private String id;

    @NotBlank(message = "Le titre de la tâche est obligatoire")
    private String title;

    private String description;

    @NotNull(message = "L'ID du projet est obligatoire")
    private Long projectId;

    @NotNull(message = "Le statut est obligatoire")
    private TaskStatus status;

    @NotNull(message = "La priorité est obligatoire")
    private TaskPriority priority;

    private String assignedTo;

    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private LocalDateTime dueDate;

    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private LocalDateTime createdAt;

    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private LocalDateTime updatedAt;
}
