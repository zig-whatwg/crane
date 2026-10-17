//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HyperlinkElementUtilsImpl = @import("impls").HyperlinkElementUtils;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const HyperlinkElementUtils = struct {
    pub const Meta = struct {
        pub const name = "HyperlinkElementUtils";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
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
            .{ "hreflang", "get_hreflang", "set_hreflang" },
            .{ "type", "get_type", "set_type" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
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
            .{ "hreflang", "get_hreflang", "set_hreflang" },
            .{ "type", "get_type", "set_type" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
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
            hreflang: runtime.DOMString = undefined,
            type: runtime.DOMString = undefined,
            _internal: ?*HyperlinkElementUtilsImpl.InternalState = null,
        },
    );

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "HyperlinkElementUtils")) {
            if (comptime @hasDecl(impls.HyperlinkElementUtils, "installHooks")) impls.HyperlinkElementUtils.installHooks();
        }
    }

    pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HyperlinkElementUtilsImpl.get_origin(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_protocol(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HyperlinkElementUtilsImpl.get_protocol(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_protocol(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try HyperlinkElementUtilsImpl.set_protocol(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_username(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HyperlinkElementUtilsImpl.get_username(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_username(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try HyperlinkElementUtilsImpl.set_username(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_password(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HyperlinkElementUtilsImpl.get_password(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_password(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try HyperlinkElementUtilsImpl.set_password(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_host(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HyperlinkElementUtilsImpl.get_host(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_host(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try HyperlinkElementUtilsImpl.set_host(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_hostname(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HyperlinkElementUtilsImpl.get_hostname(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_hostname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try HyperlinkElementUtilsImpl.set_hostname(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_port(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HyperlinkElementUtilsImpl.get_port(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_port(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try HyperlinkElementUtilsImpl.set_port(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_pathname(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HyperlinkElementUtilsImpl.get_pathname(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_pathname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try HyperlinkElementUtilsImpl.set_pathname(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_search(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HyperlinkElementUtilsImpl.get_search(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_search(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try HyperlinkElementUtilsImpl.set_search(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_hash(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HyperlinkElementUtilsImpl.get_hash(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_hash(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try HyperlinkElementUtilsImpl.set_hash(instance, value);
    }

    const reflection = @import("dom").reflection;

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_hreflang(instance: *runtime.Instance) anyerror!runtime.DOMString {
        if (comptime @hasDecl(HyperlinkElementUtilsImpl, "get_hreflang")) return try HyperlinkElementUtilsImpl.get_hreflang(instance);
        return try reflection.get(runtime.DOMString, instance, .{ .name = "hreflang" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_hreflang(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HyperlinkElementUtilsImpl, "set_hreflang")) return try HyperlinkElementUtilsImpl.set_hreflang(instance, value);
        try reflection.set(runtime.DOMString, instance, .{ .name = "hreflang" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
        if (comptime @hasDecl(HyperlinkElementUtilsImpl, "get_type")) return try HyperlinkElementUtilsImpl.get_type(instance);
        return try reflection.get(runtime.DOMString, instance, .{ .name = "type" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_type(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HyperlinkElementUtilsImpl, "set_type")) return try HyperlinkElementUtilsImpl.set_type(instance, value);
        try reflection.set(runtime.DOMString, instance, .{ .name = "type" }, value);
    }

    /// HTML [CEReactions]: the functions that run a custom element reactions
    /// bracket - the binding dispatches each in a catch scope, where
    /// engine.withPendingExceptionSetAside sets aside what the member leaves
    /// pending.
    pub const ce_reactions = .{
        "set_protocol",
        "set_username",
        "set_password",
        "set_host",
        "set_hostname",
        "set_port",
        "set_pathname",
        "set_search",
        "set_hash",
        "set_hreflang",
        "set_type",
    };
};
