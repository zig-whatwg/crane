//! Native allocator and fetch cancellation checks for resource-loading owners.
const std = @import("std");
const browser_mod = @import("browser");
const engine = @import("engine");
const dom = @import("dom");

fn fresh(comptime exercise: fn () anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

fn inputAbort() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    const result = try browser.evaluateScript(
        \\globalThis.cr1Input = document.createElement('input');
        \\cr1Input.type = 'image';
        \\cr1Input.src = 'http://127.0.0.1:65533/cr1-pending';
        \\document.body.append(cr1Input);
        \\cr1Input
    );
    defer result.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    const input = engine.convertToPlatformObject(realm, result.borrow()) orelse return error.NoElement;
    // Public generated state reaches the owner only through its hook/API;
    // the fetch group is the observable native operation to pin here.
    _ = input;
    try std.testing.expect((browser.agent_host.fetches.inFlight() != 0));
    const stopped = try browser.evaluateScript("window.stop(); cr1Input.remove(); delete globalThis.cr1Input; true");
    stopped.release();
    try std.testing.expect(!(browser.agent_host.fetches.inFlight() != 0));
}

test "input image pending activity cancels before realm teardown" {
    try fresh(inputAbort);
}

fn ownerCapacity() !void {
    try std.testing.expectEqual(@as(usize, 20), @typeInfo(dom.document_fetches.OwnerSlots).array.len);
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    const count = dom.document_fetches.ownerCount();
    // Eleven BASE owners plus input, two SVG kinds, fonts and the CSS cache.
    try std.testing.expect(count >= 17);
    try std.testing.expect(count < @typeInfo(dom.document_fetches.OwnerSlots).array.len);
}

test "all document fetch owners fit with a spare slot after process start" {
    try fresh(ownerCapacity);
}

fn svgAbort() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "http://127.0.0.1:65533/" });
    const result = try browser.evaluateScript(
        \\globalThis.cr1Svg = document.createElementNS('http://www.w3.org/2000/svg','svg');
        \\for (const kind of ['image','use']) {
        \\  const e = document.createElementNS('http://www.w3.org/2000/svg',kind);
        \\  e.setAttribute('href','http://127.0.0.1:65533/cr1-' + kind + '.svg#target');
        \\  cr1Svg.append(e);
        \\}
        \\document.body.append(cr1Svg);
        \\true
    );
    result.release();
    try std.testing.expectEqual(@as(usize, 2), browser.agent_host.fetches.inFlight());
    const stopped = try browser.evaluateScript("window.stop(); cr1Svg.remove(); delete globalThis.cr1Svg; true");
    stopped.release();
    try std.testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
}

test "SVG image and use pending activity is canceled by document abort" {
    try fresh(svgAbort);
}

fn secureXml() !void {
    const interfaces = @import("interfaces");
    const runtime = @import("runtime");
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const setup = try browser.evaluateScript("globalThis.cr1SvgScriptRan=false; customElements.define('cr1-evil',class extends HTMLElement {constructor(){super();globalThis.cr1SvgScriptRan=true;}}); true");
    setup.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    const document = try interfaces.XMLDocument.initWith(std.testing.allocator, realm, .{ .ready_state = ._complete_ });
    const generation = runtime.SlabAllocator.generationOf(document);
    defer document.releaseIfUnwrapped(generation);
    try dom.document_internals.setDocumentType(document, .xml);
    try dom.document_internals.setURL(document, "http://127.0.0.1:65533/cr1-resource.svg");
    const resource =
        \\<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml">
        \\<script>globalThis.cr1SvgScriptRan=true</script><script href="http://127.0.0.1:65533/script"/>
        \\<image href="http://127.0.0.1:65533/image"/><use href="http://127.0.0.1:65533/use"/>
        \\<style>@import 'http://127.0.0.1:65533/style';</style>
        \\<foreignObject><h:img src="http://127.0.0.1:65533/html-image"/><h:input type="image" src="http://127.0.0.1:65533/input"/><h:link rel="stylesheet" href="http://127.0.0.1:65533/link"/><h:cr1-evil/></foreignObject>
        \\</svg>
    ;
    try std.testing.expect(try dom.style.hooks.svgParseResourceDocument(document, resource, "image/svg+xml"));
    try std.testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
    const observed = try browser.evaluateScript("cr1SvgScriptRan");
    defer observed.release();
    try std.testing.expect(!engine.toBoolean(realm, observed.borrow()));
}

