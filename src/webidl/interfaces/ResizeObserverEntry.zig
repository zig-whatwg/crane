//! Generated from: resize-observer.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ResizeObserverEntryImpl = @import("impls").ResizeObserverEntry;
const Element = @import("interfaces").Element;
const FrozenArray<ResizeObserverSize> = @import("interfaces").FrozenArray<ResizeObserverSize>;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;

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
        
        // Initialize the instance (Impl receives full instance)
        ResizeObserverEntryImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ResizeObserverEntryImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_target(instance: *runtime.Instance) anyerror!Element {
        return try ResizeObserverEntryImpl.get_target(instance);
    }

    pub fn get_contentRect(instance: *runtime.Instance) anyerror!DOMRectReadOnly {
        return try ResizeObserverEntryImpl.get_contentRect(instance);
    }

    pub fn get_borderBoxSize(instance: *runtime.Instance) anyerror!anyopaque {
        return try ResizeObserverEntryImpl.get_borderBoxSize(instance);
    }

    pub fn get_contentBoxSize(instance: *runtime.Instance) anyerror!anyopaque {
        return try ResizeObserverEntryImpl.get_contentBoxSize(instance);
    }

    pub fn get_devicePixelContentBoxSize(instance: *runtime.Instance) anyerror!anyopaque {
        return try ResizeObserverEntryImpl.get_devicePixelContentBoxSize(instance);
    }

};
