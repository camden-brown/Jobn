---
description: 'JSDoc documentation conventions. USE FOR: documenting public APIs, complex logic, non-obvious parameters, and library interfaces.'
---

# JSDoc Best Practices

## When to Document

**Always document:**

- Public API surfaces (exported functions, classes, interfaces, types)
- Complex business logic that isn't self-evident from the code
- Non-obvious parameters (units, formats, ranges, side effects)
- Functions with more than 2 parameters
- Functions that throw errors
- Deprecated code (with migration path)

**Skip documentation for:**

- Self-documenting code (e.g., `getUserById(id: string): User`)
- Private/internal helpers with clear names
- Simple property assignments with typed interfaces
- Test files
- Redundant docs that just restate the type signature

## Core Tags

````typescript
/**
 * Calculate the total price including tax and discounts.
 *
 * @param items - Cart items to price (must not be empty)
 * @param taxRate - Tax rate as a decimal (e.g., 0.08 for 8%)
 * @param discountCode - Optional promo code to apply
 * @returns The total price in cents (integer)
 * @throws {EmptyCartError} If items array is empty
 * @example
 * ```ts
 * const total = calculateTotal(items, 0.08, 'SAVE10');
 * // => 5432 (cents)
 * ```
 */
````

## Tag Reference

| Tag           | When to Use                                                         |
| ------------- | ------------------------------------------------------------------- |
| `@param`      | Every parameter — include units, ranges, or format if non-obvious   |
| `@returns`    | Every function with a non-void return — describe what, not the type |
| `@throws`     | Every thrown error — include the error type and condition           |
| `@example`    | Complex functions, utilities, and public APIs                       |
| `@deprecated` | Always include what to use instead                                  |
| `@see`        | Link to related functions, external docs, or tickets                |
| `@internal`   | Mark as not part of the public API                                  |

## Style Rules

- Write descriptions as imperative sentences: "Calculate the total" not "Calculates the total" or "This function calculates the total"
- `@param name -` format (hyphen after name, not colon)
- Don't restate the TypeScript type in the description — focus on semantics
- Keep descriptions to one line when possible
- Use `@example` with runnable code snippets inside triple-backtick blocks
- Group related `@param` tags — don't interleave other tags

## Interface/Type Documentation

```typescript
/** Configuration for the retry mechanism. */
interface RetryConfig {
  /** Maximum number of retry attempts (1-10). */
  maxRetries: number;
  /** Base delay between retries in milliseconds. Actual delay uses exponential backoff. */
  baseDelay: number;
  /** If true, adds random jitter to prevent thundering herd. */
  jitter?: boolean;
}
```

## What NOT to Do

```typescript
// ❌ Redundant — restates the type signature
/** Gets a user by their ID. */
function getUserById(id: string): User { ... }

// ❌ Meaningless — adds no value
/** The name. */
name: string;

// ❌ Stale — describes old behavior
/** Returns the user's full name. */
function getDisplayName(): string { return this.email; }
```

## Module-Level Documentation

Use a top-of-file comment for modules with non-obvious purpose:

```typescript
/**
 * @module analytics
 *
 * PostHog event tracking utilities. Wraps the PostHog SDK with
 * type-safe event definitions and automatic property enrichment.
 *
 * @see {@link https://posthog.com/docs}
 */
```
