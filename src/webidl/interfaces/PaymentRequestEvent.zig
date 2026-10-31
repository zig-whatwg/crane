//! Generated from: web-based-payment-handler.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PaymentRequestEventImpl = @import("impls").PaymentRequestEvent;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ExtendableEvent = @import("interfaces").ExtendableEvent;
const PaymentMethodData = @import("dictionaries").PaymentMethodData;
const WindowClient = @import("interfaces").WindowClient;
const PaymentShippingOption = @import("dictionaries").PaymentShippingOption;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const PaymentRequestEventInit = @import("dictionaries").PaymentRequestEventInit;
const AddressInit = @import("dictionaries").AddressInit;
const USVString = @import("typedefs").USVString;
const ExtendableEventInit = @import("dictionaries").ExtendableEventInit;
const EventTarget = @import("interfaces").EventTarget;
const PaymentDetailsModifier = @import("dictionaries").PaymentDetailsModifier;
const EventInit = @import("dictionaries").EventInit;
const PaymentRequestDetailsUpdate = @import("dictionaries").PaymentRequestDetailsUpdate;
const PaymentHandlerResponse = @import("dictionaries").PaymentHandlerResponse;
const DOMString = @import("typedefs").DOMString;

pub const PaymentRequestEvent = struct {
    pub const Meta = struct {
        pub const name = "PaymentRequestEvent";
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
            .{ "topOrigin", "get_topOrigin", null },
            .{ "paymentRequestOrigin", "get_paymentRequestOrigin", null },
            .{ "paymentRequestId", "get_paymentRequestId", null },
            .{ "methodData", "get_methodData", null },
            .{ "total", "get_total", null },
            .{ "modifiers", "get_modifiers", null },
            .{ "paymentOptions", "get_paymentOptions", null },
            .{ "shippingOptions", "get_shippingOptions", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "openWindow", "call_openWindow", 1 },
            .{ "changePaymentMethod", "call_changePaymentMethod", 1 },
            .{ "changeShippingAddress", "call_changeShippingAddress", 0 },
            .{ "changeShippingOption", "call_changeShippingOption", 1 },
            .{ "respondWith", "call_respondWith", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "openWindow",
            "changePaymentMethod",
            "changeShippingAddress",
            "changeShippingOption",
            "respondWith",
        };

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
            .{ "topOrigin", "get_topOrigin", null },
            .{ "paymentRequestOrigin", "get_paymentRequestOrigin", null },
            .{ "paymentRequestId", "get_paymentRequestId", null },
            .{ "methodData", "get_methodData", null },
            .{ "total", "get_total", null },
            .{ "modifiers", "get_modifiers", null },
            .{ "paymentOptions", "get_paymentOptions", null },
            .{ "shippingOptions", "get_shippingOptions", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            topOrigin: runtime.USVString = undefined,
            paymentRequestOrigin: runtime.USVString = undefined,
            paymentRequestId: runtime.DOMString = undefined,
            methodData: runtime.JSValue = undefined,
            total: runtime.JSValue = undefined,
            modifiers: runtime.JSValue = undefined,
            paymentOptions: ?runtime.JSValue = null,
            shippingOptions: ?runtime.JSValue = null,
            _internal: ?*PaymentRequestEventImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_methodData = &get_methodData,
        .get_modifiers = &get_modifiers,
        .get_paymentOptions = &get_paymentOptions,
        .get_paymentRequestId = &get_paymentRequestId,
        .get_paymentRequestOrigin = &get_paymentRequestOrigin,
        .get_shippingOptions = &get_shippingOptions,
        .get_topOrigin = &get_topOrigin,
        .get_total = &get_total,

        .call_changePaymentMethod = &call_changePaymentMethod,
        .call_changeShippingAddress = &call_changeShippingAddress,
        .call_changeShippingOption = &call_changeShippingOption,
        .call_openWindow = &call_openWindow,
        .call_respondWith = &call_respondWith,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("PaymentRequestEvent has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(PaymentRequestEventImpl, "init") and @hasDecl(PaymentRequestEventImpl, "initOwn")) @compileError("PaymentRequestEventImpl defines both init and initOwn");
        if (comptime @hasDecl(PaymentRequestEventImpl, "init")) return PaymentRequestEventImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(PaymentRequestEventImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try PaymentRequestEventImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(PaymentRequestEventImpl, "init")) return false;
        if (comptime @hasDecl(PaymentRequestEventImpl, "construction_args")) {
            inline for (PaymentRequestEventImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(PaymentRequestEventImpl, "deinit") and @hasDecl(PaymentRequestEventImpl, "deinitOwn")) @compileError("PaymentRequestEventImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(PaymentRequestEventImpl, "deinit")) return PaymentRequestEventImpl.deinit(instance);
        if (comptime @hasDecl(PaymentRequestEventImpl, "deinitOwn")) PaymentRequestEventImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "PaymentRequestEvent")) {
            if (comptime @hasDecl(impls.PaymentRequestEvent, "installHooks")) impls.PaymentRequestEvent.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 1;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(PaymentRequestEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try PaymentRequestEventImpl.call_constructor(ctx, @"type", eventInitDict);
    }

    pub fn get_topOrigin(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try PaymentRequestEventImpl.get_topOrigin(instance);
    }

    pub fn get_paymentRequestOrigin(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try PaymentRequestEventImpl.get_paymentRequestOrigin(instance);
    }

    pub fn get_paymentRequestId(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try PaymentRequestEventImpl.get_paymentRequestId(instance);
    }

    pub fn get_methodData(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PaymentRequestEventImpl.get_methodData(instance);
    }

    pub fn get_total(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PaymentRequestEventImpl.get_total(instance);
    }

    pub fn get_modifiers(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PaymentRequestEventImpl.get_modifiers(instance);
    }

    pub fn get_paymentOptions(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try PaymentRequestEventImpl.get_paymentOptions(instance);
    }

    pub fn get_shippingOptions(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try PaymentRequestEventImpl.get_shippingOptions(instance);
    }

    pub fn call_respondWith(instance: *runtime.Instance, handlerResponsePromise: runtime.JSValue) anyerror!void {
        return try PaymentRequestEventImpl.call_respondWith(instance, handlerResponsePromise);
    }

    pub fn call_openWindow(instance: *runtime.Instance, url: runtime.USVString) anyerror!runtime.JSValue {
        return try PaymentRequestEventImpl.call_openWindow(instance, url);
    }

    pub fn call_changeShippingOption(instance: *runtime.Instance, shippingOption: runtime.DOMString) anyerror!runtime.JSValue {
        return try PaymentRequestEventImpl.call_changeShippingOption(instance, shippingOption);
    }

    pub fn call_changeShippingAddress(instance: *runtime.Instance, shippingAddress: webidl.Opt(AddressInit)) anyerror!runtime.JSValue {
        return try PaymentRequestEventImpl.call_changeShippingAddress(instance, shippingAddress);
    }

    pub fn call_changePaymentMethod(instance: *runtime.Instance, methodName: runtime.DOMString, methodDetails: webidl.Opt(?runtime.JSValue)) anyerror!runtime.JSValue {
        return try PaymentRequestEventImpl.call_changePaymentMethod(instance, methodName, methodDetails);
    }

    /// WebIDL `object` arguments (or sequences of `object`): a value that is
    /// not an Object throws a TypeError (bit i = argument i).
    pub const object_arguments = .{
        .{ "call_changePaymentMethod", 0b10 },
    };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_openWindow",
        "call_changeShippingOption",
        "call_changeShippingAddress",
        "call_changePaymentMethod",
    };
};
