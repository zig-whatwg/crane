//! A Document's active sandboxing flag set (HTML 7.1.5), as the hooks
//! Document installs reach it (dom.document_scripts): given at construction -
//! "create and initialize a Document object" step 9 - and the answer to
//! "scripting is enabled" (HTML 8.1.3.4).
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsers.html#active-sandboxing-flag-set
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#concept-n-script
//!
//! What these pin: the default (a document made with no flags is not
//! sandboxed, and runs script), that the flags a document is made with are
//! the flags it answers, and that only the sandboxed scripts flag - never
//! another - disables its scripting.

const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

const testing = std.testing;
const parse = dom.sandboxing.parseSandboxingDirective;

/// A runtime and a realm-less context to make DOM objects in.
const Fixture = struct {
    ctx_data: runtime.ContextData,

    fn init(self: *Fixture) !void {
        runtime.initializeRuntime(testing.allocator);
        self.ctx_data = try runtime.ContextData.init(testing.allocator, .{});
    }

    fn deinit(self: *Fixture) void {
        self.ctx_data.deinit();
        runtime.deinitializeRuntime();
    }

    fn ctx(self: *Fixture) runtime.Context {
        return &self.ctx_data;
    }
};

test "a document made with no sandboxing flags is not sandboxed, and scripting is enabled" {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();

    const document = try interfaces.Document.init(testing.allocator, fixture.ctx());
    defer interfaces.Document.deinit(document);

    try testing.expect(dom.document_scripts.activeSandboxingFlags(document).isEmpty());
    try testing.expect(!dom.document_scripts.scriptsSandboxed(document));
    try testing.expect(dom.document_scripts.scriptingEnabled(document));
    try testing.expect(dom.document_internals.isScriptingEnabled(document));
}

test "a document made sandboxed without allow-scripts answers its flags, and scripting is disabled" {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();

    const flags = parse("allow-same-origin allow-forms");
    const document = try interfaces.Document.initWith(testing.allocator, fixture.ctx(), .{ .sandboxing_flags = flags });
    defer interfaces.Document.deinit(document);

    try testing.expect(dom.document_scripts.activeSandboxingFlags(document).eql(flags));
    try testing.expect(dom.document_scripts.scriptsSandboxed(document));
    try testing.expect(!dom.document_scripts.scriptingEnabled(document));
    // The noscript and fragment parsers ask the same question here.
    try testing.expect(!dom.document_internals.isScriptingEnabled(document));
}

test "allow-scripts leaves scripting enabled while every other restriction stays" {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();

    const document = try interfaces.Document.initWith(testing.allocator, fixture.ctx(), .{ .sandboxing_flags = parse("allow-scripts") });
    defer interfaces.Document.deinit(document);

    const flags = dom.document_scripts.activeSandboxingFlags(document);
    try testing.expect(dom.document_scripts.scriptingEnabled(document));
    try testing.expect(!dom.document_scripts.scriptsSandboxed(document));
    try testing.expect(flags.origin);
    try testing.expect(flags.forms);
    try testing.expect(flags.modals);
    try testing.expect(flags.document_domain);
}

test "an XMLDocument takes the flags through Document's part of its construction chain" {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();

    const document = try interfaces.XMLDocument.initWith(testing.allocator, fixture.ctx(), .{ .sandboxing_flags = parse("") });
    defer interfaces.XMLDocument.deinit(document);

    try testing.expect(dom.document_scripts.scriptsSandboxed(document));
    try testing.expect(!dom.document_scripts.scriptingEnabled(document));
}
