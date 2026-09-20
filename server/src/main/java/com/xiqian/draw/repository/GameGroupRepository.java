package com.xiqian.draw.repository;

import com.xiqian.draw.domain.GameGroup;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface GameGroupRepository extends JpaRepository<GameGroup, UUID> {
    Optional<GameGroup> findByCodeIgnoreCase(String code);
    boolean existsByCode(String code);
    List<GameGroup> findAllByOrderByCreatedAtDesc();
}

