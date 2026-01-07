# WebIDL Codegen Skill

## Overview

This skill documents the WebIDL code generation system that generates Zig code from WebIDL IDL files. The system reads official WHATWG WebIDL interface definitions and generates type-safe Zig interfaces, typedefs, dictionaries, callbacks, and implementation stubs.

## Architecture

### Input Sources

**IDL Files** (`specs/idl/` and `specs/supplementary/`):
- `specs/idl/` - Symlink to `/Users/bcardarella/projects/webref/ed/idl/` containing 333 official WHATWG WebIDL definitions
- `specs/supplementary/` - Additional type definitions for testing (e.g., `PostMessageOptions.idl`, `XRFeatureInit.idl`)
- Source of truth for all generated code

### Output Structure

**Generated Files** (`src/webidl/`):
```
src/webidl/
├── interfaces/     # WebIDL interface definitions (1234 files)
├── typedefs/       # Type aliases and unions (153 files)
├── dictionaries/   # Dictionary types (948 files)
├── callbacks/      # Callback function types (78 files)
├── enums/          # Enum types (391 files)
├── namespaces/     # Namespace definitions (12 files)
└── impls/          # Implementation stubs (1242 files)
```

**Generated File Types:**

1. **Interfaces** (`src/webidl/interfaces/`)
   - WebIDL interface definitions
   - Include metadata for V8 bindings
   - Delegate to implementation files in `impls/`
   - Examples: `Blob.zig`, `ReadableStream.zig`, `Node.zig`

2. **Typedefs** (`src/webidl/typedefs/`)
   - Type aliases and union types
   - Map WebIDL typedef declarations to Zig types
   - Examples: `DOMString.zig`, `BufferSource.zig`, `EventHandler.zig`

3. **Dictionaries** (`src/webidl/dictionaries/`)
   - WebIDL dictionary types (struct-like objects)
   - Used for options/configuration objects
   - Examples: `BlobPropertyBag.zig`, `QueuingStrategy.zig`

4. **Callbacks** (`src/webidl/callbacks/`)
   - Function pointer types for callbacks
   - Examples: `EventListener.zig`, `VoidFunction.zig`

5. **Enums** (`src/webidl/enums/`)
   - WebIDL enum types
   - Generated as Zig enums
   - Examples: `ReadableStreamType.zig`, `EndingType.zig`

6. **Namespaces** (`src/webidl/namespaces/`)
   - WebIDL namespace declarations
   - Examples: `console.zig`, `WebAssembly.zig`

7. **Implementation Stubs** (`src/webidl/impls/`)
   - Stub files for interface implementations
   - **Only regenerated on explicit request** (not by default)
   - Developers fill in the actual implementation logic

### Code Generation Pipeline

The codegen system follows this pipeline:

1. **Scan IDL Files** - Find all `.idl` files in `specs/idl/` and `specs/supplementary/`
2. **Parse WebIDL** - Parse IDL syntax into Abstract Syntax Tree (AST)
3. **Build Intermediate Representation (IR)** - Resolve types, inheritance, mixins
4. **Generate Zig Code** - Write type-safe Zig files for each WebIDL construct
5. **Write to Destination** - Output to `src/webidl/` subdirectories

## Running Codegen

### Basic Command

```bash
# Generate all WebIDL files
zig build codegen -- specs/idl/ specs/supplementary/ --dest-root src/webidl/
```

**Arguments:**
- `specs/idl/` - First IDL source directory (official WHATWG definitions)
- `specs/supplementary/` - Second IDL source directory (additional definitions)
- `--dest-root src/webidl/` - Output directory root

### Build Integration

Codegen runs automatically during normal builds:

```bash
# Runs codegen automatically, then builds
zig build

# Run tests (includes codegen tests)
zig build test
```

### Regenerating Implementation Stubs

Implementation stubs in `src/webidl/impls/` are **protected from overwriting** by default. To regenerate them:

```bash
# Add --impls flag to regenerate implementation stubs
zig build codegen -- specs/idl/ specs/supplementary/ --dest-root src/webidl/ --impls
```

