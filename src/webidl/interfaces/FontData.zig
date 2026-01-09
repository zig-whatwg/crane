//! Generated from: local-font-access.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const FontDataImpl = @import("impls").FontData;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Blob = @import("interfaces").Blob;
const USVString = @import("typedefs").USVString;

pub const FontData = struct {
    pub const Meta = struct {
        pub const name = "FontData";
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
            .{ "postscriptName", "get_postscriptName", null },
            .{ "fullName", "get_fullName", null },
            .{ "family", "get_family", null },
            .{ "style", "get_style", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "blob", "call_blob", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "blob",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "postscriptName", "get_postscriptName", null },
            .{ "fullName", "get_fullName", null },
            .{ "family", "get_family", null },
            .{ "style", "get_style", null },
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
            postscriptName: runtime.USVString = undefined,
            fullName: runtime.USVString = undefined,
            family: runtime.USVString = undefined,
            style: runtime.USVString = undefined,
            _internal: ?*FontDataImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_family = &get_family,
        .get_fullName = &get_fullName,
        .get_postscriptName = &get_postscriptName,
        .get_style = &get_style,

        .call_blob = &call_blob,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FontDataImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return FontDataImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FontDataImpl.deinit(instance);
    }

    pub fn get_postscriptName(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FontDataImpl.get_postscriptName(instance);
    }

    pub fn get_fullName(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FontDataImpl.get_fullName(instance);
    }

    pub fn get_family(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FontDataImpl.get_family(instance);
    }

    pub fn get_style(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FontDataImpl.get_style(instance);
    }

    pub fn call_blob(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try FontDataImpl.call_blob(instance);
    }

};