test "secure SVG XML parsing starts no nested requests or custom element scripts" {
    try fresh(secureXml);
}

fn strictSvgEncoding() !void {
    const interfaces = @import("interfaces");
    const runtime = @import("runtime");
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const document = try interfaces.XMLDocument.initWith(std.testing.allocator, realm, .{ .ready_state = ._complete_ });
    const generation = runtime.SlabAllocator.generationOf(document);
    defer document.releaseIfUnwrapped(generation);
    try dom.document_internals.setDocumentType(document, .xml);
    try dom.document_internals.setURL(document, "http://127.0.0.1:65533/cr1-invalid-encoding.svg");
    try std.testing.expect(!try dom.style.hooks.svgParseResourceDocument(document, "<svg xmlns='http://www.w3.org/2000/svg'>\xff</svg>", "image/svg+xml"));
    try std.testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
}

test "secure SVG document rejects malformed encoded bytes instead of replacing them" {
    try fresh(strictSvgEncoding);
}

fn cssAbort() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const doc_value = try browser.evaluateScript("document");
    defer doc_value.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    const document = engine.convertToPlatformObject(realm, doc_value.borrow()) orelse return error.NoDocument;
    const style_engine = dom.style.hooks.engineOf(document) orelse return error.NoStyleEngine;
    const state = try style_engine.ensureResourceState(document);
    const cached = try state.cache.getOrPut(.{ .url = "http://127.0.0.1:65533/cr1-background" });
    try cached.entry.start(document, .css);
    try std.testing.expect(browser.agent_host.fetches.inFlight() != 0);
    const stopped = try browser.evaluateScript("window.stop(); true");
    stopped.release();
    try std.testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
    try std.testing.expect(cached.entry.handle == null);
    try std.testing.expectEqual(.failed, cached.entry.status);
}

test "document abort cancels pending CSS images and preserves a failed cache entry" {
    try fresh(cssAbort);
}

fn emptySvgReplacement() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    const result = try browser.evaluateScript(
        \\globalThis.cr1SvgImage = document.createElementNS('http://www.w3.org/2000/svg', 'image');
        \\cr1SvgImage.setAttribute('href','http://127.0.0.1:65533/cr1-pending-image');
        \\document.body.append(cr1SvgImage);
        \\true
    );
    result.release();
    try std.testing.expect(browser.agent_host.fetches.inFlight() != 0);
    const empty = try browser.evaluateScript("cr1SvgImage.setAttribute('href', ''); true");
    empty.release();
    // SVG's ImageLoader replacement discards the previous source even when
    // the replacement is empty. HTML input's explicit empty-src exception
    // is a separate caller rule and must not be changed along with it.
    try std.testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
}

test "empty SVG image href cancels its previous pending request" {
    try fresh(emptySvgReplacement);
}

fn svgCacheDoesNotStartCssWork() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><div id=ordinary></div></body>", .{ .base_url = "about:blank" });
    const doc_value = try browser.evaluateScript("document");
    defer doc_value.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    const document = engine.convertToPlatformObject(realm, doc_value.borrow()) orelse return error.NoDocument;
    const style_engine = dom.style.hooks.engineOf(document) orelse return error.NoStyleEngine;
    // SVG's external-document cache shares the lazy resource state but
    // does not establish CSS resource interest.
    const state = try style_engine.ensureResourceState(document);
    const mutation = try browser.evaluateScript("ordinary.setAttribute('class', 'changed'); ordinary.append('text'); true");
    mutation.release();
    try std.testing.expect(!state.pending);
}

test "an SVG document cache alone does not schedule a CSS resource walk" {
    try fresh(svgCacheDoesNotStartCssWork);
}

