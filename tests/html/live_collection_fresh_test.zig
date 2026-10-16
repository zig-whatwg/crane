//! A live collection's cheap per-read check (live_collections.IndexCache.
//! fresh; lane rc5): while the root's document and its tree version are
//! unchanged a read costs one registry lookup, and every change that can
//! alter the collection - an insertion, a removal, an attribute change, an
//! adoption into another document - must still be seen, and a node removed
//! and then freed is never handed out. (A free alone moves no version: see
//! tests/html/tree_version_collection_test.zig.)
const h = @import("refcount_holders_helpers.zig");
const Page = h.Page;
const onFreshThread = h.onFreshThread;

fn freshReadsSeeEveryChange() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\const fail = (what) => { throw new Error(what); };
        \\const root = document.body.appendChild(document.createElement('div'));
        \\root.innerHTML = '<p class=a></p><p></p>';
        \\const tags = root.getElementsByTagName('p');
        \\const classes = root.getElementsByClassName('a');
        \\const children = root.children;
        \\const nodes = root.childNodes;
        \\const read = () => [tags.length, tags[0] && tags[0].localName, classes.length, children.length, nodes.length].join();
        \\if (read() !== '2,p,1,2,2') fail('first read ' + read());
        \\if (read() !== '2,p,1,2,2') fail('second read, unchanged ' + read());
        \\root.appendChild(document.createElement('p')).className = 'a';
        \\if (read() !== '3,p,2,3,3') fail('after an insertion ' + read());
        \\root.firstChild.remove();
        \\if (read() !== '2,p,1,2,2') fail('after a removal ' + read());
        \\root.firstChild.className = 'a';
        \\if (read() !== '2,p,2,2,2') fail('after an attribute change ' + read());
        \\const other = document.implementation.createHTMLDocument('');
        \\other.body.appendChild(root);
        \\if (read() !== '2,p,2,2,2') fail('after adoption ' + read());
        \\root.append(other.createElement('p'));
        \\if (read() !== '3,p,2,3,3') fail('after an insertion in the new document ' + read());
        \\root.textContent = '';
        \\if (read() !== '0,,0,0,0') fail('after emptying ' + read());
    );
}

test "a live collection's cheap per-read check sees every change" {
    try onFreshThread(freshReadsSeeEveryChange);
}

fn freedNodesAreNeverRead() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.root = document.createElement('div');
        \\root.innerHTML = '<p></p><p></p><p></p>';
        \\globalThis.tags = root.getElementsByTagName('p');
        \\if (tags.length !== 3) throw new Error('length');
        \\root.innerHTML = '';
    );
    // The removed paragraphs are unwrapped and nothing holds them: whatever
    // frees them, a read must not hand one out.
    try page.collect();
    try page.run(
        \\if (tags.length !== 0 || tags[0] !== undefined) throw new Error('stale read ' + tags.length);
        \\root.innerHTML = '<p></p>';
        \\if (tags.length !== 1 || tags[0].parentNode !== root) throw new Error('refill');
    );
}

test "a live collection never hands out a node removed since its last read" {
    try onFreshThread(freedNodesAreNeverRead);
}
