//! Generated from: DOM-Style.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RGBColorImpl = @import("../impls/RGBColor.zig");

pub const RGBColor = struct {
    pub const Meta = struct {
        pub const name = "RGBColor";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            red: CSSPrimitiveValue = undefined,
            green: CSSPrimitiveValue = undefined,
            blue: CSSPrimitiveValue = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RGBColor, .{
        .deinit_fn = &deinit_wrapper,

        .get_blue = &get_blue,
        .get_green = &get_green,
        .get_red = &get_red,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        RGBColorImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        RGBColorImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_red(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RGBColorImpl.get_red(state);
    }

    pub fn get_green(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RGBColorImpl.get_green(state);
    }

    pub fn get_blue(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RGBColorImpl.get_blue(state);
    }

};
