---
description: 'Angular best practices for standalone components, signals, Material, PWA, and reactive patterns. USE FOR: implementing Angular features, components, services, routing, forms, interceptors.'
---

# Angular Best Practices

## Standalone Components (Default)

- All new components, directives, and pipes should be `standalone: true` (default in Angular 17+)
- Import dependencies directly in the component's `imports` array — no NgModules for new code
- Use `@Component({ standalone: true, imports: [...] })` pattern

## Signals (Preferred State Management)

- Use `signal()` for component-local state instead of plain properties
- Use `computed()` for derived state — replaces most getter patterns
- Use `effect()` sparingly — only for side effects (logging, localStorage sync, DOM manipulation)
- Prefer `input()` and `output()` signal-based APIs over `@Input()` / `@Output()` decorators
- Use `model()` for two-way binding with signals
- Convert RxJS observables to signals with `toSignal()` at component boundaries

## Change Detection

- Use `ChangeDetectionStrategy.OnPush` on child/presentational components
- Signals and `async` pipe work naturally with OnPush
- Never mutate objects/arrays in place — always create new references

## Angular Material

- Import individual Material modules (e.g., `MatButtonModule`, `MatInputModule`) — never import the entire library
- Use the theme's color palette via Angular Material's theming system — never hardcode Material colors
- Follow the Material Design density and spacing conventions
- Use `mat-form-field` with `appearance="outline"` consistently within a project (or match existing)
- Prefer `mat-dialog` for modals, `mat-snack-bar` for notifications — don't build custom equivalents

### Defining a Theme

Angular Material M3 themes are defined using `mat.defineTheme()` in a central SCSS file (e.g., `styles.scss` or `theme.scss`):

```scss
@use '@angular/material' as mat;

$my-theme: mat.define-theme(
  (
    color: (
      theme-type: light,
      primary: mat.$azure-palette,
      tertiary: mat.$blue-palette,
    ),
    typography: (
      brand-family: 'Roboto',
      plain-family: 'Roboto',
    ),
    density: (
      scale: 0,
    ),
  )
);

// Apply the theme globally
html {
  @include mat.all-component-themes($my-theme);
}
```

### Custom Theme Palettes

For brand colors that don't match a built-in palette, generate a custom palette from a single source color:

```scss
$my-theme: mat.define-theme(
  (
    color: (
      theme-type: light,
      primary: mat.$azure-palette,
      // Use a custom color — Material generates the full tonal palette
      tertiary: mat.$green-palette,
    ),
  )
);
```

For fully custom palettes beyond the built-in options, define the tonal palette map following the M3 tonal palette structure and pass it to the theme definition.

### Dark Mode

```scss
$dark-theme: mat.define-theme(
  (
    color: (
      theme-type: dark,
      primary: mat.$azure-palette,
      tertiary: mat.$blue-palette,
    ),
  )
);

// Apply dark theme via class or media query
.dark-theme {
  @include mat.all-component-colors($dark-theme);
}

// Or with prefers-color-scheme
@media (prefers-color-scheme: dark) {
  html {
    @include mat.all-component-colors($dark-theme);
  }
}
```

### Accessing Theme Colors in Custom Components

Use `mat.get-theme-color()` to pull colors from the active theme — **never hardcode hex values**:

```scss
@use '@angular/material' as mat;

// Access semantic roles from the theme
.my-header {
  background-color: mat.get-theme-color($my-theme, primary);
  color: mat.get-theme-color($my-theme, on-primary);
}

.my-card {
  background-color: mat.get-theme-color($my-theme, surface);
  color: mat.get-theme-color($my-theme, on-surface);
  border: 1px solid mat.get-theme-color($my-theme, outline);
}

.my-error {
  color: mat.get-theme-color($my-theme, error);
}
```

Available color roles: `primary`, `on-primary`, `primary-container`, `on-primary-container`, `secondary`, `on-secondary`, `tertiary`, `on-tertiary`, `error`, `on-error`, `surface`, `on-surface`, `outline`, `outline-variant`, `surface-variant`, `on-surface-variant`, `inverse-surface`, `inverse-on-surface`, `inverse-primary`.

### Component Style Overrides

Override Material component styles **correctly** — most LLM-generated overrides are wrong. Follow this priority order:

#### 1. Component Override Mixins (Preferred for M3)

Angular Material M3 (v19+) provides `mat.<component>-overrides()` mixins for token-based customization. These are the primary way to override component styles:

```scss
@use '@angular/material' as mat;
@use './palette' as *;

// Override component tokens globally inside a mixin
@mixin material-overrides {
  @include mat.button-overrides((
    filled-container-color: $color-blue-700,
    filled-label-text-color: $color-white,
    filled-disabled-container-color: $color-grey-200,
    filled-disabled-label-text-color: $color-grey-500,
  ));
  @include mat.icon-button-overrides((
    disabled-icon-color: $color-grey-400,
  ));
  @include mat.form-field-overrides((
    error-text-color: $color-red-600,
    outlined-error-outline-color: $color-red-600,
  ));
  @include mat.card-overrides((
    outlined-container-color: $color-white,
    outlined-outline-color: $color-grey-200,
  ));
}
```

Apply the mixin in the global `html` selector:

```scss
html {
  @include mat.theme($my-theme);
  @include material-overrides;
}
```

#### 2. CSS Custom Properties via MDC Tokens (For Targeted/Scoped Overrides)

