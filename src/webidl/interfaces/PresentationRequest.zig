//! Generated from: presentation-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PresentationRequestImpl = @import("impls").PresentationRequest;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const PresentationAvailability = @import("interfaces").PresentationAvailability;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const PresentationConnection = @import("interfaces").PresentationConnection;
const USVString = @import("typedefs").USVString;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const PresentationRequest = struct {
    pub const Meta = struct {
        pub const name = "PresentationRequest";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onconnectionavailable", "get_onconnectionavailable", "set_onconnectionavailable" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "start", "call_start", 0 },
            .{ "reconnect", "call_reconnect", 1 },
            .{ "getAvailability", "call_getAvailability", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "start",
            "reconnect",
            "getAvailability",
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
            .{ "onconnectionavailable", "get_onconnectionavailable", "set_onconnectionavailable" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            onconnectionavailable: typedefs.EventHandler = undefined,
            _internal: ?*PresentationRequestImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onconnectionavailable = &get_onconnectionavailable,

        .set_onconnectionavailable = &set_onconnectionavailable,

        .call_getAvailability = &call_getAvailability,
        .call_reconnect = &call_reconnect,
        .call_start = &call_start,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("PresentationRequest has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(PresentationRequestImpl, "init") and @hasDecl(PresentationRequestImpl, "initOwn")) @compileError("PresentationRequestImpl defines both init and initOwn");
        if (comptime @hasDecl(PresentationRequestImpl, "init")) return PresentationRequestImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(PresentationRequestImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try PresentationRequestImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(PresentationRequestImpl, "init")) return false;
        if (comptime @hasDecl(PresentationRequestImpl, "construction_args")) {
            inline for (PresentationRequestImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(PresentationRequestImpl, "deinit") and @hasDecl(PresentationRequestImpl, "deinitOwn")) @compileError("PresentationRequestImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(PresentationRequestImpl, "deinit")) return PresentationRequestImpl.deinit(instance);
        if (comptime @hasDecl(PresentationRequestImpl, "deinitOwn")) PresentationRequestImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "PresentationRequest")) {
            if (comptime @hasDecl(impls.PresentationRequest, "installHooks")) impls.PresentationRequest.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 1;

    /// Arguments for constructor (WebIDL overloading)
    pub const ConstructorArgs = union(enum) {
        /// constructor(url)
        USVString: runtime.USVString,
        /// constructor(urls)
        sequence: runtime.JSValue,
    };

    /// WebIDL overload set of the constructor: one entry per variant of
    /// ConstructorArgs, in its order, for the overload resolution algorithm
    /// (webidl.overload_resolution) the binding runs to pick the variant.
    pub const constructor_overloads = &[_]webidl.overload_resolution.Overload{
        .{ .function = "USVString", .args = &.{.{ .kinds = &.{.string} }} },
        .{ .function = "sequence", .args = &.{.{ .kinds = &.{.sequence} }} },
    };

    /// WebIDL constructor (overloaded)
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, args: ConstructorArgs) !*runtime.Instance {
        // Pass args union directly to impl
        return try PresentationRequestImpl.call_constructor(ctx, args);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onconnectionavailable(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(PresentationRequestImpl, "get_onconnectionavailable")) return try PresentationRequestImpl.get_onconnectionavailable(instance);
        return event_handlers.value(EventHandler, instance, "onconnectionavailable");
    }

    pub fn set_onconnectionavailable(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(PresentationRequestImpl, "set_onconnectionavailable")) return try PresentationRequestImpl.set_onconnectionavailable(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onconnectionavailable", value);
    }

    pub fn call_start(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PresentationRequestImpl.call_start(instance);
    }

    pub fn call_getAvailability(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PresentationRequestImpl.call_getAvailability(instance);
    }

    pub fn call_reconnect(instance: *runtime.Instance, presentationId: runtime.USVString) anyerror!runtime.JSValue {
        return try PresentationRequestImpl.call_reconnect(instance, presentationId);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{"set_onconnectionavailable"};

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_start",
        "call_getAvailability",
        "call_reconnect",
    };
};
