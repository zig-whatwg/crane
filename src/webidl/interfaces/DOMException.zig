//! Generated from: webidl.idl
//! Generated at: 2025-11-25T14:21:39Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DOMExceptionImpl = @import("impls").DOMException;
const DOMString = @import("typedefs").DOMString;

pub const DOMException = struct {
    pub const Meta = struct {
        pub const name = "DOMException";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
            .{ .name = "Serializable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", null },
            .{ "message", "get_message", null },
            .{ "code", "get_code", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "INDEX_SIZE_ERR", "get_INDEX_SIZE_ERR" },
            .{ "DOMSTRING_SIZE_ERR", "get_DOMSTRING_SIZE_ERR" },
            .{ "HIERARCHY_REQUEST_ERR", "get_HIERARCHY_REQUEST_ERR" },
            .{ "WRONG_DOCUMENT_ERR", "get_WRONG_DOCUMENT_ERR" },
            .{ "INVALID_CHARACTER_ERR", "get_INVALID_CHARACTER_ERR" },
            .{ "NO_DATA_ALLOWED_ERR", "get_NO_DATA_ALLOWED_ERR" },
            .{ "NO_MODIFICATION_ALLOWED_ERR", "get_NO_MODIFICATION_ALLOWED_ERR" },
            .{ "NOT_FOUND_ERR", "get_NOT_FOUND_ERR" },
            .{ "NOT_SUPPORTED_ERR", "get_NOT_SUPPORTED_ERR" },
            .{ "INUSE_ATTRIBUTE_ERR", "get_INUSE_ATTRIBUTE_ERR" },
            .{ "INVALID_STATE_ERR", "get_INVALID_STATE_ERR" },
            .{ "SYNTAX_ERR", "get_SYNTAX_ERR" },
            .{ "INVALID_MODIFICATION_ERR", "get_INVALID_MODIFICATION_ERR" },
            .{ "NAMESPACE_ERR", "get_NAMESPACE_ERR" },
            .{ "INVALID_ACCESS_ERR", "get_INVALID_ACCESS_ERR" },
            .{ "VALIDATION_ERR", "get_VALIDATION_ERR" },
            .{ "TYPE_MISMATCH_ERR", "get_TYPE_MISMATCH_ERR" },
            .{ "SECURITY_ERR", "get_SECURITY_ERR" },
            .{ "NETWORK_ERR", "get_NETWORK_ERR" },
            .{ "ABORT_ERR", "get_ABORT_ERR" },
            .{ "URL_MISMATCH_ERR", "get_URL_MISMATCH_ERR" },
            .{ "QUOTA_EXCEEDED_ERR", "get_QUOTA_EXCEEDED_ERR" },
            .{ "TIMEOUT_ERR", "get_TIMEOUT_ERR" },
            .{ "INVALID_NODE_TYPE_ERR", "get_INVALID_NODE_TYPE_ERR" },
            .{ "DATA_CLONE_ERR", "get_DATA_CLONE_ERR" },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "name", "get_name", null },
            .{ "message", "get_message", null },
            .{ "code", "get_code", null },
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
            name: runtime.DOMString = undefined,
            message: runtime.DOMString = undefined,
            code: u16 = undefined,
            _internal: ?*DOMExceptionImpl.InternalState = null,
        },
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

    const delegates = .{

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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DOMExceptionImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DOMExceptionImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, message: DOMString, name: DOMString) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try DOMExceptionImpl.call_constructor(allocator, ctx, message, name);
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
