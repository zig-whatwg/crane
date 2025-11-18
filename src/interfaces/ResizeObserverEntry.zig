//! Generated from: resize-observer.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ResizeObserverEntryImpl = @import("../impls/ResizeObserverEntry.zig");

pub const ResizeObserverEntry = struct {
    pub const Meta = struct {
        pub const name = "ResizeObserverEntry";
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
            target: Element = undefined,
            contentRect: DOMRectReadOnly = undefined,
            borderBoxSize: FrozenArray<ResizeObserverSize> = undefined,
            contentBoxSize: FrozenArray<ResizeObserverSize> = undefined,
            devicePixelContentBoxSize: FrozenArray<ResizeObserverSize> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ResizeObserverEntry, .{
        .deinit_fn = &deinit_wrapper,

        .get_borderBoxSize = &get_borderBoxSize,
        .get_contentBoxSize = &get_contentBoxSize,
        .get_contentRect = &get_contentRect,
        .get_devicePixelContentBoxSize = &get_devicePixelContentBoxSize,
        .get_target = &get_target,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        ResizeObserverEntryImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ResizeObserverEntryImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_target(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ResizeObserverEntryImpl.get_target(state);
    }

    pub fn get_contentRect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ResizeObserverEntryImpl.get_contentRect(state);
    }

    pub fn get_borderBoxSize(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ResizeObserverEntryImpl.get_borderBoxSize(state);
    }

    pub fn get_contentBoxSize(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ResizeObserverEntryImpl.get_contentBoxSize(state);
    }

    pub fn get_devicePixelContentBoxSize(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ResizeObserverEntryImpl.get_devicePixelContentBoxSize(state);
    }

};
