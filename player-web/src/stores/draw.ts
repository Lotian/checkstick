import { computed, ref } from 'vue'
import { defineStore } from 'pinia'
import { api, errorMessage } from '@/api/client'
import { normalizeGroupCode } from '@/utils/code'
import { getVisitorId } from '@/utils/visitor'
import type { DrawResult, PublicGroupState } from '@/types'

const GROUP_KEY = 'xiqian.group-code'

export const useDrawStore = defineStore('draw', () => {
  // 历史值可能是旧版 6 位字母数字码，统一规范化成 4 位数字
  const groupCode = ref(normalizeGroupCode(localStorage.getItem(GROUP_KEY)))
  const state = ref<PublicGroupState | null>(null)
  const result = ref<DrawResult | null>(null)
  const loading = ref(false)
  const drawing = ref(false)
  const error = ref('')

  const hasJoined = computed(() => state.value !== null)
  const canDraw = computed(
    () => state.value?.roundStatus === 'ACTIVE' && !result.value && !drawing.value,
  )

  async function join(code: string) {
    loading.value = true
    error.value = ''
    try {
      const normalized = normalizeGroupCode(code)
      const response = await api.get<PublicGroupState>(`/public/groups/${normalized}/state`, {
        headers: { 'X-Visitor-Id': getVisitorId() },
      })
      groupCode.value = normalized
      localStorage.setItem(GROUP_KEY, normalized)
      state.value = response.data
      result.value = response.data.result
    } catch (caught) {
      error.value = errorMessage(caught)
      state.value = null
    } finally {
      loading.value = false
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
      error.value = errorMessage(caught)
    } finally {
      drawing.value = false
    }
  }

  function leave() {
    state.value = null
    result.value = null
    error.value = ''
  }

  return { groupCode, state, result, loading, drawing, error, hasJoined, canDraw, join, draw, leave }
})

