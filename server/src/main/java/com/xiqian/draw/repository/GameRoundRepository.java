package com.xiqian.draw.repository;

import com.xiqian.draw.domain.GameRound;
import com.xiqian.draw.domain.RoundStatus;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface GameRoundRepository extends JpaRepository<GameRound, UUID> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select r from GameRound r where r.id = :id")
    Optional<GameRound> findByIdForUpdate(@Param("id") UUID id);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select r from GameRound r where r.group.id = :groupId and r.status in :statuses")
    Optional<GameRound> findCurrentForUpdate(@Param("groupId") UUID groupId,
                                             @Param("statuses") Collection<RoundStatus> statuses);

    Optional<GameRound> findFirstByGroupIdAndStatusInOrderByStartedAtDesc(
            UUID groupId, Collection<RoundStatus> statuses);

    Optional<GameRound> findFirstByGroupIdOrderByRoundNumberDesc(UUID groupId);

    List<GameRound> findAllByGroupIdOrderByRoundNumberDesc(UUID groupId);
}

