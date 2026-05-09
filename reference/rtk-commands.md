# rtk Command Reference

`rtk` is a token-optimized command wrapper that compresses build/test/git output by 60–90% before it reaches the LLM. All agents should use `rtk` for shell commands to minimize context consumption.

## Core Commands

| Command                          | Purpose                   | Savings |
| -------------------------------- | ------------------------- | ------- |
| `rtk git status`                 | Compact git status        | ~80%    |
| `rtk git diff`                   | Compressed diff output    | ~75%    |
| `rtk git add` / `rtk git commit` | Compact confirmations     | ~92%    |
| `rtk git log -n 5`               | One-line commit summaries | ~80%    |

## File Reading

| Command                         | Purpose                                 | When to Use                                             |
| ------------------------------- | --------------------------------------- | ------------------------------------------------------- |
| `rtk read <file>`               | Smart file read, strips noise           | Default for reading files (~70% savings)                |
| `rtk read <file> -l aggressive` | Signatures only, strips function bodies | Understanding file shape without implementation details |
| `rtk smart <file>`              | 2-line heuristic summary per file       | Triaging which files to read in full                    |

## Search & Navigation

| Command                | Purpose                        | Savings |
| ---------------------- | ------------------------------ | ------- |
| `rtk ls .`             | Token-optimized directory tree | ~80%    |
| `rtk grep "pattern" .` | Grouped search results         | ~80%    |
| `rtk find "*.ts" .`    | Compact find results           | ~80%    |

## Project Analysis

| Command           | Purpose                           | When to Use                                                                   |
| ----------------- | --------------------------------- | ----------------------------------------------------------------------------- |
| `rtk deps`        | Compact dependency summary        | Early — understand available libraries (reads package.json, Cargo.toml, etc.) |
| `rtk json <file>` | JSON structure without values     | Config files: tsconfig, package.json, .eslintrc, API schemas                  |
| `rtk tsc`         | TypeScript errors grouped by file | Instead of raw `tsc` for TS projects                                          |

## Error Handling

| Command             | Purpose                             | When to Use                                                  |
| ------------------- | ----------------------------------- | ------------------------------------------------------------ |
| `rtk err <cmd>`     | Filter errors only from any command | When a build/test partially fails — extract only error lines |
| `rtk summary <cmd>` | Heuristic summary of long output    | Fallback for commands rtk doesn't have a specific filter for |

## Scanning Strategy

1. **Start broad**: `rtk ls .` + `rtk smart <files>` to identify relevant areas
2. **Drill in**: `rtk read <file>` for specific files that matter
3. **Config files**: `rtk json <file>` for tsconfig, package.json, etc.
4. **Dependencies**: `rtk deps` early to understand available libraries
5. **Full read**: Only read full files when you need implementation details

## Notes

- Verify commands in config are already `rtk`-prefixed — run them as-is
- For ad-hoc commands, prefix with `rtk`: `rtk git status`, `rtk ls .`, etc.
- When using `GIT_AUTHOR_DATE`/`GIT_COMMITTER_DATE` env vars, use raw `git` (rtk wraps transparently)
