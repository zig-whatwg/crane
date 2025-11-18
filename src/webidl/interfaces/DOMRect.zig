//! Generated from: geometry.idl
//! Generated at: 2025-11-18T18:28:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DOMRectImpl = @import("impls").DOMRect;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const DOMRectInit = @import("dictionaries").DOMRectInit;

pub const DOMRect = struct {
    pub const Meta = struct {
        pub const name = "DOMRect";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *DOMRectReadOnly;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Serializable" },
            .{ .name = "LegacyWindowAlias", .value = .{ .identifier = "SVGRect" } },
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
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(DOMRect, .{
        .deinit_fn = &deinit_wrapper,

        .get_bottom = &get_bottom,
        .get_height = &get_height,
        .get_height = &get_height,
        .get_left = &get_left,
        .get_right = &get_right,
        .get_top = &get_top,
        .get_width = &get_width,
        .get_width = &get_width,
        .get_x = &get_x,
        .get_x = &get_x,
        .get_y = &get_y,
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
        DOMRectImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DOMRectImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, x: f64, y: f64, width: f64, height: f64) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try DOMRectImpl.constructor(instance, x, y, width, height);
        
        return instance;
    }

    pub fn get_x(instance: *runtime.Instance) anyerror!f64 {
        return try DOMRectImpl.get_x(instance);
    }

    pub fn get_y(instance: *runtime.Instance) anyerror!f64 {
        return try DOMRectImpl.get_y(instance);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!f64 {
        return try DOMRectImpl.get_width(instance);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!f64 {
        return try DOMRectImpl.get_height(instance);
    }

    pub fn get_top(instance: *runtime.Instance) anyerror!f64 {
        return try DOMRectImpl.get_top(instance);
    }

    pub fn get_right(instance: *runtime.Instance) anyerror!f64 {
        return try DOMRectImpl.get_right(instance);
    }

    pub fn get_bottom(instance: *runtime.Instance) anyerror!f64 {
        return try DOMRectImpl.get_bottom(instance);
    }

    pub fn get_left(instance: *runtime.Instance) anyerror!f64 {
        return try DOMRectImpl.get_left(instance);
    }

    pub fn get_x(instance: *runtime.Instance) anyerror!f64 {
        return try DOMRectImpl.get_x(instance);
    }

    pub fn get_y(instance: *runtime.Instance) anyerror!f64 {
        return try DOMRectImpl.get_y(instance);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!f64 {
        return try DOMRectImpl.get_width(instance);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!f64 {
        return try DOMRectImpl.get_height(instance);
    }

    /// Arguments for fromRect (WebIDL overloading)
    pub const FromRectArgs = union(enum) {
        /// fromRect(other)
        DOMRectInit: DOMRectInit,
        /// fromRect(other)
        DOMRectInit: DOMRectInit,
    };

    pub fn call_fromRect(instance: *runtime.Instance, args: FromRectArgs) anyerror!DOMRectReadOnly {
        switch (args) {
            .DOMRectInit => |arg| return try DOMRectImpl.DOMRectInit(instance, arg),
            .DOMRectInit => |arg| return try DOMRectImpl.DOMRectInit(instance, arg),
        }
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!anyopaque {
        return try DOMRectImpl.call_toJSON(instance);
    }

};
