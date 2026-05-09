---
description: 'PostHog analytics patterns: event taxonomy, feature flags, session recordings, group analytics. USE FOR: implementing analytics tracking, feature flags, A/B tests, user identification.'
---

# PostHog Best Practices

## Event Taxonomy

### Naming Convention

- Use `object_action` format: `page_viewed`, `button_clicked`, `form_submitted`
- Lowercase with underscores — consistent, grep-friendly
- Be specific: `signup_form_submitted` not `form_submitted`
- Prefix domain events: `checkout_started`, `checkout_completed`, `checkout_abandoned`

### Event Categories

| Category      | Pattern              | Examples                              |
| ------------- | -------------------- | ------------------------------------- |
| Page views    | `{page}_viewed`      | `dashboard_viewed`, `settings_viewed` |
| User actions  | `{object}_{action}`  | `report_exported`, `filter_applied`   |
| System events | `{system}_{event}`   | `api_error_occurred`, `cache_miss`    |
| Feature usage | `{feature}_{action}` | `search_used`, `bulk_edit_started`    |

### Property Naming

- Use `snake_case` for all property names
- Prefix with `$` only for PostHog's built-in properties — never for custom ones
- Include context: `source`, `variant`, `count`, `duration_ms`
- Use consistent value types: booleans for flags, numbers for counts, strings for categories

```typescript
posthog.capture('report_exported', {
  report_type: 'monthly_summary',
  format: 'pdf',
  row_count: 150,
  duration_ms: 2340,
  source: 'dashboard',
});
```

## Custom Events vs Autocapture

| Use Custom Events                              | Use Autocapture                           |
| ---------------------------------------------- | ----------------------------------------- |
| Business-critical actions (purchases, signups) | Exploratory analysis of click patterns    |
| Events needing structured properties           | Quick validation of UI engagement         |
| Funnel steps you'll track long-term            | Retroactive analysis before instrumenting |
| Anything with numeric/complex properties       | Low-priority interaction tracking         |

**Rule**: If you'll build a dashboard or alert on it, use a custom event. Autocapture is for discovery.

## User Identification

```typescript
// After login — link anonymous events to the user
posthog.identify(user.id, {
  email: user.email,
  name: user.name,
  plan: user.subscription.plan,
  company_id: user.companyId,
});

// On logout — reset to anonymous
posthog.reset();
```

### Rules

- Call `identify` once per session (after login), not on every page
- Set person properties that are useful for filtering: `plan`, `role`, `company_id`
- **Never send PII you don't need** — don't send passwords, tokens, SSNs
- Use `posthog.alias(newId, oldId)` when merging accounts

## Group Analytics

```typescript
// Associate user with their company
posthog.group('company', user.companyId, {
  name: user.companyName,
  plan: 'enterprise',
  employee_count: 150,
});
```

- Use groups for B2B analytics — analyze behavior at the company/team level
- Set group properties that are useful for segmentation
- Group types: `company`, `team`, `project` — define in PostHog settings

## Feature Flags

```typescript
// Boolean flag
if (posthog.isFeatureEnabled('new-dashboard')) {
  showNewDashboard();
}

// Multivariate flag
const variant = posthog.getFeatureFlag('checkout-flow');
if (variant === 'streamlined') {
  showStreamlinedCheckout();
}

// With payload
const config = posthog.getFeatureFlagPayload('pricing-experiment');
```

### Best Practices

- Use descriptive flag names: `new-dashboard-v2` not `flag-123`
- Always provide a fallback for when the flag isn't loaded yet
- Clean up flags after rollout is complete — remove the conditional code
- Use `posthog.onFeatureFlags(() => { ... })` to wait for flags to load
- Log flag evaluations as events for debugging: PostHog does this automatically with `$feature_flag_called`

## Session Recordings

- Enable recording for targeted user segments, not all traffic (cost management)
- Use `posthog.capture('$recording_start')` to programmatically trigger recording for specific flows
- Mask sensitive inputs with `data-ph-no-capture` attribute
- Use `data-ph-capture-attribute-*` for custom element identification in recordings

## Angular Integration

```typescript
// app.config.ts
import posthog from 'posthog-js';

posthog.init('phc_...', {
  api_host: 'https://app.posthog.com',
  capture_pageview: false, // handle manually with Angular router
});

// Router event tracking
this.router.events
  .pipe(
    filter((event) => event instanceof NavigationEnd),
    takeUntilDestroyed(this.destroyRef),
  )
  .subscribe((event: NavigationEnd) => {
    posthog.capture('$pageview', { $current_url: event.urlAfterRedirects });
  });
```

## Patterns to Avoid

- Don't capture everything — high event volume with no analysis plan wastes money
- Don't use autocapture as your primary tracking strategy
- Don't send raw user input as event properties (search queries are OK if not sensitive)
- Don't call `identify` on every page load — only after authentication
- Don't hardcode feature flag fallbacks that match the "off" state — default to the existing behavior
