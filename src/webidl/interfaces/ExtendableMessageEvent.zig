//! Generated from: service-workers.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ExtendableMessageEventImpl = @import("impls").ExtendableMessageEvent;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ExtendableEvent = @import("interfaces").ExtendableEvent;
const ServiceWorker = @import("interfaces").ServiceWorker;
const Client = @import("interfaces").Client;
const ExtendableEventInit = @import("dictionaries").ExtendableEventInit;
const EventTarget = @import("interfaces").EventTarget;
const ExtendableMessageEventInit = @import("dictionaries").ExtendableMessageEventInit;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;
const MessagePort = @import("interfaces").MessagePort;

pub const ExtendableMessageEvent = struct {
    pub const Meta = struct {
        pub const name = "ExtendableMessageEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ExtendableEvent.State;
        pub const ParentInterface = ExtendableEvent;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "ServiceWorker" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .ServiceWorker = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "data", "get_data", null },
            .{ "origin", "get_origin", null },
            .{ "lastEventId", "get_lastEventId", null },
            .{ "source", "get_source", null },
            .{ "ports", "get_ports", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
            "waitUntil",
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
            lastEventId: typedefs.DOMString = undefined,
            source: ?union(enum) {
                Client: Client,
                ServiceWorker: ServiceWorker,
                MessagePort: MessagePort,
            } = null,
            ports: runtime.JSValue = undefined,
            cached_source: ?runtime.JSValue = null,
            _internal: ?*ExtendableMessageEventImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_data = &get_data,
        .get_lastEventId = &get_lastEventId,
        .get_origin = &get_origin,
        .get_ports = &get_ports,
        .get_source = &get_source,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("ExtendableMessageEvent has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(ExtendableMessageEventImpl, "init") and @hasDecl(ExtendableMessageEventImpl, "initOwn")) @compileError("ExtendableMessageEventImpl defines both init and initOwn");
        if (comptime @hasDecl(ExtendableMessageEventImpl, "init")) return ExtendableMessageEventImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(ExtendableMessageEventImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try ExtendableMessageEventImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ExtendableMessageEventImpl, "init")) return false;
        if (comptime @hasDecl(ExtendableMessageEventImpl, "construction_args")) {
            inline for (ExtendableMessageEventImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(ExtendableMessageEventImpl, "deinit") and @hasDecl(ExtendableMessageEventImpl, "deinitOwn")) @compileError("ExtendableMessageEventImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(ExtendableMessageEventImpl, "deinit")) return ExtendableMessageEventImpl.deinit(instance);
        if (comptime @hasDecl(ExtendableMessageEventImpl, "deinitOwn")) ExtendableMessageEventImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ExtendableMessageEvent")) {
            if (comptime @hasDecl(impls.ExtendableMessageEvent, "installHooks")) impls.ExtendableMessageEvent.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": DOMString, eventInitDict: webidl.Opt(ExtendableMessageEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ExtendableMessageEventImpl.call_constructor(ctx, @"type", eventInitDict);
    }

    pub fn get_data(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ExtendableMessageEventImpl.get_data(instance);
    }

    pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try ExtendableMessageEventImpl.get_origin(instance);
    }

    pub fn get_lastEventId(instance: *runtime.Instance) anyerror!DOMString {
        return try ExtendableMessageEventImpl.get_lastEventId(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_source(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try ExtendableMessageEventImpl.get_source(instance);
    }

    pub fn get_ports(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ExtendableMessageEventImpl.get_ports(instance);
    }
};
