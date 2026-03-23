# Scope

## Purpose

This document defines the intended scope of bonsai.

Its purpose is to keep the project focused, prevent premature expansion, and make it clear what the engine is trying to become in the near term versus over time.

## Project Scope

bonsai is a modern C++ game engine project built with production-style architecture.

The project is intended to grow into a small but serious engine that demonstrates clean subsystem boundaries, disciplined runtime design, practical rendering integration, and a maintainable repository structure.

The engine is expected to support both 2D and 3D over time, but it will grow into those capabilities incrementally rather than trying to establish full engine breadth up front.

## In Scope

The following areas are in scope for bonsai as a project:

### Foundation
Low-level reusable building blocks that support the rest of the engine.

Examples include:
- assertions
- logging
- identifiers and handles
- result or error utilities
- configuration support
- small common utility types where justified

### Platform
The boundary between the engine and the operating system or execution environment.

Examples include:
- application entry
- windowing integration
- input plumbing
- timing hooks
- file system access at boundary points
- environment integration

### Core Runtime
The lifecycle and orchestration layer of the engine.

Examples include:
- engine startup and shutdown
- application loop
- frame sequencing
- event flow
- module or service wiring
- runtime diagnostics

### Rendering
A real but disciplined graphics path.

Examples include:
- graphics context setup
- renderer structure
- frame production
- resource ownership and lifetime
- shaders and rendering backend integration
- debug rendering as needed

### Scene / World
The representation of runtime world state.

Examples include:
- transforms
- hierarchy or world structure
- update sequencing
- view or camera-related world concepts
- scene composition support

### Gameplay Layer
Applications and demos built on top of the engine.

Examples include:
- sandbox applications
- small demonstrations
- vertical slices that exercise the engine honestly

### Tooling
Practical developer-facing support systems introduced when justified.

Examples include:
- validation utilities
- asset helpers
- workflow scripts
- small support tools that reduce project friction

### Testing
Validation infrastructure across the project.

Examples include:
- unit tests
- integration tests
- smoke tests
- regression checks
- validation scripts

### Deployment
Repository, build, packaging, and release concerns.

Examples include:
- CMake structure
- CI workflows
- build verification
- artifact packaging later
- release hygiene

## Early Scope

In the near term, bonsai is focused on establishing a stable implementation foundation before deeper engine breadth is added.

The early focus is:

- repository structure
- build discipline
- foundational utilities
- platform boundary establishment
- core runtime shape
- testing from the beginning
- minimal but real demonstrations of progress

This means early milestones should prioritize architectural integrity and validation over feature breadth.

## Explicit Scope Boundaries

bonsai is intended to be a serious engine project, but not an everything-at-once engine project.

The repository should remain focused on:
- clear subsystem ownership
- incremental progress
- observable behavior
- maintainability
- architectural reasoning made visible through code, tests, and structure

If a feature adds complexity without advancing those goals, it is probably outside the current scope.

## Scope Rule

A change belongs in scope when it satisfies all of the following:

- it has a clear subsystem home
- it supports the current implementation direction
- it can be validated at the current project stage
- it does not force premature architecture for future hypothetical needs
- it improves the engine or the repo in a concrete way

If a proposed addition does not meet those conditions, it should be deferred.