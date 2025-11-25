//! Generated from: sanitizer-api.idl
//! Generated at: 2025-11-25T13:07:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SanitizerImpl = @import("impls").Sanitizer;
const SanitizerConfig = @import("dictionaries").SanitizerConfig;
const SanitizerAttribute = @import("typedefs").SanitizerAttribute;
const SanitizerPresets = @import("enums").SanitizerPresets;
const SanitizerElement = @import("typedefs").SanitizerElement;
const SanitizerElementWithAttributes = @import("typedefs").SanitizerElementWithAttributes;

pub const Sanitizer = struct {
    pub const Meta = struct {
        pub const name = "Sanitizer";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "get", "call_get", 0 },
            .{ "allowElement", "call_allowElement", 1 },
            .{ "removeElement", "call_removeElement", 1 },
            .{ "replaceElementWithChildren", "call_replaceElementWithChildren", 1 },
            .{ "allowAttribute", "call_allowAttribute", 1 },
            .{ "removeAttribute", "call_removeAttribute", 1 },
            .{ "setComments", "call_setComments", 1 },
            .{ "setDataAttributes", "call_setDataAttributes", 1 },
            .{ "removeUnsafe", "call_removeUnsafe", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "get",
            "allowElement",
            "removeElement",
            "replaceElementWithChildren",
            "allowAttribute",
            "removeAttribute",
            "setComments",
            "setDataAttributes",
            "removeUnsafe",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*SanitizerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_allowAttribute = &call_allowAttribute,
        .call_allowElement = &call_allowElement,
        .call_get = &call_get,
        .call_removeAttribute = &call_removeAttribute,
        .call_removeElement = &call_removeElement,
        .call_removeUnsafe = &call_removeUnsafe,
        .call_replaceElementWithChildren = &call_replaceElementWithChildren,
        .call_setComments = &call_setComments,
        .call_setDataAttributes = &call_setDataAttributes,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SanitizerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SanitizerImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, configuration: *const anyopaque) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try SanitizerImpl.call_constructor(allocator, ctx, configuration);
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
