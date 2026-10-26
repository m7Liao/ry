<template>
  <main class="attendance-mobile"><div class="mobile-wrap">
    <header class="mobile-heading"><div><h1>我的签到记录</h1><p class="mobile-subtitle">查看本人已保存的签到结果</p></div><el-button link type="primary" @click="$router.push('/h5/checkin')">返回签到</el-button></header>
    <p v-if="error" class="mobile-error" role="alert">{{ error }}</p>
    <el-empty v-if="!loading && !rows.length && !error" description="暂无签到记录" />
    <article v-for="r in rows" :key="r.recordId" class="mobile-card"><h2>{{ r.sessionTitle }}</h2><dl><div><dt>办公场所</dt><dd>{{ r.siteName }}</dd></div><div><dt>签到时间</dt><dd>{{ r.checkinTime }}</dd></div><div><dt>记录编号</dt><dd>{{ r.recordId }}</dd></div></dl></article>
    <div class="mobile-actions"><el-button @click="refresh" :loading="loading">刷新</el-button><el-button v-if="rows.length < total" type="primary" plain :loading="loading" @click="more">加载更多</el-button></div>
    <p v-if="rows.length" class="mobile-notice" style="text-align:center">已显示 {{ rows.length }} / {{ total }} 条</p>
  </div></main>
</template>
<script setup name="AttendanceMobileRecords">
import { myRecords } from '@/api/attendance/checkin'
import './mobile.css'
const rows = ref([]), total = ref(0), loading = ref(false), error = ref('')
let page = 1
async function load(append = false) {
  if (loading.value) return
  loading.value = true; error.value = ''
  try { const r = await myRecords({ pageNum: page, pageSize: 10 }); const ids = new Set(rows.value.map(v => v.recordId)); rows.value = append ? [...rows.value, ...r.rows.filter(v => !ids.has(v.recordId))] : r.rows; total.value = r.total }
  catch (e) { error.value = e.message || '记录加载失败，请重试'; if (append) page-- }
  finally { loading.value = false }
}
function refresh() { if (loading.value) return; page = 1; load() }
function more() { if (loading.value) return; page++; load(true) }
load()
</script>
