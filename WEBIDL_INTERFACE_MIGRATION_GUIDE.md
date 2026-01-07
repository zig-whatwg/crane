# WebIDL Interface Migration Guide

**Purpose:** Migrate interfaces from old `webidl.interface()` pattern to new runtime-based impl system  
**Status:** Template based on successful URL/URLSearchParams migration

## Overview

This guide describes how to migrate any WHATWG specification interface from the old system (`webidl/src/*/`) to the new runtime-based system (`src/webidl/impls/`).

### Systems Comparison

| Aspect | Old System (`webidl/src/*`) | New System (`src/webidl/impls/*`) |
|--------|----------------------------|-----------------------------------|
| Pattern | `webidl.interface()` macro | Runtime-based with codegen |
| State | Defined in interface struct | InternalState + Generated State |
| Lifecycle | Manual init/deinit | Runtime.Instance lifecycle |
| Properties | Direct struct fields | Computed from InternalState |
| Automation | Manual updates | Auto-generated from IDL |

## Prerequisites

✅ **Codegen must support InternalState** (already implemented)
- Generated interfaces have `_internal: ?*{ImplName}.InternalState = null` field
- Codegen in `src/webidl/codegen/writer.zig` and `generator.zig`

## Migration Process

### Step 1: Analyze Old Implementation

**Location:** `webidl/src/{spec-name}/{InterfaceName}.zig`

**Identify:**
1. **Internal state** - What data structures does it maintain?
2. **Dependencies** - What other modules does it import?
3. **Lifecycle** - How are resources allocated and freed?
4. **Properties** - Are they stored or computed?
5. **Methods** - What algorithms do they implement?

**Example (URL):**
```zig
// Old: webidl/src/url/URL.zig
pub const URL = webidl.interface(struct {
    url_record: URLRecord,              // ← Internal state
    query_impl: *URLSearchParamsImpl,   // ← Related object
    allocator: std.mem.Allocator,       // ← Resource management
    
    pub fn init(...) { }                // ← Lifecycle
    pub fn get_href(...) { }            // ← Computed property
});
```

### Step 2: Design InternalState

**Location:** `src/webidl/impls/{InterfaceName}.zig`

**Define InternalState with:**
- Core data structures (parsed objects, internal state)
- References to related objects
- Allocator for resource management

**Pattern:**
```zig
/// Internal state for {InterfaceName} implementation
pub const InternalState = struct {
    // Core data structure (source of truth)
    {core_structure}: {CoreType},
    
    // Related objects (if bidirectional relationship)
    {related_object}_instance: ?*runtime.Instance,
    
    // Resource management
    allocator: std.mem.Allocator,
    
    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        self.{core_structure}.deinit();
        allocator.destroy(self);
    }
};
```

**Example (URL):**
```zig
pub const InternalState = struct {
    url_record: URLRecord,                     // Parsed URL
    query_params_instance: ?*runtime.Instance, // URLSearchParams
    allocator: std.mem.Allocator,
    
    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        self.url_record.deinit();
        allocator.destroy(self);
    }
};
```

### Step 3: Implement Constructor

**Pattern:**
```zig
pub fn call_constructor(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    {params...}
) !*runtime.Instance {
    // 1. Create runtime instance
    const instance = try init(allocator, State, &{InterfaceName}.vtable, ctx);
    errdefer deinit(instance);
    
    const state = instance.getState(State);
    
    // 2. Parse/process input parameters
    const {core_data} = try {parseFunction}(allocator, {params});
    errdefer {core_data}.deinit();
    
    // 3. Create InternalState
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);
    
    internal.* = InternalState{
        .{core_structure} = {core_data},
        .{related_object}_instance = null,
        .allocator = allocator,
    };
    
    state.own._internal = internal;
    
    // 4. Initialize related objects (if needed)
    // See bidirectional relationship pattern below
    
    return instance;
}
```

### Step 4: Implement Lifecycle

**Pattern:**
```zig
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return runtime.Instance.init(allocator, StateType, vtable, ctx);
}

pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit(internal.allocator);
    }
    runtime.Instance.deinit(instance);
}
```

### Step 5: Implement Getters

**Two approaches:**

**A. Computed Properties (Chrome KURL pattern)**
- Properties calculated from core structure on-demand
- No redundant storage
- Single source of truth

```zig
pub fn get_{property}(instance: *runtime.Instance) !runtime.{Type} {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    
    // Compute from core structure
    return {compute_from}(internal.allocator, &internal.{core_structure});
}
```

**B. Cached Properties**
- Store computed value in Generated State
- Return cached value on subsequent calls

