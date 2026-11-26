//! MIME Sniffing, "rules for identifying an unknown MIME type": each HTML
//! row's pattern ends with a tag-terminating byte, "any one of the following
//! bytes: 0x20 (SP), 0x3E (">")" (mimesniff §3, Terminology). Lane core1 found
//! that only SP was taken: an unlabeled `<!DOCTYPE html>` resource computed as
//! text/plain (html_core's object_resource_type test, which had never run).

const std = @import("std");
const infra = @import("infra");
const mimesniff = @import("mimesniff");

/// The computed MIME type's essence for `header` with the sniff-scriptable
/// flag set, owned by the testing allocator; null for none.
fn computed(header: []const u8) !?[]const u8 {
    const allocator = std.testing.allocator;
    var mt = (try mimesniff.identifyUnknownMimeType(allocator, header, true)) orelse return null;
    defer mt.deinit();
    const essence = try mt.essence(allocator);
    defer allocator.free(essence);
    return try infra.bytes.isomorphicEncode(allocator, essence);
}

fn expectComputed(expected: []const u8, header: []const u8) !void {
    const got = (try computed(header)) orelse {
        std.debug.print("no computed type for \"{s}\"\n", .{header});
        return error.TestExpectedEqual;
    };
    defer std.testing.allocator.free(got);
    std.testing.expectEqualStrings(expected, got) catch |err| {
        std.debug.print("header \"{s}\"\n", .{header});
        return err;
    };
}

/// Each HTML row's string before its tag-terminating byte.
const html_rows = [_][]const u8{
    "<!DOCTYPE HTML", "<HTML",  "<HEAD",  "<SCRIPT", "<IFRAME", "<H1", "<DIV", "<FONT", "<TABLE",
    "<A",             "<STYLE", "<TITLE", "<B",      "<BODY",   "<BR", "<P",   "<!--",
};

test "every HTML row ends with a space or a '>', after leading whitespace, in either case" {
    for (html_rows) |row| {
        for ([_][]const u8{ " ", ">" }) |terminator| {
            var buf: [64]u8 = undefined;
            try expectComputed("text/html", try std.fmt.bufPrint(&buf, "{s}{s}rest", .{ row, terminator }));
            try expectComputed("text/html", try std.fmt.bufPrint(&buf, "\n\t {s}{s}", .{ row, terminator }));
            // The rows are case-insensitive but for "<!--".
            const lower = std.ascii.lowerString(buf[32..][0..row.len], row);
            try expectComputed("text/html", try std.fmt.bufPrint(buf[0..32], "{s}{s}", .{ lower, terminator }));
        }
    }
    try expectComputed("text/html", "<!DOCTYPE html><p>x");
}

test "no other byte terminates a tag" {
    // "<Bx", "<HTML/", "<P\t", "<!---": the row's string, then a byte that is
    // not 0x20 or 0x3E - so no HTML row matches, and the text rules decide.
    for ([_][]const u8{ "<Bx", "<HTML/", "<P\tx", "<!---x" }) |header| {
        const got = try computed(header);
        defer if (got) |g| std.testing.allocator.free(g);
        try std.testing.expect(got == null or !std.mem.eql(u8, got.?, "text/html"));
    }
}
