//! Generated from: idle-detection.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const IdleDetectorImpl = @import("impls").IdleDetector;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const IdleOptions = @import("dictionaries").IdleOptions;
const ScreenIdleState = @import("enums").ScreenIdleState;
const UserIdleState = @import("enums").UserIdleState;
const Observable = @import("interfaces").Observable;
const PermissionState = @import("enums").PermissionState;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const IdleDetector = struct {
    pub const Meta = struct {
        pub const name = "IdleDetector";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "userState", "get_userState", null },
            .{ "screenState", "get_screenState", null },
            .{ "onchange", "get_onchange", "set_onchange" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "start", "call_start", 0 },
        };

        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "requestPermission", "call_static_requestPermission", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "requestPermission",
            "start",
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
            .{ "userState", "get_userState", null },
            .{ "screenState", "get_screenState", null },
            .{ "onchange", "get_onchange", "set_onchange" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
        /// Member-level [Exposed] overrides; unlisted members inherit the interface.
        pub const exposed_static_members = .{
            .{ "requestPermission", .{"Window"} },
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            userState: ?enums.UserIdleState = null,
            screenState: ?enums.ScreenIdleState = null,
            onchange: typedefs.EventHandler = undefined,
            _internal: ?*IdleDetectorImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onchange = &get_onchange,
        .get_screenState = &get_screenState,
        .get_userState = &get_userState,

        .set_onchange = &set_onchange,

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
        inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
            if (comptime !takesConstructionArg(field.name)) @compileError("IdleDetector has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(IdleDetectorImpl, "init") and @hasDecl(IdleDetectorImpl, "initOwn")) @compileError("IdleDetectorImpl defines both init and initOwn");
        if (comptime @hasDecl(IdleDetectorImpl, "init")) return IdleDetectorImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(IdleDetectorImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try IdleDetectorImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(IdleDetectorImpl, "init")) return false;
        if (comptime @hasDecl(IdleDetectorImpl, "construction_args")) {
            inline for (IdleDetectorImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(IdleDetectorImpl, "deinit") and @hasDecl(IdleDetectorImpl, "deinitOwn")) @compileError("IdleDetectorImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(IdleDetectorImpl, "deinit")) return IdleDetectorImpl.deinit(instance);
        if (comptime @hasDecl(IdleDetectorImpl, "deinitOwn")) IdleDetectorImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "IdleDetector")) {
            if (comptime @hasDecl(impls.IdleDetector, "installHooks")) impls.IdleDetector.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 0;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try IdleDetectorImpl.call_constructor(ctx);
    }

    pub fn get_userState(instance: *runtime.Instance) anyerror!?UserIdleState {
        return try IdleDetectorImpl.get_userState(instance);
    }

    pub fn get_screenState(instance: *runtime.Instance) anyerror!?ScreenIdleState {
        return try IdleDetectorImpl.get_screenState(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(IdleDetectorImpl, "get_onchange")) return try IdleDetectorImpl.get_onchange(instance);
        return event_handlers.value(EventHandler, instance, "onchange");
    }

    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(IdleDetectorImpl, "set_onchange")) return try IdleDetectorImpl.set_onchange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onchange", value);
    }

    pub fn call_start(instance: *runtime.Instance, options: webidl.Opt(IdleOptions)) anyerror!runtime.JSValue {
        return try IdleDetectorImpl.call_start(instance, options);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_static_requestPermission(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try IdleDetectorImpl.call_static_requestPermission(instance);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{"set_onchange"};

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_start",
        "call_static_requestPermission",
    };
};