```zig
pub fn get_{property}(instance: *runtime.Instance) !runtime.{Type} {
    const state = instance.getState(State);
    
    // Check if cached (Generated State has the field)
    if (state.own.{property}) |cached| {
        return cached;
    }
    
    const internal = state.own._internal orelse return error.InvalidState;
    
    // Compute and cache
    const value = try {compute_from}(internal.allocator, &internal.{core_structure});
    state.own.{property} = value;
    return value;
}
```

### Step 6: Implement Setters

**Pattern:**
```zig
pub fn set_{property}(instance: *runtime.Instance, value: runtime.{Type}) !void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    
    // Modify core structure
    try internal.{core_structure}.{update_method}(value);
    
    // Invalidate caches if using cached properties
    state.own.{property} = null;
    
    // Sync with related objects if needed
    try {update_related_objects}(instance);
}
```

### Step 7: Implement Methods

**Pattern:**
```zig
pub fn call_{method}(
    instance: *runtime.Instance,
    {params...}
) !{ReturnType} {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    
    // Delegate to core structure or implement algorithm
    return internal.{core_structure}.{method}({params});
}
```

### Step 8: Add Module Imports

**Location:** `build.zig`

Find where `impls_mod.addImport` calls are made and add your dependencies:

```zig
// After URL infrastructure imports
impls_mod.addImport("{module_name}", {module_var});
```

**Common modules:**
- `infra` - Infra primitives (lists, strings, etc.)
- `encoding` - Text encoding/decoding
- `url` - URL parsing/serialization
- `dom` - DOM types and structures

### Step 9: Test Build

```bash
cd /path/to/whatwg
zig build
```

Fix any compilation errors, then commit.

## Patterns for Common Scenarios

### Bidirectional Relationships

**Example:** URL ↔ URLSearchParams

**In Constructor:**
```zig
// Create related object
const RelatedInterface = interfaces.{RelatedName};
const related_instance = try RelatedInterface.call_constructor(
    allocator,
    ctx,
    {init_data},
);
errdefer RelatedInterface.deinit(related_instance);

// Get related object's internal state
const RelatedState = interfaces.{RelatedName}.State;
const related_state = related_instance.getState(RelatedState);
if (related_state.own._internal) |related_internal| {
    // Initialize it
    // ...
    
    // Set back-reference
    related_internal.{parent_object} = instance;
}

// Store in this object's internal state
internal.{related_object}_instance = related_instance;
```

**In Update Methods:**
```zig
fn updateRelatedObject(instance: *runtime.Instance) !void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    
    if (internal.{related_object}_instance) |related_instance| {
        const RelatedImpl = @import("impls").{RelatedName};
        const related_state = related_instance.getState(interfaces.{RelatedName}.State);
        
        if (related_state.own._internal) |related_internal_ptr| {
            const related_internal: *RelatedImpl.InternalState = 
                @ptrCast(@alignCast(related_internal_ptr));
            
            // Update related object's state
            try related_internal.{update_method}({data});
        }
    }
}
```

### Union Type Handling

**Example:** URLSearchParams constructor

**WebIDL:**
```webidl
constructor(optional (sequence<sequence<USVString>> or 
                      record<USVString, USVString> or 
                      USVString) init = "");
```

**Pattern:**
```zig
pub fn call_constructor(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    init_data: *const anyopaque,
) !*runtime.Instance {
    // Create instance
    const instance = try init(allocator, State, &{Interface}.vtable, ctx);
    errdefer deinit(instance);
    
    const state = instance.getState(State);
    
    // Create InternalState
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);
    
    internal.* = InternalState{
        .list = infra.List(Tuple).init(allocator),
        .allocator = allocator,
    };
    
    // Type detection for union types
    // Option 1: Runtime type tag (if provided by runtime)
    // Option 2: Duck typing (check structure)
    // Option 3: Accept typed input via helper functions
    
    // For now, treat as string if non-null
    // TODO: Implement proper union type detection
    _ = init_data;
    
    state.own._internal = internal;
    return instance;
}
```

### Error Handling

**Pattern:**
```zig
pub fn call_{method}(...) !ReturnType {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    
    // Try operation, convert errors
    const result = internal.{core_structure}.{method}(...) catch |err| {
        return switch (err) {
            error.ParseError => error.TypeError,  // WebIDL errors
            error.OutOfMemory => error.OutOfMemory,
            else => error.InternalError,
        };
    };
    
    return result;
}
```

### Memory Management

