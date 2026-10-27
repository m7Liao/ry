const statuses = ['NORMAL', 'ABNORMAL', 'PENDING', 'REST']
const groups = ['SETTLED', 'MISSING']
const anomalies = ['LATE', 'EARLY', 'MISSING_IN', 'MISSING_OUT']
const allowed = (value, values) => typeof value === 'string' && values.includes(value) ? value : ''
const siteNumber = value => {
  if (!['number', 'string'].includes(typeof value) || !/^\d+$/.test(String(value))) return undefined
  const id = Number(value)
  return Number.isSafeInteger(id) && id > 0 ? id : undefined
}
const isoDate = value => {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false
  const time = new Date(value + 'T00:00:00Z')
  return Number.isFinite(time.getTime()) && time.toISOString().slice(0, 10) === value
}

/** 缓存页面再次由看板进入时，完整恢复本次条件，避免残留上一次的筛选。 */
export function readDailyDashboardQuery(query = {}) {
  return {
    siteId: siteNumber(query.siteId),
    resultStatus: allowed(query.resultStatus, statuses),
    resultGroup: allowed(query.resultGroup, groups),
    abnormalType: allowed(query.abnormalType, anomalies),
    dateRange: isoDate(query.beginDate) && isoDate(query.endDate) && query.beginDate <= query.endDate ? [query.beginDate, query.endDate] : []
  }
}

export function dailyDashboardRoute(filters = {}) {
  const parsed = readDailyDashboardQuery(filters)
  const query = {}
  if (parsed.dateRange.length) [query.beginDate, query.endDate] = parsed.dateRange
  for (const key of ['siteId', 'resultStatus', 'resultGroup', 'abnormalType']) if (parsed[key]) query[key] = parsed[key]
  return { path: '/attendance/daily', query }
}
