//! V8 Callback Patterns for WebIDL
//!
//! Provides callback generation for V8 bindings:
//! - Constructor callbacks (new Element())
//! - Property getter callbacks (elem.tagName)
//! - Property setter callbacks (elem.id = "foo")
//! - Method callbacks (elem.getAttribute("class"))
//!
//! Based on patterns from zig-js-runtime (Lightpanda headless browser).
//!
//! ## Architecture
//!
//! Each WebIDL interface gets:
//! - One constructor callback → creates Instance, wraps in V8 object
//! - N getter callbacks → extract Instance, call get_property()
//! - M setter callbacks → extract Instance, call set_property()
//! - P method callbacks → extract Instance, call call_method()
//!
//! ## V8 Callback Signature
//!
//! All V8 callbacks follow this pattern:
//! ```c++
//! void Callback(const v8::FunctionCallbackInfo<v8::Value>& info) {
//!     // Get Instance from V8 object internal field
//!     // Call WebIDL implementation
//!     // Convert result to V8 value
//!     // Set return value
//! }
//! ```
//!
//! ## Usage
//!
//! ```zig
//! const callbacks = @import("runtime").v8_callbacks;
//!
//! // Generate constructor callback
//! const ctor = callbacks.generateConstructor(Element, "init");
//!
//! // Generate getter callback
//! const getter = callbacks.generateGetter(Element, "tagName", "get_tagName");
//!
//! // Generate setter callback
//! const setter = callbacks.generateSetter(Element, "id", "set_id");
//!
//! // Generate method callback
//! const method = callbacks.generateMethod(Element, "getAttribute", "call_getAttribute");
//! ```

const std = @import("std");
const Instance = @import("../../../instance.zig").Instance;
const V8Context = @import("../context.zig").V8Context;

/// Callback information passed from V8
///
/// Mimics v8::FunctionCallbackInfo and v8::PropertyCallbackInfo
/// In real V8 integration, this would be a wrapper around V8's callback info.
pub const CallbackInfo = struct {
    /// V8 context handle (in real V8, this is v8::Local<v8::Context>)
    v8_ctx: *V8Context,

    /// 'this' object handle (in real V8, this is v8::Local<v8::Object>)
    this_handle: ?usize,

    /// Arguments (in real V8, these are v8::Local<v8::Value>)
    args: []const usize,

    /// Return value slot (in real V8, this is v8::ReturnValue<v8::Value>)
    return_value: ?usize,

    /// Get 'this' object
    pub fn getThis(self: CallbackInfo) !*Instance {
        const handle = self.this_handle orelse return error.NoThisObject;
        return try self.v8_ctx.getInstance(handle);
    }

    /// Get argument at index
    pub fn getArg(self: CallbackInfo, index: usize) ?usize {
        if (index >= self.args.len) return null;
        return self.args[index];
    }

    /// Get argument count
    pub fn argCount(self: CallbackInfo) usize {
        return self.args.len;
    }

    /// Set return value
    pub fn setReturnValue(self: *CallbackInfo, value: usize) void {
        self.return_value = value;
    }
};

/// Property callback information
///
/// Mimics v8::PropertyCallbackInfo
pub const PropertyCallbackInfo = struct {
    /// V8 context handle
    v8_ctx: *V8Context,

    /// 'this' object handle
    this_handle: usize,

    /// Return value slot
    return_value: ?usize,

    /// For setters: the value being set
    value: ?usize,

    /// Get 'this' object
    pub fn getThis(self: PropertyCallbackInfo) !*Instance {
        return try self.v8_ctx.getInstance(self.this_handle);
    }

    /// Set return value
    pub fn setReturnValue(self: *PropertyCallbackInfo, val: usize) void {
        self.return_value = val;
    }

    /// Set return value to undefined (represented as null)
    /// Used when accessing properties on prototypes without instances
    pub fn setUndefined(self: *PropertyCallbackInfo) void {
        self.return_value = null;
    }

    /// Get value being set (for setters)
    pub fn getValue(self: PropertyCallbackInfo) ?usize {
        return self.value;
    }
};

/// Constructor callback pattern
///
/// Generated for each WebIDL interface constructor.
///
/// In real V8, this would be:
/// ```c++
/// void ElementConstructor(const v8::FunctionCallbackInfo<v8::Value>& info) {
///     v8::Isolate* isolate = info.GetIsolate();
///     v8::Local<v8::Context> context = isolate->GetCurrentContext();
///
///     // Create WebIDL instance
///     auto* instance = Element::init(allocator, ctx);
///
///     // Wrap in V8 object
///     v8::Local<v8::Object> obj = CreateV8Object(isolate, instance);
///     info.GetReturnValue().Set(obj);
/// }
/// ```
pub const ConstructorCallback = struct {
    interface_name: []const u8,
    init_fn: *const fn (std.mem.Allocator, ?*anyopaque) anyerror!*Instance,

    /// Execute constructor callback
    pub fn call(
        self: ConstructorCallback,
        allocator: std.mem.Allocator,
        info: *CallbackInfo,
    ) !void {
        // Create WebIDL instance
        const runtime_ctx = null; // TODO: Extract from V8 context embedder data
        const instance = try self.init_fn(allocator, runtime_ctx);
        errdefer instance.vtable.deinit.?(instance);

        // Create V8 object handle (mock - in real V8, would create v8::Object)
        const v8_obj_handle = @intFromPtr(instance); // Mock: reuse instance address

        // Bind Instance to V8 Object
        try info.v8_ctx.bindInstance(instance, v8_obj_handle);

        // Set return value
        info.setReturnValue(v8_obj_handle);
    }
};

