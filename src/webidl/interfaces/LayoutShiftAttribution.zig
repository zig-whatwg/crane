//! Generated from: layout-instability.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const LayoutShiftAttributionImpl = @import("impls").LayoutShiftAttribution;
const Node = @import("interfaces").Node;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;

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
        
        // Initialize the instance (Impl receives full instance)
        LayoutShiftAttributionImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        LayoutShiftAttributionImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_node(instance: *runtime.Instance) anyerror!anyopaque {
        return try LayoutShiftAttributionImpl.get_node(instance);
    }

    pub fn get_previousRect(instance: *runtime.Instance) anyerror!DOMRectReadOnly {
        return try LayoutShiftAttributionImpl.get_previousRect(instance);
    }

    pub fn get_currentRect(instance: *runtime.Instance) anyerror!DOMRectReadOnly {
        return try LayoutShiftAttributionImpl.get_currentRect(instance);
    }

};
