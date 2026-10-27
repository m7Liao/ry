import request from '@/utils/request'

export const getAttendanceDashboard = params => request({ url: '/attendance/dashboard', method: 'get', params })
