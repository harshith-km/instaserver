import { ThemeProvider } from './ThemeContext'
import ThemeToggle from './components/ThemeToggle'
import Hero from './components/Hero'
import ScriptBuilder from './components/ScriptBuilder'
import Footer from './components/Footer'

function App() {
  return (
    <ThemeProvider>
      <div className="min-h-screen bg-white text-slate-900 dark:bg-[#0f172a] dark:text-slate-100 transition-colors">
        <ThemeToggle />
        <Hero />
        <ScriptBuilder />
        <Footer />
      </div>
    </ThemeProvider>
  )
}

export default App
