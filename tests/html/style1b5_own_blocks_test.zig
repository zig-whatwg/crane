//! Lane style1 batch 5 (step 2): a resolution that matched a block of the
//! element's own - its style attribute's, a presentational hint's - is looked
//! up in the matched-properties cache by the block's CONTENT (Blink:
//! CSSPropertyValueSet::ComputeHash in MatchResult's key, Equals() in
//! CachedMatchedProperties::CorrespondsTo), and the entry keeps a snapshot of
//! the block, so an owner that rewrites its block in place changes nothing
//! the entry holds (design tmp/redesign/style-memory-design.md 3.6).
//!
//! RED at 11e1c6a8b86: a resolution with an own block was never looked up
//! (`Resolution.own_blocks`), so every hit count below was zero.
const std = @import("std");
const testing = std.testing;
const dom = @import("dom");
const helpers = @import("edges_node_holders_helpers.zig");

fn hits(page: helpers.Page) u32 {
    return counters(page).hits;
}

/// The document's cache counters: lookups answered and not.
fn counters(page: helpers.Page) struct { hits: u32, misses: u32 } {
    const document = page.browser.current_context.?.document_instance.?;
    const engine = dom.style.engine.engineOf(document) orelse return .{ .hits = 0, .misses = 0 };
    const cache = engine.matched_properties orelse return .{ .hits = 0, .misses = 0 };
    return .{ .hits = cache.hits, .misses = cache.misses };
}

/// Run `source` and expect every lookup it makes to hit (at least one).
fn expectOnlyHits(page: helpers.Page, source: []const u8) !void {
    const before = counters(page);
    try page.run(source);
    const after = counters(page);
    try testing.expectEqual(before.misses, after.misses);
    try testing.expect(after.hits > before.hits);
}

const rows_css =
    \\.row { display: block; margin: 2px 0; padding: 1px 4px; color: #333; border: 1px solid #ddd; }
    \\.imp { margin-top: 9px !important; }
;

/// `n` rows under #list, each with `style` as its style attribute; every
/// row's margin-top read once.
fn rows(page: helpers.Page, n: usize, style: []const u8) !void {
    var buffer: [4096]u8 = undefined;
    const script = try std.fmt.bufPrint(&buffer,
        \\document.head.insertAdjacentHTML('beforeend', '<style>' + {f} + '</style>');
        \\document.body.innerHTML = '<div id="list"></div>';
        \\{{
        \\  const list = document.getElementById('list');
        \\  for (let i = 0; i < {d}; i++) {{
        \\    const e = document.createElement('div');
        \\    e.className = 'row';
        \\    e.setAttribute('style', {f});
        \\    list.append(e);
        \\  }}
        \\  globalThis.style1b5Tops = [...list.children].map((e) => getComputedStyle(e).marginTop);
        \\}}
    , .{ std.json.fmt(rows_css, .{}), n, std.json.fmt(style, .{}) });
    try page.run(script);
}

fn equalAttributesHit() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const before = hits(page);
    try rows(page, 100, "margin-top: 3px");
    const got = hits(page) - before;
    std.debug.print("\nSTYLE1B5 100 rows with one style attribute: hits {d}\n", .{got});
    // The first row runs the cascade; the 99 after it hold the same content.
    try testing.expect(got >= 99);
    try page.run(
        \\if (new Set(style1b5Tops).size !== 1 || style1b5Tops[0] !== '3px') throw new Error(style1b5Tops.join());
        \\// One content, two spellings (react-ssr writes both): a hit too.
        \\const list = document.getElementById('list');
        \\const a = document.createElement('div'); a.className = 'row'; a.setAttribute('style', 'opacity: 0.6;');
        \\const b = document.createElement('div'); b.className = 'row'; b.setAttribute('style', 'opacity:0.6');
        \\list.append(a, b);
        \\if (getComputedStyle(a).opacity !== '0.6') throw new Error('a ' + getComputedStyle(a).opacity);
    );
    try expectOnlyHits(page,
        \\{ const b = document.getElementById('list').lastChild;
        \\  if (getComputedStyle(b).opacity !== '0.6') throw new Error('b ' + getComputedStyle(b).opacity); }
    );
}

