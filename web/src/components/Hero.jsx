import { Cloud, Github, ChevronDown } from 'lucide-react'
import { theme } from '../theme'
import CopyButton from './CopyButton'

const CURL_CMD = `bash <(curl -fsSL https://raw.githubusercontent.com/harshith-km/instaserver/main/setup.sh)`

export default function Hero() {
  const scrollToBuilder = () => {
    document.getElementById('builder').scrollIntoView({ behavior: 'smooth' })
  }

  return (
    <section className={`min-h-screen flex items-center justify-center px-4 py-12 ${theme.heroSection}`}>
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
          Set up your EC2 instance in one command.
          <br className="hidden sm:block" />
          Interactive setup for Ubuntu Server & Amazon Linux.
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
          ].map((s, i) => (
            <div key={s.label} className="flex flex-col items-center">
              <span className={`text-3xl sm:text-4xl font-bold ${theme.statNumber}`}>{s.num}</span>
              <span className={`text-xs ${theme.statLabel} uppercase tracking-wider mt-1`}>{s.label}</span>
            </div>
          ))}
        </div>

        {/* CTA Buttons */}
        <div className="flex justify-center gap-4 flex-wrap animate-fade-in-up delay-500">
          <button
            onClick={scrollToBuilder}
            className={`inline-flex items-center gap-2 px-7 py-3.5 ${theme.btnPrimary} animate-pulse-glow`}
          >
            <ChevronDown size={18} />
            Build Custom Script
          </button>
          <a
            href="https://github.com/harshith-km/instaserver"
            target="_blank"
            rel="noopener noreferrer"
            className={`inline-flex items-center gap-2 px-7 py-3.5 ${theme.btnSecondary}`}
          >
            <Github size={18} />
            GitHub
          </a>
        </div>
      </div>
    </section>
  )
}
