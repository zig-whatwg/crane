//! Generated from: web-smart-card.idl
//! Generated at: 2025-11-28T18:02:25Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SmartCardErrorImpl = @import("impls").SmartCardError;
const DOMException = @import("interfaces").DOMException;
const SmartCardErrorOptions = @import("dictionaries").SmartCardErrorOptions;
const SmartCardResponseCode = @import("enums").SmartCardResponseCode;
const DOMString = @import("typedefs").DOMString;

pub const SmartCardError = struct {
    pub const Meta = struct {
        pub const name = "SmartCardError";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *DOMException;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "DedicatedWorker", "SharedWorker", "Window" } } },
            .{ .name = "SecureContext" },
            .{ .name = "IsolatedContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .DedicatedWorker = true,
            .SharedWorker = true,
            .Window = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "responseCode", "get_responseCode", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "responseCode", "get_responseCode", null },
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
            responseCode: SmartCardResponseCode = undefined,
            _internal: ?*SmartCardErrorImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_responseCode = &get_responseCode,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SmartCardErrorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SmartCardErrorImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, message: DOMString, options: SmartCardErrorOptions) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try SmartCardErrorImpl.call_constructor(allocator, ctx, message, options);
    }

    pub fn get_responseCode(instance: *runtime.Instance) anyerror!SmartCardResponseCode {
        return try SmartCardErrorImpl.get_responseCode(instance);
    }

};
