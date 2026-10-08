import axios from 'axios'

export const api = axios.create({
  baseURL: '/api',
  timeout: 12_000,
  withCredentials: true,
  // 后端使用 Spring Security 默认的异或掩码令牌（BREACH 防护）：
  // Cookie 里保存的是原始令牌，只有 /admin/auth/csrf 下发的掩码令牌才能通过校验。
  // 因此不能让 axios 自己从 Cookie 派生请求头，改为显式携带 refreshCsrf() 拿到的令牌。
  withXSRFToken: false,
})

let csrfToken = ''
let csrfHeaderName = 'X-XSRF-TOKEN'
const CSRF_ENDPOINT = '/admin/auth/csrf'
const SAFE_METHODS = new Set(['get', 'head', 'options'])

/**
 * 网络层没拿到响应时可以安全重放的请求方法。
 *
 * 判据是「重复执行一次结果相同」：PUT / PATCH 传的是绝对值，GET 无副作用，都可以重放。
 * POST 一律不重试——建局、开轮、封签都会产生新记录，重放等于重复开一局。
 */
const REPLAYABLE_METHODS = new Set(['get', 'head', 'options', 'put', 'patch', 'delete'])

/** 重试前的等待时间：足够跨过后端重启的那一两秒，又不至于让人以为卡住了。 */
const NETWORK_RETRY_DELAY_MS = 600

const delay = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms))

export function setCsrfToken(token: string, headerName?: string) {
  csrfToken = token ?? ''
  if (headerName) csrfHeaderName = headerName
}

export function clearCsrfToken() {
  csrfToken = ''
}

api.interceptors.request.use((config) => {
  if (csrfToken) config.headers.set(csrfHeaderName, csrfToken)
  return config
})

type RetriableConfig = { __csrfRetried?: boolean; __networkRetried?: boolean }

api.interceptors.response.use(
  (response) => response,
  async (error: unknown) => {
    if (!axios.isAxiosError(error)) {
      return await Promise.reject(error)
    }

    const config = error.config as (NonNullable<typeof error.config> & RetriableConfig) | undefined
    const method = config?.method?.toLowerCase() ?? 'get'

    // ① 完全没有响应：现场 WiFi 抖动，或后端正好在重启的那几秒。
    //    这种情况重放一次通常就好了，比直接弹「连接不到现场服务器」有用得多。
    if (config && !error.response && REPLAYABLE_METHODS.has(method) && !config.__networkRetried) {
      config.__networkRetried = true
      await delay(NETWORK_RETRY_DELAY_MS)
      return await api.request(config)
    }

    // ② 写请求 403：多半是 CSRF 令牌过期，刷新令牌后重放一次。
    //    刷新接口本身与普通 GET 不参与重试，从而避免服务异常时递归请求 /csrf。
    if (
      error.response?.status === 403 &&
      config &&
      !SAFE_METHODS.has(method) &&
      config.url !== CSRF_ENDPOINT &&
      !config.__csrfRetried
    ) {
      config.__csrfRetried = true
      try {
        const { data } = await api.get<{ token: string; headerName: string }>(CSRF_ENDPOINT)
        setCsrfToken(data.token, data.headerName)
        return await api.request(config)
      } catch {
        return await Promise.reject(error)
      }
    }

    return await Promise.reject(error)
  },
)

export function errorMessage(error: unknown): string {
  if (axios.isAxiosError(error)) {
    const data = error.response?.data as { message?: string; code?: string } | undefined
    if (data?.message) return data.message
    if (error.response) {
      const code = data?.code ? ` · ${data.code}` : ''
      return `请求失败（HTTP ${error.response.status}${code}）`
    }
    if (error.code === 'ECONNABORTED') return '请求超时，请检查现场网络后重试'
    return '连接不到现场服务器，请确认后端已启动'
  }
  return '发生了意外错误，请稍后重试'
}
