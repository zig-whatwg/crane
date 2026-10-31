//! Generated from: webxr.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRSystemImpl = @import("impls").XRSystem;
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
const XRSessionMode = @import("enums").XRSessionMode;
const XRSession = @import("interfaces").XRSession;
const EventListener = @import("interfaces").EventListener;
const XRSessionInit = @import("dictionaries").XRSessionInit;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const XRSystem = struct {
    pub const Meta = struct {
        pub const name = "XRSystem";
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
            .{ "ondevicechange", "get_ondevicechange", "set_ondevicechange" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "isSessionSupported", "call_isSessionSupported", 1 },
            .{ "requestSession", "call_requestSession", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "isSessionSupported",
            "requestSession",
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
            .{ "ondevicechange", "get_ondevicechange", "set_ondevicechange" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            ondevicechange: typedefs.EventHandler = undefined,
            _internal: ?*XRSystemImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_ondevicechange = &get_ondevicechange,

        .set_ondevicechange = &set_ondevicechange,

        .call_isSessionSupported = &call_isSessionSupported,
        .call_requestSession = &call_requestSession,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("XRSystem has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(XRSystemImpl, "init") and @hasDecl(XRSystemImpl, "initOwn")) @compileError("XRSystemImpl defines both init and initOwn");
        if (comptime @hasDecl(XRSystemImpl, "init")) return XRSystemImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(XRSystemImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try XRSystemImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(XRSystemImpl, "init")) return false;
        if (comptime @hasDecl(XRSystemImpl, "construction_args")) {
            inline for (XRSystemImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(XRSystemImpl, "deinit") and @hasDecl(XRSystemImpl, "deinitOwn")) @compileError("XRSystemImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(XRSystemImpl, "deinit")) return XRSystemImpl.deinit(instance);
        if (comptime @hasDecl(XRSystemImpl, "deinitOwn")) XRSystemImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "XRSystem")) {
            if (comptime @hasDecl(impls.XRSystem, "installHooks")) impls.XRSystem.installHooks();
        }
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_ondevicechange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(XRSystemImpl, "get_ondevicechange")) return try XRSystemImpl.get_ondevicechange(instance);
        return event_handlers.value(EventHandler, instance, "ondevicechange");
    }

    pub fn set_ondevicechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(XRSystemImpl, "set_ondevicechange")) return try XRSystemImpl.set_ondevicechange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ondevicechange", value);
    }

    /// Extended attributes: [NewObject]
    pub fn call_requestSession(instance: *runtime.Instance, mode: XRSessionMode, options: webidl.Opt(XRSessionInit)) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object

        return try XRSystemImpl.call_requestSession(instance, mode, options);
    }

    pub fn call_isSessionSupported(instance: *runtime.Instance, mode: XRSessionMode) anyerror!runtime.JSValue {
        return try XRSystemImpl.call_isSessionSupported(instance, mode);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{"set_ondevicechange"};

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_requestSession",
        "call_isSessionSupported",
    };
};
