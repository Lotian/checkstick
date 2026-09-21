import { ref } from 'vue'
import { defineStore } from 'pinia'
import { api, clearCsrfToken, setCsrfToken } from '@/api/client'

export const useAuthStore = defineStore('auth', () => {
  const username = ref('')
  const authenticated = ref(false)
  const checked = ref(false)

  async function refreshCsrf() {
    // 登录、会话检查后令牌都会变化，必须重新取一次掩码令牌供后续写请求使用。
    const { data } = await api.get<{ token: string; headerName: string }>('/admin/auth/csrf')
    setCsrfToken(data.token, data.headerName)
  }

  async function check() {
    try {
      const { data } = await api.get('/admin/auth/me')
      await refreshCsrf()
      // 会话与 CSRF 令牌都准备完成后才切换登录态，避免页面进入无法提交写请求的半登录状态。
      username.value = data.username
      authenticated.value = true
    } catch {
      username.value = ''
      authenticated.value = false
      clearCsrfToken()
    } finally {
      checked.value = true
    }
  }

  async function login(loginUsername: string, password: string) {
    const { data } = await api.post('/admin/auth/login', { username: loginUsername, password })
    try {
      await refreshCsrf()
      username.value = data.username
      authenticated.value = true
      checked.value = true
    } catch (error) {
      // 登录接口成功但令牌初始化失败时回滚本地状态，让用户明确重试。
      username.value = ''
      authenticated.value = false
      clearCsrfToken()
      throw error
    }
  }

  async function logout() {
    try {
      await api.post('/admin/auth/logout')
    } catch {
      // 退出动作以清理本机状态为主；网络失败不应把用户困在管理页。
    } finally {
      // 即便网络在退出时中断，也先清除本地敏感状态；服务端会话最终由超时兜底。
      username.value = ''
      authenticated.value = false
      clearCsrfToken()
    }
  }

  return { username, authenticated, checked, check, login, logout }
})

