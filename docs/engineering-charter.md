# Engineering Charter

## Purpose

This charter defines the engineering posture of bonsai. It exists to keep the project coherent as it grows.

When later decisions become ambiguous, this document should be used to resolve them.

## Core Commitments

### 1. Teachability through real architecture
bonsai will prioritize making engine structure understandable. The codebase should expose real subsystem boundaries and real tradeoffs rather than hiding them behind opaque abstractions.

### 2. Production-style standards
Although educational in purpose, bonsai should be organized and maintained like a serious software project. Documentation, testing, repository structure, and coding standards are part of the product.

### 3. Clear ownership
Every major feature must have a clear subsystem home. Cross-cutting concerns must be explicit rather than accidental.

### 4. Incremental construction
The project will be built in small checkpoints. Each checkpoint must be validated before the next one begins.

### 5. Practical dependency use
Third-party libraries may be used when they solve commodity problems cleanly and do not obscure the learning objective.

### 6. Testing from the beginning
Validation is not a finishing step. Manual and automated checks are part of the architecture process.

## Optimization Order

When tradeoffs appear, prefer:

1. teachability
2. architectural clarity
3. maintainability
4. incremental demonstrability
5. extensibility
6. feature breadth

## Non-Commitments

bonsai does not commit to:
- matching commercial engine feature breadth
- avoiding all third-party dependencies
- maximizing abstraction early
- supporting every platform immediately
- implementing advanced rendering before the runtime deserves it

## Decision Rule

When evaluating a proposal, ask:

- does it improve clarity or only add novelty?
- does it respect subsystem boundaries?
- can it be validated at the current project stage?
- is this solving a current problem or a hypothetical one?
- does it help bonsai remain educational and portfolio-worthy?

If the answer to most of these is no, the proposal probably does not belong yet.
