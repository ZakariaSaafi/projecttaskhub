package com.projecttaskhub.task_service.mapper;

import com.projecttaskhub.shareddto.dto.TaskDTO;
import com.projecttaskhub.task_service.cqrs.command.CreateTaskCommand;
import com.projecttaskhub.task_service.entity.Task;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingTarget;
import org.mapstruct.NullValuePropertyMappingStrategy;

import java.util.List;

@Mapper(
        componentModel = "spring",
        nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE
)
public interface TaskMapper {

    // Entity vers DTO
    TaskDTO toDto(Task task);

    // DTO vers Entity
    Task toEntity(TaskDTO taskDTO);

    // Command vers Entity
    @Mapping(target = "id", ignore = true)
    @Mapping(target = "createdAt", ignore = true)
    @Mapping(target = "updatedAt", ignore = true)
    Task toEntity(CreateTaskCommand command);

    // Listes
    List<TaskDTO> toDtoList(List<Task> tasks);

    List<Task> toEntityList(List<TaskDTO> taskDTOs);

    // Mise à jour d'entité existante
    @Mapping(target = "id", ignore = true)
    @Mapping(target = "createdAt", ignore = true)
    @Mapping(target = "updatedAt", ignore = true)
    void updateEntityFromDto(TaskDTO taskDTO, @MappingTarget Task task);
}