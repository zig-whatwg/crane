//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const OffscreenCanvasImpl = @import("impls").OffscreenCanvas;
const EventTarget = @import("interfaces").EventTarget;
const EventHandler = @import("typedefs").EventHandler;
const OffscreenRenderingContextId = @import("enums").OffscreenRenderingContextId;
const Promise<Blob> = @import("interfaces").Promise<Blob>;
const ImageEncodeOptions = @import("dictionaries").ImageEncodeOptions;
const OffscreenRenderingContext = @import("typedefs").OffscreenRenderingContext;
const ImageBitmap = @import("interfaces").ImageBitmap;

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
        
        // Initialize the instance (Impl receives full instance)
        OffscreenCanvasImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        OffscreenCanvasImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, width: u64, height: u64) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try OffscreenCanvasImpl.constructor(instance, width, height);
        
        return instance;
    }

    /// Extended attributes: [EnforceRange]
    pub fn get_width(instance: *runtime.Instance) anyerror!u64 {
        return try OffscreenCanvasImpl.get_width(instance);
    }

    /// Extended attributes: [EnforceRange]
    pub fn set_width(instance: *runtime.Instance, value: u64) anyerror!void {
        try OffscreenCanvasImpl.set_width(instance, value);
    }

    /// Extended attributes: [EnforceRange]
    pub fn get_height(instance: *runtime.Instance) anyerror!u64 {
        return try OffscreenCanvasImpl.get_height(instance);
    }

    /// Extended attributes: [EnforceRange]
    pub fn set_height(instance: *runtime.Instance, value: u64) anyerror!void {
        try OffscreenCanvasImpl.set_height(instance, value);
    }

    pub fn get_oncontextlost(instance: *runtime.Instance) anyerror!EventHandler {
        return try OffscreenCanvasImpl.get_oncontextlost(instance);
    }

    pub fn set_oncontextlost(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try OffscreenCanvasImpl.set_oncontextlost(instance, value);
    }

    pub fn get_oncontextrestored(instance: *runtime.Instance) anyerror!EventHandler {
        return try OffscreenCanvasImpl.get_oncontextrestored(instance);
    }

    pub fn set_oncontextrestored(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try OffscreenCanvasImpl.set_oncontextrestored(instance, value);
    }

    pub fn call_convertToBlob(instance: *runtime.Instance, options: ImageEncodeOptions) anyerror!anyopaque {
        
        return try OffscreenCanvasImpl.call_convertToBlob(instance, options);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try OffscreenCanvasImpl.call_when(instance, type_, options);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try OffscreenCanvasImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_getContext(instance: *runtime.Instance, contextId: OffscreenRenderingContextId, options: anyopaque) anyerror!anyopaque {
        
        return try OffscreenCanvasImpl.call_getContext(instance, contextId, options);
    }

    pub fn call_transferToImageBitmap(instance: *runtime.Instance) anyerror!ImageBitmap {
        return try OffscreenCanvasImpl.call_transferToImageBitmap(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try OffscreenCanvasImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try OffscreenCanvasImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
