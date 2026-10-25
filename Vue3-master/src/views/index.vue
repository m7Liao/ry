<template>
  <div class="app-container">
    <el-card shadow="never">
      <template #header>工作台</template>
      <p>欢迎，{{ userStore.nickName || userStore.name }}。</p>
      <p>请通过导航菜单选择需要使用的功能。</p>
    </el-card>
  </div>
</template>

<script setup>
import useUserStore from '@/store/modules/user'

const userStore = useUserStore()
</script>
