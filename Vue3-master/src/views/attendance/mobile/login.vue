<template>
  <main class="attendance-mobile">
    <div class="mobile-wrap">
      <header class="mobile-heading"><div><h1>考勤签到</h1><p class="mobile-subtitle">登录本人账号，继续完成扫码签到</p></div></header>
      <section class="mobile-card">
        <h2>账号登录</h2>
        <el-form ref="loginRef" :model="form" :rules="rules" label-position="top" size="large" @submit.prevent="login">
          <el-form-item label="账号" prop="username"><el-input v-model.trim="form.username" autocomplete="username" placeholder="请输入系统账号" :disabled="loading" /></el-form-item>
          <el-form-item label="密码" prop="password"><el-input v-model="form.password" type="password" show-password autocomplete="current-password" placeholder="请输入密码" :disabled="loading" /></el-form-item>
          <el-form-item v-if="captchaEnabled" label="验证码" prop="code">
            <div class="captcha-row"><el-input v-model="form.code" autocomplete="off" placeholder="填写验证码结果" :disabled="loading" /><button class="captcha-button" type="button" aria-label="刷新验证码" @click="loadCaptcha"><img v-if="image" :src="image" alt="登录验证码" /><span v-else>重新加载</span></button></div>
          </el-form-item>
          <p v-if="error" class="mobile-error" role="alert">{{ error }}</p>
          <el-button class="mobile-primary" type="primary" native-type="submit" :loading="loading">登录并继续</el-button>
        </el-form>
      </section>
      <p class="mobile-notice">请使用管理员为你建立并绑定员工档案的账号。二维码过期后，需要重新扫描现场二维码。</p>
    </div>
  </main>
</template>
<script setup name="AttendanceMobileLogin">
import { getCodeImg } from '@/api/login'
import useUserStore from '@/store/modules/user'
import { safeH5Redirect } from '@/utils/h5'
import './mobile.css'
const router = useRouter(), route = useRoute(), userStore = useUserStore()
const form = reactive({ username: '', password: '', code: '', uuid: '' }), loginRef = ref(), loading = ref(false), error = ref(''), image = ref(''), captchaEnabled = ref(true)
const rules = { username: [{ required: true, message: '请输入账号', trigger: 'blur' }], password: [{ required: true, message: '请输入密码', trigger: 'blur' }], code: [{ validator: (_, v, cb) => cb(captchaEnabled.value && !v ? new Error('请输入验证码') : undefined), trigger: 'blur' }] }
async function loadCaptcha() {
  try { const r = await getCodeImg(); captchaEnabled.value = r.captchaEnabled !== false; image.value = r.img ? 'data:image/gif;base64,' + r.img : ''; form.uuid = r.uuid; form.code = '' }
  catch (e) { error.value = e.message || '验证码加载失败，请重试' }
}
async function login() {
  if (loading.value) return
  loading.value = true; error.value = ''
  try {
    if (!await loginRef.value.validate().catch(() => false)) return
    await userStore.login(form); await router.replace(safeH5Redirect(route.query.redirect))
  }
  catch (e) { error.value = e.message || '登录失败，请检查账号、密码与验证码'; await loadCaptcha() }
  finally { loading.value = false }
}
loadCaptcha()
</script>
<style scoped>.captcha-row { display: flex; width: 100%; gap: 12px; align-items: center; } .captcha-button { border: 1px solid #dce4ee; border-radius: 6px; background: #fff; padding: 0; flex: 0 0 112px; height: 42px; cursor: pointer; overflow: hidden; } .captcha-button img { width: 112px; height: 40px; object-fit: contain; }</style>
