//! Generated from: dom.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MutationObserverImpl = @import("../impls/MutationObserver.zig");

pub const MutationObserver = struct {
    pub const Meta = struct {
        pub const name = "MutationObserver";
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

    pub const vtable = runtime.buildVTable(MutationObserver, .{
        .deinit_fn = &deinit_wrapper,

        .call_disconnect = &call_disconnect,
        .call_observe = &call_observe,
        .call_takeRecords = &call_takeRecords,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        MutationObserverImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        MutationObserverImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, callback: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try MutationObserverImpl.constructor(state, callback);
        
        return instance;
    }

    pub fn call_observe(instance: *runtime.Instance, target: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MutationObserverImpl.call_observe(state, target, options);
    }

    pub fn call_disconnect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MutationObserverImpl.call_disconnect(state);
    }

    pub fn call_takeRecords(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MutationObserverImpl.call_takeRecords(state);
    }

};
