//! Generated from: encoding.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TextDecoderStreamImpl = @import("impls").TextDecoderStream;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const TextDecoderCommon = @import("mixins").TextDecoderCommon;
const GenericTransformStream = @import("mixins").GenericTransformStream;
const ReadableStream = @import("interfaces").ReadableStream;
const TextDecoderOptions = @import("dictionaries").TextDecoderOptions;
const WritableStream = @import("interfaces").WritableStream;
const DOMString = @import("typedefs").DOMString;

pub const TextDecoderStream = struct {
    pub const Meta = struct {
        pub const name = "TextDecoderStream";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{
            TextDecoderCommon,
            GenericTransformStream,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "encoding", "get_encoding", null },
            .{ "fatal", "get_fatal", null },
            .{ "ignoreBOM", "get_ignoreBOM", null },
            .{ "readable", "get_readable", null },
            .{ "writable", "get_writable", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "encoding", "get_encoding", null },
            .{ "fatal", "get_fatal", null },
            .{ "ignoreBOM", "get_ignoreBOM", null },
            .{ "readable", "get_readable", null },
            .{ "writable", "get_writable", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            encoding: runtime.DOMString = undefined,
            fatal: bool = undefined,
            ignoreBOM: bool = undefined,
            readable: *runtime.Instance = undefined,
            writable: *runtime.Instance = undefined,
            _internal: ?*TextDecoderStreamImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_encoding = &get_encoding,
        .get_fatal = &get_fatal,
        .get_ignoreBOM = &get_ignoreBOM,
        .get_readable = &get_readable,
        .get_writable = &get_writable,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("TextDecoderStream has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(TextDecoderStreamImpl, "init") and @hasDecl(TextDecoderStreamImpl, "initOwn")) @compileError("TextDecoderStreamImpl defines both init and initOwn");
        if (comptime @hasDecl(TextDecoderStreamImpl, "init")) return TextDecoderStreamImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(TextDecoderStreamImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try TextDecoderStreamImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(TextDecoderStreamImpl, "init")) return false;
        if (comptime @hasDecl(TextDecoderStreamImpl, "construction_args")) {
            inline for (TextDecoderStreamImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(TextDecoderStreamImpl, "deinit") and @hasDecl(TextDecoderStreamImpl, "deinitOwn")) @compileError("TextDecoderStreamImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(TextDecoderStreamImpl, "deinit")) return TextDecoderStreamImpl.deinit(instance);
        if (comptime @hasDecl(TextDecoderStreamImpl, "deinitOwn")) TextDecoderStreamImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "TextDecoderStream")) {
            if (comptime @hasDecl(impls.TextDecoderStream, "installHooks")) impls.TextDecoderStream.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 0;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, label: webidl.Opt(runtime.DOMString), options: webidl.Opt(TextDecoderOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try TextDecoderStreamImpl.call_constructor(ctx, label, options);
    }

    pub fn get_encoding(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try TextDecoderStreamImpl.get_encoding(instance);
    }

    pub fn get_fatal(instance: *runtime.Instance) anyerror!bool {
        return try TextDecoderStreamImpl.get_fatal(instance);
    }

    pub fn get_ignoreBOM(instance: *runtime.Instance) anyerror!bool {
        return try TextDecoderStreamImpl.get_ignoreBOM(instance);
    }

    pub fn get_readable(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try TextDecoderStreamImpl.get_readable(instance);
    }

    pub fn get_writable(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try TextDecoderStreamImpl.get_writable(instance);
    }
};
