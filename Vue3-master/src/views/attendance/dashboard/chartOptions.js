export const statusSeries = [
  { name: '正常', key: 'normalCount', status: 'NORMAL', color: '#67c23a' },
  { name: '异常', key: 'abnormalCount', status: 'ABNORMAL', color: '#e6a23c' },
  { name: '待结算', key: 'pendingCount', status: 'PENDING', color: '#409eff' },
  { name: '休息日', key: 'restCount', status: 'REST', color: '#909399' }
]
export const anomalySeries = [
  { name: '迟到', key: 'lateCount', type: 'LATE' },
  { name: '早退', key: 'earlyCount', type: 'EARLY' },
  { name: '上班缺卡', key: 'missingInCount', type: 'MISSING_IN' },
  { name: '下班缺卡', key: 'missingOutCount', type: 'MISSING_OUT' }
]
const tooltip = { trigger: 'axis', renderMode: 'richText', confine: true }
const valueAxis = { type: 'value', name: '人次', minInterval: 1, min: 0, splitLine: { lineStyle: { color: '#ebeef5' } } }

export function trendOptions(rows = []) {
  return {
    color: statusSeries.map(s => s.color), tooltip: { ...tooltip },
    legend: { top: 4, selected: { '休息日': false } },
    grid: { top: 55, left: 20, right: 24, bottom: 15, containLabel: true },
    xAxis: { type: 'category', boundaryGap: false, data: rows.map(r => r.attendanceDate.slice(5)) }, yAxis: { ...valueAxis },
    series: statusSeries.map(s => ({ name: s.name, type: 'line', symbolSize: 6, data: rows.map(r => r[s.key]), connectNulls: false }))
  }
}
export function anomalyOptions(summary = {}) {
  return {
    tooltip: { ...tooltip, axisPointer: { type: 'shadow' } },
    grid: { top: 24, left: 20, right: 25, bottom: 15, containLabel: true },
    xAxis: { ...valueAxis }, yAxis: { type: 'category', inverse: true, data: anomalySeries.map(s => s.name) },
    series: [{ name: '已结算异常人次', type: 'bar', barMaxWidth: 30, itemStyle: { color: '#e6a23c' }, data: anomalySeries.map(s => summary[s.key] || 0) }]
  }
}
export function siteOptions(rows = []) {
  return {
    color: statusSeries.map(s => s.color), tooltip: { ...tooltip, axisPointer: { type: 'shadow' } },
    legend: { top: 4, selected: { '休息日': false } },
    grid: { top: 55, left: 20, right: 25, bottom: 15, containLabel: true },
    xAxis: { ...valueAxis }, yAxis: { type: 'category', inverse: true, axisLabel: { width: 140, overflow: 'truncate' }, data: rows.map(r => r.siteName) },
    series: statusSeries.map(s => ({ name: s.name, type: 'bar', stack: 'status', barMaxWidth: 28, data: rows.map(r => r[s.key]) }))
  }
}
