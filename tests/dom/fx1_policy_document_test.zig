//! Permissions Policy construction precedes script; quota reservation uses
//! inherited policy values, independently of the child Document's lifetime.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const Policies = dom.policy_containers.Policies;
const testing = std.testing;

const Fixture = struct {
    context: runtime.ContextData,

    fn init(self: *Fixture) !void {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(testing.allocator);
        errdefer runtime.deinitializeRuntime();
        self.context = try runtime.ContextData.init(testing.allocator, .{});
    }
    fn deinit(self: *Fixture) void {
        self.context.deinit();
        runtime.deinitializeRuntime();
    }
    fn document(self: *Fixture, header: ?[]const u8) !*runtime.Instance {
        const origin = try dom.origin_record.OriginRecord.create(testing.allocator, "https://parent.test");
        defer origin.release();
        var policies = try Policies.fromHeaders(testing.allocator, origin, null, null, .{ .enforce = header });
        errdefer policies.deinit();
        return interfaces.Document.initWith(testing.allocator, &self.context, .{ .origin = origin, .permissions_policy = policies });
    }
};

fn onThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            body() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

test "Document takes permissions policy through its generated construction chain" {
    try testing.expect(interfaces.Document.takesConstructionArg("permissions_policy"));
    try testing.expect(interfaces.XMLDocument.takesConstructionArg("permissions_policy"));
    try testing.expect(!interfaces.Node.takesConstructionArg("permissions_policy"));
    try onThread(documentPolicy);
}

fn documentPolicy() !void {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();
    const document = try fixture.document("deferred-fetch=();report-to=denied");
    defer interfaces.Document.deinit(document);
    const policies = dom.policy_containers.permissionsOf(document) orelse return error.MissingPolicy;
    const origin = (try dom.document_origin.shareable(document)).?;
    const checked = try policies.check(.deferred_fetch, .{ .serialized = origin.serialized.?, .record = origin });
    try testing.expect(!checked.enabled);
    try testing.expectEqualStrings("denied", checked.violation.?.endpoint.?);
    // HTML allowed-to-use steps 1–2: a windowless Document cannot use a
    // feature even when its policy grants it.
    try testing.expect(!try dom.policy_containers.allowedToUse(document, .deferred_fetch_minimal));
}

fn element(document: *runtime.Instance, local_name: []const u8) !*runtime.Instance {
    return interfaces.Document.call_createElement(document, .initInterned(local_name), .notPassed());
}

fn attribute(node: *runtime.Instance, name: []const u8, value: []const u8) !void {
    try interfaces.Element.call_setAttribute(node, .initInterned(name), .{ .domstring = .initInterned(value) });
}

fn expectInherited(container: *runtime.Instance, serialized: []const u8, full: bool, minimal: bool) !void {
    const target: dom.origin_record.Origin = .{ .serialized = serialized };
    const result = try dom.policy_containers.inheritedDeferredFetchPolicy(container, &target);
    try testing.expectEqual(full, result.deferred_fetch);
    try testing.expectEqual(minimal, result.deferred_fetch_minimal);
}

test "quota reservation checks actual allow and declared src without a child document" {
    try onThread(inheritedForContainer);
}

fn inheritedForContainer() !void {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();
    const document = try fixture.document(null);
    defer interfaces.Document.deinit(document);
    try dom.document_internals.setDocumentType(document, .html);
    try dom.document_internals.setURL(document, "https://parent.test/page");
    const iframe = try element(document, "iframe");
    defer dom.node_creation.destroyUninserted(iframe);
    try attribute(iframe, "src", "https://child.test/page");
    try expectInherited(iframe, "https://child.test", false, true);
    try attribute(iframe, "allow", "deferred-fetch");
    try expectInherited(iframe, "https://child.test", true, true);
    try expectInherited(iframe, "https://redirected.test", false, true);
    try attribute(iframe, "allow", "deferred-fetch *; deferred-fetch-minimal 'none'");
    try expectInherited(iframe, "https://redirected.test", true, false);
    try attribute(iframe, "allow", "deferred-fetch 'self'");
    try expectInherited(iframe, "https://parent.test", true, true);
    try expectInherited(iframe, "https://child.test", false, true);
    try attribute(iframe, "allow", "deferred-fetch");
    try attribute(iframe, "srcdoc", "<p>child</p>");
    try expectInherited(iframe, "https://parent.test", true, true);
    try expectInherited(iframe, "https://child.test", false, true);
    try attribute(iframe, "sandbox", "allow-scripts");
    try expectInherited(iframe, "null", false, true);
    try attribute(iframe, "allow", "deferred-fetch *");
    try expectInherited(iframe, "null", true, true);

    // §9.4: frame is a navigable container, but has no iframe allow policy.
    const frame = try element(document, "frame");
    defer dom.node_creation.destroyUninserted(frame);
    try attribute(frame, "allow", "deferred-fetch *");
    try expectInherited(frame, "https://child.test", false, true);
    try expectInherited(frame, "https://parent.test", true, true);
}

test "parent response denial cannot be widened by a container allow attribute" {
    try onThread(parentDenial);
}

