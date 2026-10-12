//! Generated from: mediacapture-streams.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MediaDeviceInfoImpl = @import("impls").MediaDeviceInfo;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const MediaDeviceKind = @import("enums").MediaDeviceKind;
const DOMString = @import("typedefs").DOMString;

pub const MediaDeviceInfo = struct {
    pub const Meta = struct {
        pub const name = "MediaDeviceInfo";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "deviceId", "get_deviceId", null },
            .{ "kind", "get_kind", null },
            .{ "label", "get_label", null },
            .{ "groupId", "get_groupId", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "toJSON", "call_toJSON", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toJSON",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "deviceId", "get_deviceId", null },
            .{ "kind", "get_kind", null },
            .{ "label", "get_label", null },
            .{ "groupId", "get_groupId", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            deviceId: typedefs.DOMString = undefined,
            kind: enums.MediaDeviceKind = undefined,
            label: typedefs.DOMString = undefined,
            groupId: typedefs.DOMString = undefined,
            _internal: ?*MediaDeviceInfoImpl.InternalState = null,
        },
    );

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for MediaDeviceInfo
    /// Generated from [Default] toJSON extended attribute
    pub const MediaDeviceInfoToJSON = struct {
        deviceId: runtime.DOMString,
        kind: MediaDeviceKind,
        label: runtime.DOMString,
        groupId: runtime.DOMString,

        pub const default_to_json = true;
    };

    const delegates = .{
        .get_deviceId = &get_deviceId,
        .get_groupId = &get_groupId,
        .get_kind = &get_kind,
        .get_label = &get_label,

        .call_toJSON = &call_toJSON,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("MediaDeviceInfo has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(MediaDeviceInfoImpl, "init") and @hasDecl(MediaDeviceInfoImpl, "initOwn")) @compileError("MediaDeviceInfoImpl defines both init and initOwn");
        if (comptime @hasDecl(MediaDeviceInfoImpl, "init")) return MediaDeviceInfoImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(MediaDeviceInfoImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try MediaDeviceInfoImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(MediaDeviceInfoImpl, "init")) return false;
        if (comptime @hasDecl(MediaDeviceInfoImpl, "construction_args")) {
            inline for (MediaDeviceInfoImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(MediaDeviceInfoImpl, "deinit") and @hasDecl(MediaDeviceInfoImpl, "deinitOwn")) @compileError("MediaDeviceInfoImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(MediaDeviceInfoImpl, "deinit")) return MediaDeviceInfoImpl.deinit(instance);
        if (comptime @hasDecl(MediaDeviceInfoImpl, "deinitOwn")) MediaDeviceInfoImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "MediaDeviceInfo")) {
            if (comptime @hasDecl(impls.MediaDeviceInfo, "installHooks")) impls.MediaDeviceInfo.installHooks();
        }
    }

    pub fn get_deviceId(instance: *runtime.Instance) anyerror!DOMString {
        return try MediaDeviceInfoImpl.get_deviceId(instance);
    }

    pub fn get_kind(instance: *runtime.Instance) anyerror!MediaDeviceKind {
        return try MediaDeviceInfoImpl.get_kind(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!DOMString {
        return try MediaDeviceInfoImpl.get_label(instance);
    }

    pub fn get_groupId(instance: *runtime.Instance) anyerror!DOMString {
        return try MediaDeviceInfoImpl.get_groupId(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!MediaDeviceInfoToJSON {
        return try MediaDeviceInfoImpl.call_toJSON(instance);
    }
};
