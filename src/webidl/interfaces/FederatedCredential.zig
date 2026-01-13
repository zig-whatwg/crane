//! Generated from: credential-management.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const FederatedCredentialImpl = @import("impls").FederatedCredential;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Credential = @import("Credential.zig").Credential;
const CredentialUserData = @import("mixins").CredentialUserData;
const USVString = @import("typedefs").USVString;
const FederatedCredentialInit = @import("dictionaries").FederatedCredentialInit;
const DOMString = @import("typedefs").DOMString;

pub const FederatedCredential = struct {
    pub const Meta = struct {
        pub const name = "FederatedCredential";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Credential.State;
        pub const ParentInterface = Credential;
        pub const MixinTypes = &.{
            CredentialUserData,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "provider", "get_provider", null },
            .{ "protocol", "get_protocol", null },
            .{ "name", "get_name", null },
            .{ "iconURL", "get_iconURL", null },
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
            .{ "provider", "get_provider", null },
            .{ "protocol", "get_protocol", null },
            .{ "name", "get_name", null },
            .{ "iconURL", "get_iconURL", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            provider: runtime.USVString = undefined,
            protocol: ?typedefs.DOMString = null,
            name: runtime.USVString = undefined,
            iconURL: runtime.USVString = undefined,
            _internal: ?*FederatedCredentialImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_iconURL = &get_iconURL,
        .get_name = &get_name,
        .get_protocol = &get_protocol,
        .get_provider = &get_provider,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FederatedCredentialImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return FederatedCredentialImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FederatedCredentialImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, data: FederatedCredentialInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try FederatedCredentialImpl.call_constructor(ctx, data);
    }

    pub fn get_provider(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FederatedCredentialImpl.get_provider(instance);
    }

    pub fn get_protocol(instance: *runtime.Instance) anyerror!?DOMString {
        return try FederatedCredentialImpl.get_protocol(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FederatedCredentialImpl.get_name(instance);
    }

    pub fn get_iconURL(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FederatedCredentialImpl.get_iconURL(instance);
    }

};
