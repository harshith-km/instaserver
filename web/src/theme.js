// =============================================================================
//  Centralized Theme - instaserver
//
//  Usage: import { theme } from '../theme'
//         <div className={theme.card}> ... </div>
//
//  Light: Clean, airy, white-based with rich blue accents
//  Dark:  Deep navy, immersive, electric blue/cyan accents
//  Both meet WCAG AA contrast ratios (4.5:1 for text, 3:1 for large/UI)
// =============================================================================

export const theme = {

  // ---------------------------------------------------------------------------
  //  Page / Layout
  // ---------------------------------------------------------------------------
  page:
    'bg-white text-gray-900 ' +
    'dark:bg-[#0a0f1e] dark:text-gray-100',

  // Hero section gradient background
  heroSection:
    'bg-gradient-to-b from-[#f8fafc] to-white ' +
    'dark:from-[#0a0f1e] dark:to-[#0a0f1e] ' +
    'dark:bg-[radial-gradient(ellipse_at_50%_0%,rgba(59,130,246,0.08)_0%,transparent_60%)]',

  // ---------------------------------------------------------------------------
  //  Cards / Surfaces
  // ---------------------------------------------------------------------------
  card:
    'bg-white border border-[#e5e7eb] shadow-sm ' +
    'dark:bg-[#111827] dark:border-[#1e293b] dark:shadow-none',

  cardHeader:
    'bg-[#f8fafc] border-b border-[#e5e7eb] ' +
    'dark:bg-[#1f2937] dark:border-[#1e293b]',

  // ---------------------------------------------------------------------------
  //  Typography
  // ---------------------------------------------------------------------------
  heading:
    'text-[#111827] ' +
    'dark:text-white',

  body:
    'text-[#374151] ' +
    'dark:text-[#d1d5db]',

  muted:
    'text-[#6b7280] ' +
    'dark:text-[#9ca3af]',

  // ---------------------------------------------------------------------------
  //  Accent / Brand
  // ---------------------------------------------------------------------------
  accent:
    'text-[#2563eb] ' +
    'dark:text-[#3b82f6]',

  accentSecondary:
    'text-[#0891b2] ' +
    'dark:text-[#22d3ee]',

  accentBg:
    'bg-[#2563eb] ' +
    'dark:bg-[#3b82f6]',

  // Category / section headings with accent color
  sectionLabel:
    'text-[#2563eb] ' +
    'dark:text-[#3b82f6]',

  // ---------------------------------------------------------------------------
  //  Badges / Pills
  // ---------------------------------------------------------------------------
  badge:
    'bg-blue-500/10 border border-blue-500/30 text-[#2563eb] ' +
    'dark:text-[#22d3ee] dark:bg-cyan-500/10 dark:border-cyan-500/30',

  optionCountBadge:
    'bg-blue-500/15 text-[#2563eb] ' +
    'dark:bg-cyan-500/15 dark:text-[#22d3ee]',

  // ---------------------------------------------------------------------------
  //  Stats (Hero section numbers)
  // ---------------------------------------------------------------------------
  statNumber:
    'text-[#111827] ' +
    'dark:text-white',

  statLabel:
    'text-[#9ca3af] ' +
    'dark:text-[#6b7280]',

  // ---------------------------------------------------------------------------
  //  Buttons
  // ---------------------------------------------------------------------------
  btnPrimary:
    'bg-[#2563eb] text-white font-semibold rounded-xl ' +
    'hover:bg-[#1d4ed8] hover:-translate-y-0.5 hover:shadow-lg hover:shadow-blue-500/30 ' +
    'dark:bg-[#3b82f6] dark:text-white ' +
    'dark:hover:bg-[#2563eb] dark:hover:shadow-blue-500/25 ' +
    'transition-all cursor-pointer',

  btnSecondary:
    'bg-white border border-[#e5e7eb] text-[#111827] font-semibold rounded-xl ' +
    'hover:bg-[#f8fafc] hover:border-[#d1d5db] ' +
    'dark:bg-[#1f2937] dark:text-white dark:border-[#374151] ' +
    'dark:hover:bg-[#374151] dark:hover:border-[#4b5563] ' +
    'transition-all cursor-pointer',

  // Small action buttons (Copy, Download)
  btnAction:
    'bg-[#f1f5f9] border border-[#d1d5db] text-[#374151] ' +
    'hover:bg-blue-500/10 hover:border-[#2563eb] hover:text-[#2563eb] ' +
    'dark:bg-[#374151] dark:border-[#4b5563] dark:text-[#d1d5db] ' +
    'dark:hover:bg-blue-500/10 dark:hover:border-[#3b82f6] dark:hover:text-[#3b82f6] ' +
    'transition-all cursor-pointer',

  // Copy button success state
  btnSuccess:
    'bg-emerald-500/15 border border-[#059669] text-[#059669] ' +
    'dark:border-[#10b981] dark:text-[#10b981]',

  // ---------------------------------------------------------------------------
  //  Toggle Switch
  // ---------------------------------------------------------------------------
  toggleOn:
    'bg-[#2563eb] ' +
    'dark:bg-[#3b82f6]',

  toggleOff:
    'bg-[#d1d5db] ' +
    'dark:bg-[#374151]',

  toggleKnob:
    'bg-white',

  toggleLabel:
    'text-[#374151] ' +
    'dark:text-[#d1d5db]',

  // ---------------------------------------------------------------------------
  //  Form Elements
  // ---------------------------------------------------------------------------
  input:
    'bg-[#f8fafc] border border-[#d1d5db] text-[#111827] ' +
    'focus:border-[#2563eb] focus:ring-1 focus:ring-[#2563eb]/20 ' +
    'dark:bg-[#1f2937] dark:border-[#374151] dark:text-white ' +
    'dark:focus:border-[#3b82f6] dark:focus:ring-[#3b82f6]/20 ' +
    'outline-none transition-colors',

  select:
    'bg-[#f8fafc] border border-[#d1d5db] text-[#111827] ' +
    'focus:border-[#2563eb] ' +
    'dark:bg-[#1f2937] dark:border-[#374151] dark:text-white ' +
    'dark:focus:border-[#3b82f6] ' +
    'outline-none cursor-pointer transition-colors',

  inputLabel:
    'text-[#6b7280] ' +
    'dark:text-[#9ca3af]',

  // Radio group - selected
  radioSelected:
    'bg-blue-500/10 border-[#2563eb] text-[#2563eb] ' +
    'dark:bg-blue-500/10 dark:border-[#3b82f6] dark:text-[#3b82f6]',

  // Radio group - unselected
  radioUnselected:
    'bg-[#f8fafc] border-[#d1d5db] text-[#374151] hover:border-[#9ca3af] ' +
    'dark:bg-[#1f2937] dark:border-[#374151] dark:text-[#d1d5db] dark:hover:border-[#4b5563]',

  // ---------------------------------------------------------------------------
  //  Code / Preview Panel
  // ---------------------------------------------------------------------------
  codeBlock:
    'bg-[#f1f5f9] ' +
    'dark:bg-[#0d1117]',

  codeText:
    'text-[#334155] ' +
    'dark:text-[#9ca3af]',

  codeInline:
    'text-[#2563eb] ' +
    'dark:text-[#22d3ee]',

  // Preview panel (the script output area)
  previewContainer:
    'bg-[#f8fafc] border border-[#e5e7eb] ' +
    'dark:bg-[#0d1117] dark:border-[#1e293b]',

  previewHeader:
    'bg-[#f1f5f9] border-b border-[#e5e7eb] ' +
    'dark:bg-[#111827] dark:border-[#1e293b]',

  previewHeaderText:
    'text-[#6b7280] ' +
    'dark:text-[#9ca3af]',

  // Hero curl command bar
  commandBar:
    'bg-[#f1f5f9] border border-[#e5e7eb] ' +
    'dark:bg-[#111827] dark:border-[#1e293b]',

  commandText:
    'text-[#2563eb] ' +
    'dark:text-[#22d3ee]',

  // ---------------------------------------------------------------------------
  //  Theme Toggle Button
  // ---------------------------------------------------------------------------
  themeToggle:
    'bg-white/80 border border-[#d1d5db] text-[#374151] ' +
    'hover:bg-[#f1f5f9] ' +
    'dark:bg-[#1f2937]/80 dark:border-[#4b5563] dark:text-[#d1d5db] ' +
    'dark:hover:bg-[#374151] ' +
    'backdrop-blur-sm transition-all cursor-pointer',

  // ---------------------------------------------------------------------------
  //  Footer
  // ---------------------------------------------------------------------------
  footerBorder:
    'border-t border-[#e5e7eb] ' +
    'dark:border-[#1f2937]',

  footerText:
    'text-[#9ca3af] ' +
    'dark:text-[#6b7280]',

  footerStrong:
    'text-[#374151] ' +
    'dark:text-[#9ca3af]',

  footerLink:
    'text-[#9ca3af] hover:text-[#2563eb] ' +
    'dark:text-[#6b7280] dark:hover:text-[#3b82f6] ' +
    'transition-colors',

  footerDivider:
    'text-[#d1d5db] ' +
    'dark:text-[#374151]',

  footerHeart:
    'text-red-500',

  // ---------------------------------------------------------------------------
  //  Option Group (ScriptBuilder sections)
  // ---------------------------------------------------------------------------
  optionGroup:
    'bg-white border border-[#e5e7eb] shadow-sm ' +
    'dark:bg-[#111827] dark:border-[#1e293b] dark:shadow-none ' +
    'rounded-xl p-5',

  optionGroupTitle:
    'text-[#2563eb] dark:text-[#3b82f6] ' +
    'border-b border-[#e5e7eb] dark:border-[#1e293b]',

  // ---------------------------------------------------------------------------
  //  Borders (standalone utilities)
  // ---------------------------------------------------------------------------
  border:
    'border-[#e5e7eb] ' +
    'dark:border-[#1e293b]',

  borderSubtle:
    'border-[#f1f5f9] ' +
    'dark:border-[#1f2937]',

  // ---------------------------------------------------------------------------
  //  Scrollbar (CSS class names, not Tailwind - used in App.css)
  // ---------------------------------------------------------------------------
  // Light scrollbar thumb: #cbd5e1
  // Dark scrollbar thumb: #374151

  // ---------------------------------------------------------------------------
  //  Gradient (for the "instaserver" title - applied via .text-gradient in CSS)
  // ---------------------------------------------------------------------------
  // Light: linear-gradient(135deg, #2563eb 0%, #7c3aed 50%, #2563eb 100%)
  // Dark:  linear-gradient(135deg, #3b82f6 0%, #a78bfa 50%, #3b82f6 100%)
}