fn adoptionToInertDocument() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    const pending = try browser.evaluateScript(
        \\globalThis.cr1AdoptedInput = document.createElement('input');
        \\cr1AdoptedInput.type='image';
        \\cr1AdoptedInput.src='http://127.0.0.1:65533/cr1-adopt-input';
        \\globalThis.cr1AdoptedImage = document.createElementNS('http://www.w3.org/2000/svg','image');
        \\cr1AdoptedImage.setAttribute('href','http://127.0.0.1:65533/cr1-adopt-svg');
        \\document.body.append(cr1AdoptedInput, cr1AdoptedImage);
        \\true
    );
    pending.release();
    try std.testing.expect(browser.agent_host.fetches.inFlight() >= 2);
    const adopted = try browser.evaluateScript(
        \\globalThis.cr1InertDocument = document.implementation.createHTMLDocument('inert');
        \\cr1InertDocument.body.append(cr1AdoptedInput, cr1AdoptedImage);
        \\true
    );
    adopted.release();
    try std.testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
}

test "adopting image loaders into an inert document ends their old pending activity" {
    try fresh(adoptionToInertDocument);
}

fn inlineSourceProvenance() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "http://127.0.0.1:65533/dir/page.html" });
    const realm = browser.getRealm() orelse return error.NoRealm;
    const create = try browser.evaluateScript("globalThis.cr1Sourced=document.createElement('div'); document.body.append(cr1Sourced); cr1Sourced");
    defer create.release();
    const element = engine.convertToPlatformObject(realm, create.borrow()) orelse return error.NoElement;
    for ([_][]const u8{
        "cr1Sourced.setAttribute('style', 'background-image: url(picture.png)'); true",
        "cr1Sourced.style.cssText='background-image: url(picture.png)'; true",
        "cr1Sourced.style.removeProperty('background-image'); cr1Sourced.style.setProperty('background-image','url(picture.png)'); true",
    }) |script| {
        const changed = try browser.evaluateScript(script);
        changed.release();
        const block = (try dom.style.inline_style.blockOf(element)) orelse return error.NoBlock;
        const value = (block.get(.background_image) orelse return error.NoValue).value.value;
        const occurrences = value.resourceUrls();
        try std.testing.expectEqual(@as(usize, 1), occurrences.len);
        try std.testing.expectEqualStrings("http://127.0.0.1:65533/dir/picture.png", occurrences[0].url);
        try std.testing.expect(occurrences[0].source != null);
        const source = occurrences[0].source.?;
        try std.testing.expectEqualStrings("http://127.0.0.1:65533/dir/page.html", source.base_url);
        try std.testing.expect(source.referrer == null);
        try std.testing.expectEqualStrings("", source.referrer_policy);
        try std.testing.expect(source.origin_clean);
    }
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var no_resource = try dom.style.engine.resource_loading.inlineParseContext(element, failing.allocator(), false, "color: red");
    defer no_resource.deinit();
    try std.testing.expect(no_resource.source == null);
    try std.testing.expect(!failing.has_induced_failure);
}

test "attribute and CSSOM inline URLs share their actual element base and client referrer" {
    try fresh(inlineSourceProvenance);
}

fn resourceRenderingTurn() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    const changed = try browser.evaluateScript(
        \\globalThis.cr1Rendered = document.createElement('div');
        \\cr1Rendered.style.backgroundImage='url(http://127.0.0.1:65533/cr1-rendered)';
        \\document.body.append(cr1Rendered);
        \\getComputedStyle(cr1Rendered).backgroundImage;
        \\document
    );
    defer changed.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    const document = engine.convertToPlatformObject(realm, changed.borrow()) orelse return error.NoDocument;
    const style_engine = dom.style.hooks.engineOf(document) orelse return error.NoStyleEngine;
    const state = style_engine.resourceState() orelse return error.NoResourceState;
    // Computed-style getters only resolve values. The event loop's next
    // rendering opportunity is the first place that may issue the request.
    try std.testing.expectEqual(@as(usize, 0), state.cache.count());
    _ = try browser.runEventLoopBlocking(80);
    try std.testing.expectEqual(@as(usize, 1), state.cache.count());
    try std.testing.expect(!state.pending);
    // A second invalidation must reuse the pending/completed request.
    const mutated = try browser.evaluateScript("cr1Rendered.className='changed'; true");
    mutated.release();
    _ = try browser.runEventLoopBlocking(40);
    try std.testing.expectEqual(@as(usize, 1), state.cache.count());
}

