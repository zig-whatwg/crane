//! Generated from: shared-storage.idl
//! Generated at: 2025-11-23T19:17:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SharedStorageImpl = @import("impls").SharedStorage;
const SharedStorageRunOperationMethodOptions = @import("dictionaries").SharedStorageRunOperationMethodOptions;
const SharedStorageWorkletOptions = @import("dictionaries").SharedStorageWorkletOptions;
const SharedStorageResponse = @import("typedefs").SharedStorageResponse;
const SharedStorageSetMethodOptions = @import("dictionaries").SharedStorageSetMethodOptions;
const SharedStorageModifierMethodOptions = @import("dictionaries").SharedStorageModifierMethodOptions;
const SharedStorageModifierMethod = @import("interfaces").SharedStorageModifierMethod;
const unsignedlong = @import("interfaces").unsignedlong;
const SharedStorageUrlWithMetadata = @import("dictionaries").SharedStorageUrlWithMetadata;
const SharedStorageWorklet = @import("interfaces").SharedStorageWorklet;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const SharedStorage = struct {
    pub const Meta = struct {
        pub const name = "SharedStorage";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "SharedStorageWorklet" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .SharedStorageWorklet = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "worklet", "get_worklet", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "get", "call_get", 1 },
            .{ "set", "call_set", 2 },
            .{ "append", "call_append", 2 },
            .{ "delete", "call_delete", 1 },
            .{ "clear", "call_clear", 0 },
            .{ "batchUpdate", "call_batchUpdate", 1 },
            .{ "selectURL", "call_selectURL", 2 },
            .{ "run", "call_run", 1 },
            .{ "createWorklet", "call_createWorklet", 1 },
            .{ "length", "call_length", 0 },
            .{ "remainingBudget", "call_remainingBudget", 0 },
            .{ "forEach", "call_forEach", 1 },
            .{ "forEach", "call_forEach", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "get",
            "set",
            "append",
            "delete",
            "clear",
            "batchUpdate",
            "selectURL",
            "run",
            "createWorklet",
            "length",
            "remainingBudget",
            "forEach",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "worklet", "get_worklet", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
        
        /// Iterable declaration (for Symbol.iterator support)
        pub const iterable = .{
            .value_type = "runtime.DOMString",
            .key_type = "runtime.DOMString",
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            worklet: SharedStorageWorklet = undefined,
            _internal: ?*SharedStorageImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_worklet = &get_worklet,

        .call_append = &call_append,
        .call_batchUpdate = &call_batchUpdate,
        .call_clear = &call_clear,
        .call_createWorklet = &call_createWorklet,
        .call_delete = &call_delete,
        .call_forEach = &call_forEach,
        .call_get = &call_get,
        .call_length = &call_length,
        .call_remainingBudget = &call_remainingBudget,
        .call_run = &call_run,
        .call_selectURL = &call_selectURL,
        .call_set = &call_set,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SharedStorageImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SharedStorageImpl.deinit(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_worklet(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SharedStorageImpl.get_worklet(instance);
    }

    pub fn call_delete(instance: *runtime.Instance, key: DOMString, options: SharedStorageModifierMethodOptions) anyerror!*const anyopaque {
        
        return try SharedStorageImpl.call_delete(instance, key, options);
    }

    pub fn call_append(instance: *runtime.Instance, key: DOMString, value: DOMString, options: SharedStorageModifierMethodOptions) anyerror!*const anyopaque {
        
        return try SharedStorageImpl.call_append(instance, key, value, options);
    }

    pub fn call_batchUpdate(instance: *runtime.Instance, methods: *const anyopaque, options: SharedStorageModifierMethodOptions) anyerror!*const anyopaque {
        
        return try SharedStorageImpl.call_batchUpdate(instance, methods, options);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_run(instance: *runtime.Instance, name: DOMString, options: SharedStorageRunOperationMethodOptions) anyerror!*const anyopaque {
        
        return try SharedStorageImpl.call_run(instance, name, options);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_createWorklet(instance: *runtime.Instance, moduleURL: runtime.USVString, options: SharedStorageWorkletOptions) anyerror!*const anyopaque {
        
        return try SharedStorageImpl.call_createWorklet(instance, moduleURL, options);
    }

    pub fn call_set(instance: *runtime.Instance, key: DOMString, value: DOMString, options: SharedStorageSetMethodOptions) anyerror!*const anyopaque {
        
        return try SharedStorageImpl.call_set(instance, key, value, options);
    }

    /// Extended attributes: [Exposed=SharedStorageWorklet]
    pub fn call_length(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try SharedStorageImpl.call_length(instance);
    }

    /// Extended attributes: [Exposed=SharedStorageWorklet]
    pub fn call_remainingBudget(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try SharedStorageImpl.call_remainingBudget(instance);
    }

    pub fn call_forEach(instance: *runtime.Instance, callback: *const anyopaque) anyerror!void {
        
        return try SharedStorageImpl.call_forEach(instance, callback);
    }

    pub fn call_get(instance: *runtime.Instance, key: DOMString) anyerror!*const anyopaque {
        
        return try SharedStorageImpl.call_get(instance, key);
    }

    pub fn call_clear(instance: *runtime.Instance, options: SharedStorageModifierMethodOptions) anyerror!*const anyopaque {
        
        return try SharedStorageImpl.call_clear(instance, options);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_selectURL(instance: *runtime.Instance, name: DOMString, urls: *const anyopaque, options: SharedStorageRunOperationMethodOptions) anyerror!*const anyopaque {
        
        return try SharedStorageImpl.call_selectURL(instance, name, urls, options);
    }

};
