---
description: 'Review code changes for bugs, security issues, and best practices. Use when: reviewing uncommitted changes, reviewing a PR, checking code quality before committing.'
---

Review all uncommitted changes in this project. Analyze every modified and new file.

## Review Checklist

For each file, check:

### Correctness
- Logic errors, off-by-one bugs, incorrect conditions
- Null/undefined handling — missing checks at boundaries
- Async/await correctness — missing awaits, unhandled promise rejections
- Type safety — `any` usage, unsafe assertions, missing type guards

### Security
- Injection vulnerabilities (SQL, XSS, template injection)
- Auth/authz bypasses — missing guards, exposed routes
- Data exposure — sensitive data in logs, responses, or error messages
- Path traversal — unsanitized file paths
- Hardcoded secrets or environment-specific values

### Performance
- Unbounded loops or recursive calls
- N+1 query patterns
- Missing pagination on list endpoints
- Unnecessary re-renders (Angular: OnPush violations, signal misuse)
- Large bundle imports when tree-shakeable alternatives exist

### Best Practices
- Matches existing project patterns and conventions
- Proper error handling at system boundaries
- Tests cover new logic — happy path + at least one error path
- No debug code, TODOs, `console.log`, or commented-out code remains
- Accessibility — new UI has proper labels, keyboard nav, ARIA attributes

### Angular-Specific (if applicable)
- Child/presentational components use `ChangeDetectionStrategy.OnPush`
- No manual subscribes without cleanup (`takeUntilDestroyed`)
- Signal inputs preferred over `@Input()` decorators
- No `getValue()` on BehaviorSubjects
- No nested subscribes
- Material component overrides use CSS custom properties, not `!important`

## Output Format

Present findings grouped by severity:

### 🔴 Critical (must fix before merging)
<!-- Bugs, security issues, data loss risks -->

### 🟡 Should Fix (important but not blocking)
<!-- Performance issues, missing error handling, test gaps -->

### 🔵 Suggestions (nice to have)
<!-- Style improvements, minor refactors, pattern alignment -->

### ✅ What Looks Good
<!-- Briefly note well-written code, good patterns, thorough testing -->

For each finding, include:
- **File and location**
- **What's wrong** (1–2 sentences)
- **Suggested fix** (code snippet if helpful)
