# bonsai

**bonsai** is a modern educational game engine built in C++ with production-style architecture.

Its purpose is twofold:

1. teach experienced programmers how engine subsystems are designed, connected, and validated
2. serve as a serious portfolio-quality open-source codebase

bonsai is not intended to be a toy engine, a one-off experiment, or a feature race against commercial engines. It is being built milestone by milestone with explicit architectural boundaries, tests from the beginning, and runnable demonstrations as early as practical.

## Project Goals

- build a game engine from scratch in C++
- support both 2D and 3D over time
- emphasize clean subsystem boundaries
- make architecture decisions explicit and teachable
- validate progress through both manual verification and automated tests
- produce a repository that is educational, professional, and GitHub-worthy

## Intended Audience

Primary audience:
- experienced programmers and software engineers who want to understand game engine architecture in depth

Secondary audience:
- hiring managers and technical interviewers evaluating engineering quality
- open-source contributors and learners interested in engine design

## Project Character

bonsai is:
- educational first
- production-style in standards and organization
- incremental and milestone-driven
- architecture-led rather than renderer-led
- designed for clarity, teachability, and maintainability

bonsai is not:
- a commercial competitor to Unity, Unreal, or Godot
- a build-everything-yourself stunt project
- a dumping ground for unrelated graphics experiments
- a codebase optimized for maximum abstraction from day one

## “From Scratch” Philosophy

In this project, “from scratch” means:
- we design and own the engine architecture
- we define subsystem boundaries and runtime contracts
- we implement the engine systems ourselves where those systems are the learning target

It does **not** mean:
- reimplement every commodity dependency for no reason
- avoid third-party libraries when they solve non-core problems cleanly
- make the project harder to learn by rejecting practical tooling

## Top-Level Subsystem Domains

Every major subsystem in bonsai belongs primarily to one of these domains:

- **foundation** — low-level reusable building blocks
- **platform** — operating system and environment boundary
- **core runtime** — engine lifecycle and orchestration
- **rendering** — graphics and frame production
- **scene/world** — world representation and simulation structure
- **gameplay layer** — sample game logic built on the engine
- **tooling** — developer workflow and content support
- **testing** — validation infrastructure
- **deployment** — CI, packaging, release, and distribution

## Development Approach

The engine will be built chapter by chapter and checkpoint by checkpoint.

Each checkpoint is intentionally small and must define:
- what is being added
- why it is being added now
- what files are created or updated
- what should compile or run
- what must be verified manually
- what automated tests must pass
- what is explicitly out of scope for that step

## Repository Status

This repository is currently in **Chapter 0: project definition**.

Implementation begins in Chapter 1 after the project vision, design principles, scope boundaries, roadmap, repository structure, and development standards are explicitly documented.

## Long-Term Outcome

The goal is for this repository to feel like:
- a serious engine project
- a teachable architecture case study
- a portfolio artifact that demonstrates engineering judgment, not just code volume
