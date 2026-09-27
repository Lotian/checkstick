import { createPinia, setActivePinia } from 'pinia'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { api } from '@/api/client'
import type { PublicGroupState } from '@/types'
import { useDrawStore } from './draw'

/** 早期版本用来记忆组局码的 localStorage 键；现在只应被清理，不应再被写入。 */
const LEGACY_GROUP_KEY = 'xiqian.group-code'

vi.mock('@/api/client', () => ({
  api: { get: vi.fn(), post: vi.fn() },
  errorMessage: () => '请求失败',
}))

vi.mock('@/utils/visitor', () => ({
  getVisitorId: () => 'a6bb7fd0-34a3-4c2f-8c7e-46276669a641',
}))

/** 造一个可控的 localStorage，用于确认历史组局码既不被读取也不再被写入。 */
function stubLocalStorage(initial: Record<string, string>) {
  const map = new Map(Object.entries(initial))
  vi.stubGlobal('localStorage', {
    getItem: (key: string) => (map.has(key) ? (map.get(key) as string) : null),
    setItem: (key: string, value: string) => void map.set(key, String(value)),
    removeItem: (key: string) => void map.delete(key),
  })
  return map
}

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

  afterEach(() => {
    vi.unstubAllGlobals()
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

  // 回归：入局页输入框曾自动带出上一次用过的组局码（线上表现为默认显示 5698）
  describe('组局码不预填、不落地', () => {
    it('手机里还留着上次的组局码时，输入框初值仍为空，并清掉这份残留数据', () => {
      const map = stubLocalStorage({ [LEGACY_GROUP_KEY]: '5698' })

      const store = useDrawStore()

      expect(store.groupCode).toBe('')
      expect(map.has(LEGACY_GROUP_KEY)).toBe(false)
    })

    it('旧版 6 位字母数字码同样不会被带出来（曾显示成 98）', () => {
      const map = stubLocalStorage({ [LEGACY_GROUP_KEY]: 'RR98DN' })

      expect(useDrawStore().groupCode).toBe('')
      expect(map.has(LEGACY_GROUP_KEY)).toBe(false)
    })

    it('成功入局后也不会把组局码写回本地存储', async () => {
      const map = stubLocalStorage({})
      vi.mocked(api.get).mockResolvedValueOnce({ data: groupState('5698', '一号厅') } as never)
      const store = useDrawStore()

      await store.join('5698')

      expect(store.groupCode).toBe('5698')
      expect(map.size).toBe(0)
    })

    it('离开组局后组局码被清空，再进来自动重填的隐患一并消失', async () => {
      stubLocalStorage({})
      vi.mocked(api.get).mockResolvedValueOnce({ data: groupState('5698', '一号厅') } as never)
      const store = useDrawStore()

      await store.join('5698')
      store.leave()

      expect(store.groupCode).toBe('')
      expect(store.state).toBeNull()
    })
  })
})
