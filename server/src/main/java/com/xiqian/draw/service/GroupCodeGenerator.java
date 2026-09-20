package com.xiqian.draw.service;

import org.springframework.stereotype.Component;

import java.security.SecureRandom;

@Component
public class GroupCodeGenerator {

    /** 组局码长度：4 位十进制数字，现场口头传达比字母数字混排更不容易听错。 */
    private static final int CODE_LENGTH = 4;
    private static final int DIGIT_BOUND = 10;
    private final SecureRandom secureRandom = new SecureRandom();

    public String nextCode() {
        StringBuilder code = new StringBuilder(CODE_LENGTH);
        for (int i = 0; i < CODE_LENGTH; i++) {
            // 允许前导零，码位空间为 0000~9999 共一万个
            code.append(secureRandom.nextInt(DIGIT_BOUND));
        }
        return code.toString();
    }
}
