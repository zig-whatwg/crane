//! Generated from: cssom-view.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const VisualViewportImpl = @import("impls").VisualViewport;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const VisualViewport = struct {
    pub const Meta = struct {
        pub const name = "VisualViewport";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "offsetLeft", "get_offsetLeft", null },
            .{ "offsetTop", "get_offsetTop", null },
            .{ "pageLeft", "get_pageLeft", null },
            .{ "pageTop", "get_pageTop", null },
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
            .{ "scale", "get_scale", null },
            .{ "onresize", "get_onresize", "set_onresize" },
            .{ "onscroll", "get_onscroll", "set_onscroll" },
            .{ "onscrollend", "get_onscrollend", "set_onscrollend" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "offsetLeft", "get_offsetLeft", null },
            .{ "offsetTop", "get_offsetTop", null },
            .{ "pageLeft", "get_pageLeft", null },
            .{ "pageTop", "get_pageTop", null },
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
            .{ "scale", "get_scale", null },
            .{ "onresize", "get_onresize", "set_onresize" },
            .{ "onscroll", "get_onscroll", "set_onscroll" },
            .{ "onscrollend", "get_onscrollend", "set_onscrollend" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            offsetLeft: f64 = undefined,
            offsetTop: f64 = undefined,
            pageLeft: f64 = undefined,
            pageTop: f64 = undefined,
            width: f64 = undefined,
            height: f64 = undefined,
            scale: f64 = undefined,
            onresize: typedefs.EventHandler = undefined,
            onscroll: typedefs.EventHandler = undefined,
            onscrollend: typedefs.EventHandler = undefined,
            _internal: ?*VisualViewportImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_height = &get_height,
        .get_offsetLeft = &get_offsetLeft,
        .get_offsetTop = &get_offsetTop,
        .get_onresize = &get_onresize,
        .get_onscroll = &get_onscroll,
        .get_onscrollend = &get_onscrollend,
        .get_pageLeft = &get_pageLeft,
        .get_pageTop = &get_pageTop,
        .get_scale = &get_scale,
        .get_width = &get_width,

        .set_onresize = &set_onresize,
        .set_onscroll = &set_onscroll,
        .set_onscrollend = &set_onscrollend,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("VisualViewport has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(VisualViewportImpl, "init") and @hasDecl(VisualViewportImpl, "initOwn")) @compileError("VisualViewportImpl defines both init and initOwn");
        if (comptime @hasDecl(VisualViewportImpl, "init")) return VisualViewportImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(VisualViewportImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try VisualViewportImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(VisualViewportImpl, "init")) return false;
        if (comptime @hasDecl(VisualViewportImpl, "construction_args")) {
            inline for (VisualViewportImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(VisualViewportImpl, "deinit") and @hasDecl(VisualViewportImpl, "deinitOwn")) @compileError("VisualViewportImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(VisualViewportImpl, "deinit")) return VisualViewportImpl.deinit(instance);
        if (comptime @hasDecl(VisualViewportImpl, "deinitOwn")) VisualViewportImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "VisualViewport")) {
            if (comptime @hasDecl(impls.VisualViewport, "installHooks")) impls.VisualViewport.installHooks();
        }
    }

    pub fn get_offsetLeft(instance: *runtime.Instance) anyerror!f64 {
        return try VisualViewportImpl.get_offsetLeft(instance);
    }

    pub fn get_offsetTop(instance: *runtime.Instance) anyerror!f64 {
        return try VisualViewportImpl.get_offsetTop(instance);
    }

    pub fn get_pageLeft(instance: *runtime.Instance) anyerror!f64 {
        return try VisualViewportImpl.get_pageLeft(instance);
    }

    pub fn get_pageTop(instance: *runtime.Instance) anyerror!f64 {
        return try VisualViewportImpl.get_pageTop(instance);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!f64 {
        return try VisualViewportImpl.get_width(instance);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!f64 {
        return try VisualViewportImpl.get_height(instance);
    }

    pub fn get_scale(instance: *runtime.Instance) anyerror!f64 {
        return try VisualViewportImpl.get_scale(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onresize(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(VisualViewportImpl, "get_onresize")) return try VisualViewportImpl.get_onresize(instance);
        return event_handlers.value(EventHandler, instance, "onresize");
    }

    pub fn set_onresize(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(VisualViewportImpl, "set_onresize")) return try VisualViewportImpl.set_onresize(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onresize", value);
    }

    pub fn get_onscroll(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(VisualViewportImpl, "get_onscroll")) return try VisualViewportImpl.get_onscroll(instance);
        return event_handlers.value(EventHandler, instance, "onscroll");
    }

    pub fn set_onscroll(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(VisualViewportImpl, "set_onscroll")) return try VisualViewportImpl.set_onscroll(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onscroll", value);
    }

    pub fn get_onscrollend(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(VisualViewportImpl, "get_onscrollend")) return try VisualViewportImpl.get_onscrollend(instance);
        return event_handlers.value(EventHandler, instance, "onscrollend");
    }

    pub fn set_onscrollend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(VisualViewportImpl, "set_onscrollend")) return try VisualViewportImpl.set_onscrollend(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onscrollend", value);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{ "set_onresize", "set_onscroll", "set_onscrollend" };
};
