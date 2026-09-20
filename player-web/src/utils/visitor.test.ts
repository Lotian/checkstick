import { describe, expect, it, vi } from 'vitest'
import { createVisitorId } from './visitor'

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
})

