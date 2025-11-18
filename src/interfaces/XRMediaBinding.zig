//! Generated from: webxrlayers.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRMediaBindingImpl = @import("../impls/XRMediaBinding.zig");

pub const XRMediaBinding = struct {
    pub const Meta = struct {
        pub const name = "XRMediaBinding";
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

    pub const vtable = runtime.buildVTable(XRMediaBinding, .{
        .deinit_fn = &deinit_wrapper,

        .call_createCylinderLayer = &call_createCylinderLayer,
        .call_createEquirectLayer = &call_createEquirectLayer,
        .call_createQuadLayer = &call_createQuadLayer,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        XRMediaBindingImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        XRMediaBindingImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, session: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try XRMediaBindingImpl.constructor(state, session);
        
        return instance;
    }

    pub fn call_createCylinderLayer(instance: *runtime.Instance, video: anyopaque, init: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRMediaBindingImpl.call_createCylinderLayer(state, video, init);
    }

    pub fn call_createQuadLayer(instance: *runtime.Instance, video: anyopaque, init: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRMediaBindingImpl.call_createQuadLayer(state, video, init);
    }

    pub fn call_createEquirectLayer(instance: *runtime.Instance, video: anyopaque, init: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRMediaBindingImpl.call_createEquirectLayer(state, video, init);
    }

};
