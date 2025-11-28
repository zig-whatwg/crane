//! Generated from: shared-storage.idl
//! Generated at: 2025-11-28T19:11:19Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SharedStorageDeleteMethodImpl = @import("impls").SharedStorageDeleteMethod;
const mixins = @import("mixins");
const SharedStorageModifierMethod = @import("interfaces").SharedStorageModifierMethod;
const SharedStorageModifierMethodOptions = @import("dictionaries").SharedStorageModifierMethodOptions;
const DOMString = @import("typedefs").DOMString;

pub const SharedStorageDeleteMethod = struct {
    pub const Meta = struct {
        pub const name = "SharedStorageDeleteMethod";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *SharedStorageModifierMethod;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "SharedStorageWorklet" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .SharedStorageWorklet = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
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
            _internal: ?*SharedStorageDeleteMethodImpl.InternalState = null,
        },
    );

    const delegates = .{
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SharedStorageDeleteMethodImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SharedStorageDeleteMethodImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, key: DOMString, options: webidl.Opt(SharedStorageModifierMethodOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try SharedStorageDeleteMethodImpl.call_constructor(allocator, ctx, key, options);
    }

};
