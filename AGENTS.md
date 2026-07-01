# Repository Guidelines

## Project Structure & Module Organization

This repository contains the `ArviZPairPlots` Julia package. `src/ArviZPairPlots.jl` defines the module, imports dependencies, and exposes the public API. Conversion and validation logic lives in `src/conversion.jl`. Keep new implementation files in `src/` and include them from the module entry point. Tests are consolidated in `test/runtests.jl`; add focused `@testset` blocks near related coverage. `README.md` documents supported user workflows, while `Project.toml` and `Manifest.toml` define the package environment. Update the README when public behavior changes.

## Build, Test, and Development Commands

Run commands from the repository root with Julia 1.11 or newer:

```sh
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. -e 'using Pkg; Pkg.test()'
julia --project=. -e 'using ArviZPairPlots'
```

The first command installs the locked dependencies, the second runs the complete test suite, and the third is a quick package-load smoke test. There is no separate compilation or asset-build step.

## Coding Style & Naming Conventions

Follow standard Julia style with four-space indentation, concise functions, and trailing commas in multiline calls. Use `snake_case` for functions and variables, `PascalCase` for types and modules, and a leading underscore for non-public helpers (for example, `_normalize_coords`). Keep exported names explicit in `src/ArviZPairPlots.jl`. No formatter or linter is currently configured, so match surrounding code and keep lines readable.

## Testing Guidelines

Tests use Julia's built-in `Test` framework. Name test sets after behavior, such as `"selection and normalization"`, and include regression tests for bug fixes. Cover valid conversions, argument validation, dimensional variables, and PairPlots integration where relevant. No numeric coverage threshold is enforced; changes should exercise every new branch and error path.

## Commit & Pull Request Guidelines

The limited history uses a Conventional Commits-style subject (`chore: initial commit`). Continue with short imperative subjects such as `feat: support coordinate aliases` or `fix: reject duplicate sample keys`. Pull requests should explain the user-visible change, list tests run, link relevant issues, and note API or dependency changes. Include plots or screenshots only when rendered output changes.
