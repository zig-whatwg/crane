//! The live DOM over CDP (lane cdpd1, batch 1; roadmap cdp-live-dom): the
//! DOM-domain events a DOM-enabled session is sent when the page mutates its
//! tree, in Chrome's order and shape - Blink's InspectorDOMAgent
//! (third_party/blink/renderer/core/inspector/inspector_dom_agent.cc at
//! Chrome 157.0.8103.78: DidInsertDOMNode, WillRemoveDOMNode /
//! DOMNodeRemoved, DidModifyDOMAttr, DidRemoveDOMAttr, CharacterDataModified,
//! DidInvalidateStyleAttr, DidPushShadowRoot, TopLayerElementsChanged,
//! InvalidateFrameOwnerElement).
//!
//! Through page sessions attached to a Browser on its own thread, with no
//! transport (the cdph harness's shape): what is checked is what a client
//! would be sent. Each expected node id follows Blink's bind order: getDocument
//! binds depth-first in tree order from 1, and every node an event pushes
//! takes the next id.
//!
//! Every test page is
//!     <body><div id=a><span>x</span></div><p id=b></p></body>
//! (no doctype, no whitespace), which DOM.getDocument {depth: -1} binds as
//!     #document 1, HTML 2, HEAD 3, BODY 4, DIV#a 5, SPAN 6, "x" 7, P#b 8
//! unless the test says otherwise.

const std = @import("std");
const testing = std.testing;
const devtools = @import("devtools");
const harness = @import("cdpd1_harness.zig");
const Harness = harness.Harness;
const page = harness.page;
const setUp = harness.setUp;
const expectEvents = harness.expectEvents;

test "an insertion under a parent whose children the client has is childNodeInserted, with the previous inner sibling and the node built at depth 0 (DidInsertDOMNode)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    const from = h.seen.items.len;
    try h.run(
        \\const b = document.getElementById('b');
        \\b.appendChild(document.createElement('i'));
        \\b.insertBefore(document.createElement('em'), b.firstChild);
        \\b.appendChild(document.createTextNode('tt'));
        \\b.appendChild(document.createTextNode('  '));
        \\const s = document.createElement('span');
        \\s.textContent = 'y';
        \\b.appendChild(s);
    );
    // The whitespace-only text node is skipped (ShouldSkipNode), and so is
    // it as the span's previous sibling (InnerPreviousSibling); a node with
    // an only text child takes it along (BuildArrayForContainerChildren's
    // special case).
    try expectEvents(&h, from,
        \\childNodeInserted 8 0 I#9/0
        \\childNodeInserted 8 0 EM#10/0
        \\childNodeInserted 8 9 #text#11'tt'
        \\childNodeInserted 8 11 SPAN#12/1[#text#13'y']
        \\
    );
}

test "a parent the client has not been sent the children of gets childNodeCountUpdated, from the count it was sent; deeper changes send nothing" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    // Depth 2: #document 1, HTML 2, HEAD 3, BODY 4 (children not sent).
    try setUp(&h, page, 2);
    const from = h.seen.items.len;
    try h.run(
        \\document.body.appendChild(document.createElement('i'));
        \\document.getElementById('b').remove();
        \\document.getElementById('a').appendChild(document.createElement('q'));
    );
    try expectEvents(&h, from,
        \\childNodeCountUpdated 4 3
        \\childNodeCountUpdated 4 2
        \\
    );
}

test "a removal is childNodeRemoved and unbinds the subtree: changes inside it send nothing, and reinserting it binds it anew (WillRemoveDOMNode, Unbind)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    const from = h.seen.items.len;
    try h.run(
        \\const a = document.getElementById('a');
        \\a.remove();
        \\a.firstChild.appendChild(document.createElement('b'));
        \\a.setAttribute('title', 't');
        \\document.body.appendChild(a);
    );
    try expectEvents(&h, from,
        \\childNodeRemoved 4 5
        \\childNodeInserted 4 8 DIV#9/1{id=a,title=t}
        \\
    );
}

