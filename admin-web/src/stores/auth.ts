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
      username.value = data.username
      authenticated.value = true
      await refreshCsrf()
    } catch {
      authenticated.value = false
      clearCsrfToken()
    } finally {
      checked.value = true
    }
  }

  async function login(loginUsername: string, password: string) {
    const { data } = await api.post('/admin/auth/login', { username: loginUsername, password })
    username.value = data.username
    authenticated.value = true
    checked.value = true
    await refreshCsrf()
  }

  async function logout() {
    await api.post('/admin/auth/logout')
    username.value = ''
    authenticated.value = false
    // 退出后服务端令牌已失效，下一次登录会重新下发。
    clearCsrfToken()
  }

  return { username, authenticated, checked, check, login, logout }
})

