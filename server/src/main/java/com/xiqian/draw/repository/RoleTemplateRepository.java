package com.xiqian.draw.repository;

import com.xiqian.draw.domain.RoleTemplate;
import com.xiqian.draw.domain.RoleType;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface RoleTemplateRepository extends JpaRepository<RoleTemplate, UUID> {
    Optional<RoleTemplate> findByRoleType(RoleType roleType);
    List<RoleTemplate> findAllByOrderByRoleTypeAsc();
}
