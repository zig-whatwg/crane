# Dependency Mocking Skill Usage

## When to Use

**Load this skill when a required dependency isn't implemented yet.**

Automatically loaded when:
- Spec algorithm references unimplemented spec
- `@import("spec-name")` fails (spec not in `src/`)
- Need to unblock development while waiting for dependency
- Prototyping cross-spec interactions

## What It Provides

1. **Mock Creation Patterns** - Minimal, stub, pass-through, simplified
2. **Clear Markers** - ALL mocks MUST have "TEMPORARY MOCK" and TODO
3. **Documentation Template** - What mock provides and doesn't provide
4. **Tracking** - Create bd issue for replacement
5. **Replacement Workflow** - When and how to replace with real implementation

## Critical Rule

**ALL mocks MUST be clearly marked as temporary** with:
- "TEMPORARY MOCK" in documentation
- TODO with replacement instructions
- bd issue tracking real implementation

## Full Documentation

See `SKILL.md` for mock patterns and examples.
