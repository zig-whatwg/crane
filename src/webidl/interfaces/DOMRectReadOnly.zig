//! Generated from: geometry.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DOMRectReadOnlyImpl = @import("impls").DOMRectReadOnly;
const DOMRectInit = @import("dictionaries").DOMRectInit;

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
        
        // Initialize the instance (Impl receives full instance)
        DOMRectReadOnlyImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DOMRectReadOnlyImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, x: f64, y: f64, width: f64, height: f64) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try DOMRectReadOnlyImpl.constructor(instance, x, y, width, height);
        
        return instance;
    }

    pub fn get_x(instance: *runtime.Instance) anyerror!f64 {
        return try DOMRectReadOnlyImpl.get_x(instance);
    }

    pub fn get_y(instance: *runtime.Instance) anyerror!f64 {
        return try DOMRectReadOnlyImpl.get_y(instance);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!f64 {
        return try DOMRectReadOnlyImpl.get_width(instance);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!f64 {
        return try DOMRectReadOnlyImpl.get_height(instance);
    }

    pub fn get_top(instance: *runtime.Instance) anyerror!f64 {
        return try DOMRectReadOnlyImpl.get_top(instance);
    }

    pub fn get_right(instance: *runtime.Instance) anyerror!f64 {
        return try DOMRectReadOnlyImpl.get_right(instance);
    }

    pub fn get_bottom(instance: *runtime.Instance) anyerror!f64 {
        return try DOMRectReadOnlyImpl.get_bottom(instance);
    }

    pub fn get_left(instance: *runtime.Instance) anyerror!f64 {
        return try DOMRectReadOnlyImpl.get_left(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_fromRect(instance: *runtime.Instance, other: DOMRectInit) anyerror!DOMRectReadOnly {
        // [NewObject] - Caller owns the returned object
        
        return try DOMRectReadOnlyImpl.call_fromRect(instance, other);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!anyopaque {
        return try DOMRectReadOnlyImpl.call_toJSON(instance);
    }

};
