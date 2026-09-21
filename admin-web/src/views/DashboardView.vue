<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { api, errorMessage } from '@/api/client'
import { useAuthStore } from '@/stores/auth'
import StatCard from '@/components/StatCard.vue'
import QrPanel from '@/components/QrPanel.vue'
import type { GameGroup, PlayerRange, RoleTemplate, RoundDetail, RoundListItem } from '@/types'

const MIN_PLAYERS_LIMIT = 2
const MAX_PLAYERS_LIMIT = 20

// 页面级依赖与核心业务数据
const auth = useAuthStore()
const router = useRouter()
const groups = ref<GameGroup[]>([])
const selectedGroupId = ref('')
const round = ref<RoundDetail | null>(null)

// 异步操作状态：分别控制按钮，避免一个操作阻塞整张控制台。
const loading = ref(false)
const starting = ref(false)
const closing = ref(false)

// 弹层与表单状态
const createVisible = ref(false)
const templateVisible = ref(false)
const historyVisible = ref(false)
const rangeVisible = ref(false)
const newGroupName = ref('')
const newGroupRange = reactive({ minPlayers: 5, maxPlayers: 8 })
const rangeForm = reactive({ minPlayers: 5, maxPlayers: 8 })
const templates = ref<RoleTemplate[]>([])
const history = ref<RoundListItem[]>([])
let eventSource: EventSource | null = null
let selectionSequence = 0

const selectedGroup = computed(() => groups.value.find((group) => group.id === selectedGroupId.value) ?? null)
const progress = computed(() => {
  if (!round.value?.maxPlayers) return 0
  return Math.round((round.value.drawnCount / round.value.maxPlayers) * 100)
})
const groom = computed(() => round.value?.draws.find((draw) => draw.roleType === 'GROOM'))
const bride = computed(() => round.value?.draws.find((draw) => draw.roleType === 'BRIDE'))

/** 把人数区间显示成「5~8人」或「6人」（上下限相同时）。 */
function sizeLabel(range: PlayerRange | null | undefined) {
  if (!range) return '—'
  return range.minPlayers === range.maxPlayers
    ? `${range.maxPlayers}人`
    : `${range.minPlayers}~${range.maxPlayers}人`
}

function formatTime(value?: string | null) {
  if (!value) return '—'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return '—'
  return new Intl.DateTimeFormat('zh-CN', {
    month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit',
  }).format(date)
}

/** 刷新组局列表，并尽量保留当前选择。 */
async function loadGroups(keepSelection = true) {
  loading.value = true
  try {
    const { data } = await api.get<GameGroup[]>('/admin/groups')
    groups.value = data
    const stillExists = data.some((group) => group.id === selectedGroupId.value)
    if (!keepSelection || !stillExists) selectedGroupId.value = data[0]?.id ?? ''
    await selectGroup(selectedGroupId.value)
  } catch (error) {
    ElMessage.error(errorMessage(error))
  } finally {
    loading.value = false
  }
}

async function selectGroup(groupId: string) {
  const currentSequence = ++selectionSequence
  selectedGroupId.value = groupId
  round.value = null
  closeEvents()

  const group = groups.value.find((item) => item.id === groupId)
  if (!group?.currentRound) return

  try {
    const data = await fetchRound(group.currentRound.id)
    // 用户可能在请求返回前切换了多次组局；过期响应不得覆盖最新选择。
    if (currentSequence !== selectionSequence || selectedGroupId.value !== groupId) return
    round.value = data
    connectEvents(group.currentRound.id)
  } catch (error) {
    if (currentSequence === selectionSequence) ElMessage.error(errorMessage(error))
  }
}

async function fetchRound(roundId: string) {
  const { data } = await api.get<RoundDetail>(`/admin/rounds/${roundId}`)
  return data
}