test "attributes: attributeModified with the qualified name, nothing for the same value, attributeRemoved; unbound elements send nothing (DidModifyDOMAttr, DidRemoveDOMAttr)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    const from = h.seen.items.len;
    try h.run(
        \\const a = document.getElementById('a');
        \\a.setAttribute('title', 't');
        \\a.setAttribute('title', 't');
        \\a.setAttribute('title', 'u');
        \\a.removeAttribute('title');
        \\a.removeAttribute('nope');
        \\a.setAttributeNS('http://www.w3.org/1999/xlink', 'xl:href', 'v');
        \\a.removeAttributeNS('http://www.w3.org/1999/xlink', 'href');
        \\a.id = 'a2';
        \\a.toggleAttribute('hidden');
        \\document.createElement('q').setAttribute('z', '1');
    );
    try expectEvents(&h, from,
        \\attributeModified 5 title=t
        \\attributeModified 5 title=u
        \\attributeRemoved 5 title
        \\attributeModified 5 xl:href=v
        \\attributeRemoved 5 xl:href
        \\attributeModified 5 id=a2
        \\attributeModified 5 hidden=
        \\
    );
}

test "character data: characterDataModified with the whole data; a bound text node turned whitespace-only is removed, and one that stops being so is inserted (CharacterDataModified)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    const from = h.seen.items.len;
    try h.run(
        \\const t = document.querySelector('span').firstChild;
        \\t.data = 'y';
        \\t.appendData('z');
        \\t.data = '  ';
        \\t.data = 'w';
    );
    try expectEvents(&h, from,
        \\characterDataModified 7 y
        \\characterDataModified 7 yz
        \\childNodeRemoved 6 7
        \\childNodeInserted 6 0 #text#9'w'
        \\
    );
}

test "a fragment's children are inserted one by one, each after the last; innerHTML removes then inserts" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    const from = h.seen.items.len;
    try h.run(
        \\const f = document.createDocumentFragment();
        \\f.append('one', document.createElement('em'), 'two');
        \\document.getElementById('b').append(f);
        \\document.getElementById('a').innerHTML = '<b>q</b>';
    );
    try expectEvents(&h, from,
        \\childNodeInserted 8 0 #text#9'one'
        \\childNodeInserted 8 9 EM#10/0
        \\childNodeInserted 8 10 #text#11'two'
        \\childNodeRemoved 5 6
        \\childNodeInserted 5 0 B#12/1[#text#13'q']
        \\
    );
}

test "CSSOM invalidates the inline style in a later task with no attributeModified; setting the style attribute sends both (DidInvalidateStyleAttr, InspectorRevalidateDOMTask)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    var from = h.seen.items.len;
    try h.run("document.getElementById('a').style.color = 'red';");
    _ = try h.waitEvent("DOM.inlineStyleInvalidated", from);
    try expectEvents(&h, from,
        \\inlineStyleInvalidated [5]
        \\
    );
    from = h.seen.items.len;
    try h.run(
        \\const a = document.getElementById('a');
        \\a.setAttribute('style', 'color: blue');
        \\document.querySelector('span').style.color = 'green';
    );
    _ = try h.waitEvent("DOM.inlineStyleInvalidated", from);
    try expectEvents(&h, from,
        \\attributeModified 5 style=color: blue
        \\inlineStyleInvalidated [5,6]
        \\
    );
}

test "attaching a shadow root to a bound host is shadowRootPushed with the root built at depth 0; the root's children are counted (DidPushShadowRoot)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    const from = h.seen.items.len;
    try h.run(
        \\const root = document.getElementById('a').attachShadow({ mode: 'open' });
        \\root.append(document.createElement('slot'));
        \\document.getElementById('b').attachShadow({ mode: 'closed' });
        \\document.createElement('div').attachShadow({ mode: 'open' });
    );
    try expectEvents(&h, from,
        \\shadowRootPushed 5 #document-fragment#9/0 open
        \\childNodeCountUpdated 9 1
        \\shadowRootPushed 8 #document-fragment#10/0 closed
        \\
    );
}

