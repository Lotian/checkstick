import { beforeEach, describe, expect, it } from 'vitest'
import { api, clearCsrfToken, errorMessage, setCsrfToken } from './client'

function captureRequestHeader(name = 'X-XSRF-TOKEN') {
  const seen: { value: string | undefined } = { value: undefined }
  api.defaults.adapter = async (config) => {
    seen.value = config.headers.get(name) as string | undefined
    return { data: {}, status: 200, statusText: 'OK', headers: {}, config }
  }
  return seen
}

describe('管理端 CSRF 请求头', () => {
  beforeEach(() => {
    clearCsrfToken()
  })

  it('把 /csrf 下发的掩码令牌放进写请求的请求头', async () => {
    const seen = captureRequestHeader()
    setCsrfToken('masked-token', 'X-XSRF-TOKEN')

    await api.post('/admin/groups', { name: '一号厅' })

    expect(seen.value).toBe('masked-token')
  })

  it('未取得令牌时不携带该请求头（例如 CSRF 豁免的登录请求）', async () => {
    const seen = captureRequestHeader()
    seen.value = 'unchanged'

    await api.post('/admin/auth/login', { username: 'admin', password: 'x' })

    expect(seen.value).toBeUndefined()
  })

  it('服务端返回空 message 时给出可定位的状态码', () => {
    const error = {
      isAxiosError: true,
      response: { status: 403, data: { code: 'FORBIDDEN', message: '' } },
    }

    expect(errorMessage(error)).toBe('请求失败（HTTP 403 · FORBIDDEN）')
  })
})
