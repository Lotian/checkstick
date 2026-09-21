package com.xiqian.draw.service;

import com.xiqian.draw.api.dto.GroupDtos;
import com.xiqian.draw.domain.GameGroup;
import com.xiqian.draw.repository.GameGroupRepository;
import com.xiqian.draw.repository.GameRoundRepository;
import org.junit.jupiter.api.Test;

import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class GroupServiceTest {

    @Test
    void shouldRejectExplicitBlankNameWhenPatchingGroup() {
        GameGroupRepository groupRepository = mock(GameGroupRepository.class);
        UUID groupId = UUID.randomUUID();
        when(groupRepository.findById(groupId))
                .thenReturn(Optional.of(new GameGroup("一号厅", "1024")));

        GroupService service = new GroupService(
                groupRepository,
                mock(GameRoundRepository.class),
                mock(GroupCodeGenerator.class),
                mock(RoundMapper.class));
        GroupDtos.UpdateGroupRequest request =
                new GroupDtos.UpdateGroupRequest("   ", null, null, null);

        assertThatThrownBy(() -> service.update(groupId, request))
                .isInstanceOf(BadRequestException.class)
                .hasMessage("组局名称不能为空");
    }
}
