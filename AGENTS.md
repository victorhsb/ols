# AGENTS.md — OLS (Odin Language Server)

## Build

- **Language:** Odin. Build with `odin build` directly; no package manager, Makefile, or build system abstraction.
- **Build ols:** `./build.sh` (Linux/macOS) or `./build.bat` (Windows)
- **Build odinfmt:** `./odinfmt.sh` (Linux/macOS) or `./odinfmt.bat` (Windows)
- **Debug build:** `./build.sh debug` / `./build.bat debug`
- **CI full pipeline:** `./ci.sh CI` (builds ols + odinfmt, runs all tests including odinfmt tests)
- **CI no tests:** `./ci.sh CI_NO_TESTS` (used for release builds)
- **Version:** build scripts auto-generate a `dev-YYYY-MM-DD-<short-sha>` version; CI uses `OLS_VERSION` env var if set.

## Test

- **Run all tests:** `./build.sh test` (Linux/macOS) or `./build.bat test` (Windows)
- **Run single test:** `./build.sh single_test <TEST_NAME>` (Linux/macOS) or `./build.bat single_test <TEST_NAME>` (Windows)
- **Build tests only:** `./build.sh build_test` / `./build.bat build_test`
- **odinfmt tests:** `tools/odinfmt/tests.sh` (Linux/macOS) or `tools/odinfmt/tests.bat` (Windows)
- **Known bug:** `odin test` creates an executable with the same name as a folder and gets confused. Build scripts work around this by `cd tests` and running `odin test ../tests`. Do NOT run `odin test tests` directly from the repo root.
- Tests are built with `-collection:src=../src` (or `src=src` on Windows), `-define:ODIN_TEST_THREADS=1`, and `-define:ODIN_TEST_TRACK_MEMORY=false`.

## Architecture

- `src/` — OLS language server source
  - `src/main.odin` — entry point
  - `src/server/` — LSP server implementation
  - `src/session/` — session management
  - `src/odin/` — Odin language-specific logic
  - `src/common/` — shared utilities
  - `src/testing/` — test helpers
- `tests/` — OLS test suite (memory/thread flags required, see above)
- `tools/odinfmt/` — standalone formatter tool (its own `main.odin` and tests)
- `builtin/` — builtin types/procedures definitions. Must be located next to the `ols` binary at runtime, **or** set the environment variable `OLS_BUILTIN_FOLDER` to its absolute path. This is required for OLS to function.
- `editors/vscode/` — VS Code extension (TypeScript, npm-based, separate from Odin code)
- `editors/neovim/` — Neovim config/plugin files
- `misc/ols.schema.json` and `misc/odinfmt.schema.json` — JSON schemas for configuration validation

## Dependencies

- **Odin compiler** must be installed and on PATH.
- OLS tracks the **master branch** of Odin, not a tagged release.
- **CI dependency:** LLVM 17 (Linux installs via `llvm.sh`, macOS via `brew install llvm@17`, Windows uses VS 2019 build tools).
- CI clones `https://github.com/odin-lang/Odin` (master) into an `Odin/` sibling directory and bootstraps from there.

## VS Code Extension

- Located in `editors/vscode/`. Standard Node/npm project.
- `npm run compile` — compile TypeScript via tsc.
- `npm run lint` — eslint on `src/**/*.ts`.
- `npm run package` — build `.vsix` with vsce.
- `npm run build` — compile + package.
- Entry: `out/extension.js`.

## Style & Editing

- `.editorconfig` — tabs, indent size 4, LF line endings, UTF-8.
- The Odin codebase uses tabs for indentation.

## Git

- Default branch: `main`.
- CI triggers on pushes/PRs to `main`.
- Release workflow (`release.yml`) publishes weekly "nightly" releases and tag-based releases (`dev-*` tags).
