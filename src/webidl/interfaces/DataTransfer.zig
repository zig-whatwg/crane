//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DataTransferImpl = @import("impls").DataTransfer;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Element = @import("interfaces").Element;
const DataTransferItemList = @import("interfaces").DataTransferItemList;
const DOMString = @import("typedefs").DOMString;
const FileList = @import("interfaces").FileList;

pub const DataTransfer = struct {
    pub const Meta = struct {
        pub const name = "DataTransfer";
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
            .{ "dropEffect", "get_dropEffect", "set_dropEffect" },
            .{ "effectAllowed", "get_effectAllowed", "set_effectAllowed" },
            .{ "items", "get_items", null },
            .{ "types", "get_types", null },
            .{ "files", "get_files", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "setDragImage", "call_setDragImage", 3 },
            .{ "getData", "call_getData", 1 },
            .{ "setData", "call_setData", 2 },
            .{ "clearData", "call_clearData", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setDragImage",
            "getData",
            "setData",
            "clearData",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "dropEffect", "get_dropEffect", "set_dropEffect" },
            .{ "effectAllowed", "get_effectAllowed", "set_effectAllowed" },
            .{ "items", "get_items", null },
            .{ "types", "get_types", null },
            .{ "files", "get_files", null },
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
            dropEffect: typedefs.DOMString = undefined,
            effectAllowed: typedefs.DOMString = undefined,
            items: *runtime.Instance = undefined,
            types: runtime.JSValue = undefined,
            files: *runtime.Instance = undefined,
            cached_items: ?*runtime.Instance = null,
            cached_files: ?*runtime.Instance = null,
            _internal: ?*DataTransferImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_dropEffect = &get_dropEffect,
        .get_effectAllowed = &get_effectAllowed,
        .get_files = &get_files,
        .get_items = &get_items,
        .get_types = &get_types,

        .set_dropEffect = &set_dropEffect,
        .set_effectAllowed = &set_effectAllowed,

        .call_clearData = &call_clearData,
        .call_getData = &call_getData,
        .call_setData = &call_setData,
        .call_setDragImage = &call_setDragImage,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DataTransferImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return DataTransferImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DataTransferImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try DataTransferImpl.call_constructor(ctx);
    }

    pub fn get_dropEffect(instance: *runtime.Instance) anyerror!DOMString {
        return try DataTransferImpl.get_dropEffect(instance);
    }

    pub fn set_dropEffect(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try DataTransferImpl.set_dropEffect(instance, value);
    }

    pub fn get_effectAllowed(instance: *runtime.Instance) anyerror!DOMString {
        return try DataTransferImpl.get_effectAllowed(instance);
    }

    pub fn set_effectAllowed(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try DataTransferImpl.set_effectAllowed(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_items(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_items) |cached| {
            return cached;
        }
        const value = try DataTransferImpl.get_items(instance);
        state.own.cached_items = value;
        return value;
    }

    pub fn get_types(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try DataTransferImpl.get_types(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_files(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_files) |cached| {
            return cached;
        }
        const value = try DataTransferImpl.get_files(instance);
        state.own.cached_files = value;
        return value;
    }

    pub fn call_getData(instance: *runtime.Instance, format: DOMString) anyerror!DOMString {
        
        return try DataTransferImpl.call_getData(instance, format);
    }

    pub fn call_clearData(instance: *runtime.Instance, format: webidl.Opt(DOMString)) anyerror!void {
        
        return try DataTransferImpl.call_clearData(instance, format);
    }

    pub fn call_setData(instance: *runtime.Instance, format: DOMString, data: DOMString) anyerror!void {
        
        return try DataTransferImpl.call_setData(instance, format, data);
    }

    pub fn call_setDragImage(instance: *runtime.Instance, image: *runtime.Instance, x: i32, y: i32) anyerror!void {
        
        return try DataTransferImpl.call_setDragImage(instance, image, x, y);
    }

};
