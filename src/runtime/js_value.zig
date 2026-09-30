//! # Engine-Agnostic JavaScript Value Type
//!
//! This module provides `JSValue` - a type-safe, engine-agnostic representation
//! of JavaScript values for use in WebIDL impl files.
//!
//! ## Design Goals
//!
//! 1. **Engine Independence**: No imports from engine-specific modules (v8, jsc, etc.)
//! 2. **Type Safety**: Tagged union prevents type confusion at compile time
//! 3. **No Sentinel Values**: Explicit undefined/null variants instead of @ptrFromInt(1)
//! 4. **Ownership in the types**: a `JSValue` is BORROWED wherever it is
//!    passed; what must be released is the engine protocol's `engine.Owned`
//!    (AGENTS.md "The engine boundary", rule 3). A `JSValue` an impl RETURNS
//!    is the binding's: kept values go back as `engine.retainValue(...).take()`
//!
//! ## Usage in Impl Files
//!
//! ```zig
//! const runtime = @import("runtime");
//!
//! pub fn call_forEach(instance: *runtime.Instance, callback: runtime.JSValue) !void {
//!     if (callback.isNullOrUndefined()) return;
//!
//!     // Engine operations take the value as it is, in a realm.
//!     const engine = @import("engine");
//!     if (!engine.isCallable(callback)) return error.TypeError;
//!     _ = instance;
//! }
//! ```
//!
//! ## Relationship to Engine-Specific Types
//!
//! - `runtime.JSValue` is the PUBLIC type used in impl files
//! - `v8.JSValue` (in src/runtime/engines/v8/) is the engine-specific implementation
//! - The two are compatible via `asEngineHandle()` and engine conversion functions

const std = @import("std");
const Instance = @import("instance.zig").Instance;

