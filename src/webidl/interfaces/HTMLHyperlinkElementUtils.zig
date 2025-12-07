//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLHyperlinkElementUtilsImpl = @import("impls").HTMLHyperlinkElementUtils;
const mixins = @import("mixins");
const USVString = @import("interfaces").USVString;

pub const HTMLHyperlinkElementUtils = struct {
    pub const Meta = struct {
        pub const name = "HTMLHyperlinkElementUtils";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "href", "get_href", "set_href" },
            .{ "origin", "get_origin", null },
            .{ "protocol", "get_protocol", "set_protocol" },
            .{ "username", "get_username", "set_username" },
            .{ "password", "get_password", "set_password" },
            .{ "host", "get_host", "set_host" },
            .{ "hostname", "get_hostname", "set_hostname" },
            .{ "port", "get_port", "set_port" },
            .{ "pathname", "get_pathname", "set_pathname" },
            .{ "search", "get_search", "set_search" },
            .{ "hash", "get_hash", "set_hash" },
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
            .{ "href", "get_href", "set_href" },
            .{ "origin", "get_origin", null },
            .{ "protocol", "get_protocol", "set_protocol" },
            .{ "username", "get_username", "set_username" },
            .{ "password", "get_password", "set_password" },
            .{ "host", "get_host", "set_host" },
            .{ "hostname", "get_hostname", "set_hostname" },
            .{ "port", "get_port", "set_port" },
            .{ "pathname", "get_pathname", "set_pathname" },
            .{ "search", "get_search", "set_search" },
            .{ "hash", "get_hash", "set_hash" },
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
            href: runtime.USVString = undefined,
            origin: runtime.USVString = undefined,
            protocol: runtime.USVString = undefined,
            username: runtime.USVString = undefined,
            password: runtime.USVString = undefined,
            host: runtime.USVString = undefined,
            hostname: runtime.USVString = undefined,
            port: runtime.USVString = undefined,
            pathname: runtime.USVString = undefined,
            search: runtime.USVString = undefined,
            hash: runtime.USVString = undefined,
            _internal: ?*HTMLHyperlinkElementUtilsImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_hash = &get_hash,
        .get_host = &get_host,
        .get_hostname = &get_hostname,
        .get_href = &get_href,
        .get_origin = &get_origin,
        .get_password = &get_password,
        .get_pathname = &get_pathname,
        .get_port = &get_port,
        .get_protocol = &get_protocol,
        .get_search = &get_search,
        .get_username = &get_username,

        .set_hash = &set_hash,
        .set_host = &set_host,
        .set_hostname = &set_hostname,
        .set_href = &set_href,
        .set_password = &set_password,
        .set_pathname = &set_pathname,
        .set_port = &set_port,
        .set_protocol = &set_protocol,
        .set_search = &set_search,
        .set_username = &set_username,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HTMLHyperlinkElementUtilsImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLHyperlinkElementUtilsImpl.deinit(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLHyperlinkElementUtilsImpl.get_href(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn set_href(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLHyperlinkElementUtilsImpl.set_href(instance, value);
    }

    pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLHyperlinkElementUtilsImpl.get_origin(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_protocol(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLHyperlinkElementUtilsImpl.get_protocol(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_protocol(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLHyperlinkElementUtilsImpl.set_protocol(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_username(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLHyperlinkElementUtilsImpl.get_username(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_username(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLHyperlinkElementUtilsImpl.set_username(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_password(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLHyperlinkElementUtilsImpl.get_password(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_password(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLHyperlinkElementUtilsImpl.set_password(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_host(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLHyperlinkElementUtilsImpl.get_host(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_host(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLHyperlinkElementUtilsImpl.set_host(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_hostname(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLHyperlinkElementUtilsImpl.get_hostname(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_hostname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLHyperlinkElementUtilsImpl.set_hostname(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_port(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLHyperlinkElementUtilsImpl.get_port(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_port(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLHyperlinkElementUtilsImpl.set_port(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_pathname(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLHyperlinkElementUtilsImpl.get_pathname(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_pathname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLHyperlinkElementUtilsImpl.set_pathname(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_search(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLHyperlinkElementUtilsImpl.get_search(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_search(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLHyperlinkElementUtilsImpl.set_search(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_hash(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLHyperlinkElementUtilsImpl.get_hash(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_hash(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLHyperlinkElementUtilsImpl.set_hash(instance, value);
    }

};
