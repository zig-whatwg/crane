//! Generated from: resize-observer.idl
//! Generated at: 2025-11-23T14:26:29Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ResizeObserverImpl = @import("impls").ResizeObserver;
const ResizeObserverCallback = @import("callbacks").ResizeObserverCallback;
const Element = @import("interfaces").Element;
const ResizeObserverOptions = @import("dictionaries").ResizeObserverOptions;

pub const ResizeObserver = struct {
    pub const Meta = struct {
        pub const name = "ResizeObserver";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "observe", "call_observe", 1 },
            .{ "unobserve", "call_unobserve", 1 },
            .{ "disconnect", "call_disconnect", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "observe",
            "unobserve",
            "disconnect",
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
        struct {},
    );

    const delegates = .{

        .call_disconnect = &call_disconnect,
        .call_observe = &call_observe,
        .call_unobserve = &call_unobserve,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ResizeObserverImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ResizeObserverImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, callback: ResizeObserverCallback) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ResizeObserverImpl.call_constructor(allocator, ctx, callback);
    }

    pub fn call_observe(instance: *runtime.Instance, target: Element, options: ResizeObserverOptions) anyerror!void {
        
        return try ResizeObserverImpl.call_observe(instance, target, options);
    }

    pub fn call_unobserve(instance: *runtime.Instance, target: Element) anyerror!void {
        
        return try ResizeObserverImpl.call_unobserve(instance, target);
    }

    pub fn call_disconnect(instance: *runtime.Instance) anyerror!void {
        return try ResizeObserverImpl.call_disconnect(instance);
    }

};
