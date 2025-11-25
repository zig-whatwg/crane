//! Generated from: shared-storage.idl
//! Generated at: 2025-11-25T13:07:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SharedStorageWorkletGlobalScopeImpl = @import("impls").SharedStorageWorkletGlobalScope;
const WorkletGlobalScope = @import("interfaces").WorkletGlobalScope;
const Function = @import("callbacks").Function;
const SharedStorageWorkletNavigator = @import("interfaces").SharedStorageWorkletNavigator;
const DOMString = @import("typedefs").DOMString;
const SharedStorage = @import("interfaces").SharedStorage;
const PrivateAggregation = @import("interfaces").PrivateAggregation;

pub const SharedStorageWorkletGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "SharedStorageWorkletGlobalScope";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *WorkletGlobalScope;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "SharedStorageWorklet" } },
            .{ .name = "Global", .value = .{ .identifier = "SharedStorageWorklet" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .SharedStorageWorklet = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "sharedStorage", "get_sharedStorage", null },
            .{ "privateAggregation", "get_privateAggregation", null },
            .{ "navigator", "get_navigator", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "register", "call_register", 2 },
            .{ "interestGroups", "call_interestGroups", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "register",
            "interestGroups",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "sharedStorage", "get_sharedStorage", null },
            .{ "privateAggregation", "get_privateAggregation", null },
            .{ "navigator", "get_navigator", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            sharedStorage: *runtime.Instance = undefined,
            privateAggregation: *runtime.Instance = undefined,
            navigator: *runtime.Instance = undefined,
            _internal: ?*SharedStorageWorkletGlobalScopeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_navigator = &get_navigator,
        .get_privateAggregation = &get_privateAggregation,
        .get_sharedStorage = &get_sharedStorage,

        .call_interestGroups = &call_interestGroups,
        .call_register = &call_register,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SharedStorageWorkletGlobalScopeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SharedStorageWorkletGlobalScopeImpl.deinit(instance);
    }

    pub fn get_sharedStorage(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SharedStorageWorkletGlobalScopeImpl.get_sharedStorage(instance);
    }

    pub fn get_privateAggregation(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SharedStorageWorkletGlobalScopeImpl.get_privateAggregation(instance);
    }

    pub fn get_navigator(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SharedStorageWorkletGlobalScopeImpl.get_navigator(instance);
    }

    pub fn call_interestGroups(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try SharedStorageWorkletGlobalScopeImpl.call_interestGroups(instance);
    }

    pub fn call_register(instance: *runtime.Instance, name: DOMString, operationCtor: Function) anyerror!void {
        
        return try SharedStorageWorkletGlobalScopeImpl.call_register(instance, name, operationCtor);
    }

};
