//! Generated from: sanitizer-api.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SanitizerImpl = @import("impls").Sanitizer;
const SanitizerConfig = @import("dictionaries").SanitizerConfig;
const SanitizerAttribute = @import("typedefs").SanitizerAttribute;
const (SanitizerConfig or SanitizerPresets) = @import("interfaces").(SanitizerConfig or SanitizerPresets);
const SanitizerElement = @import("typedefs").SanitizerElement;
const SanitizerElementWithAttributes = @import("typedefs").SanitizerElementWithAttributes;

pub const Sanitizer = struct {
    pub const Meta = struct {
        pub const name = "Sanitizer";
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
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Sanitizer, .{
        .deinit_fn = &deinit_wrapper,

        .call_allowAttribute = &call_allowAttribute,
        .call_allowElement = &call_allowElement,
        .call_get = &call_get,
        .call_removeAttribute = &call_removeAttribute,
        .call_removeElement = &call_removeElement,
        .call_removeUnsafe = &call_removeUnsafe,
        .call_replaceElementWithChildren = &call_replaceElementWithChildren,
        .call_setComments = &call_setComments,
        .call_setDataAttributes = &call_setDataAttributes,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        SanitizerImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SanitizerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, configuration: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try SanitizerImpl.constructor(instance, configuration);
        
        return instance;
    }

    pub fn call_replaceElementWithChildren(instance: *runtime.Instance, element: SanitizerElement) anyerror!bool {
        
        return try SanitizerImpl.call_replaceElementWithChildren(instance, element);
    }

    pub fn call_setComments(instance: *runtime.Instance, allow: bool) anyerror!bool {
        
        return try SanitizerImpl.call_setComments(instance, allow);
    }

    pub fn call_removeUnsafe(instance: *runtime.Instance) anyerror!bool {
        return try SanitizerImpl.call_removeUnsafe(instance);
    }

    pub fn call_allowElement(instance: *runtime.Instance, element: SanitizerElementWithAttributes) anyerror!bool {
        
        return try SanitizerImpl.call_allowElement(instance, element);
    }

    pub fn call_get(instance: *runtime.Instance) anyerror!SanitizerConfig {
        return try SanitizerImpl.call_get(instance);
    }

    pub fn call_allowAttribute(instance: *runtime.Instance, attribute: SanitizerAttribute) anyerror!bool {
        
        return try SanitizerImpl.call_allowAttribute(instance, attribute);
    }

    pub fn call_removeElement(instance: *runtime.Instance, element: SanitizerElement) anyerror!bool {
        
        return try SanitizerImpl.call_removeElement(instance, element);
    }

    pub fn call_removeAttribute(instance: *runtime.Instance, attribute: SanitizerAttribute) anyerror!bool {
        
        return try SanitizerImpl.call_removeAttribute(instance, attribute);
    }

    pub fn call_setDataAttributes(instance: *runtime.Instance, allow: bool) anyerror!bool {
        
        return try SanitizerImpl.call_setDataAttributes(instance, allow);
    }

};
