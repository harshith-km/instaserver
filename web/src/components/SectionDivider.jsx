import { theme } from '../theme'

export default function SectionDivider() {
  return (
    <div className="flex items-center justify-center py-8 px-4">
      <div className={`flex-1 h-px max-w-xs ${theme.border} border-t`} />
      <div className={`mx-4 w-1.5 h-1.5 rounded-full ${theme.accentBg}`} />
      <div className={`flex-1 h-px max-w-xs ${theme.border} border-t`} />
    </div>
  )
}
