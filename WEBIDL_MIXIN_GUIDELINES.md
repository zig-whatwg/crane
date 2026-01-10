# WebIDL Mixin Implementation Guidelines

**Authoritative guide for implementing WebIDL mixins in the WHATWG monorepo**

---

## Critical Rules

### 1. Always Use `webidl.mixin()` for Mixins

**ALL mixin definitions MUST use the `webidl.mixin()` wrapper:**

```zig
// ✅ CORRECT
pub const TextDecoderCommon = webidl.mixin(struct {
    encoding: []const u8,
    fatal: webidl.boolean,
    ignoreBOM: webidl.boolean,
});

// ❌ WRONG - Missing wrapper
pub const TextDecoderCommon = struct { ... };
pub const TextDecoderCommon = webidl.interface(struct { ... });
```

### 2. Always Use Composition (Embed Mixin as Field)

**Interfaces that include mixins MUST embed them as fields, not duplicate fields:**

```zig
// IDL: TextDecoder includes TextDecoderCommon;

// ✅ CORRECT - Embed mixin as field
pub const TextDecoder = webidl.interface(struct {
    mixin: TextDecoderCommon,  // ✅ Composition
    allocator: std.mem.Allocator,
    // ... other interface-specific fields
});

// ❌ WRONG - Field duplication
pub const TextDecoder = webidl.interface(struct {
    encoding: []const u8,       // ❌ Duplicated from mixin
    fatal: webidl.boolean,      // ❌ Duplicated from mixin
    ignoreBOM: webidl.boolean,  // ❌ Duplicated from mixin
    allocator: std.mem.Allocator,
});
```

### 3. Always Delegate to Mixin

**All getters for mixin attributes MUST delegate to the mixin field:**

```zig
// ✅ CORRECT - Delegation
pub inline fn encoding(self: *const TextDecoder) []const u8 {
    return self.mixin.encoding;  // ✅ Delegate to mixin
}

pub inline fn getFatal(self: *const TextDecoder) webidl.boolean {
    return self.mixin.fatal;  // ✅ Delegate to mixin
}

// ❌ WRONG - Direct field access
pub inline fn encoding(self: *const TextDecoder) []const u8 {
    return self.encodingName;  // ❌ Bypasses mixin
}
```

### 4. Initialize Mixins in Constructor

```zig
pub fn init(...) !TextDecoder {
    return .{
        .mixin = .{  // ✅ Initialize mixin
            .encoding = enc.name,
            .fatal = options.fatal,
            .ignoreBOM = options.ignoreBOM,
        },
        .allocator = allocator,
        // ... other fields
    };
}
```

---

## Multiple Mixin Composition

**When an interface includes multiple mixins, use descriptive field names:**

```zig
// IDL:
// TextDecoderStream includes TextDecoderCommon;
// TextDecoderStream includes GenericTransformStream;

pub const TextDecoderStream = webidl.interface(struct {
    decoderMixin: TextDecoderCommon,        // ✅ Descriptive name
    transformMixin: GenericTransformStream, // ✅ Descriptive name
    
    allocator: std.mem.Allocator,
    // ... other fields
    
    // Delegate to correct mixin
    pub inline fn encoding(self: *const TextDecoderStream) []const u8 {
        return self.decoderMixin.encoding;
    }
    
    pub inline fn readable(self: *const TextDecoderStream) *ReadableStream {
        return self.transformMixin.readable();
    }
});
```

---

## Implementation Workflow

### Step 1: Check Spec for Mixins

**Look for `includes` statements in the WebIDL:**

```
// In specs/encoding.md:
interface TextDecoder {
  constructor(...);
  // ...
};
TextDecoder includes TextDecoderCommon;

interface mixin TextDecoderCommon {
  readonly attribute DOMString encoding;
  readonly attribute boolean fatal;
  readonly attribute boolean ignoreBOM;
};
```

### Step 2: Create/Verify Mixin Definition

**File:** `webidl/src/encoding/TextDecoderCommon.zig`

```zig
const webidl = @import("webidl");

pub const TextDecoderCommon = webidl.mixin(struct {  // ✅ Use webidl.mixin()
    encoding: []const u8,
    fatal: webidl.boolean,
    ignoreBOM: webidl.boolean,
});
```

### Step 3: Implement Interface with Mixin

**File:** `webidl/src/encoding/TextDecoder.zig`

