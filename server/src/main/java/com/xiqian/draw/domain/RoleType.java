package com.xiqian.draw.domain;

public enum RoleType {
    GROOM("新郎"),
    BRIDE("新娘"),
    VILLAGER("村民");

    private final String displayName;

    RoleType(String displayName) {
        this.displayName = displayName;
    }

    public String getDisplayName() {
        return displayName;
    }
}

