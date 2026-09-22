<script setup lang="ts">
import { computed } from 'vue'
import type { DrawResult } from '@/types'
import { taskSteps } from '@/utils/text'

const props = defineProps<{ result: DrawResult }>()
const steps = computed(() => taskSteps(props.result.taskText))
const roleClass = computed(() => `role-card--${props.result.roleType.toLowerCase()}`)
const figureSource = computed(() => {
  if (props.result.roleType === 'GROOM') return '/assets/papercut-groom.png'
  if (props.result.roleType === 'BRIDE') return '/assets/papercut-bride.png'
  return '/assets/shot-16.jpg'
})
</script>

<template>
  <article class="role-card" :class="roleClass">
    <div class="card-corner card-corner--tl" aria-hidden="true"></div>
    <div class="card-corner card-corner--br" aria-hidden="true"></div>
    <p class="role-eyebrow">红纸落名 · 命数已定</p>
    <div class="role-mark" aria-hidden="true">{{ result.roleName.slice(-1) }}</div>
    <h1>{{ result.roleName }}</h1>
    <p class="role-subtitle">
      {{ result.roleType === 'VILLAGER' ? '旁观喜事，静候因果' : '红线相牵，照签行事' }}
    </p>

    <div class="role-figure" :class="{ 'role-figure--photo': result.roleType === 'VILLAGER' }">
      <img :src="figureSource" :alt="`${result.roleName}身份形象`" />
    </div>

    <section class="task-section">
      <h2><span>壹</span> 今夜之事</h2>
      <ol v-if="steps.length" class="task-steps">
        <li v-for="(step, index) in steps" :key="step">
          <span>{{ String(index + 1).padStart(2, '0') }}</span>
          <p>{{ step }}</p>
        </li>
      </ol>
      <p v-else class="no-task">暂 · 无 · 任 · 务</p>
    </section>

    <section class="reward-section">
      <span class="reward-seal">赏</span>
      <div>
        <h2>线下赏礼</h2>
        <p>{{ result.rewardText || '请持此身份卡向工作人员确认' }}</p>
      </div>
    </section>
    <p class="card-note">此 签 仅 本 轮 有 效</p>
  </article>
</template>