test "used CSS resources start at a rendering turn and reuse their document cache" {
    try fresh(resourceRenderingTurn);
}

fn nativeSvgAbort() !void {
    const interfaces = @import("interfaces");
    const runtime = @import("runtime");
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "http://127.0.0.1:65533/" });
    const realm = browser.getRealm() orelse return error.NoRealm;
    const result = try browser.evaluateScript("document");
    defer result.release();
    const document = engine.convertToPlatformObject(realm, result.borrow()) orelse return error.NoDocument;
    const body = (try interfaces.Document.get_body(document)) orelse return error.NoBody;
    // Q18/Q28's factory dependency is separate: exercise the actual leaf
    // owners through the generated chain even while createElementNS is red.
    const image = try interfaces.SVGImageElement.init(std.testing.allocator, realm);
    const image_generation = runtime.SlabAllocator.generationOf(image);
    defer {
        if (runtime.SlabAllocator.generationOf(image) == image_generation) {
            if (interfaces.Node.get_parentNode(image) catch null) |parent| _ = interfaces.Node.call_removeChild(parent, image) catch null;
        }
        image.releaseIfUnwrapped(image_generation);
    }
    const use = try interfaces.SVGUseElement.init(std.testing.allocator, realm);
    const use_generation = runtime.SlabAllocator.generationOf(use);
    defer {
        if (runtime.SlabAllocator.generationOf(use) == use_generation) {
            if (interfaces.Node.get_parentNode(use) catch null) |parent| _ = interfaces.Node.call_removeChild(parent, use) catch null;
        }
        use.releaseIfUnwrapped(use_generation);
    }
    defer _ = dom.document_fetches.abort(document);
    inline for (.{ .{ image, "image" }, .{ use, "use" } }) |entry| {
        try dom.node_creation.setElementNames(entry[0], "http://www.w3.org/2000/svg", entry[1]);
        try dom.node_document.set(entry[0], document);
        try dom.element_attributes.set(entry[0], "href", "http://127.0.0.1:65533/cr1-native.svg#target", .{});
        _ = try interfaces.Node.call_appendChild(body, entry[0]);
    }
    try std.testing.expectEqual(@as(usize, 2), browser.agent_host.fetches.inFlight());
    try std.testing.expect(dom.document_fetches.abort(document));
    try std.testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
}

test "generated SVG resource owners cancel their real requests without factory dispatch" {
    try fresh(nativeSvgAbort);
}

fn nativeEmptySvgReplacement() !void {
    const interfaces = @import("interfaces");
    const runtime = @import("runtime");
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const result = try browser.evaluateScript("document");
    defer result.release();
    const document = engine.convertToPlatformObject(realm, result.borrow()) orelse return error.NoDocument;
    const image = try interfaces.SVGImageElement.init(std.testing.allocator, realm);
    const generation = runtime.SlabAllocator.generationOf(image);
    defer image.releaseIfUnwrapped(generation);
    defer _ = dom.document_fetches.abort(document);
    try dom.node_creation.setElementNames(image, "http://www.w3.org/2000/svg", "image");
    try dom.node_document.set(image, document);
    for ([_][]const u8{ "", " \t\n", "http://[" }) |invalid| {
        try dom.element_attributes.set(image, "href", "http://127.0.0.1:65533/cr1-native-empty", .{});
        try std.testing.expectEqual(@as(usize, 1), browser.agent_host.fetches.inFlight());
        try dom.element_attributes.set(image, "href", invalid, .{});
        try std.testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
    }
}

test "empty href replaces a native SVG image pending request before its queued error" {
    try fresh(nativeEmptySvgReplacement);
}

