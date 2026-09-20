/**
 * 组局码为 4 位数字（0000~9999）。
 * 输入框、localStorage 里的历史值都统一走这里规范，避免旧版 6 位字母数字码残留进来。
 */

/** 只保留数字并截断到 4 位，用于输入框实时清洗与历史值迁移。 */
export function normalizeGroupCode(value: string | null | undefined): string {
  return (value ?? '').replace(/\D/g, '').slice(0, 4)
}

/** 是否为可提交的完整组局码（恰好 4 位数字）。 */
export function isCompleteGroupCode(value: string | null | undefined): boolean {
  return /^\d{4}$/.test((value ?? '').trim())
}
