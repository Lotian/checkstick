import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { api } from '@/api/client'
import type { PublicGroupState } from '@/types'
import { useDrawStore } from './draw'

vi.mock('@/api/client', () => ({
  api: { get: vi.fn(), post: vi.fn() },
  errorMessage: () => '请求失败',
}))

vi.mock('@/utils/visitor', () => ({
  getVisitorId: () => 'a6bb7fd0-34a3-4c2f-8c7e-46276669a641',
}))

function groupState(code: string, name: string): PublicGroupState {
  return {
    groupId: code,
    groupName: name,
    groupCode: code,
    roundId: null,
    roundNumber: null,
    minPlayers: null,
    maxPlayers: null,
    roundStatus: null,
    drawnCount: 0,
    remainingCount: 0,
    result: null,
  }
}

describe('玩家入局状态', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.mocked(api.get).mockReset()
  })

  it('拒绝不完整组局码且不发送请求', async () => {
    const store = useDrawStore()

    await store.join('12')

    expect(store.error).toBe('请输入完整的4位数字组局码')
    expect(api.get).not.toHaveBeenCalled()
  })

  it('并发查询乱序返回时只采用最后一次选择', async () => {
    let resolveFirst!: (value: { data: PublicGroupState }) => void
    let resolveSecond!: (value: { data: PublicGroupState }) => void
    vi.mocked(api.get)
      .mockReturnValueOnce(new Promise((resolve) => { resolveFirst = resolve }) as never)
      .mockReturnValueOnce(new Promise((resolve) => { resolveSecond = resolve }) as never)
    const store = useDrawStore()

    const first = store.join('1024')
    const second = store.join('2048')
    resolveSecond({ data: groupState('2048', '二号厅') })
    await second
    resolveFirst({ data: groupState('1024', '一号厅') })
    await first

    expect(store.groupCode).toBe('2048')
    expect(store.state?.groupName).toBe('二号厅')
  })
})