test "elements with equal style attributes hit, whatever the spelling" {
    try helpers.onFreshThread(equalAttributesHit);
}

fn importanceDiffers() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // `.imp` sets margin-top: 9px !important. An important style attribute
    // beats it (Cascade 5 6.1: element-attached declarations win within
    // the author origin's important layer); a normal one loses.
    try page.run(
        \\document.head.insertAdjacentHTML('beforeend', '<style>.row { display: block; } .imp { margin-top: 9px !important; }</style>');
        \\document.body.innerHTML = '<div id="list"></div>';
        \\const list = document.getElementById('list');
        \\const make = (style) => { const e = document.createElement('div'); e.className = 'row imp'; e.setAttribute('style', style); list.append(e); return e; };
        \\const a = make('margin-top: 3px !important');
        \\if (getComputedStyle(a).marginTop !== '3px') throw new Error('important ' + getComputedStyle(a).marginTop);
        \\const b = make('margin-top: 3px');
        \\if (getComputedStyle(b).marginTop !== '9px') throw new Error('normal ' + getComputedStyle(b).marginTop);
        \\const c = make('margin-top: 3px !important');
        \\if (getComputedStyle(c).marginTop !== '3px') throw new Error('important again ' + getComputedStyle(c).marginTop);
    );
}

test "an important style attribute and a normal one with the same value compute differently" {
    try helpers.onFreshThread(importanceDiffers);
}

fn baseUrlsDiffer() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // CSS Values 4 4.5.1: a url() resolves against its declaration's base,
    // the document's when the style attribute was parsed. The same text
    // under another base is another declaration (WPT css/cssom/
    // css-style-attr-decl-block.html, "Changes to CSS declaration block
    // after a base URL change").
    try page.run(
        \\document.head.insertAdjacentHTML('beforeend', '<base href="https://one.test/dir/"><style>.row { display: block; }</style>');
        \\document.body.innerHTML = '<div id="list"></div>';
        \\const list = document.getElementById('list');
        \\const make = (style) => { const e = document.createElement('div'); e.className = 'row'; e.setAttribute('style', style); list.append(e); return e; };
        \\const a = make('background-image: url(./)');
        \\const want_a = 'url("https://one.test/dir/")';
        \\if (getComputedStyle(a).backgroundImage !== want_a) throw new Error('a ' + getComputedStyle(a).backgroundImage);
        \\document.querySelector('base').href = 'https://two.test/other/';
        \\const b = make('background-image: url(./)');
        \\if (getComputedStyle(b).backgroundImage !== 'url("https://two.test/other/")') throw new Error('b ' + getComputedStyle(b).backgroundImage);
        \\if (getComputedStyle(a).backgroundImage !== want_a) throw new Error('a again ' + getComputedStyle(a).backgroundImage);
        \\// A pending-substitution value resolves its url() at substitution,
        \\// against its own declaration's base.
        \\document.querySelector('base').href = 'https://one.test/dir/';
        \\const c = make('--u: url(./x.png); background-image: var(--u)');
        \\if (getComputedStyle(c).backgroundImage !== 'url("https://one.test/dir/x.png")') throw new Error('c ' + getComputedStyle(c).backgroundImage);
        \\document.querySelector('base').href = 'https://two.test/other/';
        \\const d = make('--u: url(./x.png); background-image: var(--u)');
        \\if (getComputedStyle(d).backgroundImage !== 'url("https://two.test/other/x.png")') throw new Error('d ' + getComputedStyle(d).backgroundImage);
    );
}

test "equal style attribute text under another base URL computes its own URL" {
    try helpers.onFreshThread(baseUrlsDiffer);
}

