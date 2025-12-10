//! Generated from: css-highlight-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HighlightRegistryImpl = @import("impls").HighlightRegistry;
const mixins = @import("mixins");
const HighlightsFromPointOptions = @import("dictionaries").HighlightsFromPointOptions;
const HighlightHitResult = @import("dictionaries").HighlightHitResult;

pub const HighlightRegistry = struct {
    pub const Meta = struct {
        pub const name = "HighlightRegistry";
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
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "highlightsFromPoint", "call_highlightsFromPoint", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "highlightsFromPoint",
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
            _internal: ?*HighlightRegistryImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    const delegates = .{

        .call_highlightsFromPoint = &call_highlightsFromPoint,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HighlightRegistryImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return HighlightRegistryImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HighlightRegistryImpl.deinit(instance);
    }

    pub fn call_highlightsFromPoint(instance: *runtime.Instance, x: f32, y: f32, options: webidl.Opt(HighlightsFromPointOptions)) anyerror!runtime.JSValue {
        
        return try HighlightRegistryImpl.call_highlightsFromPoint(instance, x, y, options);
    }

};
