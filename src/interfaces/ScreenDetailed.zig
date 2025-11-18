//! Generated from: window-management.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ScreenDetailedImpl = @import("../impls/ScreenDetailed.zig");
const Screen = @import("Screen.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        ScreenDetailedImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ScreenDetailedImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_availWidth(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return ScreenDetailedImpl.get_availWidth(state);
    }

    pub fn get_availHeight(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return ScreenDetailedImpl.get_availHeight(state);
    }

    pub fn get_width(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return ScreenDetailedImpl.get_width(state);
    }

    pub fn get_height(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return ScreenDetailedImpl.get_height(state);
    }

    pub fn get_colorDepth(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return ScreenDetailedImpl.get_colorDepth(state);
    }

    pub fn get_pixelDepth(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return ScreenDetailedImpl.get_pixelDepth(state);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_isExtended(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return ScreenDetailedImpl.get_isExtended(state);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_onchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ScreenDetailedImpl.get_onchange(state);
    }

    /// Extended attributes: [SecureContext]
    pub fn set_onchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ScreenDetailedImpl.set_onchange(state, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_orientation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_orientation) |cached| {
            return cached;
        }
        const value = ScreenDetailedImpl.get_orientation(state);
        state.cached_orientation = value;
        return value;
    }

    pub fn get_availLeft(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return ScreenDetailedImpl.get_availLeft(state);
    }

    pub fn get_availTop(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return ScreenDetailedImpl.get_availTop(state);
    }

    pub fn get_left(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return ScreenDetailedImpl.get_left(state);
    }

    pub fn get_top(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return ScreenDetailedImpl.get_top(state);
    }

    pub fn get_isPrimary(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return ScreenDetailedImpl.get_isPrimary(state);
    }

    pub fn get_isInternal(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return ScreenDetailedImpl.get_isInternal(state);
    }

    pub fn get_devicePixelRatio(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return ScreenDetailedImpl.get_devicePixelRatio(state);
    }

    pub fn get_label(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return ScreenDetailedImpl.get_label(state);
    }

};
