//! Generated from: css-layout-api.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const LayoutChildImpl = @import("../impls/LayoutChild.zig");

pub const LayoutChild = struct {
    pub const Meta = struct {
        pub const name = "LayoutChild";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "LayoutWorklet" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .LayoutWorklet = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            styleMap: StylePropertyMapReadOnly = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(LayoutChild, .{
        .deinit_fn = &deinit_wrapper,

        .get_styleMap = &get_styleMap,

        .call_intrinsicSizes = &call_intrinsicSizes,
        .call_layoutNextFragment = &call_layoutNextFragment,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        LayoutChildImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        LayoutChildImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_styleMap(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return LayoutChildImpl.get_styleMap(state);
    }

    pub fn call_intrinsicSizes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return LayoutChildImpl.call_intrinsicSizes(state);
    }

    pub fn call_layoutNextFragment(instance: *runtime.Instance, constraints: anyopaque, breakToken: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return LayoutChildImpl.call_layoutNextFragment(state, constraints, breakToken);
    }

};
