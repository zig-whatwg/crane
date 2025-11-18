//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HTMLHyperlinkElementUtilsImpl = @import("../impls/HTMLHyperlinkElementUtils.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        HTMLHyperlinkElementUtilsImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        HTMLHyperlinkElementUtilsImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn get_href(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return HTMLHyperlinkElementUtilsImpl.get_href(state);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn set_href(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLHyperlinkElementUtilsImpl.set_href(state, value);
    }

    pub fn get_origin(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return HTMLHyperlinkElementUtilsImpl.get_origin(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_protocol(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return HTMLHyperlinkElementUtilsImpl.get_protocol(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_protocol(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLHyperlinkElementUtilsImpl.set_protocol(state, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_username(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return HTMLHyperlinkElementUtilsImpl.get_username(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_username(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLHyperlinkElementUtilsImpl.set_username(state, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_password(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return HTMLHyperlinkElementUtilsImpl.get_password(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_password(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLHyperlinkElementUtilsImpl.set_password(state, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_host(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return HTMLHyperlinkElementUtilsImpl.get_host(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_host(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLHyperlinkElementUtilsImpl.set_host(state, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_hostname(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return HTMLHyperlinkElementUtilsImpl.get_hostname(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_hostname(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLHyperlinkElementUtilsImpl.set_hostname(state, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_port(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return HTMLHyperlinkElementUtilsImpl.get_port(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_port(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLHyperlinkElementUtilsImpl.set_port(state, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_pathname(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return HTMLHyperlinkElementUtilsImpl.get_pathname(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_pathname(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLHyperlinkElementUtilsImpl.set_pathname(state, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_search(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return HTMLHyperlinkElementUtilsImpl.get_search(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_search(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLHyperlinkElementUtilsImpl.set_search(state, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_hash(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return HTMLHyperlinkElementUtilsImpl.get_hash(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_hash(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        HTMLHyperlinkElementUtilsImpl.set_hash(state, value);
    }

};
