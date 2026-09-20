package com.xiqian.draw.api.dto;

public final class AppConfigDtos {
    private AppConfigDtos() {
    }

    /**
     * @param playerBaseUrl 玩家端 H5 地址，始终以 / 结尾；为空串表示与后台同源。
     */
    public record AppConfigResponse(String playerBaseUrl) {
    }
}