/// Property getter callback pattern
///
/// Generated for each WebIDL attribute getter.
///
/// In real V8, this would be:
/// ```c++
/// void ElementTagNameGetter(v8::Local<v8::String> property,
///                            const v8::PropertyCallbackInfo<v8::Value>& info) {
///     v8::Isolate* isolate = info.GetIsolate();
///     v8::Local<v8::Object> self = info.Holder();
///
///     // Unwrap WebIDL instance
///     auto* instance = UnwrapInstance(self);
///
///     // Call WebIDL getter
///     auto tag_name = instance->get_tagName();
///
///     // Convert to V8 string
///     info.GetReturnValue().Set(v8::String::NewFromUtf8(isolate, tag_name));
/// }
/// ```
pub const GetterCallback = struct {
    property_name: []const u8,
    getter_fn: *const fn (*Instance) anyerror!usize,

    /// Execute getter callback
    ///
    /// Matches browser behavior:
    /// - If called on an instance: returns the property value
    /// - If called on prototype (no instance): returns undefined
    /// - Does NOT crash or throw error
    pub fn call(self: GetterCallback, info: *PropertyCallbackInfo) !void {
        // Try to get WebIDL instance from V8 object
        const instance = info.getThis() catch {
            // No instance (accessing property on prototype)
            // Match browser behavior: return undefined
            info.setUndefined();
            return;
        };

        // Call WebIDL getter
        const result = try self.getter_fn(instance);

        // Set return value (in real V8, would convert to v8::Value)
        info.setReturnValue(result);
    }
};

/// Property setter callback pattern
///
/// Generated for each WebIDL attribute setter.
///
/// In real V8, this would be:
/// ```c++
/// void ElementIdSetter(v8::Local<v8::String> property,
///                      v8::Local<v8::Value> value,
///                      const v8::PropertyCallbackInfo<void>& info) {
///     v8::Isolate* isolate = info.GetIsolate();
///     v8::Local<v8::Object> self = info.Holder();
///
///     // Unwrap WebIDL instance
///     auto* instance = UnwrapInstance(self);
///
///     // Convert V8 value to string
///     v8::String::Utf8Value str(isolate, value);
///
///     // Call WebIDL setter
///     instance->set_id(*str);
/// }
/// ```
pub const SetterCallback = struct {
    property_name: []const u8,
    setter_fn: *const fn (*Instance, usize) anyerror!void,

    /// Execute setter callback
    ///
    /// Matches browser behavior:
    /// - If called on an instance: sets the property value
    /// - If called on prototype (no instance): silently ignores (or throws TypeError)
    /// - Does NOT crash
    pub fn call(self: SetterCallback, info: *PropertyCallbackInfo) !void {
        // Try to get WebIDL instance from V8 object
        const instance = info.getThis() catch {
            // No instance (setting property on prototype)
            // Match browser behavior: silently ignore
            // (Some browsers throw TypeError: "Illegal invocation")
            return;
        };

        // Get value being set
        const value = info.getValue() orelse return error.NoValue;

        // Call WebIDL setter (in real V8, would convert from v8::Value)
        try self.setter_fn(instance, value);
    }
};

/// Method callback pattern
///
/// Generated for each WebIDL operation.
///
/// In real V8, this would be:
/// ```c++
/// void ElementGetAttributeMethod(const v8::FunctionCallbackInfo<v8::Value>& info) {
///     v8::Isolate* isolate = info.GetIsolate();
///     v8::Local<v8::Object> self = info.Holder();
///
///     // Unwrap WebIDL instance
///     auto* instance = UnwrapInstance(self);
///
///     // Convert arguments
///     v8::String::Utf8Value name(isolate, info[0]);
///
///     // Call WebIDL method
///     auto result = instance->getAttribute(*name);
///
///     // Convert result to V8 value
///     if (result) {
///         info.GetReturnValue().Set(v8::String::NewFromUtf8(isolate, *result));
///     } else {
///         info.GetReturnValue().SetNull();
///     }
/// }
/// ```
pub const MethodCallback = struct {
    method_name: []const u8,
    method_fn: *const fn (*Instance, []const usize) anyerror!?usize,

    /// Execute method callback
    pub fn call(self: MethodCallback, info: *CallbackInfo) !void {
        // Get WebIDL instance from V8 object
        const instance = try info.getThis();

        // Collect arguments (in real V8, would convert from v8::Value[])
        const args = info.args;

        // Call WebIDL method
        const result = try self.method_fn(instance, args);

        // Set return value (in real V8, would convert to v8::Value)
        if (result) |r| {
            info.setReturnValue(r);
        } else {
            // Null/undefined result
            info.setReturnValue(0);
        }
    }
};

