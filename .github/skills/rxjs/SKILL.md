---
description: 'RxJS operator selection, subscription management, and reactive patterns. USE FOR: choosing operators, preventing memory leaks, testing observables, Angular-specific RxJS patterns.'
---

# RxJS Best Practices

## Operator Selection Guide

### Flattening Operators (Most Common Decision)

| Operator     | Use When                                                     | Behavior                          |
| ------------ | ------------------------------------------------------------ | --------------------------------- |
| `switchMap`  | Only the latest matters (search, autocomplete, route params) | Cancels previous inner observable |
| `mergeMap`   | All results matter, order doesn't (parallel HTTP calls)      | Runs all concurrently             |
| `concatMap`  | All results matter, order matters (sequential writes)        | Queues, runs one at a time        |
| `exhaustMap` | Ignore new while busy (form submit, login)                   | Drops new until current completes |

**Default to `switchMap`** unless you have a reason for the others.

### Filtering

| Operator               | Use Case                                   |
| ---------------------- | ------------------------------------------ |
| `filter`               | Conditional pass-through                   |
| `distinctUntilChanged` | Skip consecutive duplicates                |
| `debounceTime`         | Wait for pause in emissions (search input) |
| `throttleTime`         | Rate-limit emissions (scroll events)       |
| `take(n)`              | Only first N values                        |
| `takeUntil`            | Complete when another observable emits     |
| `skip(n)`              | Ignore first N values                      |
| `first()`              | Take first value then complete             |

### Transformation

| Operator            | Use Case                                                       |
| ------------------- | -------------------------------------------------------------- |
| `map`               | Transform each value                                           |
| `tap`               | Side effects without modifying the stream (logging, analytics) |
| `scan`              | Accumulate state over time (like reduce but emits each step)   |
| `startWith`         | Provide an initial value                                       |
| `pairwise`          | Emit previous and current value as a pair                      |
| `withLatestFrom`    | Combine with the latest value from another observable          |
| `combineLatestWith` | Re-emit whenever any source emits                              |

### Error Handling

| Operator     | Use Case                                      |
| ------------ | --------------------------------------------- |
| `catchError` | Handle errors, return fallback observable     |
| `retry(n)`   | Retry N times on error                        |
| `retryWhen`  | Retry with custom logic (exponential backoff) |

**Always handle errors inside `switchMap`/`mergeMap` — not on the outer observable.** An unhandled error kills the entire stream.

```typescript
// ✅ Correct — error handled inside switchMap
this.search$.pipe(
  switchMap((query) =>
    this.api.search(query).pipe(
      catchError(() => of([])), // fallback inside
    ),
  ),
);

// ❌ Wrong — error on outer stream kills the subscription
this.search$.pipe(
  switchMap((query) => this.api.search(query)),
  catchError(() => of([])), // too late, stream is dead
);
```

## Subscription Management (Angular)

### Preferred: No Manual Subscriptions

```typescript
// ✅ Use async pipe in templates
@Component({
  template: `@for (user of users$ | async; track user.id) { ... }`
})

// ✅ Use toSignal() for signal-based components
users = toSignal(this.userService.getUsers(), { initialValue: [] });
```

### When Manual Subscription is Needed

```typescript
// ✅ Use takeUntilDestroyed with DestroyRef
export class MyComponent {
  private destroyRef = inject(DestroyRef);

  ngOnInit() {
    this.event$
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe((value) => this.handleEvent(value));
  }
}
```

### Never Do This

```typescript
// ❌ Manual subscribe without cleanup — memory leak
ngOnInit() {
  this.data$.subscribe(data => this.data = data);
}

// ❌ Storing subscription and manually unsubscribing — verbose, error-prone
private sub: Subscription;
ngOnInit() { this.sub = this.data$.subscribe(...); }
ngOnDestroy() { this.sub?.unsubscribe(); }
```

## Subject Types

| Subject            | Use Case                                |
| ------------------ | --------------------------------------- |
| `Subject`          | Multicast events with no initial value  |
| `BehaviorSubject`  | State that always has a current value   |
| `ReplaySubject(n)` | Late subscribers need the last N values |
| `AsyncSubject`     | Only emit the last value on completion  |

