# bonsai

bonsai is a modern C++ game engine project focused on disciplined architecture, maintainability, and incremental validation.

## Current implementation focus

The repository is currently establishing the engineering baseline for:

- repository structure
- build system discipline
- a minimal foundation library
- automated testing
- CI validation

Current work is intentionally limited to early repository and subsystem bootstrap. Platform, runtime, rendering, scene, and gameplay systems are introduced in later implementation phases.

## Project priorities

- architectural clarity
- maintainable subsystem boundaries
- first-class testing
- incremental, demonstrable progress
- professional repository discipline

## Build

```bash
cmake -S . -B build -G Ninja
cmake --build build