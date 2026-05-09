---
description: 'Sentry error monitoring patterns: error boundaries, breadcrumbs, performance tracing, source maps, release tracking. USE FOR: implementing error tracking, performance monitoring, debugging context.'
---

# Sentry Best Practices

## Setup & Configuration

```typescript
import * as Sentry from '@sentry/angular';

Sentry.init({
  dsn: 'https://...@sentry.io/...',
  environment: environment.name, // 'production', 'staging', 'development'
  release: `myapp@${version}`, // ties errors to deploys
  tracesSampleRate: 0.1, // 10% of transactions for performance
  replaysSessionSampleRate: 0.01, // 1% of sessions for replay
  replaysOnErrorSampleRate: 1.0, // 100% of error sessions for replay
  integrations: [
    Sentry.browserTracingIntegration(),
    Sentry.replayIntegration(),
  ],
  // Scrub sensitive data
  beforeSend(event) {
    if (event.request?.headers) {
      delete event.request.headers['Authorization'];
    }
    return event;
  },
});
```

## Error Boundaries (Angular)

```typescript
// Global error handler
@Injectable()
export class SentryErrorHandler implements ErrorHandler {
  handleError(error: unknown): void {
    Sentry.captureException(error);
    console.error(error); // still log locally
  }
}

// app.config.ts
providers: [
  { provide: ErrorHandler, useClass: SentryErrorHandler },
  { provide: Sentry.TraceService, deps: [Router] },
  {
    provide: APP_INITIALIZER,
    useFactory: () => () => {},
    deps: [Sentry.TraceService],
    multi: true,
  },
];
```

### When to Capture Manually

```typescript
try {
  await riskyOperation();
} catch (error) {
  Sentry.captureException(error, {
    tags: { operation: 'data-import', userId: user.id },
    extra: { fileSize: file.size, rowCount: rows.length },
  });
  // Handle gracefully for the user
  this.showErrorNotification('Import failed. Please try again.');
}
```

- Capture exceptions you **handle** gracefully but still want to know about
- Don't capture expected errors (validation failures, 404s from user typos)
- Don't capture errors you rethrow — they'll be caught by the global handler

## Breadcrumbs

Breadcrumbs are automatically captured for: console logs, DOM clicks, XHR/fetch requests, navigation. Add custom breadcrumbs for business-critical flows:

```typescript
Sentry.addBreadcrumb({
  category: 'checkout',
  message: `Added ${item.name} to cart`,
  level: 'info',
  data: { itemId: item.id, quantity: qty, cartTotal: cart.total },
});
```

### Rules

- Add breadcrumbs at decision points in business flows (checkout steps, onboarding stages)
- Use consistent categories: `auth`, `checkout`, `navigation`, `api`, `user-action`
- Keep data minimal — enough to reproduce, not a full state dump
- **Never include PII** in breadcrumb data (no emails, passwords, tokens)

## Custom Context

```typescript
// Set user context after login
Sentry.setUser({
  id: user.id,
  email: user.email, // only if your privacy policy allows
  segment: user.plan,
});

// Set tags for filtering in Sentry UI
Sentry.setTag('feature', 'analytics-dashboard');
Sentry.setTag('tenant', user.tenantId);

// Set extra data for debugging (not searchable)
Sentry.setExtra('featureFlags', posthog.getActiveFlags());

// Clear on logout
Sentry.setUser(null);
```

### Tags vs Extra

| Use Tags                                     | Use Extra                        |
| -------------------------------------------- | -------------------------------- |
| Searchable, filterable                       | Not searchable — debugging only  |
| Low cardinality (environment, feature, plan) | High cardinality or complex data |
| `Sentry.setTag('key', 'value')`              | `Sentry.setExtra('key', data)`   |

## Performance Transactions

```typescript
// Automatic: HTTP requests and route changes are traced by browserTracingIntegration

// Manual transaction for custom operations
const transaction = Sentry.startTransaction({
  name: 'data-import',
  op: 'task',
});

const span = transaction.startChild({
  op: 'parse',
  description: 'Parse CSV file',
});
// ... do work ...
span.finish();

transaction.finish();
```

- Use automatic tracing for HTTP and routing — don't re-instrument those
- Add manual transactions for background tasks, data processing, complex user flows
- Keep `tracesSampleRate` low in production (0.05–0.2) to manage costs

## Source Maps

- Upload source maps as part of CI/CD — never ship them to production
- Use `@sentry/webpack-plugin` or `@sentry/vite-plugin` for automatic upload
- Match the `release` value in `Sentry.init()` to the release in source map upload
- Delete source maps from the build output after uploading to Sentry

```bash
# In CI pipeline
npx sentry-cli releases files $RELEASE upload-sourcemaps ./dist --url-prefix '~/'
npx sentry-cli releases finalize $RELEASE
```

## Release Tracking

- Create a Sentry release for every deployment: ties errors to specific code versions
- Use deploy tracking to know which environment has which release
- Set up release health alerts: crash-free session rate < 99%

## Environment Tagging

| Environment   | `tracesSampleRate` | `replaysSessionSampleRate` | Notes                   |
| ------------- | ------------------ | -------------------------- | ----------------------- |
| `production`  | 0.05–0.1           | 0.01                       | Cost-conscious sampling |
| `staging`     | 0.5–1.0            | 0.1                        | More visibility for QA  |
| `development` | 0 (disabled)       | 0                          | Use console, not Sentry |

## Sensitive Data Scrubbing

- Use `beforeSend` to strip headers, cookies, and request bodies containing tokens
- Configure `denyUrls` to ignore errors from third-party scripts
- Use Sentry's server-side data scrubbing for fields like `password`, `ssn`, `credit_card`
- Never send auth tokens, API keys, or session tokens as tags/extra data

## Patterns to Avoid

- Don't capture `console.error` output AND the original exception — you'll get duplicates
- Don't set `tracesSampleRate: 1.0` in production — the cost will surprise you
- Don't ignore Sentry quota alerts — uncontrolled error volume is a symptom
- Don't use generic messages: `Sentry.captureMessage('error occurred')` — capture the actual exception
- Don't forget to call `Sentry.setUser(null)` on logout
