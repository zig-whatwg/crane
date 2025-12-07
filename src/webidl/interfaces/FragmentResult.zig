//! Generated from: css-layout-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const FragmentResultImpl = @import("impls").FragmentResult;
const mixins = @import("mixins");
const FragmentResultOptions = @import("dictionaries").FragmentResultOptions;

pub const FragmentResult = struct {
    pub const Meta = struct {
        pub const name = "FragmentResult";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "LayoutWorklet" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .LayoutWorklet = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "inlineSize", "get_inlineSize", null },
            .{ "blockSize", "get_blockSize", null },
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
            .{ "inlineSize", "get_inlineSize", null },
            .{ "blockSize", "get_blockSize", null },
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
            inlineSize: f64 = undefined,
            blockSize: f64 = undefined,
            _internal: ?*FragmentResultImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_blockSize = &get_blockSize,
        .get_inlineSize = &get_inlineSize,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FragmentResultImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FragmentResultImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, options: webidl.Opt(FragmentResultOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try FragmentResultImpl.call_constructor(allocator, ctx, options);
    }

    pub fn get_inlineSize(instance: *runtime.Instance) anyerror!f64 {
        return try FragmentResultImpl.get_inlineSize(instance);
    }

    pub fn get_blockSize(instance: *runtime.Instance) anyerror!f64 {
        return try FragmentResultImpl.get_blockSize(instance);
    }

};
