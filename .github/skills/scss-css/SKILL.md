---
description: 'SCSS/CSS patterns: BEM naming, CSS custom properties, Angular Material theming, relative units, responsive design. USE FOR: writing stylesheets, component styling, theming, responsive layouts.'
---

# SCSS / CSS Best Practices

## BEM Naming Convention

**Block\_\_Element--Modifier** — consistent, flat, and self-documenting.

```scss
// Block
.card { ... }

// Element (part of the block)
.card__header { ... }
.card__body { ... }
.card__footer { ... }

// Modifier (variation of block or element)
.card--featured { ... }
.card__header--compact { ... }
```

### Rules

- **Block**: standalone component name (`card`, `nav`, `form`, `modal`)
- **Element**: part of a block, prefixed with `__` (`card__title`, `nav__link`)
- **Modifier**: variation, prefixed with `--` (`card--large`, `button--primary`)
- Never nest more than one level of elements: `card__header__title` → `card__title` instead
- Never style based on element nesting in CSS — keep selectors flat

```scss
// ✅ Flat BEM
.card__title {
  font-size: 1.25rem;
}

// ❌ Nested selectors — fragile, high specificity
.card .header .title {
  font-size: 1.25rem;
}
```

## CSS Custom Properties (Variables)

**Always use CSS custom properties for values that might change** — never hardcode colors, spacing, or typography.

```scss
// ✅ Define in :root or component scope
:root {
  --color-primary: #1976d2;
  --color-error: #d32f2f;
  --color-text: #212121;
  --color-text-secondary: #757575;
  --color-background: #ffffff;
  --color-surface: #f5f5f5;

  --spacing-xs: 0.25rem;
  --spacing-sm: 0.5rem;
  --spacing-md: 1rem;
  --spacing-lg: 1.5rem;
  --spacing-xl: 2rem;

  --font-size-sm: 0.875rem;
  --font-size-md: 1rem;
  --font-size-lg: 1.25rem;

  --border-radius: 4px;
  --transition-fast: 150ms ease;
}

// ✅ Usage
.card {
  background: var(--color-surface);
  padding: var(--spacing-md);
  border-radius: var(--border-radius);
  color: var(--color-text);
}

// ❌ Never hardcode
.card {
  background: #f5f5f5;
  padding: 16px;
  color: #212121;
}
```

### Why

- Theming: override variables for dark mode, brand variants
- Consistency: single source of truth for design tokens
- Maintainability: change one variable, update everywhere

## Angular Material Theming

**Use Angular Material's theme system** — never override Material component colors with hardcoded values.

```scss
@use '@angular/material' as mat;

// Access theme colors
.custom-header {
  // ✅ Use theme palette
  background-color: mat.get-theme-color($theme, primary);
  color: mat.get-theme-color($theme, on-primary);
}

// ❌ Never hardcode Material colors
.custom-header {
  background-color: #1976d2; // breaks theming
}
```

### Rules

- Use `mat.get-theme-color()` to access theme palette colors
- Use `mat.get-theme-typography()` for consistent typography
- Override Material component styles with `::ng-deep` sparingly — prefer theme configuration
- Custom components should reference the same theme variables so they stay consistent when the theme changes
- When using `!important`, you're probably fighting the theme — find the proper customization point

## Relative Units

**Use `rem`, `em`, and `%` — avoid `px` for spacing, typography, and layout.**

| Unit        | Use For                                   | Base                          |
| ----------- | ----------------------------------------- | ----------------------------- |
| `rem`       | Font sizes, spacing, padding, margins     | Root font size (usually 16px) |
| `em`        | Spacing relative to the current font size | Parent font size              |
| `%`         | Widths, flexible layouts                  | Parent element size           |
| `vw` / `vh` | Full-viewport layouts, hero sections      | Viewport dimensions           |
| `px`        | Borders, shadows, fine details (1-2px)    | Absolute — use sparingly      |

```scss
// ✅ Relative
.card {
  padding: 1rem;
  margin-bottom: 1.5rem;
  font-size: 1rem;
  border-radius: 0.25rem;
}

// ✅ px is OK for these
.card {
  border: 1px solid var(--color-border);
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

// ❌ Avoid px for layout/spacing/typography
.card {
  padding: 16px;
  margin-bottom: 24px;
  font-size: 14px;
}
```

### Why

- Accessibility: users who change their browser's base font size get properly scaled layouts
- Consistency: `rem` scales uniformly across the app
- Responsive: relative units adapt better to different screen sizes

## Responsive Design

```scss
// Mobile-first breakpoints
$breakpoints: (
  sm: 600px,
  md: 960px,
  lg: 1280px,
  xl: 1920px,
);

@mixin respond-to($breakpoint) {
  @media (min-width: map-get($breakpoints, $breakpoint)) {
    @content;
  }
}

// Usage — mobile-first
.grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: var(--spacing-md);

  @include respond-to(md) {
    grid-template-columns: repeat(2, 1fr);
  }

  @include respond-to(lg) {
    grid-template-columns: repeat(3, 1fr);
  }
}
```

- **Mobile-first**: start with the smallest screen, add complexity with `min-width`
- Use CSS Grid for 2D layouts, Flexbox for 1D layouts
- Avoid media queries when intrinsic sizing works (`minmax`, `auto-fill`, `clamp`)
- Test with real device sizes, not just resizing the browser

## SCSS Organization

```scss
// Component file structure — one SCSS file per component
// my-component.component.scss

// 1. Host styles
:host {
  display: block;
}

// 2. Main block styles
.my-component { ... }

// 3. Elements
.my-component__header { ... }
.my-component__body { ... }

// 4. Modifiers
.my-component--compact { ... }

// 5. States
.my-component--loading { ... }
.my-component--error { ... }

// 6. Responsive overrides (at the end)
@include respond-to(md) { ... }
```

## Patterns to Avoid

- **Don't use `!important`** — fix specificity issues by using BEM (flat selectors)
- **Don't nest more than 3 levels deep** — leads to specificity wars and fragile selectors
- **Don't style HTML tags directly** — style classes: `.nav__link` not `nav a`
- **Don't mix naming conventions** — pick BEM and use it everywhere
- **Don't use IDs for styling** — IDs have very high specificity
- **Don't use `@extend`** — it creates unexpected CSS output; use mixins instead
- **Don't set `outline: none` without a `:focus-visible` alternative** — accessibility violation
