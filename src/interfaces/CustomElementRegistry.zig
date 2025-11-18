//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CustomElementRegistryImpl = @import("../impls/CustomElementRegistry.zig");

pub const CustomElementRegistry = struct {
    pub const Meta = struct {
        pub const name = "CustomElementRegistry";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CustomElementRegistry, .{
        .deinit_fn = &deinit_wrapper,

        .call_define = &call_define,
        .call_get = &call_get,
        .call_getName = &call_getName,
        .call_initialize = &call_initialize,
        .call_upgrade = &call_upgrade,
        .call_whenDefined = &call_whenDefined,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CustomElementRegistryImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CustomElementRegistryImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try CustomElementRegistryImpl.constructor(state);
        
        return instance;
    }

    /// Extended attributes: [CEReactions]
    pub fn call_define(instance: *runtime.Instance, name: runtime.DOMString, constructor: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return CustomElementRegistryImpl.call_define(state, name, constructor, options);
    }

    pub fn call_get(instance: *runtime.Instance, name: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return CustomElementRegistryImpl.call_get(state, name);
    }

    pub fn call_getName(instance: *runtime.Instance, constructor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CustomElementRegistryImpl.call_getName(state, constructor);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_upgrade(instance: *runtime.Instance, root: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return CustomElementRegistryImpl.call_upgrade(state, root);
    }

    pub fn call_initialize(instance: *runtime.Instance, root: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CustomElementRegistryImpl.call_initialize(state, root);
    }

    pub fn call_whenDefined(instance: *runtime.Instance, name: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return CustomElementRegistryImpl.call_whenDefined(state, name);
    }

};
