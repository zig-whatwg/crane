//! Generated from: DOM-Style.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RectImpl = @import("impls").Rect;
const CSSPrimitiveValue = @import("interfaces").CSSPrimitiveValue;

pub const Rect = struct {
    pub const Meta = struct {
        pub const name = "Rect";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            top: CSSPrimitiveValue = undefined,
            right: CSSPrimitiveValue = undefined,
            bottom: CSSPrimitiveValue = undefined,
            left: CSSPrimitiveValue = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Rect, .{
        .deinit_fn = &deinit_wrapper,

        .get_bottom = &get_bottom,
        .get_left = &get_left,
        .get_right = &get_right,
        .get_top = &get_top,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        RectImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RectImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_top(instance: *runtime.Instance) anyerror!CSSPrimitiveValue {
        return try RectImpl.get_top(instance);
    }

    pub fn get_right(instance: *runtime.Instance) anyerror!CSSPrimitiveValue {
        return try RectImpl.get_right(instance);
    }

    pub fn get_bottom(instance: *runtime.Instance) anyerror!CSSPrimitiveValue {
        return try RectImpl.get_bottom(instance);
    }

    pub fn get_left(instance: *runtime.Instance) anyerror!CSSPrimitiveValue {
        return try RectImpl.get_left(instance);
    }

};
