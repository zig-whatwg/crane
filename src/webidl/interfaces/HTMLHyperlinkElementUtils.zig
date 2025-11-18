//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HTMLHyperlinkElementUtilsImpl = @import("impls").HTMLHyperlinkElementUtils;

pub const HTMLHyperlinkElementUtils = struct {
    pub const Meta = struct {
        pub const name = "HTMLHyperlinkElementUtils";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
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
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(HTMLHyperlinkElementUtils, .{
        .deinit_fn = &deinit_wrapper,

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
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        HTMLHyperlinkElementUtilsImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLHyperlinkElementUtilsImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
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
