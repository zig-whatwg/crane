//! Generated from: payment-request.idl
//! Generated at: 2025-11-29T11:15:55Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PaymentMethodChangeEventImpl = @import("impls").PaymentMethodChangeEvent;
const mixins = @import("mixins");
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
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
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
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            methodName: runtime.DOMString = undefined,
            methodDetails: ?*const anyopaque = null,
            _internal: ?*PaymentMethodChangeEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_methodDetails = &get_methodDetails,
        .get_methodName = &get_methodName,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PaymentMethodChangeEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PaymentMethodChangeEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: webidl.Opt(PaymentMethodChangeEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try PaymentMethodChangeEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_methodName(instance: *runtime.Instance) anyerror!DOMString {
        return try PaymentMethodChangeEventImpl.get_methodName(instance);
    }

    pub fn get_methodDetails(instance: *runtime.Instance) anyerror!?*const anyopaque {
        return try PaymentMethodChangeEventImpl.get_methodDetails(instance);
    }

};
