//! HTML fetch-classic step 5: response charset, fallback, then BOM priority.
const std = @import("std");
const html = @import("html");
const fetch = @import("fetch");
const encoding = @import("html_core").parser.encoding_sniffing;

fn check(allocator: std.mem.Allocator) !void {
    var headers = fetch.internal.HeaderList.init(allocator);
    defer headers.deinit();
    try headers.append("Content-Type", "text/javascript; charset=windows-1250");
    // Fetch extract-MIME preserves the earlier same-essence charset.
    try headers.append("Content-Type", "text/javascript");
    const decoded = try html.script_execution.decodeClassicScript(allocator, "\x9c\xe6\xb9\xbf\x9f", &headers, encoding.utf_8);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("śćążź", decoded);
    const bom = try html.script_execution.decodeClassicScript(allocator, "\xff\xfeA\x00", &headers, encoding.utf_8);
    defer allocator.free(bom);
    try std.testing.expectEqualStrings("A", bom);
}

test "classic script decoding honors MIME charset and BOM without leaking on allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, check, .{});
}

test "unknown charset falls back and malformed UTF-8 is replaced" {
    const allocator = std.testing.allocator;
    var headers = fetch.internal.HeaderList.init(allocator);
    defer headers.deinit();
    try headers.append("Content-Type", "text/plain; charset=unknown");
    const legacy = try html.script_execution.decodeClassicScript(allocator, "\xe6", &headers, encoding.lookup("windows-1250").?);
    defer allocator.free(legacy);
    try std.testing.expectEqualStrings("ć", legacy);
    const invalid = try html.script_execution.decodeClassicScript(allocator, "\xef\xbb\xbf\xff", &headers, encoding.utf_8);
    defer allocator.free(invalid);
    try std.testing.expectEqualStrings("�", invalid);
}
