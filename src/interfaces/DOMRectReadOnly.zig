//! Generated from: geometry.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DOMRectReadOnlyImpl = @import("../impls/DOMRectReadOnly.zig");

pub const DOMRectReadOnly = struct {
    pub const Meta = struct {
        pub const name = "DOMRectReadOnly";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Serializable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            x: f64 = undefined,
            y: f64 = undefined,
            width: f64 = undefined,
            height: f64 = undefined,
            top: f64 = undefined,
            right: f64 = undefined,
            bottom: f64 = undefined,
            left: f64 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(DOMRectReadOnly, .{
        .deinit_fn = &deinit_wrapper,

        .get_bottom = &get_bottom,
        .get_height = &get_height,
        .get_left = &get_left,
        .get_right = &get_right,
        .get_top = &get_top,
        .get_width = &get_width,
        .get_x = &get_x,
        .get_y = &get_y,

        .call_fromRect = &call_fromRect,
        .call_toJSON = &call_toJSON,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        DOMRectReadOnlyImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        DOMRectReadOnlyImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, x: f64, y: f64, width: f64, height: f64) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try DOMRectReadOnlyImpl.constructor(state, x, y, width, height);
        
        return instance;
    }

    pub fn get_x(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return DOMRectReadOnlyImpl.get_x(state);
    }

    pub fn get_y(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return DOMRectReadOnlyImpl.get_y(state);
    }

    pub fn get_width(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return DOMRectReadOnlyImpl.get_width(state);
    }

    pub fn get_height(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return DOMRectReadOnlyImpl.get_height(state);
    }

    pub fn get_top(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return DOMRectReadOnlyImpl.get_top(state);
    }

    pub fn get_right(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return DOMRectReadOnlyImpl.get_right(state);
    }

    pub fn get_bottom(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return DOMRectReadOnlyImpl.get_bottom(state);
    }

    pub fn get_left(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return DOMRectReadOnlyImpl.get_left(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_fromRect(instance: *runtime.Instance, other: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return DOMRectReadOnlyImpl.call_fromRect(state, other);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DOMRectReadOnlyImpl.call_toJSON(state);
    }

};