/** 建立当前轮次的进度流；闭包中的 source 用于识别已被替换的旧连接。 */
function connectEvents(roundId: string) {
  closeEvents()
  const source = new EventSource(`/api/admin/rounds/${roundId}/events`, { withCredentials: true })
  eventSource = source

  source.addEventListener('progress', (event) => {
    if (eventSource !== source) return

    let nextRound: RoundDetail
    try {
      nextRound = JSON.parse((event as MessageEvent).data) as RoundDetail
    } catch {
      // 单条损坏消息交给下一次 SSE 事件或错误快照恢复，不中断整个页面。
      return
    }
    if (nextRound.id !== roundId) return

    round.value = nextRound
    const group = groups.value.find((item) => item.id === selectedGroupId.value)
    if (group?.currentRound && round.value) {
      group.currentRound.drawnCount = round.value.drawnCount
      group.currentRound.status = round.value.status
    }
  })
  source.onerror = async () => {
    // EventSource 自带重连，这里只补一次快照避免进度停留在旧值。
    try {
      const latest = await fetchRound(roundId)
      if (eventSource === source) round.value = latest
    } catch {
      // 重连期间保持最后一份可用快照，避免瞬时网络波动清空现场数据。
    }
  }
}

function closeEvents() {
  eventSource?.close()
  eventSource = null
}

function validateRange(range: PlayerRange): string {
  if (range.minPlayers < MIN_PLAYERS_LIMIT) return `最低人数不能少于 ${MIN_PLAYERS_LIMIT} 人`
  if (range.maxPlayers > MAX_PLAYERS_LIMIT) return `最高人数不能超过 ${MAX_PLAYERS_LIMIT} 人`
  if (range.maxPlayers < range.minPlayers) return '最高人数不能小于最低人数'
  return ''
}

async function createGroup() {
  if (!newGroupName.value.trim()) return
  const invalid = validateRange(newGroupRange)
  if (invalid) {
    ElMessage.warning(invalid)
    return
  }
  try {
    const { data } = await api.post<GameGroup>('/admin/groups', {
      name: newGroupName.value.trim(),
      minPlayers: newGroupRange.minPlayers,
      maxPlayers: newGroupRange.maxPlayers,
    })
    createVisible.value = false
    newGroupName.value = ''
    await loadGroups(false)
    await selectGroup(data.id)
    ElMessage.success(`组局已创建，组局码 ${data.code}（${sizeLabel(data)}）`)
  } catch (error) {
    ElMessage.error(errorMessage(error))
  }
}

function openRangeDialog() {
  if (!selectedGroup.value) return
  rangeForm.minPlayers = selectedGroup.value.minPlayers
  rangeForm.maxPlayers = selectedGroup.value.maxPlayers
  rangeVisible.value = true
}

async function saveRange() {
  if (!selectedGroup.value) return
  const invalid = validateRange(rangeForm)
  if (invalid) {
    ElMessage.warning(invalid)
    return
  }
  try {
    const { data } = await api.patch<GameGroup>(`/admin/groups/${selectedGroup.value.id}`, {
      minPlayers: rangeForm.minPlayers,
      maxPlayers: rangeForm.maxPlayers,
    })
    Object.assign(selectedGroup.value, data)
    rangeVisible.value = false
    ElMessage.success(`人数区间已保存：${sizeLabel(data)}（下一轮生效）`)
  } catch (error) {
    ElMessage.error(errorMessage(error))
  }
}

async function startRound() {
  const group = selectedGroup.value
  if (!group) return
  try {
    await ElMessageBox.confirm(
      `即将开启新一轮（${sizeLabel(group)}），当前轮次会立即关闭。`,
      '确认开新轮',
      { confirmButtonText: '开新轮', cancelButtonText: '取消', type: 'warning' },
    )
    starting.value = true
    const { data } = await api.post<RoundDetail>(`/admin/groups/${group.id}/rounds`)
    round.value = data
    connectEvents(data.id)
    await loadGroups()
    ElMessage.success(`第 ${data.roundNumber} 轮已经开始（${sizeLabel(data)}）`)
  } catch (error) {
    if (error !== 'cancel') ElMessage.error(errorMessage(error))
  } finally {
    starting.value = false
  }
}

async function closeRound() {
  const current = round.value
  if (!current) return
  try {
    await ElMessageBox.confirm(
      `本轮已抽 ${current.drawnCount} 人，封签后剩余 ${current.remainingCount} 个签位作废，本轮不再接受抽签。`,
      '确认提前封签',
      { confirmButtonText: '封签', cancelButtonText: '再看看', type: 'warning' },
    )
    closing.value = true
    const { data } = await api.post<RoundDetail>(`/admin/rounds/${current.id}/close`)
    round.value = data
    closeEvents()
    await loadGroups()
    ElMessage.success('本轮已封签')
  } catch (error) {
    if (error !== 'cancel') ElMessage.error(errorMessage(error))
  } finally {
    closing.value = false
  }
}

