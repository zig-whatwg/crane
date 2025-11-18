//! Generated from: webxr.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRViewportImpl = @import("../impls/XRViewport.zig");

pub const XRViewport = struct {
    pub const Meta = struct {
        pub const name = "XRViewport";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            x: i32 = undefined,
            y: i32 = undefined,
            width: i32 = undefined,
            height: i32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRViewport, .{
        .deinit_fn = &deinit_wrapper,

        .get_height = &get_height,
        .get_width = &get_width,
        .get_x = &get_x,
        .get_y = &get_y,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        XRViewportImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        XRViewportImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_x(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return XRViewportImpl.get_x(state);
    }

    pub fn get_y(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return XRViewportImpl.get_y(state);
    }

    pub fn get_width(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return XRViewportImpl.get_width(state);
    }

    pub fn get_height(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return XRViewportImpl.get_height(state);
    }

};
