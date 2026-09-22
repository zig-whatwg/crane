#!/usr/bin/env python3
"""Generate the Crane 0.1 WPT worklist from the upstream manifest.

THE GOAL IS WEB SPEC CONFORMANCE, NOT COMPATIBILITY WITH ANY ONE FRAMEWORK.

Crane is a general-purpose browser engine. The target is everything a headless
browser engine can run, with rendering and layout as the single deliberate
exclusion. A framework's test suite - React's, or anything else's - is a way to
VERIFY that, never a way to scope it. "Framework X does not use this" is not a
reason to leave something out, and was mistakenly used as one in an earlier
revision of this file.

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
    # --- Core DOM. ---------------------------------------------------------
    ('dom/nodes/',            'node tree, attributes, createElement'),
    ('dom/events/',           'event dispatch: capture, bubble, propagation, listener options'),
    ('dom/ranges/',           'Range and selection'),
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
    ('html/webappapis/timers/',                   'setTimeout/setInterval and their clamping'),
    ('html/webappapis/microtask-queuing/',        'queueMicrotask and microtask ordering'),
    ('html/webappapis/structured-clone/',         'postMessage payloads'),
    ('html/webappapis/scripting/',                'onX handlers, error reporting'),
    ('html/webappapis/atob/',                     'base64'),
    ('html/webappapis/dynamic-markup-insertion/', 'innerHTML, document.write'),

    # --- Element interfaces. -----------------------------------------------
    ('html/semantics/forms/',              'form controls: value, checkedness, validation, submission'),
    ('html/semantics/scripting-1/',        '<script> loading and execution'),
    ('html/semantics/document-metadata/',  'title, link, style, meta, base'),
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
    ('navigation-api/', 'Navigation API - in scope: a headless engine navigates'),
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

    # XML-serialised documents: .xhtml, .svg, .xml.
    #
    # Excluded on measurement, not on assumption. These are real web platform
    # content and belong in a general-purpose engine, but Crane has no XML
    # parser - only an HTML one. Classifying them so they run (FileType ->
    # .html) was tried and measured on 12 xhtml files:
    #
    #     before   12 ERROR, wall_ms = 0, never started
    #     after     9 TIMEOUT + 3 OK, 1 subtest passing
    #
    # So it converts instant errors into 10-second hangs and yields one result.
    # Worse for the gate, worse for run time, and a pass under the HTML parser
    # would be suspect anyway - XHTML needs self-closing tags, namespaces and
    # well-formedness the HTML parser does not implement.
    #
    # Re-include when there is an XML parser. Until then these count as a known
    # missing feature rather than as engine defects.
    ('.xhtml',  'no XML parser - see the measurement above'),
    ('.xht',    'no XML parser'),
    ('.svg',    'no XML parser'),
    ('.xml',    'no XML parser'),

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
