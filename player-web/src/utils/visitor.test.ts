import { describe, expect, it, vi } from 'vitest'
import { createVisitorId, getVisitorId } from './visitor'

describe('createVisitorId', () => {
  it('优先使用浏览器 randomUUID', () => {
    const expected = 'a6bb7fd0-34a3-4c2f-8c7e-46276669a641'
    vi.stubGlobal('crypto', {
      randomUUID: () => expected,
      getRandomValues: vi.fn(),
    })
    expect(createVisitorId()).toBe(expected)
    vi.unstubAllGlobals()
  })

  it('在 HTTP 环境生成规范 UUID v4', () => {
    vi.stubGlobal('crypto', {
      getRandomValues: (bytes: Uint8Array) => {
        bytes.fill(17)
        return bytes
      },
    })
    expect(createVisitorId()).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/)
    vi.unstubAllGlobals()
  })

  it('发现损坏的历史标识时自动生成并保存新 UUID', () => {
    const saved = new Map([['xiqian.visitor-id', 'broken-id']])
    vi.stubGlobal('localStorage', {
      getItem: (key: string) => saved.get(key) ?? null,
      setItem: (key: string, value: string) => saved.set(key, value),
    })
    vi.stubGlobal('crypto', {
      randomUUID: () => 'a6bb7fd0-34a3-4c2f-8c7e-46276669a641',
      getRandomValues: vi.fn(),
    })

    expect(getVisitorId()).toBe('a6bb7fd0-34a3-4c2f-8c7e-46276669a641')
    expect(saved.get('xiqian.visitor-id')).toBe('a6bb7fd0-34a3-4c2f-8c7e-46276669a641')
    vi.unstubAllGlobals()
  })

  it('浏览器禁用 localStorage 时仍能返回临时游客标识', () => {
    vi.stubGlobal('localStorage', {
      getItem: () => { throw new Error('storage disabled') },
      setItem: () => { throw new Error('storage disabled') },
    })
    vi.stubGlobal('crypto', {
      randomUUID: () => 'a6bb7fd0-34a3-4c2f-8c7e-46276669a641',
      getRandomValues: vi.fn(),
    })

    expect(getVisitorId()).toBe('a6bb7fd0-34a3-4c2f-8c7e-46276669a641')
    vi.unstubAllGlobals()
  })
})

