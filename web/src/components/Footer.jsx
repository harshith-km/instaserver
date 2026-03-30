import { Github, Heart } from 'lucide-react'
import { theme } from '../theme'

export default function Footer() {
  return (
    <footer className={`${theme.footerBorder} px-4 py-8 text-center ${theme.footerText} text-sm`}>
      <div className="max-w-xl mx-auto">
        <p>
          <strong className={theme.footerStrong}>instaserver</strong> &mdash; Made for the cloud
        </p>
        <div className="mt-2 flex items-center justify-center gap-2 flex-wrap">
          <a
            href="https://github.com/harshith-km/instaserver"
            target="_blank"
            rel="noopener noreferrer"
            className={`inline-flex items-center gap-1 ${theme.footerLink}`}
          >
            <Github size={14} /> GitHub
          </a>
          <span className={theme.footerDivider}>|</span>
          <span className="inline-flex items-center gap-1">
            Built with <Heart size={12} className={theme.footerHeart} /> by{' '}
            <a
              href="https://github.com/harshith-km"
              target="_blank"
              rel="noopener noreferrer"
              className={theme.footerLink}
            >
              harshith-km
            </a>
          </span>
        </div>
      </div>
    </footer>
  )
}