test "a modal dialog entering and leaving the top layer is topLayerElementsUpdated, after its open attribute changes (TopLayerElementsChanged)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    // DIALOG#d is 9.
    try setUp(&h, "data:text/html,<body><div id=a><span>x</span></div><p id=b></p><dialog id=d></dialog></body>", null);
    const from = h.seen.items.len;
    try h.run("document.getElementById('d').showModal();");
    try h.settle();
    try h.run("document.getElementById('d').close();");
    try h.settle();
    // In the top layer it has a ::backdrop (the UA's dialog::backdrop),
    // made and destroyed by the next style recalc each time.
    try expectEvents(&h, from,
        \\attributeModified 9 open=
        \\topLayerElementsUpdated
        \\pseudoElementAdded 9 ::backdrop#10/0 backdrop
        \\attributeRemoved 9 open
        \\topLayerElementsUpdated
        \\pseudoElementRemoved 9 10
        \\
    );
}

test "a child frame's new document re-sends its owner: childNodeRemoved, then childNodeInserted with the new content document (InvalidateFrameOwnerElement)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    // #document 1, HTML 2, HEAD 3, BODY 4, IFRAME#f 5, its #document 6. The
    // owner is sent again at the new document's commit, before its parser
    // ran: Blink's DocumentLoader::DidCommitNavigation calls
    // probe::DidCommitLoad with the new document still empty.
    try setUp(&h, "data:text/html,<body><iframe id=f></iframe></body>", null);
    const from = h.seen.items.len;
    try h.run("document.getElementById('f').src = 'data:text/html,<p>z';");
    _ = try h.waitEvent("DOM.childNodeInserted", from);
    try expectEvents(&h, from,
        \\attributeModified 5 src=data:text/html,<p>z
        \\childNodeRemoved 4 5
        \\childNodeInserted 4 0 IFRAME#7/0{id=f,src=data:text/html,<p>z}(#document#8/0)
        \\
    );
}

test "every DOM-enabled session is sent the events, each with its own node ids; a disabled one is sent none, and disable when not enabled fails as Chrome's" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try h.attach(1);
    try setUp(&h, page, null);
    _ = try h.callOn(1, "DOM.getDocument", "{\"depth\":2}");
    var from = h.seen.items.len;
    try h.run("document.getElementById('b').appendChild(document.createElement('i'));");
    var first: std.ArrayList(u8) = .empty;
    defer first.deinit(h.allocator);
    try h.domEvents(0, from, &first);
    try testing.expectEqualStrings("childNodeInserted 8 0 I#9/0\n", first.items);
    var second: std.ArrayList(u8) = .empty;
    defer second.deinit(h.allocator);
    try h.domEvents(1, from, &second);
    // Session 2 took the document at depth 2: P#b was never sent to it.
    try testing.expectEqualStrings("", second.items);

    _ = try h.callOn(1, "DOM.disable", "{}");
    try testing.expectEqualStrings("DOM agent hasn't been enabled", try h.errorMessage(try h.sendOn(1, "DOM.disable", "{}")));
    from = h.seen.items.len;
    try h.run("document.body.appendChild(document.createElement('i'));");
    second.clearRetainingCapacity();
    try h.domEvents(1, from, &second);
    try testing.expectEqualStrings("", second.items);
    first.clearRetainingCapacity();
    try h.domEvents(0, from, &first);
    try testing.expectEqualStrings("childNodeInserted 4 8 I#10/0\n", first.items);
}

test "the probes' gate opens with an enabled DOM agent and closes with its disable or its session's end (Blink's CoreProbeSink::s_existingAgents)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    const before = devtools.dom_events.enabledAgentCount();
    try h.load(page);
    _ = try h.call("DOM.enable", "{}");
    _ = try h.call("DOM.enable", "{}");
    try testing.expectEqual(before + 1, devtools.dom_events.enabledAgentCount());
    _ = try h.call("DOM.disable", "{}");
    try testing.expectEqual(before, devtools.dom_events.enabledAgentCount());
    // getDocument enables the agent ("Backward compatibility").
    _ = try h.call("DOM.getDocument", "{}");
    try testing.expectEqual(before + 1, devtools.dom_events.enabledAgentCount());
    h.detach(0);
    // The detach runs on the Browser thread; a later session message
    // follows it there.
    try h.attach(1);
    _ = try h.callOn(1, "Page.getFrameTree", "{}");
    try testing.expectEqual(before, devtools.dom_events.enabledAgentCount());
}

