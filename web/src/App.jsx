import { ThemeProvider } from './ThemeContext'
import { theme } from './theme'
import ThemeToggle from './components/ThemeToggle'
import Hero from './components/Hero'
import ScriptBuilder from './components/ScriptBuilder'
import Footer from './components/Footer'

function App() {
  return (
    <ThemeProvider>
      <div className={`min-h-screen transition-colors ${theme.page}`}>
        <ThemeToggle />
        <Hero />
        <ScriptBuilder />
        <Footer />
      </div>
    </ThemeProvider>
  )
}

export default App
