//! V8 RAII Handle Wrappers
//!
//! This module provides RAII-style wrappers for V8 Global handles to ensure
//! proper cleanup and prevent memory leaks. All wrappers follow the pattern:
//!
//! ```zig
//! var handle = try V8String.fromUtf8(isolate, "hello");
//! defer handle.deinit();  // Automatically disposes the V8 handle
//!
//! // Use handle.raw() to get the underlying pointer for FFI calls
//! const result = ffi.v8_SomeFunction(handle.raw());
//! ```
//!
//! ## Ownership Model
//!
//! - `wrap()` - Takes ownership of an existing handle
//! - `deinit()` - Disposes the handle and invalidates the wrapper
//! - `raw()` - Gets the underlying pointer (does not transfer ownership)
//! - `release()` - Transfers ownership out, caller must dispose
//!
//! ## HandleBag for Bulk Management
//!
//! When creating many temporary handles, use HandleBag for automatic cleanup:
//!
//! ```zig
//! var bag = HandleBag.init(allocator);
//! defer bag.deinit();  // Disposes all tracked handles
//!
//! const str1 = try bag.trackString(ffi.v8_String_NewFromUtf8(...));
//! const str2 = try bag.trackString(ffi.v8_String_NewFromUtf8(...));
//! // Both strings automatically disposed when bag.deinit() is called
//! ```

const std = @import("std");
const ffi = @import("ffi.zig");

// ============================================================================
// Error Types
// ============================================================================

pub const HandleError = error{
    /// Failed to create a V8 string
    StringCreationFailed,
    /// Failed to create a V8 object
    ObjectCreationFailed,
    /// Failed to access object property
    PropertyAccessFailed,
    /// Failed to set object property
    PropertySetFailed,
    /// Failed to call function
    FunctionCallFailed,
    /// Failed to access global object
    GlobalAccessFailed,
    /// Failed to create promise
    PromiseCreationFailed,
    /// Failed to chain promise handlers
    PromiseThenFailed,
    /// Handle was already released or disposed
    HandleInvalid,
    /// Out of memory
    OutOfMemory,
};

// ============================================================================
// V8Value - Generic Value Handle
// ============================================================================

/// RAII wrapper for V8 Global<Value>
/// Automatically disposes handle when deinit() is called
pub const V8Value = struct {
    ptr: ?*ffi.Value,

    const Self = @This();

    /// Wrap an existing V8 Value pointer, taking ownership
    pub fn wrap(ptr: *ffi.Value) Self {
        return .{ .ptr = ptr };
    }

    /// Wrap an optional V8 Value pointer
    pub fn wrapOptional(ptr: ?*ffi.Value) ?Self {
        if (ptr) |p| return wrap(p);
        return null;
    }

    /// Create an empty/invalid handle
    pub fn empty() Self {
        return .{ .ptr = null };
    }

    /// Check if handle is valid
    pub fn isValid(self: Self) bool {
        return self.ptr != null;
    }

    /// Dispose the handle and invalidate the wrapper
    pub fn deinit(self: *Self) void {
        if (self.ptr) |p| {
            ffi.v8_Value_Dispose(p);
        }
        self.ptr = null;
    }

    /// Get the raw pointer for FFI calls
    /// Returns error if handle is invalid
    pub fn raw(self: Self) HandleError!*ffi.Value {
        return self.ptr orelse return HandleError.HandleInvalid;
    }

    /// Get raw pointer or null (for optional FFI parameters)
    pub fn rawOrNull(self: Self) ?*ffi.Value {
        return self.ptr;
    }

    /// Transfer ownership - caller takes responsibility for disposal
    pub fn release(self: *Self) HandleError!*ffi.Value {
        const ptr = self.ptr orelse return HandleError.HandleInvalid;
        self.ptr = null;
        return ptr;
    }

    /// Check if value is a specific type
    pub fn isString(self: Self) bool {
        if (self.ptr) |p| return ffi.v8_Value_IsString(p);
        return false;
    }

    pub fn isObject(self: Self) bool {
        if (self.ptr) |p| return ffi.v8_Value_IsObject(p);
        return false;
    }

    pub fn isFunction(self: Self) bool {
        if (self.ptr) |p| return ffi.v8_Value_IsFunction(p);
        return false;
    }

    pub fn isArray(self: Self) bool {
        if (self.ptr) |p| return ffi.v8_Value_IsArray(p);
        return false;
    }

    pub fn isPromise(self: Self) bool {
        if (self.ptr) |p| return ffi.v8_Value_IsPromise(p);
        return false;
    }

    pub fn isUndefined(self: Self) bool {
        if (self.ptr) |p| return ffi.v8_Value_IsUndefined(p);
        return false;
    }

    pub fn isNull(self: Self) bool {
        if (self.ptr) |p| return ffi.v8_Value_IsNull(p);
        return false;
    }

    pub fn isBoolean(self: Self) bool {
        if (self.ptr) |p| return ffi.v8_Value_IsBoolean(p);
        return false;
    }

    pub fn isNumber(self: Self) bool {
        if (self.ptr) |p| return ffi.v8_Value_IsNumber(p);
        return false;
    }
};

