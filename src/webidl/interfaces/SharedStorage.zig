//! Generated from: shared-storage.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SharedStorageImpl = @import("impls").SharedStorage;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const SharedStorageRunOperationMethodOptions = @import("dictionaries").SharedStorageRunOperationMethodOptions;
const SharedStorageWorkletOptions = @import("dictionaries").SharedStorageWorkletOptions;
const SharedStorageResponse = @import("typedefs").SharedStorageResponse;
const SharedStorageSetMethodOptions = @import("dictionaries").SharedStorageSetMethodOptions;
const SharedStorageModifierMethodOptions = @import("dictionaries").SharedStorageModifierMethodOptions;
const SharedStorageModifierMethod = @import("SharedStorageModifierMethod.zig").SharedStorageModifierMethod;
const SharedStorageUrlWithMetadata = @import("dictionaries").SharedStorageUrlWithMetadata;
const SharedStorageWorklet = @import("SharedStorageWorklet.zig").SharedStorageWorklet;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const SharedStorage = struct {
    pub const Meta = struct {
        pub const name = "SharedStorage";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            .{ "values", "call_values", 0 },
            .{ "getAsyncIterator", "call_getAsyncIterator", 0 },
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
            "values",
            "getAsyncIterator",
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
        
        /// Async iterable declaration (for Symbol.asyncIterator support)
        pub const async_iterable = .{
            .value_type = "runtime.DOMString",
            .key_type = "runtime.DOMString",
            .options_type = null,
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            worklet: *runtime.Instance = undefined,
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
        .call_get = &call_get,
        .call_getAsyncIterator = &call_getAsyncIterator,
        .call_length = &call_length,
        .call_remainingBudget = &call_remainingBudget,
        .call_run = &call_run,
        .call_selectURL = &call_selectURL,
        .call_set = &call_set,
        .call_values = &call_values,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SharedStorageImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return SharedStorageImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SharedStorageImpl.deinit(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_worklet(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SharedStorageImpl.get_worklet(instance);
    }

    pub fn call_clear(instance: *runtime.Instance, options: webidl.Opt(SharedStorageModifierMethodOptions)) anyerror!runtime.JSValue {
        
        return try SharedStorageImpl.call_clear(instance, options);
    }

    pub fn call_get(instance: *runtime.Instance, key: DOMString) anyerror!runtime.JSValue {
        
        return try SharedStorageImpl.call_get(instance, key);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_selectURL(instance: *runtime.Instance, name: DOMString, urls: runtime.JSValue, options: webidl.Opt(SharedStorageRunOperationMethodOptions)) anyerror!runtime.JSValue {
        
        return try SharedStorageImpl.call_selectURL(instance, name, urls, options);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_run(instance: *runtime.Instance, name: DOMString, options: webidl.Opt(SharedStorageRunOperationMethodOptions)) anyerror!runtime.JSValue {
        
        return try SharedStorageImpl.call_run(instance, name, options);
    }

    pub fn call_append(instance: *runtime.Instance, key: DOMString, value: DOMString, options: webidl.Opt(SharedStorageModifierMethodOptions)) anyerror!runtime.JSValue {
        
        return try SharedStorageImpl.call_append(instance, key, value, options);
    }

    pub fn call_delete(instance: *runtime.Instance, key: DOMString, options: webidl.Opt(SharedStorageModifierMethodOptions)) anyerror!runtime.JSValue {
        
        return try SharedStorageImpl.call_delete(instance, key, options);
    }

    /// Extended attributes: [Exposed=SharedStorageWorklet]
    pub fn call_remainingBudget(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try SharedStorageImpl.call_remainingBudget(instance);
    }

    /// Extended attributes: [Exposed=SharedStorageWorklet]
    pub fn call_length(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try SharedStorageImpl.call_length(instance);
    }

    pub fn call_batchUpdate(instance: *runtime.Instance, methods: runtime.JSValue, options: webidl.Opt(SharedStorageModifierMethodOptions)) anyerror!runtime.JSValue {
        
        return try SharedStorageImpl.call_batchUpdate(instance, methods, options);
    }

    pub fn call_values(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try SharedStorageImpl.call_values(instance);
    }

    pub fn call_set(instance: *runtime.Instance, key: DOMString, value: DOMString, options: webidl.Opt(SharedStorageSetMethodOptions)) anyerror!runtime.JSValue {
        
        return try SharedStorageImpl.call_set(instance, key, value, options);
    }

    pub fn call_getAsyncIterator(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try SharedStorageImpl.call_getAsyncIterator(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_createWorklet(instance: *runtime.Instance, moduleURL: runtime.USVString, options: webidl.Opt(SharedStorageWorkletOptions)) anyerror!runtime.JSValue {
        
        return try SharedStorageImpl.call_createWorklet(instance, moduleURL, options);
    }

};
