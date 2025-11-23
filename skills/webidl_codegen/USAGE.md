# When to Use the WebIDL Codegen Skill

## Code Generation

Use this skill when:

### Running Codegen
- Running `zig build codegen`
- Regenerating WebIDL bindings after IDL changes
- Adding new WebIDL interfaces from IDL files
- Updating existing interfaces after spec changes

### Modifying Codegen System
- Modifying files in `src/webidl/codegen/`
- Changing code generation logic
- Adding new code generation features
- Fixing codegen bugs

### Working with Generated Files
- Understanding generated interface files in `src/webidl/interfaces/`
- Understanding generated typedef files in `src/webidl/typedefs/`
- Understanding generated dictionary files in `src/webidl/dictionaries/`
- Debugging issues with generated code

### Managing IDL Sources
- Adding IDL files to `specs/supplementary/`
- Understanding how `specs/idl/` symlink works
- Troubleshooting IDL parsing errors

## Critical Rules

### Generated Files Are Read-Only
- ❌ **NEVER** manually edit `src/webidl/interfaces/*.zig`
- ❌ **NEVER** manually edit `src/webidl/typedefs/*.zig`
- ❌ **NEVER** manually edit `src/webidl/dictionaries/*.zig`
- ❌ **NEVER** manually edit `src/webidl/callbacks/*.zig`
- ❌ **NEVER** manually edit `src/webidl/enums/*.zig`
- ❌ **NEVER** manually edit `src/webidl/namespaces/*.zig`

### Where to Make Changes
- ✅ **Edit implementations** in `src/webidl/impls/`
- ✅ **Edit codegen source** in `src/webidl/codegen/`
- ✅ **Add IDL files** to `specs/supplementary/`

### Naming Conventions in Generated Code
- Property getters: `get_size()`, `get_type()`, `get_readable()`
- Property setters: `set_value()`, `set_encoding()`
- Spec methods: `call_slice()`, `call_getReader()`, `call_cancel()`
- Constructors: `init()`, `deinit()` (no prefix)

## Common Commands

### Regenerate All WebIDL Files
```bash
zig build codegen -- specs/idl/ specs/supplementary/ --dest-root src/webidl/
```

### Regenerate Including Implementation Stubs
```bash
# ⚠️ WARNING: Overwrites impls/
zig build codegen -- specs/idl/ specs/supplementary/ --dest-root src/webidl/ --impls
```

### Test Codegen
```bash
zig build test --spec codegen
```

### Full Build (includes codegen)
```bash
zig build
```

## Quick Checklist

Before committing codegen changes:
- [ ] Modified codegen source in `src/webidl/codegen/`
- [ ] Regenerated all files: `zig build codegen -- specs/idl/ specs/supplementary/ --dest-root src/webidl/`
- [ ] Build succeeds: `zig build`
- [ ] Tests pass: `zig build test`
- [ ] Committed BOTH codegen source AND regenerated files

## When NOT to Use This Skill

Don't use this skill for:
- Writing interface implementations (that's normal Zig code in `impls/`)
- Writing tests (that's normal Zig testing)
- Working with runtime code (that's in `src/runtime/`)
- Working with WHATWG spec implementations (that's in `src/url/`, `src/encoding/`, etc.)

## See SKILL.md for Complete Documentation

For detailed information about:
- Code generation architecture
- Generated file structure
- Extended attributes
- Debugging codegen issues
- Integration with build system

Read the complete `SKILL.md` file.
