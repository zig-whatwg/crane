const std = @import("std");
const events = @import("csp").violation_events;

test "CSP deprecated report includes required empty fields and omits absent source location" {
    const allocator = std.testing.allocator;
    const body: events.ReportBody = .{
        .document_url = "https://example.test/page?x=1",
        .blocked_url = "https://other.test",
        .effective_directive = "frame-src",
        .original_policy = "frame-src 'none'; report-uri /report",
        .status_code = 200,
    };
    const bytes = try body.serializeLegacy(allocator);
    defer allocator.free(bytes);
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, bytes, .{});
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 1), parsed.value.object.count());
    const report = parsed.value.object.get("csp-report").?.object;
    try std.testing.expectEqual(@as(usize, 9), report.count());
    try std.testing.expectEqualStrings(body.document_url, report.get("document-uri").?.string);
    try std.testing.expectEqualStrings(body.blocked_url, report.get("blocked-uri").?.string);
    try std.testing.expectEqualStrings("", report.get("referrer").?.string);
    try std.testing.expectEqualStrings("", report.get("script-sample").?.string);
    try std.testing.expectEqualStrings("frame-src", report.get("effective-directive").?.string);
    try std.testing.expectEqualStrings("frame-src", report.get("violated-directive").?.string);
    try std.testing.expectEqualStrings("enforce", report.get("disposition").?.string);
    try std.testing.expectEqual(@as(i64, 200), report.get("status-code").?.integer);
    try std.testing.expect(!report.contains("source-file"));
    try std.testing.expect(!report.contains("line-number"));
    try std.testing.expect(!report.contains("column-number"));
}

test "CSP report round trips samples and includes a present zero source location" {
    const allocator = std.testing.allocator;
    const body: events.ReportBody = .{
        .document_url = "https://example.test/page",
        .blocked_url = "inline",
        .effective_directive = "script-src-elem",
        .original_policy = "script-src 'report-sample' 'nonce-abc'",
        .sample = "alert(\"\\\u{e9}\");\n\r\t\x00",
        .disposition = .report,
        .source_file = "https://example.test/script.js",
        .line_number = 0,
        .column_number = std.math.maxInt(u32),
    };
    const bytes = try body.serializeLegacy(allocator);
    defer allocator.free(bytes);
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, bytes, .{});
    defer parsed.deinit();
    const report = parsed.value.object.get("csp-report").?.object;
    try std.testing.expectEqual(@as(usize, 12), report.count());
    try std.testing.expectEqualStrings(body.sample, report.get("script-sample").?.string);
    try std.testing.expectEqualStrings(body.original_policy, report.get("original-policy").?.string);
    try std.testing.expectEqualStrings(body.source_file.?, report.get("source-file").?.string);
    try std.testing.expectEqualStrings("report", report.get("disposition").?.string);
    try std.testing.expectEqual(@as(i64, 0), report.get("line-number").?.integer);
    try std.testing.expectEqual(@as(i64, std.math.maxInt(u32)), report.get("column-number").?.integer);
}

test "CSP Reporting API body preserves null location fields and uses camel case keys" {
    const allocator = std.testing.allocator;
    const body: events.ReportBody = .{
        .document_url = "https://example.test/page",
        .blocked_url = "inline",
        .effective_directive = "style-src-attr",
        .original_policy = "style-src 'none'",
        .sample = "color: red",
        .line_number = 10,
        .column_number = 20,
    };
    const bytes = try body.serializeModern(allocator);
    defer allocator.free(bytes);
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, bytes, .{});
    defer parsed.deinit();
    const report = parsed.value.object;
    try std.testing.expectEqual(@as(usize, 11), report.count());
    try std.testing.expectEqualStrings(body.document_url, report.get("documentURL").?.string);
    try std.testing.expectEqualStrings(body.blocked_url, report.get("blockedURL").?.string);
    try std.testing.expectEqualStrings(body.sample, report.get("sample").?.string);
    try std.testing.expectEqualStrings(body.effective_directive, report.get("effectiveDirective").?.string);
    try std.testing.expectEqualStrings(body.original_policy, report.get("originalPolicy").?.string);
    try std.testing.expectEqualStrings("", report.get("referrer").?.string);
    try std.testing.expectEqualStrings("enforce", report.get("disposition").?.string);
    try std.testing.expectEqual(@as(i64, 0), report.get("statusCode").?.integer);
    try std.testing.expect(report.get("sourceFile").? == .null);
    try std.testing.expect(report.get("lineNumber").? == .null);
    try std.testing.expect(report.get("columnNumber").? == .null);
    try std.testing.expect(!report.contains("csp-report"));
    try std.testing.expect(!report.contains("violatedDirective"));
}
