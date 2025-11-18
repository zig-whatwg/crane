//! Generated from: layout-instability.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const LayoutShiftAttributionImpl = @import("../impls/LayoutShiftAttribution.zig");

pub const LayoutShiftAttribution = struct {
    pub const Meta = struct {
        pub const name = "LayoutShiftAttribution";
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
        struct {
            node: ?Node = null,
            previousRect: DOMRectReadOnly = undefined,
            currentRect: DOMRectReadOnly = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(LayoutShiftAttribution, .{
        .deinit_fn = &deinit_wrapper,

        .get_currentRect = &get_currentRect,
        .get_node = &get_node,
        .get_previousRect = &get_previousRect,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        LayoutShiftAttributionImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        LayoutShiftAttributionImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_node(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return LayoutShiftAttributionImpl.get_node(state);
    }

    pub fn get_previousRect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return LayoutShiftAttributionImpl.get_previousRect(state);
    }

    pub fn get_currentRect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return LayoutShiftAttributionImpl.get_currentRect(state);
    }

};
