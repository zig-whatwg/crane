//! Generated from: webidl.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const QuotaExceededErrorImpl = @import("../impls/QuotaExceededError.zig");
const DOMException = @import("DOMException.zig");

pub const QuotaExceededError = struct {
    pub const Meta = struct {
        pub const name = "QuotaExceededError";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *DOMException;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
            .{ .name = "Serializable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
    };

    pub const State = runtime.FlattenedState(
        struct {
            quota: ?f64 = null,
            requested: ?f64 = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(QuotaExceededError, .{
        .deinit_fn = &deinit_wrapper,

        .get_ABORT_ERR = &DOMException.get_ABORT_ERR,
        .get_DATA_CLONE_ERR = &DOMException.get_DATA_CLONE_ERR,
        .get_DOMSTRING_SIZE_ERR = &DOMException.get_DOMSTRING_SIZE_ERR,
        .get_HIERARCHY_REQUEST_ERR = &DOMException.get_HIERARCHY_REQUEST_ERR,
        .get_INDEX_SIZE_ERR = &DOMException.get_INDEX_SIZE_ERR,
        .get_INUSE_ATTRIBUTE_ERR = &DOMException.get_INUSE_ATTRIBUTE_ERR,
        .get_INVALID_ACCESS_ERR = &DOMException.get_INVALID_ACCESS_ERR,
        .get_INVALID_CHARACTER_ERR = &DOMException.get_INVALID_CHARACTER_ERR,
        .get_INVALID_MODIFICATION_ERR = &DOMException.get_INVALID_MODIFICATION_ERR,
        .get_INVALID_NODE_TYPE_ERR = &DOMException.get_INVALID_NODE_TYPE_ERR,
        .get_INVALID_STATE_ERR = &DOMException.get_INVALID_STATE_ERR,
        .get_NAMESPACE_ERR = &DOMException.get_NAMESPACE_ERR,
        .get_NETWORK_ERR = &DOMException.get_NETWORK_ERR,
        .get_NOT_FOUND_ERR = &DOMException.get_NOT_FOUND_ERR,
        .get_NOT_SUPPORTED_ERR = &DOMException.get_NOT_SUPPORTED_ERR,
        .get_NO_DATA_ALLOWED_ERR = &DOMException.get_NO_DATA_ALLOWED_ERR,
        .get_NO_MODIFICATION_ALLOWED_ERR = &DOMException.get_NO_MODIFICATION_ALLOWED_ERR,
        .get_QUOTA_EXCEEDED_ERR = &DOMException.get_QUOTA_EXCEEDED_ERR,
        .get_SECURITY_ERR = &DOMException.get_SECURITY_ERR,
        .get_SYNTAX_ERR = &DOMException.get_SYNTAX_ERR,
        .get_TIMEOUT_ERR = &DOMException.get_TIMEOUT_ERR,
        .get_TYPE_MISMATCH_ERR = &DOMException.get_TYPE_MISMATCH_ERR,
        .get_URL_MISMATCH_ERR = &DOMException.get_URL_MISMATCH_ERR,
        .get_VALIDATION_ERR = &DOMException.get_VALIDATION_ERR,
        .get_WRONG_DOCUMENT_ERR = &DOMException.get_WRONG_DOCUMENT_ERR,
        .get_code = &get_code,
        .get_message = &get_message,
        .get_name = &get_name,
        .get_quota = &get_quota,
        .get_requested = &get_requested,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        QuotaExceededErrorImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        QuotaExceededErrorImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, message: runtime.DOMString, options: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try QuotaExceededErrorImpl.constructor(state, message, options);
        
        return instance;
    }

    pub fn get_name(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return QuotaExceededErrorImpl.get_name(state);
    }

    pub fn get_message(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return QuotaExceededErrorImpl.get_message(state);
    }

    pub fn get_code(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return QuotaExceededErrorImpl.get_code(state);
    }

    pub fn get_quota(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return QuotaExceededErrorImpl.get_quota(state);
    }

    pub fn get_requested(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return QuotaExceededErrorImpl.get_requested(state);
    }

};
