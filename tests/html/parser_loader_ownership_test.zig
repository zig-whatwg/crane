//! Persistent parsers retain their loader independently of the initiating run.
const std = @import("std");
const html = @import("html");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

const LoaderContext = struct {
    allocator: std.mem.Allocator,
    references: usize = 1,
    releases: *usize,

    fn create(releases: *usize) !*LoaderContext {
        const self = try std.testing.allocator.create(LoaderContext);
        self.* = .{ .allocator = std.testing.allocator, .releases = releases };
        return self;
    }

    fn retain(context: ?*anyopaque) void {
        const self: *LoaderContext = @ptrCast(@alignCast(context.?));
        self.references += 1;
    }

    fn release(context: ?*anyopaque) void {
        const self: *LoaderContext = @ptrCast(@alignCast(context.?));
        self.releases.* += 1;
        self.references -= 1;
        if (self.references == 0) self.allocator.destroy(self);
    }

    fn load(context: ?*anyopaque, _: []const u8) ?[]const u8 {
        const self: *LoaderContext = @ptrCast(@alignCast(context.?));
        std.debug.assert(self.references > 0);
        return null;
    }

    fn descriptor(self: *LoaderContext) html.scripted_parser.ScriptLoader {
        return .{ .context = self, .loadScript = &load, .retain = &retain, .release = &release };
    }
};

test "an acquired loader outlives its initiating owner" {
    var releases: usize = 0;
    const context = try LoaderContext.create(&releases);
    var owned = context.descriptor().acquire();
    try std.testing.expectEqual(@as(usize, 2), context.references);
    LoaderContext.release(context);
    try std.testing.expect(owned.load("/late.js") == null);
    owned.deinit();
    try std.testing.expectEqual(@as(usize, 2), releases);
}

test "a complete-input parser releases its loader on synchronous EOF" {
    interfaces.process_hooks.startHooksForTest();
    const allocator = std.testing.allocator;
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(allocator, .{});
    defer ctx.deinit();
    var releases: usize = 0;
    const context = try LoaderContext.create(&releases);
    defer LoaderContext.release(context);
    const document = try html.scripted_parser.parseHTMLWithScripting(allocator, &ctx, "<!doctype html><p>done", .{ .script_loader = context.descriptor() });
    defer interfaces.Document.deinit(document);
    try std.testing.expectEqual(@as(usize, 1), context.references);
    try std.testing.expectEqual(@as(usize, 1), releases);
    try std.testing.expect(dom.document_internals.getInternal(document).?.active_parser == null);
}

test "a waiting parser releases its loader after its run owner disappears and it is canceled" {
    interfaces.process_hooks.startHooksForTest();
    const allocator = std.testing.allocator;
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(allocator, .{});
    defer ctx.deinit();
    const document = try interfaces.Document.init(allocator, &ctx);
    defer interfaces.Document.deinit(document);
    var releases: usize = 0;
    const context = try LoaderContext.create(&releases);
    const parser = try html.scripted_parser.DocumentParser.createComplete(allocator, &ctx, document, "<p>later", .{ .script_loader = context.descriptor() });
    try std.testing.expect(dom.document_lifecycle.associateParser(document, parser));
    parser.release(); // Document retains the waiting parser.
    LoaderContext.release(context); // The initiating run has already returned.
    try std.testing.expectEqual(@as(usize, 1), releases);
    dom.document_lifecycle.discardParser(document, null);
    try std.testing.expectEqual(@as(usize, 2), releases);
    try std.testing.expect(dom.document_internals.getInternal(document).?.active_parser == null);
}

test "document destruction releases a waiting parser's loader" {
    interfaces.process_hooks.startHooksForTest();
    const allocator = std.testing.allocator;
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(allocator, .{});
    defer ctx.deinit();
    var releases: usize = 0;
    const context = try LoaderContext.create(&releases);
    defer LoaderContext.release(context);
    const document = try interfaces.Document.init(allocator, &ctx);
    const parser = try html.scripted_parser.DocumentParser.createComplete(allocator, &ctx, document, "<p>later", .{ .script_loader = context.descriptor() });
    try std.testing.expect(dom.document_lifecycle.associateParser(document, parser));
    parser.release();
    interfaces.Document.deinit(document);
    try std.testing.expectEqual(@as(usize, 1), context.references);
    try std.testing.expectEqual(@as(usize, 1), releases);
}

test "a suspended parser reaches EOF after the initiating owner returned" {
    interfaces.process_hooks.startHooksForTest();
    const allocator = std.testing.allocator;
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(allocator, .{});
    defer ctx.deinit();
    const document = try interfaces.Document.init(allocator, &ctx);
    defer interfaces.Document.deinit(document);
    var releases: usize = 0;
    const context = try LoaderContext.create(&releases);
    const parser = try html.scripted_parser.DocumentParser.createComplete(allocator, &ctx, document, "<p>later", .{ .script_loader = context.descriptor() });
    try std.testing.expect(dom.document_lifecycle.associateParser(document, parser));
    parser.input_stream.complete = false;
    parser.input_stream.processInserted();
    try std.testing.expect(!parser.input_stream.eof_processed);
    parser.release();
    LoaderContext.release(context);
    try std.testing.expectEqual(@as(usize, 1), releases);
    parser.input_stream.complete = true;
    parser.input_stream.processInserted(); // Its retained pump can release Document's last reference at EOF.
    try std.testing.expectEqual(@as(usize, 2), releases);
    try std.testing.expect(dom.document_internals.getInternal(document).?.active_parser == null);
}