/// Engine-agnostic JavaScript value representation.
///
/// This is the type that WebIDL impl files should use for `any` and `object`
/// type parameters. It provides type safety without coupling to a specific
/// JavaScript engine.
///
/// The engine-specific conversion happens at the boundary, inside the engine
/// protocol's operations (`@import("engine")`).
pub const JSValue = union(enum) {
    /// JavaScript `undefined` value
    undefined: void,

    /// JavaScript `null` value
    null: void,

    /// JavaScript boolean primitive
    boolean: bool,

    /// JavaScript number primitive (IEEE 754 double)
    number: f64,

    /// JavaScript string value
    /// The data may or may not be owned depending on context
    string: StringValue,

    /// Opaque handle to an engine-managed value (object, function, symbol, a
    /// string the engine keeps as one). Who releases it is its holder's type:
    /// see EngineHandle.
    handle: EngineHandle,

    /// Zig runtime.Instance pointer
    /// This is NOT a JavaScript value - it's a Zig object that may be
    /// wrapped by the engine when returned to JavaScript
    instance: *Instance,

    // ========================================================================
    // Nested Types
    // ========================================================================

    /// String value storage
    pub const StringValue = struct {
        data: []const u8,
        owned: bool,

        /// Free owned string data
        pub fn deinit(self: *StringValue, allocator: std.mem.Allocator) void {
            if (self.owned and self.data.len > 0) {
                allocator.free(self.data);
            }
        }
    };

    /// Opaque engine handle: a handle the engine made - for V8 a
    /// `Global<Value>*`, for JavaScriptCore a protected JSValueRef.
    ///
    /// It says nothing about who releases it; the type that holds it does. A
    /// `JSValue` is BORROWED wherever it is passed - an argument, an
    /// ErrorInfo's value, `engine.Owned.borrow()`. What must be released is an
    /// `engine.Owned` (or a Completion, CallbackFunction, CallbackInterface),
    /// released exactly once. A `JSValue` an impl RETURNS to the binding is
    /// the binding's, which releases it once it is the call's result: a value
    /// the impl keeps goes back as a hold of the binding's own,
    /// `engine.retainValue(realm, kept).take()`.
    pub const EngineHandle = struct {
        /// KEEP: anyopaque required - V8 Global<Value>*, JSC JSValueRef, etc.
        ptr: *anyopaque,
    };

    // ========================================================================
    // Constructors
    // ========================================================================

    /// Create an undefined JSValue
    pub const jsUndefined = JSValue{ .undefined = {} };

    /// Create a null JSValue
    pub const jsNull = JSValue{ .null = {} };

    /// Create a boolean JSValue
    pub fn fromBoolean(value: bool) JSValue {
        return .{ .boolean = value };
    }

    /// Create a number JSValue
    pub fn fromNumber(value: f64) JSValue {
        return .{ .number = value };
    }

    /// Create a string JSValue (does not take ownership)
    pub fn fromStringRef(data: []const u8) JSValue {
        return .{ .string = .{ .data = data, .owned = false } };
    }

    /// Create a string JSValue (takes ownership of allocated slice)
    pub fn fromStringOwned(data: []const u8) JSValue {
        return .{ .string = .{ .data = data, .owned = true } };
    }

    /// A JSValue naming the engine handle `ptr` (see EngineHandle: holding
    /// it says nothing about releasing it).
    pub fn fromHandle(ptr: *anyopaque) JSValue {
        return .{ .handle = .{ .ptr = ptr } };
    }

    /// Create a JSValue from a Zig runtime Instance
    ///
    /// Use this when returning a WebIDL interface instance to JavaScript.
    /// The engine will wrap it appropriately when converting to JS.
    pub fn fromInstance(inst: *Instance) JSValue {
        return .{ .instance = inst };
    }

    /// Create a JSValue from an anyopaque pointer that is actually an Instance
    ///
    /// This is for legacy code that passes Instance pointers as *anyopaque.
    /// Prefer using `fromInstance(*Instance)` for new code.
    pub fn fromInstanceAnyopaque(inst: *anyopaque) JSValue {
        return .{ .instance = @ptrCast(@alignCast(inst)) };
    }

    // ========================================================================
    // Legacy Anyopaque Methods (Deprecated)
    // ========================================================================

    /// Create from legacy anyopaque pointer: an engine handle, or null for
    /// JavaScript null.
    ///
    /// DEPRECATED: use `fromHandle()` for an engine handle and `fromInstance()`
    /// for a runtime.Instance. The type information is lost here.
    pub fn fromAnyopaque(ptr: ?*const anyopaque) JSValue {
        if (ptr) |p| {
            return .{ .handle = .{ .ptr = @ptrCast(@constCast(p)) } };
        }
        return jsNull;
    }

    // ========================================================================
    // Type Queries
    // ========================================================================

    /// Check if this is undefined
    pub fn isUndefined(self: JSValue) bool {
        return self == .undefined;
    }

    /// Check if this is null
    pub fn isNull(self: JSValue) bool {
        return self == .null;
    }

    /// Check if this is null or undefined
    pub fn isNullOrUndefined(self: JSValue) bool {
        return self == .undefined or self == .null;
    }

    /// Check if this is a boolean
    pub fn isBoolean(self: JSValue) bool {
        return self == .boolean;
    }

    /// Check if this is a number
    pub fn isNumber(self: JSValue) bool {
        return self == .number;
    }

    /// Check if this is a string
    pub fn isString(self: JSValue) bool {
        return self == .string;
    }

    /// Check if this is an engine handle (object/function)
    pub fn isHandle(self: JSValue) bool {
        return self == .handle;
    }

    /// Check if this is a Zig instance
    pub fn isInstance(self: JSValue) bool {
        return self == .instance;
    }

    // ========================================================================
    // Value Extraction
    // ========================================================================

    /// Get boolean value, or null if not a boolean
    pub fn asBoolean(self: JSValue) ?bool {
        return switch (self) {
            .boolean => |b| b,
            else => null,
        };
    }

    /// Get number value, or null if not a number
    pub fn asNumber(self: JSValue) ?f64 {
        return switch (self) {
            .number => |n| n,
            else => null,
        };
    }

    /// Get string value, or null if not a string
    pub fn asString(self: JSValue) ?[]const u8 {
        return switch (self) {
            .string => |s| s.data,
            else => null,
        };
    }

    /// Get engine handle pointer, or null if not a handle
    pub fn asEngineHandle(self: JSValue) ?*anyopaque {
        return switch (self) {
            .handle => |h| h.ptr,
            else => null,
        };
    }

    /// Get the Instance pointer, or null if not an instance
    ///
    /// Returns the typed Instance pointer for direct use with runtime APIs.
    pub fn toInstance(self: JSValue) ?*Instance {
        return switch (self) {
            .instance => |i| i,
            else => null,
        };
    }

    /// Extract typed state from an Instance JSValue
    ///
    /// Combines toInstance() with Instance.getState() for convenience.
    /// Returns null if this is not an instance JSValue.
    ///
    /// Example:
    /// ```zig
    /// if (js_value.toTypedInstance(BlobState)) |blob_state| {
    ///     // Use blob_state
    /// }
    /// ```
    pub fn toTypedInstance(self: JSValue, comptime StateType: type) ?*StateType {
        if (self.toInstance()) |inst| {
            return inst.getState(StateType);
        }
        return null;
    }

    /// Get instance pointer as anyopaque, or null if not an instance
    ///
    /// This is for legacy code compatibility. Prefer using toInstance().
    pub fn asInstance(self: JSValue) ?*anyopaque {
        return switch (self) {
            .instance => |i| @ptrCast(i),
            else => null,
        };
    }

    /// Convert to legacy anyopaque pointer
    ///
    /// DEPRECATED: Use typed alternatives instead:
    /// - `asEngineHandle()` to get the raw handle pointer
    /// - `toInstance()` to get typed runtime.Instance
    /// - `asInstance()` for anyopaque instance extraction
    ///
    /// WARNING: This loses type information! Use only for transitional code.
    pub fn toAnyopaque(self: JSValue) ?*anyopaque {
        return switch (self) {
            .undefined, .null => null,
            .boolean => null, // Booleans can't be represented as pointers
            .number => null, // Numbers can't be represented as pointers
            .string => null, // Strings need special handling
            .handle => |h| h.ptr,
            .instance => |i| @ptrCast(i),
        };
    }

    // ========================================================================
    // Lifecycle
    // ========================================================================

    /// Free any owned resources (strings only - engine handles need engine disposal)
    pub fn deinit(self: *JSValue, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .string => |*s| s.deinit(allocator),
            else => {},
        }
        self.* = jsUndefined;
    }

    /// Create a deep copy of this JSValue.
    ///
    /// For string variants, this allocates a new buffer and copies the string data.
    /// For other variants (primitives, handles, instances), this returns a shallow copy.
    ///
    /// **IMPORTANT**: When storing a JSValue passed as an argument (e.g., in constructors),
    /// you MUST call clone() to take ownership. The argument cleanup code will free
    /// the original string buffer after the function returns.
    ///
    /// ## Example
    /// ```zig
    /// pub fn call_constructor(ctx: runtime.Context, eventInit: MessageEventInit) !*Instance {
    ///     // Clone the JSValue to take ownership before argument cleanup frees it
    ///     state.own.data = try eventInit.data.clone(ctx.allocator);
    /// }
    /// ```
    pub fn clone(self: JSValue, allocator: std.mem.Allocator) error{OutOfMemory}!JSValue {
        return switch (self) {
            .string => |s| blk: {
                if (s.data.len == 0) {
                    // Empty strings don't need allocation
                    break :blk JSValue{ .string = .{ .data = "", .owned = false } };
                }
                // Allocate a new buffer and copy the string data
                const new_buffer = try allocator.dupe(u8, s.data);
                break :blk JSValue{ .string = .{ .data = new_buffer, .owned = true } };
            },
            // Primitives, handles, and instances can be copied directly
            // (primitives are value types, handles/instances are references that
            // are managed externally)
            else => self,
        };
    }
};

