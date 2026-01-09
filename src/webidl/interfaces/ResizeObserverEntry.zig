//! Generated from: resize-observer.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ResizeObserverEntryImpl = @import("impls").ResizeObserverEntry;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Element = @import("Element.zig").Element;
const DOMRectReadOnly = @import("DOMRectReadOnly.zig").DOMRectReadOnly;
const ResizeObserverSize = @import("ResizeObserverSize.zig").ResizeObserverSize;

pub const ResizeObserverEntry = struct {
    pub const Meta = struct {
        pub const name = "ResizeObserverEntry";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "target", "get_target", null },
            .{ "contentRect", "get_contentRect", null },
            .{ "borderBoxSize", "get_borderBoxSize", null },
            .{ "contentBoxSize", "get_contentBoxSize", null },
            .{ "devicePixelContentBoxSize", "get_devicePixelContentBoxSize", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "target", "get_target", null },
            .{ "contentRect", "get_contentRect", null },
            .{ "borderBoxSize", "get_borderBoxSize", null },
            .{ "contentBoxSize", "get_contentBoxSize", null },
            .{ "devicePixelContentBoxSize", "get_devicePixelContentBoxSize", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            target: *runtime.Instance = undefined,
            contentRect: *runtime.Instance = undefined,
            borderBoxSize: runtime.JSValue = undefined,
            contentBoxSize: runtime.JSValue = undefined,
            devicePixelContentBoxSize: runtime.JSValue = undefined,
            _internal: ?*ResizeObserverEntryImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_borderBoxSize = &get_borderBoxSize,
        .get_contentBoxSize = &get_contentBoxSize,
        .get_contentRect = &get_contentRect,
        .get_devicePixelContentBoxSize = &get_devicePixelContentBoxSize,
        .get_target = &get_target,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ResizeObserverEntryImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return ResizeObserverEntryImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ResizeObserverEntryImpl.deinit(instance);
    }

    pub fn get_target(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ResizeObserverEntryImpl.get_target(instance);
    }

    pub fn get_contentRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ResizeObserverEntryImpl.get_contentRect(instance);
    }

    pub fn get_borderBoxSize(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ResizeObserverEntryImpl.get_borderBoxSize(instance);
    }

    pub fn get_contentBoxSize(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ResizeObserverEntryImpl.get_contentBoxSize(instance);
    }

    pub fn get_devicePixelContentBoxSize(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ResizeObserverEntryImpl.get_devicePixelContentBoxSize(instance);
    }

};
