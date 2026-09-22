package com.xiqian.draw.api;

import com.xiqian.draw.api.dto.StoryIntroDtos;
import com.xiqian.draw.service.StoryIntroService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/story-intro")
public class AdminStoryIntroController {

    private final StoryIntroService service;

    public AdminStoryIntroController(StoryIntroService service) {
        this.service = service;
    }

    @GetMapping
    public StoryIntroDtos.StoryIntroResponse get() {
        return service.get();
    }

    @PutMapping
    public StoryIntroDtos.StoryIntroResponse update(
            @Valid @RequestBody StoryIntroDtos.UpdateStoryIntroRequest request) {
        return service.update(request);
    }
}
