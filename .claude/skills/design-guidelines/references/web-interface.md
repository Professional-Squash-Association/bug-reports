# Web Interface Checklist

Condensed from Vercel's Web Interface Guidelines (MIT). Upstream, for the latest wording:
- https://vercel.com/design/guidelines
- https://raw.githubusercontent.com/vercel-labs/web-interface-guidelines/main/command.md

React-only items are generalised; Vercel brand preferences are left out. The project's own
rules win where they differ.

## Interaction
- Every flow works by keyboard. Follow WAI-ARIA patterns for focus traps, moving and returning focus.
- Visible focus on everything focusable: `:focus-visible`, `:focus-within` for groups. Never `outline: none` without a replacement. Sticky bars never cover the focused element.
- Hit targets: 24px minimum on desktop, 44px on touch.
- Mobile inputs are at least 16px text. Never disable zoom (`user-scalable=no`, `maximum-scale=1`).
- Never block paste.
- Navigation uses `<a>` so Cmd/Ctrl-click, middle-click and right-click work. Actions use `<button>`. No clickable `<div>`.
- State lives in the URL: filters, tabs, pagination, open panels. Share, refresh and Back must restore it, including scroll position.
- Loading buttons keep their label and add an indicator. Spinners and skeletons wait ~150-300ms before showing, then stay ~300-500ms.
- Optimistic updates: change the UI at once, reconcile, and on failure roll back or offer Undo.
- Destructive actions need a confirmation or an Undo window.
- Menu items that open a follow-up step end in "…" ("Rename…"); so do loading states ("Saving…").
- Tooltips are a last resort. Delay the first in a group, not the ones after.
- No dead zones: if it looks interactive, it is.
- `touch-action: manipulation` on controls; set `-webkit-tap-highlight-color` on purpose.
- `overscroll-behavior: contain` in modals, drawers and sheets.
- Every gesture (drag, swipe, pinch) has a tap and keyboard alternative.
- Autofocus only on desktop with a single primary input.
- Toasts and inline validation announce through polite `aria-live`.

## Motion
- Honour `prefers-reduced-motion`.
- CSS first, then the Web Animations API, then a library.
- Animate `transform` and `opacity` only. Never `transition: all`; list the properties.
- Animate only to show cause and effect, or for deliberate delight.
- Motion is interruptible, starts from where the thing physically comes from (`transform-origin`).
- No autoplay except muted, non-essential loops. Motion over 5 seconds needs pause or hide.

## Layout
- Everything aligns to a grid, baseline, edge or optical centre. Nudge ±1px when the eye beats the maths.
- Icon and text side by side: balance weight, size and spacing.
- Check mobile, laptop and ultra-wide.
- Full-bleed layouts respect `env(safe-area-inset-*)`.
- No stray scrollbars; fix the overflow.
- Let flex, grid and intrinsic sizing do the work, not JS measurement.

## Content
- Inline help before tooltips.
- No dead ends: every screen offers a next step or a way back.
- Design empty, sparse, dense and error states. Test short, average and very long content (`min-width: 0` on flex children, truncate or wrap).
- Skeletons match the final layout exactly.
- `<title>` reflects the current page.
- Typography: "…" not "...", curly quotes, non-breaking spaces in `10 MB` and `⌘ K`, `text-wrap: balance` on headings, no widows.
- Numbers that are compared use `tabular-nums`.
- Never use colour alone for status; add text.
- Dates, times, numbers and currency follow the viewer's locale (`Intl.*` or the framework's helpers). Detect language from `Accept-Language`, never IP.
- `translate="no"` on brand names, code and identifiers.
- Native elements before ARIA. Hierarchical headings, a skip link, `scroll-margin-top` on anchored headings.
- Icon-only buttons have an `aria-label`; decorative icons get `aria-hidden="true"`; images have `alt` (empty when decorative).
- Media: captions, transcripts, keyboard-operable controls.

## Forms
- Every control has a label; clicking the label focuses the control. Checkbox and label share one hit target.
- Correct `type`, `inputmode`, `autocomplete` and `name`. No spellcheck on email, codes, usernames.
- Do not block typing and do not pre-disable submit. Let people submit and show what is missing.
- Submit disables only once the request starts, with a spinner and an idempotency key.
- Errors sit next to their field. On submit, focus the first error.
- Placeholders show an example and end with "…".
- Enter submits a single-field form. In a textarea, Cmd/Ctrl+Enter submits.
- Warn before leaving with unsaved changes.
- Support password managers, 2FA and pasted one-time codes. Trim trailing whitespace.

## Performance
- Mutations complete in under 500ms.
- Explicit `width` and `height` on images. Lazy-load below the fold; prioritise the hero image.
- Preconnect to asset and CDN origins. Preload critical fonts; subset them.
- Virtualise long lists (or `content-visibility: auto`).
- No layout reads during render; batch DOM reads and writes.
- Muted looping `<video>` over animated GIFs, with a still fallback and reduced-motion handling.
- Test on Safari, iOS Low Power Mode, throttled CPU and network.

## Visual Polish
- Layered shadows (two or more), semi-transparent borders for crisp edges.
- Nested radius is no larger than its parent and concentric with it.
- On coloured backgrounds, tint borders, shadows and text toward that hue.
- Hover, active and focus are more prominent than rest.
- Colour-blind-safe palettes for charts. Prefer APCA contrast.
- Dark themes set `color-scheme: dark`; `<meta name="theme-color">` matches the background. Native `<select>` gets explicit colours.

## Copy
- Active voice, second person.
- Specific labels: "Save API Key", not "Continue".
- Numerals for counts: "8 videos".
- Errors say how to fix it, not only what went wrong.
- Keep nouns consistent; introduce as few terms as possible.

## Flag on Sight
`user-scalable=no` · paste blocked · `transition: all` · `outline: none` with no focus style ·
clickable `<div>` · navigation by script instead of `<a>` · images without dimensions ·
unlabelled inputs · icon buttons without `aria-label` · hard-coded date or number formats ·
unjustified autofocus · animated GIFs · gesture-only actions.