test "a slot's distribution is sent at the next rendering update, as Blink's lazy slot assignment reports it (DidPerformSlotDistribution)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    var from = h.seen.items.len;
    try h.run("document.getElementById('a').attachShadow({ mode: 'open' }).innerHTML = '<slot></slot>';");
    // The slot was not bound when SPAN was assigned to it: nothing to send.
    try h.settle();
    _ = try h.call("DOM.requestChildNodes", "{\"nodeId\":9}");
    try expectEvents(&h, from,
        \\shadowRootPushed 5 #document-fragment#9/0 open
        \\childNodeCountUpdated 9 1
        \\setChildNodes 9 [SLOT#10/0[]]
        \\
    );
    from = h.seen.items.len;
    try h.run("document.getElementById('a').appendChild(document.createElement('i'));");
    _ = try h.waitEvent("DOM.distributedNodesUpdated", from);
    try expectEvents(&h, from,
        \\childNodeInserted 5 6 I#11/0
        \\distributedNodesUpdated 10 [SPAN,I]
        \\
    );
}

test "adoptedStyleSheets: a change is adoptedStyleSheetsModified in the revalidation task, with Blink's styleSheetIds, and the document lists them (DidModifyAdoptedStyleSheets; IdentifiersFactory::IdForCSSStyleSheet)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    try setUp(&h, page, null);
    const from = h.seen.items.len;
    try h.run("window.s1 = new CSSStyleSheet(); window.s2 = new CSSStyleSheet(); document.adoptedStyleSheets = [s1, s2];");
    _ = try h.waitEvent("DOM.adoptedStyleSheetsModified", from);
    // The process part is the Browser's devtools token (0xC0FFEE) % 100000.
    try expectEvents(&h, from,
        \\adoptedStyleSheetsModified 1 [style-sheet-48430-1,style-sheet-48430-2]
        \\
    );
    const got = try h.call("DOM.getDocument", "{\"depth\":0}");
    const sheets = got.object.get("root").?.object.get("adoptedStyleSheets").?.array.items;
    try testing.expectEqual(@as(usize, 2), sheets.len);
    try testing.expectEqualStrings("style-sheet-48430-1", sheets[0].string);
}

test "pseudo-elements: one that starts or stops generating a box is pseudoElementAdded / pseudoElementRemoved at the next rendering update; a document's elements list theirs (PseudoElementCreated, PseudoElementDestroyed, BuildArrayForPseudoElements)" {
    var h: Harness = undefined;
    try h.init(testing.allocator);
    defer h.deinit();
    // #document 1, HTML 2, HEAD 3, STYLE 4, its text 5, BODY 6, DIV#a 7,
    // its ::before 8 (bound with the div, before its children), SPAN 9,
    // "x" 10, P#b 11.
    try setUp(&h, "data:text/html,<style>.x::before{content:'b'}</style><body><div id=a class=x><span>x</span></div><p id=b></p></body>", null);
    var from = h.seen.items.len;
    try h.run("document.getElementById('a').className = '';");
    try h.settle();
    try h.run("document.getElementById('b').className = 'x';");
    try h.settle();
    try expectEvents(&h, from,
        \\attributeModified 7 class=
        \\pseudoElementRemoved 7 8
        \\attributeModified 11 class=x
        \\pseudoElementAdded 11 ::before#12/0 before
        \\
    );
    // A node inserted is sent with no pseudo-element; the recalc adds them -
    // a q has both, by the UA sheet's quotes - each after its parent's
    // children are pushed, the first time with an empty setChildNodes
    // (PseudoElementCreated's PushChildNodesToFrontend(parent_id, 1)).
    from = h.seen.items.len;
    try h.run("const q = document.createElement('q'); q.className = 'x'; document.body.append(q);");
    try h.settle();
    try expectEvents(&h, from,
        \\childNodeInserted 6 11 Q#13/0{class=x}
        \\setChildNodes 13 []
        \\pseudoElementAdded 13 ::before#14/0 before
        \\pseudoElementAdded 13 ::after#15/0 after
        \\
    );
}
