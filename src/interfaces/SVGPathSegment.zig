//! Generated from: svg-paths.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGPathSegmentImpl = @import("../impls/SVGPathSegment.zig");

pub const SVGPathSegment = struct {
    pub const Meta = struct {
        pub const name = "SVGPathSegment";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "NoInterfaceObject" },
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            type: runtime.DOMString = undefined,
            values: sequence = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SVGPathSegment, .{
        .deinit_fn = &deinit_wrapper,

        .get_type = &get_type,
        .get_values = &get_values,

        .set_type = &set_type,
        .set_values = &set_values,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        SVGPathSegmentImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SVGPathSegmentImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return SVGPathSegmentImpl.get_type(state);
    }

    pub fn set_type(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        SVGPathSegmentImpl.set_type(state, value);
    }

    pub fn get_values(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SVGPathSegmentImpl.get_values(state);
    }

    pub fn set_values(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SVGPathSegmentImpl.set_values(state, value);
    }

};