/// Optional JSValue - used for WebIDL optional parameters
///
/// This distinguishes between:
/// - Parameter was not passed at all (not_passed)
/// - Parameter was passed with a value (passed)
pub const OptionalJSValue = union(enum) {
    /// Parameter was not passed
    not_passed: void,

    /// Parameter was passed with this value
    passed: JSValue,

    /// Check if parameter was passed
    pub fn wasPassed(self: OptionalJSValue) bool {
        return self == .passed;
    }

    /// Get the value if passed, or null
    pub fn getValue(self: OptionalJSValue) ?JSValue {
        return switch (self) {
            .not_passed => null,
            .passed => |v| v,
        };
    }

    /// Get the value if passed, or return default
    pub fn getValueOr(self: OptionalJSValue, default: JSValue) JSValue {
        return switch (self) {
            .not_passed => default,
            .passed => |v| v,
        };
    }

    /// Create from a value
    pub fn fromValue(value: JSValue) OptionalJSValue {
        return .{ .passed = value };
    }

    /// Create not-passed variant
    pub const notPassed = OptionalJSValue{ .not_passed = {} };

    /// Free any owned resources
    pub fn deinit(self: *OptionalJSValue, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .passed => |*v| v.deinit(allocator),
            .not_passed => {},
        }
    }
};