// ============================================================================
// V8String - String Handle
// ============================================================================

/// RAII wrapper for V8 Global<String>
pub const V8String = struct {
    ptr: ?*ffi.String,

    const Self = @This();

    /// Wrap an existing V8 String pointer, taking ownership
    pub fn wrap(ptr: *ffi.String) Self {
        return .{ .ptr = ptr };
    }

    /// Create a V8 string from UTF-8 bytes
    pub fn fromUtf8(isolate: *ffi.Isolate, bytes: []const u8) HandleError!Self {
        const ptr = ffi.v8_String_NewFromUtf8(
            isolate,
            bytes.ptr,
            @intCast(bytes.len),
        ) orelse return HandleError.StringCreationFailed;
        return wrap(ptr);
    }

    /// Create an empty/invalid handle
    pub fn empty() Self {
        return .{ .ptr = null };
    }

    /// Check if handle is valid
    pub fn isValid(self: Self) bool {
        return self.ptr != null;
    }

    /// Dispose the handle
    pub fn deinit(self: *Self) void {
        if (self.ptr) |p| {
            ffi.v8_String_Dispose(p);
        }
        self.ptr = null;
    }

    /// Get the raw pointer for FFI calls
    pub fn raw(self: Self) HandleError!*ffi.String {
        return self.ptr orelse return HandleError.HandleInvalid;
    }

    /// Get raw pointer or null
    pub fn rawOrNull(self: Self) ?*ffi.String {
        return self.ptr;
    }

    /// Transfer ownership
    pub fn release(self: *Self) HandleError!*ffi.String {
        const ptr = self.ptr orelse return HandleError.HandleInvalid;
        self.ptr = null;
        return ptr;
    }

    /// Get the UTF-8 length of the string
    pub fn utf8Length(self: Self, isolate: *ffi.Isolate) HandleError!usize {
        const p = self.ptr orelse return HandleError.HandleInvalid;
        return @intCast(ffi.v8_String_Utf8Length(p, isolate));
    }

    /// Convert to Zig string slice (allocates)
    pub fn toSlice(self: Self, allocator: std.mem.Allocator, isolate: *ffi.Isolate) ![]u8 {
        const p = self.ptr orelse return HandleError.HandleInvalid;
        const len = ffi.v8_String_Utf8Length(p, isolate);
        if (len <= 0) return allocator.alloc(u8, 0);

        const buf = try allocator.alloc(u8, @intCast(len + 1));
        errdefer allocator.free(buf);

        const written = ffi.v8_String_WriteUtf8(p, isolate, buf.ptr, @intCast(len + 1));
        return buf[0..@intCast(written)];
    }

    /// Cast to V8Value (string is a value)
    pub fn asValue(self: Self) V8Value {
        if (self.ptr) |p| {
            return V8Value.wrap(@ptrCast(p));
        }
        return V8Value.empty();
    }
};