// =============================================================================
//  Color Reference
// =============================================================================
//
//  DARK THEME PALETTE
//  -------------------------
//  Background primary:     #0a0f1e  (deep navy)
//  Background card:        #111827  (dark surface)
//  Background elevated:    #1f2937  (headers, inputs)
//  Border primary:         #1e293b  (subtle)
//  Border secondary:       #374151  (more visible)
//  Border emphasis:        #4b5563  (hover states)
//  Text heading:           #ffffff  (pure white)
//  Text body:              #d1d5db  (soft gray)
//  Text muted:             #9ca3af  (dim gray)
//  Text faint:             #6b7280  (very dim)
//  Accent primary:         #3b82f6  (electric blue)
//  Accent secondary:       #22d3ee  (cyan)
//  Success:                #10b981  (emerald)
//  Code background:        #0d1117  (GitHub dark)
//
//  LIGHT THEME PALETTE
//  -------------------------
//  Background primary:     #ffffff  (clean white)
//  Background card:        #ffffff  (white with shadow)
//  Background elevated:    #f8fafc  (off-white)
//  Background subtle:      #f1f5f9  (light gray)
//  Border primary:         #e5e7eb  (light gray)
//  Border secondary:       #d1d5db  (medium gray)
//  Border emphasis:        #9ca3af  (hover)
//  Text heading:           #111827  (near-black)
//  Text body:              #374151  (dark gray)
//  Text muted:             #6b7280  (medium gray)
//  Text faint:             #9ca3af  (light gray)
//  Accent primary:         #2563eb  (rich blue)
//  Accent secondary:       #0891b2  (teal)
//  Success:                #059669  (emerald)
//  Code background:        #f1f5f9  (light slate)
//  Code text:              #334155  (dark slate)
//
// =============================================================================