**Rules:**
1. **InternalState owns core structures** - Calls deinit() on them
2. **Caller owns returned strings** - Use `allocator.dupe()` or similar
3. **Use errdefer for cleanup** - Ensure no leaks on error paths
4. **Test with std.testing.allocator** - Detects leaks automatically

**Example:**
```zig
pub fn get_{property}(instance: *runtime.Instance) !runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    
    // Compute value (might allocate)
    const value = try compute(internal.allocator, &internal.{core_structure});
    errdefer internal.allocator.free(value);  // Clean up on error
    
    // Return - caller owns the memory
    return value;
}
```

## Checklist

Use this checklist for each interface migration:

### Analysis Phase
- [ ] Identified internal state structures
- [ ] Mapped dependencies (modules to import)
- [ ] Understood lifecycle (allocation/deallocation)
- [ ] Categorized properties (stored vs computed)
- [ ] Listed all methods and their algorithms

### Implementation Phase
- [ ] Defined InternalState struct
- [ ] Implemented constructor
- [ ] Implemented init/deinit lifecycle
- [ ] Implemented all getters
- [ ] Implemented all setters
- [ ] Implemented all methods
- [ ] Added module imports to build.zig
- [ ] Handled bidirectional relationships (if any)
- [ ] Implemented union type handling (if any)

### Verification Phase
- [ ] Code compiles without errors
- [ ] No memory leaks (test with std.testing.allocator)
- [ ] All TODO markers addressed or documented
- [ ] Committed with descriptive message

### Testing Phase (Future)
- [ ] Unit tests for getters/setters
- [ ] Integration tests for relationships
- [ ] Spec compliance tests (WPT)
- [ ] Memory leak verification
- [ ] Performance benchmarks

## Examples

### Completed Migrations

1. **URL** (`src/webidl/impls/URL.zig`)
   - InternalState: URLRecord + URLSearchParams reference
   - Pattern: Computed properties from URLRecord
   - Commits: `a5f73c97`, `21f52ba1`, `8ae13207`

2. **URLSearchParams** (`src/webidl/impls/URLSearchParams.zig`)
   - InternalState: List<Tuple> + URL reference
   - Pattern: Direct state manipulation
   - Commits: `1fca51ea`, `8ae13207`

### Pending Migrations

**High Priority:**
- Console (`webidl/src/console/`) - Simple, good learning example
- Encoding (`webidl/src/encoding/`) - TextEncoder, TextDecoder

**Medium Priority:**
- Streams (`webidl/src/streams/`) - Complex state machines
- DOM (`webidl/src/dom/`) - Large, many interfaces

**Low Priority:**
- HTML (`webidl/src/html/`) - Depends on DOM

## Common Issues

### Issue: "no module named '{module}' available within module 'impls'"

**Solution:** Add module import to `build.zig`:
```zig
impls_mod.addImport("{module}", {module_var});
```

### Issue: "struct has no member named 'InternalState'"

**Solution:** Make sure InternalState is defined as `pub const` in the impl file.

### Issue: "cannot assign to constant"

**Solution:** Get mutable state slice: `internal.list.toSliceMut()` instead of `toSlice()`.

### Issue: Circular dependency between interfaces

**Solution:** Use type-erased `*runtime.Instance` and cast when needed:
```zig
const RelatedImpl = @import("impls").{RelatedName};
const related_internal: *RelatedImpl.InternalState = 
    @ptrCast(@alignCast(opaque_ptr));
```

## Namespace Migration

**Namespaces are different from interfaces** - they have no instance state, only static methods.

### Key Differences

| Aspect | Interface | Namespace |
|--------|-----------|-----------|
| Instances | Has instances with state | No instances (static only) |
| Constructor | `call_constructor` creates instances | No constructor |
| State | `InternalState` per instance | No instance state |
| Methods | Operate on instance state | Static functions |

### Namespace State Management

**Problem:** Namespaces don't have instances, but some (like console) need state.

**Solution:** Store namespace state in `runtime.Context`.

### Example: Console Namespace

