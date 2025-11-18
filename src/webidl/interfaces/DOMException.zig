//! Generated from: webidl.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DOMExceptionImpl = @import("impls").DOMException;

pub const DOMException = struct {
    pub const Meta = struct {
        pub const name = "DOMException";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
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
            name: runtime.DOMString = undefined,
            message: runtime.DOMString = undefined,
            code: u16 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short INDEX_SIZE_ERR = 1;
    pub fn get_INDEX_SIZE_ERR() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short DOMSTRING_SIZE_ERR = 2;
    pub fn get_DOMSTRING_SIZE_ERR() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short HIERARCHY_REQUEST_ERR = 3;
    pub fn get_HIERARCHY_REQUEST_ERR() u16 {
        return 3;
    }

    /// WebIDL constant: const unsigned short WRONG_DOCUMENT_ERR = 4;
    pub fn get_WRONG_DOCUMENT_ERR() u16 {
        return 4;
    }

    /// WebIDL constant: const unsigned short INVALID_CHARACTER_ERR = 5;
    pub fn get_INVALID_CHARACTER_ERR() u16 {
        return 5;
    }

    /// WebIDL constant: const unsigned short NO_DATA_ALLOWED_ERR = 6;
    pub fn get_NO_DATA_ALLOWED_ERR() u16 {
        return 6;
    }

    /// WebIDL constant: const unsigned short NO_MODIFICATION_ALLOWED_ERR = 7;
    pub fn get_NO_MODIFICATION_ALLOWED_ERR() u16 {
        return 7;
    }

    /// WebIDL constant: const unsigned short NOT_FOUND_ERR = 8;
    pub fn get_NOT_FOUND_ERR() u16 {
        return 8;
    }

    /// WebIDL constant: const unsigned short NOT_SUPPORTED_ERR = 9;
    pub fn get_NOT_SUPPORTED_ERR() u16 {
        return 9;
    }

    /// WebIDL constant: const unsigned short INUSE_ATTRIBUTE_ERR = 10;
    pub fn get_INUSE_ATTRIBUTE_ERR() u16 {
        return 10;
    }

    /// WebIDL constant: const unsigned short INVALID_STATE_ERR = 11;
    pub fn get_INVALID_STATE_ERR() u16 {
        return 11;
    }

    /// WebIDL constant: const unsigned short SYNTAX_ERR = 12;
    pub fn get_SYNTAX_ERR() u16 {
        return 12;
    }

    /// WebIDL constant: const unsigned short INVALID_MODIFICATION_ERR = 13;
    pub fn get_INVALID_MODIFICATION_ERR() u16 {
        return 13;
    }

    /// WebIDL constant: const unsigned short NAMESPACE_ERR = 14;
    pub fn get_NAMESPACE_ERR() u16 {
        return 14;
    }

    /// WebIDL constant: const unsigned short INVALID_ACCESS_ERR = 15;
    pub fn get_INVALID_ACCESS_ERR() u16 {
        return 15;
    }

    /// WebIDL constant: const unsigned short VALIDATION_ERR = 16;
    pub fn get_VALIDATION_ERR() u16 {
        return 16;
    }

    /// WebIDL constant: const unsigned short TYPE_MISMATCH_ERR = 17;
    pub fn get_TYPE_MISMATCH_ERR() u16 {
        return 17;
    }

    /// WebIDL constant: const unsigned short SECURITY_ERR = 18;
    pub fn get_SECURITY_ERR() u16 {
        return 18;
    }

    /// WebIDL constant: const unsigned short NETWORK_ERR = 19;
    pub fn get_NETWORK_ERR() u16 {
        return 19;
    }

    /// WebIDL constant: const unsigned short ABORT_ERR = 20;
    pub fn get_ABORT_ERR() u16 {
        return 20;
    }

    /// WebIDL constant: const unsigned short URL_MISMATCH_ERR = 21;
    pub fn get_URL_MISMATCH_ERR() u16 {
        return 21;
    }

    /// WebIDL constant: const unsigned short QUOTA_EXCEEDED_ERR = 22;
    pub fn get_QUOTA_EXCEEDED_ERR() u16 {
        return 22;
    }

    /// WebIDL constant: const unsigned short TIMEOUT_ERR = 23;
    pub fn get_TIMEOUT_ERR() u16 {
        return 23;
    }

    /// WebIDL constant: const unsigned short INVALID_NODE_TYPE_ERR = 24;
    pub fn get_INVALID_NODE_TYPE_ERR() u16 {
        return 24;
    }

    /// WebIDL constant: const unsigned short DATA_CLONE_ERR = 25;
    pub fn get_DATA_CLONE_ERR() u16 {
        return 25;
    }

    pub const vtable = runtime.buildVTable(DOMException, .{
        .deinit_fn = &deinit_wrapper,

        .get_ABORT_ERR = &get_ABORT_ERR,
        .get_DATA_CLONE_ERR = &get_DATA_CLONE_ERR,
        .get_DOMSTRING_SIZE_ERR = &get_DOMSTRING_SIZE_ERR,
        .get_HIERARCHY_REQUEST_ERR = &get_HIERARCHY_REQUEST_ERR,
        .get_INDEX_SIZE_ERR = &get_INDEX_SIZE_ERR,
        .get_INUSE_ATTRIBUTE_ERR = &get_INUSE_ATTRIBUTE_ERR,
        .get_INVALID_ACCESS_ERR = &get_INVALID_ACCESS_ERR,
        .get_INVALID_CHARACTER_ERR = &get_INVALID_CHARACTER_ERR,
        .get_INVALID_MODIFICATION_ERR = &get_INVALID_MODIFICATION_ERR,
        .get_INVALID_NODE_TYPE_ERR = &get_INVALID_NODE_TYPE_ERR,
        .get_INVALID_STATE_ERR = &get_INVALID_STATE_ERR,
        .get_NAMESPACE_ERR = &get_NAMESPACE_ERR,
        .get_NETWORK_ERR = &get_NETWORK_ERR,
        .get_NOT_FOUND_ERR = &get_NOT_FOUND_ERR,
        .get_NOT_SUPPORTED_ERR = &get_NOT_SUPPORTED_ERR,
        .get_NO_DATA_ALLOWED_ERR = &get_NO_DATA_ALLOWED_ERR,
        .get_NO_MODIFICATION_ALLOWED_ERR = &get_NO_MODIFICATION_ALLOWED_ERR,
        .get_QUOTA_EXCEEDED_ERR = &get_QUOTA_EXCEEDED_ERR,
        .get_SECURITY_ERR = &get_SECURITY_ERR,
        .get_SYNTAX_ERR = &get_SYNTAX_ERR,
        .get_TIMEOUT_ERR = &get_TIMEOUT_ERR,
        .get_TYPE_MISMATCH_ERR = &get_TYPE_MISMATCH_ERR,
        .get_URL_MISMATCH_ERR = &get_URL_MISMATCH_ERR,
        .get_VALIDATION_ERR = &get_VALIDATION_ERR,
        .get_WRONG_DOCUMENT_ERR = &get_WRONG_DOCUMENT_ERR,
        .get_code = &get_code,
        .get_message = &get_message,
        .get_name = &get_name,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        DOMExceptionImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DOMExceptionImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, message: DOMString, name: DOMString) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try DOMExceptionImpl.constructor(instance, message, name);
        
        return instance;
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try DOMExceptionImpl.get_name(instance);
    }

    pub fn get_message(instance: *runtime.Instance) anyerror!DOMString {
        return try DOMExceptionImpl.get_message(instance);
    }

    pub fn get_code(instance: *runtime.Instance) anyerror!u16 {
        return try DOMExceptionImpl.get_code(instance);
    }

};
