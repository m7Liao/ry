/** 移动登录只接受本应用的签到页或本人记录页作为返回地址。 */
export function safeH5Redirect(value) {
  if (typeof value !== 'string') return '/h5/checkin'
  try {
    const url = new URL(value, window.location.origin)
    if (url.origin !== window.location.origin || !['/h5/checkin', '/h5/records'].includes(url.pathname)) return '/h5/checkin'
    return url.pathname + url.search
  } catch {
    return '/h5/checkin'
  }
}
