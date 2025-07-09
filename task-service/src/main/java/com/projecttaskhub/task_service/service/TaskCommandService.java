package com.projecttaskhub.task_service.service;


import com.projecttaskhub.shareddto.dto.TaskDTO;
import com.projecttaskhub.task_service.cqrs.command.CreateTaskCommand;
import com.projecttaskhub.task_service.cqrs.command.DeleteTaskCommand;
import com.projecttaskhub.task_service.cqrs.command.UpdateTaskCommand;
import com.projecttaskhub.task_service.cqrs.handler.TaskCommandHandler;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
@Slf4j
public class TaskCommandService {

    private final TaskCommandHandler commandHandler;

    public TaskDTO createTask(CreateTaskCommand command) {
        log.info("Service: Création d'une nouvelle tâche: {}", command.getTitle());
        return commandHandler.handle(command);
    }

    public TaskDTO updateTask(UpdateTaskCommand command) {
        log.info("Service: Mise à jour de la tâche: {}", command.getId());
        return commandHandler.handle(command);
    }

    public void deleteTask(DeleteTaskCommand command) {
        log.info("Service: Suppression de la tâche: {}", command.getId());
        commandHandler.handle(command);
    }
}
