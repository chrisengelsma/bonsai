# Roadmap

## Current Focus

bonsai is currently in the project-definition phase.

The immediate goal is to finish the minimum project foundation so implementation can begin with a clear repository shape, development standards, and validation strategy.

## Roadmap Philosophy

bonsai will be developed through small, validated milestones.

Each milestone should:
- have a clear architectural purpose
- produce a concrete artifact or runnable result
- define what is in scope and out of scope
- include both manual verification and automated validation where appropriate

The project should grow in a way that keeps subsystem boundaries clear and avoids premature complexity.

## Milestone 1 — Repository Bootstrap and Build Discipline

Purpose:
Establish a serious repository structure and build foundation before engine behavior is added.

Expected outcomes:
- top-level source layout
- working CMake project structure
- test framework integration
- baseline warning policy
- first CI-ready assumptions
- clean local development setup

Primary subsystem emphasis:
- foundation
- testing
- deployment

## Milestone 2 — Foundation Layer Basics

Purpose:
Create the low-level building blocks the engine will rely on.

Expected outcomes:
- assertions
- logging primitives
- result or error utilities
- identifiers or handle utilities
- foundational tests

Primary subsystem emphasis:
- foundation
- testing

## Milestone 3 — Platform Shell and Application Entry

Purpose:
Establish the platform boundary and a minimal application startup path.

Expected outcomes:
- application entry path
- platform-facing bootstrap
- initial timing and environment hooks
- clean startup and shutdown behavior

Primary subsystem emphasis:
- platform
- core runtime
- testing

## Milestone 4 — Core Runtime Loop and Event Flow

Purpose:
Define the runtime spine of the engine.

Expected outcomes:
- engine lifecycle
- frame loop
- timing model
- event flow
- runtime diagnostics wiring

Primary subsystem emphasis:
- core runtime
- foundation
- testing

## Milestone 5 — Input Path and Interactive Application

Purpose:
Make the engine respond to real input through clean subsystem boundaries.

Expected outcomes:
- input capture path
- runtime-facing input model
- simple interactive demo behavior
- smoke validation for event/input flow

Primary subsystem emphasis:
- platform
- core runtime
- testing

## Milestone 6 — Minimal Rendering Path

Purpose:
Introduce the first real rendering path without letting rendering define the whole architecture.

Expected outcomes:
- graphics context bootstrap
- minimal renderer structure
- frame clear and basic draw
- first visible rendering result

Primary subsystem emphasis:
- rendering
- platform
- core runtime
- testing

## Milestone 7 — Scene and World Basics

Purpose:
Add a world representation that can support meaningful demos.

Expected outcomes:
- transforms
- hierarchy or minimal world model
- update sequencing
- scene-owned view concepts as needed

Primary subsystem emphasis:
- scene/world
- core runtime
- testing

## Milestone 8 — Assets and Content Loading Basics

Purpose:
Move from hardcoded demonstrations toward structured content.

Expected outcomes:
- asset identifiers
- basic loading boundary
- test assets
- simple validation for content loading

Primary subsystem emphasis:
- tooling
- foundation
- core runtime
- testing

## Milestone 9 — 2D Demonstration Slice

Purpose:
Pressure-test the engine with a small but honest vertical slice.

Expected outcomes:
- playable or interactive 2D demo
- input, runtime, rendering, and scene integration
- validation that the architecture holds under real use

Primary subsystem emphasis:
- gameplay layer
- scene/world
- rendering
- testing

## Milestone 10 — 3D Expansion Path

Purpose:
Extend the engine into basic 3D support without rewriting its architectural spine.

Expected outcomes:
- 3D transforms and camera support
- basic 3D resource concepts
- minimal 3D rendering demonstration
- validation of earlier architecture decisions

Primary subsystem emphasis:
- rendering
- scene/world
- gameplay layer
- testing

## Ongoing Expectations

The following evolve continuously across the roadmap:
- testing depth
- tooling support
- documentation quality
- deployment maturity
- repository clarity