// Unit tests

const testing = std.testing;

fn mockInitFn(allocator: std.mem.Allocator, ctx: ?*anyopaque) !*Instance {
    _ = ctx;
    const inst = try allocator.create(Instance);
    inst.* = .{
        .vtable = undefined,
        .state = null,
        .ctx = null,
    };
    return inst;
}

fn mockGetterFn(instance: *Instance) !usize {
    _ = instance;
    return 0x12345678;
}

fn mockSetterFn(instance: *Instance, value: usize) !void {
    _ = instance;
    _ = value;
}

fn mockMethodFn(instance: *Instance, args: []const usize) !?usize {
    _ = instance;
    _ = args;
    return 0xABCDEF;
}

test "ConstructorCallback creates instance and binds to V8 object" {
    const ctx = try V8Context.init(testing.allocator);
    defer ctx.deinit();

    const ctor = ConstructorCallback{
        .interface_name = "Element",
        .init_fn = mockInitFn,
    };

    var callback_info = CallbackInfo{
        .v8_ctx = ctx,
        .this_handle = null,
        .args = &.{},
        .return_value = null,
    };

    try ctor.call(testing.allocator, &callback_info);

    // Verify return value is set
    try testing.expect(callback_info.return_value != null);

    // Verify instance is bound
    const v8_obj_handle = callback_info.return_value.?;
    const instance = try ctx.getInstance(v8_obj_handle);
    try testing.expect(instance != null);

    // Cleanup
    testing.allocator.destroy(instance);
}

test "GetterCallback calls WebIDL getter and returns result" {
    const ctx = try V8Context.init(testing.allocator);
    defer ctx.deinit();

    // Create mock instance
    var instance = Instance{
        .vtable = undefined,
        .state = null,
        .ctx = null,
    };

    const v8_obj_handle: usize = 0x1111;
    try ctx.bindInstance(&instance, v8_obj_handle);

    const getter = GetterCallback{
        .property_name = "tagName",
        .getter_fn = mockGetterFn,
    };

    var prop_info = PropertyCallbackInfo{
        .v8_ctx = ctx,
        .this_handle = v8_obj_handle,
        .return_value = null,
        .value = null,
    };

    try getter.call(&prop_info);

    // Verify return value
    try testing.expectEqual(@as(?usize, 0x12345678), prop_info.return_value);
}

test "SetterCallback calls WebIDL setter with value" {
    const ctx = try V8Context.init(testing.allocator);
    defer ctx.deinit();

    var instance = Instance{
        .vtable = undefined,
        .state = null,
        .ctx = null,
    };

    const v8_obj_handle: usize = 0x2222;
    try ctx.bindInstance(&instance, v8_obj_handle);

    const setter = SetterCallback{
        .property_name = "id",
        .setter_fn = mockSetterFn,
    };

    var prop_info = PropertyCallbackInfo{
        .v8_ctx = ctx,
        .this_handle = v8_obj_handle,
        .return_value = null,
        .value = 0x9999, // Value being set
    };

    // Should not error
    try setter.call(&prop_info);
}

test "MethodCallback calls WebIDL method with arguments" {
    const ctx = try V8Context.init(testing.allocator);
    defer ctx.deinit();

    var instance = Instance{
        .vtable = undefined,
        .state = null,
        .ctx = null,
    };

    const v8_obj_handle: usize = 0x3333;
    try ctx.bindInstance(&instance, v8_obj_handle);

    const method = MethodCallback{
        .method_name = "getAttribute",
        .method_fn = mockMethodFn,
    };

    const args = [_]usize{0x4444}; // Mock argument
    var callback_info = CallbackInfo{
        .v8_ctx = ctx,
        .this_handle = v8_obj_handle,
        .args = &args,
        .return_value = null,
    };

    try method.call(&callback_info);

    // Verify return value
    try testing.expectEqual(@as(?usize, 0xABCDEF), callback_info.return_value);
}

test "CallbackInfo getArg returns correct argument" {
    const ctx = try V8Context.init(testing.allocator);
    defer ctx.deinit();

    const args = [_]usize{ 0x1111, 0x2222, 0x3333 };
    const info = CallbackInfo{
        .v8_ctx = ctx,
        .this_handle = null,
        .args = &args,
        .return_value = null,
    };

    try testing.expectEqual(@as(?usize, 0x1111), info.getArg(0));
    try testing.expectEqual(@as(?usize, 0x2222), info.getArg(1));
    try testing.expectEqual(@as(?usize, 0x3333), info.getArg(2));
    try testing.expectEqual(@as(?usize, null), info.getArg(3));
}

test "CallbackInfo argCount returns correct count" {
    const ctx = try V8Context.init(testing.allocator);
    defer ctx.deinit();

    const args = [_]usize{ 0x1111, 0x2222 };
    const info = CallbackInfo{
        .v8_ctx = ctx,
        .this_handle = null,
        .args = &args,
        .return_value = null,
    };

    try testing.expectEqual(@as(usize, 2), info.argCount());
}
