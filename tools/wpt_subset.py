#!/usr/bin/env python3
"""Generate the Crane 0.1 WPT worklist from the upstream manifest.

The 0.1 target is a SLICE of several specs, not a set of whole directories, so
the in-scope allowlist in tests/wpt_runner/config.zig is too coarse to express
it. This emits a path worklist the runner consumes directly:

    python3 tools/wpt_subset.py
    zig build wpt -- --from-file=tests/wpt_0_1_worklist.txt

Every entry below carries the reason it is in or out. When something is added,
add the reason too - a bare path list rots into folklore within a month.

Scope decisions this encodes (2026-09-21):
  * Headless. No iOS build. WPT compliance gates the iOS move.
  * Gate is ZERO crashes and ZERO timeouts. Clean rate is reported, not blocking.
  * Nothing requiring layout or paint. Geometry APIs exist but return
    spec-compliant empties through LayoutBackend.
  * Custom elements fully supported.
  * iframe per spec, minus rendering.
  * All networking through libcurl, cookie store included.
"""
import json
import collections
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(REPO, 'tests', 'wpt', 'MANIFEST.json')
WORKLIST = os.path.join(REPO, 'tests', 'wpt_0_1_worklist.txt')

# Prefix -> why it is in. Checked in order; first match wins.
INCLUDE = [
    # --- Core DOM. react-dom's entire surface lives here. -------------------
    ('dom/nodes/',            'node tree, attributes, createElement'),
    ('dom/events/',           'React delegates 93 event types at the root; capture required'),
    ('dom/ranges/',           'createRange; React selection restore on commit'),
    ('dom/collections/',      'HTMLCollection'),
    ('dom/lists/',            'DOMTokenList / classList'),
    ('dom/abort/',            'AbortController, required by fetch'),
    ('dom/traversal/',        'NodeIterator / TreeWalker'),
    ('dom/idlharness',        'interface shape conformance'),
    ('dom/interface-objects', 'interface shape conformance'),

    # --- Custom elements, full support. ------------------------------------
    ('custom-elements/',      'full support; registry, reactions, upgrades, is='),

    # --- HTML DOM and parsing. ---------------------------------------------
    ('html/dom/',             'Document/Element interfaces, attribute reflection'),
    ('html/syntax/',          'HTML parsing'),

    # --- Scripting and the event loop. -------------------------------------
    ('html/webappapis/timers/',                   "setTimeout: React's scheduler falls back to it"),
    ('html/webappapis/microtask-queuing/',        'queueMicrotask, required by React'),
    ('html/webappapis/structured-clone/',         'postMessage payloads'),
    ('html/webappapis/scripting/',                'onX handlers, error reporting'),
    ('html/webappapis/atob/',                     'base64'),
    ('html/webappapis/dynamic-markup-insertion/', 'innerHTML, document.write'),

    # --- Elements React and app frameworks actually touch. ------------------
    ('html/semantics/forms/',              'React controlled inputs: value/checked/selected'),
    ('html/semantics/scripting-1/',        '<script> loading and execution'),
    ('html/semantics/document-metadata/',  'React 19 hoistables: title/link/style/meta'),
    ('html/semantics/selectors/',          'querySelector / matches'),
    ('html/semantics/tabular-data/',       'table element parsing quirks'),
    ('html/semantics/the-button-element/', 'button'),
    ('html/semantics/links/',              'a, href'),
    ('html/semantics/embedded-content/the-iframe-element/', 'iframe, full spec minus rendering'),

    # --- iframe needs real browsing contexts; navigation needs the rest. ----
    ('html/browsers/windows/',           'nested browsing contexts, contentWindow'),
    ('html/browsers/the-window-object/', 'window, cross-document postMessage'),
    ('html/browsers/origin/',            'same-origin checks for iframe'),
    ('html/browsers/history/',           'session history'),
    ('html/browsers/browsing-the-web/navigating-across-documents/',
                                         'navigate to a URL and load a document'),
    ('html/browsers/browsing-the-web/history-traversal/',  'back / forward'),
    ('html/browsers/browsing-the-web/unloading-documents/', 'beforeunload, unload'),

    # --- Networking. All of it through libcurl. ----------------------------
    ('fetch/api/',     'Fetch API; already reaches LibcurlBackend'),
    ('xhr/',           'XMLHttpRequest; today calls simulateFetch, must route to fetch'),
    ('websockets/',    'WebSocket via curl_ws_send/curl_ws_recv'),
    ('cookiestore/',   "CookieStore; must unify onto curl's cookie engine"),

    # --- Already in the runner's scope and largely working. ----------------
    ('url/', 'URL'), ('urlpattern/', 'URLPattern'), ('encoding/', 'Encoding'),
    ('console/', 'Console'), ('mimesniff/', 'MIME Sniffing'), ('streams/', 'Streams'),
    ('webidl/', 'WebIDL'),
]

