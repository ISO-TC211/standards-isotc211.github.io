import { getCollection } from 'astro:content'

export async function GET() {
  const posts = (await getCollection('news')).sort(
    (a, b) => b.data.date.valueOf() - a.data.date.valueOf()
  )
  const postPath = (id: string, date: Date) => {
    const yyyy = date.getFullYear()
    const mm = String(date.getMonth() + 1).padStart(2, '0')
    const dd = String(date.getDate()).padStart(2, '0')
    return `/site/update/${yyyy}/${mm}/${dd}/${id.replace(/^\d{4}-\d{2}-\d{2}-/, '')}`
  }
  const esc = (s: string) =>
    s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')
  const iso = (d: Date) => {
    const tzo = -d.getTimezoneOffset()
    const sign = tzo >= 0 ? '+' : '-'
    const pad = (n: number) => String(Math.abs(n)).padStart(2, '0')
    return (
      `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}` +
      `T${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}${sign}${pad(tzo / 60)}:${pad(tzo % 60)}`
    )
  }

  let entriesXml = ''
  for (const post of posts) {
    const path = postPath(post.id, post.data.date)
    const published = iso(post.data.date)
    entriesXml +=
      `<entry><title type="html">${esc(post.data.title)}</title>` +
      `<link href="${path}.html" rel="alternate" type="text/html" title="${esc(post.data.title)}" />` +
      `<published>${published}</published><updated>${published}</updated>` +
      `<id>${path}</id></entry>`
  }

  const now = iso(new Date())
  const xml =
    `<?xml version="1.0" encoding="utf-8"?><feed xmlns="http://www.w3.org/2005/Atom" >` +
    `<generator uri="https://astro.build/">Astro</generator>` +
    `<link href="/feed.xml" rel="self" type="application/atom+xml" />` +
    `<link href="/" rel="alternate" type="text/html" />` +
    `<updated>${now}</updated><id>/feed.xml</id>` +
    `<title type="html">ISO/TC 211 Normative Statements &amp; Conformance</title>` +
    `<subtitle>Normative statements and conformance repository for geographic information technology from ISO/TC 211 Geographic information/Geomatics.</subtitle>` +
    `<author><name>ISO/TC 211</name></author>` +
    entriesXml +
    `</feed>`

  return new Response(xml, {
    headers: { 'Content-Type': 'application/atom+xml; charset=utf-8' },
  })
}
