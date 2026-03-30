import { useState, useEffect } from 'react'
import { Cloud, Sun, Moon } from 'lucide-react'
import { theme } from '../theme'
import { useTheme } from '../ThemeContext'

const NAV_LINKS = [
  { id: 'hero', label: 'Home' },
  { id: 'builder', label: 'Setup' },
  { id: 'snapshot', label: 'Snapshot' },
]

export default function Navbar() {
  const [scrolled, setScrolled] = useState(false)
  const [active, setActive] = useState('hero')
  const { theme: currentTheme, toggle } = useTheme()

  useEffect(() => {
    const onScroll = () => {
      setScrolled(window.scrollY > 50)

      const sections = NAV_LINKS.map(l => ({
        id: l.id,
        el: document.getElementById(l.id),
      })).filter(s => s.el)

      for (let i = sections.length - 1; i >= 0; i--) {
        if (sections[i].el.getBoundingClientRect().top <= 120) {
          setActive(sections[i].id)
          break
        }
      }
    }
    window.addEventListener('scroll', onScroll, { passive: true })
    return () => window.removeEventListener('scroll', onScroll)
  }, [])

  const scrollTo = (id) => {
    document.getElementById(id)?.scrollIntoView({ behavior: 'smooth' })
  }

  return (
    <nav className={`fixed top-0 left-0 right-0 z-50 transition-all ${
      scrolled
        ? 'bg-white/80 dark:bg-[#0a0f1e]/80 backdrop-blur-xl border-b border-[#e5e7eb] dark:border-[#1e293b] shadow-sm'
        : 'bg-transparent border-b border-transparent'
    }`}>
      <div className="max-w-7xl mx-auto px-4 sm:px-6 h-14 flex items-center justify-between">
        {/* Logo */}
        <button onClick={() => scrollTo('hero')} className="flex items-center gap-2 cursor-pointer">
          <Cloud size={18} className={theme.accent} />
          <span className={`font-bold text-sm ${theme.heading}`}>instaserver</span>
        </button>

        {/* Center nav links */}
        <div className="flex items-center gap-1">
          {NAV_LINKS.map((link) => (
            <button
              key={link.id}
              onClick={() => scrollTo(link.id)}
              className={`px-3 py-1.5 rounded-lg text-xs sm:text-sm font-medium transition-all cursor-pointer ${
                active === link.id
                  ? 'text-[#2563eb] dark:text-[#3b82f6] bg-[#2563eb]/10 dark:bg-[#3b82f6]/10'
                  : `${theme.muted} hover:text-[#374151] dark:hover:text-[#d1d5db]`
              }`}
            >
              {link.label}
            </button>
          ))}
        </div>

        {/* Theme toggle */}
        <button
          onClick={toggle}
          className={`p-2 rounded-lg ${theme.themeToggle}`}
          aria-label="Toggle theme"
        >
          {currentTheme === 'dark' ? <Sun size={16} /> : <Moon size={16} />}
        </button>
      </div>
    </nav>
  )
}
