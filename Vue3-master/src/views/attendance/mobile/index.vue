<template>
  <main class="attendance-mobile">
    <div class="mobile-wrap">
      <header class="mobile-heading"><div><h1>考勤签到</h1><p class="mobile-subtitle">{{ identity ? `${identity.employeeName} · ${identity.employeeNo}` : '核对信息后确认签到' }}</p></div><el-button link type="primary" @click="switchAccount">切换账号</el-button></header>
      <section v-if="result" class="mobile-card" aria-live="polite">
        <div class="mobile-success">{{ result.repeated ? '本场次已签到' : '签到成功' }}</div>
        <dl><div><dt>员工</dt><dd>{{ result.employeeName }}</dd></div><div><dt>办公场所</dt><dd>{{ result.siteName }}</dd></div><div><dt>签到时间</dt><dd>{{ result.checkinTime }}</dd></div><div><dt>记录编号</dt><dd>{{ result.recordId }}</dd></div></dl>
      </section>
      <section v-else class="mobile-card" v-loading="loading">
        <h2>{{ preview?.title || '扫码签到' }}</h2>
        <dl v-if="preview"><div><dt>姓名</dt><dd>{{ preview.employeeName }}</dd></div><div><dt>工号</dt><dd>{{ preview.employeeNo }}</dd></div><div><dt>办公场所</dt><dd>{{ preview.siteName }}</dd></div></dl>
        <dl v-else-if="identity"><div><dt>所属部门</dt><dd>{{ identity.deptName }}</dd></div><div><dt>绑定场所</dt><dd>{{ identity.siteName }}</dd></div></dl>
        <p v-if="error" class="mobile-error" role="alert">{{ error }}</p>
        <p v-if="!ticket && !error" class="mobile-notice">请使用手机扫描办公场所展示的动态二维码，再确认签到。</p>
        <p v-if="preview && seconds > 0" class="mobile-notice" aria-live="polite">当前二维码还可使用 {{ seconds }} 秒。</p>
        <p v-if="preview && seconds <= 0" class="mobile-error" role="alert">二维码已过期，请重新扫描现场二维码。</p>
        <template v-if="face?.required">
          <p class="mobile-notice">本场签到需核验本人人脸。人脸识别技术由虹软®提供；本版不包含活体检测。</p>
          <FaceCapture v-if="face.ready && face.enrolled && seconds > 0" :disabled="saving" @captured="image = $event" />
        </template>
        <el-button v-if="preview" class="mobile-primary" type="primary" :loading="saving" :disabled="seconds <= 0 || loading || !!error || (face?.required && (!face.ready || !face.enrolled || !image))" @click="submit">{{ face?.required ? '核验人脸并签到' : '确认签到' }}</el-button>
        <el-button v-if="error && ticket" class="mobile-primary" @click="load">重试</el-button>
      </section>
      <nav class="mobile-actions"><el-button text type="primary" @click="$router.push('/h5/records')">原始签到记录</el-button><el-button text type="primary" @click="$router.push('/h5/daily')">我的每日考勤</el-button></nav>
      <p class="mobile-notice">签到结果以系统保存的记录为准。二维码过期或场次结束时，请联系现场管理员。</p>
    </div>
  </main>
</template>
<script setup name="AttendanceMobileCheckin">
import { myIdentity, previewCheckin, submitCheckin } from '@/api/attendance/checkin'
import { myFaceStatus, submitFaceCheckin } from '@/api/attendance/face'
import FaceCapture from '@/components/FaceCapture/index.vue'
import useUserStore from '@/store/modules/user'
import './mobile.css'
const route = useRoute(), router = useRouter(), userStore = useUserStore()
const identity = ref(null), preview = ref(null), result = ref(null), loading = ref(false), saving = ref(false), error = ref(''), seconds = ref(0)
const face = ref(null), image = ref(null)
const ticket = computed(() => typeof route.query.ticket === 'string' && /^[0-9a-f]{64}$/.test(route.query.ticket) ? route.query.ticket : '')
let timer, offset = 0, requestVersion = 0
function tick() { seconds.value = preview.value ? Math.max(0, Math.ceil((preview.value.expiresAt - Date.now() - offset) / 1000)) : 0 }
async function load() {
  const version = ++requestVersion; loading.value = true; error.value = ''; preview.value = null; result.value = null; face.value = null; image.value = null
  try {
    const me = await myIdentity()
    if (version !== requestVersion) return
    identity.value = me.data
    if (route.query.ticket && !ticket.value) throw new Error('二维码地址无效，请重新扫描现场二维码')
    if (ticket.value) {
      const r = await previewCheckin(ticket.value)
      if (version !== requestVersion) return
      preview.value = r.data; offset = r.data.serverTime - Date.now(); tick()
      if (r.data.recordId) result.value = { ...r.data, repeated: true }
      else {
        const status = await myFaceStatus()
        if (version !== requestVersion) return
        face.value = status.data
        if (face.value.required && !face.value.ready) error.value = face.value.message
        else if (face.value.required && !face.value.enrolled) error.value = '本人尚未录入人脸，请联系管理员'
      }
    }
  } catch (e) { if (version === requestVersion) error.value = e.message || '无法读取签到信息，请检查网络或联系管理员' }
  finally { if (version === requestVersion) loading.value = false }
}
async function submit() {
  if (saving.value || seconds.value <= 0) return
  saving.value = true; error.value = ''
  try { result.value = (await (face.value?.required ? submitFaceCheckin(ticket.value, image.value) : submitCheckin(ticket.value))).data }
  catch (e) { error.value = e.message || '签到提交失败，请重试' }
  finally { saving.value = false }
}
async function switchAccount() { await userStore.logOut(); router.replace({ path: '/h5/login', query: { redirect: route.fullPath } }) }
watch(() => route.query.ticket, load, { immediate: true })
onMounted(() => timer = setInterval(tick, 1000))
onBeforeUnmount(() => { requestVersion++; clearInterval(timer) })
</script>
