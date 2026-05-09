---
description: 'Playwright end-to-end testing patterns. USE FOR: writing e2e tests, page objects, locator strategies, accessibility assertions, visual regression, network mocking.'
---

# Playwright Best Practices

## Page Object Model

```typescript
// pages/login.page.ts
export class LoginPage {
  constructor(private page: Page) {}

  readonly emailInput = this.page.getByLabel('Email');
  readonly passwordInput = this.page.getByLabel('Password');
  readonly submitButton = this.page.getByRole('button', { name: 'Sign in' });
  readonly errorMessage = this.page.getByRole('alert');

  async goto() {
    await this.page.goto('/login');
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

## Test Structure

```typescript
test.describe('Login', () => {
  let loginPage: LoginPage;

  test.beforeEach(async ({ page }) => {
    loginPage = new LoginPage(page);
    await loginPage.goto();
  });

  test('should login successfully with valid credentials', async ({ page }) => {
    await loginPage.login('user@test.com', 'password');
    await expect(page).toHaveURL('/dashboard');
  });

  test('should show error for invalid credentials', async ({ page }) => {
    await loginPage.login('user@test.com', 'wrong');
    await expect(loginPage.errorMessage).toBeVisible();
    await expect(loginPage.errorMessage).toHaveText('Invalid credentials');
  });
});
```

## Test Isolation

- Each test gets a fresh browser context — no shared state between tests
- Use `test.beforeEach` for navigation and setup
- Use API calls to seed test data instead of UI flows: `await request.post('/api/seed', ...)`
- Clean up test data in `test.afterEach` if needed

## Fixtures

```typescript
// fixtures.ts
import { test as base } from '@playwright/test';
import { LoginPage } from './pages/login.page';

export const test = base.extend<{ loginPage: LoginPage }>({
  loginPage: async ({ page }, use) => {
    const loginPage = new LoginPage(page);
    await loginPage.goto();
    await use(loginPage);
  },
});
```

## Accessibility Assertions

```typescript
import AxeBuilder from '@axe-core/playwright';

test('should have no accessibility violations', async ({ page }) => {
  await page.goto('/dashboard');
  const results = await new AxeBuilder({ page }).analyze();
  expect(results.violations).toEqual([]);
});
```

- Run axe checks on every page/dialog in the test suite
- Exclude known false positives with `.exclude('.third-party-widget')`
- Test keyboard navigation: `await page.keyboard.press('Tab')` → verify focus

## Network Mocking

```typescript
test('should display data from API', async ({ page }) => {
  await page.route('/api/users', (route) => {
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify([{ id: 1, name: 'Test User' }]),
    });
  });

  await page.goto('/users');
  await expect(page.getByText('Test User')).toBeVisible();
});
```

- Mock external APIs to avoid flaky tests
- Use `route.fulfill()` for static responses
- Use `route.continue()` to modify requests/responses on the fly
- Test error states by mocking 500/404 responses

## Visual Regression

```typescript
test('dashboard should match snapshot', async ({ page }) => {
  await page.goto('/dashboard');
  await expect(page).toHaveScreenshot('dashboard.png', {
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
