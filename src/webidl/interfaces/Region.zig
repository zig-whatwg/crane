//! Generated from: css-regions.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const RegionImpl = @import("impls").Region;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSOMString = @import("typedefs").CSSOMString;
const Range = @import("interfaces").Range;

pub const Region = struct {
    pub const Meta = struct {
        pub const name = "Region";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "regionOverset", "get_regionOverset", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getRegionFlowRanges", "call_getRegionFlowRanges", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getRegionFlowRanges",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "regionOverset", "get_regionOverset", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            regionOverset: typedefs.CSSOMString = undefined,
            _internal: ?*RegionImpl.InternalState = null,
        },
    );

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Region")) {
            if (comptime @hasDecl(impls.Region, "installHooks")) impls.Region.installHooks();
        }
    }

    pub fn get_regionOverset(instance: *runtime.Instance) anyerror!CSSOMString {
        return try RegionImpl.get_regionOverset(instance);
    }

    pub fn call_getRegionFlowRanges(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try RegionImpl.call_getRegionFlowRanges(instance);
    }
};