fn parentDenial() !void {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();
    const document = try fixture.document("deferred-fetch=(), deferred-fetch-minimal=()");
    defer interfaces.Document.deinit(document);
    try dom.document_internals.setDocumentType(document, .html);
    const iframe = try element(document, "iframe");
    defer dom.node_creation.destroyUninserted(iframe);
    try attribute(iframe, "allow", "deferred-fetch *; deferred-fetch-minimal *");
    try expectInherited(iframe, "https://parent.test", false, false);
    try expectInherited(iframe, "https://child.test", false, false);
}

fn expectLazyInteractions(document: *runtime.Instance) !void {
    try testing.expect(dom.document_autofocus.ofDocument(document) == null);
    try testing.expect(try dom.top_layer.ofDocument(document, false) == null);
}

fn constructAtFailure(allocator: std.mem.Allocator, context: runtime.Context, supplied: bool) !void {
    const origin = try dom.origin_record.OriginRecord.create(allocator, "https://parent.test");
    defer origin.release();
    if (supplied) {
        var input = try Policies.fromHeaders(allocator, origin, null, null, .{
            .enforce = "deferred-fetch=();report-to=owned",
        });
        var taken = false;
        defer if (!taken) input.deinit();
        const document = try interfaces.Document.initWith(allocator, context, .{ .origin = origin, .permissions_policy = input });
        taken = true;
        defer interfaces.Document.deinit(document);
        try expectLazyInteractions(document);
        const owned = dom.policy_containers.permissionsOf(document) orelse return error.MissingPolicy;
        const check = try owned.check(.deferred_fetch, .{ .serialized = origin.serialized.?, .record = origin });
        try testing.expect(!check.enabled);
        try testing.expectEqualStrings("owned", check.violation.?.endpoint.?);
    } else {
        const document = try interfaces.Document.initWith(allocator, context, .{ .origin = origin });
        defer interfaces.Document.deinit(document);
        try expectLazyInteractions(document);
        const owned = dom.policy_containers.permissionsOf(document) orelse return error.MissingPolicy;
        try testing.expect((try owned.check(.deferred_fetch, .{ .serialized = origin.serialized.?, .record = origin })).enabled);
    }
}

fn allocationFailures() !void {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();
    // As in xm1_svg_interfaces_test, the per-thread slab/context keeps its
    // leak-checking allocator; fail allocations in the construction chain.
    try testing.checkAllAllocationFailures(testing.allocator, constructAtFailure, .{ &fixture.context, false });
    try testing.checkAllAllocationFailures(testing.allocator, constructAtFailure, .{ &fixture.context, true });
}

test "Document policy construction takes ownership only on success under every allocation failure" {
    try onThread(allocationFailures);
}

fn interactionAllocationFailures() !void {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();
    // Q57/Q58: policy ownership is eager; each interaction's allocation is
    // still lazy, and a failed first use must preserve the policy owner.
    for ([_]bool{ false, true }) |supplied| {
        for ([_]bool{ false, true }) |autofocus| {
            var failing = testing.FailingAllocator.init(testing.allocator, .{});
            const allocator = failing.allocator();
            const origin = try dom.origin_record.OriginRecord.create(allocator, "https://parent.test");
            defer origin.release();
            const document = if (supplied) blk: {
                var input = try Policies.fromHeaders(allocator, origin, null, null, .{
                    .enforce = "deferred-fetch=();report-to=owned",
                });
                errdefer input.deinit();
                break :blk try interfaces.Document.initWith(allocator, &fixture.context, .{ .origin = origin, .permissions_policy = input });
            } else try interfaces.Document.initWith(allocator, &fixture.context, .{ .origin = origin });
            defer interfaces.Document.deinit(document);
            const owned = dom.policy_containers.permissionsOf(document) orelse return error.MissingPolicy;
            try expectLazyInteractions(document);
            const before = failing.allocated_bytes - failing.freed_bytes;
            failing.fail_index = failing.alloc_index;
            if (autofocus) {
                try testing.expect(dom.document_autofocus.ensureForDocument(document) == null);
            } else {
                try testing.expectError(error.OutOfMemory, dom.top_layer.ofDocument(document, true));
            }
            try expectLazyInteractions(document);
            try testing.expectEqual(before, failing.allocated_bytes - failing.freed_bytes);
            try testing.expect(dom.policy_containers.permissionsOf(document) == owned);
            failing.fail_index = std.math.maxInt(usize);
            const checked = try owned.check(.deferred_fetch, .{ .serialized = origin.serialized.?, .record = origin });
            try testing.expectEqual(!supplied, checked.enabled);
            if (supplied) try testing.expectEqualStrings("owned", checked.violation.?.endpoint.?);
            try testing.expect(dom.document_autofocus.ensureForDocument(document) != null);
            try testing.expect(try dom.top_layer.ofDocument(document, true) != null);
            try testing.expect(dom.policy_containers.permissionsOf(document) == owned);
        }
    }
}

test "Document policy survives either lazy interaction's failed first allocation" {
    try onThread(interactionAllocationFailures);
}
