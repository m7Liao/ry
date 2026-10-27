<template><div ref="container" class="dashboard-chart" role="img" :aria-label="label" /></template>

<script setup>
import * as echarts from 'echarts'
const props = defineProps({ option: { type: Object, required: true }, label: { type: String, required: true } })
const emit = defineEmits(['select'])
const container = ref(null)
let chart, observer
function resize() { chart?.resize() }
function initialize() {
  if (!container.value || chart) return
  chart = echarts.init(container.value)
  chart.setOption(props.option, { notMerge: true })
  chart.on('click', event => { if (event.componentType === 'series') emit('select', event) })
  observer = new ResizeObserver(resize); observer.observe(container.value)
  window.addEventListener('resize', resize)
}
function dispose() { observer?.disconnect(); window.removeEventListener('resize', resize); chart?.dispose(); chart = undefined }
watch(() => props.option, option => chart?.setOption(option, { notMerge: true }))
onMounted(initialize)
onActivated(() => { initialize(); nextTick(resize) })
onDeactivated(dispose)
onBeforeUnmount(dispose)
</script>

<style scoped>.dashboard-chart { width: 100%; height: 340px; }</style>
