//! Generated from: service-workers.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WindowClientImpl = @import("../impls/WindowClient.zig");
const Client = @import("Client.zig");

pub const WindowClient = struct {
    pub const Meta = struct {
        pub const name = "WindowClient";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Client;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "ServiceWorker" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .ServiceWorker = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            visibilityState: VisibilityState = undefined,
            focused: bool = undefined,
            ancestorOrigins: FrozenArray<USVString> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(WindowClient, .{
        .deinit_fn = &deinit_wrapper,

        .get_ancestorOrigins = &get_ancestorOrigins,
        .get_focused = &get_focused,
        .get_frameType = &get_frameType,
        .get_id = &get_id,
        .get_lifecycleState = &get_lifecycleState,
        .get_type = &get_type,
        .get_url = &get_url,
        .get_visibilityState = &get_visibilityState,

        .call_focus = &call_focus,
        .call_navigate = &call_navigate,
        .call_postMessage = &call_postMessage,
        .call_postMessage = &call_postMessage,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        WindowClientImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WindowClientImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_url(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return WindowClientImpl.get_url(state);
    }

    pub fn get_frameType(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowClientImpl.get_frameType(state);
    }

    pub fn get_id(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return WindowClientImpl.get_id(state);
    }

    pub fn get_type(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowClientImpl.get_type(state);
    }

    pub fn get_lifecycleState(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowClientImpl.get_lifecycleState(state);
    }

    pub fn get_visibilityState(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowClientImpl.get_visibilityState(state);
    }

    pub fn get_focused(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return WindowClientImpl.get_focused(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_ancestorOrigins(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_ancestorOrigins) |cached| {
            return cached;
        }
        const value = WindowClientImpl.get_ancestorOrigins(state);
        state.cached_ancestorOrigins = value;
        return value;
    }

    /// Extended attributes: [NewObject]
    pub fn call_focus(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return WindowClientImpl.call_focus(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_navigate(instance: *runtime.Instance, url: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return WindowClientImpl.call_navigate(state, url);
    }

    /// Arguments for postMessage (WebIDL overloading)
    pub const PostMessageArgs = union(enum) {
        /// postMessage(message, transfer)
        any_sequence: struct {
            message: anyopaque,
            transfer: anyopaque,
        },
        /// postMessage(message, options)
        any_StructuredSerializeOptions: struct {
            message: anyopaque,
            options: anyopaque,
        },
    };

    pub fn call_postMessage(instance: *runtime.Instance, args: PostMessageArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .any_sequence => |a| return WindowClientImpl.any_sequence(state, a.message, a.transfer),
            .any_StructuredSerializeOptions => |a| return WindowClientImpl.any_StructuredSerializeOptions(state, a.message, a.options),
        }
    }

};