# Substring or prefix -> why it is out. Applied before INCLUDE.
EXCLUDE = [
    # Anything that needs layout or paint. Crane is the web platform; the host
    # supplies pixels.
    ('html/rendering/',                         'rendering'),
    ('/canvas/',                                'graphics'),
    ('dom/events/scrolling/',                   'needs layout'),
    ('dom/events/non-cancelable-when-passive/', 'scroll/touch, needs layout'),
    ('html/interaction/',                       'focus traversal needs layout'),
    ('html/browsers/browsing-the-web/scroll-to-fragid/', 'needs layout'),

    # Proposals and things not shipping.
    ('dom/observable/',        'Observable proposal'),
    ('dom/parts/',             'DOM Parts proposal'),
    ('dom/xslt/',              'XSLT'),
    ('dom/nodes/moveBefore/',  'new API, not needed for 0.1'),
    ('/tentative/',            'tentative'),
    ('.tentative.',            'tentative'),
    ('html/semantics/popovers/',           'not in 0.1'),
    ('html/semantics/permission-element/', 'not in 0.1'),
    ('html/semantics/interestfor/',        'not in 0.1'),
    ('navigation-api/',                    'new Navigation API; React and Phoenix do not need it'),
    ('html/browsers/browsing-the-web/back-forward-cache/',  'not in 0.1'),
    ('html/browsers/browsing-the-web/overlapping-navigations', 'not in 0.1'),
    ('html/browsers/browsing-the-web/read-media/', 'media'),

    # No second origin exists in a headless 0.1.
    ('html/cross-origin-',              'no cross-origin isolation in 0.1'),
    ('html/document-isolation-policy/', 'no cross-origin isolation in 0.1'),
    ('html/anonymous-iframe/',          'no cross-origin isolation in 0.1'),

    # Networking corners.
    ('fetch/metadata/',              'Sec-Fetch-* request metadata'),
    ('fetch/fetch-later/',           'not shipping'),
    ('fetch/orb/',                   'opaque response blocking'),
    ('fetch/content-encoding/zstd/', 'zstd'),
    ('websockets/stream/',           'WebSocketStream, not shipping'),

    # Harness infrastructure, not tests.
    ('/support/',                      'support files'),
    ('/resources/',                    'harness resources'),
    ('-manual.',                       'requires a human'),
    ('html/browsers/browsing-the-web/remote-context-helper', 'test infrastructure'),
]


def walk(node, prefix=()):
    """Yield (path, url_count) for every testharness entry in the manifest."""
    for key, value in node.items():
        path = prefix + (key,)
        if isinstance(value, dict):
            yield from walk(value, path)
        elif isinstance(value, list):
            yield '/'.join(path), len(value)


def excluded(path):
    for pattern, _ in EXCLUDE:
        if pattern in path or path.startswith(pattern.lstrip('/')):
            return True
    return False


def main():
    if not os.path.exists(MANIFEST):
        sys.exit(f"manifest not found: {MANIFEST}\n"
                 "The tests/wpt submodule may not be checked out.")

    items = list(walk(json.load(open(MANIFEST))['items']['testharness']))

    chosen = {}
    sources = collections.Counter()
    urls = collections.Counter()
    for path, url_count in items:
        if excluded(path):
            continue
        for prefix, why in INCLUDE:
            if path.startswith(prefix):
                chosen[path] = prefix
                sources[prefix] += 1
                urls[prefix] += url_count
                break

    with open(WORKLIST, 'w') as f:
        f.write("# Crane 0.1 WPT worklist - GENERATED by tools/wpt_subset.py\n")
        f.write("# Do not hand-edit. Change the INCLUDE/EXCLUDE tables in that\n")
        f.write("# script, which carry the reason for every decision, and re-run it.\n")
        f.write(f"# {len(chosen)} sources, {sum(urls.values())} test URLs\n")
        for path in sorted(chosen):
            f.write(path + '\n')

    print(f"{len(chosen)} sources, {sum(urls.values())} test URLs "
          f"(corpus: {len(items)} sources)\n")
    print(f"{'sources':>8} {'urls':>7}  area")
    print('-' * 76)
    for prefix, why in INCLUDE:
        if sources[prefix]:
            print(f"{sources[prefix]:8d} {urls[prefix]:7d}  {prefix:<50} {why}")
    print(f"\nwritten: {os.path.relpath(WORKLIST, REPO)}")


if __name__ == '__main__':
    main()
