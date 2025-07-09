package repository;

import com.projecttaskhub.shareddto.dto.ProjectStatus;
import entity.Project;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface ProjectRepository extends JpaRepository<Project, Long> {

    List<Project> findByOwner(String owner);

    List<Project> findByStatus(ProjectStatus status);

    Page<Project> findByOwner(String owner, Pageable pageable);

    @Query("SELECT p FROM Project p WHERE p.endDate BETWEEN :start AND :end")
    List<Project> findProjectsEndingBetween(
            @Param("start") LocalDateTime start,
            @Param("end") LocalDateTime end
    );

    @Query("SELECT p FROM Project p WHERE p.name LIKE %:name%")
    List<Project> findByNameContaining(@Param("name") String name);

    boolean existsByNameAndOwner(String name, String owner);
}
