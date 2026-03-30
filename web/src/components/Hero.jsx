import { Cloud, Github, Terminal, Camera } from 'lucide-react'
import { theme } from '../theme'
import CopyButton from './CopyButton'

const CURL_CMD = `bash <(curl -fsSL https://raw.githubusercontent.com/harshith-km/instaserver/main/setup.sh)`

export default function Hero() {
  const scrollTo = (id) => document.getElementById(id)?.scrollIntoView({ behavior: 'smooth' })

  return (
    <section id="hero" className={`min-h-screen flex items-center justify-center px-4 pt-20 pb-12 ${theme.heroSection}`}>
      <div className="text-center max-w-3xl w-full">
        {/* Badge */}
        <div className={`inline-flex items-center gap-2 ${theme.badge} px-4 py-1.5 rounded-full text-sm font-medium mb-6 animate-fade-in-up`}>
          <Cloud size={16} className="animate-float" />
          <span>Open Source</span>
        </div>

        {/* Title */}
        <h1 className="text-5xl sm:text-6xl md:text-8xl font-extrabold tracking-tight leading-none mb-5 animate-fade-in-up delay-100">
          <span className="text-gradient">instaserver</span>
        </h1>

        {/* Tagline */}
        <p className={`text-lg sm:text-xl ${theme.body} mb-10 leading-relaxed animate-fade-in-up delay-200 max-w-xl mx-auto`}>
          Setup, snapshot & replicate your servers.
          <br className="hidden sm:block" />
          One command. Ubuntu & Amazon Linux.
        </p>

        {/* Command box */}
        <div className={`${theme.commandBar} rounded-2xl p-5 mb-10 animate-fade-in-up delay-300 max-w-2xl mx-auto text-left`}>
          <div className="flex items-center gap-2 mb-3">
            <span className="w-2.5 h-2.5 rounded-full bg-red-400/70" />
            <span className="w-2.5 h-2.5 rounded-full bg-yellow-400/70" />
            <span className="w-2.5 h-2.5 rounded-full bg-green-400/70" />
            <span className={`ml-2 text-xs font-medium ${theme.muted}`}>Terminal</span>
          </div>
          <code className={`font-mono text-sm ${theme.commandText} break-all leading-relaxed block mb-4`}>
            <span className={theme.muted}>$ </span>{CURL_CMD}
          </code>
          <CopyButton text={CURL_CMD} />
        </div>

        {/* Stats */}
        <div className="flex justify-center gap-8 sm:gap-16 mb-10 animate-fade-in-up delay-400">
          {[
            { num: '21', label: 'Modules' },
            { num: '25+', label: 'Tools' },
            { num: '2', label: 'OS Families' },
          ].map((s) => (
            <div key={s.label} className="flex flex-col items-center">
              <span className={`text-3xl sm:text-4xl font-bold ${theme.statNumber}`}>{s.num}</span>
              <span className={`text-xs ${theme.statLabel} uppercase tracking-wider mt-1`}>{s.label}</span>
            </div>
          ))}
        </div>

        {/* Two tool cards */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-10 max-w-2xl mx-auto animate-fade-in-up delay-500">
          <button
            onClick={() => scrollTo('builder')}
            className={`${theme.card} rounded-2xl p-6 text-left group hover:-translate-y-1 transition-all cursor-pointer`}
          >
            <Terminal size={24} className={`${theme.accent} mb-3`} />
            <h3 className={`font-bold mb-1 ${theme.heading}`}>Setup Builder</h3>
            <p className={`text-sm ${theme.muted}`}>
              Pick tools & configs, get a ready-to-run setup script.
            </p>
          </button>
          <button
            onClick={() => scrollTo('snapshot')}
            className={`${theme.card} rounded-2xl p-6 text-left group hover:-translate-y-1 transition-all cursor-pointer`}
          >
            <Camera size={24} className={`${theme.accent} mb-3`} />
            <h3 className={`font-bold mb-1 ${theme.heading}`}>Snapshot Builder</h3>
            <p className={`text-sm ${theme.muted}`}>
              Capture your server state & generate a reinstall script.
            </p>
          </button>
        </div>

        {/* GitHub link */}
        <div className="animate-fade-in-up delay-600">
          <a
            href="https://github.com/harshith-km/instaserver"
            target="_blank"
            rel="noopener noreferrer"
            className={`inline-flex items-center gap-2 px-6 py-3 ${theme.btnSecondary} rounded-xl text-sm`}
          >
            <Github size={16} />
            View on GitHub
          </a>
        </div>
      </div>
    </section>
  )
}
