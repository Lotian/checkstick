<script setup lang="ts">
defineProps<{ drawing: boolean; disabled: boolean }>()
defineEmits<{ draw: [] }>()
</script>

<template>
  <div class="fortune-stage" :class="{ 'is-drawing': drawing }">
    <div class="fortune-shadow" aria-hidden="true"></div>
    <div class="fortune-sticks" aria-hidden="true">
      <i v-for="index in 9" :key="index" :style="{ '--stick': index }"></i>
    </div>
    <div class="fortune-tube" aria-hidden="true">
      <span class="tube-glyph">囍</span>
      <span class="tube-knot"></span>
    </div>
    <button class="draw-button" type="button" :disabled="disabled" @click="$emit('draw')">
      <span>{{ drawing ? '签意流转中' : '启签' }}</span>
      <small>{{ drawing ? '请凝神片刻' : '一念既定，不可更改' }}</small>
    </button>
    <p class="motion-status" role="status" aria-live="polite">
      {{ drawing ? '签筒正在摇动，身份即将揭晓' : '' }}
    </p>
  </div>
</template>

