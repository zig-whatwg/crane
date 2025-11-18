//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const OffscreenCanvasImpl = @import("../impls/OffscreenCanvas.zig");
const EventTarget = @import("EventTarget.zig");

pub const OffscreenCanvas = struct {
    pub const Meta = struct {
        pub const name = "OffscreenCanvas";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Transferable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            width: u64 = undefined,
            height: u64 = undefined,
            oncontextlost: EventHandler = undefined,
            oncontextrestored: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(OffscreenCanvas, .{
        .deinit_fn = &deinit_wrapper,

        .get_height = &get_height,
        .get_oncontextlost = &get_oncontextlost,
        .get_oncontextrestored = &get_oncontextrestored,
        .get_width = &get_width,

        .set_height = &set_height,
        .set_oncontextlost = &set_oncontextlost,
        .set_oncontextrestored = &set_oncontextrestored,
        .set_width = &set_width,

        .call_addEventListener = &call_addEventListener,
        .call_convertToBlob = &call_convertToBlob,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getContext = &call_getContext,
        .call_removeEventListener = &call_removeEventListener,
        .call_transferToImageBitmap = &call_transferToImageBitmap,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        OffscreenCanvasImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        OffscreenCanvasImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, width: u64, height: u64) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try OffscreenCanvasImpl.constructor(state, width, height);
        
        return instance;
    }

    /// Extended attributes: [EnforceRange]
    pub fn get_width(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return OffscreenCanvasImpl.get_width(state);
    }

    /// Extended attributes: [EnforceRange]
    pub fn set_width(instance: *runtime.Instance, value: u64) void {
        const state = instance.getState(State);
        OffscreenCanvasImpl.set_width(state, value);
    }

    /// Extended attributes: [EnforceRange]
    pub fn get_height(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return OffscreenCanvasImpl.get_height(state);
    }

    /// Extended attributes: [EnforceRange]
    pub fn set_height(instance: *runtime.Instance, value: u64) void {
        const state = instance.getState(State);
        OffscreenCanvasImpl.set_height(state, value);
    }

    pub fn get_oncontextlost(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OffscreenCanvasImpl.get_oncontextlost(state);
    }

    pub fn set_oncontextlost(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        OffscreenCanvasImpl.set_oncontextlost(state, value);
    }

    pub fn get_oncontextrestored(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OffscreenCanvasImpl.get_oncontextrestored(state);
    }

    pub fn set_oncontextrestored(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        OffscreenCanvasImpl.set_oncontextrestored(state, value);
    }

    pub fn call_convertToBlob(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return OffscreenCanvasImpl.call_convertToBlob(state, options);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return OffscreenCanvasImpl.call_when(state, type_, options);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return OffscreenCanvasImpl.call_dispatchEvent(state, event);
    }

    pub fn call_getContext(instance: *runtime.Instance, contextId: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return OffscreenCanvasImpl.call_getContext(state, contextId, options);
    }

    pub fn call_transferToImageBitmap(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OffscreenCanvasImpl.call_transferToImageBitmap(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return OffscreenCanvasImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return OffscreenCanvasImpl.call_removeEventListener(state, type_, callback, options);
    }

};
