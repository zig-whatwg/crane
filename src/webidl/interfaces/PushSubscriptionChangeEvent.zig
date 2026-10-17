//! Generated from: push-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PushSubscriptionChangeEventImpl = @import("impls").PushSubscriptionChangeEvent;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ExtendableEvent = @import("interfaces").ExtendableEvent;
const PushSubscriptionChangeEventInit = @import("dictionaries").PushSubscriptionChangeEventInit;
const ExtendableEventInit = @import("dictionaries").ExtendableEventInit;
const EventTarget = @import("interfaces").EventTarget;
const PushSubscription = @import("interfaces").PushSubscription;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const PushSubscriptionChangeEvent = struct {
    pub const Meta = struct {
        pub const name = "PushSubscriptionChangeEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ExtendableEvent.State;
        pub const ParentInterface = ExtendableEvent;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "ServiceWorker" } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .ServiceWorker = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "newSubscription", "get_newSubscription", null },
            .{ "oldSubscription", "get_oldSubscription", null },
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
            .{ "newSubscription", "get_newSubscription", null },
            .{ "oldSubscription", "get_oldSubscription", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            newSubscription: ?*runtime.Instance = null,
            oldSubscription: ?*runtime.Instance = null,
            _internal: ?*PushSubscriptionChangeEventImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_newSubscription = &get_newSubscription,
        .get_oldSubscription = &get_oldSubscription,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("PushSubscriptionChangeEvent has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(PushSubscriptionChangeEventImpl, "init") and @hasDecl(PushSubscriptionChangeEventImpl, "initOwn")) @compileError("PushSubscriptionChangeEventImpl defines both init and initOwn");
        if (comptime @hasDecl(PushSubscriptionChangeEventImpl, "init")) return PushSubscriptionChangeEventImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(PushSubscriptionChangeEventImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try PushSubscriptionChangeEventImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(PushSubscriptionChangeEventImpl, "init")) return false;
        if (comptime @hasDecl(PushSubscriptionChangeEventImpl, "construction_args")) {
            inline for (PushSubscriptionChangeEventImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(PushSubscriptionChangeEventImpl, "deinit") and @hasDecl(PushSubscriptionChangeEventImpl, "deinitOwn")) @compileError("PushSubscriptionChangeEventImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(PushSubscriptionChangeEventImpl, "deinit")) return PushSubscriptionChangeEventImpl.deinit(instance);
        if (comptime @hasDecl(PushSubscriptionChangeEventImpl, "deinitOwn")) PushSubscriptionChangeEventImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "PushSubscriptionChangeEvent")) {
            if (comptime @hasDecl(impls.PushSubscriptionChangeEvent, "installHooks")) impls.PushSubscriptionChangeEvent.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(PushSubscriptionChangeEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try PushSubscriptionChangeEventImpl.call_constructor(ctx, @"type", eventInitDict);
    }

    pub fn get_newSubscription(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try PushSubscriptionChangeEventImpl.get_newSubscription(instance);
    }

    pub fn get_oldSubscription(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try PushSubscriptionChangeEventImpl.get_oldSubscription(instance);
    }
};
