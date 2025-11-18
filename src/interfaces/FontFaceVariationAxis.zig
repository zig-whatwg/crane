//! Generated from: css-font-loading.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FontFaceVariationAxisImpl = @import("../impls/FontFaceVariationAxis.zig");

pub const FontFaceVariationAxis = struct {
    pub const Meta = struct {
        pub const name = "FontFaceVariationAxis";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            name: runtime.DOMString = undefined,
            axisTag: runtime.DOMString = undefined,
            minimumValue: f64 = undefined,
            maximumValue: f64 = undefined,
            defaultValue: f64 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(FontFaceVariationAxis, .{
        .deinit_fn = &deinit_wrapper,

        .get_axisTag = &get_axisTag,
        .get_defaultValue = &get_defaultValue,
        .get_maximumValue = &get_maximumValue,
        .get_minimumValue = &get_minimumValue,
        .get_name = &get_name,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        FontFaceVariationAxisImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        FontFaceVariationAxisImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return FontFaceVariationAxisImpl.get_name(state);
    }

    pub fn get_axisTag(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return FontFaceVariationAxisImpl.get_axisTag(state);
    }

    pub fn get_minimumValue(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return FontFaceVariationAxisImpl.get_minimumValue(state);
    }

    pub fn get_maximumValue(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return FontFaceVariationAxisImpl.get_maximumValue(state);
    }

    pub fn get_defaultValue(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return FontFaceVariationAxisImpl.get_defaultValue(state);
    }

};
