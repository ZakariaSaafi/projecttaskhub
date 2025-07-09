package com.projecttaskhub.task_service.client;

import com.projecttaskhub.shareddto.dto.ProjectDTO;
import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;

@FeignClient(name = "project-service", path = "/projects")
public interface ProjectServiceClient {

    @GetMapping("/{id}")
    ProjectDTO getProject(@PathVariable Long id);

    @GetMapping("/{id}/exists")
    Boolean projectExists(@PathVariable Long id);
}