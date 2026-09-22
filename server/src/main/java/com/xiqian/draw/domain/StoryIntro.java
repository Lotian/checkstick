package com.xiqian.draw.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.OffsetDateTime;

/** 玩家扫码后首先看到的故事简介，全站只保留一份配置。 */
@Entity
@Table(name = "story_intro")
public class StoryIntro {

    public static final String SINGLETON_ID = "default";

    @Id
    @Column(length = 32)
    private String id;

    @Column(nullable = false, length = 80)
    private String title;

    @Column(nullable = false, length = 160)
    private String subtitle;

    @Column(name = "intro_text", nullable = false, columnDefinition = "text")
    private String introText;

    @Column(name = "warning_text", nullable = false, columnDefinition = "text")
    private String warningText;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    protected StoryIntro() {
    }

    public void update(String title, String subtitle, String introText, String warningText) {
        this.title = normalize(title);
        this.subtitle = normalize(subtitle);
        this.introText = normalize(introText);
        this.warningText = normalize(warningText);
        this.updatedAt = OffsetDateTime.now();
    }

    private String normalize(String text) {
        return text == null ? "" : text.strip();
    }

    public String getTitle() { return title; }
    public String getSubtitle() { return subtitle; }
    public String getIntroText() { return introText; }
    public String getWarningText() { return warningText; }
    public OffsetDateTime getUpdatedAt() { return updatedAt; }
}
