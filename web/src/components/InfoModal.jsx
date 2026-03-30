import { X, ExternalLink } from 'lucide-react'
import { theme } from '../theme'

export default function InfoModal({ info, onClose }) {
  if (!info) return null

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4 backdrop-blur-sm bg-black/40 animate-fade-in"
      onClick={onClose}
    >
      <div
        className={`${theme.card} rounded-2xl max-w-lg w-full p-5 sm:p-6 animate-scale-in relative max-h-[90vh] overflow-y-auto`}
        onClick={(e) => e.stopPropagation()}
      >
        <button
          onClick={onClose}
          className={`absolute top-3 right-3 min-w-[44px] min-h-[44px] flex items-center justify-center rounded-lg ${theme.btnAction} border-0`}
        >
          <X size={16} />
        </button>

        <h3 className={`text-lg font-bold ${theme.heading} mb-3 pr-10`}>{info.title}</h3>
        <p className={`${theme.body} text-sm leading-relaxed mb-4`}>{info.description}</p>

        {info.details && (
          <ul className="space-y-2 mb-4">
            {info.details.map((d, i) => (
              <li key={i} className={`flex items-start gap-2 text-sm ${theme.muted}`}>
                <span className="text-[#3b82f6] dark:text-[#22d3ee] mt-0.5 shrink-0">&#x2022;</span>
                {d}
              </li>
            ))}
          </ul>
        )}

        {info.link && (
          <a
            href={info.link}
            target="_blank"
            rel="noopener noreferrer"
            className={`inline-flex items-center gap-1.5 text-sm font-medium py-2 ${theme.accent} hover:underline`}
          >
            Learn more <ExternalLink size={13} />
          </a>
        )}
      </div>
    </div>
  )
}
