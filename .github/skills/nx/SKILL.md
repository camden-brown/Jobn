---
description: 'Nx monorepo patterns: workspace structure, project configuration, generators, executors, caching, affected commands. USE FOR: Nx workspace setup, project config, running tasks, code generation, migrations.'
---

# Nx

## Workspace Structure

```
my-workspace/
├── apps/                    # Deployable applications
│   ├── my-app/
│   └── my-app-e2e/
├── libs/                    # Shared libraries
│   ├── shared/
│   │   ├── ui/              # Shared UI components
│   │   ├── util/            # Shared utilities
│   │   └── data-access/     # Shared API clients, state
│   └── feature-x/
│       ├── feature/         # Smart components, routes
│       ├── ui/              # Presentational components
│       ├── data-access/     # State, API calls
│       └── util/            # Feature-specific utilities
├── nx.json                  # Nx workspace config
├── project.json             # Root project config (if applicable)
└── tsconfig.base.json       # Base TS config with path aliases
```

## Library Types

| Type          | Purpose                          | Example                     | Depends On            |
| ------------- | -------------------------------- | --------------------------- | --------------------- |
| `feature`     | Smart components, routes, pages  | `libs/orders/feature`       | data-access, ui, util |
| `ui`          | Presentational components        | `libs/shared/ui`            | util only             |
| `data-access` | State management, API clients    | `libs/orders/data-access`   | util only             |
| `util`        | Pure functions, helpers, models  | `libs/shared/util`          | util only             |
| `shell`       | App shell, routing, layout       | `libs/orders/shell`         | feature               |

### Dependency Rules (enforce via `@nx/enforce-module-boundaries`)

- `feature` → `data-access`, `ui`, `util` ✅
- `ui` → `util` ✅
- `data-access` → `util` ✅
- `ui` → `data-access` ❌ (presentational components must not fetch data)
- `util` → anything else ❌ (utils are leaf nodes)
- Apps → any lib ✅
- Libs → apps ❌

## Project Configuration

### `project.json`

```json
{
  "name": "my-lib",
  "projectType": "library",
  "sourceRoot": "libs/my-lib/src",
  "targets": {
    "build": {
      "executor": "@nx/angular:ng-packagr-lite",
      "options": {
        "project": "libs/my-lib/ng-package.json"
      }
    },
    "test": {
      "executor": "@nx/jest:jest",
      "options": {
        "jestConfig": "libs/my-lib/jest.config.ts"
      }
    },
    "lint": {
      "executor": "@nx/eslint:lint"
    }
  },
  "tags": ["scope:shared", "type:ui"]
}
```

### `nx.json` (key settings)

```json
{
  "targetDefaults": {
    "build": {
      "dependsOn": ["^build"],
      "cache": true
    },
    "test": {
      "cache": true
    },
    "lint": {
      "cache": true
    }
  },
  "namedInputs": {
    "default": ["{projectRoot}/**/*", "sharedGlobals"],
    "sharedGlobals": ["tsconfig.base.json"],
    "production": ["default", "!{projectRoot}/**/*.spec.ts"]
  },
  "defaultBase": "main"
}
```

## Common Commands

```bash
# Run a target on a specific project
npx nx run my-app:build
npx nx test my-lib

# Run affected (only what changed)
npx nx affected -t test
npx nx affected -t build
npx nx affected -t lint

# Run on all projects
npx nx run-many -t test
npx nx run-many -t build --parallel=5

# Show project graph
npx nx graph

# Show what's affected
npx nx affected --graph

# List projects
npx nx show projects
npx nx show project my-lib

# Reset cache
npx nx reset
```

## Generators

```bash
# Generate an Angular application
npx nx g @nx/angular:app my-app

# Generate a library
npx nx g @nx/angular:lib my-lib --directory=libs/shared/my-lib

# Generate a component inside a library
npx nx g @nx/angular:component my-component --project=my-lib

# Generate a service
npx nx g @nx/angular:service my-service --project=my-lib

# Move a project
npx nx g @nx/workspace:move --project=old-name --destination=new/path

# Remove a project
npx nx g @nx/workspace:remove my-lib
```

### Generator Defaults in `nx.json`

```json
{
  "generators": {
    "@nx/angular:component": {
      "style": "scss",
      "changeDetection": "OnPush",
      "standalone": true
    },
    "@nx/angular:library": {
      "style": "scss",
      "standalone": true
    }
  }
}
```

## Module Boundary Enforcement

In `.eslintrc.json` (root):

```json
{
  "rules": {
    "@nx/enforce-module-boundaries": [
      "error",
      {
        "depConstraints": [
          { "sourceTag": "type:feature", "onlyDependOnLibsWithTags": ["type:data-access", "type:ui", "type:util"] },
          { "sourceTag": "type:ui", "onlyDependOnLibsWithTags": ["type:util"] },
          { "sourceTag": "type:data-access", "onlyDependOnLibsWithTags": ["type:util"] },
          { "sourceTag": "type:util", "onlyDependOnLibsWithTags": ["type:util"] }
        ]
      }
    ]
  }
}
```

## Caching

Nx caches task results locally (and remotely with Nx Cloud). Cacheable by default: `build`, `test`, `lint`, `e2e`.

### Cache Inputs

Define what files invalidate the cache:

```json
{
  "targets": {
    "build": {
      "inputs": ["production", "^production"],
      "outputs": ["{options.outputPath}"]
    },
    "test": {
      "inputs": ["default", "^production"]
    }
  }
}
```

- `^` prefix means "from dependencies" (e.g., `^production` = production files from dependent projects)
- `{projectRoot}` and `{workspaceRoot}` are available interpolation tokens

### Nx Cloud (remote caching)

```bash
npx nx connect
```

Enables CI and teammates to share cache — a build that already ran on CI won't re-run locally.

## Angular-Specific Nx Patterns

### Path Aliases

In `tsconfig.base.json`:
```json
{
  "compilerOptions": {
    "paths": {
      "@my-org/shared/ui": ["libs/shared/ui/src/index.ts"],
      "@my-org/shared/util": ["libs/shared/util/src/index.ts"],
      "@my-org/orders/data-access": ["libs/orders/data-access/src/index.ts"]
    }
  }
}
```

Always import via path alias, never relative paths across library boundaries:
```typescript
// ✅ Correct
import { ButtonComponent } from '@my-org/shared/ui';

// ❌ Wrong — relative import across lib boundary
import { ButtonComponent } from '../../../shared/ui/src/lib/button.component';
```

### Barrel Files (`index.ts`)

Every library exposes its public API through `src/index.ts`:
```typescript
// libs/shared/ui/src/index.ts
export { ButtonComponent } from './lib/button/button.component';
export { CardComponent } from './lib/card/card.component';
```

- Only export what consumers need — internal implementation stays private
- Never export test utilities from the main barrel
- Don't re-export from `@angular/*` or third-party packages

## Migrations (Version Updates)

**Nx manages Angular updates — do NOT use `ng update` in an Nx workspace.**

```bash
# Check for available migrations
npx nx migrate latest

# Or migrate to a specific version
npx nx migrate @nx/angular@18.0.0

# After running migrate, it creates migrations.json
# Review it, then run the migrations
npx nx migrate --run-migrations

# Clean up
rm migrations.json
```

### Migration Order
1. `npx nx migrate latest` — updates `package.json` + generates `migrations.json`
2. `npm install` — install updated packages
3. `npx nx migrate --run-migrations` — run code transformations
4. `rm migrations.json` — clean up
5. `npx nx run-many -t build` — verify everything builds
6. `npx nx run-many -t test` — verify tests pass
