//! Generated from: FileAPI.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const FileReaderSyncImpl = @import("impls").FileReaderSync;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Blob = @import("interfaces").Blob;
const DOMString = @import("typedefs").DOMString;

pub const FileReaderSync = struct {
    pub const Meta = struct {
        pub const name = "FileReaderSync";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "DedicatedWorker", "SharedWorker" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .DedicatedWorker = true,
            .SharedWorker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "readAsArrayBuffer", "call_readAsArrayBuffer", 1 },
            .{ "readAsBinaryString", "call_readAsBinaryString", 1 },
            .{ "readAsText", "call_readAsText", 1 },
            .{ "readAsDataURL", "call_readAsDataURL", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "readAsArrayBuffer",
            "readAsBinaryString",
            "readAsText",
            "readAsDataURL",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*FileReaderSyncImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_readAsArrayBuffer = &call_readAsArrayBuffer,
        .call_readAsBinaryString = &call_readAsBinaryString,
        .call_readAsDataURL = &call_readAsDataURL,
        .call_readAsText = &call_readAsText,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("FileReaderSync has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(FileReaderSyncImpl, "init") and @hasDecl(FileReaderSyncImpl, "initOwn")) @compileError("FileReaderSyncImpl defines both init and initOwn");
        if (comptime @hasDecl(FileReaderSyncImpl, "init")) return FileReaderSyncImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(FileReaderSyncImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try FileReaderSyncImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(FileReaderSyncImpl, "init")) return false;
        if (comptime @hasDecl(FileReaderSyncImpl, "construction_args")) {
            inline for (FileReaderSyncImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(FileReaderSyncImpl, "deinit") and @hasDecl(FileReaderSyncImpl, "deinitOwn")) @compileError("FileReaderSyncImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(FileReaderSyncImpl, "deinit")) return FileReaderSyncImpl.deinit(instance);
        if (comptime @hasDecl(FileReaderSyncImpl, "deinitOwn")) FileReaderSyncImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "FileReaderSync")) {
            if (comptime @hasDecl(impls.FileReaderSync, "installHooks")) impls.FileReaderSync.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 0;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try FileReaderSyncImpl.call_constructor(ctx);
    }

    pub fn call_readAsDataURL(instance: *runtime.Instance, blob: *runtime.Instance) anyerror!runtime.DOMString {
        return try FileReaderSyncImpl.call_readAsDataURL(instance, blob);
    }

    pub fn call_readAsArrayBuffer(instance: *runtime.Instance, blob: *runtime.Instance) anyerror!runtime.JSValue {
        return try FileReaderSyncImpl.call_readAsArrayBuffer(instance, blob);
    }

    pub fn call_readAsBinaryString(instance: *runtime.Instance, blob: *runtime.Instance) anyerror!runtime.DOMString {
        return try FileReaderSyncImpl.call_readAsBinaryString(instance, blob);
    }

    pub fn call_readAsText(instance: *runtime.Instance, blob: *runtime.Instance, encoding: webidl.Opt(runtime.DOMString)) anyerror!runtime.DOMString {
        return try FileReaderSyncImpl.call_readAsText(instance, blob, encoding);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_readAsDataURL", 0, "Blob" },
        .{ "call_readAsArrayBuffer", 0, "Blob" },
        .{ "call_readAsBinaryString", 0, "Blob" },
        .{ "call_readAsText", 0, "Blob" },
    };
};
