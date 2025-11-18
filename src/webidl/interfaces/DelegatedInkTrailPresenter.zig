//! Generated from: ink-enhancement.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DelegatedInkTrailPresenterImpl = @import("impls").DelegatedInkTrailPresenter;
const Element = @import("interfaces").Element;
const PointerEvent = @import("interfaces").PointerEvent;
const InkTrailStyle = @import("dictionaries").InkTrailStyle;

pub const DelegatedInkTrailPresenter = struct {
    pub const Meta = struct {
        pub const name = "DelegatedInkTrailPresenter";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            presentationArea: ?Element = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(DelegatedInkTrailPresenter, .{
        .deinit_fn = &deinit_wrapper,

        .get_presentationArea = &get_presentationArea,

        .call_updateInkTrailStartPoint = &call_updateInkTrailStartPoint,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        DelegatedInkTrailPresenterImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DelegatedInkTrailPresenterImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_presentationArea(instance: *runtime.Instance) anyerror!anyopaque {
        return try DelegatedInkTrailPresenterImpl.get_presentationArea(instance);
    }

    pub fn call_updateInkTrailStartPoint(instance: *runtime.Instance, event: PointerEvent, style: InkTrailStyle) anyerror!void {
        
        return try DelegatedInkTrailPresenterImpl.call_updateInkTrailStartPoint(instance, event, style);
    }

};
