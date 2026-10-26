<template>
  <div class="app-container">
    <el-form ref="queryRef" :inline="true" :model="query" v-show="showSearch">
      <el-form-item label="场次名称" prop="title"><el-input v-model="query.title" clearable @keyup.enter="search" style="width: 200px" /></el-form-item>
      <el-form-item label="办公场所" prop="siteId"><el-select v-model="query.siteId" filterable remote :remote-method="loadSites" clearable style="width: 230px"><el-option v-for="s in sites" :key="s.id" :label="s.label" :value="s.id" /></el-select></el-form-item>
      <el-form-item label="开关状态" prop="status"><el-select v-model="query.status" clearable style="width: 140px"><el-option label="开放（含已到期）" value="0" /><el-option label="手动关闭" value="1" /></el-select></el-form-item>
      <el-form-item><el-button type="primary" icon="Search" @click="search">搜索</el-button><el-button icon="Refresh" @click="resetQuery">重置</el-button></el-form-item>
    </el-form>
    <el-row class="mb8"><el-button type="primary" plain icon="Plus" @click="openCreate" v-hasPermi="['attendance:session:add']">创建签到场次</el-button><right-toolbar v-model:showSearch="showSearch" @queryTable="load" /></el-row>
    <el-table :data="rows" v-loading="loading">
      <el-table-column label="场次名称" prop="title" min-width="180" show-overflow-tooltip />
      <el-table-column label="办公场所" prop="siteName" min-width="160" />
      <el-table-column label="开始时间" prop="startTime" width="175" />
      <el-table-column label="结束时间" prop="endTime" width="175" />
      <el-table-column label="签到人数" prop="recordCount" width="100" align="center" />
      <el-table-column label="状态" width="100"><template #default="{ row }"><el-tag :type="row.sessionState === 'open' ? 'success' : 'info'">{{ stateLabel(row.sessionState) }}</el-tag></template></el-table-column>
      <el-table-column label="操作" width="245" fixed="right"><template #default="{ row }">
        <el-button link type="primary" @click="openQr(row)" :disabled="row.sessionState !== 'open'" v-hasPermi="['attendance:session:qrcode']">展示二维码</el-button>
        <el-button link type="primary" @click="$router.push({ path: '/attendance/record', query: { sessionId: row.sessionId } })" v-hasPermi="['attendance:record:list']">记录</el-button>
        <el-button link type="danger" @click="close(row)" :disabled="row.status !== '0'" v-hasPermi="['attendance:session:edit']">关闭</el-button>
      </template></el-table-column>
    </el-table>
    <pagination v-show="total > 0" :total="total" v-model:page="query.pageNum" v-model:limit="query.pageSize" @pagination="load" />

    <el-dialog v-model="createOpen" title="创建签到场次" width="520px" append-to-body :close-on-click-modal="false">
      <el-form ref="createRef" :model="form" :rules="rules" label-width="100px">
        <el-form-item label="办公场所" prop="siteId"><el-select v-model="form.siteId" filterable remote :remote-method="loadSites" style="width: 100%"><el-option v-for="s in sites" :key="s.id" :label="s.label" :value="s.id" :disabled="s.status !== '0'" /></el-select></el-form-item>
        <el-form-item label="场次名称" prop="title"><el-input v-model.trim="form.title" maxlength="100" placeholder="例如：周一上午签到" /></el-form-item>
        <el-form-item label="开放时长" prop="durationMinutes"><el-input-number v-model="form.durationMinutes" :min="5" :max="1440" /> 分钟</el-form-item>
        <p class="tip">保存后立即开始；每名员工在同一场次只记录一次签到。结束时间与二维码有效期分别计算。</p>
      </el-form>
      <template #footer><el-button @click="createOpen = false">取消</el-button><el-button type="primary" :loading="saving" @click="save">创建</el-button></template>
    </el-dialog>

    <el-dialog v-model="qrOpen" title="动态签到二维码" width="min(600px, 94vw)" append-to-body :close-on-click-modal="false" @closed="stopQr">
      <div class="qr-panel" v-loading="qrLoading">
        <h3>{{ currentSession?.title }}</h3><p>{{ currentSession?.siteName }}</p>
        <el-form label-position="top" class="mobile-address"><el-form-item label="手机访问的前端地址"><el-input v-model.trim="mobileBase" placeholder="例如 http://192.168.1.20" @change="renderQr" /></el-form-item></el-form>
        <el-alert v-if="loopback" title="当前地址只适合本机打开。手机扫码请填写同一局域网内可访问的前端地址。" type="warning" :closable="false" show-icon />
        <p v-if="qrError" class="qr-error" role="alert">{{ qrError }}</p>
        <img v-if="qrImage && seconds > 0 && !qrError" :src="qrImage" alt="本场次动态签到二维码" class="qr-image" />
        <el-empty v-else description="二维码暂不可用，请刷新" :image-size="100" />
        <p aria-live="polite">{{ seconds > 0 ? `二维码 ${seconds} 秒后失效，窗口保持打开将自动刷新` : '二维码已失效' }}</p>
        <el-button :loading="qrLoading" @click="refreshQr">刷新二维码</el-button>
        <el-button v-if="mobileUrl && seconds > 0 && !qrError" @click="openMobile">本机打开签到页</el-button>
        <p class="tip">手机可使用相机或扫码工具识别，随后在浏览器中登录本人账号并确认签到。</p>
      </div>
    </el-dialog>
  </div>
</template>

