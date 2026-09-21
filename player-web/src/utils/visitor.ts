const VISITOR_KEY = 'xiqian.visitor-id'
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

function fallbackUuid(): string {
  const bytes = new Uint8Array(16)
  crypto.getRandomValues(bytes)
  bytes[6] = ((bytes[6] ?? 0) & 0x0f) | 0x40
  bytes[8] = ((bytes[8] ?? 0) & 0x3f) | 0x80
  const hex = Array.from(bytes, (value) => value.toString(16).padStart(2, '0'))
  return `${hex.slice(0, 4).join('')}-${hex.slice(4, 6).join('')}-${hex.slice(6, 8).join('')}-${hex.slice(8, 10).join('')}-${hex.slice(10).join('')}`
}

export function createVisitorId(): string {
  return typeof crypto.randomUUID === 'function' ? crypto.randomUUID() : fallbackUuid()
}

export function getVisitorId(): string {
  let existing: string | null = null
  try {
    existing = localStorage.getItem(VISITOR_KEY)
  } catch {
    // 隐私模式或存储配额策略可能禁用 localStorage；本次会话仍可继续抽签。
  }

  // 旧版本或人工篡改可能留下非法值。主动自愈，避免服务端持续返回“游客标识无效”。
  if (existing && UUID_PATTERN.test(existing)) return existing.toLowerCase()

  const visitorId = createVisitorId()
  try {
    localStorage.setItem(VISITOR_KEY, visitorId)
  } catch {
    // 无法持久化时只能在刷新后生成新身份，但不阻断当前请求。
  }
  return visitorId
}

