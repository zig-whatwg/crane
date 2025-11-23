//! Mock JavaScript Engine
//!
//! V8-like mock implementation for testing WebIDL bindings.
//! Models V8's key concepts: Isolate, Context, HandleScope, Local<T>, and Persistent<T>
//!
//! Real V8 integration would use C++ APIs, but this demonstrates the patterns.

const std = @import("std");
const runtime = @import("runtime");

/// V8 Isolate equivalent - represents an isolated JS VM instance
/// In real V8: v8::Isolate
pub const Isolate = struct {
    allocator: std.mem.Allocator,
    context: *Context,
    handle_scope: ?*HandleScope,

    pub fn create(allocator: std.mem.Allocator) !*Isolate {
        const isolate = try allocator.create(Isolate);
        const ctx = try allocator.create(Context);
        ctx.* = .{
            .isolate = isolate,
            .allocator = allocator,
            .global_object = undefined,
            .objects = .empty,
        };

        isolate.* = .{
            .allocator = allocator,
            .context = ctx,
            .handle_scope = null,
        };

        return isolate;
    }

    pub fn destroy(self: *Isolate) void {
        for (self.context.objects.items) |obj| {
            if (obj.persistent) {
                if (obj.instance.vtable.deinit) |deinit_fn| {
                    deinit_fn(obj.instance);
                }
            }
            self.allocator.destroy(obj);
        }
        self.context.objects.deinit(self.allocator);
        self.allocator.destroy(self.context);
        self.allocator.destroy(self);
    }

    pub fn getCurrentContext(self: *Isolate) *Context {
        return self.context;
    }
};

/// V8 Context equivalent - represents a JS execution context
/// In real V8: v8::Context
pub const Context = struct {
    isolate: *Isolate,
    allocator: std.mem.Allocator,
    global_object: std.StringHashMap(*ObjectHandle),
    objects: std.ArrayList(*ObjectHandle),

    pub fn asRuntimeContext(self: *Context) runtime.Context {
        return @ptrCast(self);
    }

    /// Register a global constructor (like Document, Element in window)
    pub fn setGlobalConstructor(self: *Context, name: []const u8, constructor: *ObjectHandle) !void {
        try self.global_object.put(name, constructor);
    }

    /// Get a global constructor
    pub fn getGlobalConstructor(self: *Context, name: []const u8) ?*ObjectHandle {
        return self.global_object.get(name);
    }

    /// Track an object handle
    pub fn trackObject(self: *Context, obj: *ObjectHandle) !void {
        try self.objects.append(self.allocator, obj);
    }
};

/// V8 HandleScope equivalent - manages lifetime of Local<T> handles
/// In real V8: v8::HandleScope
pub const HandleScope = struct {
    context: *Context,
    handles: std.ArrayList(*ObjectHandle),

    pub fn create(context: *Context) !*HandleScope {
        const scope = try context.allocator.create(HandleScope);
        scope.* = .{
            .context = context,
            .handles = .empty,
        };
        context.isolate.handle_scope = scope;
        return scope;
    }

    pub fn destroy(self: *HandleScope) void {
        // In real V8, this would destroy all local handles created in this scope
        // For our mock, we just track them
        for (self.handles.items) |handle| {
            if (!handle.persistent) {
                if (handle.instance.vtable.deinit) |deinit_fn| {
                    deinit_fn(handle.instance);
                }
                self.context.allocator.destroy(handle);
            }
        }
        self.handles.deinit(self.context.allocator);
        self.context.isolate.handle_scope = null;
        self.context.allocator.destroy(self);
    }
};

/// Object handle representing a WebIDL interface instance in JS
/// Combines Local<T> and Persistent<T> concepts
pub const ObjectHandle = struct {
    instance: *runtime.Instance,
    interface_name: []const u8,
    persistent: bool, // true = Persistent<T>, false = Local<T>

    /// Create a local handle (garbage collected when HandleScope exits)
    pub fn createLocal(ctx: *Context, instance: *runtime.Instance, interface_name: []const u8) !*ObjectHandle {
        const handle = try ctx.allocator.create(ObjectHandle);
        handle.* = .{
            .instance = instance,
            .interface_name = interface_name,
            .persistent = false,
        };

        if (ctx.isolate.handle_scope) |scope| {
            try scope.handles.append(ctx.allocator, handle);
        }

        return handle;
    }

    /// Create a persistent handle (survives HandleScope, manually managed)
    pub fn createPersistent(ctx: *Context, instance: *runtime.Instance, interface_name: []const u8) !*ObjectHandle {
        const handle = try ctx.allocator.create(ObjectHandle);
        handle.* = .{
            .instance = instance,
            .interface_name = interface_name,
            .persistent = true,
        };

        try ctx.trackObject(handle);

        return handle;
    }

    /// Get the underlying WebIDL instance
    pub fn unwrap(self: *ObjectHandle) *runtime.Instance {
        return self.instance;
    }
};

