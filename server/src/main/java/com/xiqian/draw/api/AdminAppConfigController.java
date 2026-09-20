package com.xiqian.draw.api;

import com.xiqian.draw.api.dto.AppConfigDtos;
import com.xiqian.draw.config.AppProperties;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 后台运行时配置。玩家端与后台分属不同域名时，管理端二维码需要知道玩家端地址，
 * 因此由服务端下发，避免把域名写死在前端构建产物里。
 */
@RestController
@RequestMapping("/api/admin/app-config")
public class AdminAppConfigController {

    private final AppProperties properties;

    public AdminAppConfigController(AppProperties properties) {
        this.properties = properties;
    }

    @GetMapping
    public AppConfigDtos.AppConfigResponse get() {
        return new AppConfigDtos.AppConfigResponse(properties.resolvePlayerBaseUrl());
    }
}