fn cssomSheetSources() !void {
    const interfaces = @import("interfaces");
    const runtime = @import("runtime");
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "http://127.0.0.1:65533/dir/page.html" });
    const realm = browser.getRealm() orelse return error.NoRealm;
    for ([_][]const u8{
        "cr1Sheet.insertRule('div { background-image:url(picture.png) }')",
        "cr1Sheet.insertRule('div {color:red}'); cr1Sheet.cssRules[0].style.setProperty('background-image','url(picture.png)')",
        "cr1Sheet.insertRule('div {color:red}'); cr1Sheet.cssRules[0].style.cssText='background-image:url(picture.png)'",
        "cr1Sheet.replaceSync('div {background-image:url(picture.png)}')",
        "cr1Sheet.replace('div {background-image:url(picture.png)}')",
    }) |change| {
        const script = try std.fmt.allocPrint(std.testing.allocator, "globalThis.cr1Sheet=new CSSStyleSheet(); {s}; cr1Sheet", .{change});
        defer std.testing.allocator.free(script);
        const result = try browser.evaluateScript(script);
        defer result.release();
        _ = try browser.runEventLoopBlocking(30);
        const object = engine.convertToPlatformObject(realm, result.borrow()) orelse return error.NoSheet;
        const record = dom.style.hooks.sheetRecordOf(object) orelse return error.NoRecord;
        const rules = try record.rulesOf(object);
        try std.testing.expectEqual(@as(usize, 1), rules.items.len);
        const value = (rules.items[0].block().?.get(.background_image) orelse return error.NoValue).value.value;
        const urls = value.resourceUrls();
        try std.testing.expectEqual(@as(usize, 1), urls.len);
        try std.testing.expectEqualStrings("http://127.0.0.1:65533/dir/picture.png", urls[0].url);
        const source = urls[0].source orelse return error.NoSource;
        try std.testing.expectEqualStrings("http://127.0.0.1:65533/dir/page.html", source.base_url);
        // CSSOM's constructed-sheet algorithm sets its location to the
        // constructor document's base URL; its empty policy uses the client.
        try std.testing.expectEqualStrings("http://127.0.0.1:65533/dir/page.html", source.referrer.?);
        try std.testing.expectEqualStrings("", source.referrer_policy);
        try std.testing.expect(source.origin_clean);
    }
    const detached = try interfaces.CSSStyleDeclaration.init(std.testing.allocator, realm);
    const generation = runtime.SlabAllocator.generationOf(detached);
    defer detached.releaseIfUnwrapped(generation);
    try interfaces.CSSStyleDeclaration.call_setProperty(detached, .initInterned("background-image"), .initInterned("url(picture.png)"), .{ .was_passed = false, .value = undefined });
    var serialized = try interfaces.CSSStyleDeclaration.call_getPropertyValue(detached, .initInterned("background-image"));
    defer serialized.deinit(realm.allocator);
    try std.testing.expectEqualStrings("url(\"picture.png\")", serialized.asSlice());
}

test "CSSOM insert replacement and rule declaration edits all retain URL sources" {
    try fresh(cssomSheetSources);
}

fn backgroundHintCache() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><head><base href='http://127.0.0.1:65533/first/'></head><body></body>", .{ .base_url = "http://127.0.0.1:65533/page.html" });
    const result = try browser.evaluateScript(
        \\globalThis.cr1Table = document.createElement('table');
        \\for (let i=0; i<40; ++i) cr1Table.setAttribute('data-cr1-'+i, 'x');
        \\cr1Table.setAttribute('background', 'hint.png');
        \\document.body.append(cr1Table); cr1Table
    );
    defer result.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    const table = engine.convertToPlatformObject(realm, result.borrow()) orelse return error.NoElement;
    const first = (try dom.style.computedStyle(table, null)) orelse return error.NoStyle;
    const urls = first.get(.background_image).resourceUrls();
    try std.testing.expectEqual(@as(usize, 1), urls.len);
    try std.testing.expectEqualStrings("http://127.0.0.1:65533/first/hint.png", urls[0].url);
    try std.testing.expect(urls[0].source.?.referrer == null);
    try std.testing.expectEqualStrings("http://127.0.0.1:65533/first/", urls[0].source.?.base_url);
    const state = dom.style.element_style.existingOf(table) orelse return error.NoState;
    const cached = state.background_hint orelse return error.NoHint;
    const unrelated = try browser.evaluateScript("cr1Table.setAttribute('data-cr1', 'changed'); true");
    unrelated.release();
    _ = try dom.style.computedStyle(table, null);
    try std.testing.expect(state.background_hint.? == cached);
    const changed = try browser.evaluateScript("document.querySelector('base').href = 'http://127.0.0.1:65533/second/'; true");
    changed.release();
    const second = (try dom.style.computedStyle(table, null)) orelse return error.NoStyle;
    try std.testing.expectEqualStrings("http://127.0.0.1:65533/second/hint.png", second.get(.background_image).resourceUrls()[0].url);
    const removed = try browser.evaluateScript("cr1Table.removeAttribute('background'); true");
    removed.release();
    try std.testing.expect(state.background_hint == null);
    const plain = try browser.evaluateScript("globalThis.cr1Plain = document.createElement('div'); cr1Plain.setAttribute('background','ignored.png'); document.body.append(cr1Plain); cr1Plain");
    defer plain.release();
    const div = engine.convertToPlatformObject(realm, plain.borrow()) orelse return error.NoElement;
    _ = try dom.style.computedStyle(div, null);
    try std.testing.expect(dom.style.element_style.existingOf(div).?.background_hint == null);
}

