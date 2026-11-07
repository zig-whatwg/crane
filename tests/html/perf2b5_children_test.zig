//! A node's children are its sibling links (lane perf2, batch 5: R6 part 2;
//! tmp/plans/perf2b5-design.md 3.4) - no per-node child array, as in Blink,
//! WebKit, Gecko and Lightpanda. Every reader that walked the array now walks
//! the links, and an index (DOM 4.2.1: "the number of preceding siblings") is
//! counted where the spec asks for one.
//!
//! A characterization test: green with the array (d1ee79a9386) and without it.
//! It reads each consumer of children and indexes the array served - the
//! mutation algorithms' orders, childNodes (live, [SameObject]), live ranges'
//! offsets, the structural selectors, XPath positions, compareDocumentPosition,
//! normalize and cloneNode - through script, so the same assertions hold before
//! and after.
const std = @import("std");
const h = @import("refcount_holders_helpers.zig");
const onFreshThread = h.onFreshThread;

const script =
    \\const t = (cond, what) => { if (!cond) throw new Error(what); };
    \\const names = (n) => Array.from(n.childNodes, (c) => c.nodeType === 1 ? c.id : c.data).join(',');
    \\const p = document.createElement('div');
    \\document.body.append(p);
    \\const mk = (id) => { const e = document.createElement('span'); e.id = id; return e; };
    \\const a = mk('a'), b = mk('b'), c = mk('c'), d = mk('d'), e = mk('e');
    \\p.append(a, b, c);
    \\t(names(p) === 'a,b,c', 'append: ' + names(p));
    \\const kids = p.childNodes;
    \\t(kids === p.childNodes, 'childNodes is [SameObject]');
    \\t(kids.length === 3 && kids[1] === b && kids.item(2) === c && kids[3] === undefined, 'childNodes read');
    \\// Live ranges: offsets move with insertions and removals before them.
    \\const r = new Range(); r.setStart(p, 2); r.setEnd(p, 3);
    \\p.insertBefore(d, b);
    \\t(names(p) === 'a,d,b,c', 'insertBefore: ' + names(p));
    \\t(kids.length === 4 && kids[1] === d, 'childNodes is live');
    \\t(r.startOffset === 3 && r.endOffset === 4, 'range after insert: ' + r.startOffset + ',' + r.endOffset);
    \\p.removeChild(a);
    \\t(r.startOffset === 2 && r.endOffset === 3, 'range after remove: ' + r.startOffset + ',' + r.endOffset);
    \\p.replaceChild(e, d);
    \\t(names(p) === 'e,b,c', 'replaceChild: ' + names(p));
    \\t(r.startOffset === 2, 'range after replace: ' + r.startOffset);
    \\// Moving a child within its parent, before itself and to the end.
    \\p.insertBefore(c, e);
    \\t(names(p) === 'c,e,b', 'move to the front: ' + names(p));
    \\p.appendChild(c);
    \\t(names(p) === 'e,b,c', 'move to the end: ' + names(p));
    \\p.insertBefore(b, b.nextSibling);
    \\t(names(p) === 'e,b,c', 'insert before its own next sibling: ' + names(p));
    \\// A fragment's children, in order, and the fragment left empty.
    \\const f = document.createDocumentFragment();
    \\f.append('x', mk('f'), 'y');
    \\p.insertBefore(f, b);
    \\t(names(p) === 'e,x,f,y,b,c' && f.childNodes.length === 0, 'fragment: ' + names(p));
    \\t(p.firstChild.id === 'e' && p.lastChild.id === 'c' && b.previousSibling.data === 'y', 'links');
    \\// Structural selectors count siblings.
    \\// :nth-child counts element siblings only (the text nodes between do not count).
    \\t(p.querySelector(':scope > :nth-child(2)').id === 'f', 'nth-child(2)');
    \\t(p.querySelector(':scope > :nth-child(3)').id === 'b', 'nth-child(3)');
    \\t(p.querySelector(':scope > span:nth-of-type(2)').id === 'f', 'nth-of-type(2)');
    \\t(p.querySelector(':scope > :nth-last-child(1)').id === 'c', 'nth-last-child(1)');
    \\t(p.querySelector(':scope > :nth-last-child(2)').id === 'b', 'nth-last-child(2)');
    \\t(p.querySelector(':scope > :first-child').id === 'e' && p.querySelector(':scope > :last-child').id === 'c', 'first/last-child');
    \\t(p.querySelectorAll(':scope > :only-child').length === 0, 'only-child');
    \\t(p.querySelector('#e + span').id === 'f' && p.querySelector('#f ~ #c') !== null, 'sibling combinators');
    \\// XPath: child positions and sibling axes.
    \\const xp = (expr) => document.evaluate(expr, p, null, XPathResult.ANY_TYPE, null);
    \\t(xp('span[2]').iterateNext().id === 'f', 'xpath span[2]');
    \\t(xp('node()[3]').iterateNext().id === 'f', 'xpath node()[3]');
    \\t(xp('count(node())').numberValue === 6, 'xpath count');
    \\t(xp('span[last()]').iterateNext().id === 'c', 'xpath last()');
    \\t(document.evaluate('following-sibling::*[1]', b, null, XPathResult.ANY_TYPE, null).iterateNext().id === 'c', 'xpath following-sibling');
    \\t(document.evaluate('preceding-sibling::node()[1]', b, null, XPathResult.ANY_TYPE, null).iterateNext().data === 'y', 'xpath preceding-sibling');
    \\// Document position between siblings and cousins.
    \\t(e.compareDocumentPosition(c) === Node.DOCUMENT_POSITION_FOLLOWING, 'following sibling');
    \\t(c.compareDocumentPosition(e) === Node.DOCUMENT_POSITION_PRECEDING, 'preceding sibling');
    \\// normalize merges adjacent text; cloneNode copies the children in order.
    \\p.insertBefore(document.createTextNode('z'), b);
    \\p.normalize();
    \\t(names(p) === 'e,x,f,yz,b,c', 'normalize: ' + names(p));
    \\t(names(p.cloneNode(true)) === 'e,x,f,yz,b,c', 'cloneNode');
    \\// replaceChildren and textContent empty and refill.
    \\p.replaceChildren(c, 'w', a);
    \\t(names(p) === 'c,w,a' && kids.length === 3 && kids[2] === a, 'replaceChildren: ' + names(p));
    \\t(r.startContainer === p && r.startOffset === 0, 'range after replace all: ' + r.startOffset);
    \\p.textContent = 'only';
    \\t(names(p) === 'only' && kids.length === 1, 'textContent');
    \\p.textContent = '';
    \\t(kids.length === 0 && p.firstChild === null && p.lastChild === null && !p.hasChildNodes(), 'emptied');
    \\// A long child list: indexed reads in order and out of order.
    \\for (let i = 0; i < 300; i++) p.append(mk('n' + i));
    \\let ok = true;
    \\for (let i = 0; i < 300; i++) if (kids[i].id !== 'n' + i) ok = false;
    \\for (let i = 299; i >= 0; i -= 7) if (kids[i].id !== 'n' + i) ok = false;
    \\t(ok && kids.length === 300, 'long list');
    \\p.removeChild(kids[150]);
    \\t(kids[150].id === 'n151' && kids.length === 299, 'after a middle removal');
    \\t(p.querySelector(':scope > :nth-child(151)').id === 'n151', 'nth-child after a removal');
    \\0;
;

fn childrenAreTheLinks() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(script);
}

test "children through the links: mutation orders, childNodes, live ranges, structural selectors, XPath, document position" {
    try onFreshThread(childrenAreTheLinks);
}
