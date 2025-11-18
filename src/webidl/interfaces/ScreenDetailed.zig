//! Generated from: window-management.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ScreenDetailedImpl = @import("impls").ScreenDetailed;
const Screen = @import("interfaces").Screen;

pub const ScreenDetailed = struct {
    pub const Meta = struct {
        pub const name = "ScreenDetailed";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Screen;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            availLeft: i32 = undefined,
            availTop: i32 = undefined,
            left: i32 = undefined,
            top: i32 = undefined,
            isPrimary: bool = undefined,
            isInternal: bool = undefined,
            devicePixelRatio: f32 = undefined,
            label: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ScreenDetailed, .{
        .deinit_fn = &deinit_wrapper,

        .get_availHeight = &get_availHeight,
        .get_availLeft = &get_availLeft,
        .get_availTop = &get_availTop,
        .get_availWidth = &get_availWidth,
        .get_colorDepth = &get_colorDepth,
        .get_devicePixelRatio = &get_devicePixelRatio,
        .get_height = &get_height,
        .get_isExtended = &get_isExtended,
        .get_isInternal = &get_isInternal,
        .get_isPrimary = &get_isPrimary,
        .get_label = &get_label,
        .get_left = &get_left,
        .get_onchange = &get_onchange,
        .get_orientation = &get_orientation,
        .get_pixelDepth = &get_pixelDepth,
        .get_top = &get_top,
        .get_width = &get_width,

        .set_onchange = &set_onchange,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        ScreenDetailedImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ScreenDetailedImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_availWidth(instance: *runtime.Instance) anyerror!i32 {
        return try ScreenDetailedImpl.get_availWidth(instance);
    }

    pub fn get_availHeight(instance: *runtime.Instance) anyerror!i32 {
        return try ScreenDetailedImpl.get_availHeight(instance);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!i32 {
        return try ScreenDetailedImpl.get_width(instance);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!i32 {
        return try ScreenDetailedImpl.get_height(instance);
    }

    pub fn get_colorDepth(instance: *runtime.Instance) anyerror!u32 {
        return try ScreenDetailedImpl.get_colorDepth(instance);
    }

    pub fn get_pixelDepth(instance: *runtime.Instance) anyerror!u32 {
        return try ScreenDetailedImpl.get_pixelDepth(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_isExtended(instance: *runtime.Instance) anyerror!bool {
        return try ScreenDetailedImpl.get_isExtended(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try ScreenDetailedImpl.get_onchange(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ScreenDetailedImpl.set_onchange(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_orientation(instance: *runtime.Instance) anyerror!ScreenOrientation {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_orientation) |cached| {
            return cached;
        }
        const value = try ScreenDetailedImpl.get_orientation(instance);
        state.cached_orientation = value;
        return value;
    }

    pub fn get_availLeft(instance: *runtime.Instance) anyerror!i32 {
        return try ScreenDetailedImpl.get_availLeft(instance);
    }

    pub fn get_availTop(instance: *runtime.Instance) anyerror!i32 {
        return try ScreenDetailedImpl.get_availTop(instance);
    }

    pub fn get_left(instance: *runtime.Instance) anyerror!i32 {
        return try ScreenDetailedImpl.get_left(instance);
    }

    pub fn get_top(instance: *runtime.Instance) anyerror!i32 {
        return try ScreenDetailedImpl.get_top(instance);
    }

    pub fn get_isPrimary(instance: *runtime.Instance) anyerror!bool {
        return try ScreenDetailedImpl.get_isPrimary(instance);
    }

    pub fn get_isInternal(instance: *runtime.Instance) anyerror!bool {
        return try ScreenDetailedImpl.get_isInternal(instance);
    }

    pub fn get_devicePixelRatio(instance: *runtime.Instance) anyerror!f32 {
        return try ScreenDetailedImpl.get_devicePixelRatio(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!DOMString {
        return try ScreenDetailedImpl.get_label(instance);
    }

};
