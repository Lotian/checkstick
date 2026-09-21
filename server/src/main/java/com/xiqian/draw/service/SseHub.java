package com.xiqian.draw.service;

import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArraySet;

@Component
public class SseHub {

    private static final long TIMEOUT_MILLIS = 30 * 60 * 1000L;
    private final Map<UUID, Set<SseEmitter>> emitters = new ConcurrentHashMap<>();

    /** 为指定轮次注册长连接；三种结束路径都必须清理集合，避免长期活动中积累失效连接。 */
    public SseEmitter subscribe(UUID roundId) {
        SseEmitter emitter = new SseEmitter(TIMEOUT_MILLIS);
        emitters.computeIfAbsent(roundId, ignored -> new CopyOnWriteArraySet<>()).add(emitter);
        emitter.onCompletion(() -> remove(roundId, emitter));
        emitter.onTimeout(() -> remove(roundId, emitter));
        emitter.onError(error -> remove(roundId, emitter));
        try {
            emitter.send(SseEmitter.event().name("connected").data(Map.of("roundId", roundId)));
        } catch (IOException | IllegalStateException exception) {
            remove(roundId, emitter);
            emitter.completeWithError(exception);
        }
        return emitter;
    }

    /** 向某轮的全部管理端页面推送最新快照；单个连接失败不会影响其他订阅者。 */
    public void broadcast(UUID roundId, Object payload) {
        Set<SseEmitter> roundEmitters = emitters.getOrDefault(roundId, Set.of());
        roundEmitters.forEach(emitter -> {
            try {
                emitter.send(SseEmitter.event().name("progress").data(payload));
            } catch (IOException | IllegalStateException exception) {
                remove(roundId, emitter);
            }
        });
    }

    @Scheduled(fixedDelay = 20_000)
    public void heartbeat() {
        // 心跳可以及时发现浏览器已经断开的长连接。
        emitters.forEach((roundId, roundEmitters) -> roundEmitters.forEach(emitter -> {
            try {
                emitter.send(SseEmitter.event().comment("heartbeat"));
            } catch (IOException | IllegalStateException exception) {
                remove(roundId, emitter);
            }
        }));
    }

    private void remove(UUID roundId, SseEmitter emitter) {
        Set<SseEmitter> roundEmitters = emitters.get(roundId);
        if (roundEmitters == null) {
            return;
        }
        roundEmitters.remove(emitter);
        if (roundEmitters.isEmpty()) {
            // 只删除当前观察到的集合，避免并发订阅刚建立时误删新的映射。
            emitters.remove(roundId, roundEmitters);
        }
    }
}

