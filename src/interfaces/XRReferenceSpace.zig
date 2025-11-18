//! Generated from: webxr.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRReferenceSpaceImpl = @import("../impls/XRReferenceSpace.zig");
const XRSpace = @import("XRSpace.zig");

pub const XRReferenceSpace = struct {
    pub const Meta = struct {
        pub const name = "XRReferenceSpace";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *XRSpace;
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
            onreset: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRReferenceSpace, .{
        .deinit_fn = &deinit_wrapper,

        .get_onreset = &get_onreset,

        .set_onreset = &set_onreset,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getOffsetReferenceSpace = &call_getOffsetReferenceSpace,
        .call_removeEventListener = &call_removeEventListener,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        XRReferenceSpaceImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        XRReferenceSpaceImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_onreset(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRReferenceSpaceImpl.get_onreset(state);
    }

    pub fn set_onreset(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XRReferenceSpaceImpl.set_onreset(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return XRReferenceSpaceImpl.call_dispatchEvent(state, event);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getOffsetReferenceSpace(instance: *runtime.Instance, originOffset: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return XRReferenceSpaceImpl.call_getOffsetReferenceSpace(state, originOffset);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRReferenceSpaceImpl.call_when(state, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRReferenceSpaceImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRReferenceSpaceImpl.call_removeEventListener(state, type_, callback, options);
    }

};
