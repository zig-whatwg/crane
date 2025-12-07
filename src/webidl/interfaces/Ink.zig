//! Generated from: ink-enhancement.idl
//! Generated at: 2025-12-07T19:33:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const InkImpl = @import("impls").Ink;
const mixins = @import("mixins");
const DelegatedInkTrailPresenter = @import("interfaces").DelegatedInkTrailPresenter;
const InkPresenterParam = @import("dictionaries").InkPresenterParam;

pub const Ink = struct {
    pub const Meta = struct {
        pub const name = "Ink";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "requestPresenter", "call_requestPresenter", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "requestPresenter",
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
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*InkImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_requestPresenter = &call_requestPresenter,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return InkImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        InkImpl.deinit(instance);
    }

    pub fn call_requestPresenter(instance: *runtime.Instance, param: webidl.Opt(InkPresenterParam)) anyerror!*const anyopaque {
        
        return try InkImpl.call_requestPresenter(instance, param);
    }

};
