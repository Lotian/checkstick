package com.xiqian.draw.api;

import com.xiqian.draw.api.dto.PublicDtos;
import com.xiqian.draw.service.DrawService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/public/groups/{code}")
public class PublicDrawController {

    private final DrawService drawService;

    public PublicDrawController(DrawService drawService) {
        this.drawService = drawService;
    }

    @GetMapping("/state")
    public PublicDtos.PublicGroupState state(@PathVariable String code,
                                             @RequestHeader("X-Visitor-Id") String visitorId) {
        return drawService.state(code, visitorId);
    }

    @PostMapping("/draw")
    public PublicDtos.DrawResult draw(@PathVariable String code,
                                      @RequestHeader("X-Visitor-Id") String visitorId) {
        return drawService.draw(code, visitorId);
    }
}

