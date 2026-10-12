//! Generated from: payment-request.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PaymentMethodChangeEventImpl = @import("impls").PaymentMethodChangeEvent;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const PaymentRequestUpdateEvent = @import("interfaces").PaymentRequestUpdateEvent;
const PaymentDetailsUpdate = @import("dictionaries").PaymentDetailsUpdate;
const PaymentRequestUpdateEventInit = @import("dictionaries").PaymentRequestUpdateEventInit;
const EventTarget = @import("interfaces").EventTarget;
const PaymentMethodChangeEventInit = @import("dictionaries").PaymentMethodChangeEventInit;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const PaymentMethodChangeEvent = struct {
    pub const Meta = struct {
        pub const name = "PaymentMethodChangeEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = PaymentRequestUpdateEvent.State;
        pub const ParentInterface = PaymentRequestUpdateEvent;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "methodName", "get_methodName", null },
            .{ "methodDetails", "get_methodDetails", null },
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
            "updateWith",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "methodName", "get_methodName", null },
            .{ "methodDetails", "get_methodDetails", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            methodName: typedefs.DOMString = undefined,
            methodDetails: ?runtime.JSValue = null,
            _internal: ?*PaymentMethodChangeEventImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_methodDetails = &get_methodDetails,
        .get_methodName = &get_methodName,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("PaymentMethodChangeEvent has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(PaymentMethodChangeEventImpl, "init") and @hasDecl(PaymentMethodChangeEventImpl, "initOwn")) @compileError("PaymentMethodChangeEventImpl defines both init and initOwn");
        if (comptime @hasDecl(PaymentMethodChangeEventImpl, "init")) return PaymentMethodChangeEventImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(PaymentMethodChangeEventImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try PaymentMethodChangeEventImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(PaymentMethodChangeEventImpl, "init")) return false;
        if (comptime @hasDecl(PaymentMethodChangeEventImpl, "construction_args")) {
            inline for (PaymentMethodChangeEventImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(PaymentMethodChangeEventImpl, "deinit") and @hasDecl(PaymentMethodChangeEventImpl, "deinitOwn")) @compileError("PaymentMethodChangeEventImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(PaymentMethodChangeEventImpl, "deinit")) return PaymentMethodChangeEventImpl.deinit(instance);
        if (comptime @hasDecl(PaymentMethodChangeEventImpl, "deinitOwn")) PaymentMethodChangeEventImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "PaymentMethodChangeEvent")) {
            if (comptime @hasDecl(impls.PaymentMethodChangeEvent, "installHooks")) impls.PaymentMethodChangeEvent.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": DOMString, eventInitDict: webidl.Opt(PaymentMethodChangeEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try PaymentMethodChangeEventImpl.call_constructor(ctx, @"type", eventInitDict);
    }

    pub fn get_methodName(instance: *runtime.Instance) anyerror!DOMString {
        return try PaymentMethodChangeEventImpl.get_methodName(instance);
    }

    pub fn get_methodDetails(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try PaymentMethodChangeEventImpl.get_methodDetails(instance);
    }
};
