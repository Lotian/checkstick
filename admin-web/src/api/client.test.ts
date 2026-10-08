import axios from 'axios'
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

/**
 * 让适配器先失败若干次「网络错误」（完全没有响应），再返回成功。
 * 返回的对象会记录实际发起的请求次数，用来断言有没有重放。
 */
function adapterWithNetworkFailures(failures: number) {
  const state = { calls: 0 }
  api.defaults.adapter = async (config) => {
    state.calls += 1
    if (state.calls <= failures) {
      throw new axios.AxiosError('Network Error', 'ERR_NETWORK', config)
    }
    return { data: { ok: true }, status: 200, statusText: 'OK', headers: {}, config }
  }
  return state
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

  it('普通 GET 返回 403 时不递归刷新 CSRF 令牌', async () => {
    let requestCount = 0
    api.defaults.adapter = async (config) => {
      requestCount += 1
      const error = new axios.AxiosError('Forbidden', 'ERR_BAD_RESPONSE', config, undefined, {
        data: {}, status: 403, statusText: 'Forbidden', headers: {}, config,
      })
      throw error
    }

    await expect(api.get('/admin/groups')).rejects.toBeTruthy()
    expect(requestCount).toBe(1)
  })
})

describe('管理端网络中断自动重放', () => {
  it('保存身份内容（PUT）遇到瞬时断连时重放一次，不打扰现场', async () => {
    const state = adapterWithNetworkFailures(1)

    const response = await api.put('/admin/role-templates', { templates: [] })

    expect(response.status).toBe(200)
    expect(state.calls).toBe(2)
  })

  it('查询类请求（GET）同样可以重放', async () => {
    const state = adapterWithNetworkFailures(1)

    await api.get('/admin/role-templates')

    expect(state.calls).toBe(2)
  })

  it('建局 / 开轮（POST）绝不重放，避免凭空多出一局', async () => {
    const state = adapterWithNetworkFailures(1)

    await expect(api.post('/admin/groups', { name: '一号厅' })).rejects.toBeTruthy()
    expect(state.calls).toBe(1)
  })

  it('重放只做一次，仍然失败就如实报错', async () => {
    const state = adapterWithNetworkFailures(Number.POSITIVE_INFINITY)

    const error = await api
      .put('/admin/role-templates', { templates: [] })
      .catch((caught: unknown) => caught)

    expect(state.calls).toBe(2)
    expect(errorMessage(error)).toBe('连接不到现场服务器，请确认后端已启动')
  })
})
