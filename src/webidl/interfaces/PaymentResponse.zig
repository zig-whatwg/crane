//! Generated from: payment-request.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PaymentResponseImpl = @import("impls").PaymentResponse;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const PaymentComplete = @import("enums").PaymentComplete;
const PaymentValidationErrors = @import("dictionaries").PaymentValidationErrors;
const PaymentCompleteDetails = @import("dictionaries").PaymentCompleteDetails;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const ContactAddress = @import("interfaces").ContactAddress;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const PaymentResponse = struct {
    pub const Meta = struct {
        pub const name = "PaymentResponse";
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
            .{ "requestId", "get_requestId", null },
            .{ "methodName", "get_methodName", null },
            .{ "details", "get_details", null },
            .{ "shippingAddress", "get_shippingAddress", null },
            .{ "shippingOption", "get_shippingOption", null },
            .{ "payerName", "get_payerName", null },
            .{ "payerEmail", "get_payerEmail", null },
            .{ "payerPhone", "get_payerPhone", null },
            .{ "onpayerdetailchange", "get_onpayerdetailchange", "set_onpayerdetailchange" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "toJSON", "call_toJSON", 0 },
            .{ "complete", "call_complete", 0 },
            .{ "retry", "call_retry", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toJSON",
            "complete",
            "retry",
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
            .{ "requestId", "get_requestId", null },
            .{ "methodName", "get_methodName", null },
            .{ "details", "get_details", null },
            .{ "shippingAddress", "get_shippingAddress", null },
            .{ "shippingOption", "get_shippingOption", null },
            .{ "payerName", "get_payerName", null },
            .{ "payerEmail", "get_payerEmail", null },
            .{ "payerPhone", "get_payerPhone", null },
            .{ "onpayerdetailchange", "get_onpayerdetailchange", "set_onpayerdetailchange" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            requestId: typedefs.DOMString = undefined,
            methodName: typedefs.DOMString = undefined,
            details: runtime.JSValue = undefined,
            shippingAddress: ?*runtime.Instance = null,
            shippingOption: ?typedefs.DOMString = null,
            payerName: ?typedefs.DOMString = null,
            payerEmail: ?typedefs.DOMString = null,
            payerPhone: ?typedefs.DOMString = null,
            onpayerdetailchange: typedefs.EventHandler = undefined,
            _internal: ?*PaymentResponseImpl.InternalState = null,
        },
    );

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for PaymentResponse
    /// Generated from [Default] toJSON extended attribute
    pub const PaymentResponseToJSON = struct {
        requestId: runtime.DOMString,
        methodName: runtime.DOMString,
        details: runtime.JSValue,
        shippingAddress: ?*runtime.Instance,
        shippingOption: ?runtime.DOMString,
        payerName: ?runtime.DOMString,
        payerEmail: ?runtime.DOMString,
        payerPhone: ?runtime.DOMString,
        onpayerdetailchange: EventHandler,

        pub const default_to_json = true;
    };

    const delegates = .{
        .get_details = &get_details,
        .get_methodName = &get_methodName,
        .get_onpayerdetailchange = &get_onpayerdetailchange,
        .get_payerEmail = &get_payerEmail,
        .get_payerName = &get_payerName,
        .get_payerPhone = &get_payerPhone,
        .get_requestId = &get_requestId,
        .get_shippingAddress = &get_shippingAddress,
        .get_shippingOption = &get_shippingOption,

        .set_onpayerdetailchange = &set_onpayerdetailchange,

        .call_complete = &call_complete,
        .call_retry = &call_retry,
        .call_toJSON = &call_toJSON,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("PaymentResponse has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(PaymentResponseImpl, "init") and @hasDecl(PaymentResponseImpl, "initOwn")) @compileError("PaymentResponseImpl defines both init and initOwn");
        if (comptime @hasDecl(PaymentResponseImpl, "init")) return PaymentResponseImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(PaymentResponseImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try PaymentResponseImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(PaymentResponseImpl, "init")) return false;
        if (comptime @hasDecl(PaymentResponseImpl, "construction_args")) {
            inline for (PaymentResponseImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(PaymentResponseImpl, "deinit") and @hasDecl(PaymentResponseImpl, "deinitOwn")) @compileError("PaymentResponseImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(PaymentResponseImpl, "deinit")) return PaymentResponseImpl.deinit(instance);
        if (comptime @hasDecl(PaymentResponseImpl, "deinitOwn")) PaymentResponseImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "PaymentResponse")) {
            if (comptime @hasDecl(impls.PaymentResponse, "installHooks")) impls.PaymentResponse.installHooks();
        }
    }

    pub fn get_requestId(instance: *runtime.Instance) anyerror!DOMString {
        return try PaymentResponseImpl.get_requestId(instance);
    }

    pub fn get_methodName(instance: *runtime.Instance) anyerror!DOMString {
        return try PaymentResponseImpl.get_methodName(instance);
    }

    pub fn get_details(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PaymentResponseImpl.get_details(instance);
    }

    pub fn get_shippingAddress(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try PaymentResponseImpl.get_shippingAddress(instance);
    }

    pub fn get_shippingOption(instance: *runtime.Instance) anyerror!?DOMString {
        return try PaymentResponseImpl.get_shippingOption(instance);
    }

    pub fn get_payerName(instance: *runtime.Instance) anyerror!?DOMString {
        return try PaymentResponseImpl.get_payerName(instance);
    }

    pub fn get_payerEmail(instance: *runtime.Instance) anyerror!?DOMString {
        return try PaymentResponseImpl.get_payerEmail(instance);
    }

    pub fn get_payerPhone(instance: *runtime.Instance) anyerror!?DOMString {
        return try PaymentResponseImpl.get_payerPhone(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onpayerdetailchange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(PaymentResponseImpl, "get_onpayerdetailchange")) return try PaymentResponseImpl.get_onpayerdetailchange(instance);
        return event_handlers.value(EventHandler, instance, "onpayerdetailchange");
    }

    pub fn set_onpayerdetailchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(PaymentResponseImpl, "set_onpayerdetailchange")) return try PaymentResponseImpl.set_onpayerdetailchange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onpayerdetailchange", value);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!PaymentResponseToJSON {
        return try PaymentResponseImpl.call_toJSON(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_complete(instance: *runtime.Instance, result: webidl.Opt(PaymentComplete), details: webidl.Opt(PaymentCompleteDetails)) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object

        return try PaymentResponseImpl.call_complete(instance, result, details);
    }

    /// Extended attributes: [NewObject]
    pub fn call_retry(instance: *runtime.Instance, errorFields: webidl.Opt(PaymentValidationErrors)) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object

        return try PaymentResponseImpl.call_retry(instance, errorFields);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_complete",
        "call_retry",
    };
};
