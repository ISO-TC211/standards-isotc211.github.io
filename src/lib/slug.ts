export function postSlug(id: string): string {
  return id.replace(/^\d{4}-\d{2}-\d{2}-/, '')
}

export function postPath(date: Date, id: string): string {
  const yyyy = date.getFullYear()
  const mm = String(date.getMonth() + 1).padStart(2, '0')
  const dd = String(date.getDate()).padStart(2, '0')
  return `/site/update/${yyyy}/${mm}/${dd}/${postSlug(id)}.html`
}
