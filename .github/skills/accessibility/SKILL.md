---
description: 'Web accessibility (WCAG 2.1 AA) checklist and patterns. USE FOR: implementing accessible UIs, ARIA attributes, keyboard navigation, focus management, screen reader support.'
---

# Accessibility Best Practices (WCAG 2.1 AA)

## Core Principles

1. **Perceivable** — Content must be presentable in ways all users can perceive
2. **Operable** — UI must be operable by keyboard, assistive tech, and other input methods
3. **Understandable** — Content and UI behavior must be understandable
4. **Robust** — Content must work with current and future assistive technologies

## Semantic HTML First

- Use native HTML elements before reaching for ARIA: `<button>`, `<nav>`, `<main>`, `<dialog>`, `<table>`
- A `<button>` is always better than `<div role="button" tabindex="0" (keydown)="...">`
- Use heading hierarchy (`h1`–`h6`) — don't skip levels
- Use `<ul>`/`<ol>` for lists — screen readers announce "list, 5 items"
- Use `<table>` with `<th>` for tabular data — not CSS grid/flex layouts pretending to be tables

## ARIA Roles & Attributes

### When to Use ARIA

- **Only when no native HTML element provides the semantics** (e.g., custom dropdowns, tree views, tabs)
- **First rule of ARIA**: Don't use ARIA if you can use a native HTML element

### Common Patterns

| Pattern                     | ARIA                                          | Example                       |
| --------------------------- | --------------------------------------------- | ----------------------------- |
| Live region (toast, status) | `aria-live="polite"` or `role="alert"`        | Error messages, notifications |
| Loading state               | `aria-busy="true"`                            | While data is fetching        |
| Expanded/collapsed          | `aria-expanded="true/false"`                  | Accordions, dropdowns         |
| Current page                | `aria-current="page"`                         | Active nav link               |
| Required field              | `aria-required="true"` (or native `required`) | Form inputs                   |
| Error description           | `aria-describedby="error-id"`                 | Link input to error message   |
| Label for complex widget    | `aria-label` or `aria-labelledby`             | Icon buttons, custom controls |

### Label Priority

1. Visible `<label for="id">` (preferred)
2. `aria-labelledby` (references visible text)
3. `aria-label` (invisible label — last resort for visual designs without labels)

## Keyboard Navigation

- All interactive elements must be reachable via `Tab` key
- Custom widgets must support expected keyboard patterns:
  - **Buttons**: `Enter` and `Space` to activate
  - **Menus**: Arrow keys to navigate, `Enter` to select, `Escape` to close
  - **Tabs**: Arrow keys between tabs, `Tab` to move to tab panel
  - **Dialogs**: `Escape` to close, trap focus inside while open
- **Tab order** must follow visual layout — use DOM order, not `tabindex` hacks
- Never use `tabindex` > 0 — it breaks natural tab order
- Use `tabindex="-1"` for programmatically focusable elements (not tab-reachable)

## Focus Management

- When a dialog opens, move focus to the first interactive element inside it
- When a dialog closes, return focus to the element that triggered it
- After deleting an item from a list, move focus to the next item (or previous if last)
- Use `cdkTrapFocus` (Angular CDK) or manual focus trapping for modals
- Visible focus indicator — never remove `outline` without providing an alternative `:focus-visible` style

## Color & Contrast

- Text contrast ratio: **4.5:1** minimum (3:1 for large text ≥ 18pt)
- UI component contrast: **3:1** against adjacent colors
- Never use color alone to convey information — add icons, text, or patterns
- Test with a contrast checker tool
- Support `prefers-color-scheme` and `prefers-reduced-motion`

## Forms

- Every input needs a visible label — placeholder text is NOT a label
- Group related fields with `<fieldset>` and `<legend>`
- Error messages must be:
  - Associated with the input via `aria-describedby`
  - Announced to screen readers (live region or focus management)
  - Visible (not just color change — add text/icon)
- Indicate required fields with text "(required)" — not just an asterisk

## Images & Media

- Meaningful images: `alt="Description of what the image conveys"`
- Decorative images: `alt=""` (empty alt — never omit the attribute)
- Complex images (charts, diagrams): provide a text description nearby or via `aria-describedby`
- Videos: provide captions and transcripts

## Skip Links

- Add a "Skip to main content" link as the first focusable element
- Should be visually hidden until focused (`:focus-visible` styles)

```html
<a class="skip-link" href="#main-content">Skip to main content</a>
<!-- ... nav ... -->
<main id="main-content">...</main>
```

## Angular-Specific

- Use `@angular/cdk/a11y` — `LiveAnnouncer`, `FocusTrap`, `FocusMonitor`
- Use `LiveAnnouncer.announce()` for dynamic content changes screen readers should know about
- Angular Material components are generally accessible — don't override their ARIA attributes unless you have a specific reason
- Test with `ChromeVox`, `NVDA`, or `VoiceOver`

## Testing

- Automated: axe-core (Playwright integration, `@axe-core/playwright`)
- Manual: keyboard-only navigation test, screen reader test
- Lighthouse accessibility audit (Chrome DevTools)
- Check `prefers-reduced-motion` handling