test "HTML background hint is lazy document-sourced and invalidated by base and attribute changes" {
    try fresh(backgroundHintCache);
}

fn fontRuleDiscovery() !void {
    const runtime = @import("runtime");
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(
        "<!doctype html><head><style id=cr1Style>@import url('data:text/css,'); " ++
            "@font-face {font-family: document-face; src: local(cr1)} " ++
            "@media print { @font-face {font-family: skipped; src: local(cr1)} }" ++
            "</style></head><body><div id=cr1Host></div></body>",
        .{ .base_url = "about:blank" },
    );
    _ = try browser.runEventLoopBlocking(30);
    const setup = try browser.evaluateScript(
        \\globalThis.cr1Adopted = new CSSStyleSheet();
        \\cr1Adopted.replaceSync('@font-face {font-family: adopted-face; src: local(cr1)}');
        \\document.adoptedStyleSheets = [cr1Adopted];
        \\globalThis.cr1Shadow = cr1Host.attachShadow({mode:'open'});
        \\cr1Shadow.innerHTML = '<style>@font-face {font-family: shadow-face; src: local(cr1)}</style>';
        \\cr1Shadow.adoptedStyleSheets = [cr1Adopted];
        \\document
    );
    defer setup.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    const document = engine.convertToPlatformObject(realm, setup.borrow()) orelse return error.NoDocument;
    const owner_value = try browser.evaluateScript("cr1Style");
    defer owner_value.release();
    const owner = engine.convertToPlatformObject(realm, owner_value.borrow()) orelse return error.NoOwner;
    const record = dom.style.hooks.sheetOf(owner) orelse return error.NoRecord;
    // Supply an already fetched import through the stylesheet's public
    // record API, so this ordering check needs no network or timer race.
    const imported = try dom.style.SheetRecord.create(std.testing.allocator, "@font-face {font-family: imported-face; src: local(cr1)}", .{});
    var context = record.urlContext(document);
    try record.attachImport(record.parseOptions(&context), 0, imported);
    dom.style.sheetsChanged(document);

    const Capture = struct {
        families: [8][]const u8 = undefined,
        roots: [8]*runtime.Instance = undefined,
        count: usize = 0,

        pub fn visit(self: *@This(), rule: *dom.style.Rule, root: *runtime.Instance) !void {
            if (self.count == self.families.len) return error.TooManyRules;
            self.families[self.count] = dom.style.engine.resource_loading.font_loading.descriptorValue(rule.block().?, "font-family");
            self.roots[self.count] = root;
            self.count += 1;
        }
    };
    var capture: Capture = .{};
    try dom.style.engine.visitFontRules(document, &capture);
    try std.testing.expectEqual(@as(usize, 5), capture.count);
    for (capture.families[0..5], [_][]const u8{ "imported-face", "document-face", "adopted-face", "shadow-face", "adopted-face" }) |actual, expected| {
        try std.testing.expectEqualStrings(expected, actual);
    }
    for (capture.roots[0..3]) |root| try std.testing.expect(root == document);
    try std.testing.expect(capture.roots[3] != document);
    try std.testing.expect(capture.roots[3] == capture.roots[4]);
    const disabled = try browser.evaluateScript("cr1Style.sheet.disabled=true; cr1Adopted.disabled=true; true");
    disabled.release();
    capture.count = 0;
    try dom.style.engine.visitFontRules(document, &capture);
    try std.testing.expectEqual(@as(usize, 1), capture.count);
    try std.testing.expectEqualStrings("shadow-face", capture.families[0]);
    const removed = try browser.evaluateScript("cr1Host.remove(); cr1Style.remove(); cr1Adopted.disabled=false; true");
    removed.release();
    capture.count = 0;
    try dom.style.engine.visitFontRules(document, &capture);
    try std.testing.expectEqual(@as(usize, 1), capture.count);
    try std.testing.expectEqualStrings("adopted-face", capture.families[0]);
    try std.testing.expect(capture.roots[0] == document);
}

