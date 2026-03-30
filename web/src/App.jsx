import { ThemeProvider } from './ThemeContext'
import { theme } from './theme'
import Navbar from './components/Navbar'
import Hero from './components/Hero'
import ScriptBuilder from './components/ScriptBuilder'
import SectionDivider from './components/SectionDivider'
import Snapshot from './components/Snapshot'
import Footer from './components/Footer'

function App() {
  return (
    <ThemeProvider>
      <div className={`min-h-screen transition-colors ${theme.page}`}>
        <Navbar />
        <Hero />
        <SectionDivider />
        <ScriptBuilder />
        <SectionDivider />
        <Snapshot />
        <SectionDivider />
        <Footer />
      </div>
    </ThemeProvider>
  )
}

export default App
