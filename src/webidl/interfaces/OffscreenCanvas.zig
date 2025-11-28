//! Generated from: html.idl
//! Generated at: 2025-11-28T03:24:38Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const OffscreenCanvasImpl = @import("impls").OffscreenCanvas;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const OffscreenRenderingContextId = @import("enums").OffscreenRenderingContextId;
const Blob = @import("interfaces").Blob;
const ImageEncodeOptions = @import("dictionaries").ImageEncodeOptions;
const OffscreenRenderingContext = @import("typedefs").OffscreenRenderingContext;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const ImageBitmap = @import("interfaces").ImageBitmap;

pub const OffscreenCanvas = struct {
    pub const Meta = struct {
        pub const name = "OffscreenCanvas";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Transferable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "width", "get_width", "set_width" },
            .{ "height", "get_height", "set_height" },
            .{ "oncontextlost", "get_oncontextlost", "set_oncontextlost" },
            .{ "oncontextrestored", "get_oncontextrestored", "set_oncontextrestored" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getContext", "call_getContext", 1 },
            .{ "transferToImageBitmap", "call_transferToImageBitmap", 0 },
            .{ "convertToBlob", "call_convertToBlob", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getContext",
            "transferToImageBitmap",
            "convertToBlob",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "width", "get_width", "set_width" },
            .{ "height", "get_height", "set_height" },
            .{ "oncontextlost", "get_oncontextlost", "set_oncontextlost" },
            .{ "oncontextrestored", "get_oncontextrestored", "set_oncontextrestored" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            width: u64 = undefined,
            height: u64 = undefined,
            oncontextlost: EventHandler = undefined,
            oncontextrestored: EventHandler = undefined,
            _internal: ?*OffscreenCanvasImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_height = &get_height,
        .get_oncontextlost = &get_oncontextlost,
        .get_oncontextrestored = &get_oncontextrestored,
        .get_width = &get_width,

        .set_height = &set_height,
        .set_oncontextlost = &set_oncontextlost,
        .set_oncontextrestored = &set_oncontextrestored,
        .set_width = &set_width,

        .call_convertToBlob = &call_convertToBlob,
        .call_getContext = &call_getContext,
        .call_transferToImageBitmap = &call_transferToImageBitmap,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return OffscreenCanvasImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        OffscreenCanvasImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, width: u64, height: u64) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try OffscreenCanvasImpl.call_constructor(allocator, ctx, width, height);
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

    pub fn call_getContext(instance: *runtime.Instance, contextId: OffscreenRenderingContextId, options: *const anyopaque) anyerror!?OffscreenRenderingContext {
        
        return try OffscreenCanvasImpl.call_getContext(instance, contextId, options);
    }

    pub fn call_convertToBlob(instance: *runtime.Instance, options: ImageEncodeOptions) anyerror!*const anyopaque {
        
        return try OffscreenCanvasImpl.call_convertToBlob(instance, options);
    }

    pub fn call_transferToImageBitmap(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try OffscreenCanvasImpl.call_transferToImageBitmap(instance);
    }

};
