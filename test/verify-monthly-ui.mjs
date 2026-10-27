import assert from 'node:assert/strict'
import { shanghaiMonth, hours } from '../Vue3-master/src/utils/attendanceMonthly.js'
import { safeH5Redirect } from '../Vue3-master/src/utils/h5.js'
assert.equal(shanghaiMonth(new Date('2026-09-30T16:00:00Z')), '2026-10')
assert.equal(shanghaiMonth(new Date('2026-09-30T15:59:59Z')), '2026-09')
assert.equal(shanghaiMonth(new Date('2026-12-31T16:00:00Z')), '2027-01')
assert.equal(hours(962), '16.03')
assert.equal(hours(0), '0.00')
globalThis.window = { location: { origin: 'http://localhost' } }
assert.equal(safeH5Redirect('/h5/monthly?month=2026-09'), '/h5/monthly?month=2026-09')
for (const bad of ['//example.com/h5/monthly', 'https://example.com/h5/monthly', '/h5/monthly/../login', '/attendance/monthly']) assert.equal(safeH5Redirect(bad), '/h5/checkin')
console.log('PASS: Shanghai month boundaries, hour display and monthly login recovery')
