## 1. Introduction

This specification extends
[\[CSS-OVERFLOW-4\]](#biblio-css-overflow-4 "CSS Overflow Module Level 4").
It is currently a diff specification, defining only a few new features;
see
[\[CSS-OVERFLOW-4\]](#biblio-css-overflow-4 "CSS Overflow Module Level 4")
for the rest of the features related to overflow.

[Scroll navigation controls](#scroll-navigation)

: This section defines the ability to associate [scroll
 markers](#scroll-marker)
 with elements in a scroller (or generate them automatically as
 [::scroll-marker](#selectordef-scroll-marker)
 [pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element), with automatic user behavior and accessible
 labels), which can be activated to scroll to the associated elements
 and reflect the scroller's relative scroll progress via the
 [:target-current](#selectordef-target-current) pseudo-class.

 It also defines
 [::scroll-button()](#selectordef-scroll-button---scroll-button-direction) pseudo-elements, which can be activated to
 cause their associated scroller to scroll by a \"page\" in a given
 direction.

[Redirection of Overflow](#fragmentation)

: This section defines a highly experimental, exploratory new model
 for handling overflow by redirecting it into newly-generated
 [fragmentation
 containers](https://drafts.csswg.org/css-break-4/#fragmentation-container).

## 2. Overflow Concepts and Terminology

Copy [Level 3
content](https://drafts.csswg.org/css-overflow-3/#overflow-concepts)
when final.

### 2.1. Scrolling overflow

The following is added to the concepts in scrolling overflow:

Every [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) maintains a [current scroll
target]. It is initially `null`, and is reset to `null` after any
scrolling operations in that [scroll
container] initiated by the user, or any
script initiated operations that do not have a target, or when the
target is removed from the document. Scrolling operations in the [scroll
container] with a target Element or
PseudoElement, set the [current scroll
target](#current-scroll-target) to that target Element or PseudoElement.

Setting the current scroll target should
be defined in how to [scroll a target into
view](https://drafts.csswg.org/cssom-view-1/#scroll-a-target-into-view).

Use the current scroll target as an
[anchor priority
candidate](https://drafts.csswg.org/css-scroll-anchoring-1/#anchor-priority-candidates) for scroll anchoring.

## 3. Scroll navigation controls

### 3.1. Scroll markers

A [scroll marker] is any element or
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) with a [scroll
target](#scroll-target). An
element or pseudo-element's [scroll target] is the
[`Element`](https://dom.spec.whatwg.org/#element) indicated by the [scroll
marker](#scroll-marker). Which
elements are [scroll markers], and what their
[scroll targets] are, is host-language defined.
The [HTML \<a\>
element](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-a-element)
and [SVG \<a\>
element](https://w3c.github.io/svgwg/svg2-draft/linking.html#Links) are
[scroll markers], whose [scroll
target] is the [indicated
part](https://html.spec.whatwg.org/multipage/browsing-the-web.html#the-indicated-part-of-the-document). While these navigational links can be created today,
there is little feedback to the user regarding the current content being
viewed, and the interaction model does not match the expectations of
many modern accessible UI components.

This specification adds a mechanism for creating groups of [scroll
marker](#scroll-marker)s, and
for automatically creating
[::scroll-marker](#selectordef-scroll-marker) pseudo-elements. Within each group, the active
marker reflects the current scroll position, and can be styled to give
the user an indication of which section they are in.

Use cases include a table of contents with links to relevant contents,
markers for scrolling carousel pages, and scrollable tab panels.

Tests

- [relative-box-order-of-pseudo-elements.html](https://wpt.fyi/results/css/css-pseudo/relative-box-order-of-pseudo-elements.html "css/css-pseudo/relative-box-order-of-pseudo-elements.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/relative-box-order-of-pseudo-elements.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/relative-box-order-of-pseudo-elements.html)

Add images representing these examples.

#### 3.1.1. Scroll marker grouping

The
[scroll-target-group](#propdef-scroll-target-group) property determines whether an
element establishes a [scroll marker group
container] containing [scroll
marker](#scroll-marker)
elements forming a [scroll marker group].

A
[::scroll-marker-group](#selectordef-scroll-marker-group)
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) is the [scroll marker group
container](#scroll-marker-group-container) for its contained
[::scroll-marker](#selectordef-scroll-marker) pseudo-elements, which form a [scroll marker
group] together.

#### 3.1.2. The \'scroll target group\' property

Name:

[scroll-target-group]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) auto

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

The
[scroll-target-group](#propdef-scroll-target-group) property specifies whether the
element is a [scroll marker group
container](#scroll-marker-group-container).

[none]
: The element does not establish a [scroll marker group
 container](#scroll-marker-group-container).

[auto]
: The element establishes a [scroll marker group
 container](#scroll-marker-group-container) forming a [scroll marker group]
 containing all of the [scroll
 marker](#scroll-marker)
 elements for which this is the nearest ancestor [scroll marker group
 container].

The following snippet demonstrates how
to automatically highlight the currently visible chapter within a table
of contents

``` highlight
<!DOCTYPE HTML>
<title>scroll-target-group example with a table of contents</title>
<style>
 ol {
 background-color: gray;
 right: 10px;
 top: 10px;
 position: fixed;
 /* Triggers the browser's algorithm for calculating :target-current. */
 scroll-target-group: auto;
 }

 a:target-current {
 color: red;
 }

 .chapter {
 background: lightgray;
 height: 60vh;
 margin: 10px;
 }
</style>
<ol>
 <li><a href="#intro">Introduction</a></li>
 <li><a href="#ch1">Chapter 1</a></li>
 <li><a href="#ch2">Chapter 2</a></li>
</ol>
<div id="intro" class="chapter">Introduction content</div>
<div id="ch1" class="chapter">Chapter 1 content</div>
<div id="ch2" class="chapter">Chapter 2 content</div>
```

#### 3.1.3. The [scroll-marker-group property]
Name:

[scroll-marker-group]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) \[ \[ before [\|] after \]
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any) \[ links [\|] tabs \] \]

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[scroll
containers](https://drafts.csswg.org/css-overflow-3/#scroll-container)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword(s)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

The
[scroll-marker-group](#propdef-scroll-marker-group) property specifies whether the
[scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) should have a \'::scroll-marker-group\'
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) created, and its position relative to the scroll
container.

[none]
: The [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) does not create a \'::scroll-marker-group\'
 pseudo-element.

[before]
: The [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) generates a
 [::scroll-marker-group](#selectordef-scroll-marker-group) pseudo-element. When originating from the
 root element, the generated pseudo-element's box is the first child
 of the [originating
 element](https://drafts.csswg.org/selectors-4/#originating-element). Otherwise, its box is an immediate preceding
 sibling to its [originating element].

[after]
: The [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) generates a
 [::scroll-marker-group](#selectordef-scroll-marker-group) pseudo-element. When originating from the
 root element, the generated pseudo-element's box is the last child
 of the [originating
 element](https://drafts.csswg.org/selectors-4/#originating-element). Otherwise, its box is an immediate following
 sibling to its [originating element].

[links]
: The generated
 [::scroll-marker-group](#selectordef-scroll-marker-group) operates in \"links\" mode, functioning like
 a navigation list. This is the default mode if omitted.

[tabs]
: The generated
 [::scroll-marker-group](#selectordef-scroll-marker-group) operates in \"tabs\" mode, functioning like
 a tablist.

#### 3.1.4. The [::scroll-marker-group pseudo-element]
The [::scroll-marker-group] [fully styleable
pseudo-element](https://drafts.csswg.org/css-pseudo-4/#fully-styleable) is generated by a [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) element having a computed
[scroll-marker-group](#propdef-scroll-marker-group) property that is not
[none](#valdef-scroll-marker-group-none).

The
[::scroll-marker-group](#selectordef-scroll-marker-group) generates a box as a *sibling* of its
[originating
element](https://drafts.csswg.org/selectors-4/#originating-element), either immediately preceding (if [scroll-marker-group:
before](#propdef-scroll-marker-group)) or immediately following (if
[scroll-marker-group: after]).

The following additions are recommended for the default UA stylesheet to
ensure that the generation of scroll marker
[pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element) does not invalidate the layout of the site:

```
/* The generation of ::scroll-marker pseudo-elements shouldn't
 * invalidate layout outside of this pseudo-element. */
::scroll-marker-group { contain: size !important; }
```

#### 3.1.5. The [::scroll-marker pseudo-element]
Similar to
[::before](https://drafts.csswg.org/css-pseudo-4/#selectordef-before) and
[::after](https://drafts.csswg.org/css-pseudo-4/#selectordef-after), all elements can have a
[::scroll-marker](#selectordef-scroll-marker) pseudo-element, which is collected into the
[::scroll-marker-group](#selectordef-scroll-marker-group) of the nearest [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) ancestor, and scrolls to the element when activated.

When the computed
[content](https://drafts.csswg.org/css-content-3/#propdef-content) value of a
[::scroll-marker] pseudo-element is not
[none](https://drafts.csswg.org/css-content-3/#valdef-content-none) and its nearest ancestor [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) [scroll container] has a
computed
[scroll-marker-group](#propdef-scroll-marker-group) property that is not
[none](#valdef-scroll-marker-group-none), the pseudo-element generates a box attached as
a child of the
[::scroll-marker-group](#selectordef-scroll-marker-group) pseudo-element's generated box on its nearest
ancestor [scroll container]. These boxes
are added in the [tree
order](https://dom.spec.whatwg.org/#concept-tree-order) of their [originating
element](https://drafts.csswg.org/selectors-4/#originating-element).

These pseudo-elements are [fully styleable
pseudo-elements](https://drafts.csswg.org/css-pseudo-4/#fully-styleable) and have a default style like the [HTML \<a\>
element](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-a-element).

These pseudo-elements have an indicated [scroll
target](#scroll-target) of
their [originating
element](https://drafts.csswg.org/selectors-4/#originating-element).

#### 3.1.6. Scroll Marker Modes

A
[::scroll-marker-group](#selectordef-scroll-marker-group) operates in either [links] or [tabs] mode based on the
[scroll-marker-group](#propdef-scroll-marker-group) property value of its [originating
element](https://drafts.csswg.org/selectors-4/#originating-element). The chosen mode significantly affects the roles, focus
behaviors, and interactions of the associated elements and
pseudo-elements (see [§ 3.1.9 Activation
behavior](#scroll-marker-activation)).

If the mode is [links](#links):

- The roles of
 [::scroll-marker-group](#selectordef-scroll-marker-group) and
 [::scroll-marker](#selectordef-scroll-marker) are \`navigation\` and \`link\` respectively.

- All
 [::scroll-marker](#selectordef-scroll-marker) pseudo-elements are tab stops, in order.

- The roles of the [originating
 elements](https://drafts.csswg.org/selectors-4/#originating-element) are unaffected.

If the mode is [tabs](#tabs):

- The roles of
 [::scroll-marker-group](#selectordef-scroll-marker-group) and
 [::scroll-marker](#selectordef-scroll-marker) are \`tablist\` and \`tab\` respectively.

- The
 [::scroll-marker-group](#selectordef-scroll-marker-group) implicitly behaves as a single focusable
 component, establishing a
 [focusgroup](https://open-ui.org/components/focusgroup.explainer/).

- Only the active
 [::scroll-marker](#selectordef-scroll-marker) is a tab stop; arrow keys are used to switch
 between markers. They behave as an element with a
 [`tabindex`](https://html.spec.whatwg.org/multipage/interaction.html#attr-tabindex)
 of \"-1\", making them focusable within their
 [::scroll-marker-group](#selectordef-scroll-marker-group) either by arrow key navigation within the
 group, or via the tab key when currently active (or when no other
 [::scroll-marker] is active
 and this is the first marker in the group), ensuring the group has a
 [guaranteed tab
 stop](https://open-ui.org/components/focusgroup.explainer/#guaranteed-tab-stop).

- [Originating
 elements](https://drafts.csswg.org/selectors-4/#originating-element) of
 [::scroll-marker](#selectordef-scroll-marker) are given an implicit role of \`tabpanel\`. If
 the [originating element] is a
 [::column](https://drafts.csswg.org/css-multicol-2/#selectordef-column) pseudo-element, the \`tabpanel\` role is given
 to the [originating element] of the
 [::column].

- The
 [::scroll-marker](#selectordef-scroll-marker) pseudo-element is a focus navigation scope
 owner for its associated [originating
 element](https://drafts.csswg.org/selectors-4/#originating-element). This means that tab focus moves from the marker to
 the content. Since only the active marker is a tab stop, contents of
 the inactive tabpanels are not reached unless the active tab is
 switched.

- Content from inactive tabs is also hidden from the accessibility tree,
 meaning authors do not need to carefully apply \`interactivity:
 inert\` to hide the inactive tabpanels.

#### 3.1.7. Selecting Scroll Markers: [:target-current, [:target-before](#selectordef-target-before) and [:target-after](#selectordef-target-after) pseudo-classes]
Exactly one [scroll marker](#scroll-marker) within each [scroll marker group] is
determined to be active at a time. Such \"active\" [scroll
markers] match the
[:target-current] pseudo-class.

In addition to the
[:target-current](#selectordef-target-current) pseudo-class, this specification introduces
the [:target-before] and
[:target-after] pseudo-classes for use with [scroll
marker](#scroll-marker)
elements.

These pseudo-classes match [scroll
marker](#scroll-marker)s that
are, respectively, before or after the [active marker] (the
one matching
[:target-current](#selectordef-target-current)) within the same [scroll marker
group], as determined by [flat tree order]:

- **:target-before** matches all [scroll
 marker](#scroll-marker)s
 that precede the [active marker] in the flat tree order
 within the group.

- **:target-after** matches all [scroll
 marker](#scroll-marker)s
 that follow the [active marker] in the flat tree order
 within the group.

The following snippet demonstrates how
to style the active scroll marker and scroll markers before and after
the currently active one in a table of contents:

``` highlight
<!DOCTYPE HTML>
<title>:target-before and :target-after example</title>
<style>
 ol {
 background-color: gray;
 right: 10px;
 top: 10px;
 position: fixed;
 scroll-target-group: auto;
 }
 a:target-before {
 color: #888;
 }
 a:target-current {
 color: red;
 font-weight: bold;
 }
 a:target-after {
 color: #444;
 }
 .chapter {
 background: lightgray;
 height: 60vh;
 margin: 10px;
 }
</style>
<ol>
 <li><a href="#intro">Introduction</a></li>
 <li><a href="#ch1">Chapter 1</a></li>
 <li><a href="#ch2">Chapter 2</a></li>
</ol>
<div id="intro" class="chapter">Introduction content</div>
<div id="ch1" class="chapter">Chapter 1 content</div>
<div id="ch2" class="chapter">Chapter 2 content</div>
```

#### 3.1.8. Calculating the Active Scroll Marker

A scrolling operation might animate towards a particular position (e.g.
scrollbar arrow clicks, arrow key presses, \"behavior: smooth\"
programmatic scrolls) or might directly track a user's input (e.g. touch
scrolling, scrollbar dragging). In either case, the user agent chooses
an \'eventual scroll position\' to which the scroller will reach. This
ensures that the relevant marker is activated immediately.

This \'eventual scroll position\' is used to determine the active marker
within each [scroll marker group]. Since markers themselves
may represent just the start of the content (e.g. headers), we consider
the active marker to be the first one which we are at or beyond the
scroll position of.

Whenever a [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) participating in one or more [scroll marker
groups] is scrolled, or layout changes the eventual scroll
position, the user agent should determine and update the active marker
for each [scroll marker group] based on the section of
content most likely to be of interest given the target scroll position.

Example algorithm to determine the
active marker for a given scroll marker `group`.

1. Let `scroller` be the nearest common ancestor [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) of all of the [scroll
 marker](#scroll-marker)
 elements in `group`.

2. Let `active` be scroller.

3. While `active` is a [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) containing [scroll
 target](#scroll-target)
 elements targeted by `group`:

 1. Let `scroller` be `active`.

 2. Let `targets` be the set of the [scroll
 target](#scroll-target)
 elements whose nearest ancestor [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) is `scroller` and the [scroll
 container] elements which contain
 [scroll target] elements targeted by
 the [scroll marker group] whose nearest ancestor
 [scroll container] is
 `scroller`.

 3.

 If `scroller` has a non-null [current scroll target](#current-scroll-target)

 : Let active be the first item in `targets`
 encountered by a reverse tree order walk starting from the
 [current scroll
 target](#current-scroll-target), or the first item in tree order in
 `targets` if no target is found in the previous
 walk.

 Otherwise,

 : 1. Let `primary` be the primary scrolling axis,
 assumed to be the block direction of the container's
 writing-mode.

 2. Let `secondary` be the scrolling axis
 perpendicular to primary.

 3. Let `position` be the \'eventual scroll
 position\' considering ongoing scrolling operations.

 4. For each `axis` of `primary`,
 followed by `secondary`:

 1. Let `scrollport size` be the client size
 of `scroller` in the dimension
 `axis`.

 2. For each `target` in
 `targets`, [determine the
 scroll-into-view
 position](https://drafts.csswg.org/cssom-view-1/#determine-the-scroll-into-view-position) of `target` in
 `axis`, storing this as the associated
 `target position` of `target`.

 3. Let `scroll size` be the length of the
 [scrollable overflow
 area](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow-region) of the `scroller` in the
 dimension `axis`.

 4. Let `scroll range` be
 `scroll size`` - ``scrollport size`.

 5. If `scroll range` is greater than 0,
 redistribute unreachable target positions:

 1. Let `distribute range` be
 `min(1/8 * ``scrollport size``, ``scroll range`` / 2)`.

 2. Let `before targets` be all
 `targets` whose associated
 `target position` is less than
 `distribute range`.

 3. Let `minimum position` be the minimum
 `target position` of
 `before targets`.

 4. Update the associated
 `target position` of each target in
 `before targets` to
 `(``target position`` - ``minimum position``) / (``distribute range`` - ``minimum position``) * ``distribute range`.

 5. Let `after targets` be all
 `targets` whose associated
 `target position` is greater than
 `scroll range`` - ``distribute range`.

 6. Let `maximum position` be the maximum
 `target position` of
 `after targets`.

 7. Update the associated
 `target position` of each target in
 `after targets` to
 `(``target position`` - (``scroll range`` - ``distribute range``)) / (``maximum position`` - (``scroll range`` - ``distribute range``)) * ``distribute range`` + (``scroll range`` - ``distribute range``)`.

 6. Let `selected position` be the largest
 `target position` where
 `target position` is equal to or before
 `position` in the `axis`, or
 whose nearest smaller `target position`
 \< `position` -
 `scrollport size` / 2 and whose
 `target position` \<
 `position` + `scrollport size`
 / 2.

 7.

 If there is no such position,

 : Set the `selected position` to the
 first one.

 8. Let `active` be the all of the
 `targets` whose associated
 `target position` is
 `selected position`.

 5. Let `active` be the first item in
 `active` if it has more than one potential
 target.

4. Let `selected marker` be the [scroll
 marker](#scroll-marker)
 associated with `active`. If multiple [scroll
 marker] elements are associated with
 `active`, set `selected marker` to be the
 marker that is earliest in tree order among them.

5. Return `selected marker`

Whenever the UA determines that a new marker is the
`active marker` for a [scroll marker group]
`group` it must run the following steps:

1. Set the active state of `active marker` to true.

2. If `active marker` was the [last-focused
 element](https://open-ui.org/components/focusgroup.explainer/#last-focused-memory)
 of the `group`,

 Focus `active marker`

3. Set the [last-focused
 element](https://open-ui.org/components/focusgroup.explainer/#last-focused-memory)
 of the `group` to `active marker`.

4. Set the active state of all other [scroll
 marker](#scroll-marker)
 elements in `group` to false.

#### 3.1.9. Activation behavior

When a [scroll marker](#scroll-marker) with a non-null [scroll
target](#scroll-target) is
activated by explicit invocation or arrow key focus:

1. Let `element` be the [scroll
 target](#scroll-target) of
 the control.

2. Let `block` be \"`start`\".

3. Let `inline` be \"`start`\".

4. Let `container` be the nearest common ancestor [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) of the scroll markers in the [scroll marker
 group] associated with this [scroll
 marker](#scroll-marker).

5. [Scroll the `element` into
 view](https://drafts.csswg.org/cssom-view-1/#scroll-a-target-into-view) with `block`, `inline`, and
 `container`.

6.

 If the activation was triggered by invocation

 : 1. [Follow the
 hyperlink](https://html.spec.whatwg.org/multipage/links.html#following-hyperlinks-2) updating the URL.

 2.

 If the [scroll marker group] is in [tabs](#tabs) mode

 : Retain focus on the [scroll
 marker](#scroll-marker) element.

 3.

 If the [scroll marker group] is in [links](#links) mode

 : Set the [sequential focus navigation starting
 point](https://html.spec.whatwg.org/multipage/interaction.html#sequential-focus-navigation-starting-point)
 to the [originating
 element](https://drafts.csswg.org/selectors-4/#originating-element), losing focus from the [scroll
 marker](#scroll-marker).

 In [tabs](#tabs) mode, if the user tabs away, the focus behavior
 will ensure they tab into the relevant content.

#### 3.1.10. Next tab-index-ordered focus

When a [scroll marker](#scroll-marker) in [tabs](#tabs) mode
is activated, the next tabindex-ordered focus navigation will focus the
[scroll target](#scroll-target)
if it is focusable, otherwise, it will find the next focusable element
from the [scroll target] as though it were
focused.

### 3.2. Scroll Buttons

The [::scroll-button( \'\*\' \|
[\<scroll-button-direction\>](#typedef-scroll-button-direction)
)] pseudo-elements are
generated on [scroll
containers](https://drafts.csswg.org/css-overflow-3/#scroll-container) when their computed
[content](https://drafts.csswg.org/css-content-3/#propdef-content) value is not
[none](https://drafts.csswg.org/css-content-3/#valdef-content-none). They generate boxes as if they were immediately
preceding *siblings* of their [originating
element](https://drafts.csswg.org/selectors-4/#originating-element), with content as specified by
[content]. They exist after their
[originating element's]
[::scroll-marker-group](#selectordef-scroll-marker-group) pseudo-element (when used with
[scroll-marker-group:
before](#propdef-scroll-marker-group)).

Four distinct
[::scroll-button()](#selectordef-scroll-button---scroll-button-direction) pseudo-elements can exist on a [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container), each associated with a
[flow-relative](https://drafts.csswg.org/css-writing-modes-4/#flow-relative) direction, based on their [originating
element's](https://drafts.csswg.org/selectors-4/#originating-element) [writing
mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode): in order,
[block-start](https://drafts.csswg.org/css-writing-modes-4/#block-start),
[inline-start](https://drafts.csswg.org/css-writing-modes-4/#inline-start),
[inline-end](https://drafts.csswg.org/css-writing-modes-4/#inline-end), and
[block-end](https://drafts.csswg.org/css-writing-modes-4/#block-end). The
[::scroll-button()] pseudo-elements are both focusable and activatable by default,
with their activation behavior being to scroll their [originating
element] by one \"page\" in their
associated direction, similar to pressing PgUp/PgDn keys. [(Usually,
this will be about 85% of the
[scrollport](https://drafts.csswg.org/css-overflow-3/#scrollport) size.)] Like those keys, this scroll has an
[intended direction and end
position](https://www.w3.org/TR/css-scroll-snap-1/#intended-direction-and-end-position).

[\[CSSOM-VIEW-1\]](#biblio-cssom-view-1 "CSSOM View Module")
will grow a \"scroll by pages\" algorithm, at which point this can
reference that. See [the resolution on issue
#10914](https://github.com/w3c/csswg-drafts/issues/10914#issuecomment-2380139977).

Is this the best order for the buttons?
This does match the usual ordering of logical directions in CSS, but
similar buttons created manually are usually either ordered with
verticals and horizontals each grouped together (aka
block-start/block-end then inline-start/inline-end) or the verticals
\"around\" the horizontals (aka
block-start/inline-start/inline-end/block-end).

The four
[::scroll-button()](#selectordef-scroll-button---scroll-button-direction) pseudo-elements are individually selected by the
selector's argument. A [\*] arguments selects all four
[::scroll-button()]s; otherwise the selected pseudo-element is determined by the
[[\<scroll-button-direction\>](#typedef-scroll-button-direction)] value:

[up]\
[down]\
[left]\
[right]

: Selects the
 [::scroll-button()](#selectordef-scroll-button---scroll-button-direction) corresponding to the given physical
 direction.

[block-start]\
[block-end]\
[inline-start]\
[inline-end]

: Selects the indicated
 [::scroll-button()](#selectordef-scroll-button---scroll-button-direction) pseudo-element.

[prev]

: Selects either the
 [block-start](https://drafts.csswg.org/css-writing-modes-4/#block-start) or
 [inline-start](https://drafts.csswg.org/css-writing-modes-4/#inline-start)
 [::scroll-button()](#selectordef-scroll-button---scroll-button-direction), whichever's axis has more \"scrollable
 pages\" in the [originating
 element](https://drafts.csswg.org/selectors-4/#originating-element): the [originating
 element's] [scrollable overflow
 height](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow-region) divided by its
 [scrollport](https://drafts.csswg.org/css-overflow-3/#scrollport) height, or the same but for widths.

 If both dimensions are equally sized, selects the
 [block-start](https://drafts.csswg.org/css-writing-modes-4/#block-start)
 [::scroll-button()](#selectordef-scroll-button---scroll-button-direction).

 (#example-af1a5884) For example, say the [originating
 element](https://drafts.csswg.org/selectors-4/#originating-element) was 800px wide and 500px tall, while its
 [scrollable overflow
 area](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow-region) was 1200px wide and 1000px tall. The horizontal
 scrolling thus represents 1.5 \"pages\" (1200/800), while the
 vertical scrolling represents 2 \"pages\" (1000/500), so (assuming
 the element is in English) the [::scroll-button(prev)]
 selector would select the
 [block-start](https://drafts.csswg.org/css-writing-modes-4/#block-start) button.

[next]

: Identical to
 [prev](#valdef-scroll-button-direction-prev), except it selects the
 [block-end](https://drafts.csswg.org/css-writing-modes-4/#block-end) or
 [inline-end](https://drafts.csswg.org/css-writing-modes-4/#inline-end)
 [::scroll-button()](#selectordef-scroll-button---scroll-button-direction) instead.

Do we want to add some multi-button
keywords to make it easier to style several buttons the same way? In
particular, [all] is probably useful, but maybe also
[horizontal]/[vertical]/[block]/[inline].

The
[::scroll-button()](#selectordef-scroll-button---scroll-button-direction)s are [fully styleable
pseudo-elements](https://drafts.csswg.org/css-pseudo-4/#fully-styleable): there is no restriction on what properties apply to
them. They are styled like buttons, switching between the [native
appearance](https://drafts.csswg.org/css-ui-4/#native-appearance) and [base
appearance](https://drafts.csswg.org/css-ui-4/#base-appearance) based on the
[appearance](https://drafts.csswg.org/css-ui-4/#propdef-appearance) property value.

The
[:disabled](https://drafts.csswg.org/selectors-4/#disabled-pseudo) pseudo-class can apply to
[::scroll-button()](#selectordef-scroll-button---scroll-button-direction). It matches a given button when their
[originating
element](https://drafts.csswg.org/selectors-4/#originating-element) can't be scrolled in their associated direction.

The UA stylesheet needs to specify that
[::scroll-button()](#selectordef-scroll-button---scroll-button-direction)s are styled identically to the
[`button`](https://html.spec.whatwg.org/multipage/form-elements.html#the-button-element) element, including disabled styles.

Should
[::scroll-button()](#selectordef-scroll-button---scroll-button-direction) use the \*full\* UA styling of buttons, aka
[appearance:button]? Or the non-native rendering, aka
[appearance:none]? If the former, we'll obviously need to define
the interaction with
[appearance](https://drafts.csswg.org/css-ui-4/#propdef-appearance).

### 3.3. Focus behavior

The above features generate several focusable pseudo-elements. This
section defines some of the focus related behaviors.

#### 3.3.1. The active element

When a
[::scroll-button()](#selectordef-scroll-button---scroll-button-direction) or
[::scroll-marker](#selectordef-scroll-marker) is focused, the
[`activeElement`](https://html.spec.whatwg.org/multipage/interaction.html#dom-documentorshadowroot-activeelement) is the [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) the control is associated with.

#### 3.3.2. Focus related pseudo-classes

When a
[::scroll-button()](#selectordef-scroll-button---scroll-button-direction) or
[::scroll-marker](#selectordef-scroll-marker) is focused, none of the focus related
pseudo-classes
[:focus](https://drafts.csswg.org/selectors-4/#focus-pseudo),
[:focus-visible](https://drafts.csswg.org/selectors-4/#focus-visible-pseudo) and
[:active](https://drafts.csswg.org/selectors-4/#active-pseudo) match on the [scrolling
container](https://drafts.csswg.org/css-overflow-3/#scroll-container). Instead, [:focus] and,
when relevant [:focus-visible],
match on the focused pseudo-element. [:active] matches on the pseudo-element while it is being activated.
[:focus-within](https://drafts.csswg.org/selectors-4/#focus-within-pseudo) matches on the [scroll
container] and all of its ancestors in the
[flat
tree](https://drafts.csswg.org/css-shadow-1/#flat-tree).

When a
[::scroll-marker](#selectordef-scroll-marker) is focused,
[:focus-within](https://drafts.csswg.org/selectors-4/#focus-within-pseudo) additionally matches on the
[::scroll-marker-group](#selectordef-scroll-marker-group) it belongs to.

#### 3.3.3. Focus navigation order

While these pseudo-elements have a defined position in the element tree,
this isn't an optimal position for focus navigation (aka \"tab order\")
for these controls.

Instead, focus navigation between a [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) and the various pseudo-elements defined in this section
goes in the following order:

1. The
 [::scroll-marker-group](#selectordef-scroll-marker-group) pseudo-elements of the [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container), if it is set to [scroll-marker-group:
 before](#propdef-scroll-marker-group).

 The individual
 [::scroll-marker](#selectordef-scroll-marker) pseudo-elements generated by the [scroll
 containers](https://drafts.csswg.org/css-overflow-3/#scroll-container) descendants are reparented underneath this
 [::scroll-marker-group](#selectordef-scroll-marker-group), and navigated together as a \"focus
 group\".

2. The
 [::scroll-button()](#selectordef-scroll-button---scroll-button-direction) pseudo-elements, in the order they're
 defined as existing in.

3. The [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) itself, and its contents, in the normal focus order
 they would be in.

4. The
 [::scroll-marker-group](#selectordef-scroll-marker-group) pseudo-elements of the [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container), if it is set to [scroll-marker-group:
 after](#propdef-scroll-marker-group).

## 4. Scroll Axis Locking

When handling a scroll resulting from a user's gesture on a page, user
agent's often \"lock\" the resulting scroll to one axis, i.e. zero out
the deltas in the perpendicular axis.

For example, say a user dragged their
finger on the screen such that the element undeneath the finger would be
scrolled by 500px in the y-axis and 3px in the x-axis. Because the
gesture is almost entirely vertical, the user agent might interpret the
user's intent to be a perfectly vertical scroll. As such, the user agent
would ignore the 3px scroll delta and all further x-axis deltas for the
remainder of the gesture. In this case, the user agent has \"locked\"
the scroll to the y-axis.\
\
In many cases, this improves the user experience by avoiding accidental
drift. However, in cases where an author wishes their element to always
be diagonally scrollable, e.g. maps or zoomed images, the user would be
required to always begin their gesture at an angle that would not
trigger the locking.

The
[scroll-axis-lock](#propdef-scroll-axis-lock) property lets authors instruct the
user agent not to apply any axis locking when the specified element is
scrolled.

### 4.1. The scroll-axis-lock property

Name:

[scroll-axis-lock]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) none

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) elements

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

The
[scroll-axis-lock](#propdef-scroll-axis-lock) property specifies whether the user
agent may lock scrolls on the element to one axis.

[none]
: The user agent must not lock scrolls on the element to one axis.

[auto]
: The user agent may lock scrolls on the element to one axis.

UAs must apply the
[scroll-axis-lock](#propdef-scroll-axis-lock) value set on the root element to
the document viewport.

 Unlike
[overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) property (and its longhands), a
[scroll-axis-lock](#propdef-scroll-axis-lock) value set on the HTML
[`body`](https://html.spec.whatwg.org/multipage/sections.html#the-body-element) is *not* propagated to the viewport.

## [ Appendix A: Redirection of Overflow]
This section is highly experimental. It
documents current attempts at extending the capabilities of the
[continue](https://drafts.csswg.org/css-overflow-4/#propdef-continue) property to solve additional use
cases. However, it does not currently have consensus. It is presented
here to encourage discussion, but non-experimental implementation is not
recommended.

In CSS Level 1
[\[CSS1\]](#biblio-css1 "Cascading Style Sheets, level 1"),
placing more content than would fit inside an element with a specified
size was generally an authoring error. Doing so caused the content to
extend outside the bounds of the element, which would likely cause that
content to overlap with other elements.

CSS Level 2
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
introduced the
[overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) property, which allows authors to
have overflow be handled by scrolling, which means it is no longer an
authoring error. It also allows authors to specify that overflow is
handled by clipping, which makes sense when the author's intent is that
the content not be shown. This was further refined in the CSS Overflow
Module Level 3
[\[CSS-OVERFLOW-3\]](#biblio-css-overflow-3 "CSS Overflow Module Level 3").

However, scrolling is not the only way to present large amounts of
content, and may even not be the optimal way. After all, the codex
replaced the scroll as the common format for large written works because
of its advantages.

This specification introduces a mechanism for Web pages to specify that
an element of a page should handle overflow through pagination rather
than through scrolling.

This specification also extends the concept of overflow in another
direction. Instead of requiring that authors specify a single area into
which the content of an element must flow, this specification allows
authors to specify multiple fragments, each with their own dimensions
and styles, so that the content of the element can flow from one to the
next, using as many as needed to place the content without overflowing.

In both of these cases, implementations must break the content in the
block-progression dimension. Implementations must do this is described
in the CSS Fragmentation Module
[\[CSS-BREAK-3\]](#biblio-css-break-3 "CSS Fragmentation Module Level 3").

### [ Channeling Overflow: the [continue](https://drafts.csswg.org/css-overflow-4/#propdef-continue) property]
The
[continue](https://drafts.csswg.org/css-overflow-4/#propdef-continue) property gives authors the ability
to request that content that does not fit inside an element be
fragmented (in the sense of
[\[CSS-BREAK-3\]](#biblio-css-break-3 "CSS Fragmentation Module Level 3")),
and provides alternatives for where the remaining content should
continue.

Notably, this property explains traditional pagination, and extends it
further.

Name:

[continue](https://drafts.csswg.org/css-overflow-4/#propdef-continue)

[New values:](https://www.w3.org/TR/css-values/#value-defs)

overflow
[\|](https://drafts.csswg.org/css-values-4/#comb-one) paginate [\|] fragments

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

block containers
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification"),
flex containers
[\[CSS3-FLEXBOX\]](#biblio-css3-flexbox "CSS Flexible Box Layout Module Level 1"),
and grid containers
[\[CSS3-GRID-LAYOUT\]](#biblio-css3-grid-layout "CSS Grid Layout Module Level 1")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see below

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

The naming of this property and its
values is preliminary. This was initially proposed as \"fragmentation:
auto \| none \| break \| clone \| page\" in
<https://lists.w3.org/Archives/Public/www-style/2015Jan/0357.html>, and
there is not yet wide agreement as to which naming is better.

This property is meant to generalize and
replace
[region-fragment](https://drafts.csswg.org/css-regions-1/#propdef-region-fragment). Once it is sufficiently stable in
this specification, [region-fragment] should be removed from the regions specification in favor of
this.

 [continue:
fragments](https://drafts.csswg.org/css-overflow-4/#propdef-continue) replaces \"overflow:fragments\" from earlier
versions of this specification, while [continue:
paginate] replaces \"overflow: paged-x
\| paged-y \| paged-x-controls \| paged-y-controls\"

auto

: [auto](https://www.w3.org/TR/css-overflow-4/#valdef-continue-auto) may only occur as a computed value if the
 element is a [CSS
 Region](https://drafts.csswg.org/css-regions-1/#css-region) other than the last one in a [region
 chain](https://drafts.csswg.org/css-regions-1/#region-chain). Content that doesn't fit is pushed to the next
 region of the chain.

 In all other cases,
 [auto](https://www.w3.org/TR/css-overflow-4/#valdef-continue-auto) computes to one of the other values.

 (#issue-cb5399d1) this is different from the
 definition in [CSS Overflow 4 § 5.3 Handling of Excess Content: the
 continue
 property](https://drafts.csswg.org/css-overflow-4/#continue), where
 the specified value is the computed value. Which is model better?

[overflow]
: Content that doesn't fit overflows, according to the
 [overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) property

[paginate]

: Content that doesn't fit paginates. This creates a paginated view
 inside the element similar to the way that \'overflow: scroll\'
 creates a scrollable view.

 See [paginated overflow](#paginated-overflow)

 Print is effectively \"continue: paginate\" on the
 root.

[fragments]

: content that doesn't fit causes the element to copy itself and
 continue laying out.

 See [fragment overflow](#fragment-overflow).

The computed value of the
[continue](https://drafts.csswg.org/css-overflow-4/#propdef-continue) for a given element or
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) is determined as follow:

1. On elements or pseudo-elements with [layout
 containment](https://drafts.csswg.org/css-contain-2/#layout-containment) (see
 [\[CSS-CONTAIN-1\]](#biblio-css-contain-1 "CSS Containment Module Level 1")),
 if the specified value is
 [auto](https://www.w3.org/TR/css-overflow-4/#valdef-continue-auto) or
 [fragments](#valdef-continue-fragments) then the computed value is
 [overflow](#valdef-continue-overflow).

2. Otherwise, if the specified value is
 [auto](https://www.w3.org/TR/css-overflow-4/#valdef-continue-auto)

 1. On a [CSS
 Region](https://drafts.csswg.org/css-regions-1/#css-region) other than the last one in a [region
 chain](https://drafts.csswg.org/css-regions-1/#region-chain), the computed value is
 [auto](https://www.w3.org/TR/css-overflow-4/#valdef-continue-auto)

 2. On a page the computed value is
 [paginate](#valdef-continue-paginate)

 3. On a [fragment box](#fragment-box) the computed value is
 [fragments](#valdef-continue-fragments)

 4. Otherwise, the computed value is
 [overflow](#valdef-continue-overflow)

3. Otherwise, if the specified value is
 [fragments](#valdef-continue-fragments)

 1. On a page the computed value is
 [paginate](#valdef-continue-paginate)

 2. Otherwise, the computed value is the specified value

4. In all other cases, the computed value is the specified value

If we introduce a pseudo-element that
can select columns in a multicol, we would need to specify that auto
computes to auto on it, or introduce a new value and have auto compute
to that (but what would that value compute to on things that aren't
columns?).

 For background discussions leading to this property,
see these threads: [discussion of overflow, overflow-x, overflow-y and
overflow-style](http://lists.w3.org/Archives/Public/www-style/2012May/1197.html)
and [proposal for a fragmentation
property](https://lists.w3.org/Archives/Public/www-style/2015Jan/0357.html)

### [ Paginated overflow]
This section introduces and defines the meaning of the
[paginate](#valdef-continue-paginate) value of the
[continue](https://drafts.csswg.org/css-overflow-4/#propdef-continue) property.

Write this section

Pages should be possible to style with
\@page rules. How does that work for nested pages?

Should traditional pagination (e.g. when
printing) be expressed through some magic in the computed value of
[auto](https://www.w3.org/TR/css-overflow-4/#valdef-continue-auto), or by inserting this in the UA stylesheet:

```
@media (overflow-block: paged), (overflow-block: optional-paged) {
 :root {
 continue: paginate;
 }
}
```

Traditional pagination (e.g. when
printing) assumes that :root is contained in the page box, rather than
having the page box be a pseudo-element child of :root. Can we work
around that using something similar to fragment boxes? Or maybe by
having a fragment box (reproducing :root) inside a page box inside
:root?

How does the page box model work when it
is a child of a regular css box?

The initial proposal in
[\[CSS3GCPM\]](#biblio-css3gcpm "CSS Generated Content for Paged Media Module")
and implementation from Opera used 4 values instead of
[paginate](#valdef-continue-paginate): \"paged-x \| paged-y \| paged-x-controls \|
paged-y-controls\". Should this property also include these values, or
are they better handled as separate properties? (e.g.:
\"pagination-layout: auto \| horizontal \| vertical\",
\"pagination-controls: auto \| none\")

Ability to display N pages at once
rather than just one page at once? Could this be a value of
\"pagination-layout\", such as: \"pagination-layout: horizontal 2;\"

Brad Kemper has proposed a model for
combining pagination and fragment overflow, which also deals with
displaying multiple pages.
<https://lists.w3.org/Archives/Public/www-style/2015Mar/0241.html>

The current implementation of paginated
overflow uses the overflow/overflow-x/overflow-y properties rather than
the overflow-style property as proposed in the
[\[CSS3GCPM\]](#biblio-css3gcpm "CSS Generated Content for Paged Media Module")
draft (which also matches the
[\[CSS3-MARQUEE\]](#biblio-css3-marquee "CSS Marquee Module Level 3")
proposal). or the
[continue](https://drafts.csswg.org/css-overflow-4/#propdef-continue) property as described here.

### [ Fragmented Overflow]
This section introduces and defines the meaning of the
[fragments](#valdef-continue-fragments) value of the
[continue](https://drafts.csswg.org/css-overflow-4/#propdef-continue) property.

When the computed value of
[continue](https://drafts.csswg.org/css-overflow-4/#propdef-continue) for an element is
[fragments](#valdef-continue-fragments), and implementations would otherwise have
created a box for the element, then implementations must create a
sequence of [fragment box]es for that element. (It is possible for an
element with [continue: fragments] to
generate only one [fragment box](#fragment-box). However, if an element's computed
[continue] is not
[fragments], then its box is
not a [fragment box].) Every [fragment
box] is a fragmentation container, and any
overflow that would cause that fragmentation container to fragment
causes another [fragment box] created as a next
sibling of the previous one. [(#issue-c87585cb)Or is it as
though it's a next sibling of the element? Need to figure out exactly
how this interacts with other box-level fixup.]
Additionally, if the [fragment box] is also a
multi-column box (as defined in
[\[css-multicol-1\]](#biblio-css-multicol-1 "CSS Multi-column Layout Module Level 1")
[(#issue-6629852d)though it defines *multi-column
container*]) any content that would lead to the
creation of [overflow
columns](https://drafts.csswg.org/css-multicol-1/#overflow-columns)
[\[css-multicol-1\]](#biblio-css-multicol-1 "CSS Multi-column Layout Module Level 1")
instead is flown into an additional fragment box. However, fragment
boxes may themselves be broken (due to fragmentation in a fragmentation
context outside of them, such as pages, columns, or other fragment
boxes); such breaking leads to fragments of the same fragment box rather
than multiple fragment boxes. (This matters because fragment boxes may
be styled by their index; such breaking leads to multiple fragments of a
fragment box with a single index. This design choice is so that breaking
a fragment box across pages does not break the association of indices to
particular pieces of content.) [(#issue-74cf5d92)Should a
forced break that breaks to an outer fragmentation context cause a new
fragment of a single fragment box or a new fragment
box?] [(#issue-ca84b506)Should we
find a term other than [fragment
box](#fragment-box) here to make
this a little less confusing?]

What if we want to be able to style the
pieces of an element split within another type of fragmentation context?
These rules prevent ever using
[::nth-fragment()](#selectordef-nth-fragment) for that, despite that the name seems the most
logical name for such a feature.

``` highlight
<!DOCTYPE HTML>
<title>Breaking content into
 equal-sized cards</title>
<style>
 .in-cards {
 continue: fragments;

 width: 13em;
 height: 8em;

 padding: 4px;
 border: medium solid blue;
 margin: 6px;

 font: medium/1.3 Times New
 Roman, Times, serif;
 }
</style>
<div class="in-cards">
 In this example, the text in the div
 is broken into a series of cards.
 These cards all have the same style.
 The presence of enough content to
 overflow one of the cards causes
 another one to be created. The second
 card is created just like it's the
 next sibling of the first.
</div>
```

::: in-cards-demo
In this example, the text in the\
div is broken into a series of\
cards. These cards all have the\
same style. The presence of\
enough content to overflow\
one of the cards causes another

::: in-cards-demo
one to be created. The second\
card is created just like it's the\
next sibling of the first.

Authors may wish to style the opening
lines of an element with different styles by putting those opening lines
in a separate fragment. However, since it may be difficult to predict
the exact height occupied by those lines in order to restrict the first
fragment to that height, it is more convenient to use the
[max-lines](https://drafts.csswg.org/css-overflow-4/#propdef-max-lines) property, which forces a fragment
to break after a specified number of lines. This forces a break after
the given number of lines contained within the element or its
descendants, as long as those lines are in the same block formatting
context.

``` highlight
<!DOCTYPE HTML>
<style>
 .article {
 continue: fragments;
 }
 .article::first-letter {
 font-size: 2em;
 line-height: 0.9;
 }
 .article::nth-fragment(1) {
 font-size: 1.5em;
 max-lines: 3;
 }
 .article::nth-fragment(2) {
 column-count: 2;
 }
</style>
<div class="article">
 ...
</div>
```

The max-lines property allows\
authors to use a larger font for the first\
few lines of an article. Without the

max-lines property, authors\
might have to use the\
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height) property instead, but\
that would leave a slight gap\
if the author miscalculated\
how much height a given\
number of lines would\
occupy (which might be

particularly hard if the author\
didn't know what text would\
be filling the space, exactly\
what font would be used, or\
exactly which platform's font\
rendering would be used to\
display the font).

We should specify that [continue:
fragments](https://drafts.csswg.org/css-overflow-4/#propdef-continue) does not apply to at least some table parts,
and perhaps other elements as well. We need to determine exactly which
ones.

This specification needs to say which
type of fragmentation context is created so that it's clear which values
of the [break-\*] properties cause breaks within this context. We
probably want [break-\*: region] to apply.

This specification needs a processing
model that will apply in cases where the layout containing the fragments
has characteristics that use the intrinsic size of the fragments to
change the amount of space available for them, such as
[\[CSS3-GRID-LAYOUT\]](#biblio-css3-grid-layout "CSS Grid Layout Module Level 1").
There has already been some work on such a processing model in
[\[CSS-REGIONS-1\]](#biblio-css-regions-1 "CSS Regions Module Level 1"),
and the work done on a model there, and the editors of that
specification, should inform what happens in this specification.

### [Fragment styling]
#### [ The [::nth-fragment()](#selectordef-nth-fragment) pseudo-element]
The [::nth-fragment()]
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) is a pseudo-element that describes some of the
[fragment box](#fragment-box)es
generated by an element. The argument to the pseudo-element takes the
same syntax as the argument to the :nth-child() pseudo-class defined in
[\[SELECT\]](#biblio-select "Selectors Level 3"),
and has the same meaning except that the number is relative to [fragment
box]es generated by the element instead of
siblings of the element.

 Selectors that allow addressing fragments by counting
from the end rather than the start are intentionally not provided. Such
selectors would interfere with determining the number of fragments.

Depending on future discussions, this
[::nth-fragment(`an+b`)] syntax may be replaced with
the new [::fragment:nth(`an+b`)] syntax.

#### [ Styling of fragments]
Should this apply to continue:fragments
only, or also to continue:paginate? (If it applies, then stricter
property restrictions would be needed for continue:paginate.)

In the absence of rules with
[::nth-fragment()](#selectordef-nth-fragment)
[pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element), the computed style for each [fragment
box](#fragment-box) is the
computed style for the element for which the [fragment
box] was created. However, the style for a
[fragment box] is also influenced by rules
whose selector's
[subject](https://drafts.csswg.org/selectors-4/#selector-subject) has an
[::nth-fragment()]
pseudo-element, if the 1-based number of the [fragment
box] matches that
[::nth-fragment()]
pseudo-element and the selector (excluding the
[::nth-fragment()]
pseudo-element) matches the element generating the fragments.

When determining the style of the [fragment
box](#fragment-box), these
rules that match the fragment pseudo-element cascade together with the
rules that match the element, with the fragment pseudo-element adding
the specificity of a pseudo-class to the specificity calculation.
[(#issue-40daaa94)Does this need to be specified in the
cascading module as well?]

``` highlight
<!DOCTYPE HTML>
<style>
 .bouncy-columns {
 continue: fragments;
 width: 6em;
 height: 10em;
 float: left;
 margin: 1em;
 font: medium/1.25 Times New
 Roman, Times, serif;
 }
 .bouncy-columns::nth-fragment(1) {
 background: aqua; color: black;
 transform: rotate(-3deg);
 }
 .bouncy-columns::nth-fragment(2) {
 background: yellow; color: black;
 transform: rotate(3deg);
 }
</style>
<div class="bouncy-columns">
 ...
</div>
```

In this\
example, the\
text in the div\
is broken into\
a series of\
columns. The\
author\
probably

intended the\
text to fill two\
columns. But\
if it happens to\
fill three\
columns, the\
third column is\
still created. It

::: bouncy-columns-demo
just doesn't\
have any\
fragment-specific\
styling because\
the author\
didn't give it\
any.

Styling an
[::nth-fragment()](#selectordef-nth-fragment)
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) with the
[continue](https://drafts.csswg.org/css-overflow-4/#propdef-continue) property does take effect; if a
[fragment box](#fragment-box)
has a computed value of [continue] other than
[fragments](#valdef-continue-fragments) then that fragment box is the last fragment.
However, overriding [continue] on
the first fragment does not cause the [fragment
box] not to exist; whether there are fragment
boxes at all is determined by the computed value of overflow for the
element.

Styling an
[::nth-fragment()](#selectordef-nth-fragment) pseudo-element with the
[content](https://drafts.csswg.org/css-content-3/#propdef-content) property has no effect; the
computed value of [content] for the
fragment box remains the same as the computed value of content for the
element.

Specifying [display:
none](https://drafts.csswg.org/css-display-4/#propdef-display) for a [fragment
box](#fragment-box) causes the
fragment box with that index not to be generated. However, in terms of
the indices used for matching
[::nth-fragment()](#selectordef-nth-fragment) pseudo-elements of later fragment boxes, it
still counts as though it was generated. However, since it is not
generated, it does not contain any content.

Specifying other values of
[display](https://drafts.csswg.org/css-display-4/#propdef-display),
[position](https://drafts.csswg.org/css-position-3/#propdef-position), or
[float](https://drafts.csswg.org/css2/#propdef-float) is permitted, but is not allowed to
change the [inner display
type](https://drafts.csswg.org/css-display-4/#inner-display-type). (Since
[continue](https://drafts.csswg.org/css-overflow-4/#propdef-continue) only applies to block containers,
flex containers, and grid containers).
[(#issue-d723335f)Need to specify exactly how this
works]

To match the model for other
[pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element) where the pseudo-elements live inside their
corresponding element, declarations in
[::nth-fragment()](#selectordef-nth-fragment) pseudo-elements override declarations in rules
without the pseudo-element. The relative priority within such
declarations is determined by normal cascading order (see
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")).

Styles specified on
[::nth-fragment()](#selectordef-nth-fragment) pseudo-elements do affect inheritance to content
within the [fragment box](#fragment-box). In other words, the content within the [fragment
box] must inherit from the fragment box's style
(i.e., the pseudo-element style) rather than directly from the element.
This means that elements split between fragment boxes may have different
styles for different parts of the element.

This inheritance rule allows specifying
styles indirectly (by using explicit
[inherit](https://drafts.csswg.org/css-cascade-5/#valdef-all-inherit) or using default inheritance on properties that
don't apply to
[::first-letter](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-letter)) that can't be specified directly (based on the
rules in the next section). This is a problem. The restrictions that
apply to styling inside fragments should also apply to inheritance from
fragments.

``` highlight
<!DOCTYPE HTML>
<style>
 .article {
 continue: fragments;
 }
 .article::nth-fragment(1) {
 font-size: 1.5em;
 margin-bottom: 1em;
 height: 4em;
 }
 .article::nth-fragment(2) {
 margin-left: 5em;
 margin-right: 2em;
 }
</style>
<div class="article">
 The <code>font-size</code> property...
</div>
```

The `font-size` property\
specified on the fragment\
is inherited into the

descendants of the fragment.\
This means that inherited\
properties can be used\
reliably on a fragment, as in\
this example.

#### [Styling inside fragments]
Should this apply to continue:fragments
only, or also to continue:paginate?

The
[::nth-fragment()](#selectordef-nth-fragment)
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) can also be used to style content inside of a [fragment
box](#fragment-box). Unlike the
[::first-line](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-line) and
[::first-letter](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-letter) pseudo-elements, the
[::nth-fragment()]
pseudo-element can be applied to parts of the selector other than the
subject: in particular, it can match ancestors of the subject. However,
the only CSS properties applied by rules with such selectors are those
that apply to the [::first-letter] pseudo-element.

To be more precise, when a rule's selector has
[::nth-fragment()](#selectordef-nth-fragment) pseudo-elements attached to parts of the
selector other than the subject, the declarations in that rule apply to
a fragment (or pseudo-element thereof) when:

1. the declarations are for properties that apply to the
 [::first-letter](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-letter) pseudo-element,

2. the declarations would apply to that fragment (or pseudo-element
 thereof) had those
 [::nth-fragment()](#selectordef-nth-fragment) pseudo-elements been removed, with a
 particular association between each sequence of simple selectors and
 the element it matched, and

3. for each removed
 [::nth-fragment()](#selectordef-nth-fragment) pseudo-element, the fragment lives within a
 [fragment box](#fragment-box) of the element associated in that association with
 the selector that the pseudo-element was attached to, and whose
 index matches the pseudo-element.

``` highlight
<!DOCTYPE HTML>
<style>
 .dark-columns {
 continue: fragments;
 width: 6em;
 height: 10em;
 float: left;
 margin-right: 1em;
 font: medium/1.25 Times New
 Roman, Times, serif;
 }
 .dark-columns::nth-fragment(1) {
 background: aqua; color: black;
 }
 .dark-columns::nth-fragment(1) :link {
 color: blue;
 }
 .dark-columns::nth-fragment(1) :visited {
 color: purple;
 }
 .dark-columns::nth-fragment(2) {
 background: navy; color: white;
 }
 .dark-columns::nth-fragment(2) :link {
 color: aqua;
 }
 .dark-columns::nth-fragment(2) :visited {
 color: fuchsia;
 }
</style>
<div class="dark-columns">
 ...
</div>
```

In this\
[example](http://en.wiktionary.org/wiki/example), the\
text flows\
from one\
light-colored\
fragment into\
another\
dark-colored

fragment. We\
therefore want\
different styles\
for [hyperlinks](http://www.w3.org/Provider/Style/IntoContext.html)\
in the different\
fragments.

## [ Appendix C: Privacy Considerations]
This specification introduces no new privacy considerations.

## [ Appendix D: Security Considerations]
This specification introduces no new security considerations.

## [ Changes Since Level 4]
TBD

## [ Acknowledgments]
Thanks especially to the feedback from Rossen Atanassov, Bert Bos,
Tantek Çelik, John Daggett, fantasai, Daniel Glazman, Vincent Hardy,
Håkon Wium Lie, Peter Linss, Robert O'Callahan, Florian Rivoal, Alan
Stearns, Steve Zilles, and all the rest of the
[www-style](http://lists.w3.org/Archives/Public/www-style/) community.
