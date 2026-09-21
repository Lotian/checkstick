import { computed, ref } from 'vue'
import { defineStore } from 'pinia'
import { api, errorMessage } from '@/api/client'
import { isCompleteGroupCode, normalizeGroupCode } from '@/utils/code'
import { getVisitorId } from '@/utils/visitor'
import type { DrawResult, PublicGroupState } from '@/types'

const GROUP_KEY = 'xiqian.group-code'

/** 读取历史组局码时兼容禁用 localStorage 的浏览器环境。 */
function storedGroupCode(): string {
  try {
    return normalizeGroupCode(localStorage.getItem(GROUP_KEY))
  } catch {
    return ''
  }
}

function rememberGroupCode(code: string) {
  try {
    localStorage.setItem(GROUP_KEY, code)
  } catch {
    // 记忆失败不影响本次入局，用户刷新后重新输入即可。
  }
}

export const useDrawStore = defineStore('draw', () => {
  // 历史值可能是旧版 6 位字母数字码，统一规范化成 4 位数字
  const groupCode = ref(storedGroupCode())
  const state = ref<PublicGroupState | null>(null)
  const result = ref<DrawResult | null>(null)
  const loading = ref(false)
  const drawing = ref(false)
  const error = ref('')
  let joinSequence = 0

  const hasJoined = computed(() => state.value !== null)
  const canDraw = computed(
    () => state.value?.roundStatus === 'ACTIVE' && !result.value && !drawing.value,
  )

  async function join(code: string) {
    const normalized = normalizeGroupCode(code)
    if (!isCompleteGroupCode(normalized)) {
      error.value = '请输入完整的4位数字组局码'
      return
    }

    // 只允许最后一次查询更新界面，避免慢请求覆盖用户刚切换的新组局。
    const requestSequence = ++joinSequence
    loading.value = true
    error.value = ''
    try {
      const response = await api.get<PublicGroupState>(`/public/groups/${normalized}/state`, {
        headers: { 'X-Visitor-Id': getVisitorId() },
      })
      if (requestSequence !== joinSequence) return
      groupCode.value = normalized
      rememberGroupCode(normalized)
      state.value = response.data
      result.value = response.data.result
    } catch (caught) {
      if (requestSequence !== joinSequence) return
      error.value = errorMessage(caught)
      state.value = null
    } finally {
      if (requestSequence === joinSequence) loading.value = false
    }
  }

  async function draw() {
    if (!canDraw.value) return
    drawing.value = true
    error.value = ''
    const minimumAnimation = new Promise((resolve) => window.setTimeout(resolve, 1900))
    try {
      const [response] = await Promise.all([
        api.post<DrawResult>(`/public/groups/${groupCode.value}/draw`, null, {
          headers: { 'X-Visitor-Id': getVisitorId() },
        }),
        minimumAnimation,
      ])
      result.value = response.data
      if (state.value) {
        state.value.result = response.data
        state.value.drawnCount += 1
        state.value.remainingCount = Math.max(0, state.value.remainingCount - 1)
      }
    } catch (caught) {
      await minimumAnimation
      const drawError = errorMessage(caught)
      // 抽签冲突往往意味着轮次刚被封签或抽满；刷新快照，让按钮与服务端状态保持一致。
      await join(groupCode.value)
      error.value = drawError
    } finally {
      drawing.value = false
    }
  }

  function leave() {
    joinSequence += 1
    loading.value = false
    state.value = null
    result.value = null
    error.value = ''
  }

  return { groupCode, state, result, loading, drawing, error, hasJoined, canDraw, join, draw, leave }
})

