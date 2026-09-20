import axios from 'axios'

export const api = axios.create({
  baseURL: '/api',
  timeout: 10_000,
})

export function errorMessage(error: unknown): string {
  if (axios.isAxiosError(error)) {
    return error.response?.data?.message || '连接现场服务器失败，请稍后重试'
  }
  return '发生了意外错误，请稍后重试'
}

