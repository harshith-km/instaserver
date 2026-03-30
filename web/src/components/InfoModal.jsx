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
        className={`${theme.card} rounded-2xl max-w-lg w-full p-6 animate-scale-in relative`}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Close button */}
        <button
          onClick={onClose}
          className={`absolute top-4 right-4 p-1.5 rounded-lg ${theme.btnAction} border-0`}
        >
          <X size={16} />
        </button>

        {/* Title */}
        <h3 className={`text-lg font-bold ${theme.heading} mb-3 pr-8`}>{info.title}</h3>

        {/* Description */}
        <p className={`${theme.body} text-sm leading-relaxed mb-4`}>{info.description}</p>

        {/* Details list */}
        {info.details && (
          <ul className="space-y-2 mb-4">
            {info.details.map((d, i) => (
              <li key={i} className={`flex items-start gap-2 text-sm ${theme.muted}`}>
                <span className="text-[#3b82f6] dark:text-[#22d3ee] mt-0.5">&#x2022;</span>
                {d}
              </li>
            ))}
          </ul>
        )}

        {/* Link */}
        {info.link && (
          <a
            href={info.link}
            target="_blank"
            rel="noopener noreferrer"
            className={`inline-flex items-center gap-1.5 text-sm font-medium ${theme.accent} hover:underline`}
          >
            Learn more <ExternalLink size={13} />
          </a>
        )}
      </div>
    </div>
  )
}
