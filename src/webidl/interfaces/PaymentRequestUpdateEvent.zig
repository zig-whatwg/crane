//! Generated from: payment-request.idl
//! Generated at: 2025-11-28T03:24:38Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PaymentRequestUpdateEventImpl = @import("impls").PaymentRequestUpdateEvent;
const Event = @import("interfaces").Event;
const PaymentDetailsUpdate = @import("dictionaries").PaymentDetailsUpdate;
const PaymentRequestUpdateEventInit = @import("dictionaries").PaymentRequestUpdateEventInit;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const PaymentRequestUpdateEvent = struct {
    pub const Meta = struct {
        pub const name = "PaymentRequestUpdateEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "updateWith", "call_updateWith", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "updateWith",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
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
            _internal: ?*PaymentRequestUpdateEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_updateWith = &call_updateWith,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PaymentRequestUpdateEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PaymentRequestUpdateEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: PaymentRequestUpdateEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try PaymentRequestUpdateEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn call_updateWith(instance: *runtime.Instance, detailsPromise: *const anyopaque) anyerror!void {
        
        return try PaymentRequestUpdateEventImpl.call_updateWith(instance, detailsPromise);
    }

};
