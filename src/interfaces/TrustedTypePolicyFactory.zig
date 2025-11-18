//! Generated from: trusted-types.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TrustedTypePolicyFactoryImpl = @import("../impls/TrustedTypePolicyFactory.zig");

pub const TrustedTypePolicyFactory = struct {
    pub const Meta = struct {
        pub const name = "TrustedTypePolicyFactory";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            emptyHTML: TrustedHTML = undefined,
            emptyScript: TrustedScript = undefined,
            defaultPolicy: ?TrustedTypePolicy = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(TrustedTypePolicyFactory, .{
        .deinit_fn = &deinit_wrapper,

        .get_defaultPolicy = &get_defaultPolicy,
        .get_emptyHTML = &get_emptyHTML,
        .get_emptyScript = &get_emptyScript,

        .call_createPolicy = &call_createPolicy,
        .call_getAttributeType = &call_getAttributeType,
        .call_getPropertyType = &call_getPropertyType,
        .call_isHTML = &call_isHTML,
        .call_isScript = &call_isScript,
        .call_isScriptURL = &call_isScriptURL,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        TrustedTypePolicyFactoryImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        TrustedTypePolicyFactoryImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_emptyHTML(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TrustedTypePolicyFactoryImpl.get_emptyHTML(state);
    }

    pub fn get_emptyScript(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TrustedTypePolicyFactoryImpl.get_emptyScript(state);
    }

    pub fn get_defaultPolicy(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TrustedTypePolicyFactoryImpl.get_defaultPolicy(state);
    }

    pub fn call_createPolicy(instance: *runtime.Instance, policyName: runtime.DOMString, policyOptions: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return TrustedTypePolicyFactoryImpl.call_createPolicy(state, policyName, policyOptions);
    }

    pub fn call_isScript(instance: *runtime.Instance, value: anyopaque) bool {
        const state = instance.getState(State);
        
        return TrustedTypePolicyFactoryImpl.call_isScript(state, value);
    }

    pub fn call_isScriptURL(instance: *runtime.Instance, value: anyopaque) bool {
        const state = instance.getState(State);
        
        return TrustedTypePolicyFactoryImpl.call_isScriptURL(state, value);
    }

    pub fn call_getPropertyType(instance: *runtime.Instance, tagName: runtime.DOMString, property: runtime.DOMString, elementNs: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return TrustedTypePolicyFactoryImpl.call_getPropertyType(state, tagName, property, elementNs);
    }

    pub fn call_isHTML(instance: *runtime.Instance, value: anyopaque) bool {
        const state = instance.getState(State);
        
        return TrustedTypePolicyFactoryImpl.call_isHTML(state, value);
    }

    pub fn call_getAttributeType(instance: *runtime.Instance, tagName: runtime.DOMString, attribute: runtime.DOMString, elementNs: anyopaque, attrNs: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return TrustedTypePolicyFactoryImpl.call_getAttributeType(state, tagName, attribute, elementNs, attrNs);
    }

};
