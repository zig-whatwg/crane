//! Generated from: cssom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MediaListImpl = @import("impls").MediaList;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSOMString = @import("typedefs").CSSOMString;

pub const MediaList = struct {
    pub const Meta = struct {
        pub const name = "MediaList";
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
            .{ "mediaText", "get_mediaText", "set_mediaText" },
            .{ "length", "get_length", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "item", "call_item", 1 },
            .{ "appendMedium", "call_appendMedium", 1 },
            .{ "deleteMedium", "call_deleteMedium", 1 },
            .{ "toString", "get_mediaText", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "item",
            "appendMedium",
            "deleteMedium",
            "toString",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "mediaText", "get_mediaText", "set_mediaText" },
            .{ "length", "get_length", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// WebIDL 2.5.6 special operations, own or inherited (the derived-most):
        /// the function that runs each. The binding installs indexed and named
        /// property handlers from this table (webidl.SpecialOperations).
        pub const special_operations: webidl.SpecialOperations = .{
            .indexed_getter = .{ .function = "call_item" },
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            mediaText: typedefs.CSSOMString = undefined,
            length: u32 = undefined,
            _internal: ?*MediaListImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_length = &get_length,
        .get_mediaText = &get_mediaText,

        .set_mediaText = &set_mediaText,

        .call_appendMedium = &call_appendMedium,
        .call_deleteMedium = &call_deleteMedium,
        .call_item = &call_item,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("MediaList has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(MediaListImpl, "init") and @hasDecl(MediaListImpl, "initOwn")) @compileError("MediaListImpl defines both init and initOwn");
        if (comptime @hasDecl(MediaListImpl, "init")) return MediaListImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(MediaListImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try MediaListImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(MediaListImpl, "init")) return false;
        if (comptime @hasDecl(MediaListImpl, "construction_args")) {
            inline for (MediaListImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return false;
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(MediaListImpl, "deinit") and @hasDecl(MediaListImpl, "deinitOwn")) @compileError("MediaListImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(MediaListImpl, "deinit")) return MediaListImpl.deinit(instance);
        if (comptime @hasDecl(MediaListImpl, "deinitOwn")) MediaListImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "MediaList")) {
            if (comptime @hasDecl(impls.MediaList, "installHooks")) impls.MediaList.installHooks();
        }
    }

    /// Extended attributes: [Stringifier], [LegacyNullToEmptyString]
    pub fn get_mediaText(instance: *runtime.Instance) anyerror!CSSOMString {
        return try MediaListImpl.get_mediaText(instance);
    }

    /// Extended attributes: [Stringifier], [LegacyNullToEmptyString]
    pub fn set_mediaText(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try MediaListImpl.set_mediaText(instance, value);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try MediaListImpl.get_length(instance);
    }

    pub fn call_appendMedium(instance: *runtime.Instance, medium: CSSOMString) anyerror!void {
        return try MediaListImpl.call_appendMedium(instance, medium);
    }

    pub fn call_deleteMedium(instance: *runtime.Instance, medium: CSSOMString) anyerror!void {
        return try MediaListImpl.call_deleteMedium(instance, medium);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?CSSOMString {
        return try MediaListImpl.call_item(instance, index);
    }

    /// WebIDL [LegacyNullToEmptyString]: the values null converts to "" for
    /// (bit i = argument i; an attribute setter's value is bit 0).
    pub const legacy_null_to_empty = .{
        .{ "set_mediaText", 0b1 },
    };
};
