---
description: "Playwright end-to-end testing patterns. USE FOR: writing e2e tests, page objects, locator strategies, accessibility assertions, visual regression, network mocking."
---

# Playwright Best Practices

## Test Naming — Acceptance Criteria Convention

Test names MUST read as **user acceptance criteria**: declarative statements describing expected behavior from the user's perspective. Do NOT use `should` prefixes or implementation-centric wording.

```typescript
// GOOD — reads as an acceptance criterion
test('the application toolbar is visible on app pages', ...);
test('clicking new chat in the sidebar navigates to the new chat page', ...);
test('returning users are not shown the onboarding dialog', ...);
test('a no-results message is shown when search finds no matches', ...);

// BAD — implementation-centric or "should" style
test('should render toolbar', ...);
test('renders the toolbar', ...);
test('redirects root to /app', ...);
test('upload endpoint is called when a file is attached', ...);
```

Guidelines:

- Write from the user's perspective: "the user sees…", "clicking X navigates to…", "first-time users are presented with…"
- Use `test.describe` for the feature area (e.g. `'Navigation'`, `'Chat'`, `'File Uploads'`)
- Each `test()` name is a standalone acceptance criterion that is meaningful in test reports
- Avoid technical jargon in test names; prefer domain language

## Mock Data — Factory Pattern

All mock data MUST be generated via factory functions using `@faker-js/faker`. Factories live in `e2e/support/factories/` and are barrel-exported from `e2e/support/factories/index.ts`.

```typescript
// e2e/support/factories/thread.factory.ts
import { faker } from "@faker-js/faker";
import type { Thread } from "../../../src/app/shared/models/threads.model";

faker.seed(42);

export function createThread(overrides: Partial<Thread> = {}): Thread {
  return {
    id: faker.string.uuid(),
    title: faker.lorem.sentence(),
    created_at: faker.date.recent().getTime() / 1000,
    pinned: false,
    ...overrides,
  };
}
```

Rules:

- Every factory accepts a `Partial<T>` overrides argument so tests can customize only what matters
- Use `faker.seed(42)` at the top of each factory file for deterministic output
- Use stable IDs (e.g. `'e2e-thread-001'`) in `mock-data.ts` for tests that assert on specific values
- Import from `'../support/factories'` in test files, not from mock-data wrappers
- Factory files: `auth.factory.ts`, `thread.factory.ts`, `file.factory.ts`, `app.factory.ts`

## Route Handlers — Domain Separation

API route handlers are split by domain in `e2e/support/handlers/`:

```
e2e/support/
  handlers/
    auth.handlers.ts      ← /v1/me, /v1/me/groups, MSAL blocking
    thread.handlers.ts    ← /v1/threads CRUD + datasets
    file.handlers.ts      ← /v1/threads/:id/files, /v1/files/:id
    app.handlers.ts       ← /v1/sources, /v1/onboarding, /v1/models
  api-handlers.ts         ← orchestrator that composes all handlers
```

Registration order matters (last-registered wins in Playwright):

1. File handlers (broadest regex patterns)
2. Thread handlers
3. App handlers
4. Auth handlers (most specific, highest priority)

Handlers import from factories, not from mock-data:

```typescript
import { createThread, createDeleteResponse } from "../factories";
```

## Project Structure

```
apps/graphite-chat-ui/e2e/
  playwright.config.ts           ← Chromium only, static server via `serve`
  tsconfig.json
  fixtures/test.fixture.ts       ← authenticatedPage + mockOverrides
  support/
    constants.ts                 ← API_URL, escapeRegex
    msal-setup.ts                ← MSAL localStorage cache for fake auth
    mock-data.ts                 ← stable-ID wrappers over factories
    api-handlers.ts              ← orchestrator
    factories/                   ← @faker-js/faker factory functions
    handlers/                    ← domain-specific route handlers
  tests/
    navigation.spec.ts
    chat.spec.ts
    file-uploads.spec.ts
    thread-management.spec.ts
    onboarding.spec.ts
    tutorials.spec.ts
```

## Running Tests

```bash
# Full suite
npm run e2e

# With visible browser
npx playwright test --config=apps/graphite-chat-ui/e2e/playwright.config.ts --headed

# Single file
npx playwright test --config=apps/graphite-chat-ui/e2e/playwright.config.ts tests/chat.spec.ts

# Docker
npm run e2e:docker
```

## Page Object Model

```typescript
export class LoginPage {
  constructor(private page: Page) {}

  readonly emailInput = this.page.getByLabel("Email");
  readonly passwordInput = this.page.getByLabel("Password");
  readonly submitButton = this.page.getByRole("button", { name: "Sign in" });
  readonly errorMessage = this.page.getByRole("alert");

  async goto() {
    await this.page.goto("/login");
  }

  async login(email: string, password: string) {
    await this.emailInput.fill(email);
    await this.passwordInput.fill(password);
    await this.submitButton.click();
  }
}
```

- One page object per page or major component
- Expose locators as `readonly` properties
- Expose user actions as methods
- Never assert inside page objects — assertions belong in tests

## Locator Strategy (Priority Order)

1. **`getByRole`** — most accessible, most resilient: `page.getByRole('button', { name: 'Submit' })`
2. **`getByLabel`** — for form inputs: `page.getByLabel('Email')`
3. **`getByText`** — for visible text content: `page.getByText('Welcome back')`
4. **`getByTestId`** — last resort for elements without accessible roles: `page.getByTestId('chart-container')`
5. **Avoid**: CSS selectors, XPath, class names, IDs (fragile, break on refactors)

## Test Isolation

- Each test gets a fresh browser context — no shared state between tests
- Use `test.beforeEach` for navigation and setup
- Use API calls to seed test data instead of UI flows
- Clean up test data in `test.afterEach` if needed

## Fixtures

```typescript
import { test as base } from "@playwright/test";

export const test = base.extend<{ authenticatedPage: Page }>({
  authenticatedPage: async ({ page }, use) => {
    // inject MSAL cache + setup API mocks
    await use(page);
  },
});
```

## Accessibility Assertions

```typescript
import AxeBuilder from "@axe-core/playwright";

test("the dashboard has no accessibility violations", async ({ page }) => {
  await page.goto("/dashboard");
  const results = await new AxeBuilder({ page }).analyze();
  expect(results.violations).toEqual([]);
});
```

## Network Mocking

```typescript
test("user data is displayed after loading", async ({ page }) => {
  await page.route("/api/users", (route) =>
    route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify([createUser({ name: "Test User" })]),
    }),
  );

  await page.goto("/users");
  await expect(page.getByText("Test User")).toBeVisible();
});
```

- Mock all external APIs via route handlers to avoid flaky tests
- Use `route.fulfill()` for static responses
- Use `route.continue()` to modify requests/responses on the fly
- Test error states by mocking 500/404 responses

## Visual Regression

```typescript
test("the dashboard matches the visual snapshot", async ({ page }) => {
  await page.goto("/dashboard");
  await expect(page).toHaveScreenshot("dashboard.png", {
    maxDiffPixelRatio: 0.01,
  });
});
```

- Use `toHaveScreenshot` with a tolerance threshold
- Update snapshots deliberately: `npx playwright test --update-snapshots`
- Mask dynamic content (dates, avatars) with `mask: [page.locator('.timestamp')]`

## Waiting

- **Don't use `page.waitForTimeout()`** — it's flaky and slow
- Prefer auto-waiting via locator assertions: `await expect(locator).toBeVisible()`
- Use `page.waitForResponse()` when you need to wait for a specific API call
- Use `page.waitForLoadState('networkidle')` sparingly — only for complex SPAs
