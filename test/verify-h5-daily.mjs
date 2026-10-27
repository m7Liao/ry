import assert from 'node:assert/strict'
import { safeH5Redirect } from '../Vue3-master/src/utils/h5.js'
globalThis.window = { location: { origin: 'http://localhost' } }
assert.equal(safeH5Redirect('/h5/daily?month=2026-10'), '/h5/daily?month=2026-10')
assert.equal(safeH5Redirect('/h5/records'), '/h5/records')
for (const bad of ['https://example.com/h5/daily','//example.com/h5/daily','/attendance/daily','/h5/daily/../login',null]) assert.equal(safeH5Redirect(bad), '/h5/checkin')
console.log('PASS: employee daily-result login recovery and same-origin redirect boundaries')
