package service;


import com.projecttaskhub.shareddto.dto.ProjectDTO;
import com.projecttaskhub.shareddto.dto.ProjectStatus;
import com.projecttaskhub.shareddto.event.ProjectEvent;
import entity.Project;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import mapper.ProjectMapper;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import repository.ProjectRepository;

import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
@Transactional
public class ProjectService {

    private final ProjectRepository projectRepository;
    private final ProjectMapper projectMapper;
    private final RabbitTemplate rabbitTemplate;

    public ProjectDTO createProject(ProjectDTO projectDTO) {
        // Vérifier que le projet n'existe pas déjà pour cet utilisateur
        if (projectRepository.existsByNameAndOwner(projectDTO.getName(), projectDTO.getOwner())) {
            throw new IllegalArgumentException("Un projet avec ce nom existe déjà pour cet utilisateur");
        }

        Project project = projectMapper.toEntity(projectDTO);
        project.setCreatedAt(LocalDateTime.now());
        project.setUpdatedAt(LocalDateTime.now());

        Project savedProject = projectRepository.save(project);
        ProjectDTO result = projectMapper.toDto(savedProject);

        // Publier l'événement
        publishProjectEvent("PROJECT_CREATED", result);

        log.info("Projet créé avec l'ID: {}", savedProject.getId());
        return result;
    }

    @Transactional(readOnly = true)
    public ProjectDTO getProjectById(Long id) {
        Project project = projectRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Projet non trouvé avec l'ID: " + id));
        return projectMapper.toDto(project);
    }

    @Transactional(readOnly = true)
    public List<ProjectDTO> getAllProjects() {
        List<Project> projects = projectRepository.findAll();
        return projectMapper.toDtoList(projects);
    }

    @Transactional(readOnly = true)
    public Page<ProjectDTO> getProjectsPaginated(Pageable pageable) {
        Page<Project> projects = projectRepository.findAll(pageable);
        return projects.map(projectMapper::toDto);
    }

    @Transactional(readOnly = true)
    public List<ProjectDTO> getProjectsByOwner(String owner) {
        List<Project> projects = projectRepository.findByOwner(owner);
        return projectMapper.toDtoList(projects);
    }

    @Transactional(readOnly = true)
    public List<ProjectDTO> getProjectsByStatus(ProjectStatus status) {
        List<Project> projects = projectRepository.findByStatus(status);
        return projectMapper.toDtoList(projects);
    }

    public ProjectDTO updateProject(Long id, ProjectDTO projectDTO) {
        Project existingProject = projectRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Projet non trouvé avec l'ID: " + id));

        projectMapper.updateEntityFromDto(projectDTO, existingProject);
        existingProject.setUpdatedAt(LocalDateTime.now());

        Project savedProject = projectRepository.save(existingProject);
        ProjectDTO result = projectMapper.toDto(savedProject);

        // Publier l'événement
        publishProjectEvent("PROJECT_UPDATED", result);

        log.info("Projet mis à jour avec l'ID: {}", id);
        return result;
    }

    public void deleteProject(Long id) {
        Project project = projectRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Projet non trouvé avec l'ID: " + id));

        ProjectDTO projectDTO = projectMapper.toDto(project);
        projectRepository.delete(project);

        // Publier l'événement
        publishProjectEvent("PROJECT_DELETED", projectDTO);

        log.info("Projet supprimé avec l'ID: {}", id);
    }

    @Transactional(readOnly = true)
    public List<ProjectDTO> searchProjectsByName(String name) {
        List<Project> projects = projectRepository.findByNameContaining(name);
        return projectMapper.toDtoList(projects);
    }

    private void publishProjectEvent(String eventType, ProjectDTO projectDTO) {
        try {
            ProjectEvent event = new ProjectEvent();
            event.setEventType(eventType);
            event.setProjectId(projectDTO.getId());
            event.setProjectName(projectDTO.getName());
            event.setEventData(projectDTO.toString());
            event.setTimestamp(LocalDateTime.now());

            rabbitTemplate.convertAndSend("project.exchange", "project.events", event);
            log.info("Événement publié: {} pour le projet {}", eventType, projectDTO.getId());
        } catch (Exception e) {
            log.error("Erreur lors de la publication de l'événement: {}", e.getMessage());
        }
    }
}
