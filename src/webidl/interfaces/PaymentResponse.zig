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
const EventTarget = @import("EventTarget.zig").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const PaymentComplete = @import("enums").PaymentComplete;
const PaymentValidationErrors = @import("dictionaries").PaymentValidationErrors;
const PaymentCompleteDetails = @import("dictionaries").PaymentCompleteDetails;
const Observable = @import("Observable.zig").Observable;
const Event = @import("Event.zig").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("EventListener.zig").EventListener;
const ContactAddress = @import("ContactAddress.zig").ContactAddress;
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
        pub const lazy_properties = .{
        };
        
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
        shippingAddress: *runtime.Instance,
        shippingOption: runtime.DOMString,
        payerName: runtime.DOMString,
        payerEmail: runtime.DOMString,
        payerPhone: runtime.DOMString,
        onpayerdetailchange: EventHandler,
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
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PaymentResponseImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return PaymentResponseImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PaymentResponseImpl.deinit(instance);
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

    pub fn get_onpayerdetailchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try PaymentResponseImpl.get_onpayerdetailchange(instance);
    }

    pub fn set_onpayerdetailchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try PaymentResponseImpl.set_onpayerdetailchange(instance, value);
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

};
