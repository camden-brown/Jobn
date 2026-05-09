---
description: 'Structured debugging: stack traces, common Angular/Node error patterns, isolating test failures, performance profiling. USE FOR: diagnosing bugs, reading error output, isolating failures, performance issues.'
---

# Debugging

## Reading Stack Traces

### JavaScript / TypeScript
- Read **bottom-up** — the top frame is where the error was thrown, lower frames show the call chain
- Look for **your code first** — skip `node_modules/`, `zone.js`, `rxjs/internal/` frames
- `at Object.<anonymous>` usually means top-level module code
- `at async` prefix = the frame crossed an `await` boundary
- Source maps: if you see `.js` paths, check that source maps are enabled (`sourceMap: true` in tsconfig)

### Angular-Specific Stack Traces
- `ExpressionChangedAfterItHasBeenCheckedError` — read the component name from the error, check template bindings that modify state during change detection
- `NullInjectorError: No provider for X` — the service/token is missing from `providers` in the component, route, or `app.config.ts`
- `NG0100` through `NG0999` — Angular error codes. Look up at `angular.io/errors/{code}`
- Zone.js wraps stack traces — the real cause is usually 2-3 frames deep

### Node.js Stack Traces
- `ERR_MODULE_NOT_FOUND` — check `exports` field in `package.json`, file extension, path casing
- `ECONNREFUSED` — target service is not running or wrong port
- `ENOMEM` / `heap out of memory` — increase with `--max-old-space-size=4096`
- Unhandled rejection traces: add `process.on('unhandledRejection', ...)` to catch these globally during debugging

## Common Error Patterns

### Angular
| Error | Likely Cause | Fix |
|-------|-------------|-----|
| `ExpressionChangedAfterItHasBeenChecked` | Mutating state in lifecycle hook or getter | Move logic to a signal/computed, or use `afterNextRender` |
| `NullInjectorError` | Missing provider | Add to `providers` or use `providedIn: 'root'` |
| `Can't bind to 'X' since it isn't a known property` | Missing import of component/directive | Import the standalone component in the parent's `imports` |
| `Circular dependency detected` | A imports B imports A | Extract shared code to a third module |
| `404 on lazy-loaded route` | Incorrect `loadComponent` path | Check the import path, use relative paths |
| `NG0203: inject() must be called from an injection context` | `inject()` called outside constructor/field initializer | Move to field initializer or constructor body |

### Node.js / Express
| Error | Likely Cause | Fix |
|-------|-------------|-----|
| `Cannot read properties of undefined` | Missing null check | Add optional chaining or guard clause at boundary |
| `CORS error` | Missing CORS headers | Add `cors()` middleware with correct origin |
| `JWT malformed` | Token parsing issue | Check `Authorization` header format: `Bearer {token}` |
| `EADDRINUSE` | Port already in use | Kill the process: `lsof -ti:{port} \| xargs kill` |
| `TypeError: X is not a function` | Wrong import (default vs named) | Check export: `export default` vs `export { X }` |

### TypeScript
| Error | Likely Cause | Fix |
|-------|-------------|-----|
| `TS2322: Type 'X' is not assignable to type 'Y'` | Type mismatch | Check the types; use type narrowing, not `as` |
| `TS2345: Argument of type 'X' is not assignable` | Wrong argument type | Check function signature; narrow or transform the input |
| `TS7053: Element implicitly has an 'any' type` | Indexing with `string` on unknown keys | Use a `Record<string, T>` or add an index signature |
| `TS2339: Property 'X' does not exist on type 'Y'` | Missing property or wrong type | Check the interface; narrow with type guard if it's a union |

## Isolating Test Failures

### Strategy
1. **Run the single failing test** — `npx jest path/to/file --testNamePattern "test name"` or `npx vitest path/to/file -t "test name"`
2. **Check if it's flaky** — run it 3 times in isolation. If it passes alone but fails in suite, it's a test interaction issue
3. **Check test order dependency** — run with `--runInBand` (Jest) to force sequential execution
4. **Check for leaked state** — look for shared mutable state, missing `beforeEach` resets, module-level variables
5. **Add `console.log` at the assertion** — verify actual vs expected values right before the assertion

### Common Test Issues
- **Timer-dependent tests** — use `fakeAsync` / `jest.useFakeTimers()`, not real `setTimeout`
- **Async test not awaiting** — missing `await`, missing `fakeAsync`/`tick`, or missing `done()` callback
- **Angular TestBed pollution** — `TestBed.resetTestingModule()` between tests if configuring differently
- **Mock not resetting** — use `jest.restoreAllMocks()` in `afterEach`
- **HTTP test not flushing** — `httpTestingController.verify()` at end, `req.flush()` for each expected request

## Performance Debugging

### Frontend (Angular)
1. **Profile with Chrome DevTools** — Performance tab → Record → reproduce the issue
2. **Check change detection** — look for excessive `ngDoCheck` calls in the profiler
3. **Bundle analysis** — `npx ng build --stats-json && npx webpack-bundle-analyzer dist/stats.json`
4. **Runtime performance** — `console.time('label')` / `console.timeEnd('label')` around suspect code
5. **Memory leaks** — Chrome DevTools → Memory tab → take heap snapshots before/after navigation

### Backend (Node.js)
1. **CPU profiling** — `node --prof app.js` then `node --prof-process isolate-*.log`
2. **Memory** — `process.memoryUsage()` at intervals; watch for `heapUsed` growing without bound
3. **Slow queries** — log query execution time; check for missing indexes, full table scans
4. **Event loop lag** — `perf_hooks.monitorEventLoopDelay()` or use `clinic.js`

### Quick Performance Wins
- Add `trackBy` to `*ngFor` / `@for` loops
- Use `OnPush` change detection on child/presentational components
- Lazy-load routes and heavy components
- Use `loading="lazy"` on images below the fold
- Debounce search inputs (300ms)
- Virtual scroll for long lists (`cdk-virtual-scroll-viewport`)
