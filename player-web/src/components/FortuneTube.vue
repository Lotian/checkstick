<script setup lang="ts">
defineProps<{ drawing: boolean; disabled: boolean }>()
defineEmits<{ draw: [] }>()
</script>

<template>
  <section class="fortune-stage panel-enter" :class="{ 'is-drawing': drawing }">
    <img class="fortune-papercut" src="/assets/papercut-smile.png" alt="" />
    <h2>{{ drawing ? '签意流转' : '一签入命' }}</h2>
    <p>{{ drawing ? '请凝神片刻，一念既定，不可更改。' : '命签未启，请亲手揭开今夜身份。' }}</p>
    <button class="cinema-button" type="button" :disabled="disabled" @click="$emit('draw')">
      {{ drawing ? '正 在 启 签…' : '启 签' }}
    </button>
    <p class="motion-status" role="status" aria-live="polite">
      {{ drawing ? '正在为你抽取身份' : '' }}
    </p>
  </section>
</template>
