//! Generated from: css-layout-api.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BreakTokenImpl = @import("impls").BreakToken;
const ChildBreakToken = @import("interfaces").ChildBreakToken;

pub const BreakToken = struct {
    pub const Meta = struct {
        pub const name = "BreakToken";
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
            childBreakTokens: runtime.FrozenArray(ChildBreakToken) = undefined,
            data: anyopaque = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(BreakToken, .{
        .deinit_fn = &deinit_wrapper,

        .get_childBreakTokens = &get_childBreakTokens,
        .get_data = &get_data,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return BreakTokenImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BreakTokenImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_childBreakTokens(instance: *runtime.Instance) anyerror!anyopaque {
        return try BreakTokenImpl.get_childBreakTokens(instance);
    }

    pub fn get_data(instance: *runtime.Instance) anyerror!anyopaque {
        return try BreakTokenImpl.get_data(instance);
    }

};
