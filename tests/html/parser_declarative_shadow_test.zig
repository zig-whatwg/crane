//! Declarative shadow DOM: HTML "in head", a start tag whose tag name is
//! "template", steps 6-7 - a template with a shadowrootmode attribute attaches
//! a shadow root to the adjusted current node and its contents parse into it.
//! Allowed where the parser's "allow declarative shadow roots" is true: a
//! navigated document's parser and document.open on it, setHTMLUnsafe and
//! parseHTMLUnsafe; not innerHTML, DOMParser or a createHTMLDocument document.
//! Chrome, Firefox and Safari all ship it (shadow-dom/declarative/).
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");

fn onFreshThread(comptime exercise: fn () anyerror!void) !void {
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

/// Load `markup` as the page, then evaluate `script`; it must return "ok".
fn expectOk(markup: []const u8, comptime script: []const u8) !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(markup, .{ .base_url = "http://example.test/declarative-shadow" });
    const result = try page.evaluateScriptToString(script, testing.allocator);
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("ok", result);
}

fn livePage() !void {
    try expectOk(
        \\<!doctype html><body>
        \\<div id=open><template shadowrootmode=open shadowrootdelegatesfocus shadowrootclonable shadowrootserializable><slot></slot><span id=inner>in</span></template><p>light</p></div>
        \\<div id=closed><template shadowrootmode=closed><b>c</b></template></div>
        \\<div id=twice><template shadowrootmode=open>one</template><template shadowrootmode=open>two</template></div>
        \\<a id=badhost><template shadowrootmode=open>x</template></a>
        \\<div id=badmode><template shadowrootmode=sideways>x</template></div>
        \\<script>
        \\var closedRoot = null;
        \\</script>
    ,
        \\(() => {
        \\  const fail = [];
        \\  const open = document.getElementById('open');
        \\  const root = open.shadowRoot;
        \\  if (!root) return 'no open shadow root';
        \\  if (root.mode !== 'open') fail.push('mode ' + root.mode);
        \\  if (!root.delegatesFocus) fail.push('delegatesFocus');
        \\  if (!root.clonable) fail.push('clonable');
        \\  if (!root.serializable) fail.push('serializable');
        \\  if (root.querySelector('#inner')?.textContent !== 'in') fail.push('content');
        \\  if (open.querySelector('template')) fail.push('the template stayed in the light tree');
        \\  if (open.innerHTML !== '<p>light</p>') fail.push('light ' + open.innerHTML);
        \\  if (root.querySelector('slot').assignedNodes().length !== 1) fail.push('slot assignment');
        \\  const closed = document.getElementById('closed');
        \\  if (closed.shadowRoot !== null) fail.push('closed root exposed');
        \\  if (closed.firstChild !== null) fail.push('closed host has children: ' + closed.innerHTML);
        \\  const twice = document.getElementById('twice');
        \\  if (twice.shadowRoot?.textContent !== 'one') fail.push('first template wins');
        \\  const second = twice.querySelector('template');
        \\  if (!second || second.content.textContent !== 'two' || second.getAttribute('shadowrootmode') !== 'open') fail.push('second template is ordinary: ' + twice.innerHTML);
        \\  const bad = document.getElementById('badhost');
        \\  if (bad.shadowRoot || !bad.querySelector('template')) fail.push('invalid host');
        \\  const badmode = document.getElementById('badmode');
        \\  if (badmode.shadowRoot || !badmode.querySelector('template')) fail.push('invalid mode');
        \\  return fail.length ? fail.join('; ') : 'ok';
        \\})()
    );
}

test "a parsed page attaches declarative shadow roots" {
    try onFreshThread(livePage);
}

fn attachShadowReusesDeclarative() !void {
    try expectOk(
        \\<!doctype html><body><div id=host><template shadowrootmode=open><span>old</span></template></div>
    ,
        \\(() => {
        \\  const host = document.getElementById('host');
        \\  const root = host.shadowRoot;
        \\  let threw = false;
        \\  try { host.attachShadow({mode: 'closed'}); } catch (e) { threw = e.name; }
        \\  if (threw !== 'NotSupportedError') return 'other mode: ' + threw;
        \\  const again = host.attachShadow({mode: 'open'});
        \\  if (again !== root) return 'not the same root';
        \\  if (again.firstChild !== null) return 'not emptied';
        \\  try { host.attachShadow({mode: 'open'}); return 'reused twice'; } catch (e) { if (e.name !== 'NotSupportedError') return e.name; }
        \\  return 'ok';
        \\})()
    );
}

test "attachShadow on a declarative host reuses its root once, emptied" {
    try onFreshThread(attachShadowReusesDeclarative);
}

