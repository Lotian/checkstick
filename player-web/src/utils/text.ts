export function taskSteps(taskText: string): string[] {
  return taskText
    .split(/\r?\n/)
    .map((step) => step.trim())
    .filter(Boolean)
}

/** 本次活动的名字。写成毛笔书法的只有这三个字，首屏大标题会据此换成官方文字 logo。 */
export const BRAND_TITLE = '纸嫁衣'

/**
 * 后台标题是否正好是本次活动名。
 *
 * 大标题用的是官方毛笔字 logo 图片，而不是字体——手写书法的味道字体还原不出来。
 * 但标题可以在后台改，所以改名后必须退回普通文字，避免图文不符。
 */
export function isBrandTitle(title: string | null | undefined): boolean {
  return (title ?? '').trim() === BRAND_TITLE
}

