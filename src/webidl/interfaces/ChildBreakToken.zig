//! Generated from: css-layout-api.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ChildBreakTokenImpl = @import("impls").ChildBreakToken;
const BreakType = @import("enums").BreakType;
const LayoutChild = @import("interfaces").LayoutChild;

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
        
        // Initialize the instance (Impl receives full instance)
        ChildBreakTokenImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ChildBreakTokenImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_breakType(instance: *runtime.Instance) anyerror!BreakType {
        return try ChildBreakTokenImpl.get_breakType(instance);
    }

    pub fn get_child(instance: *runtime.Instance) anyerror!LayoutChild {
        return try ChildBreakTokenImpl.get_child(instance);
    }

};
