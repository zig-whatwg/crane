//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MessageEventImpl = @import("impls").MessageEvent;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Event = @import("interfaces").Event;
const MessageEventInit = @import("dictionaries").MessageEventInit;
const EventTarget = @import("interfaces").EventTarget;
const MessageEventSource = @import("typedefs").MessageEventSource;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;
const MessagePort = @import("interfaces").MessagePort;

pub const MessageEvent = struct {
    pub const Meta = struct {
        pub const name = "MessageEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Event.State;
        pub const ParentInterface = Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker", "AudioWorklet" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
            .AudioWorklet = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "data", "get_data", null },
            .{ "origin", "get_origin", null },
            .{ "lastEventId", "get_lastEventId", null },
            .{ "source", "get_source", null },
            .{ "ports", "get_ports", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "initMessageEvent", "call_initMessageEvent", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "initMessageEvent",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "data", "get_data", null },
            .{ "origin", "get_origin", null },
            .{ "lastEventId", "get_lastEventId", null },
            .{ "source", "get_source", null },
            .{ "ports", "get_ports", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            data: runtime.JSValue = undefined,
            origin: runtime.USVString = undefined,
            lastEventId: runtime.DOMString = undefined,
            source: ?typedefs.MessageEventSource = null,
            ports: runtime.JSValue = undefined,
            _internal: ?*MessageEventImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_data = &get_data,
        .get_lastEventId = &get_lastEventId,
        .get_origin = &get_origin,
        .get_ports = &get_ports,
        .get_source = &get_source,

        .call_initMessageEvent = &call_initMessageEvent,

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
        inline for (@typeInfo(@TypeOf(args)).@"struct".field_names) |field_name| {
            if (comptime !takesConstructionArg(field_name)) @compileError("MessageEvent has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(MessageEventImpl, "init") and @hasDecl(MessageEventImpl, "initOwn")) @compileError("MessageEventImpl defines both init and initOwn");
        if (comptime @hasDecl(MessageEventImpl, "init")) return MessageEventImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(MessageEventImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try MessageEventImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(MessageEventImpl, "init")) return false;
        if (comptime @hasDecl(MessageEventImpl, "construction_args")) {
            inline for (MessageEventImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(MessageEventImpl, "deinit") and @hasDecl(MessageEventImpl, "deinitOwn")) @compileError("MessageEventImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(MessageEventImpl, "deinit")) return MessageEventImpl.deinit(instance);
        if (comptime @hasDecl(MessageEventImpl, "deinitOwn")) MessageEventImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "MessageEvent")) {
            if (comptime @hasDecl(impls.MessageEvent, "installHooks")) impls.MessageEvent.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 1;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(MessageEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try MessageEventImpl.call_constructor(ctx, @"type", eventInitDict);
    }

    pub fn get_data(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try MessageEventImpl.get_data(instance);
    }

    pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try MessageEventImpl.get_origin(instance);
    }

    pub fn get_lastEventId(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try MessageEventImpl.get_lastEventId(instance);
    }

    pub fn get_source(instance: *runtime.Instance) anyerror!?MessageEventSource {
        return try MessageEventImpl.get_source(instance);
    }

    pub fn get_ports(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try MessageEventImpl.get_ports(instance);
    }

    pub fn call_initMessageEvent(instance: *runtime.Instance, @"type": runtime.DOMString, bubbles: webidl.Opt(bool), cancelable: webidl.Opt(bool), data: webidl.Opt(runtime.JSValue), origin: webidl.Opt(runtime.USVString), lastEventId: webidl.Opt(runtime.DOMString), source: webidl.Opt(?MessageEventSource), ports: webidl.Opt(runtime.JSValue)) anyerror!void {
        return try MessageEventImpl.call_initMessageEvent(instance, @"type", bubbles, cancelable, data, origin, lastEventId, source, ports);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_initMessageEvent", 7, "MessagePort" },
    };
};
