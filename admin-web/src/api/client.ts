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

type RetriableConfig = { __csrfRetried?: boolean }

api.interceptors.response.use(
  (response) => response,
  async (error: unknown) => {
    if (axios.isAxiosError(error) && error.response?.status === 403) {
      const config = error.config as (NonNullable<typeof error.config> & RetriableConfig) | undefined
      const method = config?.method?.toLowerCase() ?? 'get'
      const isUnsafeRequest = !SAFE_METHODS.has(method)

      // 仅写请求可能因 CSRF 失效而返回 403。刷新接口本身与普通 GET 不参与重试，
      // 从而避免服务异常时递归请求 /csrf。
      if (config && isUnsafeRequest && config.url !== CSRF_ENDPOINT && !config.__csrfRetried) {
        config.__csrfRetried = true
        try {
          const { data } = await api.get<{ token: string; headerName: string }>(CSRF_ENDPOINT)
          setCsrfToken(data.token, data.headerName)
          return await api.request(config)
        } catch {
          return await Promise.reject(error)
        }
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
