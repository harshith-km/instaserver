import { Sun, Moon } from 'lucide-react'
import { useTheme } from '../ThemeContext'

export default function ThemeToggle() {
  const { theme, toggle } = useTheme()

  return (
    <button
      onClick={toggle}
      className="fixed top-4 right-4 z-50 p-2.5 rounded-full border transition-all cursor-pointer backdrop-blur-sm bg-white/80 border-slate-300 text-slate-600 hover:bg-slate-100 dark:bg-slate-800/80 dark:border-slate-600 dark:text-slate-300 dark:hover:bg-slate-700"
      aria-label="Toggle theme"
    >
      {theme === 'dark' ? <Sun size={18} /> : <Moon size={18} />}
    </button>
  )
}
