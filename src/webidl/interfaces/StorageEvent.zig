//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const StorageEventImpl = @import("impls").StorageEvent;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Event = @import("interfaces").Event;
const Storage = @import("interfaces").Storage;
const EventTarget = @import("interfaces").EventTarget;
const StorageEventInit = @import("dictionaries").StorageEventInit;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const StorageEvent = struct {
    pub const Meta = struct {
        pub const name = "StorageEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Event.State;
        pub const ParentInterface = Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "key", "get_key", null },
            .{ "oldValue", "get_oldValue", null },
            .{ "newValue", "get_newValue", null },
            .{ "url", "get_url", null },
            .{ "storageArea", "get_storageArea", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "initStorageEvent", "call_initStorageEvent", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "initStorageEvent",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "key", "get_key", null },
            .{ "oldValue", "get_oldValue", null },
            .{ "newValue", "get_newValue", null },
            .{ "url", "get_url", null },
            .{ "storageArea", "get_storageArea", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            key: ?runtime.DOMString = null,
            oldValue: ?runtime.DOMString = null,
            newValue: ?runtime.DOMString = null,
            url: runtime.USVString = undefined,
            storageArea: ?*runtime.Instance = null,
            _internal: ?*StorageEventImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_key = &get_key,
        .get_newValue = &get_newValue,
        .get_oldValue = &get_oldValue,
        .get_storageArea = &get_storageArea,
        .get_url = &get_url,

        .call_initStorageEvent = &call_initStorageEvent,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Make a new instance: the construction chain, this interface's State
    /// and vtable.
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return initChain(allocator, State, &vtable, ctx, .{});
    }

    /// Make a new instance with construction arguments: facts given at
    /// construction, as a C++ constructor's parameters. Each field of `args`
    /// must be taken by an impl on the chain (its `construction_args`).
    pub fn initWith(allocator: std.mem.Allocator, ctx: runtime.Context, args: anytype) !*runtime.Instance {
        inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
            if (comptime !takesConstructionArg(field.name)) @compileError("StorageEvent has no construction argument '" ++ field.name ++ "'");
        }
        return initChain(allocator, State, &vtable, ctx, args);
    }

    /// The construction chain for a descendant's State and vtable, for an
    /// impl that still chains by hand.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return initChain(allocator, StateType, vtable_ptr, ctx, .{});
    }

    /// The construction chain: the parent interface's, then the impl's own
    /// steps (`initOwn`), whose failure unwinds the parent's part and frees
    /// the slot. An impl that still defines `init` chains by hand.
    pub inline fn initChain(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
        args: anytype,
    ) !*runtime.Instance {
        if (comptime @hasDecl(StorageEventImpl, "init") and @hasDecl(StorageEventImpl, "initOwn")) @compileError("StorageEventImpl defines both init and initOwn");
        if (comptime @hasDecl(StorageEventImpl, "init")) return StorageEventImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(StorageEventImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try StorageEventImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(StorageEventImpl, "init")) return false;
        if (comptime @hasDecl(StorageEventImpl, "construction_args")) {
            inline for (StorageEventImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return Meta.ParentInterface.takesConstructionArg(name);
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(StorageEventImpl, "deinit") and @hasDecl(StorageEventImpl, "deinitOwn")) @compileError("StorageEventImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(StorageEventImpl, "deinit")) return StorageEventImpl.deinit(instance);
        if (comptime @hasDecl(StorageEventImpl, "deinitOwn")) StorageEventImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "StorageEvent")) {
            if (comptime @hasDecl(impls.StorageEvent, "installHooks")) impls.StorageEvent.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(StorageEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try StorageEventImpl.call_constructor(ctx, @"type", eventInitDict);
    }

    pub fn get_key(instance: *runtime.Instance) anyerror!?runtime.DOMString {
        return try StorageEventImpl.get_key(instance);
    }

    pub fn get_oldValue(instance: *runtime.Instance) anyerror!?runtime.DOMString {
        return try StorageEventImpl.get_oldValue(instance);
    }

    pub fn get_newValue(instance: *runtime.Instance) anyerror!?runtime.DOMString {
        return try StorageEventImpl.get_newValue(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try StorageEventImpl.get_url(instance);
    }

    pub fn get_storageArea(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try StorageEventImpl.get_storageArea(instance);
    }

    pub fn call_initStorageEvent(instance: *runtime.Instance, @"type": runtime.DOMString, bubbles: webidl.Opt(bool), cancelable: webidl.Opt(bool), key: webidl.Opt(?runtime.DOMString), oldValue: webidl.Opt(?runtime.DOMString), newValue: webidl.Opt(?runtime.DOMString), url: webidl.Opt(runtime.USVString), storageArea: webidl.Opt(?*runtime.Instance)) anyerror!void {
        return try StorageEventImpl.call_initStorageEvent(instance, @"type", bubbles, cancelable, key, oldValue, newValue, url, storageArea);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_initStorageEvent", 7, "Storage" },
    };
};
