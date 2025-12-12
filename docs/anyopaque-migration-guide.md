# Migrating from anyopaque to Typed Alternatives

This guide provides comprehensive patterns for migrating `anyopaque` usage to type-safe alternatives in the WHATWG Zig codebase.

## Table of Contents

1. [When to Keep anyopaque](#when-to-keep-anyopaque)
2. [Pattern 1: Comptime Generics](#pattern-1-comptime-generics)
3. [Pattern 2: Tagged Unions](#pattern-2-tagged-unions)
4. [Pattern 3: TypedCallback](#pattern-3-typedcallback)
5. [Pattern 4: TypedAlgorithm](#pattern-4-typedalgorithm)
6. [Testing Patterns](#testing-patterns)
7. [Decision Tree](#decision-tree)
8. [Common Mistakes](#common-mistakes)

---

## When to Keep anyopaque

**NOT all `anyopaque` should be refactored.** The following patterns are **legitimate** and must be kept:

### 1. C ABI / FFI Boundaries

C interop requires opaque pointers. The C ABI cannot express Zig generic types.

```zig
// KEEP: C ABI callback must use anyopaque
pub const NativeMethodFn = *const fn (
    engine_ctx: *anyopaque,    // V8 Isolate, JSC VM, etc.
    this: *anyopaque,          // JS object reference
    argc: u32,
    argv: [*]const *anyopaque, // Array of JS values
) callconv(.c) ?*anyopaque;

// KEEP: V8/JSC/SpiderMonkey FFI functions
pub extern fn v8_Isolate_SetData(isolate: *Isolate, slot: c_int, data: ?*anyopaque) void;
pub extern fn v8_Isolate_GetData(isolate: *Isolate, slot: c_int) ?*anyopaque;
```

**Mark these with:** `// KEEP: FFI boundary - C interop requires anyopaque`

### 2. VTable Polymorphism

Runtime backend switching requires type erasure. Different implementations have different types.

```zig
// KEEP: VTable pattern for pluggable backends
pub const LayoutBackend = struct {
    ptr: *anyopaque,  // KEEP: Different impl types (Stub, Real, Mock)
    vtable: *const VTable,

    pub const VTable = struct {
        // KEEP: VTable functions receive type-erased impl pointer
        getOffsetWidth: *const fn (ptr: *anyopaque, element: *runtime.Instance) f64,
        deinit: *const fn (ptr: *anyopaque) void,
    };
};
```

**Mark these with:** `// KEEP: VTable polymorphism - enables runtime backend switching`

### 3. Runtime Instance State

The `Instance` struct is a type-erased handle for WebIDL interface polymorphism.

```zig
// KEEP: Polymorphic state for all WebIDL interfaces
pub const Instance = struct {
    vtable: *const VTable,
    state: *anyopaque,  // KEEP: Element, Document, Node, etc. have different states
    ctx: Context,
};
```

**Mark these with:** `// KEEP: Polymorphic state - use getState(T) for type safety`

### 4. Engine-Specific Handles

Different JS engines (V8, JSC, SpiderMonkey) have incompatible internal types.

```zig
// KEEP: Engine interface abstraction
pub const EngineInterface = struct {
    wrapAsyncIterator: *const fn (
        engine_ctx: *anyopaque,  // V8 Isolate OR JSC VM OR SpiderMonkey Context
        zig_iterator: *anyopaque,
    ) EngineError!*anyopaque,
};
```

---

## Pattern 1: Comptime Generics

**Use when:** The type is known at compile time but you want reusable code.

### Before: Manual Type Erasure

```zig
// BAD: Manual anyopaque casting everywhere
pub const List = struct {
    items: []*anyopaque,
    allocator: Allocator,

    pub fn append(self: *List, item: *anyopaque) !void {
        // No type safety - can append wrong type!
    }

    pub fn get(self: *List, index: usize) ?*anyopaque {
        // Caller must cast - error-prone!
    }
};

// Usage requires manual casts
var list = List{...};
try list.append(@ptrCast(&my_node));
const item: *Node = @ptrCast(@alignCast(list.get(0).?));
```

### After: Comptime Generic

```zig
// GOOD: Type-safe at compile time
pub fn List(comptime T: type) type {
    return struct {
        items: []*T,
        allocator: Allocator,

        pub fn append(self: *@This(), item: *T) !void {
            // Type-safe: can only append *T
        }

        pub fn get(self: *@This(), index: usize) ?*T {
            // Type-safe return - no casting needed
        }
    };
}

// Usage is type-safe
var list = List(*Node){...};
try list.append(&my_node);       // Compile error if wrong type!
const item = list.get(0);        // Returns ?*Node directly
```

### Real Examples from Codebase

```zig
// src/infra/list.zig
pub fn List(comptime T: type) type {
    return struct {
        items: std.ArrayList(T),
        // ...
    };
}

// src/streams/internal/async_promise.zig
pub fn AsyncPromise(comptime T: type) type {
    return struct {
        value: ?T,
        state: State,
        // Type-safe fulfillment
        pub fn fulfill(self: *@This(), value: T) void {
            self.value = value;
            self.state = .fulfilled;
        }
    };
}

// src/webidl/wrappers.zig
pub fn Sequence(comptime T: type) type {
    return struct {
        items: []const T,
        // Type-safe WebIDL sequence
    };
}
```

---

## Pattern 2: Tagged Unions

**Use when:** You have a finite set of possible types at runtime.

### Before: Type Erasure with Manual Tracking

```zig
// BAD: Manual type tracking
const EventTarget = struct {
    target_type: TargetType,  // Manual tag
    target_ptr: *anyopaque,   // Type-erased pointer

    const TargetType = enum { element, document, window };

    pub fn getElement(self: EventTarget) ?*Element {
        if (self.target_type != .element) return null;
        return @ptrCast(@alignCast(self.target_ptr));
    }
};
```

### After: Tagged Union

```zig
// GOOD: Type-safe tagged union
const EventTarget = union(enum) {
    element: *Element,
    document: *Document,
    window: *Window,

    pub fn dispatchEvent(self: EventTarget, event: *Event) bool {
        return switch (self) {
            .element => |el| el.dispatchEvent(event),
            .document => |doc| doc.dispatchEvent(event),
            .window => |win| win.dispatchEvent(event),
        };
    }

    pub fn getElement(self: EventTarget) ?*Element {
        return switch (self) {
            .element => |el| el,
            else => null,
        };
    }
};
```

### Real Examples from Codebase

```zig
// src/url/host.zig
pub const Host = union(enum) {
    domain: []const u8,
    ipv4: u32,
    ipv6: [8]u16,
    opaque_host: []const u8,
    empty: void,

    pub fn serialize(self: Host, allocator: Allocator) ![]u8 {
        return switch (self) {
            .domain => |d| try allocator.dupe(u8, d),
            .ipv4 => |ip| try serializeIPv4(allocator, ip),
            .ipv6 => |ip| try serializeIPv6(allocator, ip),
            .opaque_host => |o| try allocator.dupe(u8, o),
            .empty => try allocator.dupe(u8, ""),
        };
    }
};

// src/webidl/types.zig - WebIDL value types
pub const Value = union(enum) {
    undefined: void,
    null: void,
    boolean: bool,
    number: f64,
    string: []const u8,
    object: *runtime.Instance,
    symbol: Symbol,
};
```

---

## Pattern 3: TypedCallback

**Use when:** You have callback functions that receive user data.

### Before: anyopaque User Data

```zig
// BAD: Type-unsafe callback
pub const TimerCallback = *const fn (user_data: ?*anyopaque) void;

fn scheduleTimer(delay_ms: u64, callback: TimerCallback, user_data: ?*anyopaque) void {
    // ...
}

fn myTimerHandler(user_data: ?*anyopaque) void {
    // Manual cast - no compile-time safety!
    const state = @as(*MyState, @ptrCast(@alignCast(user_data orelse return)));
    state.doSomething();
}

// Usage
scheduleTimer(1000, myTimerHandler, @ptrCast(&my_state));
```

### After: TypedCallback

```zig
// GOOD: Type-safe callback wrapper
pub fn TypedCallback(comptime UserData: type, comptime ReturnType: type) type {
    return struct {
        callback: *const fn (data: *UserData) ReturnType,
        data: *UserData,

        pub fn invoke(self: @This()) ReturnType {
            return self.callback(self.data);
        }
    };
}

// Type-safe timer callback
pub fn TypedTimerCallback(comptime T: type) type {
    return TypedCallback(T, void);
}

fn scheduleTimer(comptime T: type, delay_ms: u64, callback: TypedTimerCallback(T)) void {
    // Type information preserved!
}

fn myTimerHandler(state: *MyState) void {
    // Direct typed access - no casting!
    state.doSomething();
}

// Usage - type-safe!
const cb = TypedTimerCallback(MyState){
    .callback = myTimerHandler,
    .data = &my_state,
};
scheduleTimer(MyState, 1000, cb);
```

### Real Examples from Codebase

```zig
// src/runtime/typed_callback.zig
pub fn TypedCallback(comptime UserData: type, comptime ReturnType: type) type {
    return struct {
        const Self = @This();

        callback: *const fn (data: *UserData) ReturnType,
        data: *UserData,
        allocator: ?std.mem.Allocator = null,  // For owned data

        pub fn init(callback: *const fn (data: *UserData) ReturnType, data: *UserData) Self {
            return .{ .callback = callback, .data = data };
        }

        pub fn initOwned(callback: ..., data: *UserData, allocator: Allocator) Self {
            return .{ .callback = callback, .data = data, .allocator = allocator };
        }

        pub fn invoke(self: Self) ReturnType {
            return self.callback(self.data);
        }

        pub fn deinit(self: *Self) void {
            if (self.allocator) |alloc| {
                alloc.destroy(self.data);
                self.allocator = null;
            }
        }
    };
}

// Specialized variants
pub fn TypedTimerCallback(comptime T: type) type { ... }
pub fn TypedMicrotaskCallback(comptime T: type) type { ... }
pub fn TypedGCCallback(comptime T: type) type { ... }
pub fn TypedPromiseFulfillCallback(comptime T: type) type { ... }
```

---

## Pattern 4: TypedAlgorithm

**Use when:** You have algorithms/operations with context that need polymorphic storage.

### Before: Manual Vtable with anyopaque

```zig
// BAD: Manual vtable construction
pub const Algorithm = struct {
    context: ?*anyopaque,
    invoke: *const fn (ctx: ?*anyopaque) anyerror!void,
    destroy: *const fn (ctx: ?*anyopaque, allocator: Allocator) void,
};

// Manual wrapper function with casting
fn myAlgorithmInvoke(ctx: ?*anyopaque) anyerror!void {
    const my_ctx = @as(*MyContext, @ptrCast(@alignCast(ctx orelse return error.InvalidContext)));
    return my_ctx.execute();
}
```

### After: TypedAlgorithm

```zig
// GOOD: Type-safe algorithm with automatic erasure
pub fn TypedAlgorithm(comptime Context: type, comptime Result: type) type {
    return struct {
        context: *Context,
        call_fn: *const fn (*Context) Result,
        deinit_fn: ?*const fn (*Context) void,

        const Self = @This();

        pub fn init(
            context: *Context,
            call_fn: *const fn (*Context) Result,
            deinit_fn: ?*const fn (*Context) void,
        ) Self {
            return .{ .context = context, .call_fn = call_fn, .deinit_fn = deinit_fn };
        }

        /// Type-safe invocation
        pub fn call(self: Self) Result {
            return self.call_fn(self.context);
        }

        /// Convert to type-erased form for polymorphic storage
        pub fn erase(self: Self) ErasedAlgorithm(Result) {
            return ErasedAlgorithm(Result).init(
                @ptrCast(self.context),
                @ptrCast(self.call_fn),
                if (self.deinit_fn) |f| @ptrCast(f) else null,
            );
        }

        pub fn deinit(self: Self) void {
            if (self.deinit_fn) |f| f(self.context);
        }
    };
}
```

### createTypedAlgorithm Helper

For cases where you need the erased form directly:

```zig
// src/streams/internal/algorithm.zig
pub fn createTypedAlgorithm(
    comptime Context: type,
    allocator: Allocator,
    context: *Context,
    comptime invoke_fn: *const fn (*runtime.Instance, *Context) anyerror!*AsyncPromise(void),
    comptime invoke_with_arg_fn: *const fn (*runtime.Instance, *Context, *const anyopaque) anyerror!*AsyncPromise(void),
    comptime destroy_fn: *const fn (*Context, Allocator) void,
) !*Algorithm {
    // Generates type-safe wrappers at comptime
    const Wrapper = struct {
        fn invoke(controller: *runtime.Instance, ctx: ?*anyopaque) anyerror!*AsyncPromise(void) {
            const typed_ctx: *Context = @ptrCast(@alignCast(ctx orelse return error.InvalidContext));
            return invoke_fn(controller, typed_ctx);
        }
        // ... other wrappers
    };

    const algo = try allocator.create(Algorithm);
    algo.* = .{
        .context = context,
        .vtable = &.{ .invoke = Wrapper.invoke, ... },
        .allocator = allocator,
    };
    return algo;
}
```

### Real Usage in Streams

```zig
// src/webidl/impls/ReadableStream.zig
pub fn createPullAlgorithmFromIterable(
    allocator: Allocator,
    context: *FromIterableContext,
) !*Algorithm {
    // Type-safe algorithm creation
    return createTypedAlgorithm(
        FromIterableContext,
        allocator,
        context,
        pullFromIterable,        // fn(*Instance, *FromIterableContext) !*AsyncPromise(void)
        pullFromIterableWithArg,
        destroyFromIterableContext,
    );
}
```

---

## Testing Patterns

### Testing Typed Callbacks

```zig
test "TypedCallback - basic usage" {
    const TestContext = struct {
        counter: usize = 0,

        fn increment(self: *@This()) usize {
            self.counter += 1;
            return self.counter;
        }
    };

    var ctx = TestContext{};
    const cb = TypedCallback(TestContext, usize).init(&TestContext.increment, &ctx);

    try testing.expectEqual(@as(usize, 1), cb.invoke());
    try testing.expectEqual(@as(usize, 2), cb.invoke());
    try testing.expectEqual(@as(usize, 2), ctx.counter);
}
```

### Testing TypedAlgorithm

```zig
test "TypedAlgorithm - maintains type through call chain" {
    const Counter = struct {
        calls: usize = 0,

        fn execute(self: *@This()) i32 {
            self.calls += 1;
            return @intCast(self.calls);
        }
    };

    var counter = Counter{};

    const algo = TypedAlgorithm(Counter, i32).init(
        &counter,
        Counter.execute,
        null,
    );

    try testing.expectEqual(@as(i32, 1), algo.call());
    try testing.expectEqual(@as(i32, 2), algo.call());
    try testing.expectEqual(@as(usize, 2), counter.calls);
}

test "TypedAlgorithm.erase - polymorphic storage" {
    const State = struct { value: u64 };
    var state = State{ .value = 100 };

    const typed = TypedAlgorithm(State, u64).init(
        &state,
        struct {
            fn call(ctx: *State) u64 {
                return ctx.value;
            }
        }.call,
        null,
    );

    // Erase for polymorphic storage
    const erased = typed.erase();

    // Still works through type erasure
    try testing.expectEqual(@as(u64, 100), erased.call());
}
```

### Testing Tagged Unions

```zig
test "Tagged union - type-safe dispatch" {
    const Target = union(enum) {
        element: *Element,
        document: *Document,

        fn getName(self: Target) []const u8 {
            return switch (self) {
                .element => |el| el.tag_name,
                .document => |doc| doc.title,
            };
        }
    };

    var elem = Element{ .tag_name = "div" };
    var doc = Document{ .title = "Test" };

    const target1 = Target{ .element = &elem };
    const target2 = Target{ .document = &doc };

    try testing.expectEqualStrings("div", target1.getName());
    try testing.expectEqualStrings("Test", target2.getName());
}
```

---

## Decision Tree

Use this flowchart to determine the right pattern:

```
Is this a C ABI / FFI boundary?
├─ YES → KEEP anyopaque (callconv(.c) requires it)
│         Add comment: // KEEP: FFI boundary - C interop requires anyopaque
└─ NO ↓

Is this a VTable polymorphism pattern?
├─ YES → KEEP anyopaque (runtime dispatch requires type erasure)
│         Add comment: // KEEP: VTable polymorphism - enables runtime backend switching
└─ NO ↓

Does this cross engine boundaries (V8/JSC/SpiderMonkey)?
├─ YES → KEEP anyopaque (different engines have incompatible types)
│         Add comment: // KEEP: Engine abstraction - different engines have different types
└─ NO ↓

Is the context type known at compile time?
├─ YES → Use COMPTIME GENERICS: `fn Container(comptime T: type) type`
└─ NO ↓

Is this a callback with user data?
├─ YES → Use TYPEDCALLBACK: `TypedCallback(UserData, ReturnType)`
└─ NO ↓

Can the possible types be enumerated?
├─ YES → Use TAGGED UNION: `union(enum) { type_a: *A, type_b: *B, ... }`
└─ NO ↓

Is this an algorithm that needs polymorphic storage?
├─ YES → Use TYPEDALGORITHM: `TypedAlgorithm(Context, Result)` with `.erase()`
└─ NO → KEEP anyopaque (truly polymorphic - document why)
```

---

## Common Mistakes

### Mistake 1: Over-typing VTables

```zig
// WRONG: This breaks polymorphism!
pub const Backend = struct {
    ptr: *SqliteBackend,  // Can't swap implementations
    vtable: *const VTable,
};

// CORRECT: Keep type erasure for VTables
pub const Backend = struct {
    ptr: *anyopaque,  // KEEP: VTable polymorphism
    vtable: *const VTable,
};
```

### Mistake 2: Breaking C ABI

```zig
// WRONG: C ABI can't use generics
pub fn TypedNativeCallback(comptime T: type) type {
    return *const fn (ctx: *T) callconv(.c) void;  // COMPILE ERROR
}

// CORRECT: C ABI requires anyopaque
pub const NativeCallback = *const fn (ctx: *anyopaque) callconv(.c) void;
```

### Mistake 3: Unnecessary Type Erasure

```zig
// WRONG: Using anyopaque when type is known
fn processTimer(ctx: ?*anyopaque) void {
    const timer = @as(*Timer, @ptrCast(@alignCast(ctx orelse return)));
    timer.fire();
}

// CORRECT: Use typed parameter directly
fn processTimer(timer: *Timer) void {
    timer.fire();  // No cast needed!
}
```

### Mistake 4: Forgetting Type Erasure for Storage

```zig
// WRONG: Can't store different callback types together
var callbacks: std.ArrayList(TypedCallback(SpecificType, void)) = ...;

// CORRECT: Use erase() for polymorphic storage
const ErasedCb = ErasedCallback(void);
var callbacks: std.ArrayList(ErasedCb) = ...;
callbacks.append(typed_callback.erase());
```

---

## Summary Table

| Pattern | Use When | Example |
|---------|----------|---------|
| **KEEP anyopaque** | FFI boundaries, VTables, Engine interfaces | `callconv(.c)` functions |
| **Comptime Generics** | Type known at compile time | `List(T)`, `Promise(T)` |
| **Tagged Unions** | Finite set of possible types | `Host`, `Value`, `EventTarget` |
| **TypedCallback** | Callbacks with user data | Timer, microtask, GC callbacks |
| **TypedAlgorithm** | Operations needing polymorphic storage | Stream algorithms |

---

## Related Documentation

- [Type Safety Guidelines](type-safety.md) - Detailed list of legitimate anyopaque uses
- [Typed Callbacks Pattern](patterns/typed-callbacks.md) - Migration patterns for callbacks
- [Opaque Handle Pattern](patterns/opaque-handles.md) - Breaking circular imports

---

## Verification Checklist

Before considering a refactoring complete:

- [ ] All `anyopaque` uses are either KEEP (with comment) or REFACTORED
- [ ] New code uses appropriate typed pattern
- [ ] Tests verify type safety at compile time
- [ ] Tests verify runtime behavior is preserved
- [ ] No memory leaks (`std.testing.allocator` passes)
- [ ] Documentation updated if public API changed
