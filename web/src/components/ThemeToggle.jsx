import { Sun, Moon } from 'lucide-react'
import { useTheme } from '../ThemeContext'
import { theme as t } from '../theme'

export default function ThemeToggle() {
  const { theme, toggle } = useTheme()

  return (
    <button
      onClick={toggle}
      className={`fixed top-5 right-5 z-50 p-2.5 rounded-full ${t.themeToggle} animate-fade-in`}
      aria-label="Toggle theme"
    >
      {theme === 'dark' ? <Sun size={18} /> : <Moon size={18} />}
    </button>
  )
}