async function toggleGroup(group: GameGroup) {
  try {
    const { data } = await api.patch<GameGroup>(`/admin/groups/${group.id}`, { enabled: !group.enabled })
    Object.assign(group, data)
    ElMessage.success(data.enabled ? '组局已启用' : '组局已停用')
  } catch (error) {
    ElMessage.error(errorMessage(error))
  }
}

async function openTemplates() {
  try {
    const { data } = await api.get<RoleTemplate[]>('/admin/role-templates')
    templates.value = data
    templateVisible.value = true
  } catch (error) {
    ElMessage.error(errorMessage(error))
  }
}

async function saveTemplates() {
  try {
    const payload = templates.value.map(({ roleType, taskText, rewardText }) => ({
      roleType, taskText, rewardText,
    }))
    const { data } = await api.put<RoleTemplate[]>('/admin/role-templates', { templates: payload })
    templates.value = data
    templateVisible.value = false
    ElMessage.success('身份任务和奖励已经保存')
  } catch (error) {
    ElMessage.error(errorMessage(error))
  }
}

async function openHistory() {
  if (!selectedGroup.value) return
  try {
    const { data } = await api.get<RoundListItem[]>(`/admin/groups/${selectedGroup.value.id}/rounds`)
    history.value = data
    historyVisible.value = true
  } catch (error) {
    ElMessage.error(errorMessage(error))
  }
}

async function viewHistory(item: RoundListItem) {
  try {
    // 历史详情不是当前组局选择流程的一部分，先关闭旧流再加载指定轮次。
    selectionSequence += 1
    closeEvents()
    round.value = await fetchRound(item.id)
    historyVisible.value = false
    if (item.status !== 'CLOSED') connectEvents(item.id)
  } catch (error) {
    ElMessage.error(errorMessage(error))
  }
}

function exportCsv() {
  if (round.value) window.open(`/api/admin/rounds/${round.value.id}/export.csv`)
}

async function logout() {
  await auth.logout()
  await router.replace('/login')
}

onMounted(() => loadGroups(false))
onBeforeUnmount(closeEvents)
</script>

