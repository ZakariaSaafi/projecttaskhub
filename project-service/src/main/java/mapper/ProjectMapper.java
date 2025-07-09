package mapper;

import com.projecttaskhub.shareddto.dto.ProjectDTO;
import entity.Project;
import org.mapstruct.Mapper;
import org.mapstruct.MappingTarget;
import org.mapstruct.NullValuePropertyMappingStrategy;

import java.util.List;

@Mapper(
        componentModel = "spring",
        nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE
)
public interface ProjectMapper {

    ProjectDTO toDto(Project project);

    Project toEntity(ProjectDTO projectDTO);

    List<ProjectDTO> toDtoList(List<Project> projects);

    void updateEntityFromDto(ProjectDTO projectDTO, @MappingTarget Project project);
}