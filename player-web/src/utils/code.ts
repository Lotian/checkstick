/**
 * 组局码规则：4 位数字（0000~9999），由后端随机生成并允许前导零。
 *
 * 这里有一个历史包袱需要留意：早期版本用的是 6 位「字母 + 数字」组局码。
 * 不管来源是什么，只要不是 4 位纯数字就**整体作废**，绝不能从中抠数字——
 * 那会得到毫无意义的 `98`（例如旧码 `RR98DN`），
 * 并被当成「用户已经输入的内容」显示在输入框里。
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
