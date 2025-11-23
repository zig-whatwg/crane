//! Generated from: xhr.idl
//! Generated at: 2025-11-23T20:06:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FormDataImpl = @import("impls").FormData;
const USVString = @import("interfaces").USVString;
const Blob = @import("interfaces").Blob;
const HTMLElement = @import("interfaces").HTMLElement;
const HTMLFormElement = @import("interfaces").HTMLFormElement;
const FormDataEntryValue = @import("typedefs").FormDataEntryValue;

pub const FormData = struct {
    pub const Meta = struct {
        pub const name = "FormData";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "append", "call_append", 2 },
            .{ "append", "call_append", 2 },
            .{ "delete", "call_delete", 1 },
            .{ "get", "call_get", 1 },
            .{ "getAll", "call_getAll", 1 },
            .{ "has", "call_has", 1 },
            .{ "set", "call_set", 2 },
            .{ "set", "call_set", 2 },
            .{ "forEach", "call_forEach", 1 },
            .{ "forEach", "call_forEach", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "append",
            "append",
            "delete",
            "get",
            "getAll",
            "has",
            "set",
            "set",
            "forEach",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
        
        /// Iterable declaration (for Symbol.iterator support)
        pub const iterable = .{
            .value_type = "runtime.USVString",
            .key_type = "FormDataEntryValue",
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {},
    );

    const delegates = .{

        .call_append = &call_append,
        .call_delete = &call_delete,
        .call_forEach = &call_forEach,
        .call_get = &call_get,
        .call_getAll = &call_getAll,
        .call_has = &call_has,
        .call_set = &call_set,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FormDataImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FormDataImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, form: *runtime.Instance, submitter: *runtime.Instance) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try FormDataImpl.call_constructor(allocator, ctx, form, submitter);
    }

    pub fn call_delete(instance: *runtime.Instance, name: runtime.USVString) anyerror!void {
        
        return try FormDataImpl.call_delete(instance, name);
    }

    pub fn call_append(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) anyerror!void {
        
        return try FormDataImpl.call_append(instance, name, value);
    }

    pub fn call_getAll(instance: *runtime.Instance, name: runtime.USVString) anyerror!*const anyopaque {
        
        return try FormDataImpl.call_getAll(instance, name);
    }

    pub fn call_has(instance: *runtime.Instance, name: runtime.USVString) anyerror!bool {
        
        return try FormDataImpl.call_has(instance, name);
    }

    pub fn call_forEach(instance: *runtime.Instance, callback: *const anyopaque) anyerror!void {
        
        return try FormDataImpl.call_forEach(instance, callback);
    }

    pub fn call_set(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) anyerror!void {
        
        return try FormDataImpl.call_set(instance, name, value);
    }

    pub fn call_get(instance: *runtime.Instance, name: runtime.USVString) anyerror!FormDataEntryValue {
        
        return try FormDataImpl.call_get(instance, name);
    }

};
