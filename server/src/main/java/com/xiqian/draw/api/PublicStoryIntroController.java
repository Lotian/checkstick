package com.xiqian.draw.api;

import com.xiqian.draw.api.dto.StoryIntroDtos;
import com.xiqian.draw.service.StoryIntroService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/public/story-intro")
public class PublicStoryIntroController {

    private final StoryIntroService service;

    public PublicStoryIntroController(StoryIntroService service) {
        this.service = service;
    }

    @GetMapping
    public StoryIntroDtos.StoryIntroResponse get() {
        return service.get();
    }
}
