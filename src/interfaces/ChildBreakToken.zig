//! Generated from: css-layout-api.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ChildBreakTokenImpl = @import("../impls/ChildBreakToken.zig");

pub const ChildBreakToken = struct {
    pub const Meta = struct {
        pub const name = "ChildBreakToken";
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
            breakType: BreakType = undefined,
            child: LayoutChild = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ChildBreakToken, .{
        .deinit_fn = &deinit_wrapper,

        .get_breakType = &get_breakType,
        .get_child = &get_child,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        ChildBreakTokenImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ChildBreakTokenImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_breakType(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ChildBreakTokenImpl.get_breakType(state);
    }

    pub fn get_child(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ChildBreakTokenImpl.get_child(state);
    }

};
