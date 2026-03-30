import { Cloud, Github, ChevronDown } from 'lucide-react'
import CopyButton from './CopyButton'

const CURL_CMD = `bash <(curl -fsSL https://raw.githubusercontent.com/harshith-km/instaserver/main/setup.sh)`

export default function Hero() {
  const scrollToBuilder = () => {
    document.getElementById('builder').scrollIntoView({ behavior: 'smooth' })
  }

  return (
    <section className="min-h-screen flex items-center justify-center px-4 py-8 bg-gradient-to-b from-slate-50 to-white dark:from-[#0f172a] dark:to-[#0f172a] dark:bg-[radial-gradient(ellipse_at_50%_0%,rgba(6,182,212,0.08)_0%,transparent_60%)]">
      <div className="text-center max-w-2xl">
        <div className="inline-flex items-center gap-2 bg-cyan-500/10 border border-cyan-500/30 text-cyan-600 dark:text-cyan-400 px-4 py-1.5 rounded-full text-sm font-medium mb-6">
          <Cloud size={18} />
          <span>Open Source</span>
        </div>

        <h1 className="text-5xl sm:text-6xl md:text-7xl font-extrabold tracking-tight leading-tight mb-4">
          <span className="text-gradient">instaserver</span>
        </h1>

        <p className="text-lg text-slate-500 dark:text-slate-400 mb-8 leading-relaxed">
          Set up your EC2 instance in one command.<br />
          Interactive setup for Ubuntu Server & Amazon Linux.
        </p>

        <div className="flex items-center gap-3 bg-slate-100 border border-slate-200 dark:bg-slate-800 dark:border-slate-700 rounded-xl px-4 py-3.5 mb-8 overflow-x-auto">
          <code className="flex-1 font-mono text-sm text-cyan-600 dark:text-cyan-400 whitespace-nowrap">{CURL_CMD}</code>
          <CopyButton text={CURL_CMD} />
        </div>

        <div className="flex justify-center gap-10 sm:gap-12 mb-8">
          {[
            { num: '21', label: 'Modules' },
            { num: '25+', label: 'Tools' },
            { num: '2', label: 'OS Families' },
          ].map((s) => (
            <div key={s.label} className="flex flex-col items-center">
              <span className="text-3xl font-bold text-slate-900 dark:text-white">{s.num}</span>
              <span className="text-xs text-slate-400 dark:text-slate-500 uppercase tracking-wider">{s.label}</span>
            </div>
          ))}
        </div>

        <div className="flex justify-center gap-3 flex-wrap">
          <button
            onClick={scrollToBuilder}
            className="inline-flex items-center gap-2 px-6 py-3 bg-cyan-500 text-white dark:text-slate-900 font-semibold rounded-xl hover:bg-cyan-600 hover:-translate-y-0.5 hover:shadow-lg hover:shadow-cyan-500/30 transition-all cursor-pointer"
          >
            <ChevronDown size={18} />
            Build Custom Script
          </button>
          <a
            href="https://github.com/harshith-km/instaserver"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 px-6 py-3 bg-white border border-slate-200 text-slate-900 dark:bg-slate-800 dark:text-white dark:border-slate-700 font-semibold rounded-xl hover:bg-slate-50 dark:hover:bg-slate-700 hover:border-slate-300 dark:hover:border-slate-600 transition-all"
          >
            <Github size={18} />
            GitHub
          </a>
        </div>
      </div>
    </section>
  )
}