```zig
const TextDecoderCommon = @import("TextDecoderCommon.zig").TextDecoderCommon;

pub const TextDecoder = webidl.interface(struct {
    mixin: TextDecoderCommon,  // ✅ Embed mixin
    
    allocator: std.mem.Allocator,
    enc: *const Encoding,
    // ... other interface-specific fields
    
    pub fn init(...) !TextDecoder {
        return .{
            .mixin = .{ ... },  // ✅ Initialize
            // ... other fields
        };
    }
    
    // ✅ Delegate getters
    pub inline fn encoding(self: *const TextDecoder) []const u8 {
        return self.mixin.encoding;
    }
    
    pub inline fn getFatal(self: *const TextDecoder) webidl.boolean {
        return self.mixin.fatal;
    }
    
    pub inline fn getIgnoreBOM(self: *const TextDecoder) webidl.boolean {
        return self.mixin.ignoreBOM;
    }
});
```

### Step 4: Update Internal References

**Change all internal field accesses to use the mixin:**

```zig
// ❌ BEFORE
if (!self.ignoreBOM and !self.bomSeen) { ... }
if (self.fatal and result.had_errors) { ... }

// ✅ AFTER
if (!self.mixin.ignoreBOM and !self.bomSeen) { ... }
if (self.mixin.fatal and result.had_errors) { ... }
```

---

## Verification Checklist

When implementing or reviewing mixin code:

### For Mixin Definitions:
- [ ] Uses `webidl.mixin()` wrapper
- [ ] File named in PascalCase (e.g., `TextDecoderCommon.zig`)
- [ ] Contains only shared attributes (no constructors)
- [ ] All fields use camelCase
- [ ] Documented which interfaces include this mixin

### For Interfaces Using Mixins:
- [ ] Checked spec for ALL `includes` statements
- [ ] Embedded mixin(s) as field(s)
- [ ] Used descriptive names for multiple mixins
- [ ] Initialized mixin field(s) in constructor
- [ ] Added delegation methods for all mixin getters
- [ ] NO duplicate mixin fields in struct
- [ ] Updated all internal references to use `self.mixin.field`
- [ ] Tests verify mixin delegation works

---

## Common Mistakes to Avoid

### ❌ Mistake 1: Not Using `webidl.mixin()`

```zig
// ❌ WRONG
pub const TextDecoderCommon = struct {
    encoding: []const u8,
    // ...
};
```

### ❌ Mistake 2: Duplicating Mixin Fields

```zig
// ❌ WRONG
pub const TextDecoder = webidl.interface(struct {
    encoding: []const u8,       // ❌ Should be in mixin
    fatal: webidl.boolean,      // ❌ Should be in mixin
    ignoreBOM: webidl.boolean,  // ❌ Should be in mixin
    allocator: std.mem.Allocator,
});
```

### ❌ Mistake 3: Not Delegating

```zig
// ❌ WRONG
pub inline fn encoding(self: *const TextDecoder) []const u8 {
    return self.encodingName;  // ❌ Not using mixin
}
```

### ❌ Mistake 4: Using Generic Mixin Names

```zig
// ❌ WRONG
pub const TextDecoderStream = webidl.interface(struct {
    mixin1: TextDecoderCommon,        // ❌ Non-descriptive
    mixin2: GenericTransformStream,   // ❌ Non-descriptive
});

// ✅ CORRECT
pub const TextDecoderStream = webidl.interface(struct {
    decoderMixin: TextDecoderCommon,        // ✅ Descriptive
    transformMixin: GenericTransformStream, // ✅ Descriptive
});
```

---

## Reference: Known Mixins

### Encoding Standard
- **TextDecoderCommon** - Shared by TextDecoder, TextDecoderStream
- **TextEncoderCommon** - Shared by TextEncoder, TextEncoderStream

### Streams Standard
- **ReadableStreamGenericReader** - Shared by ReadableStreamDefaultReader, ReadableStreamBYOBReader
- **GenericTransformStream** - Shared by transform stream classes (TextDecoderStream, TextEncoderStream, etc.)

### DOM/Fetch (Examples)
- **WindowOrWorkerGlobalScope** - Shared by Window, WorkerGlobalScope
- **Body** - Shared by Request, Response

---

## See Also

- **ENCODING_MIXIN_FIXES_SUMMARY.md** - Complete refactoring history
- **ENCODING_MIXIN_USAGE_GUIDE.md** - Quick reference for developers
- **skills/whatwg/SKILL.md** - Complete WHATWG implementation guide
- **specs/*.md** - WHATWG specifications with WebIDL definitions

---

**Last Updated:** 2025-11-10  
**Status:** ✅ All encoding mixins correctly implemented
