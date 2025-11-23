//! Generated from: css-regions.idl
//! Generated at: 2025-11-23T14:26:29Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RegionImpl = @import("impls").Region;
const CSSOMString = @import("interfaces").CSSOMString;
const Range = @import("interfaces").Range;

pub const Region = struct {
    pub const Meta = struct {
        pub const name = "Region";
        pub const is_mixin = true;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "regionOverset", "get_regionOverset", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "getRegionFlowRanges", "call_getRegionFlowRanges", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getRegionFlowRanges",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "regionOverset", "get_regionOverset", null },
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
            regionOverset: CSSOMString = undefined,
            _internal: ?*RegionImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_regionOverset = &get_regionOverset,

        .call_getRegionFlowRanges = &call_getRegionFlowRanges,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RegionImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RegionImpl.deinit(instance);
    }

    pub fn get_regionOverset(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try RegionImpl.get_regionOverset(instance);
    }

    pub fn call_getRegionFlowRanges(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try RegionImpl.call_getRegionFlowRanges(instance);
    }

};
