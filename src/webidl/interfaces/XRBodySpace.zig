//! Generated from: body-tracking.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRBodySpaceImpl = @import("impls").XRBodySpace;
const XRSpace = @import("interfaces").XRSpace;
const XRBodyJoint = @import("enums").XRBodyJoint;

pub const XRBodySpace = struct {
    pub const Meta = struct {
        pub const name = "XRBodySpace";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *XRSpace;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            jointName: XRBodyJoint = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRBodySpace, .{
        .deinit_fn = &deinit_wrapper,

        .get_jointName = &get_jointName,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
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
        
        // Initialize the instance (Impl receives full instance)
        XRBodySpaceImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRBodySpaceImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_jointName(instance: *runtime.Instance) anyerror!XRBodyJoint {
        return try XRBodySpaceImpl.get_jointName(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try XRBodySpaceImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try XRBodySpaceImpl.call_when(instance, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try XRBodySpaceImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try XRBodySpaceImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
