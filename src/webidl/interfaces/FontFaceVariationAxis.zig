//! Generated from: css-font-loading.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FontFaceVariationAxisImpl = @import("impls").FontFaceVariationAxis;

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
        
        // Initialize the instance (Impl receives full instance)
        FontFaceVariationAxisImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FontFaceVariationAxisImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try FontFaceVariationAxisImpl.get_name(instance);
    }

    pub fn get_axisTag(instance: *runtime.Instance) anyerror!DOMString {
        return try FontFaceVariationAxisImpl.get_axisTag(instance);
    }

    pub fn get_minimumValue(instance: *runtime.Instance) anyerror!f64 {
        return try FontFaceVariationAxisImpl.get_minimumValue(instance);
    }

    pub fn get_maximumValue(instance: *runtime.Instance) anyerror!f64 {
        return try FontFaceVariationAxisImpl.get_maximumValue(instance);
    }

    pub fn get_defaultValue(instance: *runtime.Instance) anyerror!f64 {
        return try FontFaceVariationAxisImpl.get_defaultValue(instance);
    }

};
