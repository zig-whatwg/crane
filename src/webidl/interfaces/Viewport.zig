//! Generated from: css-viewport.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ViewportImpl = @import("impls").Viewport;
const DOMRect = @import("interfaces").DOMRect;

pub const Viewport = struct {
    pub const Meta = struct {
        pub const name = "Viewport";
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
            segments: ?runtime.FrozenArray(DOMRect) = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Viewport, .{
        .deinit_fn = &deinit_wrapper,

        .get_segments = &get_segments,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return ViewportImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ViewportImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_segments(instance: *runtime.Instance) anyerror!anyopaque {
        return try ViewportImpl.get_segments(instance);
    }

};