test "font rule discovery follows imports adopted sheets conditions and shadow scopes" {
    try fresh(fontRuleDiscovery);
}

fn cssomFontRuleSources() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "http://127.0.0.1:65533/fonts/page.html" });
    const realm = browser.getRealm() orelse return error.NoRealm;
    for ([_][]const u8{
        "cr1FontRule.style.setProperty('src','url(new.woff2)')",
        "cr1FontRule.style.cssText='font-family: cr1; src:url(new.woff2)'",
    }) |change| {
        const script = try std.fmt.allocPrint(
            std.testing.allocator,
            "globalThis.cr1FontSheet=new CSSStyleSheet(); cr1FontSheet.insertRule('@font-face {{font-family: cr1; src:url(old.woff2)}}'); globalThis.cr1FontRule=cr1FontSheet.cssRules[0]; {s}; cr1FontRule",
            .{change},
        );
        defer std.testing.allocator.free(script);
        const result = try browser.evaluateScript(script);
        defer result.release();
        const object = engine.convertToPlatformObject(realm, result.borrow()) orelse return error.NoRule;
        const rule = dom.style.hooks.cssRuleOf(object) orelse return error.NoRule;
        const resource = rule.data.font_face.sources.?.items[0].resource.?;
        try std.testing.expectEqualStrings("http://127.0.0.1:65533/fonts/new.woff2", resource.url);
        try std.testing.expectEqualStrings("http://127.0.0.1:65533/fonts/page.html", resource.source.?.base_url);
        const detach = try browser.evaluateScript("cr1FontSheet.deleteRule(0); cr1FontRule.style.fontWeight='700'; true");
        detach.release();
        try std.testing.expect(rule.sheet() == null);
        try std.testing.expect(rule.data.font_face.sources.?.items[0].resource.?.source == resource.source);
        const replace = try browser.evaluateScript("cr1FontRule.style.src='url(detached.woff2)'; true");
        replace.release();
        const replaced = rule.data.font_face.sources.?.items[0].resource.?;
        try std.testing.expectEqualStrings("detached.woff2", replaced.url);
        try std.testing.expect(replaced.source == null);
        const remove = try browser.evaluateScript("cr1FontRule.style.removeProperty('src'); true");
        remove.release();
        try std.testing.expect(rule.data.font_face.sources == null);
    }
}

test "font descriptor CSSOM mutation captures sources and detached edits release them" {
    try fresh(cssomFontRuleSources);
}

fn cssImageVisibility() !void {
    if (comptime !@hasDecl(dom.style.engine, "isCssImageResourceOrigin")) return error.MissingImageEligibility;
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><div style='content-visibility:hidden'><span id=skipped></span></div><div style='display:none'><span id=absent></span></div><div style='display:contents' id=delegating></div></body>", .{ .base_url = "about:blank" });
    const realm = browser.getRealm() orelse return error.NoRealm;
    inline for (.{ .{ "skipped", true }, .{ "absent", false }, .{ "delegating", true } }) |row| {
        const value = try browser.evaluateScript("document.getElementById('" ++ row[0] ++ "')");
        defer value.release();
        const element = engine.convertToPlatformObject(realm, value.borrow()) orelse return error.NoElement;
        try std.testing.expectEqual(row[1], try dom.style.engine.isCssImageResourceOrigin(element));
    }
}

