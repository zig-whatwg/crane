//! HTML 8.9.1.6 "PDF viewing support" (lane nav4; the user, 2026-11-14:
//! "PDF viewer supported" is a platform capability, on in Crane's default
//! platforms): navigator.pdfViewerEnabled, and navigator.plugins and
//! navigator.mimeTypes with the five plugins and two mime types the spec
//! names - the same objects every time, cross-linked as the spec says.
//!
//! The capability is compiled in (platform.capabilities.pdf_viewer); with it
//! compiled out (-Dplatform-without=pdf_viewer) both lists are empty and
//! pdfViewerEnabled is false, which src/html/navigator/pdf_viewer.zig's own
//! tests pin through the functions the impls call (pluginNamesWhen(false),
//! mimeTypesWhen(false), pluginIndex, mimeTypeIndex).
//!
//! tests/html is one executable: the engine may already be started.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const browser_mod = @import("browser");

const Browser = browser_mod.Browser;

fn logReporter(_: ?*anyopaque, _: *const engine.ErrorInfo) void {}

const Page = struct {
    browser: *Browser,

    fn start() !Page {
        const browser = try Browser.init(testing.allocator, .{ .snapshot_path = "" });
        errdefer browser.deinit();
        try browser.navigateWithOptions("http://nav4.test/pdf.html", .window, .{ .skip_load = true });
        const context = browser.current_context orelse return error.NoPage;
        try context.loadHTML("<!doctype html><p>pdf viewer", .{ .base_url = "http://nav4.test/pdf.html" });
        return .{ .browser = browser };
    }

    fn stop(self: Page) void {
        self.browser.deinit();
    }

    fn expect(self: Page, source: []const u8, expected: []const u8) !void {
        const realm = self.browser.getRealm() orelse return error.NoRealm;
        const answer = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, .{ .report = logReporter });
        defer testing.allocator.free(answer);
        try testing.expectEqualStrings(expected, answer);
    }
};

test "navigator.pdfViewerEnabled is the platform's PDF viewer supported: true on the default platform" {
    const page = try Page.start();
    defer page.stop();
    try page.expect("typeof navigator.pdfViewerEnabled + ':' + navigator.pdfViewerEnabled", "boolean:true");
    try page.expect("String(navigator.javaEnabled())", "false");
}

test "navigator.plugins holds the five PDF viewer plugins, in the spec's order, with their fixed strings" {
    const page = try Page.start();
    defer page.stop();
    try page.expect("String(navigator.plugins.length)", "5");
    try page.expect("Array.from({length: 5}, (_, i) => navigator.plugins.item(i).name).join('|')", "PDF Viewer|Chrome PDF Viewer|Chromium PDF Viewer|Microsoft Edge PDF Viewer|WebKit built-in PDF");
    try page.expect("Array.from(navigator.plugins, p => p.description + '/' + p.filename + '/' + p.length).join('|')", "Portable Document Format/internal-pdf-viewer/2|Portable Document Format/internal-pdf-viewer/2|Portable Document Format/internal-pdf-viewer/2|Portable Document Format/internal-pdf-viewer/2|Portable Document Format/internal-pdf-viewer/2");
    try page.expect("String(navigator.plugins.item(5)) + ',' + String(navigator.plugins.namedItem('Flash'))", "null,null");
    try page.expect("String(navigator.plugins.refresh())", "undefined");
}

test "navigator.mimeTypes holds the two PDF viewer mime types, each enabled by the generic plugin" {
    const page = try Page.start();
    defer page.stop();
    try page.expect("String(navigator.mimeTypes.length)", "2");
    try page.expect("Array.from(navigator.mimeTypes, m => m.type + '/' + m.description + '/' + m.suffixes).join('|')", "application/pdf/Portable Document Format/pdf|text/pdf/Portable Document Format/pdf");
    try page.expect("String(navigator.mimeTypes.item(2)) + ',' + String(navigator.mimeTypes.namedItem('image/png'))", "null,null");
}

test "the same objects every time: [SameObject] arrays, items by index, by name and through a plugin, and enabledPlugin" {
    const page = try Page.start();
    defer page.stop();
    try page.expect("String(navigator.plugins === navigator.plugins && navigator.mimeTypes === navigator.mimeTypes)", "true");
    try page.expect("String(navigator.plugins.item(0) === navigator.plugins[0] && navigator.plugins.namedItem('Chrome PDF Viewer') === navigator.plugins[1] && navigator.plugins['WebKit built-in PDF'] === navigator.plugins.item(4))", "true");
    try page.expect("String(navigator.mimeTypes.namedItem('text/pdf') === navigator.mimeTypes[1] && navigator.mimeTypes['application/pdf'] === navigator.mimeTypes.item(0))", "true");
    try page.expect("String(navigator.mimeTypes[0].enabledPlugin === navigator.plugins[0] && navigator.mimeTypes[1].enabledPlugin === navigator.plugins[0])", "true");
    try page.expect("String(navigator.plugins[3].item(1) === navigator.mimeTypes[1] && navigator.plugins[2].namedItem('application/pdf') === navigator.mimeTypes[0] && navigator.plugins[0]['text/pdf'] === navigator.mimeTypes[1])", "true");
    // Kept by the arrays: a collection between reads changes nothing.
    try page.expect("globalThis.firstPlugin = navigator.plugins[0]; 'kept'", "kept");
    try page.expect("String(globalThis.firstPlugin === navigator.mimeTypes[0].enabledPlugin)", "true");
}

test "named properties are not enumerable ([LegacyUnenumerableNamedProperties]): only the indices are own enumerable keys" {
    const page = try Page.start();
    defer page.stop();
    try page.expect("Object.keys(navigator.plugins).join()", "0,1,2,3,4");
    try page.expect("Object.keys(navigator.mimeTypes).join()", "0,1");
    try page.expect("String('PDF Viewer' in navigator.plugins) + ',' + String('text/pdf' in navigator.mimeTypes)", "true,true");
}
