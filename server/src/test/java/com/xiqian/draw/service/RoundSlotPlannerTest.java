package com.xiqian.draw.service;

import com.xiqian.draw.domain.RoleType;
import org.junit.jupiter.api.Test;

import java.security.SecureRandom;
import java.util.List;
import java.util.Random;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class RoundSlotPlannerTest {

    private final Random random = new SecureRandom();

    @Test
    void shouldPlaceGroomAndBrideWithinMinimumPlayers() {
        int[][] ranges = {{5, 8}, {2, 2}, {2, 8}, {3, 20}, {5, 5}, {8, 8}, {6, 7}};

        for (int[] range : ranges) {
            int minPlayers = range[0];
            int maxPlayers = range[1];
            String hint = "最低" + minPlayers + "人最高" + maxPlayers + "人";

            for (int attempt = 0; attempt < 200; attempt++) {
                List<RoleType> roles = RoundSlotPlanner.plan(minPlayers, maxPlayers, random);

                assertThat(roles).as(hint + " 签位数量").hasSize(maxPlayers);

                long groomCount = roles.stream().filter(role -> role == RoleType.GROOM).count();
                long brideCount = roles.stream().filter(role -> role == RoleType.BRIDE).count();
                long villagerCount = roles.stream().filter(role -> role == RoleType.VILLAGER).count();
                assertThat(groomCount).as(hint + " 新郎数量").isEqualTo(1);
                assertThat(brideCount).as(hint + " 新娘数量").isEqualTo(1);
                assertThat(villagerCount).as(hint + " 村民数量").isEqualTo(maxPlayers - 2);

                assertThat(roles.indexOf(RoleType.GROOM)).as(hint + " 新郎位置").isLessThan(minPlayers);
                assertThat(roles.indexOf(RoleType.BRIDE)).as(hint + " 新娘位置").isLessThan(minPlayers);
            }
        }
    }

    @Test
    void shouldStillShuffleTheRest() {
        // 统计新郎没有出现在第 0 个签位的次数，若完全没有打乱则恒为 0
        int notFirstCount = 0;
        for (int attempt = 0; attempt < 200; attempt++) {
            if (RoundSlotPlanner.plan(5, 8, random).indexOf(RoleType.GROOM) != 0) {
                notFirstCount++;
            }
        }
        assertThat(notFirstCount).isGreaterThan(0);
    }

    @Test
    void shouldRejectInvalidRange() {
        assertThatThrownBy(() -> RoundSlotPlanner.plan(1, 5, random))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> RoundSlotPlanner.plan(6, 5, random))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
