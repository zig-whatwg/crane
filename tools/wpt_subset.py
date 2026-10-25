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

Scope decisions this encodes (updated 2026-10-22):
  * Headless. No iOS build. WPT compliance gates the iOS move.
  * A file blocks when its harness is not OK or its nonempty subtest set has
    no passes (tools/wpt_progress.py gate_status).
  * Style parsing, cascade, computed values and CSSOM are in scope. Layout,
    paint and hardware APIs are out. Geometry-only files are excluded below.
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
    # Tentative-named files inside approved groups d, f and e: NOT included
    # (the user, 2026-10-22: tentative tests wait until a spec settles or a
    # browser ships the feature, like group a). The two blanket tentative
    # exclusions below apply to them.

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
    ('html/the-xhtml-syntax/', 'XHTML parsing and named character references; XML-format sources await runner support'),
    ('html/interaction/focus/', 'logical focus, autofocus and sequential DOM navigation; geometry exceptions below'),
    ('html/semantics/interactive-elements/', 'dialog, details and summary DOM behavior, excluding geometry'),

    # --- Accessibility and MathML DOM (rows 111/112, 2026-10-21). ------------
    ('accname/',              'accessible-name computation from DOM and style'),
    ('html-aam/',             'HTML accessible names and semantic roles'),
    ('wai-aria/',             'ARIA reflection, roles and accessibility tree properties'),
    ('mathml/relations/html5-tree/', 'MathML DOM integration, focus, hyperlinks and attributes; no MathML layout'),
    ('svg/struct/scripted/autofocus-attribute.svg', 'SVG autofocus candidate from row 111; XML-format runner pending row 113'),

    # --- Style system, not box construction (the user, 2026-10-20). ---------
    ('css/css-syntax/',       'CSS tokenization and declaration/rule parsing'),
    ('css/cssom/',            'CSSOM rules, stylesheets and resolved style; geometry exceptions below'),
    ('css/selectors/',        'selector syntax, matching and style invalidation; geometry exceptions below'),
    ('css/compositing/parsing/', 'compositing property syntax and computed values, not compositing pixels'),
    ('css/css-align/parsing/', 'alignment property syntax and computed values, not alignment layout'),
    ('css/css-anchor-position/parsing/', 'anchor property syntax and computed values, not anchor geometry'),
    ('css/css-animations/parsing/', 'animation property syntax and computed values'),
    ('css/css-backgrounds/parsing/', 'background property syntax and computed values, not painting'),
    ('css/css-box/parsing/', 'box property syntax and computed values'),
    ('css/css-break/parsing/', 'fragmentation property syntax and computed values, not pagination'),
    ('css/css-cascade/parsing/', 'cascade property syntax'),
    ('css/css-color-adjust/parsing/', 'color adjustment property syntax and computed values'),
    ('css/css-color/parsing/', 'color parsing, computation and serialization'),
    ('css/css-contain/content-visibility/parsing/', 'content-visibility property syntax and computed values'),
    ('css/css-contain/parsing/', 'containment property syntax and computed values, not layout'),
    ('css/css-content/parsing/', 'generated-content property syntax and computed values'),
    ('css/css-display/parsing/', 'display property syntax and computed values, not box generation'),
    ('css/css-flexbox/parsing/', 'flex property syntax and computed values, not flex layout'),
    ('css/css-flexbox/getcomputedstyle/', 'flex computed keywords, factors and percentages without laying out flex items'),
    ('css/css-fonts/parsing/', 'font property syntax and computed values, not glyph metrics'),
    ('css/css-forced-color-adjust/parsing/', 'forced color property syntax and computed values'),
    ('css/css-forms/parsing/', 'form appearance property syntax and computed values'),
    ('css/css-gaps/parsing/', 'gap property syntax and computed values, not layout'),
    ('css/css-grid/parsing/', 'grid property syntax and computed values, not grid layout'),
    ('css/css-images/parsing/', 'image value syntax and serialization, not decoding or painting'),
    ('css/css-inline/parsing/', 'inline property syntax and computed values, not line boxes'),
    ('css/css-inline/text-box-trim/parsing/', 'text-box property syntax and computed values, not font metrics'),
    ('css/css-lists/parsing/', 'list property syntax and computed values, not marker painting'),
    ('css/css-logical/parsing/', 'logical property syntax and computed values'),
    ('css/css-masking/parsing/', 'mask property syntax and computed values, not masking pixels'),
    ('css/css-multicol/parsing/', 'column property syntax and computed values, not multicolumn layout'),
    ('css/css-overflow/parsing/', 'overflow property syntax and computed values, not scrolling'),
    ('css/css-overscroll-behavior/parsing/', 'overscroll property syntax and computed values'),
    ('css/css-page/parsing/', 'page descriptor syntax and computed values, not printing'),
    ('css/css-paint-api/parsing/', 'paint() value parsing, not paint worklet execution'),
    ('css/css-position/parsing/', 'position property syntax and computed values, not box coordinates'),
    ('css/css-pseudo/parsing/', 'pseudo-element property syntax and computed values'),
    ('css/css-rhythm/parsing/', 'rhythm property syntax and computed values, not line layout'),
    ('css/css-ruby/parsing/', 'ruby property syntax and computed values, not ruby layout'),
    ('css/css-scroll-anchoring/parsing/', 'scroll anchoring property syntax and computed values'),
    ('css/css-scroll-snap/parsing/', 'scroll snap property syntax and computed values, not scroll behavior'),
    ('css/css-scroll-snap/scroll-initial-target/parsing/', 'scroll-initial-target property syntax and computed values'),
    ('css/css-shapes/parsing/', 'shape value syntax and computed values, not shape geometry'),
    ('css/css-size-adjust/parsing/', 'text size adjustment property syntax and computed values'),
    ('css/css-sizing/aspect-ratio/parsing/', 'aspect-ratio property syntax and computed values, not sizing'),
    ('css/css-sizing/contain-intrinsic-size/parsing/', 'intrinsic-size property syntax and computed values'),
    ('css/css-sizing/parsing/', 'sizing property syntax and computed values'),
    ('css/css-sizing/responsive-iframe/parsing/', 'responsive-iframe property syntax and computed values'),
    ('css/css-tables/parsing/', 'table property syntax and computed values, not table layout'),
    ('css/css-text-decor/parsing/', 'text decoration property syntax and computed values'),
    ('css/css-text-decor/text-shadow/parsing/', 'text-shadow syntax and computed values'),
    ('css/css-text/parsing/', 'text property syntax and computed values, not shaping'),
    ('css/css-transforms/parsing/', 'transform property syntax and computed values'),
    ('css/css-transitions/parsing/', 'transition property syntax and computed values'),
    ('css/css-typed-om/the-stylepropertymap/computed/', 'typed computed style values, not box geometry'),
    ('css/css-ui/parsing/', 'UI property syntax and computed values, not native widgets'),
    ('css/css-view-transitions/parsing/', 'view transition property syntax and computed values, not screenshots'),
    ('css/css-viewport/zoom/parsing/', 'zoom property syntax and computed values, not zoomed geometry'),
    ('css/css-will-change/parsing/', 'will-change property syntax and computed values'),
    ('css/css-writing-modes/parsing/', 'writing mode property syntax and computed values, not text layout'),
    ('css/cssom-view/parsing/', 'CSSOM View property syntax and computed values, not geometry APIs'),
    ('css/filter-effects/parsing/', 'filter value syntax and computed values, not pixel filters'),
    ('css/motion/parsing/', 'motion path syntax and computed values, not motion geometry'),
    ('css/css-color/computed-color.html', 'computed color serialization'),
    ('css/css-easing/timing-functions-syntax-computed.html', 'computed easing function syntax'),
    ('css/css-images/cross-fade-computed-value.html', 'computed cross-fade image serialization'),
    ('css/css-images/image-set/image-set-computed.sub.html', 'computed image-set URLs and resolution serialization'),
    ('css/css-images/image-orientation/image-orientation-from-image-computed-style.html', 'image-orientation computed keyword'),
    ('css/css-images/image-orientation/image-orientation-none-computed-style.html', 'image-orientation computed keyword'),
    # CSS Variables and the Properties and Values API, whole directories (the
    # user, 2026-10-25, lane vars1): every testharness file except the
    # geometry-dependent ones excluded below. Animation and transition files
    # are in: their offset* reads are bare style flushes, not assertions.
    ('css/css-variables/', 'custom properties, var() substitution, cycles and CSSOM serialization'),
    ('css/css-properties-values-api/', 'registered custom properties: @property, registerProperty, typed computation'),
    # The user, 2026-10-25: typed attr() files for Codex row 122's attr() work.
    # Not attr-invalidation-after-view-transition.html or the four
    # attr-security-animation/transition files: they need view transitions
    # or an animation engine, which the user deferred.
    ('css/css-values/attr-IACVT.html', 'typed attr() substitution, its taint and invalidation (row 122)'),
    ('css/css-values/attr-all-types.html', 'typed attr() substitution, its taint and invalidation (row 122)'),
    ('css/css-values/attr-argument-grammar.html', 'typed attr() substitution, its taint and invalidation (row 122)'),
    ('css/css-values/attr-container-style-query.html', 'typed attr() substitution, its taint and invalidation (row 122)'),
    ('css/css-values/attr-css-wide-keywords.html', 'typed attr() substitution, its taint and invalidation (row 122)'),
    ('css/css-values/attr-cycle.html', 'typed attr() substitution, its taint and invalidation (row 122)'),
    ('css/css-values/attr-invalidation-after-stylesheet-change.html', 'typed attr() substitution, its taint and invalidation (row 122)'),
    ('css/css-values/attr-invalidation.html', 'typed attr() substitution, its taint and invalidation (row 122)'),
    ('css/css-values/attr-length-specified.html', 'typed attr() substitution, its taint and invalidation (row 122)'),
    ('css/css-values/attr-null-namespace.xhtml', 'typed attr() substitution, its taint and invalidation (row 122)'),
    ('css/css-values/attr-pseudo-elem-invalidation-2.html', 'typed attr() substitution, its taint and invalidation (row 122)'),
    ('css/css-values/attr-pseudo-elem-invalidation.html', 'typed attr() substitution, its taint and invalidation (row 122)'),
    ('css/css-values/attr-pseudo-element-originating.html', 'typed attr() substitution, its taint and invalidation (row 122)'),
    ('css/css-values/attr-revert-rule.html', 'typed attr() substitution, its taint and invalidation (row 122)'),
    ('css/css-values/attr-security-if.html', 'typed attr() substitution, its taint and invalidation (row 122)'),
    ('css/css-values/attr-security.html', 'typed attr() substitution, its taint and invalidation (row 122)'),
    ('css/css-values/attr-universal-selector.html', 'typed attr() substitution, its taint and invalidation (row 122)'),
    ('css/css-values/acos-asin-atan-atan2-computed.html', 'inverse trigonometric CSS value computation'),
    ('css/css-values/calc-infinity-nan-computed.html', 'CSS numeric infinity and NaN computation'),
    ('css/css-values/clamp-color-computed.html', 'clamping computed color channels'),
    ('css/css-values/clamp-integer-computed.html', 'clamping computed integer values'),
    ('css/css-values/clamp-length-computed.html', 'computed length math before percentage resolution'),
    ('css/css-values/hypot-pow-sqrt-computed.html', 'CSS numeric math function computation'),
    ('css/css-values/ident-function-computed.html', 'computed custom identifier construction'),
    ('css/css-values/minmax-angle-computed.html', 'computed min/max angles'),
    ('css/css-values/minmax-integer-computed.html', 'computed min/max integers'),
    ('css/css-values/minmax-length-computed.html', 'computed min/max absolute and font-relative lengths'),
    ('css/css-values/minmax-number-computed.html', 'computed min/max numbers'),
    ('css/css-values/minmax-time-computed.html', 'computed min/max time values'),
    ('css/css-values/progress-computed.html', 'computed numeric progress ratios'),
    ('css/css-values/random-item-computed.html', 'computed random item substitution and value-sharing semantics'),
    ('css/css-values/round-mod-rem-computed.html', 'computed rounding, modulus and remainder'),
    ('css/css-values/signs-abs-computed.html', 'computed signs and absolute values'),
    ('css/css-values/sin-cos-tan-computed.html', 'computed trigonometric functions'),
    ('css/css-values/calc-size/interpolate-size-computed.html', 'computed interpolate-size keyword'),
    ('css/css-values/urls/url-request-modifiers-computed.sub.html', 'computed URL request modifier serialization'),
    # minmax-percentage-computed and minmax-length-percent-computed use
    # test_math_used's margin-left and require containing-block width. They
    # are deliberately outside these computation-only file entries.

    # --- CSS outside parsing directories (proposal group f, row 114 Q10). --
    # Reviewed by assertions and helpers, not inferred from file names.
    # Mixed files retain functional assertions; geometry cases are listed
    # separately in the proposal evidence. No layout worklets or pixels.
    ('css/CSS2/floats/computed-float-position-absolute.html', 'CSS2 computed style and inheritance; no rendered box assertions'),
    ('css/compositing/mix-blend-mode/mix-blend-mode-parsing.html', 'compositing syntax and value parsing outside the parsing directory'),
    ('css/css-align/content-distribution/parse-align-content-001.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/content-distribution/parse-align-content-002.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/content-distribution/parse-align-content-003.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/content-distribution/parse-align-content-004.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/content-distribution/parse-align-content-005.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/content-distribution/parse-justify-content-001.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/content-distribution/parse-justify-content-002.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/content-distribution/parse-justify-content-003.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/content-distribution/parse-justify-content-004.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/content-distribution/parse-justify-content-005.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/default-alignment/parse-align-items-001.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/default-alignment/parse-align-items-002.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/default-alignment/parse-align-items-003.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/default-alignment/parse-align-items-004.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/default-alignment/parse-align-items-005.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/default-alignment/parse-justify-items-001.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/default-alignment/parse-justify-items-002.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/default-alignment/parse-justify-items-003.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/default-alignment/parse-justify-items-004.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/default-alignment/parse-justify-items-005.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/default-alignment/parse-justify-items-006.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/default-alignment/shorthand-serialization-001.html', 'align value or rule serialization; no rendered boxes'),
    ('css/css-align/flow-start-and-end-serialization.html', 'align value or rule serialization; no rendered boxes'),
    ('css/css-align/gaps/column-gap-parsing-001.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/gaps/gap-normal-computed-001.html', 'align computed style and inheritance; no rendered box assertions'),
    ('css/css-align/gaps/gap-parsing-001.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/gaps/gap-parsing-002.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/gaps/grid-column-gap-parsing-001.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/gaps/grid-gap-parsing-001.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/gaps/grid-row-gap-parsing-001.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/gaps/row-gap-parsing-001.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/self-alignment/parse-align-self-001.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/self-alignment/parse-align-self-002.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/self-alignment/parse-align-self-003.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/self-alignment/parse-align-self-004.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/self-alignment/parse-align-self-005.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/self-alignment/parse-justify-self-001.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/self-alignment/parse-justify-self-002.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/self-alignment/parse-justify-self-003.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/self-alignment/parse-justify-self-004.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-align/self-alignment/parse-justify-self-005.html', 'align syntax and value parsing outside the parsing directory'),
    ('css/css-anchor-position/anchor-parse-invalid.html', 'anchor position syntax and value parsing outside the parsing directory'),
    ('css/css-anchor-position/anchor-parse-valid.html', 'anchor position syntax and value parsing outside the parsing directory'),
    ('css/css-anchor-position/anchor-size-parse-invalid.html', 'anchor position syntax and value parsing outside the parsing directory'),
    ('css/css-anchor-position/anchor-size-parse-valid.html', 'anchor position syntax and value parsing outside the parsing directory'),
    ('css/css-anchor-position/at-position-try-parse.html', 'anchor position style value object and CSSOM behavior'),
    ('css/css-anchor-position/container-queries/at-container-anchored-parsing-any.html', 'anchor position syntax and value parsing outside the parsing directory'),
    ('css/css-anchor-position/container-queries/at-container-anchored-parsing.html', 'anchor position syntax and value parsing outside the parsing directory'),
    ('css/css-anchor-position/container-queries/at-container-anchored-serialization.html', 'anchor position value or rule serialization; no rendered boxes'),
    ('css/css-anchor-position/container-queries/container-type-anchored-computed.html', 'anchor position computed style and inheritance; no rendered box assertions'),
    ('css/css-anchor-position/container-queries/container-type-anchored-parsing.html', 'anchor position syntax and value parsing outside the parsing directory'),
    ('css/css-anchor-position/position-area-computed-insets.html', 'anchor position computed style and inheritance; no rendered box assertions'),
    ('css/css-anchor-position/position-area-computed.html', 'anchor position computed style and inheritance; no rendered box assertions'),
    ('css/css-anchor-position/position-area-parsing.html', 'anchor position syntax and value parsing outside the parsing directory'),
    ('css/css-animations/computed-style-animation-parsing.html', 'animations syntax and value parsing outside the parsing directory'),
    ('css/css-animations/style-animation-parsing.html', 'animations syntax and value parsing outside the parsing directory'),
    ('css/css-backgrounds/border-width-computed.html', 'backgrounds computed style and inheritance; no rendered box assertions'),
    ('css/css-borders/border-shape/border-shape-ignore-radius-computed.html', 'borders computed style and inheritance; no rendered box assertions'),
    ('css/css-borders/corner-shape/corner-block-start-computed.html', 'borders computed style and inheritance; no rendered box assertions'),
    ('css/css-borders/corner-shape/corner-computed.html', 'borders computed style and inheritance; no rendered box assertions'),
    ('css/css-borders/corner-shape/corner-shape-computed.html', 'borders computed style and inheritance; no rendered box assertions'),
    ('css/css-borders/corner-shape/corner-top-computed.html', 'borders computed style and inheritance; no rendered box assertions'),
    ('css/css-borders/corner-shape/corner-top-left-computed.html', 'borders computed style and inheritance; no rendered box assertions'),
    ('css/css-box/margin-trim/margin-trim-computed-value.html', 'margin resolved values with mixed measured trimming assertions'),
    ('css/css-cascade/at-scope-parsing.html', 'cascade syntax and value parsing outside the parsing directory'),
    ('css/css-color/color-mix-currentcolor-visited-getcomputedstyle.html', 'color computed style and inheritance; no rendered box assertions'),
    ('css/css-color/relative-currentcolor-visited-getcomputedstyle.html', 'color computed style and inheritance; no rendered box assertions'),
    ('css/css-color-hdr/computed.html', 'color hdr computed style and inheritance; no rendered box assertions'),
    ('css/css-color-hdr/parsing.html', 'color hdr syntax and value parsing outside the parsing directory'),
    ('css/css-conditional/at-supports-at-rule-serialization.html', 'conditional value or rule serialization; no rendered boxes'),
    ('css/css-conditional/container-queries/at-container-parsing.html', 'conditional syntax and value parsing outside the parsing directory'),
    ('css/css-conditional/container-queries/at-container-serialization.html', 'conditional value or rule serialization; no rendered boxes'),
    ('css/css-conditional/container-queries/at-container-style-parsing.html', 'conditional syntax and value parsing outside the parsing directory'),
    ('css/css-conditional/container-queries/at-container-style-serialization.html', 'conditional value or rule serialization; no rendered boxes'),
    ('css/css-conditional/container-queries/container-computed.html', 'conditional computed style and inheritance; no rendered box assertions'),
    ('css/css-conditional/container-queries/container-name-computed.html', 'conditional computed style and inheritance; no rendered box assertions'),
    ('css/css-conditional/container-queries/container-name-parsing.html', 'conditional syntax and value parsing outside the parsing directory'),
    ('css/css-conditional/container-queries/container-parsing.html', 'conditional syntax and value parsing outside the parsing directory'),
    ('css/css-conditional/container-queries/container-type-computed.html', 'conditional computed style and inheritance; no rendered box assertions'),
    ('css/css-conditional/container-queries/container-type-parsing.html', 'conditional syntax and value parsing outside the parsing directory'),
    ('css/css-conditional/container-queries/scroll-state/at-container-scrollable-parsing.html', 'conditional syntax and value parsing outside the parsing directory'),
    ('css/css-conditional/container-queries/scroll-state/at-container-scrollable-serialization.html', 'conditional value or rule serialization; no rendered boxes'),
    ('css/css-conditional/container-queries/scroll-state/at-container-scrolled-parsing.html', 'conditional syntax and value parsing outside the parsing directory'),
    ('css/css-conditional/container-queries/scroll-state/at-container-scrolled-serialization.html', 'conditional value or rule serialization; no rendered boxes'),
    ('css/css-conditional/container-queries/scroll-state/at-container-snapped-parsing.html', 'conditional syntax and value parsing outside the parsing directory'),
    ('css/css-conditional/container-queries/scroll-state/at-container-snapped-serialization.html', 'conditional value or rule serialization; no rendered boxes'),
    ('css/css-conditional/container-queries/scroll-state/at-container-stuck-parsing.html', 'conditional syntax and value parsing outside the parsing directory'),
    ('css/css-conditional/container-queries/scroll-state/at-container-stuck-serialization.html', 'conditional value or rule serialization; no rendered boxes'),
    ('css/css-conditional/container-queries/scroll-state/container-type-scroll-state-computed.html', 'conditional computed style and inheritance; no rendered box assertions'),
    ('css/css-conditional/container-queries/scroll-state/container-type-scroll-state-parsing.html', 'conditional syntax and value parsing outside the parsing directory'),
    ('css/css-conditional/js/CSS-supports-details-content-pseudo-parsing.html', 'conditional syntax and value parsing outside the parsing directory'),
    ('css/css-contain/content-visibility/document-element-computed-style.html', 'contain computed style and inheritance; no rendered box assertions'),
    ('css/css-content/computed-value.html', 'content computed style and inheritance; no rendered box assertions'),
    ('css/css-display/display-contents-computed-style.html', 'display computed style and inheritance; no rendered box assertions'),
    ('css/css-display/display-contents-parsing-001.html', 'display syntax and value parsing outside the parsing directory'),
    ('css/css-env/env-parsing.html', 'env syntax and value parsing outside the parsing directory'),
    # The user, 2026-10-25 (lane vars1 Q5): env() substitution files, not
    # tentative and no rendered boxes.
    ('css/css-env/env-fallback-substitution.html', 'env() fallback substitution in custom properties; computed values only'),
    ('css/css-env/env-revert-rule.html', 'env() fallback CSS-wide keyword after substitution; computed values only'),
    ('css/css-flexbox/balance/flex-line-count-computed.html', 'flexbox computed style and inheritance; no rendered box assertions'),
    ('css/css-flexbox/balance/flex-wrap-computed.html', 'flexbox computed style and inheritance; no rendered box assertions'),
    ('css/css-fonts/font-feature-settings-serialization-001.html', 'fonts value or rule serialization; no rendered boxes'),
    ('css/css-fonts/font-shorthand-serialization-001.html', 'fonts value or rule serialization; no rendered boxes'),
    ('css/css-fonts/font-shorthand-serialization-font-stretch.html', 'fonts value or rule serialization; no rendered boxes'),
    ('css/css-fonts/font-shorthand-serialization-prevention.html', 'fonts value or rule serialization; no rendered boxes'),
    ('css/css-fonts/font-size-computed-keyword.html', 'fonts computed style and inheritance; no rendered box assertions'),
    ('css/css-fonts/font-size-computed-no-child.html', 'fonts computed style and inheritance; no rendered box assertions'),
    ('css/css-fonts/font-size-computed.html', 'font-size computation and inheritance, with one mixed used percentage-width case'),
    ('css/css-fonts/font-variant-alternates-parsing.html', 'fonts syntax and value parsing outside the parsing directory'),
    ('css/css-fonts/font-variation-settings-serialization-001.html', 'fonts value or rule serialization; no rendered boxes'),
    ('css/css-fonts/font-variation-settings-serialization-002.html', 'fonts value or rule serialization; no rendered boxes'),
    ('css/css-fonts/test_font_family_parsing.html', 'fonts syntax and value parsing outside the parsing directory'),
    ('css/css-fonts/test_font_feature_values_parsing.html', 'fonts syntax and value parsing outside the parsing directory'),
    ('css/css-fonts/variations/font-parse-numeric-stretch-style-weight.html', 'fonts syntax and value parsing outside the parsing directory'),
    ('css/css-fonts/variations/font-style-parsing.html', 'fonts syntax and value parsing outside the parsing directory'),
    ('css/css-fonts/variations/font-weight-parsing.html', 'fonts syntax and value parsing outside the parsing directory'),
    ('css/css-forms/input-file-base-appearance-computed.html', 'forms computed style and inheritance; no rendered box assertions'),
    ('css/css-forms/input-text-base-appearance-computed-style.html', 'forms computed style and inheritance; no rendered box assertions'),
    ('css/css-grid/computed-grid-column.html', 'grid computed style and inheritance; no rendered box assertions'),
    ('css/css-grid/grid-lanes/grid-lanes-grid-template-columns-computed-withcontent.html', 'grid-lanes track serialization with mixed used-track geometry assertions'),
    ('css/css-grid/grid-model/grid-computed-value-display-floated-items-001.html', 'grid computed style and inheritance; no rendered box assertions'),
    ('css/css-grid/subgrid/grid-template-computed-invalid-subgrid.html', 'grid computed style and inheritance; no rendered box assertions'),
    ('css/css-grid/subgrid/grid-template-computed-nogrid.html', 'grid computed style and inheritance; no rendered box assertions'),
    ('css/css-highlight-api/highlight-pseudo-computed.html', 'highlight api computed style and inheritance; no rendered box assertions'),
    ('css/css-highlight-api/highlight-pseudo-from-font-computed.html', 'highlight api computed style and inheritance; no rendered box assertions'),
    ('css/css-highlight-api/highlight-pseudo-parsing.html', 'highlight api syntax and value parsing outside the parsing directory'),
    ('css/css-images/gradient/color-stops-parsing.html', 'images syntax and value parsing outside the parsing directory'),
    ('css/css-images/image-set/image-set-parsing.html', 'images syntax and value parsing outside the parsing directory'),
    ('css/css-images/object-view-box-parsing.html', 'images syntax and value parsing outside the parsing directory'),
    ('css/css-inline/baseline-source/baseline-source-computed.html', 'inline computed style and inheritance; no rendered box assertions'),
    ('css/css-inline/initial-letter/initial-letter-computed.html', 'inline computed style and inheritance; no rendered box assertions'),
    ('css/css-layout-api/computed-style-layout-function.https.html', 'layout() display value parsing and serialization; no layout worklet executes'),
    ('css/css-link-params/link-parameters-computed.html', 'link params computed style and inheritance; no rendered box assertions'),
    ('css/css-lists/li-counter-increment-computed-style.html', 'lists computed style and inheritance; no rendered box assertions'),
    ('css/css-mixins/functions/at-function-parsing.html', 'mixins syntax and value parsing outside the parsing directory'),
    ('css/css-mixins/functions/dashed-function-parsing.html', 'mixins syntax and value parsing outside the parsing directory'),
    ('css/css-mixins/mixins/mixin-parsing.html', 'mixins syntax and value parsing outside the parsing directory'),
    ('css/css-multicol/zero-column-width-computed-style.html', 'multicol computed style and inheritance; no rendered box assertions'),
    ('css/css-nesting/parsing.html', 'nesting syntax and value parsing outside the parsing directory'),
    ('css/css-overflow/column-creates-computed-style.html', 'overflow computed style and inheritance; no rendered box assertions'),
    ('css/css-overflow/column-updates-computed-style.html', 'overflow computed style and inheritance; no rendered box assertions'),
    ('css/css-parser-api/idlharness.html', 'CSS Parser API IDL shape; WICG draft and shipping status flagged for approval'),
    ('css/css-position/backdrop-inherit-computed.html', 'position computed style and inheritance; no rendered box assertions'),
    ('css/css-position/overlay/overlay-computed.html', 'position computed style and inheritance; no rendered box assertions'),
    ('css/css-position/sticky/position-sticky-parsing.html', 'position syntax and value parsing outside the parsing directory'),
    ('css/css-pseudo/highlight-cascade/highlight-currentcolor-computed-inheritance.html', 'pseudo computed style and inheritance; no rendered box assertions'),
    ('css/css-pseudo/highlight-cascade/highlight-currentcolor-computed-visited.html', 'pseudo computed style and inheritance; no rendered box assertions'),
    ('css/css-pseudo/highlight-cascade/highlight-currentcolor-computed.html', 'pseudo computed style and inheritance; no rendered box assertions'),
    ('css/css-pseudo/highlight-cascade/highlight-pseudos-computed.html', 'pseudo computed style and inheritance; no rendered box assertions'),
    ('css/css-pseudo/highlight-cascade/highlight-pseudos-inheritance-computed-001.html', 'pseudo computed style and inheritance; no rendered box assertions'),
    ('css/css-pseudo/highlight-cascade/highlight-pseudos-visited-computed-001.html', 'pseudo computed style and inheritance; no rendered box assertions'),
    ('css/css-pseudo/marker-computed-content.html', 'pseudo computed style and inheritance; no rendered box assertions'),
    ('css/css-pseudo/marker-display-computed.html', 'pseudo computed style and inheritance; no rendered box assertions'),
    ('css/css-pseudo/marker-variable-computed-style.html', 'pseudo computed style and inheritance; no rendered box assertions'),
    ('css/css-scrollbars/scrollbar-color-parsing.html', 'scrollbars syntax and value parsing outside the parsing directory'),
    ('css/css-scrollbars/scrollbar-width-parsing.html', 'scrollbars syntax and value parsing outside the parsing directory'),
    ('css/css-shadow/host-context-parsing.html', 'shadow syntax and value parsing outside the parsing directory'),
    ('css/css-shadow/host-parsing.html', 'shadow syntax and value parsing outside the parsing directory'),
    ('css/css-shadow/part/serialization.html', 'shadow value or rule serialization; no rendered boxes'),
    ('css/css-shadow/slotted-parsing.html', 'shadow syntax and value parsing outside the parsing directory'),
    ('css/css-shapes/basic-shape-circle-ellipse-serialization.html', 'shapes value or rule serialization; no rendered boxes'),
    ('css/css-shapes/shape-functions/circle-function-computed.html', 'shapes computed style and inheritance; no rendered box assertions'),
    ('css/css-shapes/shape-functions/ellipse-function-computed.html', 'shapes computed style and inheritance; no rendered box assertions'),
    ('css/css-shapes/shape-functions/inset-function-computed.html', 'shapes computed style and inheritance; no rendered box assertions'),
    ('css/css-shapes/shape-functions/path-function-computed-collision.html', 'shapes computed style and inheritance; no rendered box assertions'),
    ('css/css-shapes/shape-functions/path-function-computed.html', 'shapes computed style and inheritance; no rendered box assertions'),
    ('css/css-shapes/shape-functions/polygon-function-computed.html', 'shapes computed style and inheritance; no rendered box assertions'),
    ('css/css-shapes/shape-functions/polygon-function-round-computed.html', 'shapes computed style and inheritance; no rendered box assertions'),
    ('css/css-shapes/shape-functions/rect-function-computed.html', 'shapes computed style and inheritance; no rendered box assertions'),
    ('css/css-shapes/shape-functions/shape-function-computed.html', 'shapes computed style and inheritance; no rendered box assertions'),
    ('css/css-shapes/shape-functions/xywh-function-computed.html', 'shapes computed style and inheritance; no rendered box assertions'),
    ('css/css-shapes/shape-outside/values/shape-outside-computed-shape-000.html', 'shapes computed style and inheritance; no rendered box assertions'),
    ('css/css-shapes/shape-outside/values/shape-outside-computed-shape-001.html', 'shapes computed style and inheritance; no rendered box assertions'),
    ('css/css-shapes/shape-outside/values/shape-outside-gradient-computed.html', 'shapes computed style and inheritance; no rendered box assertions'),
    ('css/css-sizing/stretch/parsing.html', 'sizing syntax and value parsing outside the parsing directory'),
    ('css/css-tables/table-cell-writing-mode-computed.html', 'tables computed style and inheritance; no rendered box assertions'),
    ('css/css-tables/table-position-sticky-computed.html', 'tables computed style and inheritance; no rendered box assertions'),
    ('css/css-text/tab-size/tab-size-computed-value-001.html', 'text computed style and inheritance; no rendered box assertions'),
    ('css/css-text/word-spacing/word-spacing-computed-001.html', 'text computed style and inheritance; no rendered box assertions'),
    ('css/css-text-decor/text-decoration-thickness-computed.html', 'text decor computed style and inheritance; no rendered box assertions'),
    ('css/css-text-decor/text-underline-offset-computed.html', 'text decor computed style and inheritance; no rendered box assertions'),
    ('css/css-transforms/animation/transform-interpolation-computed-value.html', 'transforms computed style and inheritance; no rendered box assertions'),
    ('css/css-transforms/transform-and-individual-transform-properties-computed-style.html', 'transforms computed style and inheritance; no rendered box assertions'),
    ('css/css-typed-om/parse-calc-expressions.html', 'typed om syntax and value parsing outside the parsing directory'),
    ('css/css-typed-om/stylevalue-objects/parse-invalid.html', 'typed om syntax and value parsing outside the parsing directory'),
    ('css/css-typed-om/stylevalue-objects/parse.html', 'typed om syntax and value parsing outside the parsing directory'),
    ('css/css-typed-om/stylevalue-objects/parseAll-invalid.html', 'typed om syntax and value parsing outside the parsing directory'),
    ('css/css-typed-om/stylevalue-objects/parseAll.html', 'typed om syntax and value parsing outside the parsing directory'),
    ('css/css-typed-om/stylevalue-serialization/cssImageValue.html', 'typed om value or rule serialization; no rendered boxes'),
    ('css/css-typed-om/stylevalue-serialization/cssStyleValue-cssom.html', 'typed om value or rule serialization; no rendered boxes'),
    ('css/css-typed-om/stylevalue-serialization/cssStyleValue-string.html', 'typed om value or rule serialization; no rendered boxes'),
    ('css/css-typed-om/stylevalue-serialization/cssUnparsedValue.html', 'typed om value or rule serialization; no rendered boxes'),
    ('css/css-typed-om/stylevalue-subclasses/cssUnparsedValue-empty.any.js', 'typed om style value object and CSSOM behavior'),
    ('css/css-typed-om/stylevalue-subclasses/cssUnparsedValue-indexed-getter-setter.html', 'typed om style value object and CSSOM behavior'),
    ('css/css-typed-om/stylevalue-subclasses/cssUnparsedValue-iterable.html', 'typed om style value object and CSSOM behavior'),
    ('css/css-typed-om/stylevalue-subclasses/cssUnparsedValue-length.html', 'typed om style value object and CSSOM behavior'),
    ('css/css-typed-om/stylevalue-subclasses/cssUnparsedValue.html', 'typed om style value object and CSSOM behavior'),
    ('css/css-ui/accent-color-computed.html', 'ui computed style and inheritance; no rendered box assertions'),
    ('css/css-ui/accent-color-parsing.html', 'ui syntax and value parsing outside the parsing directory'),
    ('css/css-ui/animation/caret-animation-parsing.html', 'ui syntax and value parsing outside the parsing directory'),
    ('css/css-ui/appearance-parsing.html', 'ui syntax and value parsing outside the parsing directory'),
    ('css/css-ui/appearance-serialization.html', 'ui value or rule serialization; no rendered boxes'),
    ('css/css-ui/caret-shape-parsing.html', 'ui syntax and value parsing outside the parsing directory'),
    ('css/css-ui/input-security-computed.html', 'ui computed style and inheritance; no rendered box assertions'),
    ('css/css-ui/input-security-parsing.html', 'ui syntax and value parsing outside the parsing directory'),
    ('css/css-ui/webkit-appearance-parsing.html', 'ui syntax and value parsing outside the parsing directory'),
    ('css/css-ui/webkit-appearance-serialization.html', 'ui value or rule serialization; no rendered boxes'),
    ('css/css-values/attr-parse-url.html', 'values syntax and value parsing outside the parsing directory'),
    ('css/css-values/attr-serialization.html', 'values value or rule serialization; no rendered boxes'),
    ('css/css-values/calc-dimension-serialization-order.html', 'values value or rule serialization; no rendered boxes'),
    ('css/css-values/calc-invalid-parsing.html', 'values syntax and value parsing outside the parsing directory'),
    ('css/css-values/calc-serialization-002.html', 'values value or rule serialization; no rendered boxes'),
    ('css/css-values/calc-serialization.html', 'values value or rule serialization; no rendered boxes'),
    ('css/css-values/calc-size/calc-size-parsing.html', 'values syntax and value parsing outside the parsing directory'),
    ('css/css-values/calc-size/interpolate-size-parsing.html', 'values syntax and value parsing outside the parsing directory'),
    ('css/css-values/ident-function-parsing.html', 'values syntax and value parsing outside the parsing directory'),
    ('css/css-values/inherit-function-parsing.html', 'values syntax and value parsing outside the parsing directory'),
    ('css/css-values/tree-counting/calc-sibling-function-parsing.html', 'values syntax and value parsing outside the parsing directory'),
    ('css/css-values/urls/url-request-modifiers-font-face-parsing.html', 'values syntax and value parsing outside the parsing directory'),
    ('css/css-values/urls/url-request-modifiers-import-parsing.sub.html', 'values syntax and value parsing outside the parsing directory'),
    ('css/css-values/viewport-units-parsing.html', 'values syntax and value parsing outside the parsing directory'),
    ('css/css-view-transitions/computed-style-no-active-transition.html', 'view transitions computed style and inheritance; no rendered box assertions'),
    ('css/css-view-transitions/navigation/with-types/at-rule-with-types-parsing.html', 'view transitions syntax and value parsing outside the parsing directory'),
    ('css/css-view-transitions/pseudo-computed-style-stays-in-sync-with-new-element.html', 'view transitions computed style and inheritance; no rendered box assertions'),
    ('css/css-view-transitions/pseudo-get-computed-style-clean-style.html', 'view transitions computed style and inheritance; no rendered box assertions'),
    ('css/css-view-transitions/pseudo-get-computed-style-escaped-star.html', 'view transitions computed style and inheritance; no rendered box assertions'),
    ('css/css-view-transitions/pseudo-get-computed-style.html', 'view transitions computed style and inheritance; no rendered box assertions'),
    ('css/css-viewport/computedStyle-zoom.html', 'viewport computed style and inheritance; no rendered box assertions'),
    ('css/css-viewport/zoom/computed-border-width-keywords.html', 'viewport computed style and inheritance; no rendered box assertions'),
    ('css/css-viewport/zoom/computed-column-rule-width-keywords.html', 'viewport computed style and inheritance; no rendered box assertions'),
    ('css/css-viewport/zoom/computed-initial.html', 'viewport computed style and inheritance; no rendered box assertions'),
    ('css/css-viewport/zoom/computed-outline-width-keywords.html', 'viewport computed style and inheritance; no rendered box assertions'),
    ('css/css-viewport/zoom/line-height-computed.html', 'viewport computed style and inheritance; no rendered box assertions'),
    ('css/css-viewport/zoom/matrix-zoom-anim-computed.html', 'viewport computed style and inheritance; no rendered box assertions'),
    ('css/css-viewport/zoom/svg-computed-style.html', 'viewport computed style and inheritance; no rendered box assertions'),
    ('css/css-viewport/zoom/text-indent-computed.html', 'viewport computed style and inheritance; no rendered box assertions'),
    ('css/css-viewport/zoom/translate-matrix-zoom-anim-accumulated-computed.html', 'transform animation accumulation with mixed percentage-translation geometry'),
    ('css/css-viewport/zoom/word-spacing-inherited-computed.html', 'viewport computed style and inheritance; no rendered box assertions'),
    ('css/css-writing-modes/text-combine-upright-parsing-digits-001.html', 'writing modes syntax and value parsing outside the parsing directory'),
    ('css/css-writing-modes/text-combine-upright-parsing-digits-002.html', 'writing modes syntax and value parsing outside the parsing directory'),
    ('css/css-writing-modes/text-combine-upright-parsing-invalid-001.html', 'writing modes syntax and value parsing outside the parsing directory'),
    ('css/css-writing-modes/text-combine-upright-parsing-invalid-002.html', 'writing modes syntax and value parsing outside the parsing directory'),
    ('css/css-writing-modes/text-combine-upright-parsing-valid-001.html', 'writing modes syntax and value parsing outside the parsing directory'),
    ('css/css-writing-modes/text-orientation-parsing-001.html', 'writing modes syntax and value parsing outside the parsing directory'),
    ('css/css-writing-modes/text-orientation-parsing-sideways-right-001.html', 'writing modes syntax and value parsing outside the parsing directory'),
    ('css/css-writing-modes/unicode-bidi-parsing-001.html', 'writing modes syntax and value parsing outside the parsing directory'),
    ('css/css-writing-modes/unicode-bidi-parsing-002.html', 'writing modes syntax and value parsing outside the parsing directory'),
    ('css/css-writing-modes/wm-propagation-body-computed-direction-001.html', 'writing modes computed style and inheritance; no rendered box assertions'),
    ('css/css-writing-modes/wm-propagation-body-computed-direction-002.html', 'writing modes computed style and inheritance; no rendered box assertions'),
    ('css/css-writing-modes/wm-propagation-body-computed-root.html', 'writing modes computed style and inheritance; no rendered box assertions'),
    ('css/css-writing-modes/wm-propagation-body-computed-writing-mode.html', 'writing modes computed style and inheritance; no rendered box assertions'),
    ('css/css-writing-modes/writing-mode-parsing-001.html', 'writing modes syntax and value parsing outside the parsing directory'),
    ('css/css-writing-modes/writing-mode-parsing-sideways-lr-001.html', 'writing modes syntax and value parsing outside the parsing directory'),
    ('css/css-writing-modes/writing-mode-parsing-sideways-rl-001.html', 'writing modes syntax and value parsing outside the parsing directory'),
    ('css/css-writing-modes/writing-mode-parsing-svg1-001.html', 'writing modes syntax and value parsing outside the parsing directory'),
    ('css/fill-stroke/webkit-text-stroke-computed.html', 'fill stroke computed style and inheritance; no rendered box assertions'),
    ('css/geometry/structured-serialization.html', 'structured clone of geometry value objects; no measured coordinates are asserted'),
    ('css/mediaqueries/aspect-ratio-serialization.html', 'mediaqueries value or rule serialization; no rendered boxes'),
    ('css/mediaqueries/at-custom-media-parsing.html', 'mediaqueries syntax and value parsing outside the parsing directory'),
    ('css/mediaqueries/match-media-parsing.html', 'mediaqueries syntax and value parsing outside the parsing directory'),
    ('css/mediaqueries/mq-escaped-serialization.html', 'mediaqueries value or rule serialization; no rendered boxes'),

    # --- Editing and syntax quirks, without caret/box geometry. ------------
    ('editing/',              'editing commands, DOM mutations and input events; geometry exceptions below'),
    ('quirks/classname-query-after-sibling-adoption.html', 'quirks-mode class-name matching after adoption'),
    ('quirks/hashless-hex-color/', 'quirks-mode CSS color parsing'),
    ('quirks/unitless-length/', 'quirks-mode CSS length parsing'),
    ('quirks/supports.html',   'quirks-mode CSS.supports and conditional declaration parsing'),

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
    ('html/browsers/browsing-the-web/back-forward-cache/', 'history document preservation and restoration; geometry exceptions below'),
    ('html/browsers/browsing-the-web/overlapping-navigations-and-traversals/', 'ordering and cancellation of concurrent navigations'),
    ('html/cross-origin-', 'cross-origin policies, isolation and navigation; COOP/COEP implementation is separately queued'),

    # --- Networking. All of it through libcurl. ----------------------------
    ('fetch/api/',     'Fetch API; already reaches LibcurlBackend'),
    ('fetch/metadata/', 'Sec-Fetch request metadata and redirect behavior'),
    ('fetch/content-encoding/zstd/', 'HTTP Zstandard content decoding'),
    ('fetch/fetch-later/', 'deferred Fetch API; merged Fetch spec, approved by the user 2026-10-22'),
    ('xhr/',           'XMLHttpRequest; today calls simulateFetch, must route to fetch'),
    ('websockets/',    'WebSocket API; WebSocketStream remains deferred below'),
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
    ('wasm/core/',     'WebAssembly core conformance'),
    ('wasm/jsapi/',    'WebAssembly JavaScript API'),
    ('wasm/webapi/',   'WebAssembly Web API integration'),
    ('wasm/serialization/', 'WebAssembly module serialization'),
    ('wasm/create_multiple_memory.worker.js', 'WebAssembly memory creation in workers'),
    # Wide arithmetic is the explicit approved tentative entry above.
    # Other WebAssembly proposals remain outside these core/API prefixes.
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

