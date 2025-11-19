//! Generated from: html.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasFiltersImpl = @import("impls").CanvasFilters;
const DOMString = @import("typedefs").DOMString;

pub const CanvasFilters = struct {
    pub const Meta = struct {
        pub const name = "CanvasFilters";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            filter: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CanvasFilters, .{
        .deinit_fn = &deinit_wrapper,

        .get_filter = &get_filter,

        .set_filter = &set_filter,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return CanvasFiltersImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasFiltersImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_filter(instance: *runtime.Instance) anyerror!DOMString {
        return try CanvasFiltersImpl.get_filter(instance);
    }

    pub fn set_filter(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CanvasFiltersImpl.set_filter(instance, value);
    }

};
