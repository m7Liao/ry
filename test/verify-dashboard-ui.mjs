import assert from 'node:assert/strict'
import { createRequire } from 'node:module'
import { readDailyDashboardQuery, dailyDashboardRoute } from '../Vue3-master/src/utils/attendanceDashboard.js'
import { trendOptions, anomalyOptions, siteOptions, statusSeries } from '../Vue3-master/src/views/attendance/dashboard/chartOptions.js'

const require = createRequire(new URL('../Vue3-master/package.json', import.meta.url))
const echarts = require('echarts')
const period = { beginDate: '2026-10-19', endDate: '2026-10-21', siteId: 42 }
for (const filter of [{ resultGroup: 'SETTLED' }, { resultGroup: 'MISSING' }, { resultStatus: 'NORMAL' }, { resultStatus: 'ABNORMAL' }, { resultStatus: 'PENDING' }, { resultGroup: 'SETTLED', abnormalType: 'LATE' }]) {
  const route = dailyDashboardRoute({ ...period, ...filter })
  assert.equal(route.path, '/attendance/daily')
  const query = Object.fromEntries(new URLSearchParams(route.query))
  const parsed = readDailyDashboardQuery(query)
  assert.deepEqual(parsed.dateRange, ['2026-10-19', '2026-10-21'])
  assert.equal(parsed.siteId, 42)
  for (const [key, value] of Object.entries(filter)) assert.equal(parsed[key], value)
}
const stale = readDailyDashboardQuery({ resultGroup: 'MISSING', abnormalType: 'LATE' })
Object.assign(stale, readDailyDashboardQuery({ resultStatus: 'NORMAL' }))
assert.equal(stale.resultGroup, '')
assert.equal(stale.abnormalType, '')
assert.deepEqual(readDailyDashboardQuery({ beginDate: '2026-02-30', endDate: '2026-03-02', siteId: ['42'], resultGroup: ' OR 1=1' }), { siteId: undefined, resultStatus: '', resultGroup: '', abnormalType: '', dateRange: [] })
assert.deepEqual(readDailyDashboardQuery({ beginDate: '2026-10-21', endDate: '2026-10-19' }).dateRange, [])

const rows = [{ attendanceDate: '2026-10-19', normalCount: 1, abnormalCount: 2, pendingCount: 1, restCount: 0 }, { attendanceDate: '2026-10-20', normalCount: 2, abnormalCount: 1, pendingCount: 0, restCount: 1 }]
const summary = { lateCount: 2, earlyCount: 2, missingInCount: 1, missingOutCount: 2 }
const sites = [{ siteName: '办公场所甲', normalCount: 3, abnormalCount: 3, pendingCount: 1, restCount: 2 }, { siteName: '<script>alert(1)</script>', normalCount: 1, abnormalCount: 1, pendingCount: 1, restCount: 0 }]
const options = [trendOptions(rows), anomalyOptions(summary), siteOptions(sites)]
assert.deepEqual(options[0].series[0].data, [1, 2])
assert.deepEqual(options[1].series[0].data, [2, 2, 1, 2])
assert.equal(options[2].series.length, statusSeries.length)
for (const option of options) {
  assert.equal(option.tooltip.renderMode, 'richText')
  const chart = echarts.init(null, null, { renderer: 'svg', ssr: true, width: 900, height: 340 })
  try {
    chart.setOption({ ...option, animation: false })
    const svg = chart.renderToSVGString()
    assert.ok(svg.includes('<svg') && svg.includes('<path'))
    assert.ok(!svg.includes('<script>'))
  } finally { chart.dispose() }
}
for (const option of [trendOptions([]), anomalyOptions({}), siteOptions([])]) {
  const chart = echarts.init(null, null, { renderer: 'svg', ssr: true, width: 900, height: 340 })
  try { chart.setOption({ ...option, animation: false }); assert.ok(chart.renderToSVGString().includes('<svg')) } finally { chart.dispose() }
}
console.log('PASS: dashboard drill-down conditions, cached-filter reset, input validation and ECharts SVG rendering (including empty and unsafe-text cases)')