// ============================================================================
// V8Object - Object Handle
// ============================================================================

/// RAII wrapper for V8 Global<Object>
pub const V8Object = struct {
    ptr: ?*ffi.Object,

    const Self = @This();

    /// Wrap an existing V8 Object pointer, taking ownership
    pub fn wrap(ptr: *ffi.Object) Self {
        return .{ .ptr = ptr };
    }

    /// Create a new empty object
    pub fn create(isolate: *ffi.Isolate) HandleError!Self {
        const ptr = ffi.v8_Object_New(isolate) orelse
            return HandleError.ObjectCreationFailed;
        return wrap(ptr);
    }

    /// Create an empty/invalid handle
    pub fn empty() Self {
        return .{ .ptr = null };
    }

    /// Check if handle is valid
    pub fn isValid(self: Self) bool {
        return self.ptr != null;
    }

    /// Dispose the handle
    pub fn deinit(self: *Self) void {
        if (self.ptr) |p| {
            ffi.v8_Object_Dispose(p);
        }
        self.ptr = null;
    }

    /// Get the raw pointer for FFI calls
    pub fn raw(self: Self) HandleError!*ffi.Object {
        return self.ptr orelse return HandleError.HandleInvalid;
    }

    /// Get raw pointer or null
    pub fn rawOrNull(self: Self) ?*ffi.Object {
        return self.ptr;
    }

    /// Transfer ownership
    pub fn release(self: *Self) HandleError!*ffi.Object {
        const ptr = self.ptr orelse return HandleError.HandleInvalid;
        self.ptr = null;
        return ptr;
    }

    /// Get a property by string key
    pub fn getProperty(self: Self, context: *ffi.Context, key: []const u8) HandleError!V8Value {
        const p = self.ptr orelse return HandleError.HandleInvalid;
        const result = ffi.v8_Object_GetPropertyWithKey(context, p, key.ptr, @intCast(key.len)) orelse
            return HandleError.PropertyAccessFailed;
        return V8Value.wrap(result);
    }

    /// Set a property by string key
    pub fn setProperty(self: Self, context: *ffi.Context, key: []const u8, value: V8Value) HandleError!void {
        const p = self.ptr orelse return HandleError.HandleInvalid;
        const v = try value.raw();
        if (!ffi.v8_Object_SetPropertyWithKey(context, p, key.ptr, @intCast(key.len), v)) {
            return HandleError.PropertySetFailed;
        }
    }

    /// Cast to V8Value (object is a value)
    pub fn asValue(self: Self) V8Value {
        if (self.ptr) |p| {
            return V8Value.wrap(@ptrCast(p));
        }
        return V8Value.empty();
    }
};

// ============================================================================
// V8Array - Array Handle
// ============================================================================

