# Audience and Purpose

## Primary Audience

The primary audience for bonsai is experienced programmers, especially software engineers with strong general development experience who want to understand how a game engine is structured internally.

This project assumes readers can learn APIs and syntax on their own. The emphasis is on:
- architectural reasoning
- subsystem design
- ownership and dependency boundaries
- tradeoffs and sequencing
- validation strategy

## Secondary Audiences

### Hiring managers and technical interviewers

The repository should demonstrate:
- engineering judgment
- clean architecture
- ability to control scope
- disciplined iteration
- testing and validation habits
- professional documentation

### Open-source learners and contributors

The repository should be readable enough that contributors can understand:
- where code belongs
- why a subsystem exists
- how to extend a system without breaking architecture
- how progress is verified

## Purpose of the Project

bonsai exists to teach and demonstrate engine architecture.

This is not just a game project, and it is not just a rendering experiment. The point is to build a coherent engine codebase whose structure, docs, tests, and examples make the system understandable.

The project should help answer questions like:
- why is this subsystem separate?
- why is this abstraction here?
- why now instead of later?
- what are the tradeoffs of this design?
- how do we know this checkpoint is complete?

## Educational Stance

bonsai is intended to be instructional without becoming beginner-oriented hand-holding.

It should explain:
- why each subsystem is introduced
- what problem it solves
- what alternatives were considered
- how to know whether the design is working

It should avoid:
- unexplained large code dumps
- “just trust the pattern” architecture
- introducing complexity before it earns its keep
