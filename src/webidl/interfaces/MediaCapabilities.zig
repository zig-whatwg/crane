//! Generated from: media-capabilities.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MediaCapabilitiesImpl = @import("impls").MediaCapabilities;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const MediaCapabilitiesEncodingInfo = @import("dictionaries").MediaCapabilitiesEncodingInfo;
const MediaEncodingConfiguration = @import("dictionaries").MediaEncodingConfiguration;
const MediaDecodingConfiguration = @import("dictionaries").MediaDecodingConfiguration;
const MediaCapabilitiesDecodingInfo = @import("dictionaries").MediaCapabilitiesDecodingInfo;

pub const MediaCapabilities = struct {
    pub const Meta = struct {
        pub const name = "MediaCapabilities";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "decodingInfo", "call_decodingInfo", 1 },
            .{ "encodingInfo", "call_encodingInfo", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "decodingInfo",
            "encodingInfo",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*MediaCapabilitiesImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_decodingInfo = &call_decodingInfo,
        .call_encodingInfo = &call_encodingInfo,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("MediaCapabilities has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(MediaCapabilitiesImpl, "init") and @hasDecl(MediaCapabilitiesImpl, "initOwn")) @compileError("MediaCapabilitiesImpl defines both init and initOwn");
        if (comptime @hasDecl(MediaCapabilitiesImpl, "init")) return MediaCapabilitiesImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(MediaCapabilitiesImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try MediaCapabilitiesImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(MediaCapabilitiesImpl, "init")) return false;
        if (comptime @hasDecl(MediaCapabilitiesImpl, "construction_args")) {
            inline for (MediaCapabilitiesImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(MediaCapabilitiesImpl, "deinit") and @hasDecl(MediaCapabilitiesImpl, "deinitOwn")) @compileError("MediaCapabilitiesImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(MediaCapabilitiesImpl, "deinit")) return MediaCapabilitiesImpl.deinit(instance);
        if (comptime @hasDecl(MediaCapabilitiesImpl, "deinitOwn")) MediaCapabilitiesImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "MediaCapabilities")) {
            if (comptime @hasDecl(impls.MediaCapabilities, "installHooks")) impls.MediaCapabilities.installHooks();
        }
    }

    /// Extended attributes: [NewObject]
    pub fn call_encodingInfo(instance: *runtime.Instance, configuration: MediaEncodingConfiguration) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object

        return try MediaCapabilitiesImpl.call_encodingInfo(instance, configuration);
    }

    /// Extended attributes: [NewObject]
    pub fn call_decodingInfo(instance: *runtime.Instance, configuration: MediaDecodingConfiguration) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object

        return try MediaCapabilitiesImpl.call_decodingInfo(instance, configuration);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_encodingInfo",
        "call_decodingInfo",
    };
};