fn rewriteAfterHit() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try rows(page, 3, "margin-top: 3px");
    const before = hits(page);
    try page.run(
        \\const list = document.getElementById('list');
        \\const [a, b] = list.children;
        \\// a's block rewritten in place, through the CSSOM, after b hit a's entry.
        \\a.style.marginTop = '7px';
        \\if (getComputedStyle(a).marginTop !== '7px') throw new Error('a ' + getComputedStyle(a).marginTop);
        \\if (getComputedStyle(b).marginTop !== '3px') throw new Error('b ' + getComputedStyle(b).marginTop);
        \\// The next element with the old content still reads the old value,
        \\// and one with the new content reads the new one.
        \\const c = document.createElement('div'); c.className = 'row'; c.setAttribute('style', 'margin-top: 3px'); list.append(c);
        \\if (getComputedStyle(c).marginTop !== '3px') throw new Error('c ' + getComputedStyle(c).marginTop);
        \\const d = document.createElement('div'); d.className = 'row'; d.setAttribute('style', 'margin-top: 7px'); list.append(d);
        \\if (getComputedStyle(d).marginTop !== '7px') throw new Error('d ' + getComputedStyle(d).marginTop);
        \\// And through the attribute: the block is re-parsed in place.
        \\b.setAttribute('style', 'margin-top: 7px');
        \\if (getComputedStyle(b).marginTop !== '7px') throw new Error('b changed ' + getComputedStyle(b).marginTop);
        \\b.removeAttribute('style');
        \\if (getComputedStyle(b).marginTop !== '2px') throw new Error('b removed ' + getComputedStyle(b).marginTop);
    );
    // c hit the entry a made before its rewrite; d hit a's new one.
    try testing.expect(hits(page) - before >= 2);
}

test "an element's style rewritten in place after a hit leaves the other element's style and the next lookups right" {
    try helpers.onFreshThread(rewriteAfterHit);
}

fn cssomWriteRekeys() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.head.insertAdjacentHTML('beforeend', '<style>.row { display: block; }</style>');
        \\document.body.innerHTML = '<div id="list"></div>';
        \\const list = document.getElementById('list');
        \\const make = (style) => { const e = document.createElement('div'); e.className = 'row'; e.setAttribute('style', style); list.append(e); return e; };
        \\globalThis.style1b5X = make('color: blue');
        \\globalThis.style1b5Y = make('color: red');
        \\if (getComputedStyle(style1b5X).color !== 'rgb(0, 0, 255)') throw new Error('x');
        \\if (getComputedStyle(style1b5Y).color !== 'rgb(255, 0, 0)') throw new Error('y');
    );
    // y's block now holds x's content: its next resolution finds x's entry
    // only under a hash computed again after the write.
    try expectOnlyHits(page,
        \\style1b5Y.style.color = 'blue';
        \\if (getComputedStyle(style1b5Y).color !== 'rgb(0, 0, 255)') throw new Error('y blue ' + getComputedStyle(style1b5Y).color);
    );
    // Typed OM and removeProperty write the same block (a stale hash after
    // any of these writes panics the Debug check in contentHash) ...
    try page.run(
        \\style1b5Y.attributeStyleMap.set('color', 'red');
        \\if (getComputedStyle(style1b5Y).color !== 'rgb(255, 0, 0)') throw new Error('y typed ' + getComputedStyle(style1b5Y).color);
        \\const z = document.createElement('div'); z.className = 'row'; z.setAttribute('style', 'color: red'); document.getElementById('list').append(z);
        \\if (getComputedStyle(z).color !== 'rgb(255, 0, 0)') throw new Error('z');
        \\style1b5Y.style.removeProperty('color');
        \\if (getComputedStyle(style1b5Y).color !== 'rgb(0, 0, 0)') throw new Error('y removed ' + getComputedStyle(style1b5Y).color);
    );
    // ... and the cssText setter: y then holds x's content again.
    try expectOnlyHits(page,
        \\style1b5Y.style.cssText = 'color: blue';
        \\if (getComputedStyle(style1b5Y).color !== 'rgb(0, 0, 255)') throw new Error('y cssText ' + getComputedStyle(style1b5Y).color);
    );
}

test "a CSSOM or Typed OM write to a style attribute keys the block by its new content" {
    try helpers.onFreshThread(cssomWriteRekeys);
}