<script setup name="AttendanceSession">
import QRCode from 'qrcode'
import { listSession, createSession, closeSession, issueQrCode } from '@/api/attendance/checkin'
import { siteOptions } from '@/api/attendance/site'
const { proxy } = getCurrentInstance()
const route = useRoute()
const query = reactive({ pageNum: 1, pageSize: 10, title: '', siteId: route.query.siteId ? Number(route.query.siteId) : undefined, status: '' })
const rows = ref([]), sites = ref([]), total = ref(0), loading = ref(false), showSearch = ref(true)
const createOpen = ref(false), saving = ref(false), form = ref({}), createRef = ref()
const qrOpen = ref(false), qrLoading = ref(false), qrImage = ref(''), qrError = ref(''), qrData = ref(null), currentSession = ref(null)
const mobileBase = ref(localStorage.getItem('attendance.h5Base') || import.meta.env.VITE_APP_H5_BASE_URL || window.location.origin)
const mobileUrl = ref(''), seconds = ref(0)
let timer, clockOffset = 0, qrVersion = 0, retryAt = 0
const loopback = computed(() => { try { return ['localhost', '127.0.0.1', '[::1]'].includes(new URL(mobileBase.value).hostname) } catch { return false } })
const rules = { siteId: [{ required: true, message: '请选择场所', trigger: 'change' }], title: [{ required: true, message: '请输入场次名称', trigger: 'blur' }], durationMinutes: [{ required: true, message: '请选择开放时长', trigger: 'change' }] }
const stateLabel = state => ({ open: '进行中', expired: '已到期', closed: '已关闭' })[state] || state
async function load() { loading.value = true; try { const r = await listSession(query); rows.value = r.rows; total.value = r.total } finally { loading.value = false } }
async function loadSites(keyword = '') { sites.value = (await siteOptions(keyword)).data }
function search() { query.pageNum = 1; load() }
function resetQuery() { proxy.resetForm('queryRef'); search() }
async function openCreate() { await loadSites(); form.value = { siteId: query.siteId, title: '', durationMinutes: 30 }; createOpen.value = true; nextTick(() => createRef.value?.clearValidate()) }
async function save() {
  if (!await createRef.value.validate().catch(() => false)) return
  saving.value = true
  try { await createSession(form.value); createOpen.value = false; proxy.$modal.msgSuccess('场次已创建'); await load() }
  finally { saving.value = false }
}
async function close(row) { try { await proxy.$modal.confirm(`确认关闭“${row.title}”？关闭后无法继续签到。`) } catch { return }; await closeSession(row.sessionId); proxy.$modal.msgSuccess('场次已关闭'); await load() }
async function renderQr() {
  qrImage.value = ''; mobileUrl.value = ''
  if (!qrData.value) return
  try {
    const origin = new URL(mobileBase.value)
    if (!['http:', 'https:'].includes(origin.protocol) || origin.username || origin.password || origin.search || origin.hash || !['', '/'].includes(origin.pathname)) throw new Error('请填写完整的前端地址，例如 http://192.168.1.20，不带路径、账号或参数')
    const target = new URL('/h5/checkin', origin.origin); target.searchParams.set('ticket', qrData.value.ticket)
    const url = target.toString()
    const image = await QRCode.toDataURL(url, { width: 300, margin: 4, errorCorrectionLevel: 'M' })
    mobileUrl.value = url; qrImage.value = image; qrError.value = ''
    localStorage.setItem('attendance.h5Base', origin.origin)
  } catch (error) { qrError.value = error.message || '二维码生成失败' }
}
function tick() {
  seconds.value = qrData.value ? Math.max(0, Math.ceil((qrData.value.expiresAt - Date.now() - clockOffset) / 1000)) : 0
  if (qrOpen.value && qrData.value && seconds.value <= 10 && !qrLoading.value && Date.now() >= retryAt) refreshQr()
}
async function refreshQr() {
  if (!currentSession.value || qrLoading.value) return
  const version = ++qrVersion; qrLoading.value = true
  try {
    const r = await issueQrCode(currentSession.value.sessionId)
    if (!qrOpen.value || version !== qrVersion) return
    qrData.value = r.data; clockOffset = r.data.serverTime - Date.now(); retryAt = Date.now() + Math.max(5000, r.data.expiresAt - r.data.serverTime - 10000)
    await renderQr(); tick()
  } catch (error) { if (version === qrVersion) { qrError.value = error.message || '二维码刷新失败，请确认场次和场所状态'; retryAt = Date.now() + 15000 } }
  finally { if (version === qrVersion) qrLoading.value = false }
}
async function openQr(row) { stopQr(); currentSession.value = row; qrOpen.value = true; qrError.value = ''; qrData.value = null; qrImage.value = ''; mobileUrl.value = ''; seconds.value = 0; await refreshQr(); if (qrOpen.value) timer = setInterval(tick, 1000) }
function stopQr() { clearInterval(timer); qrVersion++; qrLoading.value = false; qrData.value = null; qrImage.value = ''; mobileUrl.value = '' }
function openMobile() { if (mobileUrl.value) window.open(mobileUrl.value, '_blank', 'noopener,noreferrer') }
onBeforeUnmount(stopQr)
loadSites(); load()
</script>
<style scoped>
.qr-panel { text-align: center; } .qr-panel h3 { margin-top: 0; } .qr-image { display: block; width: min(300px, 100%); margin: 10px auto; background: #fff; }
.mobile-address { text-align: left; margin-top: 20px; } .qr-error { color: var(--el-color-danger); } .tip { font-size: 13px; color: var(--el-text-color-secondary); line-height: 1.7; }
</style>