/// RAII wrapper for V8 Global<Array>
pub const V8Array = struct {
    ptr: ?*ffi.Array,

    const Self = @This();

    /// Wrap an existing V8 Array pointer, taking ownership
    pub fn wrap(ptr: *ffi.Array) Self {
        return .{ .ptr = ptr };
    }

    /// Create a new array with given length
    pub fn create(isolate: *ffi.Isolate, length: usize) Self {
        const ptr = ffi.v8_Array_New(isolate, @intCast(length));
        return wrap(ptr);
    }

    /// Create an empty/invalid handle
    pub fn empty() Self {
        return .{ .ptr = null };
    }

    /// Check if handle is valid
    pub fn isValid(self: Self) bool {
        return self.ptr != null;
    }

    /// Dispose the handle
    pub fn deinit(self: *Self) void {
        if (self.ptr) |p| {
            ffi.v8_Array_Dispose(p);
        }
        self.ptr = null;
    }

    /// Get the raw pointer for FFI calls
    pub fn raw(self: Self) HandleError!*ffi.Array {
        return self.ptr orelse return HandleError.HandleInvalid;
    }

    /// Get array length
    pub fn getLength(self: Self) HandleError!u32 {
        const p = self.ptr orelse return HandleError.HandleInvalid;
        return ffi.v8_Array_Length(p);
    }

    /// Get element at index
    pub fn get(self: Self, context: *ffi.Context, index: u32) HandleError!V8Value {
        const p = self.ptr orelse return HandleError.HandleInvalid;
        const result = ffi.v8_Array_Get(context, p, index) orelse
            return HandleError.PropertyAccessFailed;
        return V8Value.wrap(result);
    }

    /// Set element at index
    pub fn set(self: Self, context: *ffi.Context, index: u32, value: V8Value) HandleError!void {
        const p = self.ptr orelse return HandleError.HandleInvalid;
        const v = try value.raw();
        if (!ffi.v8_Array_Set(p, context, index, v)) {
            return HandleError.PropertySetFailed;
        }
    }

    /// Cast to V8Value
    pub fn asValue(self: Self) V8Value {
        if (self.ptr) |p| {
            return V8Value.wrap(@ptrCast(p));
        }
        return V8Value.empty();
    }
};

// ============================================================================
// V8Function - Function Handle
// ============================================================================

/// RAII wrapper for V8 Global<Function>
pub const V8Function = struct {
    ptr: ?*ffi.Function,

    const Self = @This();

    /// Wrap an existing V8 Function pointer, taking ownership
    pub fn wrap(ptr: *ffi.Function) Self {
        return .{ .ptr = ptr };
    }

    /// Create an empty/invalid handle
    pub fn empty() Self {
        return .{ .ptr = null };
    }

    /// Check if handle is valid
    pub fn isValid(self: Self) bool {
        return self.ptr != null;
    }

    /// Dispose the handle
    pub fn deinit(self: *Self) void {
        if (self.ptr) |p| {
            ffi.v8_Function_Dispose(p);
        }
        self.ptr = null;
    }

    /// Get the raw pointer for FFI calls
    pub fn raw(self: Self) HandleError!*ffi.Function {
        return self.ptr orelse return HandleError.HandleInvalid;
    }

    /// Get raw pointer or null
    pub fn rawOrNull(self: Self) ?*ffi.Function {
        return self.ptr;
    }

    /// Transfer ownership
    pub fn release(self: *Self) HandleError!*ffi.Function {
        const ptr = self.ptr orelse return HandleError.HandleInvalid;
        self.ptr = null;
        return ptr;
    }

    /// Call the function with the safe wrapper (captures exceptions)
    pub fn callSafe(
        self: Self,
        context: *ffi.Context,
        receiver: ?V8Value,
        args: []const V8Value,
    ) !V8Value {
        const fn_ptr = self.ptr orelse return HandleError.HandleInvalid;

        // Build args array
        var raw_args: [16]*ffi.Value = undefined;
        const arg_count = @min(args.len, 16);
        for (args[0..arg_count], 0..) |arg, i| {
            raw_args[i] = try arg.raw();
        }

        const recv_ptr = if (receiver) |r| r.rawOrNull() else null;

        const result = ffi.v8_Function_Call_Safe(
            fn_ptr,
            context,
            recv_ptr,
            @intCast(arg_count),
            if (arg_count > 0) &raw_args else null,
        );
        defer ffi.v8_FreeFunctionCallResult(result);

        if (result.error_info) |err| {
            // Log error details
            if (err.message) |msg| {
                std.log.err("Function call error: {s}", .{std.mem.sliceTo(msg, 0)});
            }
            return HandleError.FunctionCallFailed;
        }

        if (result.value) |v| {
            return V8Value.wrap(v);
        }

        return V8Value.empty();
    }

    /// Cast to V8Value
    pub fn asValue(self: Self) V8Value {
        if (self.ptr) |p| {
            return V8Value.wrap(@ptrCast(p));
        }
        return V8Value.empty();
    }
};

