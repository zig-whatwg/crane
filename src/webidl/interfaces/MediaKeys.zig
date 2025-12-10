//! Generated from: encrypted-media.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MediaKeysImpl = @import("impls").MediaKeys;
const mixins = @import("mixins");
const MediaKeySession = @import("interfaces").MediaKeySession;
const MediaKeySessionType = @import("enums").MediaKeySessionType;
const MediaKeyStatus = @import("enums").MediaKeyStatus;
const MediaKeysPolicy = @import("dictionaries").MediaKeysPolicy;
const BufferSource = @import("typedefs").BufferSource;

pub const MediaKeys = struct {
    pub const Meta = struct {
        pub const name = "MediaKeys";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "createSession", "call_createSession", 0 },
            .{ "getStatusForPolicy", "call_getStatusForPolicy", 0 },
            .{ "setServerCertificate", "call_setServerCertificate", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "createSession",
            "getStatusForPolicy",
            "setServerCertificate",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
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
            _internal: ?*MediaKeysImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_createSession = &call_createSession,
        .call_getStatusForPolicy = &call_getStatusForPolicy,
        .call_setServerCertificate = &call_setServerCertificate,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MediaKeysImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return MediaKeysImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaKeysImpl.deinit(instance);
    }

    pub fn call_setServerCertificate(instance: *runtime.Instance, serverCertificate: BufferSource) anyerror!runtime.JSValue {
        
        return try MediaKeysImpl.call_setServerCertificate(instance, serverCertificate);
    }

    pub fn call_createSession(instance: *runtime.Instance, sessionType: webidl.Opt(MediaKeySessionType)) anyerror!*runtime.Instance {
        
        return try MediaKeysImpl.call_createSession(instance, sessionType);
    }

    pub fn call_getStatusForPolicy(instance: *runtime.Instance, policy: webidl.Opt(MediaKeysPolicy)) anyerror!runtime.JSValue {
        
        return try MediaKeysImpl.call_getStatusForPolicy(instance, policy);
    }

};
