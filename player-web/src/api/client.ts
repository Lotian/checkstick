import axios from 'axios'

export const api = axios.create({
  baseURL: '/api',
  timeout: 10_000,
})

export function errorMessage(error: unknown): string {
  if (axios.isAxiosError(error)) {
    const data = error.response?.data as { message?: string; code?: string } | undefined
    if (data?.message) return data.message
    if (error.response) return `请求失败（HTTP ${error.response.status}），请稍后重试`
    if (error.code === 'ECONNABORTED') return '请求超时，请检查现场网络后重试'
    return '连接现场服务器失败，请稍后重试'
  }
  return '发生了意外错误，请稍后重试'
}