⚠️ **WARNING**: The `--impls` flag will overwrite existing implementation files. Only use when:
- Creating new interfaces for the first time
- You want to reset implementations to stubs
- You've backed up any custom implementation code

## Generated File Structure

### Interface Files

Interface files in `src/webidl/interfaces/` follow this pattern:

```zig
//! Generated from: FileAPI.idl
//! Generated at: 2025-11-23T01:22:14Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BlobImpl = @import("impls").Blob;
const ReadableStream = @import("interfaces").ReadableStream;
const BlobPart = @import("typedefs").BlobPart;

pub const Blob = struct {
    pub const Meta = struct {
        pub const name = "Blob";
        pub const is_mixin = false;
        pub const BaseType = ?*anyopaque;
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Serializable" },
        };
        
        /// Property binding hints for V8Interface
        pub const properties = .{
            .{ "size", "get_size", null },
            .{ "type", "get_type", null },
        };
        
        /// Method binding hints for V8Interface
        pub const methods = .{
            .{ "slice", "call_slice", 0 },
            .{ "stream", "call_stream", 0 },
        };
    };
    
    // Delegate functions call into implementation
    pub fn get_size(instance: *runtime.Instance) anyerror!u64 {
        return try BlobImpl.get_size(instance);
    }
    
    pub fn call_slice(instance: *runtime.Instance, start: i64, end: i64, contentType: DOMString) anyerror!Blob {
        return try BlobImpl.call_slice(instance, start, end, contentType);
    }
};
```

**Key Features:**
- Metadata for V8 bindings (extended attributes, property/method lists)
- Delegate functions that call into `impls/` for actual implementation
- Type-safe function signatures from IDL
- Documentation from IDL comments

### Typedef Files

Typedef files in `src/webidl/typedefs/` define type aliases:

```zig
//! WebIDL typedef: BufferSource
//!
//! Spec: typedef (ArrayBufferView or ArrayBuffer) BufferSource;
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const webidl = @import("webidl");

pub const BufferSource = webidl.buffer_sources.BufferSource;
```

**Types of Typedefs:**
1. **Primitive aliases** - Simple Zig type aliases (e.g., `DOMString = []const u16`)
2. **Union types** - WebIDL union types as Zig tagged unions
3. **References** - References to types from other modules

### Dictionary Files

Dictionary files in `src/webidl/dictionaries/` define configuration structs:

```zig
//! WebIDL dictionary: BlobPropertyBag
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const BlobPropertyBag = struct {
    type: ?runtime.DOMString = null,
    endings: ?EndingType = null,
};
```

### Implementation Stub Files

Implementation stubs in `src/webidl/impls/` provide templates for developers:

```zig
//! Implementation for Blob interface
//!
//! This file provides the actual implementation logic for the Blob interface.

const std = @import("std");
const runtime = @import("runtime");

pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
    // TODO: Implement initialization
    _ = allocator;
    _ = ctx;
    return error.NotImplemented;
}

pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Implement cleanup
    _ = instance;
}

pub fn get_size(instance: *runtime.Instance) anyerror!u64 {
    // TODO: Implement size getter
    _ = instance;
    return error.NotImplemented;
}

pub fn call_slice(instance: *runtime.Instance, start: i64, end: i64, contentType: []const u8) anyerror!*runtime.Instance {
    // TODO: Implement slice method
    _ = instance;
    _ = start;
    _ = end;
    _ = contentType;
    return error.NotImplemented;
}
```

## Naming Conventions

The codegen follows strict naming conventions for generated code:

### Property Getters/Setters

**Getters use `get_` prefix:**
```zig
pub fn get_size(instance: *runtime.Instance) anyerror!u64
pub fn get_type(instance: *runtime.Instance) anyerror!DOMString
pub fn get_readable(instance: *runtime.Instance) anyerror!*ReadableStream
```

**Setters use `set_` prefix:**
```zig
pub fn set_value(instance: *runtime.Instance, value: DOMString) anyerror!void
```

### Spec Methods

**All WebIDL interface methods use `call_` prefix:**
```zig
pub fn call_slice(instance: *runtime.Instance, ...) anyerror!Blob
pub fn call_getReader(instance: *runtime.Instance, ...) anyerror!ReadableStreamReader
pub fn call_cancel(instance: *runtime.Instance, reason: ?JSValue) anyerror!void
```

