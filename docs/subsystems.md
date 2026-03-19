# Subsystems

bonsai organizes major responsibilities into the following subsystem domains.

## foundation

Low-level reusable building blocks with minimal policy.

Examples:
- assertions
- logging primitives
- IDs and handles
- utility types
- result/error helpers
- configuration primitives
- low-level math support if adopted later

## platform

Boundary to the operating system and external execution environment.

Examples:
- window creation
- raw input plumbing
- clocks and timing hooks at the OS boundary
- file system boundary operations
- environment and process integration

## core runtime

Engine lifecycle and orchestration.

Examples:
- bootstrap
- application lifecycle
- main loop
- event routing model
- frame sequencing
- module wiring
- engine configuration

## rendering

Graphics subsystem and frame production.

Examples:
- renderer interfaces
- backend implementations
- GPU resources
- frame orchestration
- shaders
- render command handling
- debug rendering

## scene/world

World representation and simulation-facing structure.

Examples:
- entity or object model
- transforms
- hierarchy
- world update sequencing
- spatial organization
- camera-related world concepts

## gameplay layer

Sample game logic built on top of the engine.

Examples:
- sandbox application
- test scenes
- game-side systems
- example interactions that pressure-test the engine honestly

## tooling

Developer-facing productivity and content support.

Examples:
- asset helpers
- validation scripts
- workflow utilities
- content pipeline support
- developer documentation helpers

## testing

Validation infrastructure across the project.

Examples:
- unit tests
- integration tests
- smoke tests
- regression tests
- test fixtures and harnesses

## deployment

Build, package, release, and distribution concerns.

Examples:
- CI workflows
- release process
- packaging
- artifact publishing
- versioning strategy
