//! Generated from: digital-credentials.idl
//! Generated at: 2025-11-29T11:15:56Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DigitalCredentialImpl = @import("impls").DigitalCredential;
const mixins = @import("mixins");
const Credential = @import("interfaces").Credential;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const DigitalCredential = struct {
    pub const Meta = struct {
        pub const name = "DigitalCredential";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Credential.State;
        pub const ParentInterface = Credential;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "protocol", "get_protocol", null },
            .{ "data", "get_data", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "toJSON", "call_toJSON", 0 },
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "userAgentAllowsProtocol", "call_userAgentAllowsProtocol", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toJSON",
            "userAgentAllowsProtocol",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "isConditionalMediationAvailable",
            "willRequestConditionalCreation",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "protocol", "get_protocol", null },
            .{ "data", "get_data", null },
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
            protocol: runtime.DOMString = undefined,
            data: *const anyopaque = undefined,
            cached_data: ?*const anyopaque = null,
            _internal: ?*DigitalCredentialImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_data = &get_data,
        .get_protocol = &get_protocol,

        .call_toJSON = &call_toJSON,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DigitalCredentialImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DigitalCredentialImpl.deinit(instance);
    }

    pub fn get_protocol(instance: *runtime.Instance) anyerror!DOMString {
        return try DigitalCredentialImpl.get_protocol(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_data(instance: *runtime.Instance) anyerror!*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_data) |cached| {
            return cached;
        }
        const value = try DigitalCredentialImpl.get_data(instance);
        state.own.cached_data = value;
        return value;
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try DigitalCredentialImpl.call_toJSON(instance);
    }

    pub fn call_userAgentAllowsProtocol(instance: *runtime.Instance, protocol: DOMString) anyerror!bool {
        
        return try DigitalCredentialImpl.call_userAgentAllowsProtocol(instance, protocol);
    }

};