**1. Add State to ContextData** (`src/runtime/context.zig`):
```zig
pub const ConsoleState = struct {
    count_map: std.StringHashMap(u32),
    timer_table: std.StringHashMap(i64),
    group_stack: std.ArrayList(u32),
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .count_map = std.StringHashMap(u32).init(allocator),
            .timer_table = std.StringHashMap(i64).init(allocator),
            .group_stack = .{}, // ArrayList empty init
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        // Free all keys
        var count_iter = self.count_map.keyIterator();
        while (count_iter.next()) |key| {
            allocator.free(key.*);
        }
        self.count_map.deinit();
        
        var timer_iter = self.timer_table.keyIterator();
        while (timer_iter.next()) |key| {
            allocator.free(key.*);
        }
        self.timer_table.deinit();
        
        self.group_stack.deinit(allocator);
    }
    
    pub fn getIndentLevel(self: *const Self) u32 {
        return @intCast(self.group_stack.items.len);
    }
};

pub const ContextData = struct {
    allocator: std.mem.Allocator,
    logger: Logger,
    engine_ctx: ?*anyopaque,
    console_state: ConsoleState, // ← Add namespace state here
    
    pub fn init(allocator: std.mem.Allocator, options: Options) !Self {
        return .{
            .allocator = allocator,
            .logger = Logger.init(allocator, .{ ... }),
            .engine_ctx = options.engine_ctx,
            .console_state = ConsoleState.init(allocator), // ← Initialize
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.console_state.deinit(self.allocator); // ← Cleanup
        self.logger.deinit();
    }
};
```

**2. Export State from Runtime** (`src/runtime/root.zig`):
```zig
pub const ConsoleState = @import("context.zig").ConsoleState;
```

**3. Implement Namespace Methods** (`src/webidl/impls/console.zig`):
```zig
/// console.count(label)
pub fn call_count(ctx: runtime.Context, label: runtime.DOMString) void {
    const label_str = label.asSlice();
    
    const gop = ctx.console_state.count_map.getOrPut(label_str) catch return;
    if (!gop.found_existing) {
        const owned_label = ctx.allocator.dupe(u8, label_str) catch return;
        gop.key_ptr.* = owned_label;
        gop.value_ptr.* = 1;
    } else {
        gop.value_ptr.* += 1;
    }
    
    printIndented(ctx, "{s}: {d}", .{ label_str, gop.value_ptr.* });
}

/// console.time(label)
pub fn call_time(ctx: runtime.Context, label: runtime.DOMString) void {
    const label_str = label.asSlice();
    
    const gop = ctx.console_state.timer_table.getOrPut(label_str) catch return;
    if (!gop.found_existing) {
        const owned_label = ctx.allocator.dupe(u8, label_str) catch return;
        gop.key_ptr.* = owned_label;
        gop.value_ptr.* = std.time.milliTimestamp();
    }
}

/// console.group(data...)
pub fn call_group(ctx: runtime.Context, data: []const *const anyopaque) void {
    _ = data;
    printIndented(ctx, "▼ Group", .{});
    ctx.console_state.group_stack.append(ctx.allocator, 0) catch {};
}
```

### Namespace Patterns

**Per-Context State:**
- Each `runtime.Context` has its own namespace state
- Multiple contexts = separate state (thread-safe by design)
- No global variables needed

**State Lifecycle:**
- Init: `ContextData.init` creates namespace state
- Use: Namespace methods access `ctx.{namespace}_state`
- Cleanup: `ContextData.deinit` frees namespace state

**Testing:**
```zig
test "console state is per-context" {
    var ctx1 = try runtime.ContextData.init(allocator, .{});
    defer ctx1.deinit();
    
    var ctx2 = try runtime.ContextData.init(allocator, .{});
    defer ctx2.deinit();
    
    // Operations on ctx1 don't affect ctx2
    console.call_count(&ctx1, label);
    console.call_count(&ctx1, label);
    
    try testing.expectEqual(@as(u32, 2), ctx1.console_state.count_map.get("label").?);
    try testing.expect(!ctx2.console_state.count_map.contains("label"));
}
```

### When to Use Namespace Pattern

Use namespaces when:
- ✅ Spec defines it as namespace (not interface)
- ✅ All methods are static (no `this` binding)
- ✅ No instances created from constructor
- ✅ Examples: console, Math, Reflect

Don't use for:
- ❌ Interfaces with constructors
- ❌ Objects with instance state
- ❌ Prototypes with methods

## Resources

- **WHATWG Specs:** https://spec.whatwg.org/
- **Codegen:** `src/webidl/codegen/`
- **Runtime:** `src/runtime/`
- **Interface Example:** `src/webidl/impls/URL.zig` (reference implementation)
- **Namespace Example:** `src/webidl/impls/console.zig` (console namespace)
- **Context State:** `src/runtime/context.zig` (namespace state management)
- **Migration Summary:** `tmp/summaries/url_migration_complete.md`

## Getting Help

1. Check existing impl files for patterns
2. Review URL/URLSearchParams implementation
3. Read spec carefully - algorithm steps matter
4. Test incrementally - compile often
5. Ask questions when requirements unclear

**Remember:** Spec compliance > Performance. Get it correct first, optimize later.
