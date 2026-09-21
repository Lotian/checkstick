<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import FortuneTube from '@/components/FortuneTube.vue'
import IdentityCard from '@/components/IdentityCard.vue'
import { useDrawStore } from '@/stores/draw'
import { isCompleteGroupCode, normalizeGroupCode } from '@/utils/code'

const store = useDrawStore()
const codeInput = ref(normalizeGroupCode(store.groupCode))
const showResult = computed(() => Boolean(store.result) && !store.drawing)

async function submitCode() {
  if (isCompleteGroupCode(codeInput.value)) {
    await store.join(codeInput.value)
  }
}

onMounted(() => {
  if (isCompleteGroupCode(codeInput.value)) store.join(codeInput.value)
})
</script>

<template>
  <main class="player-shell">
    <header class="brand-lockup">
      <span class="brand-thread" aria-hidden="true"></span>
      <p>纸上姻缘 · 一签入局</p>
      <h1><span>囍</span> 签</h1>
      <div class="brand-divider"><i></i><b>缘</b><i></i></div>
    </header>

    <section v-if="!store.hasJoined" class="join-panel panel-enter">
      <p class="vertical-note" aria-hidden="true">吉时已到</p>
      <div class="join-copy">
        <span class="section-number">入 / 局</span>
        <h2>请录组局暗号</h2>
        <p>四字为引，寻得今夜属于你的那一桌。</p>
      </div>
      <form @submit.prevent="submitCode">
        <label for="group-code">四位数字组局码</label>
        <input
          id="group-code"
          v-model="codeInput"
          maxlength="4"
          inputmode="numeric"
          autocomplete="off"
          placeholder="例如 1024"
          @input="codeInput = normalizeGroupCode(codeInput)"
        />
        <button class="ink-button" type="submit" :disabled="!isCompleteGroupCode(codeInput) || store.loading">
          {{ store.loading ? '正在寻局…' : '推门入局' }}
        </button>
      </form>
      <p v-if="store.error" class="error-banner" role="alert">{{ store.error }}</p>
    </section>

    <template v-else>
      <section class="round-ribbon panel-enter">
        <button type="button" class="text-button" @click="store.leave">更换组局</button>
        <div>
          <small>{{ store.state?.groupCode }}</small>
          <strong>{{ store.state?.groupName }}</strong>
        </div>
        <p v-if="store.state?.roundId">
          第 {{ store.state.roundNumber }} 轮 · 余 {{ store.state.remainingCount }} 签
          <template v-if="store.state.minPlayers">
            · 本局 {{ store.state.minPlayers }}~{{ store.state.maxPlayers }} 人
          </template>
        </p>
        <p v-else>尚未开签</p>
      </section>

      <IdentityCard v-if="showResult && store.result" :result="store.result" class="reveal-card" />

      <section v-else-if="!store.state?.roundId" class="waiting-panel panel-enter">
        <span class="waiting-glyph">候</span>
        <h2>吉时未至</h2>
        <p>工作人员尚未开新一轮，请稍候再试。</p>
        <button class="ink-button" type="button" @click="store.join(store.groupCode)">再探一次</button>
      </section>

      <section v-else-if="store.state.roundStatus === 'FULL'" class="waiting-panel panel-enter">
        <span class="waiting-glyph">满</span>
        <h2>本轮签尽</h2>
        <p>此轮身份均已有主，请等待工作人员开新一轮。</p>
        <button class="ink-button" type="button" @click="store.join(store.groupCode)">查看新轮</button>
      </section>

      <section v-else-if="store.state.roundStatus === 'CLOSED'" class="waiting-panel panel-enter">
        <span class="waiting-glyph">封</span>
        <h2>本轮已封签</h2>
        <p>本轮已经结束，请等待工作人员开启下一轮。</p>
        <button class="ink-button" type="button" @click="store.join(store.groupCode)">查看新轮</button>
      </section>

      <FortuneTube
        v-else
        :drawing="store.drawing"
        :disabled="!store.canDraw"
        @draw="store.draw"
      />

      <p v-if="store.error" class="error-banner floating-error" role="alert">
        {{ store.error }}
        <button type="button" @click="store.error = ''">知道了</button>
      </p>
    </template>

    <footer>身份一经抽取，本轮不再更改</footer>
  </main>
</template>