// ============================================================================
// V8Promise - Promise Handle
// ============================================================================

/// RAII wrapper for V8 Global<Promise>
pub const V8Promise = struct {
    ptr: ?*ffi.Promise,

    const Self = @This();

    /// Wrap an existing V8 Promise pointer, taking ownership
    pub fn wrap(ptr: *ffi.Promise) Self {
        return .{ .ptr = ptr };
    }

    /// Create an empty/invalid handle
    pub fn empty() Self {
        return .{ .ptr = null };
    }

    /// Check if handle is valid
    pub fn isValid(self: Self) bool {
        return self.ptr != null;
    }

    /// Dispose the handle
    pub fn deinit(self: *Self) void {
        if (self.ptr) |p| {
            ffi.v8_Promise_Dispose(p);
        }
        self.ptr = null;
    }

    /// Get the raw pointer for FFI calls
    pub fn raw(self: Self) HandleError!*ffi.Promise {
        return self.ptr orelse return HandleError.HandleInvalid;
    }

    /// Cast to V8Value
    pub fn asValue(self: Self) V8Value {
        if (self.ptr) |p| {
            return V8Value.wrap(@ptrCast(p));
        }
        return V8Value.empty();
    }
};

// ============================================================================
// V8PromiseResolver - Promise Resolver Handle
// ============================================================================

/// RAII wrapper for V8 Global<Promise::Resolver>
pub const V8PromiseResolver = struct {
    ptr: ?*ffi.PromiseResolver,

    const Self = @This();

    /// Wrap an existing resolver pointer, taking ownership
    pub fn wrap(ptr: *ffi.PromiseResolver) Self {
        return .{ .ptr = ptr };
    }

    /// Create a new promise resolver
    pub fn create(context: *ffi.Context) HandleError!Self {
        const ptr = ffi.v8_PromiseResolver_New(context) orelse
            return HandleError.PromiseCreationFailed;
        return wrap(ptr);
    }

    /// Create an empty/invalid handle
    pub fn empty() Self {
        return .{ .ptr = null };
    }

    /// Check if handle is valid
    pub fn isValid(self: Self) bool {
        return self.ptr != null;
    }

    /// Dispose the handle
    pub fn deinit(self: *Self) void {
        if (self.ptr) |p| {
            ffi.v8_PromiseResolver_Dispose(p);
        }
        self.ptr = null;
    }

    /// Get the raw pointer for FFI calls
    pub fn raw(self: Self) HandleError!*ffi.PromiseResolver {
        return self.ptr orelse return HandleError.HandleInvalid;
    }

    /// Resolve the promise with a value
    pub fn resolve(self: Self, context: *ffi.Context, value: V8Value) HandleError!void {
        const p = self.ptr orelse return HandleError.HandleInvalid;
        const v = try value.raw();
        _ = ffi.v8_PromiseResolver_Resolve(p, context, v);
    }

    /// Reject the promise with a value
    pub fn reject(self: Self, context: *ffi.Context, value: V8Value) HandleError!void {
        const p = self.ptr orelse return HandleError.HandleInvalid;
        const v = try value.raw();
        _ = ffi.v8_PromiseResolver_Reject(p, context, v);
    }

    /// Get the underlying promise
    pub fn getPromise(self: Self) HandleError!V8Promise {
        const p = self.ptr orelse return HandleError.HandleInvalid;
        const promise = ffi.v8_PromiseResolver_GetPromise(p) orelse
            return HandleError.PromiseCreationFailed;
        return V8Promise.wrap(promise);
    }
};

// ============================================================================
// V8Context - Context Handle
// ============================================================================