### Constructors/Internal Methods

**These do NOT get prefixes:**
```zig
pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance
pub fn deinit(instance: *runtime.Instance) void
```

## Extended Attributes

The codegen parses WebIDL extended attributes and includes them in generated metadata:

**Common Extended Attributes:**
- `[Exposed=Window]` - Interface only available in Window context
- `[Exposed=*]` - Interface available in all contexts  
- `[Exposed=(Window,Worker)]` - Available in multiple contexts
- `[Serializable]` - Can be structured cloned
- `[Transferable]` - Can be transferred between contexts
- `[SecureContext]` - Only available in secure contexts (HTTPS)

**Example in Generated Code:**
```zig
pub const extended_attributes = .{
    .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
    .{ .name = "Serializable" },
};

pub const exposed_in = .{
    .Window = true,
    .Worker = false,
};
```

## Codegen Source Files

The code generation system is implemented in `src/webidl/codegen/`:

| File | Purpose |
|------|---------|
| `root.zig` | Module exports and public API |
| `pipeline.zig` | Main codegen pipeline orchestration |
| `idl_scanner.zig` | Scan directories for IDL files |
| `idl_parser.zig` | Parse WebIDL syntax |
| `lexer.zig` | Tokenize WebIDL source |
| `parser.zig` | Parse tokens into AST |
| `ir.zig` | Intermediate representation builder |
| `types.zig` | Type definitions for AST/IR |
| `generator.zig` | Main code generation logic |
| `writer.zig` | Write Zig code to files |
| `refs.zig` | Type reference resolution |
| `overload.zig` | Overload resolution |
| `extattr.zig` | Extended attribute parsing |
| `property_classifier.zig` | Classify properties vs methods |
| `spec_priority.zig` | Prioritize specifications |
| `config.zig` | Codegen configuration |
| `adapter.zig` | Adapt IR to output format |
| `files.zig` | File I/O utilities |

## Workflow for Codegen Changes

### When Modifying Codegen Logic

1. **Make changes** to source files in `src/webidl/codegen/`
2. **Test changes** with codegen tests:
   ```bash
   zig build test --spec codegen
   ```
3. **Regenerate all files**:
   ```bash
   zig build codegen -- specs/idl/ specs/supplementary/ --dest-root src/webidl/
   ```
4. **Verify build succeeds**:
   ```bash
   zig build
   ```
5. **Run full test suite**:
   ```bash
   zig build test
   ```
6. **Commit changes** - Both codegen source AND regenerated files together

### When IDL Files Change

If WebIDL definitions in `specs/idl/` or `specs/supplementary/` change:

1. **Regenerate affected files**:
   ```bash
   zig build codegen -- specs/idl/ specs/supplementary/ --dest-root src/webidl/
   ```
2. **Update implementations** in `src/webidl/impls/` if needed
3. **Update tests** to match new signatures
4. **Verify all tests pass**:
   ```bash
   zig build test
   ```

## Important Rules

### ✅ DO

- ✅ **Always regenerate after codegen changes** - Run codegen before committing
- ✅ **Commit generated files** - Generated files should be in version control
- ✅ **Test after regeneration** - Ensure all tests still pass
- ✅ **Update both IDL sources and codegen** - Keep them in sync
- ✅ **Use `--impls` flag carefully** - Only when you need fresh stubs

### ❌ DON'T

- ❌ **Don't manually edit generated interface/typedef/dictionary files** - Changes will be overwritten
- ❌ **Don't skip regeneration** - Generated files must match IDL sources
- ❌ **Don't modify IDL files directly** - Use official WHATWG sources
- ❌ **Don't use `--impls` on existing code** - It will overwrite implementations
- ❌ **Don't commit without testing** - Always verify build and tests pass

## Golden Rule: Generated Files Are Read-Only

