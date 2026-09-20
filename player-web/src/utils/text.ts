export function taskSteps(taskText: string): string[] {
  return taskText
    .split(/\r?\n/)
    .map((step) => step.trim())
    .filter(Boolean)
}

