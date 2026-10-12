//! Generated from: xhr.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XMLHttpRequestEventTargetImpl = @import("impls").XMLHttpRequestEventTarget;
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

pub const XMLHttpRequestEventTarget = struct {
    pub const Meta = struct {
        pub const name = "XMLHttpRequestEventTarget";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker", "SharedWorker" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
            .SharedWorker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onloadstart", "get_onloadstart", "set_onloadstart" },
            .{ "onprogress", "get_onprogress", "set_onprogress" },
            .{ "onabort", "get_onabort", "set_onabort" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onload", "get_onload", "set_onload" },
            .{ "ontimeout", "get_ontimeout", "set_ontimeout" },
            .{ "onloadend", "get_onloadend", "set_onloadend" },
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
            .{ "onloadstart", "get_onloadstart", "set_onloadstart" },
            .{ "onprogress", "get_onprogress", "set_onprogress" },
            .{ "onabort", "get_onabort", "set_onabort" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onload", "get_onload", "set_onload" },
            .{ "ontimeout", "get_ontimeout", "set_ontimeout" },
            .{ "onloadend", "get_onloadend", "set_onloadend" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            onloadstart: typedefs.EventHandler = undefined,
            onprogress: typedefs.EventHandler = undefined,
            onabort: typedefs.EventHandler = undefined,
            onerror: typedefs.EventHandler = undefined,
            onload: typedefs.EventHandler = undefined,
            ontimeout: typedefs.EventHandler = undefined,
            onloadend: typedefs.EventHandler = undefined,
            _internal: ?*XMLHttpRequestEventTargetImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onabort = &get_onabort,
        .get_onerror = &get_onerror,
        .get_onload = &get_onload,
        .get_onloadend = &get_onloadend,
        .get_onloadstart = &get_onloadstart,
        .get_onprogress = &get_onprogress,
        .get_ontimeout = &get_ontimeout,

        .set_onabort = &set_onabort,
        .set_onerror = &set_onerror,
        .set_onload = &set_onload,
        .set_onloadend = &set_onloadend,
        .set_onloadstart = &set_onloadstart,
        .set_onprogress = &set_onprogress,
        .set_ontimeout = &set_ontimeout,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("XMLHttpRequestEventTarget has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(XMLHttpRequestEventTargetImpl, "init") and @hasDecl(XMLHttpRequestEventTargetImpl, "initOwn")) @compileError("XMLHttpRequestEventTargetImpl defines both init and initOwn");
        if (comptime @hasDecl(XMLHttpRequestEventTargetImpl, "init")) return XMLHttpRequestEventTargetImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(XMLHttpRequestEventTargetImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try XMLHttpRequestEventTargetImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(XMLHttpRequestEventTargetImpl, "init")) return false;
        if (comptime @hasDecl(XMLHttpRequestEventTargetImpl, "construction_args")) {
            inline for (XMLHttpRequestEventTargetImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(XMLHttpRequestEventTargetImpl, "deinit") and @hasDecl(XMLHttpRequestEventTargetImpl, "deinitOwn")) @compileError("XMLHttpRequestEventTargetImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(XMLHttpRequestEventTargetImpl, "deinit")) return XMLHttpRequestEventTargetImpl.deinit(instance);
        if (comptime @hasDecl(XMLHttpRequestEventTargetImpl, "deinitOwn")) XMLHttpRequestEventTargetImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "XMLHttpRequestEventTarget")) {
            if (comptime @hasDecl(impls.XMLHttpRequestEventTarget, "installHooks")) impls.XMLHttpRequestEventTarget.installHooks();
        }
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onloadstart(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(XMLHttpRequestEventTargetImpl, "get_onloadstart")) return try XMLHttpRequestEventTargetImpl.get_onloadstart(instance);
        return event_handlers.value(EventHandler, instance, "onloadstart");
    }

    pub fn set_onloadstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(XMLHttpRequestEventTargetImpl, "set_onloadstart")) return try XMLHttpRequestEventTargetImpl.set_onloadstart(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onloadstart", value);
    }

    pub fn get_onprogress(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(XMLHttpRequestEventTargetImpl, "get_onprogress")) return try XMLHttpRequestEventTargetImpl.get_onprogress(instance);
        return event_handlers.value(EventHandler, instance, "onprogress");
    }

    pub fn set_onprogress(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(XMLHttpRequestEventTargetImpl, "set_onprogress")) return try XMLHttpRequestEventTargetImpl.set_onprogress(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onprogress", value);
    }

    pub fn get_onabort(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(XMLHttpRequestEventTargetImpl, "get_onabort")) return try XMLHttpRequestEventTargetImpl.get_onabort(instance);
        return event_handlers.value(EventHandler, instance, "onabort");
    }

    pub fn set_onabort(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(XMLHttpRequestEventTargetImpl, "set_onabort")) return try XMLHttpRequestEventTargetImpl.set_onabort(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onabort", value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(XMLHttpRequestEventTargetImpl, "get_onerror")) return try XMLHttpRequestEventTargetImpl.get_onerror(instance);
        return event_handlers.value(EventHandler, instance, "onerror");
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(XMLHttpRequestEventTargetImpl, "set_onerror")) return try XMLHttpRequestEventTargetImpl.set_onerror(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onerror", value);
    }

    pub fn get_onload(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(XMLHttpRequestEventTargetImpl, "get_onload")) return try XMLHttpRequestEventTargetImpl.get_onload(instance);
        return event_handlers.value(EventHandler, instance, "onload");
    }

    pub fn set_onload(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(XMLHttpRequestEventTargetImpl, "set_onload")) return try XMLHttpRequestEventTargetImpl.set_onload(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onload", value);
    }

    pub fn get_ontimeout(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(XMLHttpRequestEventTargetImpl, "get_ontimeout")) return try XMLHttpRequestEventTargetImpl.get_ontimeout(instance);
        return event_handlers.value(EventHandler, instance, "ontimeout");
    }

    pub fn set_ontimeout(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(XMLHttpRequestEventTargetImpl, "set_ontimeout")) return try XMLHttpRequestEventTargetImpl.set_ontimeout(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ontimeout", value);
    }

    pub fn get_onloadend(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(XMLHttpRequestEventTargetImpl, "get_onloadend")) return try XMLHttpRequestEventTargetImpl.get_onloadend(instance);
        return event_handlers.value(EventHandler, instance, "onloadend");
    }

    pub fn set_onloadend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(XMLHttpRequestEventTargetImpl, "set_onloadend")) return try XMLHttpRequestEventTargetImpl.set_onloadend(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onloadend", value);
    }
};
