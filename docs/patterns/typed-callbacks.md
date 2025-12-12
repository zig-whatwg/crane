# Typed Callback Migration Guide

This guide documents how to identify and migrate `anyopaque` callback patterns to typed alternatives.

## Pattern Identification

### Patterns That CAN Be Migrated

1. **Manual context casting in callback body**
   ```zig
   // BEFORE: Manual @ptrCast/@alignCast
   fn callback(ctx: ?*anyopaque) void {
       const state = @as(*State, @ptrCast(@alignCast(ctx orelse return)));
       state.doSomething();
   }
   ```

2. **Callback registration with separate context pointer**
   ```zig
   // BEFORE: Separate context and function
   pub const CallbackFn = *const fn (ctx: ?*anyopaque, data: []const u8) void;
   
   fn register(cb: CallbackFn, ctx: ?*anyopaque) void { ... }
   ```

3. **Struct fields storing callback with context**
   ```zig
   // BEFORE: Struct with anyopaque context
   const Handler = struct {
       callback: *const fn (ctx: ?*anyopaque, event: Event) void,
       context: ?*anyopaque,
   };
   ```

### Patterns That Should NOT Be Migrated

1. **C ABI boundaries (`callconv(.c)`)**
   ```zig
   // KEEP: C ABI requires type erasure
   pub const NativeMethodFn = *const fn (
       engine_ctx: *anyopaque,
       this: *anyopaque,
       argc: u32,
       argv: [*]const *anyopaque,
   ) callconv(.c) ?*anyopaque;
   ```

2. **VTable polymorphism**
   ```zig
   // KEEP: Runtime backend selection requires type erasure
   pub const Backend = struct {
       ptr: *anyopaque,  // Type-erased implementation pointer
       vtable: *const VTable,
   };
   ```

3. **Engine interface boundaries**
   ```zig
   // KEEP: Different JS engines have different types
   pub const EngineInterface = struct {
       wrapAsyncIterator: *const fn (
           engine_ctx: *anyopaque,  // V8 Isolate, JSC VM, etc.
           zig_iterator: *anyopaque,
       ) EngineError!*anyopaque,
   };
   ```

4. **Pointer tagging systems**
   ```zig
   // KEEP: Pointer tagging requires raw address manipulation
   pub fn tagPointer(ptr: *anyopaque, tag: PointerTag) *anyopaque { ... }
   ```

5. **WebIDL `object` and `symbol` types**
   ```zig
   // KEEP: These represent "any JS object" by definition
   .zig_type = *anyopaque,  // for 'object' type
   .zig_type = *anyopaque,  // for 'symbol' type
   ```

---

## Migration Patterns

### Pattern 1: Typed Callback Wrapper

**Before:**
```zig
pub const CallbackFn = *const fn (ctx: ?*anyopaque, data: []const u8) void;

fn processData(cb: CallbackFn, ctx: ?*anyopaque, data: []const u8) void {
    cb(ctx, data);
}

// Usage
fn myCallback(ctx: ?*anyopaque, data: []const u8) void {
    const state = @as(*MyState, @ptrCast(@alignCast(ctx orelse return)));
    state.processData(data);
}

processData(myCallback, @ptrCast(&my_state), "hello");
```

**After:**
```zig
pub fn TypedCallback(comptime Context: type) type {
    return struct {
        callback: *const fn (ctx: *Context, data: []const u8) void,
        context: *Context,
        
        pub fn call(self: @This(), data: []const u8) void {
            self.callback(self.context, data);
        }
    };
}

fn processData(comptime Context: type, cb: TypedCallback(Context), data: []const u8) void {
    cb.call(data);
}

// Usage
fn myCallback(state: *MyState, data: []const u8) void {
    state.processData(data);
}

processData(MyState, .{ .callback = myCallback, .context = &my_state }, "hello");
```

### Pattern 2: Generic Handler Struct

**Before:**
```zig
const EventHandler = struct {
    callback: *const fn (ctx: ?*anyopaque, event: Event) void,
    context: ?*anyopaque,
    
    fn invoke(self: *const EventHandler, event: Event) void {
        self.callback(self.context, event);
    }
};
```

**After:**
```zig
fn TypedEventHandler(comptime Context: type) type {
    return struct {
        callback: *const fn (ctx: *Context, event: Event) void,
        context: *Context,
        
        pub fn invoke(self: *const @This(), event: Event) void {
            self.callback(self.context, event);
        }
    };
}

// For mixed contexts, use a tagged union:
const EventHandler = union(enum) {
    state_a: TypedEventHandler(StateA),
    state_b: TypedEventHandler(StateB),
    // etc.
    
    pub fn invoke(self: *const EventHandler, event: Event) void {
        switch (self.*) {
            .state_a => |h| h.invoke(event),
            .state_b => |h| h.invoke(event),
        }
    }
};
```

