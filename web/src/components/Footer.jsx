import { Github, Heart } from 'lucide-react'

export default function Footer() {
  return (
    <footer className="border-t border-slate-200 dark:border-slate-800 px-4 py-8 text-center text-slate-400 dark:text-slate-500 text-sm">
      <div className="max-w-xl mx-auto">
        <p>
          <strong className="text-slate-600 dark:text-slate-400">instaserver</strong> &mdash; Made for the cloud
        </p>
        <div className="mt-2 flex items-center justify-center gap-2 flex-wrap">
          <a
            href="https://github.com/harshith-km/instaserver"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1 text-slate-400 dark:text-slate-500 hover:text-cyan-500 dark:hover:text-cyan-400 transition-colors"
          >
            <Github size={14} /> GitHub
          </a>
          <span className="text-slate-300 dark:text-slate-700">|</span>
          <span className="inline-flex items-center gap-1">
            Built with <Heart size={12} className="text-red-500" /> by{' '}
            <a
              href="https://github.com/harshith-km"
              target="_blank"
              rel="noopener noreferrer"
              className="text-slate-400 dark:text-slate-500 hover:text-cyan-500 dark:hover:text-cyan-400 transition-colors"
            >
              harshith-km
            </a>
          </span>
        </div>
      </div>
    </footer>
  )
}
