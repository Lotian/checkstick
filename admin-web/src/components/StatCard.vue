<script setup lang="ts">
defineProps<{ label: string; value: string | number; note: string; tone?: 'red' | 'gold' | 'neutral' }>()
</script>

<template>
  <article class="stat-card" :class="`stat-card--${tone ?? 'neutral'}`">
    <span>{{ label }}</span>
    <strong>{{ value }}</strong>
    <small>{{ note }}</small>
  </article>
</template>

