//! Generated from: payment-request.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PaymentRequestImpl = @import("impls").PaymentRequest;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const EventHandler = @import("typedefs").EventHandler;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const PaymentMethodData = @import("dictionaries").PaymentMethodData;
const PaymentShippingType = @import("enums").PaymentShippingType;
const SecurePaymentConfirmationAvailability = @import("enums").SecurePaymentConfirmationAvailability;
const PaymentOptions = @import("dictionaries").PaymentOptions;
const Observable = @import("interfaces").Observable;
const SecurePaymentConfirmationCapabilities = @import("typedefs").SecurePaymentConfirmationCapabilities;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const PaymentDetailsInit = @import("dictionaries").PaymentDetailsInit;
const EventListener = @import("interfaces").EventListener;
const PaymentResponse = @import("interfaces").PaymentResponse;
const ContactAddress = @import("interfaces").ContactAddress;
const DOMString = @import("typedefs").DOMString;
const PaymentDetailsUpdate = @import("dictionaries").PaymentDetailsUpdate;

pub const PaymentRequest = struct {
    pub const Meta = struct {
        pub const name = "PaymentRequest";
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
            .{ "id", "get_id", null },
            .{ "shippingAddress", "get_shippingAddress", null },
            .{ "shippingOption", "get_shippingOption", null },
            .{ "shippingType", "get_shippingType", null },
            .{ "onshippingaddresschange", "get_onshippingaddresschange", "set_onshippingaddresschange" },
            .{ "onshippingoptionchange", "get_onshippingoptionchange", "set_onshippingoptionchange" },
            .{ "onpaymentmethodchange", "get_onpaymentmethodchange", "set_onpaymentmethodchange" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "show", "call_show", 0 },
            .{ "abort", "call_abort", 0 },
            .{ "canMakePayment", "call_canMakePayment", 0 },
        };

        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "securePaymentConfirmationAvailability", "call_static_securePaymentConfirmationAvailability", 0 },
            .{ "getSecurePaymentConfirmationCapabilities", "call_static_getSecurePaymentConfirmationCapabilities", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "show",
            "abort",
            "canMakePayment",
            "securePaymentConfirmationAvailability",
            "getSecurePaymentConfirmationCapabilities",
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
            .{ "id", "get_id", null },
            .{ "shippingAddress", "get_shippingAddress", null },
            .{ "shippingOption", "get_shippingOption", null },
            .{ "shippingType", "get_shippingType", null },
            .{ "onshippingaddresschange", "get_onshippingaddresschange", "set_onshippingaddresschange" },
            .{ "onshippingoptionchange", "get_onshippingoptionchange", "set_onshippingoptionchange" },
            .{ "onpaymentmethodchange", "get_onpaymentmethodchange", "set_onpaymentmethodchange" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            id: runtime.DOMString = undefined,
            shippingAddress: ?*runtime.Instance = null,
            shippingOption: ?runtime.DOMString = null,
            shippingType: ?enums.PaymentShippingType = null,
            onshippingaddresschange: typedefs.EventHandler = undefined,
            onshippingoptionchange: typedefs.EventHandler = undefined,
            onpaymentmethodchange: typedefs.EventHandler = undefined,
            _internal: ?*PaymentRequestImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_id = &get_id,
        .get_onpaymentmethodchange = &get_onpaymentmethodchange,
        .get_onshippingaddresschange = &get_onshippingaddresschange,
        .get_onshippingoptionchange = &get_onshippingoptionchange,
        .get_shippingAddress = &get_shippingAddress,
        .get_shippingOption = &get_shippingOption,
        .get_shippingType = &get_shippingType,

        .set_onpaymentmethodchange = &set_onpaymentmethodchange,
        .set_onshippingaddresschange = &set_onshippingaddresschange,
        .set_onshippingoptionchange = &set_onshippingoptionchange,

        .call_abort = &call_abort,
        .call_canMakePayment = &call_canMakePayment,
        .call_show = &call_show,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("PaymentRequest has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(PaymentRequestImpl, "init") and @hasDecl(PaymentRequestImpl, "initOwn")) @compileError("PaymentRequestImpl defines both init and initOwn");
        if (comptime @hasDecl(PaymentRequestImpl, "init")) return PaymentRequestImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(PaymentRequestImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try PaymentRequestImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(PaymentRequestImpl, "init")) return false;
        if (comptime @hasDecl(PaymentRequestImpl, "construction_args")) {
            inline for (PaymentRequestImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(PaymentRequestImpl, "deinit") and @hasDecl(PaymentRequestImpl, "deinitOwn")) @compileError("PaymentRequestImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(PaymentRequestImpl, "deinit")) return PaymentRequestImpl.deinit(instance);
        if (comptime @hasDecl(PaymentRequestImpl, "deinitOwn")) PaymentRequestImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "PaymentRequest")) {
            if (comptime @hasDecl(impls.PaymentRequest, "installHooks")) impls.PaymentRequest.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 2;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, methodData: runtime.JSValue, details: PaymentDetailsInit, options: webidl.Opt(PaymentOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try PaymentRequestImpl.call_constructor(ctx, methodData, details, options);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try PaymentRequestImpl.get_id(instance);
    }

    pub fn get_shippingAddress(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try PaymentRequestImpl.get_shippingAddress(instance);
    }

    pub fn get_shippingOption(instance: *runtime.Instance) anyerror!?runtime.DOMString {
        return try PaymentRequestImpl.get_shippingOption(instance);
    }

    pub fn get_shippingType(instance: *runtime.Instance) anyerror!?PaymentShippingType {
        return try PaymentRequestImpl.get_shippingType(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onshippingaddresschange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(PaymentRequestImpl, "get_onshippingaddresschange")) return try PaymentRequestImpl.get_onshippingaddresschange(instance);
        return event_handlers.value(EventHandler, instance, "onshippingaddresschange");
    }

    pub fn set_onshippingaddresschange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(PaymentRequestImpl, "set_onshippingaddresschange")) return try PaymentRequestImpl.set_onshippingaddresschange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onshippingaddresschange", value);
    }

    pub fn get_onshippingoptionchange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(PaymentRequestImpl, "get_onshippingoptionchange")) return try PaymentRequestImpl.get_onshippingoptionchange(instance);
        return event_handlers.value(EventHandler, instance, "onshippingoptionchange");
    }

    pub fn set_onshippingoptionchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(PaymentRequestImpl, "set_onshippingoptionchange")) return try PaymentRequestImpl.set_onshippingoptionchange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onshippingoptionchange", value);
    }

    pub fn get_onpaymentmethodchange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(PaymentRequestImpl, "get_onpaymentmethodchange")) return try PaymentRequestImpl.get_onpaymentmethodchange(instance);
        return event_handlers.value(EventHandler, instance, "onpaymentmethodchange");
    }

    pub fn set_onpaymentmethodchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(PaymentRequestImpl, "set_onpaymentmethodchange")) return try PaymentRequestImpl.set_onpaymentmethodchange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onpaymentmethodchange", value);
    }

    /// Extended attributes: [NewObject]
    pub fn call_abort(instance: *runtime.Instance) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        return try PaymentRequestImpl.call_abort(instance);
    }

    pub fn call_static_getSecurePaymentConfirmationCapabilities(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PaymentRequestImpl.call_static_getSecurePaymentConfirmationCapabilities(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_canMakePayment(instance: *runtime.Instance) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        return try PaymentRequestImpl.call_canMakePayment(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_show(instance: *runtime.Instance, detailsPromise: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object

        return try PaymentRequestImpl.call_show(instance, detailsPromise);
    }

    pub fn call_static_securePaymentConfirmationAvailability(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PaymentRequestImpl.call_static_securePaymentConfirmationAvailability(instance);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{ "set_onshippingaddresschange", "set_onshippingoptionchange", "set_onpaymentmethodchange" };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_abort",
        "call_static_getSecurePaymentConfirmationCapabilities",
        "call_canMakePayment",
        "call_show",
        "call_static_securePaymentConfirmationAvailability",
    };
};
