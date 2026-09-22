package com.xiqian.draw.service;

import com.xiqian.draw.api.dto.StoryIntroDtos;
import com.xiqian.draw.domain.StoryIntro;
import com.xiqian.draw.repository.StoryIntroRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class StoryIntroService {

    private final StoryIntroRepository repository;

    public StoryIntroService(StoryIntroRepository repository) {
        this.repository = repository;
    }

    @Transactional(readOnly = true)
    public StoryIntroDtos.StoryIntroResponse get() {
        return toResponse(findSingleton());
    }

    @Transactional
    public StoryIntroDtos.StoryIntroResponse update(StoryIntroDtos.UpdateStoryIntroRequest request) {
        StoryIntro intro = findSingleton();
        intro.update(request.title(), request.subtitle(), request.introText(), request.warningText());
        repository.flush();
        return toResponse(intro);
    }

    private StoryIntro findSingleton() {
        return repository.findById(StoryIntro.SINGLETON_ID)
                .orElseThrow(() -> new IllegalStateException("缺少故事简介初始配置，请检查数据库迁移"));
    }

    private StoryIntroDtos.StoryIntroResponse toResponse(StoryIntro intro) {
        return new StoryIntroDtos.StoryIntroResponse(
                intro.getTitle(), intro.getSubtitle(), intro.getIntroText(),
                intro.getWarningText(), intro.getUpdatedAt());
    }
}
