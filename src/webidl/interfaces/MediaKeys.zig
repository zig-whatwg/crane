//! Generated from: encrypted-media.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaKeysImpl = @import("impls").MediaKeys;
const MediaKeySession = @import("interfaces").MediaKeySession;
const Promise<boolean> = @import("interfaces").Promise<boolean>;
const MediaKeySessionType = @import("enums").MediaKeySessionType;
const Promise<MediaKeyStatus> = @import("interfaces").Promise<MediaKeyStatus>;
const MediaKeysPolicy = @import("dictionaries").MediaKeysPolicy;
const BufferSource = @import("typedefs").BufferSource;

pub const MediaKeys = struct {
    pub const Meta = struct {
        pub const name = "MediaKeys";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MediaKeys, .{
        .deinit_fn = &deinit_wrapper,

        .call_createSession = &call_createSession,
        .call_getStatusForPolicy = &call_getStatusForPolicy,
        .call_setServerCertificate = &call_setServerCertificate,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        MediaKeysImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaKeysImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_setServerCertificate(instance: *runtime.Instance, serverCertificate: BufferSource) anyerror!anyopaque {
        
        return try MediaKeysImpl.call_setServerCertificate(instance, serverCertificate);
    }

    pub fn call_createSession(instance: *runtime.Instance, sessionType: MediaKeySessionType) anyerror!MediaKeySession {
        
        return try MediaKeysImpl.call_createSession(instance, sessionType);
    }

    pub fn call_getStatusForPolicy(instance: *runtime.Instance, policy: MediaKeysPolicy) anyerror!anyopaque {
        
        return try MediaKeysImpl.call_getStatusForPolicy(instance, policy);
    }

};
