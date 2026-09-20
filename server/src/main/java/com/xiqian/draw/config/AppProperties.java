package com.xiqian.draw.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app")
public class AppProperties {

    /**
     * 玩家端 H5 的对外地址，例如 https://h5.example.com。
     * 留空表示玩家端与管理后台同源，由前端回退到当前页面的 origin。
     */
    private String publicBaseUrl = "";

    private final Admin admin = new Admin();

    public String getPublicBaseUrl() {
        return publicBaseUrl;
    }

    public void setPublicBaseUrl(String publicBaseUrl) {
        this.publicBaseUrl = publicBaseUrl == null ? "" : publicBaseUrl.trim();
    }

    /** 归一化后的玩家端地址，始终以 / 结尾；未配置时返回空串。 */
    public String resolvePlayerBaseUrl() {
        if (publicBaseUrl.isEmpty()) {
            return "";
        }
        return publicBaseUrl.endsWith("/") ? publicBaseUrl : publicBaseUrl + "/";
    }

    public Admin getAdmin() {
        return admin;
    }

    public static class Admin {
        // 不给默认口令：未配置时启动直接失败，避免用出厂的弱口令对外提供服务。
        private String username = "";
        private String password = "";

        public String getUsername() {
            return username;
        }

        public void setUsername(String username) {
            this.username = username == null ? "" : username.trim();
        }

        public String getPassword() {
            return password;
        }

        public void setPassword(String password) {
            this.password = password == null ? "" : password;
        }
    }
}
