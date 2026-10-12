//! Generated from: image-capture.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ImageCaptureImpl = @import("impls").ImageCapture;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const PhotoSettings = @import("dictionaries").PhotoSettings;
const MediaStreamTrack = @import("interfaces").MediaStreamTrack;
const PhotoCapabilities = @import("dictionaries").PhotoCapabilities;
const Blob = @import("interfaces").Blob;
const ImageBitmap = @import("interfaces").ImageBitmap;

pub const ImageCapture = struct {
    pub const Meta = struct {
        pub const name = "ImageCapture";
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
            .{ "track", "get_track", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "takePhoto", "call_takePhoto", 0 },
            .{ "getPhotoCapabilities", "call_getPhotoCapabilities", 0 },
            .{ "getPhotoSettings", "call_getPhotoSettings", 0 },
            .{ "grabFrame", "call_grabFrame", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "takePhoto",
            "getPhotoCapabilities",
            "getPhotoSettings",
            "grabFrame",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "track", "get_track", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            track: *runtime.Instance = undefined,
            _internal: ?*ImageCaptureImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_track = &get_track,

        .call_getPhotoCapabilities = &call_getPhotoCapabilities,
        .call_getPhotoSettings = &call_getPhotoSettings,
        .call_grabFrame = &call_grabFrame,
        .call_takePhoto = &call_takePhoto,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("ImageCapture has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(ImageCaptureImpl, "init") and @hasDecl(ImageCaptureImpl, "initOwn")) @compileError("ImageCaptureImpl defines both init and initOwn");
        if (comptime @hasDecl(ImageCaptureImpl, "init")) return ImageCaptureImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(ImageCaptureImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try ImageCaptureImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ImageCaptureImpl, "init")) return false;
        if (comptime @hasDecl(ImageCaptureImpl, "construction_args")) {
            inline for (ImageCaptureImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(ImageCaptureImpl, "deinit") and @hasDecl(ImageCaptureImpl, "deinitOwn")) @compileError("ImageCaptureImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(ImageCaptureImpl, "deinit")) return ImageCaptureImpl.deinit(instance);
        if (comptime @hasDecl(ImageCaptureImpl, "deinitOwn")) ImageCaptureImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ImageCapture")) {
            if (comptime @hasDecl(impls.ImageCapture, "installHooks")) impls.ImageCapture.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, videoTrack: *runtime.Instance) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ImageCaptureImpl.call_constructor(ctx, videoTrack);
    }

    pub fn get_track(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ImageCaptureImpl.get_track(instance);
    }

    pub fn call_takePhoto(instance: *runtime.Instance, photoSettings: webidl.Opt(PhotoSettings)) anyerror!runtime.JSValue {
        return try ImageCaptureImpl.call_takePhoto(instance, photoSettings);
    }

    pub fn call_getPhotoCapabilities(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ImageCaptureImpl.call_getPhotoCapabilities(instance);
    }

    pub fn call_getPhotoSettings(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ImageCaptureImpl.call_getPhotoSettings(instance);
    }

    pub fn call_grabFrame(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ImageCaptureImpl.call_grabFrame(instance);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_takePhoto",
        "call_getPhotoCapabilities",
        "call_getPhotoSettings",
        "call_grabFrame",
    };
};
