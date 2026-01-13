# Zig Skill Usage

## When to Use

**Load this skill when writing any Zig code.**

Automatically loaded when:
- Writing or refactoring Zig code (any domain)
- Implementing algorithms and data structures
- Managing memory and performance
- Writing tests
- Documenting public APIs

## What It Provides

Universal Zig best practices (not WHATWG-specific):
1. **Code Quality** - Naming, error handling, memory management, type safety
2. **Performance** - Inline functions, preallocations, fast paths, early exits
3. **Testing** - Coverage requirements, memory leak detection, TDD workflow
4. **Documentation** - Public API documentation (skip private/temporary code)

## Key Philosophy

- Public APIs MUST be documented and tested
- Private/temporary code MAY skip documentation
- Always use `std.testing.allocator` to detect leaks
- Explicit ownership and cleanup with `defer`

## Full Documentation

See `SKILL.md` for comprehensive patterns and examples.
