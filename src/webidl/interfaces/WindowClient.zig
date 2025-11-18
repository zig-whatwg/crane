//! Generated from: service-workers.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WindowClientImpl = @import("impls").WindowClient;
const Client = @import("interfaces").Client;
const VisibilityState = @import("interfaces").VisibilityState;
const Promise<WindowClient> = @import("interfaces").Promise<WindowClient>;
const Promise<WindowClient?> = @import("interfaces").Promise<WindowClient?>;
const FrozenArray<USVString> = @import("interfaces").FrozenArray<USVString>;

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
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        WindowClientImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WindowClientImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try WindowClientImpl.get_url(instance);
    }

    pub fn get_frameType(instance: *runtime.Instance) anyerror!FrameType {
        return try WindowClientImpl.get_frameType(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try WindowClientImpl.get_id(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!ClientType {
        return try WindowClientImpl.get_type(instance);
    }

    pub fn get_lifecycleState(instance: *runtime.Instance) anyerror!ClientLifecycleState {
        return try WindowClientImpl.get_lifecycleState(instance);
    }

    pub fn get_visibilityState(instance: *runtime.Instance) anyerror!anyopaque {
        return try WindowClientImpl.get_visibilityState(instance);
    }

    pub fn get_focused(instance: *runtime.Instance) anyerror!bool {
        return try WindowClientImpl.get_focused(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_ancestorOrigins(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_ancestorOrigins) |cached| {
            return cached;
        }
        const value = try WindowClientImpl.get_ancestorOrigins(instance);
        state.cached_ancestorOrigins = value;
        return value;
    }

    /// Extended attributes: [NewObject]
    pub fn call_focus(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try WindowClientImpl.call_focus(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_navigate(instance: *runtime.Instance, url: runtime.USVString) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try WindowClientImpl.call_navigate(instance, url);
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
            options: StructuredSerializeOptions,
        },
    };

    pub fn call_postMessage(instance: *runtime.Instance, args: PostMessageArgs) anyerror!void {
        switch (args) {
            .any_sequence => |a| return try WindowClientImpl.any_sequence(instance, a.message, a.transfer),
            .any_StructuredSerializeOptions => |a| return try WindowClientImpl.any_StructuredSerializeOptions(instance, a.message, a.options),
        }
    }

};
