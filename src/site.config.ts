import type { SiteConfig } from '@isotc211/astro-ui'

export const siteConfig: SiteConfig = {
  title: 'ISO/TC 211 Normative Statements & Conformance',
  titleHtml: 'ISO/TC&nbsp;211 Normative Statements &amp; Conformance',
  brandSub: 'Harmonized Resources Maintenance Agency',
  description: 'Normative statements and conformance repository for geographic information technology from ISO/TC 211 Geographic information/Geomatics.',
  faviconSvg: '/assets/favicon.svg',
  faviconIco: '/assets/favicon.ico',
  nav: [
    { title: 'News', url: '/news/' },
    { title: 'About', url: '/about/' },
    { title: 'ISO/TC 211 Resources', url: 'https://www.isotc211.org' },
  ],
  committee: {
    id: 211,
    name: 'Geographic information/Geomatics',
    home: 'https://committee.iso.org/home/tc211',
  },
  footerLinks: [
    { title: 'Main Site', url: 'https://www.isotc211.org' },
    { title: 'Geodetic Registry', url: 'https://geodetic.isotc211.org/' },
    { title: 'UML Models', url: 'http://iso.sparxcloud.com/index.php' },
    { title: 'Schemas', url: 'https://schemas.isotc211.org' },
    { title: 'Terminology', url: 'https://isotc211.geolexica.org/' },
    { title: 'Ontologies', url: 'https://def.isotc211.org' },
    { title: 'Registries', url: 'https://registry.isotc211.org/' },
  ],
  social: {
    links: [
      { url: 'https://twitter.com/ISOTC211' },
      { url: 'https://github.com/ISO-TC211' },
    ],
  },
}
