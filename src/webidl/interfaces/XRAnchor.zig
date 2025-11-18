//! Generated from: anchors.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRAnchorImpl = @import("impls").XRAnchor;
const Promise<DOMString> = @import("interfaces").Promise<DOMString>;
const XRSpace = @import("interfaces").XRSpace;

pub const XRAnchor = struct {
    pub const Meta = struct {
        pub const name = "XRAnchor";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            anchorSpace: XRSpace = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRAnchor, .{
        .deinit_fn = &deinit_wrapper,

        .get_anchorSpace = &get_anchorSpace,

        .call_delete = &call_delete,
        .call_requestPersistentHandle = &call_requestPersistentHandle,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        XRAnchorImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRAnchorImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_anchorSpace(instance: *runtime.Instance) anyerror!XRSpace {
        return try XRAnchorImpl.get_anchorSpace(instance);
    }

    pub fn call_delete(instance: *runtime.Instance) anyerror!void {
        return try XRAnchorImpl.call_delete(instance);
    }

    pub fn call_requestPersistentHandle(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRAnchorImpl.call_requestPersistentHandle(instance);
    }

};
