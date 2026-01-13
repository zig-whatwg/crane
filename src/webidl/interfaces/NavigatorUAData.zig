//! Generated from: ua-client-hints.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigatorUADataImpl = @import("impls").NavigatorUAData;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const UADataValues = @import("dictionaries").UADataValues;
const NavigatorUABrandVersion = @import("dictionaries").NavigatorUABrandVersion;
const UALowEntropyJSON = @import("dictionaries").UALowEntropyJSON;
const DOMString = @import("typedefs").DOMString;

pub const NavigatorUAData = struct {
    pub const Meta = struct {
        pub const name = "NavigatorUAData";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "brands", "get_brands", null },
            .{ "mobile", "get_mobile", null },
            .{ "platform", "get_platform", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getHighEntropyValues", "call_getHighEntropyValues", 1 },
            .{ "toJSON", "call_toJSON", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getHighEntropyValues",
            "toJSON",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "brands", "get_brands", null },
            .{ "mobile", "get_mobile", null },
            .{ "platform", "get_platform", null },
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
            brands: runtime.JSValue = undefined,
            mobile: bool = undefined,
            platform: typedefs.DOMString = undefined,
            _internal: ?*NavigatorUADataImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_brands = &get_brands,
        .get_mobile = &get_mobile,
        .get_platform = &get_platform,

        .call_getHighEntropyValues = &call_getHighEntropyValues,
        .call_toJSON = &call_toJSON,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NavigatorUADataImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return NavigatorUADataImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigatorUADataImpl.deinit(instance);
    }

    pub fn get_brands(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try NavigatorUADataImpl.get_brands(instance);
    }

    pub fn get_mobile(instance: *runtime.Instance) anyerror!bool {
        return try NavigatorUADataImpl.get_mobile(instance);
    }

    pub fn get_platform(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigatorUADataImpl.get_platform(instance);
    }

    pub fn call_getHighEntropyValues(instance: *runtime.Instance, hints: runtime.JSValue) anyerror!runtime.JSValue {
        
        return try NavigatorUADataImpl.call_getHighEntropyValues(instance, hints);
    }

    pub fn call_toJSON(instance: *runtime.Instance) anyerror!UALowEntropyJSON {
        return try NavigatorUADataImpl.call_toJSON(instance);
    }

};
