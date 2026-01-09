//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PluginImpl = @import("impls").Plugin;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const MimeType = @import("MimeType.zig").MimeType;
const DOMString = @import("typedefs").DOMString;

pub const Plugin = struct {
    pub const Meta = struct {
        pub const name = "Plugin";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "LegacyUnenumerableNamedProperties" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", null },
            .{ "description", "get_description", null },
            .{ "filename", "get_filename", null },
            .{ "length", "get_length", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "item", "call_item", 1 },
            .{ "namedItem", "call_namedItem", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "item",
            "namedItem",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "name", "get_name", null },
            .{ "description", "get_description", null },
            .{ "filename", "get_filename", null },
            .{ "length", "get_length", null },
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
            name: typedefs.DOMString = undefined,
            description: typedefs.DOMString = undefined,
            filename: typedefs.DOMString = undefined,
            length: u32 = undefined,
            _internal: ?*PluginImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_description = &get_description,
        .get_filename = &get_filename,
        .get_length = &get_length,
        .get_name = &get_name,

        .call_item = &call_item,
        .call_namedItem = &call_namedItem,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PluginImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return PluginImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PluginImpl.deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try PluginImpl.get_name(instance);
    }

    pub fn get_description(instance: *runtime.Instance) anyerror!DOMString {
        return try PluginImpl.get_description(instance);
    }

    pub fn get_filename(instance: *runtime.Instance) anyerror!DOMString {
        return try PluginImpl.get_filename(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try PluginImpl.get_length(instance);
    }

    pub fn call_namedItem(instance: *runtime.Instance, name: DOMString) anyerror!?*runtime.Instance {
        
        return try PluginImpl.call_namedItem(instance, name);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {
        
        return try PluginImpl.call_item(instance, index);
    }

    /// Get supported property names for named property enumeration (Reflect.ownKeys, etc.)
    /// Per WebIDL spec §3.9.3, returns names in list order for proper enumeration
    pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
        return PluginImpl.getSupportedPropertyNames(instance, allocator);
    }

};
