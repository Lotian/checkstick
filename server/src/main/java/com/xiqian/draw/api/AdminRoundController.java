package com.xiqian.draw.api;

import com.xiqian.draw.api.dto.RoundDtos;
import com.xiqian.draw.service.RoundService;
import com.xiqian.draw.service.SseHub;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.nio.charset.StandardCharsets;
import java.util.UUID;

@RestController
@RequestMapping("/api/admin/rounds/{id}")
public class AdminRoundController {

    private final RoundService roundService;
    private final SseHub sseHub;

    public AdminRoundController(RoundService roundService, SseHub sseHub) {
        this.roundService = roundService;
        this.sseHub = sseHub;
    }

    @GetMapping
    public RoundDtos.RoundResponse get(@PathVariable UUID id) {
        return roundService.get(id);
    }

    /** 提前封签：抽满最低人数后不再等满最高人数，直接结束本轮。 */
    @PostMapping("/close")
    public RoundDtos.RoundResponse close(@PathVariable UUID id) {
        RoundDtos.RoundResponse response = roundService.closeEarly(id);
        sseHub.broadcast(id, response);
        return response;
    }

    @GetMapping(path = "/events", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter events(@PathVariable UUID id) {
        roundService.get(id);
        return sseHub.subscribe(id);
    }

    @GetMapping(value = "/export.csv", produces = "text/csv;charset=UTF-8")
    public ResponseEntity<byte[]> export(@PathVariable UUID id) {
        RoundDtos.RoundResponse round = roundService.get(id);
        StringBuilder csv = new StringBuilder("\uFEFF序号,身份,游客标识,抽取时间\r\n");
        round.draws().forEach(draw -> csv.append(draw.slotIndex()).append(',')
                .append(escape(draw.roleName())).append(',')
                .append(escape(draw.visitorId())).append(',')
                .append(escape(String.valueOf(draw.drawnAt()))).append("\r\n"));
        byte[] content = csv.toString().getBytes(StandardCharsets.UTF_8);
        HttpHeaders headers = new HttpHeaders();
        headers.setContentDisposition(ContentDisposition.attachment()
                .filename("round-" + round.roundNumber() + ".csv", StandardCharsets.UTF_8).build());
        return ResponseEntity.ok().headers(headers).body(content);
    }

    private String escape(String value) {
        return "\"" + (value == null ? "" : value.replace("\"", "\"\"")) + "\"";
    }
}
