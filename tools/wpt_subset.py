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
import argparse
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

    # --- Tier 1: core headless APIs real apps and agents use (the user, 2026-10-01). ---
    ('shadow-dom/',    'DOM Standard shadow trees, slots, retargeting'),
    ('IndexedDB/',     'IndexedDB'),
    ('WebCryptoAPI/',  'Web Crypto (crypto.subtle, getRandomValues)'),
    ('webstorage/',    'localStorage / sessionStorage and storage events'),
    ('domxpath/',      'document.evaluate / XPath'),
    ('domparsing/',    'DOMParser, XMLSerializer, innerHTML/outerHTML, insertAdjacentHTML'),
    ('selection/',     'Selection API'),
    ('cookies/',       'HTTP cookie semantics through libcurl'),
    ('wasm/',          'WebAssembly JS and Web APIs'),
    ('FileAPI/',       'Blob, File, FileReader, blob URLs'),
    ('workers/',       'dedicated and shared workers'),

    # --- Tier 2: security, performance timing, service workers (the user, 2026-10-01). ---
    ('referrer-policy/',           'Referrer Policy'),
    ('content-security-policy/',   'Content Security Policy'),
    ('mixed-content/',             'Mixed Content'),
    ('cors/',                      'CORS'),
    ('subresource-integrity/',     'Subresource Integrity'),
    ('trusted-types/',             'Trusted Types'),
    ('sanitizer-api/',             'HTML Sanitizer API'),
    ('upgrade-insecure-requests/', 'Upgrade Insecure Requests'),
    ('service-workers/',           'Service Workers and the Cache API'),
    ('user-timing/',               'User Timing'),
    ('resource-timing/',           'Resource Timing'),
    ('navigation-timing/',         'Navigation Timing'),
    ('performance-timeline/',      'Performance Timeline'),
    ('hr-time/',                   'High Resolution Time'),
    ('beacon/',                    'Beacon'),
    ('eventsource/',               'Server-Sent Events'),
    ('webmessaging/',              'MessageChannel, BroadcastChannel, postMessage'),
    ('web-locks/',                 'Web Locks'),
    ('compression/',               'Compression Streams'),
    ('permissions/',               'Permissions API'),
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
    # The WebSocketInit option bag (and its targetAddressSpace member) is
    # whatwg/websockets#76, still open; no stable browser ships it (wpt.fyi
    # 2026-10-17: Chrome 155, Firefox 158 and Safari 27 pass 0 of 2 and 0 of 6
    # in every variant; only Chrome 158 dev's experimental run passes).
    # Re-include when the PR merges or a stable browser ships it.
    ('websockets/constructor/option-bag.any.js',           'WebSocketInit, unmerged whatwg/websockets#76'),
    ('websockets/constructor/target-address-space.any.js', 'WebSocketInit, unmerged whatwg/websockets#76'),
    # The editable combobox (<input list> with appearance:base) exists only in
    # Open UI's explainer (the file's only rel=help is
    # open-ui.org/components/combobox.explainer); HTML has no text for it, and
    # every sibling in customizable-combobox/ is .tentative. No browser passes
    # it (wpt.fyi 23b0b89b1a, 2026-10-18: Chrome, Firefox and Safari fail
    # "Datalist should open after focusing input"; Edge 0 of 1). Codex row 72
    # Q7. Re-include when HTML specifies it or a stable browser ships it.
    ('html/semantics/forms/customizable-combobox/customizable-combobox-option-attributes.html',
     'editable combobox, Open UI explainer only'),
    # Restoring a <select multiple>'s selectedcontent after a history
    # traversal: HTML's "update a select's descendant selectedcontent
    # elements" step 1 returns when the select has multiple, and the file says
    # itself that form control restoration is not specified (rel=help
    # whatwg/html#9799). No browser passes its first assertion (Chrome, Firefox
    # and Safari, 2026-10-18). Codex row 72 Q8. Re-include when HTML specifies
    # selectedcontent for multiple selects.
    ('html/semantics/forms/the-select-element/customizable-select-multiple-popup/selectedcontent-multiple-restore.optional.html',
     'selectedcontent for select multiple, unspecified'),

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

    # Tests no engine can pass as written: they time out in Chrome, Firefox and
    # Safari (wpt.fyi 2026-09-30) because of the test, not a missing feature.
    # Each has an upstream issue; re-include when it is fixed and the WPT
    # snapshot has the fix.
    ('html/browsers/history/the-history-interface/traverse_the_history_1.html',
     'never completes: start_test_wait() has no caller in the automated test - wpt#63098'),
    ('html/browsers/history/the-history-interface/traverse_the_history_write_after_load_1.html',
     'never completes (start_test_wait), and expects document.open() to add a history entry, removed by whatwg/html#3946 - wpt#63098'),
    ('html/browsers/history/the-history-interface/joint_session_history/002.html',
     'expects document.open() to add a history entry and fire pageshow, removed by whatwg/html#3946 - wpt#63099'),
    ('html/browsers/history/the-location-interface/location_replace_session_history.html',
     'only completes if an iframe document is restored from session history without reloading (optional bfcache; times out in Servo too) - wpt#63100'),
    # Its abort-reason case waits for the service worker to see the page's
    # abort while its respondWith() promise is pending, and that promise
    # resolves only in the abort listener. ServiceWorker "Handle Fetch" waits
    # for respondWith (step 16) before it signals abort (step 20), so the case
    # deadlocks by the spec itself: Chrome, Firefox and Safari all time out
    # (wpt.fyi df642c4142; Firefox's meta marks it expected TIMEOUT). The
    # ordering is open upstream as w3c/ServiceWorker#1544 (since 2020). The
    # user's call for 0.1 (2026-10-17): exclude; re-include when #1544 is
    # resolved and the test follows it.
    ('fetch/api/abort/serviceworker-intercepted.https.html',
     'abort reason during a pending respondWith: deadlocks by the spec step order in every browser - w3c/ServiceWorker#1544'),

    # Inside the tier 1 and tier 2 suites: what needs layout, a feature excluded
    # elsewhere, or a human.
    ('shadow-dom/focus/',            'focus traversal needs layout (as html/interaction/)'),
    ('shadow-dom/focus-navigation/', 'focus navigation needs layout'),
    ('selection/caret/',             'caret position needs layout'),
    ('selection/bidi/',              'bidi selection needs layout'),
    ('wasm/proposals/',              'WebAssembly proposals, not shipping'),
    ('content-security-policy/webrtc/', 'WebRTC is out of scope'),
    ('content-security-policy/xslt/',   'XSLT is out of scope (as dom/xslt/)'),
    ('content-security-policy/plugin-types/', 'plugins do not exist'),
    ('workers/non-automated/',       'requires a human'),

    # Geometry (the user, 2026-10-16): Crane builds a style system - cascade and
    # computed style - and no layout, so a file that can pass only with boxes is
    # out: it reads a scroll position, measures a box (offset*), hit-tests a
    # point or drags a pointer across text, or loads lazily by viewport. Listed
    # file by file, each confirmed from its FAILING subtests (generation 148's
    # failure messages and the assertions they come from), not from the file
    # merely mentioning scrollY. A file that fails for a functional reason stays,
    # even when it also reads geometry: where every box is 0 its geometry
    # assertions compare equal (the customizable-select Home/End and arrow-key
    # files), or its subject is not a box (ShadowRoot elementFromPoint with
    # negative coordinates; autofocus before the resize steps).
    ('FileAPI/url/url-in-tags.window.js',
     'reads a scroll position, needs layout'),
    ('html/browsers/browsing-the-web/history-traversal/persisted-user-state-restoration/scroll-restoration-fragment-scrolling-cross-origin.html',
     'reads a scroll position, needs layout'),
    ('html/browsers/browsing-the-web/history-traversal/persisted-user-state-restoration/scroll-restoration-fragment-scrolling-samedoc.html',
     'reads a scroll position, needs layout'),
    ('html/browsers/browsing-the-web/history-traversal/persisted-user-state-restoration/scroll-restoration-navigation-samedoc.html',
     'reads a scroll position, needs layout'),
    ('html/browsers/browsing-the-web/history-traversal/scroll-restoration-order.html',
     'reads a scroll position, needs layout'),
    ('html/browsers/history/the-location-interface/same-hash.html',
     'reads a scroll position, needs layout'),
    ('html/semantics/forms/the-input-element/radio-focused-and-scrolled-into-view.html',
     'reads a scroll position, needs layout'),
    ('html/semantics/forms/the-select-element/select-multiple-resize-does-not-autoscroll.html',
     'reads a scroll position, needs layout'),
    ('html/webappapis/scripting/event-loops/new-scroll-event-dispatched-at-next-updating-rendering-time.html',
     'reads a scroll position, needs layout'),
    ('navigation-api/scroll-behavior/after-transition-basic.html',
     'reads a scroll position, needs layout'),
    ('navigation-api/scroll-behavior/after-transition-change-history-scroll-restoration-during-promise.html',
     'reads a scroll position, needs layout'),
    ('navigation-api/scroll-behavior/after-transition-explicit-scroll.html',
     'reads a scroll position, needs layout'),
    ('navigation-api/scroll-behavior/after-transition-push.html',
     'reads a scroll position, needs layout'),
    ('navigation-api/scroll-behavior/after-transition-reject.html',
     'reads a scroll position, needs layout'),
    ('navigation-api/scroll-behavior/after-transition-reload-no-scroll-anchoring.html',
     'reads a scroll position, needs layout'),
    ('navigation-api/scroll-behavior/after-transition-reload.html',
     'reads a scroll position, needs layout'),
    ('navigation-api/scroll-behavior/after-transition-replace.html',
     'reads a scroll position, needs layout'),
    ('navigation-api/scroll-behavior/after-transition-skips-restore-when-scrolled.html',
     'reads a scroll position, needs layout'),
    ('navigation-api/scroll-behavior/after-transition-timing.html',
     'reads a scroll position, needs layout'),
    ('navigation-api/scroll-behavior/manual-basic.html',
     'reads a scroll position, needs layout'),
    ('navigation-api/scroll-behavior/manual-immediate-scroll.html',
     'reads a scroll position, needs layout'),
    ('navigation-api/scroll-behavior/manual-scroll-after-dispatch.html',
     'reads a scroll position, needs layout'),
    ('navigation-api/scroll-behavior/manual-scroll-after-resolve.html',
     'reads a scroll position, needs layout'),
    ('navigation-api/scroll-behavior/manual-scroll-fragment-does-not-exist.html',
     'reads a scroll position, needs layout'),
    ('navigation-api/scroll-behavior/manual-scroll-in-precommit-handler.html',
     'reads a scroll position, needs layout'),
    ('navigation-api/scroll-behavior/manual-scroll-push.html',
     'reads a scroll position, needs layout'),
    ('navigation-api/scroll-behavior/manual-scroll-reload-no-scroll-anchoring.html',
     'reads a scroll position, needs layout'),
    ('navigation-api/scroll-behavior/manual-scroll-reload.html',
     'reads a scroll position, needs layout'),
    ('navigation-api/scroll-behavior/manual-scroll-repeated.html',
     'reads a scroll position, needs layout'),
    ('navigation-api/scroll-behavior/manual-scroll-replace.html',
     'reads a scroll position, needs layout'),
    ('navigation-api/scroll-behavior/manual-scroll-resets-when-no-fragment.html',
     'reads a scroll position, needs layout'),
    ('shadow-dom/scroll-restore-shadow.html',
     'reads a scroll position, needs layout'),
    ('html/dom/elements/global-attributes/the-lang-attribute-001.html',
     'measures a box (offset*), needs layout'),
    ('html/dom/elements/global-attributes/the-lang-attribute-002.html',
     'measures a box (offset*), needs layout'),
    ('html/dom/elements/global-attributes/the-lang-attribute-003.html',
     'measures a box (offset*), needs layout'),
    ('html/dom/elements/global-attributes/the-lang-attribute-004.html',
     'measures a box (offset*), needs layout'),
    ('html/dom/elements/global-attributes/the-lang-attribute-005.html',
     'measures a box (offset*), needs layout'),
    ('html/dom/elements/global-attributes/the-lang-attribute-006.html',
     'measures a box (offset*), needs layout'),
    ('html/dom/elements/global-attributes/the-lang-attribute-007.html',
     'measures a box (offset*), needs layout'),
    ('html/dom/elements/global-attributes/the-lang-attribute-008.html',
     'measures a box (offset*), needs layout'),
    ('html/dom/elements/global-attributes/the-lang-attribute-009.html',
     'measures a box (offset*), needs layout'),
    ('html/dom/elements/global-attributes/the-lang-attribute-010.html',
     'measures a box (offset*), needs layout'),
    ('html/dom/elements/global-attributes/the-lang-attribute-011.html',
     'measures a box (offset*), needs layout'),
    ('html/semantics/document-metadata/the-meta-element/the-lang-attribute-012.html',
     'measures a box (offset*), needs layout'),
    ('html/semantics/forms/the-fieldset-element/fieldset-intrinsic-size.html',
     'measures a box (offset*), needs layout'),
    ('html/semantics/forms/the-select-element/customizable-select/select-accessibility-minimum-target-size.html',
     'measures a box (offset*), needs layout'),
    ('html/syntax/parsing-html-fragments/the-input-byte-stream-001.html',
     'measures a box (offset*), needs layout'),
    ('html/syntax/parsing-html-fragments/the-input-byte-stream-007.html',
     'measures a box (offset*), needs layout'),
    ('html/syntax/parsing-html-fragments/the-input-byte-stream-009.html',
     'measures a box (offset*), needs layout'),
    ('html/syntax/parsing-html-fragments/the-input-byte-stream-016.html',
     'measures a box (offset*), needs layout'),
    ('html/syntax/parsing-html-fragments/the-input-byte-stream-018.html',
     'measures a box (offset*), needs layout'),
    ('html/syntax/parsing-html-fragments/the-input-byte-stream-030.html',
     'measures a box (offset*), needs layout'),
    ('html/syntax/parsing-html-fragments/the-input-byte-stream-034.html',
     'measures a box (offset*), needs layout'),
    ('html/syntax/parsing-html-fragments/the-input-byte-stream-037.html',
     'measures a box (offset*), needs layout'),
    ('html/syntax/parsing-html-fragments/the-input-byte-stream-038.html',
     'measures a box (offset*), needs layout'),
    ('shadow-dom/imperative-slot-initial-fallback.html',
     'measures a box (offset*), needs layout'),
    ('shadow-dom/offsetTop-offsetLeft-across-shadow-boundaries.html',
     'measures a box (offset*), needs layout'),
    ('shadow-dom/untriaged/styles/test-001.html',
     'measures a box (offset*), needs layout'),
    ('shadow-dom/untriaged/styles/test-005.html',
     'measures a box (offset*), needs layout'),
    ('shadow-dom/untriaged/styles/test-008.html',
     'measures a box (offset*), needs layout'),
    ('html/semantics/forms/the-select-element/customizable-select/selectedcontent-list-box-pick.html',
     'hit-tests a point or drags a pointer across text, needs layout'),
    ('selection/anchor-removal.html',
     'hit-tests a point or drags a pointer across text, needs layout'),
    ('selection/canvas-drag.html',
     'hit-tests a point or drags a pointer across text, needs layout'),
    ('selection/drag-disabled-textarea-shadow-dom.html',
     'hit-tests a point or drags a pointer across text, needs layout'),
    ('selection/drag-out-of-floated-content.html',
     'hit-tests a point or drags a pointer across text, needs layout'),
    ('selection/drag-selection-contenteditable-to-out-of-flow-user-select-none.html',
     'hit-tests a point or drags a pointer across text, needs layout'),
    ('selection/drag-selection-extend-to-user-select-none.html',
     'hit-tests a point or drags a pointer across text, needs layout'),
    ('selection/extend-selection-in-shadow-tree.html',
     'hit-tests a point or drags a pointer across text, needs layout'),
    ('shadow-dom/DocumentOrShadowRoot-prototype-elementFromPoint.html',
     'hit-tests a point or drags a pointer across text, needs layout'),
    ('shadow-dom/MouseEvent-prototype-offsetX-offsetY.html',
     'hit-tests a point or drags a pointer across text, needs layout'),
    ('shadow-dom/execcommand-insertList-in-shadow.html',
     'hit-tests a point or drags a pointer across text, needs layout'),
    ('shadow-dom/wheel-event-related-target.html',
     'hit-tests a point or drags a pointer across text, needs layout'),
    ('xhr/formdata/constructor-submitter-coordinate.html',
     'hit-tests a point or drags a pointer across text, needs layout'),
    ('html/semantics/embedded-content/the-iframe-element/cross-site/iframe-loading-lazy-multiple-queued-navigations-cross-site.sub.html',
     'lazy loading by viewport, needs layout'),
    ('html/semantics/embedded-content/the-iframe-element/iframe-loading-lazy-base-url-2.html',
     'lazy loading by viewport, needs layout'),
    ('html/semantics/embedded-content/the-iframe-element/iframe-loading-lazy-base-url.html',
     'lazy loading by viewport, needs layout'),
    ('html/semantics/embedded-content/the-iframe-element/iframe-loading-lazy-multiple-queued-navigations.html',
     'lazy loading by viewport, needs layout'),
    ('html/semantics/embedded-content/the-iframe-element/iframe-loading-lazy-multiple-times.html',
     'lazy loading by viewport, needs layout'),

    # Found after the geometry pass (Codex row 62, 2026-10-17): every one of its
    # 330 subtests (six variants x 55) fails with "unsupported operation:
    # Crane has no layout: a pointer moves onto an element origin only" - the
    # test drives clicks by viewport point (test_driver Actions), which needs
    # boxes. Chrome, Firefox and Safari pass each variant 55/55.
    ('html/semantics/the-button-element/command-and-commandfor/invalid-element-types.html',
     'hit-tests a point (pointer actions at viewport coordinates), needs layout'),
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
            # [hash, [url, extras], [url, extras], ...]: the first element is
            # the file's hash, not a URL.
            yield '/'.join(path), len(value) - 1


def excluded(path):
    for pattern, _ in EXCLUDE:
        if pattern in path or path.startswith(pattern.lstrip('/')):
            return True
    return False


def main():
    # Both default to this checkout. --manifest lets the worklist be generated
    # against a WPT tree that is not tests/wpt yet (a rebuilt snapshot before
    # its cut-over); --worklist writes somewhere other than the checked-in file.
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--manifest', default=MANIFEST,
                        help='MANIFEST.json to read (default: tests/wpt/MANIFEST.json)')
    parser.add_argument('--worklist', default=WORKLIST,
                        help='worklist to write (default: tests/wpt_0_1_worklist.txt)')
    args = parser.parse_args()
    manifest, worklist = args.manifest, args.worklist

    if not os.path.exists(manifest):
        sys.exit(f"manifest not found: {manifest}\n"
                 "The tests/wpt submodule may not be checked out.")

    items = list(walk(json.load(open(manifest))['items']['testharness']))

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

    with open(worklist, 'w') as f:
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
    print(f"\nwritten: {os.path.relpath(worklist, REPO)}")


if __name__ == '__main__':
    main()
