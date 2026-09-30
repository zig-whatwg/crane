//! A Document's script state, as the hooks Document installs reach it:
//! dom.document_scripts (its script lists, currentScript, the
//! ignore-destructive-writes counter), dom.document_modules (its module map
//! and import map) and dom.document_browsing_context (its window).
//!
//! Spec: https://html.spec.whatwg.org/multipage/scripting.html#script-processing-model
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#module-map
//!
//! What these pin: each hook answers the Document's own state - the state its
//! IDL members read - and the module map owns what is stored in it, disposing
//! of it with the Document.

const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

const testing = std.testing;
const Scripts = dom.document_scripts.Scripts;

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

test "the script lists keep their order, and the in-order list's head stays until it is removed" {
    var scripts = Scripts.init(testing.allocator);
    defer scripts.deinit();

    // Never dereferenced: the lists hold element pointers and nothing else.
    var a: runtime.Instance = undefined;
    var b: runtime.Instance = undefined;
    var c: runtime.Instance = undefined;

    try scripts.addAsap(&a);
    try scripts.addAsap(&b);
    try scripts.addAsap(&c);
    scripts.removeAsap(&b);
    try testing.expectEqualSlices(*runtime.Instance, &.{ &a, &c }, scripts.scripts_to_execute_asap.items);

    try scripts.appendInOrder(&a);
    try scripts.appendInOrder(&b);
    // Looking at the head leaves it the head.
    try testing.expect(scripts.firstInOrder() == &a);
    try testing.expect(scripts.firstInOrder() == &a);
    try testing.expect(scripts.removeFirstInOrder() == &a);
    try testing.expect(scripts.removeFirstInOrder() == &b);
    try testing.expect(scripts.removeFirstInOrder() == null);

    try scripts.addWhenParsingFinished(&c);
    try scripts.addWhenParsingFinished(&a);
    try testing.expectEqualSlices(*runtime.Instance, &.{ &c, &a }, scripts.scripts_to_execute_when_parsing_finished.items);
    scripts.clearWhenParsingFinished();
    try testing.expectEqual(@as(usize, 0), scripts.scripts_to_execute_when_parsing_finished.items.len);
}

test "the ignore-destructive-writes counter never goes below zero" {
    var scripts = Scripts.init(testing.allocator);
    defer scripts.deinit();

    scripts.decrementIgnoreDestructiveWrites();
    try testing.expectEqual(@as(u32, 0), scripts.ignore_destructive_writes_counter);
    scripts.incrementIgnoreDestructiveWrites();
    scripts.incrementIgnoreDestructiveWrites();
    scripts.decrementIgnoreDestructiveWrites();
    try testing.expectEqual(@as(u32, 1), scripts.ignore_destructive_writes_counter);
}

test "a Document's scripts are reached through document_scripts.of, and currentScript reads them" {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();

    const document = try interfaces.Document.init(testing.allocator, fixture.ctx());
    defer interfaces.Document.deinit(document);
    const script = try interfaces.HTMLScriptElement.init(testing.allocator, fixture.ctx());
    defer interfaces.HTMLScriptElement.deinit(script);

    const scripts = dom.document_scripts.of(document) orelse return error.NoDocumentScripts;
    try testing.expect(scripts.current_script == null);
    try testing.expect(try interfaces.Document.get_currentScript(document) == null);

    // "Execute the script element" sets currentScript through the hook; the
    // IDL attribute returns it.
    scripts.current_script = script;
    const current = (try interfaces.Document.get_currentScript(document)) orelse return error.NoCurrentScript;
    try testing.expect(current.htmlscript_element == script);

    // Scripting is enabled by default, and nothing blocks scripts yet.
    try testing.expect(dom.document_scripts.scriptingEnabled(document));
    try testing.expect(!dom.document_scripts.hasStyleSheetBlockingScripts(document));
    // No CSP: every script is allowed.
    try testing.expect(dom.document_scripts.inlineScriptAllowedByCsp(document, null, null, null));
    try testing.expect(dom.document_scripts.externalScriptAllowedByCsp(document, "https", "example.test", null, "/a.js", null));

    // An element is no Document.
    try testing.expect(dom.document_scripts.of(script) == null);
}

var disposed: usize = 0;

fn countDisposal(module: *anyopaque) void {
    _ = module;
    disposed += 1;
}

test "a module stored in a Document's module map is the map's, disposed of with the Document" {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();

    const document = try interfaces.Document.init(testing.allocator, fixture.ctx());
    var document_alive = true;
    defer if (document_alive) interfaces.Document.deinit(document);

    try testing.expect(dom.document_modules.allocator(document) != null);

    // Never dereferenced: the dispose function only counts.
    var module: u8 = 0;
    disposed = 0;
    dom.document_modules.setModuleDisposeFunction(document, &countDisposal);
    try dom.document_modules.setModule(document, "javascript-or-wasm:https://example.test/m.js", &module);
    try testing.expect(dom.document_modules.getModule(document, "javascript-or-wasm:https://example.test/m.js") == @as(*anyopaque, &module));
    try testing.expectEqual(@as(usize, 0), disposed);

    interfaces.Document.deinit(document);
    document_alive = false;
    try testing.expectEqual(@as(usize, 1), disposed);
}

test "an import map answers its mappings, a scope's before the top level" {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();

    const document = try interfaces.Document.init(testing.allocator, fixture.ctx());
    defer interfaces.Document.deinit(document);

    try testing.expect(!dom.document_modules.importMapAcquired(document));
    try dom.document_modules.addImportMapping(document, "lib", "https://example.test/lib.js");
    try dom.document_modules.addScopedImportMapping(document, "https://example.test/scoped/", "lib", "https://example.test/scoped-lib.js");
    dom.document_modules.acquireImportMap(document);
    try testing.expect(dom.document_modules.importMapAcquired(document));

    try testing.expectEqualStrings("https://example.test/lib.js", dom.document_modules.resolveImportSpecifier(document, "lib", "https://example.test/app.js").?);
    try testing.expectEqualStrings("https://example.test/scoped-lib.js", dom.document_modules.resolveImportSpecifier(document, "lib", "https://example.test/scoped/app.js").?);
    try testing.expect(dom.document_modules.resolveImportSpecifier(document, "other", "https://example.test/app.js") == null);
}

test "the window a Document's browsing context is given is what defaultView answers" {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();

    const document = try interfaces.Document.init(testing.allocator, fixture.ctx());
    defer interfaces.Document.deinit(document);
    // Any platform object stands in for the window: defaultView only hands
    // the pointer back.
    const window = try interfaces.Document.init(testing.allocator, fixture.ctx());
    defer interfaces.Document.deinit(window);

    try testing.expect(try interfaces.Document.get_defaultView(document) == null);
    dom.document_browsing_context.setWindow(document, window);
    const view = (try interfaces.Document.get_defaultView(document)) orelse return error.NoDefaultView;
    try testing.expectEqual(@intFromPtr(window), @intFromPtr(view));
}
