package com.xiqian.draw.service;

import com.xiqian.draw.domain.RoleType;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Objects;
import java.util.Random;

/**
 * 规划一轮的签位顺序。
 *
 * <p>一共 maxPlayers 个签位：1 个新郎 + 1 个新娘 + 其余村民，打乱后按顺序摆放，
 * 玩家按到场顺序领取序号最小的空闲签位。
 *
 * <p>额外保证：<b>新郎与新娘一定落在前 minPlayers 个签位内</b>。
 * 因为本轮允许在抽满 minPlayers 人后提前封签，若不保证这一点，
 * 提前封签时可能出现"这一局没有新娘/新郎"的情况。
 */
public final class RoundSlotPlanner {

    private RoundSlotPlanner() {
    }

    public static List<RoleType> plan(int minPlayers, int maxPlayers, Random random) {
        if (minPlayers < 2) {
            throw new IllegalArgumentException("最低人数不能少于2（需要新郎与新娘各一人）");
        }
        if (maxPlayers < minPlayers) {
            throw new IllegalArgumentException("最高人数不能小于最低人数");
        }
        Objects.requireNonNull(random, "随机数生成器不能为空");

        List<RoleType> roles = new ArrayList<>(maxPlayers);
        roles.add(RoleType.GROOM);
        roles.add(RoleType.BRIDE);
        for (int i = 2; i < maxPlayers; i++) {
            roles.add(RoleType.VILLAGER);
        }
        Collections.shuffle(roles, random);

        // 把落在最低人数之外的主角，与最低人数之内的村民交换位置。
        // 前 minPlayers 个签位里至少有 minPlayers-2 个村民，足够放下两个主角，
        // 所以当 minPlayers >= 2 时交换一定能完成。
        for (RoleType special : List.of(RoleType.GROOM, RoleType.BRIDE)) {
            int index = roles.indexOf(special);
            if (index < minPlayers) {
                continue;
            }
            int villagerIndex = indexOfVillagerBefore(roles, minPlayers);
            if (villagerIndex >= 0) {
                Collections.swap(roles, index, villagerIndex);
            }
        }
        return roles;
    }

    private static int indexOfVillagerBefore(List<RoleType> roles, int limit) {
        for (int index = 0; index < limit; index++) {
            if (roles.get(index) == RoleType.VILLAGER) {
                return index;
            }
        }
        return -1;
    }
}
