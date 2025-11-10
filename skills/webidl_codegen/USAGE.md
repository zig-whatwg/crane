# When to Use the WebIDL Codegen Skill

Use this skill when:

## Code Generation
- Running `zig build codegen`
- Modifying files in `webidl/src/`
- Adding new WebIDL interfaces
- Updating existing interfaces

## Method Naming
- **ALWAYS** when writing property getters → Use `get_` prefix (with underscore)
- **ALWAYS** when writing property setters → Use `set_` prefix (with underscore)
- **ALWAYS** when writing spec public methods → Use `call_` prefix
- **NEVER** prefix `init()`, `deinit()`, or internal helpers

## File Modifications
- Modifying any `.zig` file in `webidl/src/`
- Adding new interface methods
- Adding property accessors
- Implementing spec methods

## Critical Rules
- Property getters: `get_fatal()` NOT `getFatal()`
- Property setters: `set_encoding()` NOT `setEncoding()`
- Spec methods: `call_decode()` NOT `decode()`
- Internal methods: `init()` NOT `call_init()`

## Quick Check
Before committing `webidl/src/` changes, verify:
1. All getters have `get_` (with underscore)
2. All setters have `set_` (with underscore)  
3. All spec methods have `call_` prefix
4. Init/deinit have NO prefix
5. Run `zig build codegen` to regenerate

## See SKILL.md for complete documentation
