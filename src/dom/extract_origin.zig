//! HTML's platform-object "extract an origin" steps. Every successful
//! extraction gives its caller an OWNED OriginRecord on the current thread.
//! The caller releases it, or passes a borrowed view to a retaining holder.
//!
//! lint-impls: hook for Origin, URL, HTMLHyperlinkElementUtils, SVGAElement, WindowOrWorkerGlobalScope, MessageEvent, ExtendableMessageEvent
const std = @import("std");
const runtime = @import("runtime");
const process_start = @import("process_start.zig");
const OriginRecord = @import("origin_record.zig").OriginRecord;
const api_parser = @import("api_parser");
const origins = @import("fetch").internal.origins;

pub const Owner = enum { origin, url, hyperlink, svg_anchor, global, message_event, extendable_message_event };
pub const Implementation = struct {
    owns: *const fn (*runtime.Instance) bool,
    extract: *const fn (*runtime.Instance) anyerror!?*OriginRecord,
};

// process-wide: immutable extraction function pointers installed at process start, identical for every Browser and thread
var implementations: [@typeInfo(Owner).@"enum".field_names.len]?Implementation = @splat(null);

pub fn install(owner: Owner, steps: Implementation) void {
    process_start.assertInstalling();
    implementations[@intFromEnum(owner)] = steps;
}

/// A platform object without extraction steps returns null (HTML's default).
pub fn extract(instance: *runtime.Instance) !?*OriginRecord {
    for (implementations) |entry| {
        const steps = entry orelse continue;
        if (steps.owns(instance)) return steps.extract(instance);
    }
    return null;
}

/// URL Standard "origin", following basic URL parsing without a base.
/// Invalid input gives null; allocation failure remains an error. A "null"
/// serialization creates a fresh opaque record. Recovering a blob URL's
/// opaque creator identity needs the blob store's origin-record support.
pub fn ownedRecordForUrl(allocator: std.mem.Allocator, input: []const u8) !?*OriginRecord {
    var parsed = api_parser.parseURL(allocator, input, null) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return null,
    };
    defer parsed.deinit();
    // The shared serializer maps invalid input to "null", so retain the
    // validity check above: a failed parse is not an opaque origin.
    const serialized = try origins.serializedOriginOf(allocator, input);
    defer allocator.free(serialized);
    return try OriginRecord.create(allocator, serialized);
}