When you need to override a specific instance rather than all instances, use MDC CSS custom properties on a scoped class:

```scss
// Scoped override — only icon buttons with this class get primary color
.mat-mdc-icon-button.icon-button-primary:not(:disabled) {
  --mdc-icon-button-icon-color: #{$color-blue-700};
  color: #{$color-blue-700}; // needed when inside form-field suffix
}
```

**Important M3 caveats:**
- The `color` input (`color="primary"`) is **removed in Angular Material M3** (v19+). It no longer adds `.mat-primary` or sets color tokens.
- Form field suffixes (`matIconSuffix`) inherit `color` from `--mat-form-field-trailing-icon-color`. To override an icon button inside a suffix, you must set both `--mdc-icon-button-icon-color` AND `color` explicitly.
- Always test disabled vs enabled states separately — disabled tokens are different from active tokens.

#### 3. Theme Configuration (Legacy/Simple)

Use `mat.theme()` or individual component theme mixins:

```scss
@use '@angular/material' as mat;

@include mat.button-theme($my-theme);
@include mat.form-field-theme($my-theme);
```

#### 3. Inline CSS Custom Properties (For One-Off Element Overrides)

For individual element overrides in templates or component styles:

```scss
.mat-mdc-form-field {
  --mat-form-field-container-text-size: 0.875rem;
}

.mat-mdc-raised-button {
  --mdc-protected-button-container-shape: 8px;
}
```

#### 4. Component-Scoped `::ng-deep` (Last Resort)

`::ng-deep` pierces Angular's view encapsulation. Use **only** when CSS custom properties and theme config don't cover your case:

```scss
// ✅ Scoped with :host — limits the override to this component
:host ::ng-deep .mat-mdc-form-field-subscript-wrapper {
  display: none;
}

// ❌ Unscoped — affects ALL form fields in the app
::ng-deep .mat-mdc-form-field-subscript-wrapper {
  display: none;
}
```

**Rules for `::ng-deep`:**

- Always scope with `:host` to limit blast radius
- Never use in global `styles.scss` — only in component SCSS files
- Add a comment explaining WHY it's needed and what it overrides
- Check if a CSS custom property exists first — prefer that approach
- `::ng-deep` is deprecated but still functional; no replacement exists yet for encapsulated overrides

#### What NOT to Do

```scss
// ❌ Don't use !important to fight Material specificity
.mat-mdc-button {
  background-color: red !important;
}

// ❌ Don't target internal MDC class names directly in global styles
.mdc-button__label {
  font-weight: bold;
}

// ❌ Don't hardcode colors that should come from the theme
.mat-mdc-tab-header {
  background: #1976d2;
}

// ❌ Don't override Material typography with px units
.mat-mdc-card-title {
  font-size: 18px; // use theme typography or rem
}
```

### Density

Adjust component density for compact UIs (data tables, toolbars, dense forms):

```scss
$compact-theme: mat.define-theme(
  (
    density: (
      scale: -1,
      // -1 = compact, -2 = most compact, 0 = default
    ),
  )
);

// Apply density globally or scoped to a container
.compact-section {
  @include mat.all-component-densities($compact-theme);
}
```

### Typography

Use the theme's typography system instead of ad-hoc font styles:

```scss
.my-title {
  @include mat.typography-level($my-theme, headline-small);
}

.my-body {
  @include mat.typography-level($my-theme, body-medium);
}
```

Available levels: `display-large`, `display-medium`, `display-small`, `headline-large`, `headline-medium`, `headline-small`, `title-large`, `title-medium`, `title-small`, `body-large`, `body-medium`, `body-small`, `label-large`, `label-medium`, `label-small`.

## Routing

- Use lazy loading with `loadComponent` / `loadChildren` for route-level code splitting
- Implement route guards as functional guards (functions, not classes)
- Use `resolve` for data that must load before the route activates
- Use `canDeactivate` guards for unsaved-changes prompts

## Services & Dependency Injection

- Prefer `providedIn: 'root'` for singleton services
- Use `inject()` function instead of constructor injection
- Use `DestroyRef` with `takeUntilDestroyed()` for cleanup

## Reactive Forms (Preferred)

- Use typed reactive forms (`FormGroup`, `FormControl` with generics)
- Validate at the form level, not in templates
- Use custom validators as pure functions

## Interceptors

- Use functional interceptors (`HttpInterceptorFn`) instead of class-based
- Register via `provideHttpClient(withInterceptors([...]))`
- Common interceptors: auth token injection, error handling, loading state

## PWA Considerations

- Use `@angular/pwa` for service worker setup
- Implement offline-first data strategies with IndexedDB or Cache API
- Handle `SwUpdate` for version notifications
- Lazy-load non-critical assets

## File Organization

- Feature-based folder structure: `features/{feature}/` with component, service, model, spec files
- Shared utilities in `shared/` — components, pipes, directives, models
- Core singleton services in `core/`
- One component per file — no multi-component files
- Barrel exports (`index.ts`) for shared modules only — not inside features

## Patterns to Avoid

- Don't use `any` — use proper typing
- Don't subscribe in components — use `async` pipe or `toSignal()`
- Don't use `ngOnChanges` — use signal inputs or `computed()`
- Don't create services just to hold a single BehaviorSubject — use signals
- Don't use `setTimeout` for Angular-related timing — use proper lifecycle hooks or signals