/// FunctionCallbackInfo - passed to C++ callbacks from JS
/// In real V8: v8::FunctionCallbackInfo<v8::Value>
pub const FunctionCallbackInfo = struct {
    context: *Context,
    this: ?*ObjectHandle,
    args: []const *ObjectHandle,
    return_value: ?*ObjectHandle,

    pub fn getContext(self: *FunctionCallbackInfo) *Context {
        return self.context;
    }

    pub fn getThis(self: *FunctionCallbackInfo) ?*ObjectHandle {
        return self.this;
    }

    pub fn getArg(self: *FunctionCallbackInfo, index: usize) ?*ObjectHandle {
        if (index >= self.args.len) return null;
        return self.args[index];
    }

    pub fn setReturnValue(self: *FunctionCallbackInfo, value: *ObjectHandle) void {
        self.return_value = value;
    }
};

/// PropertyCallbackInfo - passed to property getter/setter callbacks
/// In real V8: v8::PropertyCallbackInfo<v8::Value>
pub const PropertyCallbackInfo = struct {
    context: *Context,
    this: *ObjectHandle,
    return_value: ?*ObjectHandle,

    pub fn getThis(self: *PropertyCallbackInfo) *ObjectHandle {
        return self.this;
    }

    pub fn setReturnValue(self: *PropertyCallbackInfo, value: *ObjectHandle) void {
        self.return_value = value;
    }
};

/// FunctionTemplate - template for creating JS function constructors
/// In real V8: v8::FunctionTemplate
pub const FunctionTemplate = struct {
    name: []const u8,
    constructor: *const fn (*FunctionCallbackInfo) anyerror!void,
    prototype_properties: std.StringHashMap(PropertyDescriptor),

    pub const PropertyDescriptor = struct {
        getter: ?*const fn (*PropertyCallbackInfo) anyerror!void,
        setter: ?*const fn (*PropertyCallbackInfo, *ObjectHandle) anyerror!void,
    };

    pub fn create(allocator: std.mem.Allocator, name: []const u8, constructor: *const fn (*FunctionCallbackInfo) anyerror!void) !*FunctionTemplate {
        const template = try allocator.create(FunctionTemplate);
        template.* = .{
            .name = name,
            .constructor = constructor,
            .prototype_properties = .empty,
        };
        return template;
    }

    pub fn setProperty(
        self: *FunctionTemplate,
        name: []const u8,
        getter: ?*const fn (*PropertyCallbackInfo) anyerror!void,
        setter: ?*const fn (*PropertyCallbackInfo, *ObjectHandle) anyerror!void,
    ) !void {
        try self.prototype_properties.put(name, .{
            .getter = getter,
            .setter = setter,
        });
    }
};

/// Value types for JS values
/// In real V8: v8::Value, v8::String, v8::Number, etc.
pub const Value = union(enum) {
    undefined,
    null_value,
    boolean: bool,
    number: f64,
    string: []const u8,
    object: *ObjectHandle,

    pub fn isObject(self: Value) bool {
        return self == .object;
    }

    pub fn isString(self: Value) bool {
        return self == .string;
    }

    pub fn asObject(self: Value) ?*ObjectHandle {
        return switch (self) {
            .object => |obj| obj,
            else => null,
        };
    }

    pub fn asString(self: Value) ?[]const u8 {
        return switch (self) {
            .string => |s| s,
            else => null,
        };
    }
};

/// Helper to create a V8-style string
/// In real V8: v8::String::NewFromUtf8()
pub fn createString(ctx: *Context, str: []const u8) !Value {
    _ = ctx;
    return Value{ .string = str };
}

/// Helper to create a V8-style number
/// In real V8: v8::Number::New()
pub fn createNumber(ctx: *Context, num: f64) Value {
    _ = ctx;
    return Value{ .number = num };
}

/// Helper to create undefined
/// In real V8: v8::Undefined()
pub fn createUndefined(ctx: *Context) Value {
    _ = ctx;
    return Value.undefined;
}