**Files in these directories are AUTO-GENERATED:**
- `src/webidl/interfaces/` ❌ DO NOT EDIT
- `src/webidl/typedefs/` ❌ DO NOT EDIT
- `src/webidl/dictionaries/` ❌ DO NOT EDIT
- `src/webidl/callbacks/` ❌ DO NOT EDIT
- `src/webidl/enums/` ❌ DO NOT EDIT
- `src/webidl/namespaces/` ❌ DO NOT EDIT

**Exception for experimentation:**
1. ✅ You MAY temporarily edit a generated file to test a bug fix
2. ⚠️ Once the fix works, you MUST:
   - Update the codegen source files to produce that fix
   - Regenerate ALL files: `zig build codegen -- specs/idl/ specs/supplementary/ --dest-root src/webidl/`
   - Verify the codegen produces the correct output
3. ❌ NEVER commit manual edits to generated files
4. ❌ NEVER leave generated files in a manually-edited state

**Files you CAN edit:**
- `src/webidl/impls/` ✅ EDIT FREELY - This is where you implement interfaces
- `src/webidl/codegen/` ✅ EDIT TO FIX CODEGEN - Source of code generation
- `specs/supplementary/` ✅ ADD TEST IDL - Additional definitions

## Debugging Codegen Issues

### Problem: Type Mismatch Errors After Regeneration

**Solution:** Delete all generated files and regenerate from scratch:

```bash
# Delete generated files (keep impls!)
rm -rf src/webidl/interfaces/*
rm -rf src/webidl/typedefs/*
rm -rf src/webidl/dictionaries/*
rm -rf src/webidl/callbacks/*
rm -rf src/webidl/enums/*
rm -rf src/webidl/namespaces/*

# Regenerate everything
zig build codegen -- specs/idl/ specs/supplementary/ --dest-root src/webidl/

# Verify
zig build
```

**Why this works:** Partial regeneration can leave stale files with wrong signatures.

### Problem: Missing Types/Interfaces

**Solution:** Check if the IDL file exists and is being parsed:

```bash
# Check if IDL file exists
ls specs/idl/MyInterface.idl
ls specs/supplementary/MyInterface.idl

# Run codegen with verbose output
zig build codegen -- specs/idl/ specs/supplementary/ --dest-root src/webidl/ --verbose

# Check for parser errors
zig build test --spec codegen
```

### Problem: Wrong Function Signatures

**Solution:** Check the IDL definition and regenerate:

1. Verify IDL syntax is correct
2. Check for typos in parameter names/types
3. Regenerate the specific file
4. Compare with expected signature

## Integration with Build System

The codegen is integrated into `build.zig`:

```zig
// Codegen tool executable
const codegen_exe = b.addExecutable(.{
    .name = "codegen",
    .root_module = b.createModule(.{
        .root_source_file = b.path("tools/codegen_main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "codegen", .module = codegen_mod },
            .{ .name = "webidl", .module = webidl_mod },
        },
    }),
});

// Codegen step
const codegen_step = b.step("codegen", "Generate WebIDL bindings");
const codegen_run = b.addRunArtifact(codegen_exe);
codegen_run.addArgs(&.{
    "specs/idl/",
    "specs/supplementary/",
    "--dest-root",
    "src/webidl/",
});
codegen_step.dependOn(&codegen_run.step);
```

## References

- **WebIDL Specification**: https://webidl.spec.whatwg.org/
- **WebRef IDL Repository**: https://github.com/w3c/webref (source for `specs/idl/`)
- **WHATWG Specifications**: `specs/whatwg/` (markdown specifications)
- **Codegen Entry Point**: `tools/codegen_main.zig`
- **Codegen Module**: `src/webidl/codegen/`

## Summary

The WebIDL codegen system:
- Reads IDL files from `specs/idl/` and `specs/supplementary/`
- Generates type-safe Zig code in `src/webidl/`
- Creates interfaces, typedefs, dictionaries, callbacks, enums, and namespaces
- Provides implementation stubs for developers to fill in
- Follows strict naming conventions (`get_`, `set_`, `call_` prefixes)
- Includes metadata for V8 JavaScript bindings
- Runs automatically during build or manually via `zig build codegen`

**Remember:** Generated files are the source of truth for WebIDL type definitions. Always regenerate after changes to IDL files or codegen logic.
