//! Generated from: scroll-animations.idl
//! Generated at: 2025-11-23T20:06:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ViewTimelineImpl = @import("impls").ViewTimeline;
const ScrollTimeline = @import("interfaces").ScrollTimeline;
const CSSNumericValue = @import("interfaces").CSSNumericValue;
const ViewTimelineOptions = @import("dictionaries").ViewTimelineOptions;
const Element = @import("interfaces").Element;
const AnimationEffect = @import("interfaces").AnimationEffect;
const CSSNumberish = @import("typedefs").CSSNumberish;
const Animation = @import("interfaces").Animation;
const ScrollAxis = @import("enums").ScrollAxis;
const ScrollTimelineOptions = @import("dictionaries").ScrollTimelineOptions;

pub const ViewTimeline = struct {
    pub const Meta = struct {
        pub const name = "ViewTimeline";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *ScrollTimeline;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "subject", "get_subject", null },
            .{ "startOffset", "get_startOffset", null },
            .{ "endOffset", "get_endOffset", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "play",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "subject", "get_subject", null },
            .{ "startOffset", "get_startOffset", null },
            .{ "endOffset", "get_endOffset", null },
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
            subject: *runtime.Instance = undefined,
            startOffset: *runtime.Instance = undefined,
            endOffset: *runtime.Instance = undefined,
            _internal: ?*ViewTimelineImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_endOffset = &get_endOffset,
        .get_startOffset = &get_startOffset,
        .get_subject = &get_subject,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ViewTimelineImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ViewTimelineImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, options: ViewTimelineOptions) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ViewTimelineImpl.call_constructor(allocator, ctx, options);
    }

    pub fn get_subject(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ViewTimelineImpl.get_subject(instance);
    }

    pub fn get_startOffset(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ViewTimelineImpl.get_startOffset(instance);
    }

    pub fn get_endOffset(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ViewTimelineImpl.get_endOffset(instance);
    }

};
