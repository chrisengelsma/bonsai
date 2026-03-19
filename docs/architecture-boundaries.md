# Architecture Boundaries

This document defines how responsibility is divided in bonsai and how subsystem domains should relate to one another.

## Boundary Philosophy

bonsai uses strict-but-pragmatic boundaries.

That means:
- subsystem domains are defined early
- code should be placed according to primary responsibility
- convenience coupling is discouraged
- abstractions should not be introduced before they solve a real problem
- small pragmatic decisions are acceptable when they do not compromise long-term architecture

## Dependency Direction

At a high level:

- lower-level domains should not depend on higher-level domains
- platform details should not leak upward unchecked
- gameplay layer depends on the engine; the engine does not depend on gameplay layer
- testing may touch any domain for validation purposes, but test-only utilities should not become production dependencies
- tooling may depend on engine-facing APIs or file formats, but production runtime should not depend on tooling unless explicitly justified

## Practical Rules

### foundation
May be depended on widely.
Should contain minimal policy and minimal environmental assumptions.

### platform
May depend on foundation.
Should not depend on scene/world, gameplay layer, or tooling.

### core runtime
May depend on foundation and platform abstractions.
Should orchestrate systems without absorbing unrelated implementation detail.

### rendering
May depend on foundation and platform as needed.
Should not absorb scene/world ownership or gameplay policy.

### scene/world
May depend on foundation and core runtime contracts.
Should represent world structure, not platform details.

### gameplay layer
May depend on engine-facing APIs.
Must remain downstream of the engine.

### tooling
May depend on engine-facing formats, metadata, and selected APIs.
Should remain separable from runtime execution.

### testing
May validate any subsystem.
Should not force production code into distorted shapes without a good reason.

### deployment
Owns packaging, CI, release, and artifact strategy.
Should not contain runtime logic.

## Boundary Smells

Treat these as warnings:

- OS handles showing up in scene/world objects
- renderer classes containing gameplay rules
- gameplay-specific assumptions in core runtime
- tooling code mixed into runtime modules
- tests that require the full engine to validate a basic foundation utility
- a “misc” module that grows without clear ownership

If a feature does not have a clear home, the design should be discussed before implementation begins.
