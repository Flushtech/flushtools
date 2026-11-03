# Contributing

Thanks for taking an interest in FlushTools.

## Before opening a pull request

1. Open an issue first for larger changes so the API and compatibility impact can be discussed.
2. Keep changes focused. Public C ABI changes must be reflected in both `src/` and `include/flushtools.h`.
3. Add or update tests for changed behaviour.
4. Run the relevant checks before submitting.

## Development setup

Install the Odin compiler. CI currently pins `dev-2026-09`. A C compiler is needed
for the ABI test; Clang is needed for sanitizer runs.

On Linux:

```sh
make check
make asan
make tsan
```

macOS is not currently a validated target. The Makefile can select a `.dylib`
output, but builds, tests, and release assets are not covered by CI yet.

On Windows, from a shell with Odin on `PATH`:

```bat
build.bat
build.bat test
```

The C ABI test is part of CI on both supported release platforms. Sanitizer jobs
currently run on Linux.

## API and compatibility

- Treat the declarations in `include/flushtools.h` as the public ABI contract.
- Keep exported names, calling conventions, argument types, and struct layouts in
  sync with the Odin implementation.
- Do not change an existing exported function's behaviour or layout silently.
- Document breaking changes clearly and use a `BREAKING CHANGE:` footer or
  `!` in the Conventional Commit type when appropriate.
- The version constants in the Odin source and C header are managed by
  release-please; do not edit them manually.

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` for a backward-compatible feature
- `fix:` for a bug fix
- `docs:` for documentation-only changes
- `test:` for tests
- `ci:` for CI or automation
- `refactor:` for behaviour-preserving code changes

A `feat` or `fix` can affect the next release version, so choose the type
according to the user-visible impact.

## Pull requests

Explain the problem, the approach, and any ABI or compatibility implications.
Include test results and update the README or API documentation when public
behaviour changes.
