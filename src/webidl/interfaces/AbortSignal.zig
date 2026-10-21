//! Generated from: dom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AbortSignalImpl = @import("impls").AbortSignal;
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

pub const AbortSignal = struct {
    pub const Meta = struct {
        pub const name = "AbortSignal";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "aborted", "get_aborted", null },
            .{ "reason", "get_reason", null },
            .{ "onabort", "get_onabort", "set_onabort" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "throwIfAborted", "call_throwIfAborted", 0 },
        };

        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "abort", "call_static_abort", 0 },
            .{ "timeout", "call_static_timeout", 1 },
            .{ "any", "call_static_any", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "abort",
            "timeout",
            "any",
            "throwIfAborted",
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
            .{ "aborted", "get_aborted", null },
            .{ "reason", "get_reason", null },
            .{ "onabort", "get_onabort", "set_onabort" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            aborted: bool = undefined,
            reason: runtime.JSValue = undefined,
            onabort: typedefs.EventHandler = undefined,
            _internal: ?*AbortSignalImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_aborted = &get_aborted,
        .get_onabort = &get_onabort,
        .get_reason = &get_reason,

        .set_onabort = &set_onabort,

        .call_throwIfAborted = &call_throwIfAborted,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("AbortSignal has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(AbortSignalImpl, "init") and @hasDecl(AbortSignalImpl, "initOwn")) @compileError("AbortSignalImpl defines both init and initOwn");
        if (comptime @hasDecl(AbortSignalImpl, "init")) return AbortSignalImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(AbortSignalImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try AbortSignalImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(AbortSignalImpl, "init")) return false;
        if (comptime @hasDecl(AbortSignalImpl, "construction_args")) {
            inline for (AbortSignalImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(AbortSignalImpl, "deinit") and @hasDecl(AbortSignalImpl, "deinitOwn")) @compileError("AbortSignalImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(AbortSignalImpl, "deinit")) return AbortSignalImpl.deinit(instance);
        if (comptime @hasDecl(AbortSignalImpl, "deinitOwn")) AbortSignalImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "AbortSignal")) {
            if (comptime @hasDecl(impls.AbortSignal, "installHooks")) impls.AbortSignal.installHooks();
        }
    }

    pub fn get_aborted(instance: *runtime.Instance) anyerror!bool {
        return try AbortSignalImpl.get_aborted(instance);
    }

    pub fn get_reason(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try AbortSignalImpl.get_reason(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onabort(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(AbortSignalImpl, "get_onabort")) return try AbortSignalImpl.get_onabort(instance);
        return event_handlers.value(EventHandler, instance, "onabort");
    }

    pub fn set_onabort(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(AbortSignalImpl, "set_onabort")) return try AbortSignalImpl.set_onabort(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onabort", value);
    }

    pub fn call_throwIfAborted(instance: *runtime.Instance) anyerror!void {
        return try AbortSignalImpl.call_throwIfAborted(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_static_abort(instance: *runtime.Instance, reason: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try AbortSignalImpl.call_static_abort(instance, reason);
    }

    /// Extended attributes: [Exposed=(Window,Worker)], [NewObject]
    pub fn call_static_timeout(instance: *runtime.Instance, milliseconds: u64) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try AbortSignalImpl.call_static_timeout(instance, milliseconds);
    }

    /// Extended attributes: [NewObject]
    pub fn call_static_any(instance: *runtime.Instance, signals: runtime.JSValue) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try AbortSignalImpl.call_static_any(instance, signals);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{"set_onabort"};

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_static_any", 0, "AbortSignal" },
    };

    /// WebIDL [EnforceRange]: the integer arguments and attribute values
    /// whose conversion takes that branch of ConvertToInt (bit i = argument i;
    /// an attribute setter's value is bit 0).
    pub const enforce_range = .{
        .{ "call_static_timeout", 0b1 },
    };
};
