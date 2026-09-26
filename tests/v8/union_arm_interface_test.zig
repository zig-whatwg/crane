//! WebIDL §3.2.24 step 4 - which member interface a platform object goes to
//! in a union with interface arms.
//!
//! A generated union arm of interface type is a bare `*runtime.Instance`: the
//! Zig type does not say WHICH interface. The conversion used to put any
//! wrapped object into the first such arm, so `fetch(new URL(...))` handed a
//! URL to the Request constructor as a Request, and `div.append(blob)` handed
//! a Blob to the DOM as a Node. The interface is recovered from the arm's
//! name, which codegen derives from the interface's (`sanitizeTypeName`), and
//! the object's state ancestry is asked whether it implements it.
//!
//! An arm whose name maps to no interface cannot be checked and accepts any
//! platform object - the old behaviour. That default is pinned below, and so
//! is the property that makes it rare: every interface arm of every
//! generated union typedef maps to an interface.

const std = @import("std");
const v8 = @import("v8");
const runtime = @import("runtime");

const conv = v8.conversions;

fn nameOf(comptime arm: []const u8) ?[]const u8 {
    return conv.unionArmInterfaceName(arm);
}

test "arm names map back to the interfaces codegen derived them from" {
    try std.testing.expectEqualStrings("Request", nameOf("request").?);
    try std.testing.expectEqualStrings("Node", nameOf("node").?);
    try std.testing.expectEqualStrings("ReadableStream", nameOf("readable_stream").?);
    // Runs of capitals: no underscore until a capital follows a lower-case
    // letter.
    try std.testing.expectEqualStrings("URLSearchParams", nameOf("urlsearch_params").?);
    try std.testing.expectEqualStrings("HTMLVideoElement", nameOf("htmlvideo_element").?);
    try std.testing.expectEqualStrings("ReadableStreamBYOBReader", nameOf("readable_stream_byobreader").?);
    // A digit neither starts nor ends a word.
    try std.testing.expectEqualStrings("WebGL2RenderingContext", nameOf("web_gl2rendering_context").?);
}

test "a typedef of an interface type maps to the interface" {
    // MessageEventSource's first arm is WindowProxy, a typedef for Window.
    try std.testing.expectEqualStrings("Window", nameOf("window_proxy").?);
}

test "an arm naming no interface maps to nothing, so it cannot be checked" {
    // The default: `implementsArm` accepts any platform object for such an
    // arm - what every arm did before the check existed. It must stay rare;
    // the next test is what keeps it so.
    try std.testing.expect(nameOf("no_such_interface") == null);
    try std.testing.expect(nameOf("usvstring") == null);
    try std.testing.expect(nameOf("") == null);
}

test "every interface arm of every generated union typedef maps to an interface" {
    @setEvalBranchQuota(10_000_000);
    const typedefs = conv.generated_typedefs;
    var checked: usize = 0;
    inline for (comptime std.meta.declarations(typedefs)) |decl| {
        const T = @field(typedefs, decl.name);
        if (@TypeOf(T) == type and @typeInfo(T) == .@"union") {
            inline for (@typeInfo(T).@"union".fields) |field| {
                if (field.type == *runtime.Instance) {
                    if (comptime nameOf(field.name) == null) {
                        std.debug.print("{s}.{s} names no interface\n", .{ decl.name, field.name });
                        return error.UnmappedUnionArm;
                    }
                    checked += 1;
                }
            }
        }
    }
    // BodyInit, RequestInfo, MessageEventSource, BlobPart and the rest.
    try std.testing.expect(checked > 40);
}
