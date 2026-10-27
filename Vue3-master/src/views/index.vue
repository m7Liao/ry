<template>
  <div class="app-container">
    <el-card shadow="never">
      <template #header>工作台</template>
      <p>欢迎，{{ userStore.nickName || userStore.name }}。</p>
      <p>请通过导航菜单选择需要使用的功能。</p>
      <el-button type="primary" plain icon="DataAnalysis" v-hasPermi="['attendance:dashboard:view']" @click="$router.push('/attendance/dashboard')">打开考勤看板</el-button>
    </el-card>
  </div>
</template>

<script setup>
import useUserStore from '@/store/modules/user'

const userStore = useUserStore()
</script>
