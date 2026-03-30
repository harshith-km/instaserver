import { Camera, Server, Database, Shield, FolderGit2, Container, Globe, Terminal } from 'lucide-react'
import { theme } from '../theme'
import CopyButton from './CopyButton'

const SNAP_CMD = `bash <(curl -fsSL https://raw.githubusercontent.com/harshith-km/instaserver/main/snapshot.sh)`

const CAPTURES = [
  { icon: Server, label: 'OS & Packages', desc: 'System info, installed packages, versions, running services' },
  { icon: FolderGit2, label: 'Git Projects', desc: 'Repos with remotes, branches, framework detection (Next.js, Express, Django...)' },
  { icon: Globe, label: 'Web Server', desc: 'Full Nginx/Apache config copy, SSL certs with expiry dates' },
  { icon: Database, label: 'Databases', desc: 'PostgreSQL, MySQL, MongoDB, Redis — names and status' },
  { icon: Container, label: 'Docker & PM2', desc: 'Containers, images, compose files, PM2 process dump' },
  { icon: Shield, label: 'Security', desc: 'SSH config, firewall rules, user accounts, sudo access, Fail2Ban' },
]

const EXTRA = [
  'Cron jobs & systemd timers',
  '.env file locations (keys only, no secrets)',
  'Shell config (.bashrc, .zshrc)',
  'Global npm & pip packages',
  'Kernel sysctl tuning',
  'Network config & disk mounts',
  'AWS EC2 metadata & IAM role',
  'Logrotate & custom systemd services',
]

export default function Snapshot() {
  return (
    <section className="px-4 sm:px-6 py-20 max-w-6xl mx-auto" id="snapshot">
      {/* Header */}
      <div className="text-center mb-12 animate-fade-in-up">
        <div className={`inline-flex items-center justify-center w-12 h-12 rounded-2xl mb-4 ${theme.accentBg}`}>
          <Camera size={24} className="text-white" />
        </div>
        <h2 className={`text-3xl sm:text-4xl font-bold mb-3 ${theme.heading}`}>Server Snapshot</h2>
        <p className={`${theme.muted} text-lg max-w-lg mx-auto`}>
          Capture your entire server state. Replicate it anywhere with one script.
        </p>
      </div>

      {/* Command */}
      <div className={`${theme.commandBar} rounded-2xl p-5 mb-12 max-w-2xl mx-auto animate-fade-in-up delay-100`}>
        <div className="flex items-center gap-2 mb-3">
          <span className="w-2.5 h-2.5 rounded-full bg-red-400/70" />
          <span className="w-2.5 h-2.5 rounded-full bg-yellow-400/70" />
          <span className="w-2.5 h-2.5 rounded-full bg-green-400/70" />
          <span className={`ml-2 text-xs font-medium ${theme.muted}`}>Terminal</span>
        </div>
        <code className={`font-mono text-sm ${theme.commandText} break-all leading-relaxed block mb-4`}>
          <span className={theme.muted}>$ </span>{SNAP_CMD}
        </code>
        <CopyButton text={SNAP_CMD} />
      </div>

      {/* What it captures grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 mb-10 animate-fade-in-up delay-200">
        {CAPTURES.map((c, i) => (
          <div key={i} className={`${theme.card} rounded-xl p-5 group hover:-translate-y-0.5 transition-transform`}>
            <c.icon size={20} className={`${theme.accent} mb-3`} />
            <h4 className={`font-semibold mb-1 ${theme.heading} text-sm`}>{c.label}</h4>
            <p className={`text-xs ${theme.muted} leading-relaxed`}>{c.desc}</p>
          </div>
        ))}
      </div>

      {/* Extra captures */}
      <div className={`${theme.card} rounded-xl p-6 animate-fade-in-up delay-300`}>
        <h4 className={`font-semibold mb-4 ${theme.heading} text-sm`}>Also captures:</h4>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-x-8 gap-y-2">
          {EXTRA.map((item, i) => (
            <div key={i} className={`flex items-center gap-2 text-sm ${theme.body}`}>
              <span className={`${theme.accent} text-xs`}>&#x2713;</span>
              {item}
            </div>
          ))}
        </div>
      </div>

      {/* Output info */}
      <div className="text-center mt-10 animate-fade-in-up delay-400">
        <p className={`${theme.muted} text-sm`}>
          Output: <code className={`${theme.commandText} font-mono text-xs`}>~/server-snapshot-YYYYMMDD-HHMMSS/</code> with a ready-to-use <code className={`${theme.commandText} font-mono text-xs`}>reinstall.sh</code>
        </p>
      </div>
    </section>
  )
}
