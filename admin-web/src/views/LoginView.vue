<script setup lang="ts">
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { useAuthStore } from '@/stores/auth'
import { errorMessage } from '@/api/client'

const auth = useAuthStore()
const router = useRouter()
const submitting = ref(false)
const form = reactive({ username: 'admin', password: '' })

async function submit() {
  if (!form.username || !form.password) {
    ElMessage.warning('请输入管理员账号和密码')
    return
  }
  submitting.value = true
  try {
    await auth.login(form.username, form.password)
    await router.replace('/')
  } catch (error) {
    ElMessage.error(errorMessage(error))
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <main class="login-page">
    <div class="login-stage" aria-hidden="true">
      <span class="stage-moon">囍</span>
      <i></i><i></i><i></i>
    </div>
    <section class="login-card">
      <div class="admin-seal">司</div>
      <p class="overline">现场司仪 · 控签台</p>
      <h1>囍签管理</h1>
      <p class="login-intro">开一轮签，看一场局。所有身份都由服务器落定。</p>
      <el-form label-position="top" @submit.prevent="submit">
        <el-form-item label="管理员账号">
          <el-input v-model="form.username" size="large" autocomplete="username" />
        </el-form-item>
        <el-form-item label="通行口令">
          <el-input
            v-model="form.password"
            size="large"
            type="password"
            show-password
            autocomplete="current-password"
            @keyup.enter="submit"
          />
        </el-form-item>
        <el-button class="login-submit" type="primary" size="large" :loading="submitting" @click="submit">
          登台理签
        </el-button>
      </el-form>
      <p class="http-note">短期活动后台 · 请勿在不可信网络输入密码</p>
    </section>
  </main>
</template>

