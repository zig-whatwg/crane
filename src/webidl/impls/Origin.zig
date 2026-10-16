//! HTML 7.1.1.3, the Origin interface. An Origin owns a reference to its
//! origin record, independently of the platform object it was extracted from.
//! https://html.spec.whatwg.org/multipage/browsers.html#the-origin-interface
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const engine = @import("engine");
const OriginRecord = dom.origin_record.OriginRecord;

pub const State = interfaces.Origin.State;
pub const construction_args = .{"origin"};

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    origin: *OriginRecord,
};

pub fn installHooks() void {
    dom.extract_origin.install(.origin, .{ .owns = &ownsOrigin, .extract = &extractOrigin });
}

/// The construction argument is borrowed. Each new Origin keeps its own
/// reference, as Blink's DOMOrigin keeps a scoped_refptr<SecurityOrigin>.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);
    internal.* = .{
        .allocator = allocator,
        .origin = if (@hasField(@TypeOf(args), "origin")) args.origin.retain() else try OriginRecord.create(allocator, "null"),
    };
    instance.getState(StateType).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    internal.origin.release();
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

/// Constructor step 1: a new opaque origin, unique to this object until copied.
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    return interfaces.Origin.init(ctx.allocator, ctx);
}

fn recordOf(instance: *runtime.Instance) !*OriginRecord {
    const state = instance.stateAs(State) orelse return error.TypeError;
    return (state.own._internal orelse return error.InvalidStateError).origin;
}

fn view(record: *const OriginRecord) dom.origin_record.Origin {
    return .{ .serialized = record.serialized orelse "null", .record = record };
}

/// The opaque getter returns whether this's origin is an opaque origin.
pub fn get_opaque(instance: *runtime.Instance) anyerror!bool {
    return (try recordOf(instance)).isOpaque();
}

pub fn call_isSameOrigin(instance: *runtime.Instance, other: *runtime.Instance) anyerror!bool {
    return dom.origin_record.sameOrigin(view(try recordOf(instance)), view(try recordOf(other)));
}

pub fn call_isSameSite(instance: *runtime.Instance, other: *runtime.Instance) anyerror!bool {
    const a = try recordOf(instance);
    const b = try recordOf(other);
    // "Obtain a site" step 1: an opaque origin is its own site. Equal
    // tuple origins also necessarily have equal sites.
    if (dom.origin_record.sameOrigin(view(a), view(b))) return true;
    if (a.isOpaque() or b.isOpaque()) return false;
    const allocator = instance.ctx.allocator;
    const a_site = try @import("html").agent_clusters.siteOf(allocator, view(a).serialized);
    defer allocator.free(a_site);
    const b_site = try @import("html").agent_clusters.siteOf(allocator, view(b).serialized);
    defer allocator.free(b_site);
    return std.mem.eql(u8, a_site, b_site);
}

/// Origin.from steps 1-3: platform extraction, else a primitive string's
/// basic URL parse, else TypeError. Objects are never string-coerced.
pub fn call_static_from(instance: *runtime.Instance, value: runtime.JSValue) anyerror!*runtime.Instance {
    const ctx = instance.ctx;
    const platform_object = switch (value) {
        .instance => |object| object,
        .handle => engine.convertToPlatformObject(ctx, value),
        else => null,
    };
    const record = if (platform_object) |object|
        (try dom.extract_origin.extract(object)) orelse return error.TypeError
    else switch (value) {
        .string => |string| (try dom.extract_origin.ownedRecordForUrl(ctx.allocator, string.data)) orelse return error.TypeError,
        .handle => blk: {
            if (engine.typeOf(ctx, value) != .string) return error.TypeError;
            const string = try engine.convertToUSVString(ctx, value, ctx.allocator);
            defer ctx.allocator.free(string);
            break :blk (try dom.extract_origin.ownedRecordForUrl(ctx.allocator, string)) orelse return error.TypeError;
        },
        else => return error.TypeError,
    };
    defer record.release();
    return interfaces.Origin.initWith(ctx.allocator, ctx, .{ .origin = record });
}

fn ownsOrigin(instance: *runtime.Instance) bool {
    return instance.stateAs(State) != null;
}

/// Origin's extract-an-origin steps return this's origin (with our own hold).
fn extractOrigin(instance: *runtime.Instance) !?*OriginRecord {
    return (try recordOf(instance)).retain();
}
