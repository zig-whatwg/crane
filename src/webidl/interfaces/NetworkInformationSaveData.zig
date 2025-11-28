//! Generated from: savedata.idl
//! Generated at: 2025-11-28T19:51:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NetworkInformationSaveDataImpl = @import("impls").NetworkInformationSaveData;
const mixins = @import("mixins");

pub const NetworkInformationSaveData = struct {
    pub const Meta = struct {
        pub const name = "NetworkInformationSaveData";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "saveData", "get_saveData", null },
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
            .{ "saveData", "get_saveData", null },
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
            saveData: bool = undefined,
            cached_saveData: ?bool = null,
            _internal: ?*NetworkInformationSaveDataImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_saveData = &get_saveData,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NetworkInformationSaveDataImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NetworkInformationSaveDataImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_saveData(instance: *runtime.Instance) anyerror!bool {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_saveData) |cached| {
            return cached;
        }
        const value = try NetworkInformationSaveDataImpl.get_saveData(instance);
        state.own.cached_saveData = value;
        return value;
    }

};