// ============================================================================
// Tests
// ============================================================================

test "JSValue undefined" {
    const value = JSValue.jsUndefined;
    try std.testing.expect(value.isUndefined());
    try std.testing.expect(value.isNullOrUndefined());
    try std.testing.expect(!value.isNull());
    try std.testing.expect(!value.isBoolean());
}

test "JSValue null" {
    const value = JSValue.jsNull;
    try std.testing.expect(value.isNull());
    try std.testing.expect(value.isNullOrUndefined());
    try std.testing.expect(!value.isUndefined());
}

test "JSValue boolean" {
    const value_true = JSValue.fromBoolean(true);
    const value_false = JSValue.fromBoolean(false);

    try std.testing.expect(value_true.isBoolean());
    try std.testing.expectEqual(true, value_true.asBoolean());
    try std.testing.expectEqual(false, value_false.asBoolean());
}

test "JSValue number" {
    const value = JSValue.fromNumber(42.5);
    try std.testing.expect(value.isNumber());
    try std.testing.expectEqual(@as(f64, 42.5), value.asNumber().?);
}

test "JSValue string" {
    const value = JSValue.fromStringRef("hello");
    try std.testing.expect(value.isString());
    try std.testing.expectEqualStrings("hello", value.asString().?);
}

test "JSValue handle" {
    var dummy: u8 = 0;
    const value = JSValue.fromHandle(&dummy);
    try std.testing.expect(value.isHandle());
    try std.testing.expect(value.asEngineHandle().? == @as(*anyopaque, &dummy));
}

test "OptionalJSValue not passed" {
    const opt = OptionalJSValue.notPassed;
    try std.testing.expect(!opt.wasPassed());
    try std.testing.expect(opt.getValue() == null);
}

test "OptionalJSValue passed" {
    const opt = OptionalJSValue.fromValue(JSValue.fromNumber(123));
    try std.testing.expect(opt.wasPassed());
    try std.testing.expectEqual(@as(f64, 123), opt.getValue().?.asNumber().?);
}

test "JSValue toAnyopaque for primitives returns null" {
    const undef = JSValue.jsUndefined;
    try std.testing.expect(undef.toAnyopaque() == null);

    const boolean = JSValue.fromBoolean(true);
    try std.testing.expect(boolean.toAnyopaque() == null);

    const number = JSValue.fromNumber(42);
    try std.testing.expect(number.toAnyopaque() == null);
}

