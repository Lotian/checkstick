<script setup lang="ts">
import { onMounted, ref } from 'vue'
import QRCode from 'qrcode'
import { api } from '@/api/client'
import type { AppConfig } from '@/types'
import { resolvePlayerBaseUrl } from '@/utils/playerUrl'

const qrDataUrl = ref('')
const publicUrl = ref(resolvePlayerBaseUrl('', window.location.origin))
const qrError = ref('')

async function loadPlayerBaseUrl() {
  try {
    const { data } = await api.get<AppConfig>('/admin/app-config')
    publicUrl.value = resolvePlayerBaseUrl(data.playerBaseUrl, window.location.origin)
  } catch {
    // 配置接口不可用时沿用同源地址，不影响二维码展示与现场使用。
  }
}

onMounted(async () => {
  await loadPlayerBaseUrl()
  try {
    qrDataUrl.value = await QRCode.toDataURL(publicUrl.value, {
      width: 420,
      margin: 2,
      color: { dark: '#2c0d0f', light: '#ead9b7' },
      errorCorrectionLevel: 'M',
    })
  } catch {
    // 地址仍保留在页面上，二维码库异常时工作人员可以让玩家手动访问。
    qrError.value = '二维码生成失败，请使用上方地址进入玩家端'
  }
})

function printQr() {
  window.print()
}
</script>

<template>
  <section class="qr-panel">
    <div class="qr-copy">
      <span class="panel-kicker">固定入口</span>
      <h2>玩家扫码处</h2>
      <p>二维码固定不变，玩家扫码后输入桌面展示的组局码。</p>
      <code>{{ publicUrl }}</code>
      <el-button plain @click="printQr">打印二维码</el-button>
    </div>
    <img v-if="qrDataUrl" :src="qrDataUrl" alt="玩家端固定二维码" />
    <p v-else-if="qrError" class="qr-error" role="alert">{{ qrError }}</p>
  </section>
</template>
