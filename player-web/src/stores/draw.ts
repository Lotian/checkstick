import { computed, ref } from 'vue'
import { defineStore } from 'pinia'
import { api, errorMessage } from '@/api/client'
import { isCompleteGroupCode, normalizeGroupCode } from '@/utils/code'
import { getVisitorId } from '@/utils/visitor'
import type { DrawResult, PublicGroupState } from '@/types'

/** 早期版本用来「记住上次输入过的组局码」的 localStorage 键，现已废弃。 */
const LEGACY_GROUP_KEY = 'xiqian.group-code'

/**
 * 组局码不在本地记忆，每次进来都是空输入框。
 *
 * 二维码固定不变，玩家每次扫码后都必须自己输入桌上告知的组局码。一旦预填，
 * 玩家看到的就是上一个局的码（例如 5698），既有串局风险，也会让人误以为
 * 那是系统给的默认值。
 *
 * 早期版本会把码写进 localStorage 并在下次进入时预填输入框，
 * 所以这里做一次清理，把残留在老用户手机里的数据删掉。
 */
function forgetLegacyGroupCode() {
  try {
    localStorage.removeItem(LEGACY_GROUP_KEY)
  } catch {
    // 隐私模式等禁用 localStorage 的环境：本来就没存进去，忽略即可。
  }
}

export const useDrawStore = defineStore('draw', () => {
  forgetLegacyGroupCode()

  // 空字符串起步：组局码只能由玩家自己输入
  const groupCode = ref('')
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
    // 连组局码一起清掉：回到入局页就是全空的，不会顺手把上一个局带回来
    groupCode.value = ''
  }

  return { groupCode, state, result, loading, drawing, error, hasJoined, canDraw, join, draw, leave }
})

