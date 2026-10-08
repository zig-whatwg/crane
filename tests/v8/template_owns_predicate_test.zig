//! `wrapper_cache.templateOwns` - is this a template's contents whose
//! template is alive?
//!
//! It gates a free, as `treeOwns` does: the weak callback's `engineOwns` asks
//! it before freeing an instance whose wrapper the collector took. A template
//! owns its content natively (HTML 4.12.3; WebKit's RefPtr, Blink's traced
//! content_), so while the template lives the content's wrapper may go but the
//! fragment stays; the template's teardown frees it, or - when script still
//! holds the fragment - makes it nobody's and leaves it to its wrapper.
//!
//! Wrong towards "false", the fragment was freed under a template whose
//! wrapper had been replaced or collected, and `template.content` read a freed
//! or reissued slot (PR-M1). Wrong towards "true", a fragment would outlive
//! its template unfreed. So the tests pin both answers and the DEFAULT:
//! anything that is not a live template's contents answers false.
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent) and makes its own agent.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");

const templateOwns = v8.wrapper_cache_mod.templateOwns;

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

const Reports = struct {
    count: usize = 0,

    fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }

    fn reporter(self: *Reports) protocol.Reporter {
        return .{ .report = report, .host = self };
    }
};

var pools_ready = false;

fn setup() !void {
    try protocol.initializeEngine(.{});
    if (pools_ready) return;
    interfaces.process_hooks.startHooksForTest();
    runtime.SlabAllocator.init(std.heap.page_allocator);
    runtime.ArenaAllocator.init(std.heap.page_allocator);
    pools_ready = true;
}

const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open() !Page {
        try setup();
        const no_hooks: protocol.HostHooks = .{};
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
        errdefer protocol.destroyAgent(agent);
        const realm = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .agent = agent, .realm = realm };
    }

    fn close(self: Page) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
    }

    /// The platform object `source` evaluates to.
    fn instance(self: Page, source: []const u8) !*runtime.Instance {
        var reports: Reports = .{};
        const held = try protocol.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        defer held.release();
        try testing.expectEqual(@as(usize, 0), reports.count);
        return protocol.convertToPlatformObject(self.realm, held.value) orelse error.NotAPlatformObject;
    }

    fn collect(self: Page) !void {
        const Collect = struct {
            fn steps(data: ?*anyopaque) void {
                protocol.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
            }
        };
        try protocol.runInRealm(self.realm, Collect.steps, self.agent);
        try protocol.runInRealm(self.realm, Collect.steps, self.agent);
    }
};

const xhtml = "http://www.w3.org/1999/xhtml";

test "templateOwns: a live template's contents are its template's; the template itself is not" {
    const page = try Page.open();
    defer page.close();
    const template = try page.instance("globalThis.d = new Document(); globalThis.t = d.createElementNS('" ++ xhtml ++ "', 'template'); t");
    const content = try page.instance("t.content");
    try testing.expect(templateOwns(content));
    try testing.expect(!templateOwns(template));
}

test "templateOwns: a live template's content outlives its own wrapper's collection" {
    const page = try Page.open();
    defer page.close();
    const template = try page.instance("globalThis.d = new Document(); globalThis.t = d.createElementNS('" ++ xhtml ++ "', 'template'); t.content.append('a'); t");
    const content = try interfaces.HTMLTemplateElement.get_content(template);
    const generation = runtime.SlabAllocator.generationOf(content);
    // Without the edge between the wrappers - as when the template's wrapper
    // was replaced or collected - nothing keeps the content's wrapper.
    protocol.forgetTracedChild(template, .{ .name = "content" });
    try page.collect();
    try testing.expect(!protocol.hasWrapper(content));
    // The fragment is still the template's.
    try testing.expectEqual(generation, runtime.SlabAllocator.generationOf(content));
    try testing.expectEqual(content, try interfaces.HTMLTemplateElement.get_content(template));
    try testing.expectEqual(content, try page.instance("t.content.textContent === 'a' ? t.content : null"));
}

test "templateOwns: the default - an ordinary fragment, a shadow root and a non-node answer false" {
    const page = try Page.open();
    defer page.close();
    try testing.expect(!templateOwns(try page.instance("new DocumentFragment()")));
    try testing.expect(!templateOwns(try page.instance("new Document().createElementNS('" ++ xhtml ++ "', 'div').attachShadow({ mode: 'open' })")));
    const headers = try interfaces.Headers.init(testing.allocator, page.realm);
    defer interfaces.Headers.deinit(headers);
    try testing.expect(!templateOwns(headers));
}

test "templateOwns: once its template is gone the content is nobody's, and its wrapper's collection frees it" {
    const page = try Page.open();
    defer page.close();
    const document = try page.instance("globalThis.d = new Document(); d");
    // A template script never saw, made natively.
    const template = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned(xhtml), runtime.DOMString.initInterned("template"), .{ .was_passed = false, .value = undefined });
    try testing.expect(!protocol.hasWrapper(template));
    const content = try interfaces.HTMLTemplateElement.get_content(template);
    const generation = runtime.SlabAllocator.generationOf(content);
    try testing.expect(templateOwns(content));

    // Its wrapper going changes nothing while the template lives.
    try page.collect();
    try testing.expectEqual(generation, runtime.SlabAllocator.generationOf(content));
    try testing.expect(templateOwns(content));

    dom.node_creation.destroyUninserted(template);
    // Freed with the template, or left to its wrapper - and then nobody's.
    if (runtime.SlabAllocator.generationOf(content) == generation) {
        try testing.expect(!templateOwns(content));
        try page.collect();
    }
    try testing.expect(runtime.SlabAllocator.generationOf(content) != generation);
}
