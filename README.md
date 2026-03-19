# bonsai

bonsai is a modern C++ game engine project built with production-style architecture.

The project is intended to demonstrate how a serious engine can be structured, validated, and evolved over time. It emphasizes clean subsystem boundaries, incremental progress, and long-term maintainability.

bonsai is not a toy engine, a one-off graphics experiment, or a race to replicate commercial engine feature breadth. It is being built through deliberate milestones with explicit architectural boundaries, tests from the beginning, and runnable demonstrations as early as practical.

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
- production-style in standards and organization
- architecture-led rather than renderer-led
- incremental in scope and validation
- designed for clarity, maintainability, and demonstrable progress

bonsai is not:
- a commercial competitor to Unity, Unreal, or Godot
- a build-everything-yourself stunt project
- a dumping ground for unrelated graphics experiments
- a codebase optimized for premature abstraction

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

bonsai is developed through small, validated milestones.

Each milestone should define:
- what is being added
- why it is being added now
- what artifacts or files are introduced
- what should build, run, or demonstrate visible progress
- what must be verified manually
- what automated tests or checks must pass
- what is explicitly out of scope for that step

## Repository Status

bonsai is currently in the initial project-definition and repository-foundation phase.

Implementation begins once the project direction, design principles, roadmap, and repository shape are aligned well enough to support disciplined growth.

## Long-Term Outcome

The goal is for this repository to feel like:
- a serious engine project
- a teachable architecture case study
- a portfolio artifact that demonstrates engineering judgment, not just code volume
