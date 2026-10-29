//! CSSOM 6.4.4; import media identity through native records and public interfaces.
//! Liaison Q4/Q77. A fresh thread owns every runtime pool and realm.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const a = std.testing.allocator;

const Host = struct {
    fn window(realm: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
        return interfaces.Window.init(a, realm) catch null;
    }
};

fn importViews(realm: runtime.Context) !void {
    for ([_]bool{ false, true }) |sheet_first| {
        const parent = try dom.style.SheetRecord.create(a, "@import url(child.css) screen;", .{});
        defer parent.unref();
        const child = try dom.style.SheetRecord.create(a, "", .{ .media = "screen" });
        // attachImport takes the child's reference on both success and error.
        try parent.attachImport(.{ .allocator = a }, 0, child);
        const rule = child.owner_rule orelse return error.NoImportRule;
        const rule_object = try dom.style.objects.ruleObject(rule, realm);
        const held_rule = try engine.retainValue(realm, .{ .instance = rule_object });
        defer held_rule.release();
        const sheet_object = try dom.style.objects.sheetObject(child, realm);
        const held_sheet = try engine.retainValue(realm, .{ .instance = sheet_object });
        defer held_sheet.release();
        const first = if (sheet_first)
            try interfaces.StyleSheet.get_media(sheet_object)
        else
            try interfaces.CSSImportRule.get_media(rule_object);
        const second = if (sheet_first)
            try interfaces.CSSImportRule.get_media(rule_object)
        else
            try interfaces.StyleSheet.get_media(sheet_object);
        try std.testing.expect(first == second);
        try std.testing.expect(first == try interfaces.CSSImportRule.get_media(rule_object));
        try std.testing.expect(first == try interfaces.StyleSheet.get_media(sheet_object));
        try interfaces.MediaList.set_mediaText(second, runtime.DOMString.initInterned("print"));
        var text = try interfaces.MediaList.get_mediaText(first);
        defer text.deinit(a);
        try std.testing.expectEqualStrings("print", text.asSlice());
        try interfaces.MediaList.call_appendMedium(first, runtime.DOMString.initInterned("screen"));
        var changed = try interfaces.MediaList.get_mediaText(second);
        defer changed.deinit(a);
        try std.testing.expectEqualStrings("print, screen", changed.asSlice());
        const parent_object = try interfaces.StyleSheet.get_parentStyleSheet(sheet_object) orelse return error.NoParentSheet;
        const ordinary_media = try interfaces.StyleSheet.get_media(parent_object);
        try std.testing.expect(ordinary_media != first);
        try std.testing.expectEqual(@as(u32, 0), try interfaces.MediaList.get_length(ordinary_media));
    }
}

fn checkImports() !void {
    try engine.initializeEngine(.{});
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(a);
    defer runtime.deinitializeRuntime();
    var scope = runtime.BrowserScope.init(a);
    defer scope.deinit();
    const hooks: engine.HostHooks = .{};
    const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &hooks, .allocator = a });
    defer engine.destroyAgent(agent);
    const realm = try engine.createWindowRealm(&.{ .agent = agent, .allocator = a, .from_snapshot = false, .timer = null, .origin = "https://om1.test", .browser_scope = &scope, .create_global_object = Host.window });
    defer engine.destroyWindowRealm(realm, .global_detached);
    const Run = struct {
        realm: runtime.Context,
        result: anyerror!void = {},
        fn steps(raw: ?*anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(raw.?));
            self.result = importViews(self.realm);
        }
    };
    var run: Run = .{ .realm = realm };
    try engine.runInRealm(realm, Run.steps, &run);
    try run.result;
}

test "an import and its associated sheet share one live MediaList in either getter order" {
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, struct {
        fn body(out: *anyerror!void) void {
            out.* = checkImports();
        }
    }.body, .{&result});
    thread.join();
    try result;
}

fn reportAdoption(_: ?*anyopaque, info: *const engine.ErrorInfo) void {
    std.debug.print("om1 stylesheet adoption: {s}\n", .{info.message});
}

fn adoptionScript(realm: runtime.Context, text: []const u8) !engine.Owned {
    return engine.evaluateClassicScript(realm, .{ .utf8 = text }, "", null, .{ .report = reportAdoption, .host = null });
}

