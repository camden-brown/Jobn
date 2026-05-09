---
description: 'TypeScript strict-mode patterns, type safety, and idioms. USE FOR: writing type-safe code, defining interfaces, handling unknown data, discriminated unions.'
---

# TypeScript Best Practices

## Strict Mode

- Always work with `strict: true` in tsconfig — never disable individual strict flags
- Enable `noUncheckedIndexedAccess` for safer array/object access
- Enable `exactOptionalPropertyTypes` when the project supports it

## Type Safety

- **Never use `any`** — use `unknown` at system boundaries (API responses, parsed JSON, user input) and narrow with type guards
- Prefer `interface` for object shapes, `type` for unions, intersections, and mapped types
- Use `readonly` for properties and arrays that shouldn't be mutated
- Use `as const` for literal types and exhaustive checking

## Discriminated Unions

```typescript
type Result<T> = { success: true; data: T } | { success: false; error: string };
```

- Use a common literal property (`type`, `kind`, `status`) as the discriminant
- Handle every variant — use exhaustive switch with `never` default

## Utility Types

| Type                              | Use Case                            |
| --------------------------------- | ----------------------------------- |
| `Partial<T>`                      | Optional update payloads            |
| `Required<T>`                     | Enforce all properties              |
| `Pick<T, K>`                      | Select specific properties          |
| `Omit<T, K>`                      | Exclude specific properties         |
| `Record<K, V>`                    | Dictionary/map types                |
| `Extract<T, U>` / `Exclude<T, U>` | Filter union members                |
| `NonNullable<T>`                  | Remove null/undefined               |
| `ReturnType<T>`                   | Infer return type of a function     |
| `Parameters<T>`                   | Infer parameter types of a function |

## Type Guards

- Use `is` return type for custom type guards: `function isUser(x: unknown): x is User`
- Prefer `in` operator for discriminated unions over type assertions
- Use `satisfies` operator to validate a value matches a type without widening

## Generics

- Use constraints: `<T extends BaseType>` — not bare `<T>`
- Name generics meaningfully for complex signatures: `<TInput, TOutput>` not `<T, U>`
- Provide defaults when a generic has a common case: `<T = string>`

## Enums

- Prefer `const enum` or union literal types over regular enums for tree-shaking
- If using enums, use string enums for debuggability: `enum Status { Active = 'ACTIVE' }`

## Null Handling

- Use optional chaining `?.` and nullish coalescing `??` — not `&&` chains or `|| ''`
- Be explicit about `null` vs `undefined` — pick one convention and stick to it
- Use `!` non-null assertion only when the type system truly can't know (rare)

## Patterns to Avoid

- `as` type assertions — narrow instead of assert
- `@ts-ignore` / `@ts-expect-error` — fix the type error or add a proper type guard
- Index signatures when a `Map<K, V>` is more appropriate
- Overloads when a union parameter works
- Re-exporting types without `type` keyword — use `export type { Foo }` for type-only exports