<template>
  <div class="admin-shell">
    <aside class="side-rail">
      <div class="admin-brand">
        <span>囍</span>
        <div><strong>囍签</strong><small>现场控签台</small></div>
      </div>

      <div class="rail-heading">
        <span>进行中的组局</span>
        <button type="button" aria-label="新建组局" @click="createVisible = true">＋</button>
      </div>
      <nav class="group-list" aria-label="组局列表">
        <button
          v-for="group in groups"
          :key="group.id"
          type="button"
          :class="{ active: group.id === selectedGroupId, disabled: !group.enabled }"
          @click="selectGroup(group.id)"
        >
          <span class="group-code">{{ group.code }}</span>
          <strong>{{ group.name }}</strong>
          <small v-if="group.currentRound">
            {{ group.currentRound.drawnCount }}/{{ group.currentRound.maxPlayers }} · 第{{ group.currentRound.roundNumber }}轮
          </small>
          <small v-else>{{ sizeLabel(group) }} · 尚未开轮</small>
        </button>
        <p v-if="!groups.length && !loading" class="empty-groups">还没有组局，点击右上角 ＋ 创建。</p>
      </nav>

      <div class="rail-actions">
        <button type="button" @click="openTemplates">身份内容</button>
        <button type="button" :disabled="!selectedGroup" @click="openHistory">历史轮次</button>
      </div>
      <div class="admin-profile">
        <span>{{ auth.username.slice(0, 1).toUpperCase() }}</span>
        <div><strong>{{ auth.username }}</strong><small>单管理员</small></div>
        <button type="button" @click="logout">退出</button>
      </div>
    </aside>

    <main class="admin-main">
      <header class="topbar">
        <div>
          <p>LIVE CEREMONY CONSOLE</p>
          <h1>{{ selectedGroup?.name ?? '选择或新建一个组局' }}</h1>
        </div>
        <div v-if="selectedGroup" class="topbar-code">
          <span>玩家组局码</span><strong>{{ selectedGroup.code }}</strong>
        </div>
      </header>

      <template v-if="selectedGroup">
        <section class="command-bar">
          <div>
            <span class="live-dot" :class="{ offline: !round || round.status === 'CLOSED' }"></span>
            <p v-if="round">第 {{ round.roundNumber }} 轮 · 本局 {{ sizeLabel(round) }}</p>
            <p v-else>等待开轮 · 本局 {{ sizeLabel(selectedGroup) }}</p>
          </div>
          <div class="command-actions">
            <el-button
              v-if="round && round.status === 'ACTIVE'"
              type="warning"
              plain
              :loading="closing"
              :disabled="!round.canCloseEarly"
              :title="round.canCloseEarly ? '' : `至少抽满 ${round.minPlayers} 人才能封签`"
              @click="closeRound"
            >
              提前封签{{ round.canCloseEarly ? '' : `（需满${round.minPlayers}人）` }}
            </el-button>
            <el-button type="primary" :disabled="starting || !selectedGroup.enabled" @click="startRound">
              开新轮（{{ sizeLabel(selectedGroup) }}）
            </el-button>
            <el-dropdown trigger="click">
              <el-button>组局设置</el-button>
              <template #dropdown>
                <el-dropdown-menu>
                  <el-dropdown-item @click="openRangeDialog">
                    人数区间（当前 {{ sizeLabel(selectedGroup) }}）
                  </el-dropdown-item>
                  <el-dropdown-item @click="toggleGroup(selectedGroup)">
                    {{ selectedGroup.enabled ? '停用组局' : '重新启用' }}
                  </el-dropdown-item>
                </el-dropdown-menu>
              </template>
            </el-dropdown>
          </div>
        </section>

        <section class="stats-grid">
          <StatCard label="已落签" :value="round?.drawnCount ?? 0" :note="round ? `共 ${round.maxPlayers} 支身份签` : '开轮后开始计数'" tone="red" />
          <StatCard label="余签" :value="round?.remainingCount ?? '—'" note="抽满最高人数自动封签" tone="gold" />
          <StatCard label="新郎" :value="groom ? '已出' : '未出'" :note="groom ? formatTime(groom.drawnAt) : '等待命签'" />
          <StatCard label="新娘" :value="bride ? '已出' : '未出'" :note="bride ? formatTime(bride.drawnAt) : '等待命签'" />
        </section>

        <section class="workspace-grid">
          <article class="progress-card">
            <div class="card-heading">
              <div><span class="panel-kicker">实时进度</span><h2>本轮落签录</h2></div>
              <span v-if="round" class="status-chip" :class="round.status.toLowerCase()">{{ round.status }}</span>
            </div>
            <div v-if="round" class="progress-layout">
              <div class="progress-ring" :style="{ '--progress': `${progress * 3.6}deg` }">
                <div><strong>{{ progress }}%</strong><span>{{ round.drawnCount }} / {{ round.maxPlayers }}</span></div>
              </div>
              <div class="progress-copy">
                <p>开始于 {{ formatTime(round.startedAt) }} · 本局 {{ sizeLabel(round) }}</p>
                <h3 v-if="round.status === 'FULL'">本轮已满员</h3>
                <h3 v-else-if="round.status === 'CLOSED'">本轮已封签</h3>
                <h3 v-else-if="round.canCloseEarly">已满 {{ round.minPlayers }} 人，可封签或继续等满 {{ round.maxPlayers }} 人</h3>
                <h3 v-else>还需 {{ round.minPlayers - round.drawnCount }} 人达到封签条件</h3>
                <span>SSE 实时同步 · 断线会自动恢复</span>
              </div>
            </div>
            <div v-else class="empty-round">
              <span>签</span><h3>尚未开轮</h3><p>点「开新轮」按 {{ sizeLabel(selectedGroup) }} 生成签位。</p>
            </div>
          </article>

          <QrPanel />
        </section>

        <section class="draw-table-card">
          <div class="card-heading">
            <div><span class="panel-kicker">身份明细</span><h2>已抽玩家</h2></div>
            <el-button v-if="round" plain @click="exportCsv">导出 CSV</el-button>
          </div>
          <el-table :data="round?.draws ?? []" empty-text="尚无玩家抽签">
            <el-table-column prop="slotIndex" label="签序" width="80" />
            <el-table-column label="身份" width="120">
              <template #default="scope">
                <span class="role-badge" :class="scope.row.roleType.toLowerCase()">{{ scope.row.roleName }}</span>
              </template>
            </el-table-column>
            <el-table-column prop="visitorId" label="游客标识" min-width="260" show-overflow-tooltip />
            <el-table-column label="抽取时间" width="160">
              <template #default="scope">{{ formatTime(scope.row.drawnAt) }}</template>
            </el-table-column>
          </el-table>
        </section>
      </template>

      <section v-else class="blank-stage">
        <span>局</span><h2>先立一局，再迎宾客</h2><p>新建组局后会获得固定的四位数字组局码，并可自定义一局的人数区间。</p>
        <el-button type="primary" @click="createVisible = true">新建组局</el-button>
      </section>
    </main>

    <el-dialog v-model="createVisible" title="新建组局" width="460px">
      <el-form label-position="top" @submit.prevent="createGroup">
        <el-form-item label="现场名称">
          <el-input v-model="newGroupName" maxlength="80" placeholder="例如：一号厅 · 红轿局" @keyup.enter="createGroup" />
        </el-form-item>
        <el-form-item label="本局人数区间">
          <div class="range-row">
            <el-input-number v-model="newGroupRange.minPlayers" :min="MIN_PLAYERS_LIMIT" :max="MAX_PLAYERS_LIMIT" />
            <span>~</span>
            <el-input-number v-model="newGroupRange.maxPlayers" :min="MIN_PLAYERS_LIMIT" :max="MAX_PLAYERS_LIMIT" />
            <small>签位按最高人数生成</small>
          </div>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="createVisible = false">取消</el-button>
        <el-button type="primary" :disabled="!newGroupName.trim()" @click="createGroup">生成组局码</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="rangeVisible" title="本局人数区间" width="460px">
      <p class="drawer-intro">
        签位数量按「最高人数」生成；抽满「最低人数」后即可点「提前封签」结束本轮。
        改动只影响之后新开的轮次。
      </p>
      <el-form label-position="top">
        <el-form-item label="最低人数 / 最高人数">
          <div class="range-row">
            <el-input-number v-model="rangeForm.minPlayers" :min="MIN_PLAYERS_LIMIT" :max="MAX_PLAYERS_LIMIT" />
            <span>~</span>
            <el-input-number v-model="rangeForm.maxPlayers" :min="MIN_PLAYERS_LIMIT" :max="MAX_PLAYERS_LIMIT" />
          </div>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="rangeVisible = false">取消</el-button>
        <el-button type="primary" @click="saveRange">保存</el-button>
      </template>
    </el-dialog>

    <el-drawer v-model="templateVisible" title="身份任务与奖励" size="min(720px, 92vw)">
      <p class="drawer-intro">
        每个身份一套内容，适用于所有人数的局；开轮时会复制这里的内容作为快照，修改不影响已开始的轮次。
      </p>
      <div class="template-list">
        <section v-for="template in templates" :key="template.id" class="template-item">
          <header>
            <strong>{{ template.roleName }}</strong>
          </header>
          <el-form label-position="top">
            <el-form-item label="任务步骤（每行一步）">
              <el-input
                v-model="template.taskText"
                type="textarea"
                :rows="3"
                :disabled="template.roleType === 'VILLAGER'"
                :placeholder="template.roleType === 'VILLAGER' ? '村民暂无任务' : '第一步\n第二步'"
              />
            </el-form-item>
            <el-form-item label="奖励文本">
              <el-input v-model="template.rewardText" type="textarea" :rows="2" />
            </el-form-item>
          </el-form>
        </section>
      </div>
      <div class="drawer-save"><el-button type="primary" size="large" @click="saveTemplates">保存全部内容</el-button></div>
    </el-drawer>

    <el-drawer v-model="historyVisible" title="历史轮次" size="520px">
      <div class="history-list">
        <button v-for="item in history" :key="item.id" type="button" @click="viewHistory(item)">
          <span>第 {{ item.roundNumber }} 轮</span>
          <strong>{{ sizeLabel(item) }} · {{ item.drawnCount }}/{{ item.maxPlayers }}</strong>
          <small>{{ formatTime(item.startedAt) }} · {{ item.status }}</small>
        </button>
      </div>
    </el-drawer>
  </div>
</template>