/// RAII wrapper for V8 Global<Context>
pub const V8Context = struct {
    ptr: ?*ffi.Context,

    const Self = @This();

    /// Wrap an existing V8 Context pointer, taking ownership
    pub fn wrap(ptr: *ffi.Context) Self {
        return .{ .ptr = ptr };
    }

    /// Create an empty/invalid handle
    pub fn empty() Self {
        return .{ .ptr = null };
    }

    /// Check if handle is valid
    pub fn isValid(self: Self) bool {
        return self.ptr != null;
    }

    /// Dispose the handle
    pub fn deinit(self: *Self) void {
        if (self.ptr) |p| {
            ffi.v8_Context_Dispose(p);
        }
        self.ptr = null;
    }

    /// Get the raw pointer for FFI calls
    pub fn raw(self: Self) HandleError!*ffi.Context {
        return self.ptr orelse return HandleError.HandleInvalid;
    }

    /// Get raw pointer or null
    pub fn rawOrNull(self: Self) ?*ffi.Context {
        return self.ptr;
    }

    /// Get the global object
    pub fn global(self: Self) HandleError!V8Object {
        const p = self.ptr orelse return HandleError.HandleInvalid;
        const g = ffi.v8_Context_Global(p) orelse
            return HandleError.GlobalAccessFailed;
        return V8Object.wrap(g);
    }
};

// ============================================================================
// V8Script - Compiled Script Handle
// ============================================================================

/// RAII wrapper for V8 Global<Script>
pub const V8Script = struct {
    ptr: ?*ffi.Script,

    const Self = @This();

    /// Wrap an existing V8 Script pointer, taking ownership
    pub fn wrap(ptr: *ffi.Script) Self {
        return .{ .ptr = ptr };
    }

    /// Create an empty/invalid handle
    pub fn empty() Self {
        return .{ .ptr = null };
    }

    /// Check if handle is valid
    pub fn isValid(self: Self) bool {
        return self.ptr != null;
    }

    /// Dispose the handle
    pub fn deinit(self: *Self) void {
        if (self.ptr) |p| {
            ffi.v8_Script_Dispose(p);
        }
        self.ptr = null;
    }

    /// Get the raw pointer for FFI calls
    pub fn raw(self: Self) HandleError!*ffi.Script {
        return self.ptr orelse return HandleError.HandleInvalid;
    }
};

// ============================================================================
// V8Module - ES Module Handle
// ============================================================================

/// RAII wrapper for V8 Global<Module>
pub const V8Module = struct {
    ptr: ?*ffi.Module,

    const Self = @This();

    /// Wrap an existing V8 Module pointer, taking ownership
    pub fn wrap(ptr: *ffi.Module) Self {
        return .{ .ptr = ptr };
    }

    /// Create an empty/invalid handle
    pub fn empty() Self {
        return .{ .ptr = null };
    }

    /// Check if handle is valid
    pub fn isValid(self: Self) bool {
        return self.ptr != null;
    }

    /// Dispose the handle
    pub fn deinit(self: *Self) void {
        if (self.ptr) |p| {
            ffi.v8_Module_Dispose(p);
        }
        self.ptr = null;
    }

    /// Get the raw pointer for FFI calls
    pub fn raw(self: Self) HandleError!*ffi.Module {
        return self.ptr orelse return HandleError.HandleInvalid;
    }

    /// Get module status
    pub fn getStatus(self: Self) HandleError!ffi.ModuleStatus {
        const p = self.ptr orelse return HandleError.HandleInvalid;
        return @enumFromInt(ffi.v8_Module_GetStatus(p));
    }
};

// ============================================================================
// HandleBag - Bulk Handle Management
// ============================================================================

