//! Generated from: css-pseudo.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSPseudoElementImpl = @import("../impls/CSSPseudoElement.zig");
const EventTarget = @import("EventTarget.zig");
const GeometryUtils = @import("GeometryUtils.zig");

pub const CSSPseudoElement = struct {
    pub const Meta = struct {
        pub const name = "CSSPseudoElement";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{
            GeometryUtils,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            type: CSSOMString = undefined,
            element: Element = undefined,
            parent: (Element or CSSPseudoElement) = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSPseudoElement, .{
        .deinit_fn = &deinit_wrapper,

        .get_element = &get_element,
        .get_parent = &get_parent,
        .get_type = &get_type,

        .call_addEventListener = &call_addEventListener,
        .call_convertPointFromNode = &call_convertPointFromNode,
        .call_convertQuadFromNode = &call_convertQuadFromNode,
        .call_convertRectFromNode = &call_convertRectFromNode,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getBoxQuads = &call_getBoxQuads,
        .call_pseudo = &call_pseudo,
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
        CSSPseudoElementImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CSSPseudoElementImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPseudoElementImpl.get_type(state);
    }

    pub fn get_element(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPseudoElementImpl.get_element(state);
    }

    pub fn get_parent(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPseudoElementImpl.get_parent(state);
    }

    pub fn call_convertRectFromNode(instance: *runtime.Instance, rect: anyopaque, from: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSPseudoElementImpl.call_convertRectFromNode(state, rect, from, options);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSPseudoElementImpl.call_when(state, type_, options);
    }

    pub fn call_getBoxQuads(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSPseudoElementImpl.call_getBoxQuads(state, options);
    }

    pub fn call_pseudo(instance: *runtime.Instance, type_: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSPseudoElementImpl.call_pseudo(state, type_);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return CSSPseudoElementImpl.call_dispatchEvent(state, event);
    }

    pub fn call_convertQuadFromNode(instance: *runtime.Instance, quad: anyopaque, from: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSPseudoElementImpl.call_convertQuadFromNode(state, quad, from, options);
    }

    pub fn call_convertPointFromNode(instance: *runtime.Instance, point: anyopaque, from: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSPseudoElementImpl.call_convertPointFromNode(state, point, from, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSPseudoElementImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSPseudoElementImpl.call_removeEventListener(state, type_, callback, options);
    }

};
