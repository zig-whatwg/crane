//! Range XML wrapper removal, preserving namespaces, order and script mode.
const helpers = @import("edges_node_holders_helpers.zig");

fn exercise() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const ns = 'http://www.w3.org/1999/xhtml';
        \\const doc = new DOMParser().parseFromString('<root xmlns="' + ns + '"/>', 'application/xml');
        \\const range = doc.createRange(); range.selectNodeContents(doc.documentElement);
        \\const nested = range.createContextualFragment('<html><head><a/></head><body><b/><html><head><c/></head><body><d/></body></html></body></html>');
        \\if (Array.from(nested.children, e => e.localName).join(',') !== 'a,b,c,d') throw new Error('nested wrappers retained');
        \\const ordinary = range.createContextualFragment('<div><html><body><x/></body></html></div>');
        \\if (ordinary.firstChild.firstChild.localName !== 'html') throw new Error('ordinary descendant changed');
        \\const foreign = range.createContextualFragment('<html xmlns="urn:x"><body/></html>');
        \\if (foreign.firstChild.namespaceURI !== 'urn:x' || foreign.firstChild.firstChild.localName !== 'body') throw new Error('foreign wrappers changed');
        \\const siblings = range.createContextualFragment('<!--a--><html><head/><body>x</body></html><html><body>y</body></html>');
        \\if (siblings.textContent !== 'xy' || siblings.firstChild.nodeType !== 8 || siblings.children.length !== 0) throw new Error('wrapper sibling order');
        \\globalThis.xm1FragmentRan = 0;
        \\const inert = range.createContextualFragment('<html><body><script>globalThis.xm1FragmentRan++</script><p>kept</p></body></html>');
        \\if (xm1FragmentRan !== 0) throw new Error('XML script ran during parse');
        \\document.body.appendChild(inert);
        \\if (xm1FragmentRan !== 0 || inert.childNodes.length !== 0) throw new Error('XML inert script or insertion');
        \\const htmlRange = document.createRange(); htmlRange.selectNodeContents(document.body);
        \\const active = htmlRange.createContextualFragment('<script>globalThis.xm1FragmentRan++</script>');
        \\if (xm1FragmentRan !== 0) throw new Error('HTML script ran during parse');
        \\document.body.appendChild(active);
        \\if (xm1FragmentRan !== 1) throw new Error('HTML fragment script did not run on insertion');
    );
}

test "XML contextual fragments unwrap HTML wrappers without changing insertion semantics" {
    try helpers.onFreshThread(exercise);
}
