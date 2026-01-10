//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const OffscreenCanvasImpl = @import("impls").OffscreenCanvas;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("EventTarget.zig").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const OffscreenRenderingContextId = @import("enums").OffscreenRenderingContextId;
const Blob = @import("Blob.zig").Blob;
const ImageEncodeOptions = @import("dictionaries").ImageEncodeOptions;
const OffscreenRenderingContext = @import("typedefs").OffscreenRenderingContext;
const Observable = @import("Observable.zig").Observable;
const Event = @import("Event.zig").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("EventListener.zig").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const ImageBitmap = @import("ImageBitmap.zig").ImageBitmap;

pub const OffscreenCanvas = struct {
    pub const Meta = struct {
        pub const name = "OffscreenCanvas";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
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
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            width: u64 = undefined,
            height: u64 = undefined,
            oncontextlost: typedefs.EventHandler = undefined,
            oncontextrestored: typedefs.EventHandler = undefined,
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

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return OffscreenCanvasImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return OffscreenCanvasImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        OffscreenCanvasImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, width: u64, height: u64) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try OffscreenCanvasImpl.call_constructor(ctx, width, height);
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

    pub fn call_transferToImageBitmap(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try OffscreenCanvasImpl.call_transferToImageBitmap(instance);
    }

    pub fn call_getContext(instance: *runtime.Instance, contextId: OffscreenRenderingContextId, options: webidl.Opt(runtime.JSValue)) anyerror!?OffscreenRenderingContext {
        
        return try OffscreenCanvasImpl.call_getContext(instance, contextId, options);
    }

    pub fn call_convertToBlob(instance: *runtime.Instance, options: webidl.Opt(ImageEncodeOptions)) anyerror!runtime.JSValue {
        
        return try OffscreenCanvasImpl.call_convertToBlob(instance, options);
    }

};
