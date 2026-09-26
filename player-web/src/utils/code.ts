/**
 * 组局码规则：4 位数字（0000~9999），由后端随机生成并允许前导零。
 *
 * 这里有一个历史包袱需要留意：早期版本用的是 6 位「字母 + 数字」组局码，
 * 而玩家的浏览器 localStorage 里可能还留着那种旧值（例如 `RR98DN`）。
 * 旧值必须**整体丢弃**，绝不能把里面的数字抠出来——
 * 那会得到毫无意义的 `98`，并被当成「用户已经输入的内容」显示在输入框里。
 */

/**
 * 输入框实时清洗（面向用户逐字输入与粘贴）。
 *
 * 规则：去掉两端空白后
 *   - 整体是纯数字 → 保留前 4 位（粘贴多位数时按前 4 位截断）
 *   - 含任何非数字字符 → 视为无效输入，返回空串
 *
 * 注意第二条：宁可让输入框空着，也不做「抠数字」这种会误导用户的猜测。
 */
export function normalizeGroupCode(value: string | null | undefined): string {
  const trimmed = (value ?? '').trim()
  if (!/^\d+$/.test(trimmed)) {
    return ''
  }
  return trimmed.slice(0, 4)
}

/** 是否为可提交的完整组局码（恰好 4 位数字）。 */
export function isCompleteGroupCode(value: string | null | undefined): boolean {
  return /^\d{4}$/.test((value ?? '').trim())
}

/**
 * 迁移 localStorage 里的历史值。
 *
 * 只有「本身就已经是完整 4 位数字码」才沿用；6 位旧码、残缺输入、空值一律返回空串。
 */
export function resolveStoredGroupCode(value: string | null | undefined): string {
  const trimmed = (value ?? '').trim()
  return isCompleteGroupCode(trimmed) ? trimmed : ''
}
