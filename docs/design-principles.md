# Design Principles

These principles govern the architecture of bonsai.

## 1. Clarity over cleverness

If a design is technically interesting but makes control flow, ownership, or cost harder to understand, it is the wrong design for this project.

## 2. The engine owns the architecture

Third-party libraries may support implementation, but they must not dictate subsystem shape or bleed through the codebase unchecked.

## 3. Clean subsystem boundaries

Every major feature belongs primarily to one of the engine’s top-level subsystem domains. Boundary violations must be treated as design problems, not conveniences.

## 4. Composition before inheritance

Prefer explicit composition and small interfaces over deep inheritance trees, especially in core runtime, scene/world, and rendering.

## 5. Testability is a design constraint

If a system cannot be validated in isolation or in a controlled integration path, the design likely needs improvement.

## 6. Determinism where practical

Core runtime, scene/world, and testing behavior should remain as deterministic as practical so debugging and regression checking stay tractable.

## 7. Platform concerns stay in platform

Operating system details should remain in the platform layer rather than leaking into core runtime, rendering, or scene/world code.

## 8. Rendering is not the whole engine

Rendering is important, but it should not dictate architecture for unrelated systems. The engine is broader than graphics.

## 9. Gameplay is downstream

The gameplay layer exists to exercise the engine, not define it. Engine architecture must not hard-code one game’s assumptions.

## 10. Tooling begins early

Scripts, validators, docs helpers, and workflow support are part of the project, not optional polish to defer indefinitely.

## 11. Observable systems are better systems

Assertions, logging, diagnostics, and debug visibility are part of the architecture, especially in foundation, core runtime, rendering, and testing.

## 12. Complexity must be earned

Do not introduce abstractions for hypothetical future scale. Add complexity when real milestone pressure justifies it.