fn checkAdoption(source: []const u8, inspect_owners: bool, collect: bool) !void {
    try engine.initializeEngine(.{});
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(a);
    defer runtime.deinitializeRuntime();
    var scope = runtime.BrowserScope.init(a);
    defer scope.deinit();
    const hooks: engine.HostHooks = .{};
    const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &hooks, .allocator = a });
    defer engine.destroyAgent(agent);
    const realm = try engine.createWindowRealm(&.{ .agent = agent, .allocator = a, .from_snapshot = false, .timer = null, .origin = "https://om1.test", .browser_scope = &scope, .create_global_object = Host.window });
    defer engine.destroyWindowRealm(realm, .global_detached);
    const held_document = try adoptionScript(realm, "globalThis.d = new Document().implementation.createHTMLDocument('om1'); d");
    defer held_document.release();
    const document = engine.convertToPlatformObject(realm, held_document.value) orelse return error.NoDocument;
    const held_window = try adoptionScript(realm, "globalThis");
    defer held_window.release();
    const window = engine.convertToPlatformObject(realm, held_window.value) orelse return error.NoWindow;
    dom.document_browsing_context.setWindow(document, window);
    dom.window_globals.setDocument(window, document);
    if (inspect_owners) {
        if (comptime @hasDecl(dom.template_contents, "existingOwnerDocument")) {
            // Repeated queries must not manufacture the inert document.
            try std.testing.expect(dom.template_contents.existingOwnerDocument(document) == null);
            try std.testing.expect(dom.template_contents.existingOwnerDocument(document) == null);
            const template = try adoptionScript(realm, "d.createElement('template').content.ownerDocument");
            defer template.release();
            const owner = engine.convertToPlatformObject(realm, template.value) orelse return error.NoDocument;
            try std.testing.expect(owner != document);
            try std.testing.expect(dom.template_contents.existingOwnerDocument(document) == owner);
            try std.testing.expect(dom.template_contents.existingOwnerDocument(owner) == owner);
        } else return std.testing.expect(false);
    }
    const setup = try adoptionScript(realm,
        \\globalThis.check = (condition, message) => { if (!condition) throw new Error(message); };
        \\globalThis.host = d.createElement('div'); d.body.appendChild(host);
        \\globalThis.root = host.attachShadow({mode:'open'});
        \\globalThis.sheet = new CSSStyleSheet(); sheet.replaceSync(':host { color: red }');
        \\root.adoptedStyleSheets = [sheet]; globalThis.array = root.adoptedStyleSheets;
    );
    setup.release();
    const result = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, a, .{ .report = reportAdoption, .host = null });
    defer a.free(result);
    try std.testing.expectEqualStrings("ok", result);
    if (collect) {
        const dropped = try adoptionScript(realm, "globalThis.sheet=null; globalThis.host=null; globalThis.destination=null;");
        dropped.release();
        const Collect = struct {
            fn steps(data: ?*anyopaque) void {
                engine.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
            }
        };
        try engine.runInRealm(realm, Collect.steps, agent);
        try engine.runInRealm(realm, Collect.steps, agent);
        const after = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = "check(root.adoptedStyleSheets===array && array.length===0, 'after collection'); array.length=0; 'ok'" }, "", null, a, .{ .report = reportAdoption, .host = null });
        defer a.free(after);
        try std.testing.expectEqualStrings("ok", after);
    }
}

fn adoptionThread(source: []const u8, inspect: bool, collect: bool) !void {
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, struct {
        fn body(out: *anyerror!void, text: []const u8, owner_query: bool, gc: bool) void {
            out.* = checkAdoption(text, owner_query, gc);
        }
    }.body, .{ &result, source, inspect, collect });
    thread.join();
    try result;
}

test "the read-only template-owner query creates no document and follows the existing relation" {
    try adoptionThread("'ok'", true, false);
}

test "same-document and both associated-template adoption directions preserve the sheet array" {
    try adoptionThread(
        \\(() => {
        \\const parent = d.createElement('section'); d.body.appendChild(parent); parent.appendChild(host);
        \\d.adoptNode(host);
        \\check(root.adoptedStyleSheets===array && array.length===1 && array[0]===sheet, 'same document');
        \\const template = d.createElement('template'); template.innerHTML='<template></template>';
        \\template.content.appendChild(host);
        \\check(host.ownerDocument!==d && root.ownerDocument===host.ownerDocument, 'inert owner');
        \\check(root.adoptedStyleSheets===array && array.length===1 && array[0]===sheet, 'to template');
        \\template.content.firstChild.content.appendChild(host);
        \\check(array.length===1 && array[0]===sheet, 'nested template');
        \\d.body.appendChild(host);
        \\check(host.ownerDocument===d && root.adoptedStyleSheets===array && array.length===1 && array[0]===sheet, 'from template');
        \\return 'ok'; })()
    , false, false);
}

test "unrelated-document adoption clears the same sheet array and survives collection" {
    try adoptionThread(
        \\(() => {
        \\globalThis.destination = d.implementation.createHTMLDocument('other');
        \\destination.body.appendChild(host);
        \\check(root.ownerDocument===destination, 'new owner');
        \\check(root.adoptedStyleSheets===array && array.length===0, 'cleared existing array');
        \\return 'ok'; })()
    , false, true);
}

test "a template does not preserve adopted sheets across an unrelated document" {
    try adoptionThread(
        \\(() => {
        \\const template = d.createElement('template'); template.content.appendChild(host);
        \\check(array.length===1, 'associated owner');
        \\const destination = d.implementation.createHTMLDocument('other');
        \\destination.body.appendChild(host);
        \\check(root.adoptedStyleSheets===array && array.length===0, 'unrelated owner');
        \\d.body.appendChild(host);
        \\check(root.adoptedStyleSheets===array && array.length===0, 'no revival');
        \\return 'ok'; })()
    , false, false);
}
