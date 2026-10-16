const std = @import("std");
const csp = @import("csp");
const sandbox = csp.directives.sandbox;

test "sandbox ignores report-only and meta delivery" {
    const cases = [_]struct { source: csp.PolicySource, disposition: csp.PolicyDisposition }{
        .{ .source = .header, .disposition = .report },
        .{ .source = .meta, .disposition = .enforce },
        .{ .source = .meta, .disposition = .report },
    };
    for (cases) |case| {
        var policy = try csp.parseSerializedCSP(std.testing.allocator, "sandbox", case.source, case.disposition);
        defer policy.deinit();
        try std.testing.expect(sandbox.getSandboxFlags(&policy) == null);
    }
}

test "sandbox intersects only enforced header policies" {
    var list = csp.CSPList.init(std.testing.allocator);
    defer list.deinit();
    try list.append(try csp.parseSerializedCSP(std.testing.allocator, "sandbox allow-scripts allow-same-origin allow-forms", .header, .enforce));
    try list.append(try csp.parseSerializedCSP(std.testing.allocator, "sandbox", .header, .report));
    try list.append(try csp.parseSerializedCSP(std.testing.allocator, "sandbox", .meta, .enforce));
    try std.testing.expect(sandbox.areScriptsAllowed(&list));
    try std.testing.expect(sandbox.areFormsAllowed(&list));
    try std.testing.expect(sandbox.getCombinedSandboxFlags(&list).?.allow_same_origin);
    try list.append(try csp.parseSerializedCSP(std.testing.allocator, "sandbox allow-scripts", .header, .enforce));
    const flags = sandbox.getCombinedSandboxFlags(&list).?;
    try std.testing.expect(flags.allow_scripts);
    try std.testing.expect(!flags.allow_forms);
    try std.testing.expect(!flags.allow_same_origin);
}
