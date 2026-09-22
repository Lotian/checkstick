<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import FortuneTube from '@/components/FortuneTube.vue'
import IdentityCard from '@/components/IdentityCard.vue'
import { api } from '@/api/client'
import { useDrawStore } from '@/stores/draw'
import type { StoryIntro } from '@/types'
import { isCompleteGroupCode, normalizeGroupCode } from '@/utils/code'

const DEFAULT_STORY: StoryIntro = {
  title: '纸嫁衣',
  subtitle: '这一次，换你走进故事里',
  introText: '奘铃村，一座被冥婚诅咒困住百年的村子。戏子梁少平宁死不肯送祝小红出嫁，横死在残坟之前；祝小红化为一缕阴魂，至今不散。从此每逢阴时，村中红烛亮起、纸人成行，静静等待 "新的新娘" 入殓。你将穿过红妆铜镜台、拜过喜堂怨偶、赴过阴间酒席 —— 十三重场景，步步惊心。记住：唯有祝小红，可平息残坟前煞金刚的怨恨；阴间之食，浆糊豆饼可安饥肠……当你踏进奘铃村那一刻起，故事，就已经开始了……',
  warningText: '本惊奇屋含惊吓与追逐，1.2 米以下儿童、老人、孕妇、心脏病患者请勿入内；感到不适可随时示意工作人员退出；场内禁止拍照录像。',
}

const store = useDrawStore()
const stage = ref<'intro' | 'game'>('intro')
const codeInput = ref(normalizeGroupCode(store.groupCode))
const story = reactive<StoryIntro>({ ...DEFAULT_STORY })
const showResult = computed(() => Boolean(store.result) && !store.drawing)
const codeDigits = computed(() => Array.from({ length: 4 }, (_, index) => codeInput.value[index] ?? ''))

const screenState = computed(() => {
  if (stage.value === 'intro') return 'intro'
  if (!store.hasJoined) return 'join'
  if (showResult.value && store.result) return store.result.roleType.toLowerCase()
  if (!store.state?.roundId) return 'waiting'
  if (store.state.roundStatus === 'FULL' || store.state.roundStatus === 'CLOSED') return 'full'
  return 'drawing'
})

async function loadStory() {
  try {
    const { data } = await api.get<StoryIntro>('/public/story-intro')
    Object.assign(story, data)
  } catch {
    // 服务暂不可用时展示内置文案，不能让扫码入口停在空白页。
  }
}

async function submitCode() {
  if (isCompleteGroupCode(codeInput.value)) await store.join(codeInput.value)
}

function leaveGroup() {
  store.leave()
  codeInput.value = normalizeGroupCode(store.groupCode)
}

onMounted(loadStory)
</script>

<template>
  <main class="cinema-screen" :data-state="screenState">
    <div class="cinema-bg" aria-hidden="true"></div>
    <div class="cinema-veil" aria-hidden="true"></div>

    <div class="cinema-content">
      <section v-if="stage === 'intro'" class="story-screen panel-enter">
        <header class="mini-brand">
          <span>囍</span>
          <p>纸 上 姻 缘 · 一 签 入 局</p>
        </header>
        <div class="story-copy">
          <p class="story-kicker">今 夜 · 入 戏</p>
          <h1>{{ story.title }}</h1>
          <h2>{{ story.subtitle }}</h2>
          <p class="story-intro">{{ story.introText }}</p>
          <div v-if="story.warningText" class="story-warning">
            <strong>入场须知</strong>
            <p>{{ story.warningText }}</p>
          </div>
        </div>
        <button class="cinema-button" type="button" @click="stage = 'game'">下 一 步</button>
        <p class="story-footnote">继续即表示已阅读并知悉入场须知</p>
      </section>

      <section v-else-if="!store.hasJoined" class="join-screen panel-enter">
        <header class="wordmark">
          <h1><i>囍</i>签</h1>
          <p>纸 上 姻 缘 · 一 签 入 局</p>
        </header>
        <div class="join-copy">
          <p class="story-kicker">寻 局</p>
          <h2>请录组局暗号</h2>
          <p>四字为引，寻得今夜属于你的那一桌。</p>
        </div>
        <form @submit.prevent="submitCode">
          <label class="sr-only" for="group-code">四位数字组局码</label>
          <div class="code-entry">
            <i v-for="(digit, index) in codeDigits" :key="index" :class="{ empty: !digit }">
              {{ digit || '·' }}
            </i>
            <input
              id="group-code"
              v-model="codeInput"
              maxlength="4"
              inputmode="numeric"
              autocomplete="one-time-code"
              aria-describedby="group-code-help"
              @input="codeInput = normalizeGroupCode(codeInput)"
            />
          </div>
          <button class="cinema-button" type="submit" :disabled="!isCompleteGroupCode(codeInput) || store.loading">
            {{ store.loading ? '正 在 寻 局…' : '推 门 入 局' }}
          </button>
        </form>
        <p id="group-code-help" class="join-help">桌面立牌上有四位数字组局码</p>
        <p v-if="store.error" class="error-banner" role="alert">{{ store.error }}</p>
      </section>

      <template v-else>
        <section class="round-ribbon panel-enter">
          <button type="button" class="text-button" @click="leaveGroup">更换组局</button>
          <div><small>{{ store.state?.groupCode }}</small><strong>{{ store.state?.groupName }}</strong></div>
          <p v-if="store.state?.roundId">第 {{ store.state.roundNumber }} 轮 · 余 {{ store.state.remainingCount }} 签</p>
          <p v-else>尚未开签</p>
        </section>

        <IdentityCard v-if="showResult && store.result" :result="store.result" class="reveal-card" />

        <section v-else-if="!store.state?.roundId" class="status-screen panel-enter">
          <img src="/assets/papercut-cry.png" alt="" />
          <h2>吉时未至</h2>
          <p>工作人员尚未开新一轮，请在厅内稍候。</p>
          <button class="cinema-button ghost" type="button" @click="store.join(store.groupCode)">再 探 一 次</button>
        </section>

        <section v-else-if="store.state.roundStatus === 'FULL'" class="status-screen panel-enter">
          <img src="/assets/papercut-cry.png" alt="" />
          <h2>本轮签尽</h2>
          <p>此轮身份均已有主，请等待工作人员开新一轮。</p>
          <button class="cinema-button ghost" type="button" @click="store.join(store.groupCode)">查 看 新 轮</button>
        </section>

        <section v-else-if="store.state.roundStatus === 'CLOSED'" class="status-screen panel-enter">
          <img src="/assets/papercut-cry.png" alt="" />
          <h2>本轮已封签</h2>
          <p>本轮已经结束，请等待工作人员开启下一轮。</p>
          <button class="cinema-button ghost" type="button" @click="store.join(store.groupCode)">查 看 新 轮</button>
        </section>

        <FortuneTube v-else :drawing="store.drawing" :disabled="!store.canDraw" @draw="store.draw" />

        <p v-if="store.error" class="error-banner floating-error" role="alert">
          {{ store.error }}
          <button type="button" @click="store.error = ''">知道了</button>
        </p>
      </template>
    </div>
    <div class="corner-seal" aria-hidden="true">囍</div>
  </main>
</template>