**Prefer signals over BehaviorSubject** for component state in modern Angular.

## Testing Observables

```typescript
// Simple async test
it('should emit values', (done) => {
  service.getData().subscribe((data) => {
    expect(data).toBeDefined();
    done();
  });
});

// With marble testing (for complex streams)
import { TestScheduler } from 'rxjs/testing';

const scheduler = new TestScheduler((actual, expected) => {
  expect(actual).toEqual(expected);
});

scheduler.run(({ cold, expectObservable }) => {
  const source$ = cold('a-b-c|', { a: 1, b: 2, c: 3 });
  const result$ = source$.pipe(map((x) => x * 10));
  expectObservable(result$).toBe('a-b-c|', { a: 10, b: 20, c: 30 });
});
```

## Anti-Patterns

### Never Use `getValue()` on BehaviorSubject

`getValue()` is a synchronous escape hatch that defeats the purpose of reactive programming. It reads the current value without subscribing, which means you miss updates, break the reactive data flow, and create hidden temporal coupling.

```typescript
// ❌ NEVER — synchronous read breaks reactivity
const currentUser = this.user$.getValue();
this.api.fetchOrders(currentUser.id).subscribe(...);

// ✅ Use the stream — stays reactive, handles updates
this.user$.pipe(
  switchMap(user => this.api.fetchOrders(user.id)),
).subscribe(...);

// ✅ If you need the value once (e.g., in a click handler), use take(1) or firstValueFrom
async handleClick() {
  const user = await firstValueFrom(this.user$);
  // ... use user
}

// ✅ If you truly need synchronous access to current state, use a signal instead
private user = toSignal(this.user$);
handleClick() {
  const currentUser = this.user();
}
```

**Why `getValue()` is harmful:**

- It's a code smell — if you need the value synchronously, you're likely not thinking reactively
- It creates race conditions — the value may have changed between reading it and using it
- It hides data dependencies — the code doesn't express that it depends on `user$`
- It breaks composability — you can't pipe, combine, or test the resulting logic reactively

### Never Nest Subscribes

Nested subscribes are the #1 RxJS anti-pattern. They create memory leaks, prevent cancellation, and produce unreadable code.

```typescript
// ❌ NEVER — nested subscribes, memory leaks, no cancellation
this.route.params.subscribe((params) => {
  this.userService.getUser(params['id']).subscribe((user) => {
    this.ordersService.getOrders(user.id).subscribe((orders) => {
      this.orders = orders;
    });
  });
});

// ✅ Use flattening operators — clean, cancellable, no leaks
this.route.params
  .pipe(
    switchMap((params) => this.userService.getUser(params['id'])),
    switchMap((user) => this.ordersService.getOrders(user.id)),
    takeUntilDestroyed(this.destroyRef),
  )
  .subscribe((orders) => {
    this.orders = orders;
  });

// ✅ Even better — use toSignal and avoid subscribing entirely
orders = toSignal(
  this.route.params.pipe(
    switchMap((params) => this.userService.getUser(params['id'])),
    switchMap((user) => this.ordersService.getOrders(user.id)),
  ),
  { initialValue: [] },
);
```

**Every nested subscribe:**

- Creates a subscription that is NOT cleaned up when the outer emits again
- Cannot be cancelled — `switchMap` cancels, nested subscribes don't
- Accumulates subscriptions over time → memory leak
- Makes error handling nearly impossible to do correctly

### Other Anti-Patterns

- **Don't use `toPromise()`** — use `firstValueFrom()` or `lastValueFrom()`
- **Don't create hot observables without a way to complete them** — they leak
- **Don't use `shareReplay` without `{ refCount: true }`** — the source subscription is never cleaned up
- **Don't use `combineLatest` when `withLatestFrom` is what you mean** — `combineLatest` re-emits when ANY source emits; `withLatestFrom` only emits when the primary source emits
- **Don't subscribe just to set a property** — use `async` pipe or `toSignal()` instead
- **Don't use `tap` to modify external state** — `tap` is for side effects like logging, not for imperative state mutations that should be expressed as stream transformations
- **Don't use `Subject` when a `BehaviorSubject` or signal is more appropriate** — if consumers need the current value, `Subject` will miss it
