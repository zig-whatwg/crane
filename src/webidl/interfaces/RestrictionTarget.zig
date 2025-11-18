//! Generated from: element-capture.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RestrictionTargetImpl = @import("impls").RestrictionTarget;
const Element = @import("interfaces").Element;
const Promise<RestrictionTarget> = @import("interfaces").Promise<RestrictionTarget>;

pub const RestrictionTarget = struct {
    pub const Meta = struct {
        pub const name = "RestrictionTarget";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Serializable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RestrictionTarget, .{
        .deinit_fn = &deinit_wrapper,

        .call_fromElement = &call_fromElement,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        RestrictionTargetImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RestrictionTargetImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [Exposed=Window], [SecureContext]
    pub fn call_fromElement(instance: *runtime.Instance, element: Element) anyerror!anyopaque {
        
        return try RestrictionTargetImpl.call_fromElement(instance, element);
    }

};
