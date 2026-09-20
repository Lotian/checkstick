package com.xiqian.draw.service;

import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
public class RoundProgressListener {

    private final RoundService roundService;
    private final SseHub sseHub;

    public RoundProgressListener(RoundService roundService, SseHub sseHub) {
        this.roundService = roundService;
        this.sseHub = sseHub;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onDrawCompleted(DrawCompletedEvent event) {
        sseHub.broadcast(event.roundId(), roundService.get(event.roundId()));
    }
}

