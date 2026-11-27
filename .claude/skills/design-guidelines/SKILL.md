---
name: design-guidelines
description: >-
  Design rules for every project: the editing pass that makes UI read as made by a
  designer, not generated. The AI default is to add (explanations, extra actions, fine
  print, icons, longer labels); a designer subtracts until only what the user needs right
  now is left. Covers copy (with a word budget), actions, button states, layout fit and polish, and links the
  unslop-ui visual-tells skill and Vercel's Web Interface Guidelines. Use whenever building,
  changing, reviewing or auditing any UI: a page, sheet, modal, dialog, form, empty state,
  component, native screen or email. Trigger even for "small" UI edits.
---

# Design Guidelines

The project's own design system always wins (its CLAUDE.md, style guide, tokens, casing
rules). These rules fill the gaps and set the default taste.

## The one rule

**Every element must earn its place. Default to removing.**

Before you finish any UI, delete each element in your head and ask: "Does the user lose
something they need right now?" If not, cut it. The generated look comes less from colours
and fonts than from too much stuff: too many words, actions, notes and decorations.

## The example (references/share-sheet-ai-vs-human.png)

Two "Share Workspace" sheets. The AI version:

1. A paragraph under the title that explains what the title already says.
2. The same fact three times: "Invite people", "They join by opening the link", "Anyone
   with this link can join".
3. A button that rests on a past state: "Copied". The user has copied nothing yet.
4. Four actions: Send Invite Link, Copied, Create Another Link, and "use Intent on your
   Mac" to remove people.
5. Admin edge cases in the main flow (removing people, turning off links).
6. Long labels with a decorative icon: "[upload icon] Send Invite Link".
7. A vague fact: "expires next week".
8. Fine print above the actions, so the eye hits text before the buttons.
9. A sheet much taller than its content, with blurred filler at the bottom.
10. Odd capitals in prose: "Invite people to Open shared workspace links".

The human version: title, "Send Link" (primary), "Copy Link" (secondary), one line of
fine print below: "Anyone with the link can join. Expires in 7 days." Nothing else.

## Copy

- **Do not explain what the UI already shows.** A title plus clear buttons needs no intro
  paragraph. If it does need one, the title or labels are wrong; fix those instead.
- **Say each fact once**, in the one place the user needs it.
- **Short labels, verb first, specific object**: "Send Link", "Copy Link", "Watch Live".
  Drop words the context supplies ("Invite" in a share sheet).
- **Concrete over vague**: "Expires in 7 days", "3 min left", not "next week", "soon".
- **No narration of the mechanism** ("They join by opening the link you send them").
  Trust the user.
- **No marketing filler** in product UI: no "seamlessly", "effortlessly", "powerful".
- **Fine print is one line, after the actions**, small and muted. Never above them.
- Errors say what happened and what to do next, in one sentence.
- Never talk down: no "Don't worry", "Oops", "Simply".

### Less text (references/less-text-nightmail.png)

**Count the words on the screen, then cut them by more than half.** A first draft is
almost always two to six times too long. In the example, Nightmail cut its waitlist screen
from 51 words to 15, "Check your email" from 67 to 15, and its price page from 203 to 34.
Nothing the user needed was lost.

What was cut, and the rule behind each cut:

- **One screen, one state.** The "Check your email" screen still showed the whole waitlist
  screen above it. When the user moves to the next step, the last step's copy goes.
- **Do not write what a control already does.** "Nothing after a few minutes? Look in spam,
  or check the address" was cut because "Send again in 1:00" and "Change address" already
  say it.
- **Hide the second path behind one short label.** The sign-in form for invited users
  became "Already invited?", which opens the form. The method paragraph on the price page
  became "How we compared +". The detail is still there for the few who look for it.
- **Do not repeat what the user just typed** unless they must check it. The waitlist screen
  dropped the email address; "Check your email" kept it, because a typo there is the main
  reason no email comes.
- **Do not restate the heading in the body.** "Full for now. Join the waitlist and we'll
  email you" under a "Join the waitlist" button says nothing new.
- **No bold lead-ins and no "how it works" lines** ("The link works once, for 30
  minutes"). If a limit matters, show it when the user hits it.
- **Short status screens get about 15 words.** Heading, one sentence, the actions. A
  reading page (pricing, docs) keeps its facts (the table) and cuts the prose around them.

## Actions

- **One primary action per view.** One secondary at most in a small surface (sheet,
  modal, card). Everything else goes elsewhere or away.
- **Rare and admin actions leave the main flow.** Put them in settings, a menu or the
  place where they are managed. Do not add a note pointing there.
- **A label names the action, never a status.** Feedback is transient: "Copy Link" turns
  to "Copied" for about 2 seconds, then back. Do not ship the feedback state as the
  resting state.
- **No icon in a button whose label is already clear.** Icons earn a place in icon-only
  buttons (with an aria-label) or toolbars.
- **No "do it again" actions by default** ("Create Another Link", "Add Another"). Add one
  only when repeating is the main job.

## Layout

- **Containers fit their content.** A sheet, modal or card is as tall as what is in it.
  No empty bands, no filler to balance space.
- **Order follows the eye**: title, then the action, then the fine print.
- **Group by spacing, not by boxes.** Do not wrap everything in a card or a border.
- One alignment per block. A short, focused surface can centre; a reading surface aligns
  left. Do not mix them in one block.
- One spacing scale, used consistently. Edges line up.

## States

Design every state, not only the happy path: empty, loading, error, partial, too long,
offline, no permission. Each empty state offers the next action. Test with real content:
long names, long titles, many items, zero items.

## Visual tells

Load the **unslop-ui** skill, if it is installed, for the visual side: untouched framework defaults, AI purple,
gradient text, unprompted glow, emoji as icons, rounded-everything, the hero plus three
cards, and the cream plus serif plus sage "tasteful default". Its rule: every colour,
type and layout choice must have a reason specific to the project. Without the skill,
apply that rule by hand. With it, run its scanner on web code when you audit.

## Interface details

Follow Vercel's Web Interface Guidelines for interaction, forms, motion, accessibility
and performance details. The condensed checklist is in
[references/web-interface.md](references/web-interface.md). Read it before you build or
review a web UI.

## The final pass

Before you say UI work is done, do this edit pass, in order:

1. Delete every sentence that repeats the title, a label or another sentence.
   Count the words before and after; if you did not cut about half, cut again.
2. Delete every action the user does not need on this screen right now.
3. Shorten every label to verb plus object.
4. Check that no button rests on a feedback state.
5. Move fine print below the actions and cut it to one line.
6. Make the container fit its content.
7. Check the visual tells (unslop-ui) and the interface details (web-interface.md).

If the result looks almost too plain, it is probably right.