fn presentationalHints() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const before = hits(page);
    try page.run(
        \\document.head.insertAdjacentHTML('beforeend', '<base href="https://one.test/dir/">');
        \\let html = '';
        \\for (let i = 0; i < 50; i++) html += '<font color="red" face="Georgia" size="5">f</font>';
        \\document.body.innerHTML = '<div id="list">' + html + '</div>';
        \\const fonts = [...document.querySelectorAll('font')];
        \\for (const f of fonts) { const s = getComputedStyle(f); if (s.color !== 'rgb(255, 0, 0)' || s.fontFamily !== 'Georgia' || s.fontSize !== '24px') throw new Error(s.color + ' ' + s.fontFamily + ' ' + s.fontSize); }
        \\fonts[0].setAttribute('color', 'blue');
        \\if (getComputedStyle(fonts[0]).color !== 'rgb(0, 0, 255)') throw new Error('changed ' + getComputedStyle(fonts[0]).color);
        \\if (getComputedStyle(fonts[1]).color !== 'rgb(255, 0, 0)') throw new Error('other ' + getComputedStyle(fonts[1]).color);
    );
    try testing.expect(hits(page) - before >= 49);
    try page.run(
        \\// The background hint resolves against the document's base when parsed.
        \\document.body.insertAdjacentHTML('beforeend', '<table id="t1" background="a.png"></table>');
        \\const t1 = document.getElementById('t1');
        \\if (getComputedStyle(t1).backgroundImage !== 'url("https://one.test/dir/a.png")') throw new Error('t1 ' + getComputedStyle(t1).backgroundImage);
        \\document.querySelector('base').href = 'https://two.test/other/';
        \\document.body.insertAdjacentHTML('beforeend', '<table id="t2" background="a.png"></table>');
        \\const t2 = document.getElementById('t2');
        \\if (getComputedStyle(t2).backgroundImage !== 'url("https://two.test/other/a.png")') throw new Error('t2 ' + getComputedStyle(t2).backgroundImage);
    );
}

test "presentational hints with equal content hit, and a hint under another base computes its own URL" {
    try helpers.onFreshThread(presentationalHints);
}

fn uniqueAttributesFlood() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // 1,000 rows whose style attributes no other row holds, then three rows
    // with one new content, then a row with the 401st row's content. Built
    // first, read after: no read dirties a style.
    try page.run(
        \\document.head.insertAdjacentHTML('beforeend', '<style>.row { display: block; margin: 2px 0; color: #333; }</style>');
        \\document.body.innerHTML = '<div id="list"></div>';
        \\{
        \\  const list = document.getElementById('list');
        \\  const make = (style) => { const e = document.createElement('div'); e.className = 'row'; e.setAttribute('style', style); list.append(e); return e; };
        \\  globalThis.flood = [];
        \\  for (let i = 0; i < 1000; i++) flood.push(make('margin-top: ' + i + 'px'));
        \\  globalThis.repeats = [make('margin-top: 5000px'), make('margin-top: 5000px'), make('margin-top: 5000px')];
        \\  globalThis.again = make('margin-top: 400px');
        \\  for (let i = 0; i < 1000; i++) if (getComputedStyle(flood[i]).marginTop !== i + 'px') throw new Error('row ' + i);
        \\}
    );
    const document = page.browser.current_context.?.document_instance.?;
    const cache = dom.style.engine.engineOf(document).?.matched_properties.?;
    const Cache = @TypeOf(cache.*);
    std.debug.print("\nSTYLE1B5 1,000 unique style attributes: entries {d} hits {d} misses {d}\n", .{ cache.entries, cache.hits, cache.misses });
    // The first prune (at the cache's limit, some 490 rows in) finds that
    // no own-block entry served a hit; from there a content no other
    // element holds gets no entry (design 3.6 item 9), so the cache holds
    // what that prune kept and is not pruned again ...
    try testing.expect(cache.entries <= Cache.prune_target + 2 * Cache.per_key);
    // ... an entry that prune kept still serves ...
    try expectOnlyHits(page,
        \\if (getComputedStyle(again).marginTop !== '400px') throw new Error('again ' + getComputedStyle(again).marginTop);
    );
    // ... and a content that repeats is kept from its second sighting: two
    // cascades, then a hit.
    const before = counters(page);
    try page.run(
        \\for (const e of repeats) if (getComputedStyle(e).marginTop !== '5000px') throw new Error('repeat ' + getComputedStyle(e).marginTop);
    );
    const after = counters(page);
    try testing.expectEqual(before.misses + 2, after.misses);
    try testing.expectEqual(before.hits + 1, after.hits);
}

test "style attributes no other element holds do not prune the cache; one that repeats is kept from its second sighting" {
    try helpers.onFreshThread(uniqueAttributesFlood);
}
