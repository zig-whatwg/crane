# Monorepo Navigation Skill Usage

## When to Use

**Load this skill when working with cross-spec dependencies.**

Automatically loaded when:
- Looking for implementations of other WHATWG specs
- Need to import functionality from another spec (e.g., Infra, WebIDL)
- Checking if a dependency is implemented
- Understanding monorepo structure (`src/` directory)
- Spec algorithm references another spec

## What It Provides

1. **Monorepo Structure** - How specs are organized in `src/`
2. **Finding Implementations** - Locate spec by name (e.g., "Infra" → `src/infra/`)
3. **Import Patterns** - How to import cross-spec dependencies
4. **Checking Implementation Status** - Is spec implemented or needs mocking?
5. **Common Dependencies** - Infra, WebIDL, URL, Encoding, Streams

## Quick Pattern

- Infra → `src/infra/` (used by nearly all specs)
- WebIDL → `src/webidl/` (type system)
- URL → `src/url/`, Encoding → `src/encoding/`, etc.

## Full Documentation

See `SKILL.md` for complete navigation patterns.