### Pattern 3: Closure-Like Pattern

**Before:**
```zig
fn scheduleWork(work: *const fn (ctx: ?*anyopaque) void, ctx: ?*anyopaque) void {
    // Queue the work
}

// Usage
fn doWork(ctx: ?*anyopaque) void {
    const data = @as(*WorkData, @ptrCast(@alignCast(ctx orelse return)));
    data.execute();
}
scheduleWork(doWork, @ptrCast(&work_data));
```

**After:**
```zig
fn TypedWork(comptime T: type) type {
    return struct {
        data: *T,
        execute: *const fn (*T) void,
        
        pub fn run(self: @This()) void {
            self.execute(self.data);
        }
    };
}

fn scheduleWork(comptime T: type, work: TypedWork(T)) void {
    // Queue the work
}

// Usage
const work = TypedWork(WorkData){
    .data = &work_data,
    .execute = WorkData.execute,
};
scheduleWork(WorkData, work);
```

---

## Decision Tree

```
Is this an FFI/C ABI boundary?
├─ YES → KEEP anyopaque (callconv(.c) requires it)
└─ NO ↓

Is this a VTable polymorphism pattern?
├─ YES → KEEP anyopaque (runtime dispatch requires type erasure)
└─ NO ↓

Does the callback cross engine boundaries?
├─ YES → KEEP anyopaque (different engines have different types)
└─ NO ↓

Is the context type known at compile time?
├─ YES → MIGRATE to typed callback
└─ NO ↓

Can contexts be enumerated in a tagged union?
├─ YES → MIGRATE using tagged union
└─ NO → KEEP anyopaque (truly polymorphic)
```

---

## Testing Guidance

### Before Migration
```zig
test "callback with anyopaque context" {
    var state = TestState{};
    const callback = makeCallback(&state);
    callback.call("test");
    try testing.expect(state.called);
}
```

### After Migration
```zig
test "typed callback" {
    var state = TestState{};
    const callback = TypedCallback(TestState){
        .callback = TestState.onData,
        .context = &state,
    };
    callback.call("test");
    try testing.expect(state.called);
}
```

### Verify Type Safety
```zig
test "typed callback rejects wrong type" {
    var wrong_state = WrongState{};
    // This should NOT compile:
    // const callback = TypedCallback(TestState){
    //     .callback = TestState.onData,
    //     .context = &wrong_state,  // Compile error: type mismatch
    // };
}
```

---

## Common Mistakes

### Mistake 1: Over-typing VTables
```zig
// WRONG: Trying to type a VTable context
pub const Backend = struct {
    ptr: *SqliteBackend,  // This breaks polymorphism!
    vtable: *const VTable,
};

// CORRECT: Keep type erasure for VTables
pub const Backend = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
};
```

### Mistake 2: Breaking C ABI
```zig
// WRONG: Can't use generics with C ABI
pub fn TypedNativeCallback(comptime T: type) type {
    return *const fn (ctx: *T) callconv(.c) void;  // ERROR
}

// CORRECT: C ABI requires anyopaque
pub const NativeCallback = *const fn (ctx: *anyopaque) callconv(.c) void;
```

### Mistake 3: Unnecessary Type Erasure
```zig
// WRONG: Using anyopaque when type is known
fn processTimer(ctx: ?*anyopaque) void {
    const timer = @as(*Timer, @ptrCast(@alignCast(ctx orelse return)));
    // ...
}

// CORRECT: Use typed parameter directly
fn processTimer(timer: *Timer) void {
    // No cast needed!
}
```

---

## Files to Reference

- `src/runtime/engine_interface.zig` - Examples of necessary anyopaque (KEEP)
- `src/runtime/engine_binding.zig` - C ABI callback patterns (KEEP)
- `src/platform/layout_backend.zig` - VTable pattern (KEEP)
- `src/trusted_types/policy.zig` - Refactorable callback patterns
- `src/webidl/impls/callback_helpers.zig` - Typed callback utilities

---

## Summary

| Pattern | Action | Reason |
|---------|--------|--------|
| C ABI callback | KEEP | C interop requires type erasure |
| VTable context | KEEP | Runtime polymorphism requires type erasure |
| Engine interface | KEEP | Different engines have incompatible types |
| Pointer tagging | KEEP | Raw pointer manipulation required |
| WebIDL object/symbol | KEEP | Spec-mandated "any object" type |
| Internal callbacks | MIGRATE | Compile-time type safety possible |
| Event handlers | MIGRATE | Context type usually known |
| Timer callbacks | MIGRATE | Context type usually known |
