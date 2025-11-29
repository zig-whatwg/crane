//! Generated from: eyedropper-api.idl
//! Generated at: 2025-11-29T05:01:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const EyeDropperImpl = @import("impls").EyeDropper;
const mixins = @import("mixins");
const ColorSelectionOptions = @import("dictionaries").ColorSelectionOptions;
const ColorSelectionResult = @import("dictionaries").ColorSelectionResult;

pub const EyeDropper = struct {
    pub const Meta = struct {
        pub const name = "EyeDropper";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "open", "call_open", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "open",
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
            _internal: ?*EyeDropperImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_open = &call_open,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return EyeDropperImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        EyeDropperImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try EyeDropperImpl.call_constructor(allocator, ctx);
    }

    pub fn call_open(instance: *runtime.Instance, options: webidl.Opt(ColorSelectionOptions)) anyerror!*const anyopaque {
        
        return try EyeDropperImpl.call_open(instance, options);
    }

};