fn optIns() !void {
    try expectOk(
        \\<!doctype html><body>
    ,
        \\(() => {
        \\  const fail = [];
        \\  const markup = '<div id=h><template shadowrootmode=open><i>s</i></template></div>';
        \\  const div = document.createElement('div');
        \\  div.innerHTML = markup;
        \\  if (div.firstChild.shadowRoot || !div.querySelector('template')) fail.push('innerHTML');
        \\  const unsafe = document.createElement('div');
        \\  unsafe.setHTMLUnsafe(markup);
        \\  if (unsafe.firstChild.shadowRoot?.textContent !== 's') fail.push('setHTMLUnsafe ' + unsafe.innerHTML);
        \\  const parsed = Document.parseHTMLUnsafe(markup);
        \\  if (parsed.getElementById('h').shadowRoot?.textContent !== 's') fail.push('parseHTMLUnsafe');
        \\  const domparser = new DOMParser().parseFromString(markup, 'text/html');
        \\  if (domparser.getElementById('h').shadowRoot) fail.push('DOMParser');
        \\  const fresh = document.implementation.createHTMLDocument('');
        \\  fresh.write(markup);
        \\  if (fresh.getElementById('h').shadowRoot) fail.push('createHTMLDocument write');
        \\  const host = document.createElement('div');
        \\  const shadow = host.attachShadow({mode: 'open'});
        \\  shadow.setHTMLUnsafe(markup);
        \\  if (shadow.firstChild.shadowRoot?.textContent !== 's') fail.push('ShadowRoot setHTMLUnsafe');
        \\  const reopened = Document.parseHTMLUnsafe('');
        \\  reopened.open(); reopened.write(markup); reopened.close();
        \\  if (reopened.getElementById('h').shadowRoot?.textContent !== 's') fail.push('parseHTMLUnsafe then open');
        \\  return fail.length ? fail.join('; ') : 'ok';
        \\})()
    );
}

test "declarative shadow roots need the opt-in: setHTMLUnsafe and parseHTMLUnsafe, not innerHTML or DOMParser" {
    try onFreshThread(optIns);
}

fn getHTML() !void {
    try expectOk(
        \\<!doctype html><body>
    ,
        \\(() => {
        \\  const fail = [];
        \\  const host = document.createElement('div');
        \\  host.setHTMLUnsafe('<span><template shadowrootmode=open shadowrootserializable shadowrootdelegatesfocus shadowrootclonable><b>x</b></template>light</span>');
        \\  const span = host.firstChild;
        \\  const expected = '<span><template shadowrootmode="open" shadowrootdelegatesfocus="" shadowrootserializable="" shadowrootclonable=""><b>x</b></template>light</span>';
        \\  const got = host.getHTML({serializableShadowRoots: true});
        \\  if (got !== expected) fail.push('serializable: ' + got);
        \\  if (host.getHTML() !== '<span>light</span>') fail.push('no options: ' + host.getHTML());
        \\  if (host.innerHTML !== '<span>light</span>') fail.push('innerHTML: ' + host.innerHTML);
        \\  const other = document.createElement('div');
        \\  other.setHTMLUnsafe('<p><template shadowrootmode=closed><u>y</u></template></p>');
        \\  if (other.getHTML({serializableShadowRoots: true}) !== '<p></p>') fail.push('not serializable');
        \\  if (span.shadowRoot.getHTML() !== '<b>x</b>') fail.push('ShadowRoot.getHTML ' + span.shadowRoot.getHTML());
        \\  if (span.shadowRoot.innerHTML !== '<b>x</b>') fail.push('ShadowRoot.innerHTML ' + span.shadowRoot.innerHTML);
        \\  const p = document.createElement('p');
        \\  const shadow = p.attachShadow({mode: 'closed'});
        \\  shadow.innerHTML = '<i>z</i>';
        \\  const wrap = document.createElement('div');
        \\  wrap.append(p);
        \\  const listed = wrap.getHTML({shadowRoots: [shadow]});
        \\  if (listed !== '<p><template shadowrootmode="closed"><i>z</i></template></p>') fail.push('shadowRoots: ' + listed);
        \\  return fail.length ? fail.join('; ') : 'ok';
        \\})()
    );
}

test "getHTML serializes the shadow roots it is asked for" {
    try onFreshThread(getHTML);
}

fn documentWriteAndClone() !void {
    try expectOk(
        \\<!doctype html><body>
    ,
        \\(() => {
        \\  const fail = [];
        \\  const frame = document.body.appendChild(document.createElement('iframe')).contentDocument;
        \\  frame.open();
        \\  frame.write('<div id=h><template shadowrootmode=open>w</template></div>');
        \\  frame.close();
        \\  if (frame.getElementById('h').shadowRoot?.textContent !== 'w') fail.push('document.write into a frame');
        \\  const copy = document.cloneNode(false);
        \\  copy.write('<div><template shadowrootmode=open>c</template></div>');
        \\  if (copy.body.firstChild.shadowRoot?.textContent !== 'c') fail.push('a clone keeps the opt-in');
        \\  return fail.length ? fail.join('; ') : 'ok';
        \\})()
    );
}

test "document.write into a navigable's document and a clone of it allow declarative shadow roots" {
    try onFreshThread(documentWriteAndClone);
}

fn shadowRootModeReflection() !void {
    try expectOk(
        \\<!doctype html><body>
    ,
        \\(() => {
        \\  const t = document.createElement('template');
        \\  if (t.shadowRootMode !== '') return 'absent: ' + t.shadowRootMode;
        \\  t.setAttribute('shadowrootmode', 'OPEN');
        \\  if (t.shadowRootMode !== 'open') return 'OPEN: ' + t.shadowRootMode;
        \\  t.setAttribute('shadowrootmode', 'closed');
        \\  if (t.shadowRootMode !== 'closed') return 'closed: ' + t.shadowRootMode;
        \\  t.setAttribute('shadowrootmode', 'sideways');
        \\  if (t.shadowRootMode !== '') return 'invalid: ' + t.shadowRootMode;
        \\  t.shadowRootMode = 'Closed';
        \\  if (t.getAttribute('shadowrootmode') !== 'Closed' || t.shadowRootMode !== 'closed') return 'setter';
        \\  return 'ok';
        \\})()
    );
}

test "template.shadowRootMode reflects shadowrootmode, limited to only known values" {
    try onFreshThread(shadowRootModeReflection);
}