/// Manages multiple handles with automatic cleanup
/// Use when creating many temporary handles that should all be disposed together
pub const HandleBag = struct {
    allocator: std.mem.Allocator,
    values: std.ArrayList(*ffi.Value),
    objects: std.ArrayList(*ffi.Object),
    strings: std.ArrayList(*ffi.String),
    arrays: std.ArrayList(*ffi.Array),
    functions: std.ArrayList(*ffi.Function),
    promises: std.ArrayList(*ffi.Promise),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .values = std.ArrayList(*ffi.Value).init(allocator),
            .objects = std.ArrayList(*ffi.Object).init(allocator),
            .strings = std.ArrayList(*ffi.String).init(allocator),
            .arrays = std.ArrayList(*ffi.Array).init(allocator),
            .functions = std.ArrayList(*ffi.Function).init(allocator),
            .promises = std.ArrayList(*ffi.Promise).init(allocator),
        };
    }

    /// Dispose all tracked handles and free internal storage
    pub fn deinit(self: *Self) void {
        for (self.values.items) |v| ffi.v8_Value_Dispose(v);
        for (self.objects.items) |o| ffi.v8_Object_Dispose(o);
        for (self.strings.items) |s| ffi.v8_String_Dispose(s);
        for (self.arrays.items) |a| ffi.v8_Array_Dispose(a);
        for (self.functions.items) |f| ffi.v8_Function_Dispose(f);
        for (self.promises.items) |p| ffi.v8_Promise_Dispose(p);

        self.values.deinit();
        self.objects.deinit();
        self.strings.deinit();
        self.arrays.deinit();
        self.functions.deinit();
        self.promises.deinit();
    }

    /// Track a value handle
    pub fn trackValue(self: *Self, value: *ffi.Value) !*ffi.Value {
        try self.values.append(value);
        return value;
    }

    /// Track an object handle
    pub fn trackObject(self: *Self, object: *ffi.Object) !*ffi.Object {
        try self.objects.append(object);
        return object;
    }

    /// Track a string handle
    pub fn trackString(self: *Self, string: *ffi.String) !*ffi.String {
        try self.strings.append(string);
        return string;
    }

    /// Track an array handle
    pub fn trackArray(self: *Self, array: *ffi.Array) !*ffi.Array {
        try self.arrays.append(array);
        return array;
    }

    /// Track a function handle
    pub fn trackFunction(self: *Self, func: *ffi.Function) !*ffi.Function {
        try self.functions.append(func);
        return func;
    }

    /// Track a promise handle
    pub fn trackPromise(self: *Self, promise: *ffi.Promise) !*ffi.Promise {
        try self.promises.append(promise);
        return promise;
    }

    /// Create and track a string from UTF-8
    pub fn createString(self: *Self, isolate: *ffi.Isolate, bytes: []const u8) !*ffi.String {
        const str = ffi.v8_String_NewFromUtf8(
            isolate,
            bytes.ptr,
            @intCast(bytes.len),
        ) orelse return HandleError.StringCreationFailed;
        return self.trackString(str);
    }

    /// Create and track a new object
    pub fn createObject(self: *Self, isolate: *ffi.Isolate) !*ffi.Object {
        const obj = ffi.v8_Object_New(isolate) orelse
            return HandleError.ObjectCreationFailed;
        return self.trackObject(obj);
    }

    /// Create and track a new array
    pub fn createArray(self: *Self, isolate: *ffi.Isolate, length: usize) !*ffi.Array {
        const arr = ffi.v8_Array_New(isolate, @intCast(length));
        return self.trackArray(arr);
    }

    /// Get count of all tracked handles
    pub fn count(self: Self) usize {
        return self.values.items.len +
            self.objects.items.len +
            self.strings.items.len +
            self.arrays.items.len +
            self.functions.items.len +
            self.promises.items.len;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "V8Value empty and wrap" {
    const empty = V8Value.empty();
    try std.testing.expect(!empty.isValid());
    try std.testing.expectError(HandleError.HandleInvalid, empty.raw());
}

test "V8String empty" {
    const empty = V8String.empty();
    try std.testing.expect(!empty.isValid());
}

test "HandleBag init and deinit" {
    var bag = HandleBag.init(std.testing.allocator);
    defer bag.deinit();
    try std.testing.expectEqual(@as(usize, 0), bag.count());
}
