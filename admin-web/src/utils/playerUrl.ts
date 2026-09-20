/**
 * 解析玩家端二维码地址。
 *
 * 优先使用服务端下发的 PUBLIC_BASE_URL（玩家端与后台分域部署时必须配置）；
 * 未配置（空串）时回退到与后台同源，保持单域名部署的原有行为。
 */
export function resolvePlayerBaseUrl(configured: string | null | undefined, origin: string): string {
  const value = (configured ?? '').trim()
  if (!value) {
    return `${origin.replace(/\/+$/, '')}/`
  }
  return value.endsWith('/') ? value : `${value}/`
}
