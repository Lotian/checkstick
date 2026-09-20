package com.xiqian.draw.repository;

import com.xiqian.draw.domain.DrawSlot;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface DrawSlotRepository extends JpaRepository<DrawSlot, UUID> {
    Optional<DrawSlot> findByRoundIdAndVisitorId(UUID roundId, String visitorId);
    Optional<DrawSlot> findFirstByRoundIdAndVisitorIdIsNullOrderBySlotIndexAsc(UUID roundId);
    long countByRoundIdAndVisitorIdIsNotNull(UUID roundId);
    List<DrawSlot> findAllByRoundIdOrderBySlotIndexAsc(UUID roundId);
}

