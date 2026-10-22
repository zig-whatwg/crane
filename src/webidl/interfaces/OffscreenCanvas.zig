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
        pub const lazy_properties = .{};

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
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Make a new instance: the construction chain, this interface's State
    /// and vtable.
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return initChain(allocator, State, &vtable, ctx, .{});
    }

    /// Make a new instance with construction arguments: facts given at
    /// construction, as a C++ constructor's parameters. Each field of `args`
    /// must be taken by an impl on the chain (its `construction_args`).
    pub fn initWith(allocator: std.mem.Allocator, ctx: runtime.Context, args: anytype) !*runtime.Instance {
        inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
            if (comptime !takesConstructionArg(field.name)) @compileError("OffscreenCanvas has no construction argument '" ++ field.name ++ "'");
        }
        return initChain(allocator, State, &vtable, ctx, args);
    }

    /// The construction chain for a descendant's State and vtable, for an
    /// impl that still chains by hand.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return initChain(allocator, StateType, vtable_ptr, ctx, .{});
    }

    /// The construction chain: the parent interface's, then the impl's own
    /// steps (`initOwn`), whose failure unwinds the parent's part and frees
    /// the slot. An impl that still defines `init` chains by hand.
    pub inline fn initChain(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
        args: anytype,
    ) !*runtime.Instance {
        if (comptime @hasDecl(OffscreenCanvasImpl, "init") and @hasDecl(OffscreenCanvasImpl, "initOwn")) @compileError("OffscreenCanvasImpl defines both init and initOwn");
        if (comptime @hasDecl(OffscreenCanvasImpl, "init")) return OffscreenCanvasImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(OffscreenCanvasImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try OffscreenCanvasImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(OffscreenCanvasImpl, "init")) return false;
        if (comptime @hasDecl(OffscreenCanvasImpl, "construction_args")) {
            inline for (OffscreenCanvasImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return Meta.ParentInterface.takesConstructionArg(name);
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(OffscreenCanvasImpl, "deinit") and @hasDecl(OffscreenCanvasImpl, "deinitOwn")) @compileError("OffscreenCanvasImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(OffscreenCanvasImpl, "deinit")) return OffscreenCanvasImpl.deinit(instance);
        if (comptime @hasDecl(OffscreenCanvasImpl, "deinitOwn")) OffscreenCanvasImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "OffscreenCanvas")) {
            if (comptime @hasDecl(impls.OffscreenCanvas, "installHooks")) impls.OffscreenCanvas.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 2;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, width: u64, height: u64) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try OffscreenCanvasImpl.call_constructor(ctx, width, height);
    }

    /// WebIDL [EnforceRange] constructor arguments (bit i = argument i).
    pub const constructor_enforce_range: u32 = 0b11;

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

    const event_handlers = @import("dom").event_handlers;

    pub fn get_oncontextlost(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(OffscreenCanvasImpl, "get_oncontextlost")) return try OffscreenCanvasImpl.get_oncontextlost(instance);
        return event_handlers.value(EventHandler, instance, "oncontextlost");
    }

    pub fn set_oncontextlost(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(OffscreenCanvasImpl, "set_oncontextlost")) return try OffscreenCanvasImpl.set_oncontextlost(instance, value);
        try event_handlers.setValue(EventHandler, instance, "oncontextlost", value);
    }

    pub fn get_oncontextrestored(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(OffscreenCanvasImpl, "get_oncontextrestored")) return try OffscreenCanvasImpl.get_oncontextrestored(instance);
        return event_handlers.value(EventHandler, instance, "oncontextrestored");
    }

    pub fn set_oncontextrestored(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(OffscreenCanvasImpl, "set_oncontextrestored")) return try OffscreenCanvasImpl.set_oncontextrestored(instance, value);
        try event_handlers.setValue(EventHandler, instance, "oncontextrestored", value);
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

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{ "set_oncontextlost", "set_oncontextrestored" };

    /// WebIDL [EnforceRange]: the integer arguments and attribute values
    /// whose conversion takes that branch of ConvertToInt (bit i = argument i;
    /// an attribute setter's value is bit 0).
    pub const enforce_range = .{
        .{ "set_width", 0b1 },
        .{ "set_height", 0b1 },
    };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_convertToBlob",
    };
};
