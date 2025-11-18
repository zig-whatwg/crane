//! Generated from: cssom-view.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ScreenImpl = @import("../impls/Screen.zig");

pub const Screen = struct {
    pub const Meta = struct {
        pub const name = "Screen";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            availWidth: i32 = undefined,
            availHeight: i32 = undefined,
            width: i32 = undefined,
            height: i32 = undefined,
            colorDepth: u32 = undefined,
            pixelDepth: u32 = undefined,
            isExtended: bool = undefined,
            onchange: EventHandler = undefined,
            orientation: ScreenOrientation = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Screen, .{
        .deinit_fn = &deinit_wrapper,

        .get_availHeight = &get_availHeight,
        .get_availWidth = &get_availWidth,
        .get_colorDepth = &get_colorDepth,
        .get_height = &get_height,
        .get_isExtended = &get_isExtended,
        .get_onchange = &get_onchange,
        .get_orientation = &get_orientation,
        .get_pixelDepth = &get_pixelDepth,
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
        ScreenImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ScreenImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_availWidth(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return ScreenImpl.get_availWidth(state);
    }

    pub fn get_availHeight(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return ScreenImpl.get_availHeight(state);
    }

    pub fn get_width(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return ScreenImpl.get_width(state);
    }

    pub fn get_height(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return ScreenImpl.get_height(state);
    }

    pub fn get_colorDepth(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return ScreenImpl.get_colorDepth(state);
    }

    pub fn get_pixelDepth(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return ScreenImpl.get_pixelDepth(state);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_isExtended(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return ScreenImpl.get_isExtended(state);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_onchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ScreenImpl.get_onchange(state);
    }

    /// Extended attributes: [SecureContext]
    pub fn set_onchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ScreenImpl.set_onchange(state, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_orientation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_orientation) |cached| {
            return cached;
        }
        const value = ScreenImpl.get_orientation(state);
        state.cached_orientation = value;
        return value;
    }

};