test "CSS image eligibility ignores skipped contents but excludes display none subtrees" {
    // Integrator Q5 probe: Chrome/Firefox/Safari no/yes/yes for skipped
    // descendant images, and no/no/no for display:none descendants.
    try fresh(cssImageVisibility);
}

fn fontTextParent() !void {
    if (comptime !@hasDecl(dom.style.engine, "fontStyleForText")) return error.MissingFontTextStyle;
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><div id=host>assigned</div><div id=unused>unused</div><div id=none style='display:none'>hidden</div><div id=shadow></div></body>", .{ .base_url = "about:blank" });
    const setup = try browser.evaluateScript(
        \\document.getElementById('host').attachShadow({mode:'open'}).innerHTML = '<slot style="font-weight:700">fallback</slot>';
        \\document.getElementById('unused').attachShadow({mode:'open'}).innerHTML = '<span>No slot</span>';
        \\document.getElementById('shadow').attachShadow({mode:'open'}).textContent = 'shadow child';
        \\true
    );
    setup.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    const assigned = try browser.evaluateScript("document.getElementById('host').firstChild");
    defer assigned.release();
    const assigned_instance = engine.convertToPlatformObject(realm, assigned.borrow()) orelse return error.NoText;
    const assigned_node = dom.instance_bridge.getNodeBase(assigned_instance) orelse return error.NoText;
    const assigned_style = (try dom.style.engine.fontStyleForText(assigned_node)) orelse return error.NoAssignedStyle;
    try std.testing.expectEqual(@as(f64, 700), assigned_style.get(.font_weight).number);
    inline for (.{ "document.getElementById('unused').firstChild", "document.getElementById('none').firstChild", "document.getElementById('host').shadowRoot.firstChild.firstChild" }) |expression| {
        const value = try browser.evaluateScript(expression);
        defer value.release();
        const instance = engine.convertToPlatformObject(realm, value.borrow()) orelse return error.NoText;
        const node = dom.instance_bridge.getNodeBase(instance) orelse return error.NoText;
        try std.testing.expect(try dom.style.engine.fontStyleForText(node) == null);
    }
    const shadow = try browser.evaluateScript("document.getElementById('shadow').shadowRoot.firstChild");
    defer shadow.release();
    const shadow_instance = engine.convertToPlatformObject(realm, shadow.borrow()) orelse return error.NoText;
    try std.testing.expect(try dom.style.engine.fontStyleForText(dom.instance_bridge.getNodeBase(shadow_instance).?) != null);
}

test "font text inherits through the flat tree and excludes unassigned and hidden text" {
    try fresh(fontTextParent);
}

fn skippedFontText() !void {
    if (comptime !@hasDecl(dom.style.engine, "fontStyleForText")) return error.MissingFontTextStyle;
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><div style='content-visibility:hidden' id=parent>own text<span id=descendant>nested text</span></div></body>", .{ .base_url = "about:blank" });
    const realm = browser.getRealm() orelse return error.NoRealm;
    const computed = try browser.evaluateScript("getComputedStyle(document.getElementById('parent')).getPropertyValue('content-visibility')");
    defer computed.release();
    const computed_text = try engine.convertToDOMString(realm, computed.borrow(), std.testing.allocator);
    defer std.testing.allocator.free(computed_text);
    try std.testing.expectEqualStrings("hidden", computed_text);
    inline for (.{ "parent", "descendant" }) |id| {
        const value = try browser.evaluateScript("document.getElementById('" ++ id ++ "').firstChild");
        defer value.release();
        const instance = engine.convertToPlatformObject(realm, value.borrow()) orelse return error.NoText;
        try std.testing.expect(try dom.style.engine.fontStyleForText(dom.instance_bridge.getNodeBase(instance).?) == null);
    }
}

test "font text under skipped contents excludes own and descendant text" {
    // Q47/Q55's target assertions are active after row118 e72b8c09:
    // the container keeps its box, but its own and descendant text are
    // skipped through the shared CSS Contain 2 applicability helper.
    try fresh(skippedFontText);
}