test "JSValue toAnyopaque for handle returns pointer" {
    var dummy: u8 = 0;
    const value = JSValue.fromHandle(&dummy);
    try std.testing.expect(value.toAnyopaque() != null);
}

// ============================================================================
// Instance-related Tests
// ============================================================================

test "JSValue instance - fromInstance and toInstance roundtrip" {
    const VTable = @import("instance.zig").VTable;

    // Create a dummy vtable for testing
    const delegates = .{};
    const vtable = VTable{
        .deinit = null,
        .methods_ptr = &delegates,
    };

    // Create a dummy Instance on the stack for testing
    // Note: In real code, Instance is heap-allocated via SlabAllocator
    var dummy_state: u32 = 42;
    var instance = Instance{
        .vtable = &vtable,
        .state = @ptrCast(&dummy_state),
        .ctx = undefined,
    };

    // Test fromInstance and toInstance
    const value = JSValue.fromInstance(&instance);
    try std.testing.expect(value.isInstance());
    try std.testing.expect(!value.isUndefined());
    try std.testing.expect(!value.isHandle());

    const recovered = value.toInstance();
    try std.testing.expect(recovered != null);
    try std.testing.expect(recovered.? == &instance);
}

test "JSValue instance - toTypedInstance extracts state" {
    const VTable = @import("instance.zig").VTable;

    const TestState = struct {
        value: u32,
        name: []const u8,
    };

    var state = TestState{ .value = 123, .name = "test" };

    const delegates = .{};
    const vtable = VTable{
        .deinit = null,
        .methods_ptr = &delegates,
    };

    var instance = Instance{
        .vtable = &vtable,
        .state = @ptrCast(&state),
        .ctx = undefined,
    };

    const value = JSValue.fromInstance(&instance);

    // Extract typed state
    const typed_state = value.toTypedInstance(TestState);
    try std.testing.expect(typed_state != null);
    try std.testing.expectEqual(@as(u32, 123), typed_state.?.value);
    try std.testing.expectEqualStrings("test", typed_state.?.name);
}

test "JSValue instance - toInstance returns null for non-instance" {
    const undef = JSValue.jsUndefined;
    try std.testing.expect(undef.toInstance() == null);

    const number = JSValue.fromNumber(42);
    try std.testing.expect(number.toInstance() == null);

    var dummy: u8 = 0;
    const handle = JSValue.fromHandle(&dummy);
    try std.testing.expect(handle.toInstance() == null);
}

test "JSValue instance - asInstance returns anyopaque for compatibility" {
    const VTable = @import("instance.zig").VTable;

    const delegates = .{};
    const vtable = VTable{
        .deinit = null,
        .methods_ptr = &delegates,
    };

    var dummy_state: u32 = 0;
    var instance = Instance{
        .vtable = &vtable,
        .state = @ptrCast(&dummy_state),
        .ctx = undefined,
    };

    const value = JSValue.fromInstance(&instance);

    // asInstance returns ?*anyopaque for compatibility
    const anyopaque_ptr = value.asInstance();
    try std.testing.expect(anyopaque_ptr != null);
    try std.testing.expect(anyopaque_ptr.? == @as(*anyopaque, &instance));
}

test "JSValue instance - fromInstanceAnyopaque for legacy code" {
    const VTable = @import("instance.zig").VTable;

    const delegates = .{};
    const vtable = VTable{
        .deinit = null,
        .methods_ptr = &delegates,
    };

    var dummy_state: u32 = 0;
    var instance = Instance{
        .vtable = &vtable,
        .state = @ptrCast(&dummy_state),
        .ctx = undefined,
    };

    // Simulate legacy code passing Instance as *anyopaque
    const legacy_ptr: *anyopaque = @ptrCast(&instance);
    const value = JSValue.fromInstanceAnyopaque(legacy_ptr);

    try std.testing.expect(value.isInstance());
    try std.testing.expect(value.toInstance().? == &instance);
}
