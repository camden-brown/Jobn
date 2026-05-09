---
description: 'Unit testing patterns for Jest, Vitest, and Angular TestBed. USE FOR: writing unit tests, mocking, test structure, coverage strategy, Angular component testing.'
---

# Unit Testing Best Practices

## Test Structure (AAA Pattern)

```typescript
describe('UserService', () => {
  describe('getUser', () => {
    it('should return the user when found', () => {
      // Arrange
      const mockRepo = { findById: vi.fn().mockResolvedValue(testUser) };
      const service = new UserService(mockRepo);

      // Act
      const result = await service.getUser('123');

      // Assert
      expect(result).toEqual(testUser);
    });
  });
});
```

## Naming Conventions

- `describe` blocks: name the unit under test (class, function, module)
- Nested `describe`: name the method or scenario
- `it` blocks: start with "should" — describe the expected behavior, not the implementation
- Be specific: `'should return 404 when user not found'` not `'should handle errors'`

## What to Test

| Always Test                        | Skip                                    |
| ---------------------------------- | --------------------------------------- |
| Public API behavior                | Private methods (test via public API)   |
| Edge cases (empty, null, max, min) | Framework internals                     |
| Error paths and exceptions         | Simple getters/setters with no logic    |
| Business logic and calculations    | Third-party library behavior            |
| State transitions                  | Implementation details (internal state) |
| Integration points (mocked)        | UI layout/styling                       |

## Mocking

### Jest

```typescript
// Module mock
jest.mock('./userRepo');
const mockRepo = jest.mocked(userRepo);
mockRepo.findById.mockResolvedValue(testUser);

// Spy
const spy = jest.spyOn(service, 'validate');

// Manual mock in __mocks__/
// __mocks__/userRepo.ts
```

### Vitest

```typescript
// Module mock
vi.mock('./userRepo');
const mockRepo = vi.mocked(userRepo);
mockRepo.findById.mockResolvedValue(testUser);

// Spy
const spy = vi.spyOn(service, 'validate');

// Inline mock factory
vi.mock('./userRepo', () => ({
  findById: vi.fn(),
}));
```

### Mocking Rules

- Mock at module boundaries — never mock the thing you're testing
- Prefer dependency injection over module mocking when possible
- Reset mocks between tests: `beforeEach(() => vi.clearAllMocks())` or `jest.clearAllMocks()`
- Use `mockReturnValue` for sync, `mockResolvedValue` for async
- Assert mock calls: `expect(mock).toHaveBeenCalledWith(expectedArgs)`

## Angular TestBed

```typescript
describe('UserComponent', () => {
  let component: UserComponent;
  let fixture: ComponentFixture<UserComponent>;
  let userService: jasmine.SpyObj<UserService>;

  beforeEach(async () => {
    userService = jasmine.createSpyObj('UserService', ['getUser']);

    await TestBed.configureTestingModule({
      imports: [UserComponent], // standalone component
      providers: [{ provide: UserService, useValue: userService }],
    }).compileComponents();

    fixture = TestBed.createComponent(UserComponent);
    component = fixture.componentInstance;
  });

  it('should display user name after loading', () => {
    userService.getUser.and.returnValue(of(testUser));
    fixture.detectChanges();

    const nameEl = fixture.debugElement.query(By.css('.user-name'));
    expect(nameEl.nativeElement.textContent).toContain('John');
  });
});
```

### Angular Testing Rules

- Use `imports` (not `declarations`) for standalone components
- Mock services with `jasmine.createSpyObj` or `jest.fn()` objects
- Call `fixture.detectChanges()` after setup to trigger lifecycle
- Test DOM output via `fixture.debugElement.query()` — not by inspecting component properties
- For signal-based components: set input signals, call `fixture.detectChanges()`, assert DOM

## Async Testing

```typescript
// Vitest / Jest
it('should fetch data', async () => {
  const result = await service.getData();
  expect(result).toBeDefined();
});

// Angular with fakeAsync
it('should debounce input', fakeAsync(() => {
  component.onSearch('query');
  tick(300);
  fixture.detectChanges();
  expect(service.search).toHaveBeenCalledWith('query');
}));
```

## Coverage Strategy

- Aim for meaningful coverage, not 100% — focus on business logic
- Branch coverage matters more than line coverage
- Cover every public method's happy path + at least one error path
- Don't write tests just to hit coverage numbers — test behavior

## Test Isolation

- Each test must be independent — no shared mutable state between tests
- Use `beforeEach` for setup, not `beforeAll` (unless truly shared immutable fixtures)
- Clean up side effects (timers, subscriptions, DOM changes) in `afterEach`
- Tests must pass in any order and when run in isolation
