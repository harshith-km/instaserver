import { Sun, Moon } from 'lucide-react'
import { useTheme } from '../ThemeContext'
import { theme as t } from '../theme'

export default function ThemeToggle() {
  const { theme, toggle } = useTheme()

  return (
    <button
      onClick={toggle}
      className={`fixed top-3.5 right-16 sm:right-4 z-50 p-2 rounded-lg ${t.themeToggle} animate-fade-in`}
      aria-label="Toggle theme"
    >
      {theme === 'dark' ? <Sun size={16} /> : <Moon size={16} />}
    </button>
  )
}
