import { useState } from 'react'
import { Copy, Check } from 'lucide-react'

export default function CopyButton({ text, label = 'Copy' }) {
  const [copied, setCopied] = useState(false)

  const handleCopy = async () => {
    await navigator.clipboard.writeText(text)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  return (
    <button
      onClick={handleCopy}
      className={`inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium rounded-md border transition-all cursor-pointer whitespace-nowrap ${
        copied
          ? 'bg-emerald-500/15 border-emerald-500 text-emerald-600 dark:text-emerald-400'
          : 'bg-slate-200 border-slate-300 text-slate-700 hover:bg-cyan-500/10 hover:border-cyan-500 hover:text-cyan-600 dark:bg-slate-700 dark:border-slate-600 dark:text-slate-200 dark:hover:text-cyan-400'
      }`}
    >
      {copied ? <Check size={14} /> : <Copy size={14} />}
      {copied ? 'Copied!' : label}
    </button>
  )
}
