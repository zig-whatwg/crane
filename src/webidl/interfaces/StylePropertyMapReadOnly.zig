//! Generated from: css-typed-om.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const StylePropertyMapReadOnlyImpl = @import("impls").StylePropertyMapReadOnly;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSStyleValue = @import("interfaces").CSSStyleValue;
const USVString = @import("typedefs").USVString;

pub const StylePropertyMapReadOnly = struct {
    pub const Meta = struct {
        pub const name = "StylePropertyMapReadOnly";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker", "PaintWorklet", "LayoutWorklet" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
            .PaintWorklet = true,
            .LayoutWorklet = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "size", "get_size", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "get", "call_get", 1 },
            .{ "getAll", "call_getAll", 1 },
            .{ "has", "call_has", 1 },
            .{ "forEach", "call_forEach", 1 },
            .{ "forEach", "call_forEach", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "get",
            "getAll",
            "has",
            "forEach",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "size", "get_size", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
        
        /// Iterable declaration (for Symbol.iterator support)
        pub const iterable = .{
            .value_type = "runtime.USVString",
            .key_type = "runtime.sequence(CSSStyleValue)",
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            size: u32 = undefined,
            _internal: ?*StylePropertyMapReadOnlyImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_size = &get_size,

        .call_forEach = &call_forEach,
        .call_get = &call_get,
        .call_getAll = &call_getAll,
        .call_has = &call_has,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return StylePropertyMapReadOnlyImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return StylePropertyMapReadOnlyImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        StylePropertyMapReadOnlyImpl.deinit(instance);
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!u32 {
        return try StylePropertyMapReadOnlyImpl.get_size(instance);
    }

    pub fn call_has(instance: *runtime.Instance, property: runtime.USVString) anyerror!bool {
        
        return try StylePropertyMapReadOnlyImpl.call_has(instance, property);
    }

    pub fn call_get(instance: *runtime.Instance, property: runtime.USVString) anyerror!runtime.JSValue {
        
        return try StylePropertyMapReadOnlyImpl.call_get(instance, property);
    }

    pub fn call_getAll(instance: *runtime.Instance, property: runtime.USVString) anyerror!runtime.JSValue {
        
        return try StylePropertyMapReadOnlyImpl.call_getAll(instance, property);
    }

    pub fn call_forEach(instance: *runtime.Instance, callback: runtime.JSValue) anyerror!void {
        
        return try StylePropertyMapReadOnlyImpl.call_forEach(instance, callback);
    }

    /// Get entries for pair iterable support (used by V8 for iteration)
    /// Returns slice of entries with .name and .value fields
    pub fn getEntriesForIterable(instance: *runtime.Instance) ?[]const StylePropertyMapReadOnlyImpl.IterableEntry {
        return StylePropertyMapReadOnlyImpl.getEntriesInternal(instance);
    }

};
