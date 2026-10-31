//! Generated from: webrtc.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const RTCSessionDescriptionImpl = @import("impls").RTCSessionDescription;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const RTCSessionDescriptionInit = @import("dictionaries").RTCSessionDescriptionInit;
const DOMString = @import("typedefs").DOMString;
const RTCSdpType = @import("enums").RTCSdpType;

pub const RTCSessionDescription = struct {
    pub const Meta = struct {
        pub const name = "RTCSessionDescription";
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
            .{ "type", "get_type", null },
            .{ "sdp", "get_sdp", null },
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
            .{ "type", "get_type", null },
            .{ "sdp", "get_sdp", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            type: enums.RTCSdpType = undefined,
            sdp: runtime.DOMString = undefined,
            _internal: ?*RTCSessionDescriptionImpl.InternalState = null,
        },
    );

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for RTCSessionDescription
    /// Generated from [Default] toJSON extended attribute
    pub const RTCSessionDescriptionToJSON = struct {
        type: RTCSdpType,
        sdp: runtime.DOMString,

        pub const default_to_json = true;
    };

    const delegates = .{
        .get_sdp = &get_sdp,
        .get_type = &get_type,

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
        inline for (@typeInfo(@TypeOf(args)).@"struct".field_names) |field_name| {
            if (comptime !takesConstructionArg(field_name)) @compileError("RTCSessionDescription has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(RTCSessionDescriptionImpl, "init") and @hasDecl(RTCSessionDescriptionImpl, "initOwn")) @compileError("RTCSessionDescriptionImpl defines both init and initOwn");
        if (comptime @hasDecl(RTCSessionDescriptionImpl, "init")) return RTCSessionDescriptionImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(RTCSessionDescriptionImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try RTCSessionDescriptionImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(RTCSessionDescriptionImpl, "init")) return false;
        if (comptime @hasDecl(RTCSessionDescriptionImpl, "construction_args")) {
            inline for (RTCSessionDescriptionImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(RTCSessionDescriptionImpl, "deinit") and @hasDecl(RTCSessionDescriptionImpl, "deinitOwn")) @compileError("RTCSessionDescriptionImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(RTCSessionDescriptionImpl, "deinit")) return RTCSessionDescriptionImpl.deinit(instance);
        if (comptime @hasDecl(RTCSessionDescriptionImpl, "deinitOwn")) RTCSessionDescriptionImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "RTCSessionDescription")) {
            if (comptime @hasDecl(impls.RTCSessionDescription, "installHooks")) impls.RTCSessionDescription.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 1;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, descriptionInitDict: RTCSessionDescriptionInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try RTCSessionDescriptionImpl.call_constructor(ctx, descriptionInitDict);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!RTCSdpType {
        return try RTCSessionDescriptionImpl.get_type(instance);
    }

    pub fn get_sdp(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try RTCSessionDescriptionImpl.get_sdp(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!RTCSessionDescriptionToJSON {
        return try RTCSessionDescriptionImpl.call_toJSON(instance);
    }
};