# Substring or prefix -> why it is out. Only the two tentative rules below
# allow an exact-path INCLUDE exception; every other exclusion wins.
EXCLUDE = [
    # Group a remains deferred. Exact-path INCLUDE entries above record the
    # user's approved exceptions; they bypass only these tentative patterns.
    ('/tentative/', 'tentative features await individual scope approval'),
    ('.tentative.', 'tentative features await individual scope approval'),
    # Group e decisions, 2026-10-22: drafts/unmerged proposals are not yet in
    # the 0.1 worklist, even when one browser ships them.
    ('dom/observable/', 'WICG draft; deferred by the user 2026-10-22'),
    ('html/anonymous-iframe/', 'WICG draft; deferred by the user 2026-10-22'),
    ('html/document-isolation-policy/', 'WICG draft; deferred by the user 2026-10-22'),
    ('fetch/orb/', 'unmerged Fetch proposal; deferred by the user 2026-10-22'),
    ('websockets/stream/', 'unmerged WebSocketStream proposal; deferred by the user 2026-10-22'),

    # Anything that needs layout or paint. Crane is the web platform; the host
    # supplies pixels.
    ('html/rendering/',                         'rendering'),
    ('/canvas/',                                'graphics'),
    ('dom/events/scrolling/',                   'needs layout'),
    ('dom/events/non-cancelable-when-passive/', 'scroll/touch, needs layout'),
    ('html/browsers/browsing-the-web/scroll-to-fragid/', 'needs layout'),

    # 2026-10-21 proposal: exclude measured boxes and coordinate hit-testing,
    # not style reads used only to flush. Mixed files retain their functional
    # subtests; the proposal evidence names their layout-only subtests.
    ('accname/name/comp_name_from_content_alt_counter_invalidation.html', 'all accessible-name assertions require generated CSS counter content (row 112)'),
    ('accname/name/comp_name_from_content_alt_counter_multi_instance.html', 'all accessible-name assertions require generated CSS counter content (row 112)'),
    ('css/cssom/caretPositionFromPoint', 'asserts caret offsets from hit-tested viewport coordinates'),
    # The user, 2026-10-25: no animation engine yet (element.animate and the
    # Animation objects are stubs), so the registered-property animation and
    # transition files would block whatever is built. Out for now.
    ('css/css-properties-values-api/animation/', 'needs an animation engine, which Crane does not have yet (the user, 2026-10-25)'),
    ('css/css-variables/variable-reference-perspective-origin.html', 'every case asserts perspective-origin percentages resolved against the used 200px box'),
    ('css/css-variables/variable-animation-guaranteed-invalid.html', 'check-layout-th asserts each animated box offsetWidth (the invalid case stretches to its container)'),
    ('css/css-properties-values-api/at-property-viewport-units.html', 'asserts viewport units against the laid-out 400x200 iframe viewport'),
    ('css/css-properties-values-api/at-property-viewport-units-dynamic.html', 'asserts viewport units after resizing the laid-out iframe viewport'),
    ('css/cssom/caretRangeFromPoint', 'asserts caret ranges from hit-tested viewport coordinates'),
    ('css/cssom/computed-style-002.html', 'asserts percentage width resolved against iframe width'),
    ('css/cssom/computed-style-003.html', 'asserts percentage width after iframe display/layout changes'),
    ('css/cssom/computed-style-004.html', 'asserts percentage width after nested iframe resizing'),
    ('css/cssom/getComputedStyle-layout-dependent-', 'asserts used percentage width after inline/block box reconstruction'),
    ('css/cssom/getComputedStyle-insets-relpos-inline.html', 'asserts inset pixels resolved against inline containing-block width'),
    ('css/cssom/getComputedStyle-insets-grid.html', 'asserts auto inset pixels resolved against grid-area edges'),
    ('css/cssom/getComputedStyle-sticky-pos-percent.html', 'asserts sticky top resolves to 250px from container height'),
    ('css/cssom/getComputedStyle-dynamic-subdoc.html', 'asserts media-query color after changing the laid-out iframe viewport width'),
    ('fetch/metadata/generated/element-video-poster.', 'every case waits for rendered video clientWidth to equal the poster width'),
    ('fetch/metadata/generated/element-img-environment-change.', 'every case waits for srcset selection after changing the laid-out iframe viewport width'),
    ('css/selectors/i18n/css3-selectors-lang-', 'selector matches are asserted solely through measured offsetWidth'),
    ('css/css-grid/parsing/grid-template-columns-computed-implicit-track.html', 'all resolved track lists assert a leading implicit track sized from grid item width'),
    ('css/css-grid/parsing/grid-template-rows-computed-implicit-track.html', 'all resolved track lists assert a leading implicit track sized from grid item height'),
    ('css/css-grid/parsing/grid-template-repeat-auto-computed-withcontent-', 'all resolved track lists assert auto-fit track collapse and auto-fill counts from grid placement and size'),
    ('css/css-grid/parsing/grid-template-columns-intrinsic-auto-repeat-computed.tentative.html', 'all resolved track sizes require intrinsic grid-lanes layout'),
    ('css/css-grid/parsing/grid-template-columns-intrinsic-auto-repeat-computed-withcontent.tentative.html', 'all resolved track counts/sizes require intrinsic grid-lanes layout'),
    ('css/css-grid/parsing/grid-template-columns-intrinsic-auto-repeat-computed-implicit-track.tentative.html', 'all resolved track lists assert a leading implicit track sized from grid item width'),
    ('css/css-grid/parsing/grid-template-rows-intrinsic-auto-repeat-computed.tentative.html', 'all resolved track sizes require intrinsic grid-lanes layout'),
    ('css/css-grid/parsing/grid-template-rows-intrinsic-auto-repeat-computed-withcontent.tentative.html', 'all resolved track counts/sizes require intrinsic grid-lanes layout'),
    ('css/css-grid/parsing/grid-template-rows-intrinsic-auto-repeat-computed-implicit-track.tentative.html', 'all resolved track lists assert a leading implicit track sized from grid item height'),
    # Computed-looking files reviewed with group (f), but asserting boxes.
    ('css/css-box/margin-trim/computed-margin-values/', 'checkLayout asserts used trimmed margins and laid-out container sizes'),
    ('css/css-grid/placement/grid-auto-flow-sparse-001.html', 'checkLayout asserts sparse grid item offsets and sizes'),
    ('css/css-pseudo/marker-computed-size.html', 'asserts resolved marker width/height from generated text and image boxes'),
    ('css/css-rhythm/computedstyle/block-level-replaced-elements-affected-by-block-step-size.html', 'checkLayout asserts replaced-element used margins and container heights'),
    ('css/css-rhythm/computedstyle/inline-level-replaced-elements-not-affected-by-block-step-size.html', 'checkLayout asserts replaced-element used margins and container heights'),
    ('css/css-values/minmax-length-percent-computed.html', 'test_math_used resolves percentage margins against the containing block width'),
    ('css/css-values/minmax-percentage-computed.html', 'test_math_used resolves percentage margins against the containing block width'),
    ('css/css-viewport/zoom/translate-zoom-anim-computed.html', 'asserted transform matrices resolve percentage translations against used element height'),
    ('css/css-writing-modes/forms/button-appearance-native-computed-style.html', 'asserts nonzero native widget used block/inline sizes and physical dimensions'),
    ('css/css-writing-modes/forms/checkbox-switch-input-computed-style.tentative.html', 'asserts nonzero native widget used block/inline sizes and physical dimensions'),
    ('css/css-writing-modes/forms/color-input-appearance-native-computed-style.html', 'asserts nonzero native widget used block/inline sizes and physical dimensions'),
    ('css/css-writing-modes/forms/date-input-appearance-native-computed-style.html', 'asserts nonzero native widget used block/inline sizes and physical dimensions'),
    ('css/css-writing-modes/forms/file-input-computed-style.html', 'asserts nonzero native widget used block/inline sizes and physical dimensions'),
    ('css/css-writing-modes/forms/meter-appearance-native-computed-style.optional.html', 'asserts nonzero native widget used block/inline sizes and physical dimensions'),
    ('css/css-writing-modes/forms/progress-appearance-native-computed-style.optional.html', 'asserts nonzero native widget used block/inline sizes and physical dimensions'),
    ('css/css-writing-modes/forms/select-appearance-native-computed-style.html', 'asserts nonzero native widget used block/inline sizes and physical dimensions'),

    ('mathml/relations/html5-tree/attribute-overflow.html', 'asserts MathML child getBoundingClientRect coordinates'),
    ('mathml/relations/html5-tree/canvas-visited-privacy.html', 'asserts rendered canvas getImageData pixels'),
    ('mathml/relations/html5-tree/content-editable.html', 'asserts fraction numerator/denominator getBoundingClientRect sizes'),
    ('mathml/relations/html5-tree/display-1.html', 'asserts MathML block/inline getBoundingClientRect positions'),
    ('mathml/relations/html5-tree/dynamic-childlist-', 'asserts MathML layout feature detection and getBoundingClientRect sizes'),
    ('mathml/relations/html5-tree/integration-point-4.html', 'asserts MathML fraction getBoundingClientRect sizes and alignment'),
    ('mathml/relations/html5-tree/integration-point-5.html', 'asserts MathML fraction getBoundingClientRect sizes and alignment'),

    ('html/interaction/focus/processing-model/preventScroll', 'asserts scroll positions before/after focus'),
    ('html/interaction/focus/processing-model/textarea-scroll-selection.html', 'asserts textarea scrollTop after selection changes'),
    ('html/interaction/focus/the-autofocus-attribute/update-the-rendering.html', 'asserts a scroll event caused by focusing an input beyond the laid-out viewport (row 111 Q14)'),
    # Keep non-table.html and css-table-not-focusgroup.html: they assert that
    # directional keys do not create focusgroup behavior, without box metrics.
    ('html/interaction/focus/focusgroup/tentative/grid-navigation/col-', 'keyboard focus target depends on rendered table column geometry'),
    ('html/interaction/focus/focusgroup/tentative/grid-navigation/colspan.html', 'keyboard focus target depends on spanning table-cell geometry'),
    ('html/interaction/focus/focusgroup/tentative/grid-navigation/css-table.html', 'keyboard focus target depends on CSS table layout'),
    ('html/interaction/focus/focusgroup/tentative/grid-navigation/does-not-wrap-or-flow.html', 'keyboard focus target depends on table row/column geometry'),
    ('html/interaction/focus/focusgroup/tentative/grid-navigation/empty-spaces.html', 'keyboard focus target depends on empty table-cell geometry'),
    ('html/interaction/focus/focusgroup/tentative/grid-navigation/flows-in-both-axes.html', 'keyboard focus target depends on table row/column geometry'),
    ('html/interaction/focus/focusgroup/tentative/grid-navigation/moves-across-table-sections.html', 'keyboard focus target depends on table section layout'),
    ('html/interaction/focus/focusgroup/tentative/grid-navigation/relayout-before-navigation.html', 'keyboard focus target depends on updated table layout'),
    ('html/interaction/focus/focusgroup/tentative/grid-navigation/row-', 'keyboard focus target depends on rendered table row geometry'),
    ('html/interaction/focus/focusgroup/tentative/grid-navigation/rowspan.html', 'keyboard focus target depends on spanning table-cell geometry'),
    ('html/interaction/focus/focusgroup/tentative/grid-navigation/simple-case', 'keyboard focus target depends on table row/column geometry'),
    ('html/interaction/focus/focusgroup/tentative/grid-navigation/wraps-in-both-axes.html', 'keyboard focus target depends on table row/column geometry'),
    # Keep fallback-to-dom-order.html: its expected order is the DOM order.
    ('html/interaction/focus/focusgroup/tentative/reading-flow-navigation/explicit-visual-reordering.html', 'keyboard focus target depends on visual flex layout order'),
    ('html/interaction/focus/focusgroup/tentative/reading-flow-navigation/flex-visual-order-basic.html', 'keyboard focus target depends on visual flex layout order'),
    ('html/interaction/focus/focusgroup/tentative/reading-flow-navigation/nested-containers.html', 'keyboard focus target depends on nested visual layout order'),
    ('html/interaction/focus/focusgroup/tentative/reading-flow-navigation/partial-reordering.html', 'keyboard focus target depends on visual layout order'),
    ('html/interaction/focus/focusgroup/tentative/reading-flow-navigation/simple-mixed.html', 'keyboard focus target depends on visual flex layout order'),
    ('shadow-dom/focus-navigation/reading-flow/tentative/grid-', 'keyboard focus target depends on grid visual layout order'),
    ('shadow-dom/focus-navigation/reading-flow/tentative/flex-', 'keyboard focus target depends on flex visual layout order'),
    ('shadow-dom/focus-navigation/reading-flow/tentative/carousel-grid-order.html', 'keyboard focus target depends on grid/carousel visual layout order'),
    ('shadow-dom/focus-navigation/tentative/focus-navigation-scroller-', 'focus target depends on a scrollable box'),
    ('shadow-dom/focus-navigation/tentative/focus-scroller-layout-update.html', 'focus target changes when layout creates a scrollable box'),
    ('shadow-dom/focus/focus-scroll-under-delegatesFocus.html', 'waits for and asserts scrolling caused by focus'),
    ('shadow-dom/focus/text-selection-with-delegatesFocus', 'pointer drag places a text selection using hit-testing'),

    ('html/semantics/interactive-elements/the-details-element/closed-details-layout-apis.tentative.html', 'asserts closed-details getBoundingClientRect geometry'),
    ('html/semantics/interactive-elements/the-dialog-element/abspos-dialog-layout.html', 'asserts dialog getBoundingClientRect and viewport dimensions'),
    ('html/semantics/interactive-elements/the-dialog-element/centering.html', 'asserts dialog getBoundingClientRect centering'),
    ('html/semantics/interactive-elements/the-dialog-element/multiple-centered-dialogs.html', 'asserts centered getBoundingClientRect positions against clientHeight'),
    ('html/semantics/interactive-elements/the-dialog-element/non-modal-dialog-layout.html', 'asserts non-modal dialog getBoundingClientRect positions'),
    ('html/semantics/interactive-elements/the-dialog-element/modal-dialog-scroll-height.html', 'asserts modal dialog scrollHeight'),
    ('html/semantics/interactive-elements/the-dialog-element/modal-dialog-selection.html', 'pointer drag places a text selection using hit-testing'),
    ('html/semantics/interactive-elements/the-dialog-element/inert-svg-hittest.html', 'asserts pointer hit-testing on SVG geometry'),
    ('html/semantics/interactive-elements/the-dialog-element/dialog-inert.html', 'asserts dialog elementFromPoint hit-testing at viewport coordinates'),
    ('html/semantics/interactive-elements/the-dialog-element/backdrop-receives-element-events.html', 'asserts dialog backdrop hit-testing at viewport pointer coordinates'),
    ('html/semantics/interactive-elements/the-dialog-element/dialog-closedby-bounds-clicking.html', 'asserts light-dismiss inside/outside rendered bounds at viewport pointer coordinates'),
    ('html/semantics/interactive-elements/the-dialog-element/dialog-light-dismiss-pointer-capture.html', 'asserts light-dismiss by hit-testing viewport pointer coordinates'),
    ('html/semantics/interactive-elements/the-dialog-element/dialog-light-dismiss-touch.html', 'asserts touch light-dismiss by hit-testing viewport pointer coordinates'),
    ('html/semantics/interactive-elements/the-dialog-element/closed-dialog-does-not-block-mouse-events.html', 'targets viewport pointer clicks using offsetLeft/Top/Width/Height'),
    ('html/semantics/interactive-elements/the-dialog-element/inert-inlines.html', 'asserts inert inline hit-testing using measured offset coordinates'),
    ('html/semantics/interactive-elements/the-dialog-element/inert-label-focus.html', 'targets an inert label by measured offset coordinates'),
    ('html/semantics/interactive-elements/the-dialog-element/inert-node-is-uneditable.html', 'targets editable text by measured offset coordinates'),
    ('html/semantics/interactive-elements/the-dialog-element/modal-dialog-ancestor-is-inert.html', 'asserts pointer targets at measured getBoundingClientRect centers'),
    ('html/semantics/interactive-elements/the-dialog-element/modal-dialog-blocks-mouse-events.html', 'asserts pointer targets at measured getBoundingClientRect centers'),
    ('html/semantics/interactive-elements/the-dialog-element/popover-dialog-does-not-block-mouse-events.html', 'targets viewport pointer clicks using measured offset coordinates'),

    ('editing/other/double-click-range-selection-in-', 'double-click selection requires text-position hit-testing'),
    ('editing/other/password-bidi-dblclick.html', 'double-click selection requires bidi text-position hit-testing'),
    ('editing/run/caret-navigation-around-line-break.html', 'asserts caret navigation after offsetWidth-based pointer placement'),
    ('dom/nodes/moveBefore/child-style-preserve.html', 'asserts moved child getBoundingClientRect width'),
    ('dom/nodes/moveBefore/moveBefore-from-light-to-shadow.html', 'asserts moved/slotted getBoundingClientRect width'),
    ('dom/nodes/moveBefore/moveBefore-shadow-inside.html', 'asserts shadow descendant getBoundingClientRect width after a move'),
    ('dom/nodes/moveBefore/moveBefore-size-query.html', 'asserts color selected by a query on laid-out container width'),
    ('dom/nodes/moveBefore/selection-preserve.html', 'pointer drag sets a visual text selection using clientWidth/clientHeight coordinates'),
    ('dom/nodes/moveBefore/continue-css-transition-left.html', 'asserts transition progress solely through getBoundingClientRect().x'),
    ('dom/nodes/moveBefore/css-transition-cross-shadow.html', 'asserts transition progress solely through getBoundingClientRect().x'),
    ('dom/nodes/moveBefore/css-transition-trigger.html', 'asserts transition progress solely through getBoundingClientRect().x'),
    ('dom/ranges/tentative/OpaqueRange-geometry-', 'asserts text range getClientRects/getBoundingClientRect geometry'),
    ('dom/ranges/tentative/OpaqueRange-highlightsFromPoint.html', 'asserts range hit-testing using getBoundingClientRect coordinates'),
    ('shadow-dom/Document-caretPositionFromPoint.tentative.html', 'asserts caretPositionFromPoint from measured coordinates'),
    ('html/semantics/forms/the-select-element/select-popover-position-with-zoom.tentative.html', 'asserts picker getBoundingClientRect positions under zoom'),
    ('html/semantics/forms/the-select-element/select-many-options.tentative.html', 'asserts picker getBoundingClientRect edges against viewport height'),
    ('html/semantics/the-button-element/command-and-commandfor/on-scroll-behavior.tentative.html', 'asserts scrollTop/scrollLeft positions and scroll-event behavior'),
    ('selection/select-end-of-line-image.tentative.html', 'pointer hit-testing selects the visual end of a rendered line'),
    ('selection/selection-direction-on-double-click.tentative.html', 'double-click selection requires text-position hit-testing'),
    ('selection/selection-direction-on-triple-click.tentative.html', 'triple-click selection requires text-position hit-testing'),

    # Proposals and things not shipping.
    ('dom/parts/',             'DOM Parts proposal'),
    ('dom/xslt/',              'XSLT'),
    # Tentative filenames are reviewed by behavior, not excluded wholesale.
    # moveBefore is in the DOM Standard and ships in Chrome and Firefox;
    # its DOM/state-preservation tests belong here (geometry exceptions above).
    ('html/semantics/popovers/',           'not in 0.1'),
    ('html/semantics/permission-element/', 'not in 0.1'),
    ('html/semantics/interestfor/',        'not in 0.1'),
    ('html/browsers/browsing-the-web/read-media/', 'media'),

    # Networking corners.
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
    # its siblings exercise the same explainer-only feature. No browser passes
    # option-attributes (wpt.fyi 23b0b89b1a, 2026-10-18: Chrome, Firefox and Safari fail
    # "Datalist should open after focusing input"; Edge 0 of 1). Codex row 72
    # Q7. Re-include when HTML specifies it or a stable browser ships it.
    ('html/semantics/forms/customizable-combobox/',
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
    # Needs Gecko's test preference dom.serviceWorkers.testUpdateOverOneDay
    # ("treat all registrations as older than 24 hours", the file's opening
    # comment); there is no WebDriver or testdriver way to set it, and Chrome,
    # Firefox and Safari all time out on wpt.fyi (2026-10-18). Lane sw1-b8.
    # Re-include if a testdriver hook for the update clock appears.
    ('service-workers/service-worker/update-after-oneday.https.html',
     'needs a Gecko-only test preference'),

    # XML-serialised documents: .xhtml, .svg, .xml.
    #
    # The engine has XML parsing, but the frozen 7c9db2e3a6 runner does not
    # execute XML-format test documents. Row 113 adds that runner path.
    # These are pending candidates, not measured Crane failures. Re-include
    # after its runner change is gated and the worklist proposal is approved.
    ('.xhtml',  'XML-format runner pending row 113'),
    ('.xht',    'XML-format runner pending row 113'),
    ('.svg',    'XML-format runner pending row 113'),
    ('.xml',    'XML-format runner pending row 113'),

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
    ('selection/caret/',             'caret position needs layout'),
    ('selection/bidi/',              'bidi selection needs layout'),
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
            # Explicitly reviewed tentative files do not waive any other
            # exclusion (geometry, unsupported formats, hardware, etc.).
            if pattern in ('/tentative/', '.tentative.') and any(
                    path == prefix for prefix, _ in INCLUDE):
                continue
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
