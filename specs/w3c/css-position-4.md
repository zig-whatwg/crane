## 1. Introduction

This is an early delta spec over
[\[css-position-3\]](#biblio-css-position-3 "CSS Positioned Layout Module Level 3").

## 2. Scrollable Containing Block

When a [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) establishes an [absolute positioning containing
block](https://drafts.csswg.org/css-position-3/#absolute-positioning-containing-block) for an [absolutely positioned
box](https://drafts.csswg.org/css-position-3/#absolute-position), one of three possible [containing
blocks](https://drafts.csswg.org/css-display-4/#containing-block) are used:

[fixed containing block]

: The [fixed containing
 block](#fixed-containing-block) of a [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) corresponds to the
 [scrollport](https://drafts.csswg.org/css-overflow-3/#scrollport), i.e. the inner [padding
 box](https://drafts.csswg.org/css-box-4/#padding-box) edges of the [scroll
 container], but scrolling with the outer
 context, not the [scroll container]'s
 contents.

 The [fixed containing
 block](#fixed-containing-block) established by the document is the [fixed
 positioning containing
 block](https://drafts.csswg.org/css-position-3/#fixed-positioning-containing-block).

[local containing block]

: The [local containing
 block](#local-containing-block) of a [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) corresponds to the [padding
 box](https://drafts.csswg.org/css-box-4/#padding-box) edges of the [scroll
 container], but is affixed to the
 [scrollable overflow
 area](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow-region), and scrolls with the [scroll
 container]'s contents.

 The [local containing
 block](#local-containing-block) established by the document is the [initial
 containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block).

[scrollable containing block]

: The [scrollable containing
 block](#scrollable-containing-block) of a [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) corresponds to the [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge) of the [scroll
 container]'s [scrollable overflow
 area](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow-region), i.e. the outer edge of the
 [padding](https://drafts.csswg.org/css-box-4/#padding) surrounding its content when determining the extent
 of its [scrollable overflow
 area]. See [CSS Overflow 3
 § 2.2 Scrollable
 Overflow](https://drafts.csswg.org/css-overflow-3/#scrollable). In
 all cases the [scrollable containing
 block] at least encompasses
 the [local containing
 block](#local-containing-block).

 This includes floats, but ignores absolutely
 positioned descendants, content overflowing descendant boxes, and
 the effects of relative positioning and transforms, which do
 otherwise extend the scrollable area to display them.

 The [scrollable containing
 block](#scrollable-containing-block) established by the document is the union of the
 [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block) and the [margin
 box](https://drafts.csswg.org/css-box-4/#margin-box) of the [root
 element](https://drafts.csswg.org/css-display-4/#root-element)'s generated
 [box](https://drafts.csswg.org/css-display-4/#box).

 While all of these are in some sense corresponding to
the [padding
box](https://drafts.csswg.org/css-box-4/#padding-box), they do not coincide for boxes with [scrollable
overflow](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow).

Figure out the exact concepts needed for
top layer. They probably want to do something a tiny bit different,
specific to their layer.

Unless otherwise specified, absolutely positioned boxes use the [local
containing
block](#local-containing-block). Certain CSS features can specify a different
[containing
block](https://drafts.csswg.org/css-display-4/#containing-block). For example, [fixed-positioned
boxes](https://drafts.csswg.org/css-position-3/#fixed-position) typically use the document's [fixed containing
block](#fixed-containing-block), and
[position-area](https://drafts.csswg.org/css-anchor-position-1/#propdef-position-area) values other than
[none](https://drafts.csswg.org/css-anchor-position-1/#valdef-position-area-none) can opt absolutely positioned boxes into the
[scrollable containing
block](#scrollable-containing-block).

 There is not currently any way to refer to a [fixed
containing
block](#fixed-containing-block) other than the [fixed positioning containing
block](https://drafts.csswg.org/css-position-3/#fixed-positioning-containing-block), but one might be added in the future.

## 3. Top Layer

[`Document`](https://dom.spec.whatwg.org/#document)s have a [top layer], an [ordered
set](https://infra.spec.whatwg.org/#ordered-set) containing
[elements](https://dom.spec.whatwg.org/#concept-element) from the document. Elements in the [top
layer](#document-top-layer)
do not lay out normally based on their position in the document; instead
they generate
[boxes](https://drafts.csswg.org/css-display-4/#box) as if they were siblings of the root element. [Top
layer] elements are rendered in the order
they appear in the [top layer]; the last
element in the [top layer] is rendered on
top of everything else.

 This special rendering behavior ensures that elements
in the [top layer](#document-top-layer) cannot be clipped by anything in the document, or
obscured by anything except elements later in the [top
layer]. This ensures that things like
[popovers](https://html.spec.whatwg.org/multipage/popover.html#the-popover-attribute)
can be displayed reliably, regardless of what their ancestor elements
might be doing.

The [top layer root] of an element is its nearest ancestor element that is in the
[top layer](#document-top-layer), or none otherwise (in which case it's painted as part
of the document as normal).

Two elements are [in the same top layer] if they have the same [top layer
root](#top-layer-root)
(including if both are none). An element A is [in a higher top
layer] than an element B if A
has a [top layer root], and either B has a
[top layer root] earlier in the [top
layer](#document-top-layer) than A's, or B doesn't have a [top layer
root] at all.

 The [top
layer](#document-top-layer) is managed entirely by the [user
agent](https://infra.spec.whatwg.org/#user-agent); it cannot be directly manipulated by authors. This
ensures that \"nested\" invocations of top-layer-using APIs, like a
popup within a popup, will display correctly.

 The [top
layer](#document-top-layer) interacts with the
[overlay](#propdef-overlay) property in a somewhat unusual way. See
[overlay] for details.

[`Document`](https://dom.spec.whatwg.org/#document)s also have a [pending top layer
removals] [ordered
set](https://infra.spec.whatwg.org/#ordered-set), containing elements that are pending removal. (See the
algorithms, below, for details on how this is used.)

The [top layer](#document-top-layer) (and the [pending top layer
removals](#pending-top-layer-removals)) should not be interacted with directly by
specification algorithms. (Individual features using the [top
layer] might have ownership over various
things in the top layer, like a popover inside of a popover, that need
to be reordered or moved as a group.) Instead, specifications should use
the following algorithms.

### 3.1. Top Layer Styling

Every element [rendered in the top
layer](#render-in-the-top-layer), as well as its corresponding
[::backdrop](#selectordef-backdrop) pseudo-element, are rendered with the following
qualities:

- It generates a new [stacking
 context](https://www.w3.org/TR/CSS2/visuren.html#x43).

- Its parent stacking context is the root stacking context.

- It is rendered as an atomic unit as if it were a sibling of the
 document's root.

 Ancestor elements with
 [overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow),
 [opacity](https://drafts.csswg.org/css-color-4/#propdef-opacity),
 [mask](https://drafts.csswg.org/css-masking-1/#propdef-mask), etc. cannot affect it.

- If its
 [position](https://drafts.csswg.org/css-position-3/#propdef-position) property computes to
 [fixed](https://drafts.csswg.org/css-position-3/#valdef-position-fixed), its containing block is the viewport;
 otherwise, it's the initial containing block.

- If it is an element, it and its
 [::backdrop](#selectordef-backdrop) pseudo-element are [not
 rendered](https://drafts.csswg.org/css-images-4/#element-not-rendered) if its [shadow-including inclusive
 ancestor](https://dom.spec.whatwg.org/#concept-shadow-including-inclusive-ancestor) has the [display:
 none](https://drafts.csswg.org/css-display-4/#propdef-display).

- If its specified
 [display](https://drafts.csswg.org/css-display-4/#propdef-display) property is
 [contents](https://drafts.csswg.org/css-display-4/#valdef-display-contents), it computes to
 [block](https://drafts.csswg.org/css-display-4/#valdef-display-block).

- If its specified
 [position](https://drafts.csswg.org/css-position-3/#propdef-position) property is not
 [absolute](https://drafts.csswg.org/css-position-3/#valdef-position-absolute) or
 [fixed](https://drafts.csswg.org/css-position-3/#valdef-position-fixed), it computes to
 [absolute].

- Unless overridden by another specification, its static position for
 left, right, and top is zero.

### 3.2. The [::backdrop Pseudo-Element]
Each element [rendered in the top
layer](#render-in-the-top-layer) has a [::backdrop] pseudo-element, for which it
is the [originating
element](https://drafts.csswg.org/selectors-4/#originating-element).

When its computed
[content](https://drafts.csswg.org/css-content-3/#propdef-content) value is not
[none](https://drafts.csswg.org/css-content-3/#valdef-content-none),
[::backdrop](#selectordef-backdrop) pseudo-elements generate boxes as if they were
siblings of the root element. They're automatically rendered as a
separate item in the [top
layer](#document-top-layer), below their [originating
element](https://drafts.csswg.org/selectors-4/#originating-element). (See \"[paint a
document](#paint-a-document)\" for details.)

 The
[::backdrop](#selectordef-backdrop) pseudo-element can be used to create a backdrop that
hides the underlying document for an element in a top layer (such as an
element that is displayed fullscreen).

The [::backdrop](#selectordef-backdrop) pseudo-element is a [fully styleable
pseudo-element](https://drafts.csswg.org/css-pseudo-4/#fully-styleable).

User agents should contain the following rules in a UA-level style
sheet:

``` highlight
::backdrop {
 position: fixed;
 inset: 0;
}
```

Other specifications can additional properties to the default
[::backdrop](#selectordef-backdrop) rendering.

 For example, a fullscreen element (see
[\[FULLSCREEN\]](#biblio-fullscreen "Fullscreen API Standard"))
styles its
[::backdrop](#selectordef-backdrop) as opaque black by default.

See [§ 3.1 Top Layer Styling](#top-styling) for additional details on
how [::backdrop](#selectordef-backdrop) elements are rendered.

### 3.3. Top Layer Manipulation

An element `el` is [in the top layer] if `el` is
[contained](https://infra.spec.whatwg.org/#list-contain) in its [node
document's](https://dom.spec.whatwg.org/#concept-node-document) [top
layer](#document-top-layer) but *not* [contained] in its
[node document's] [pending top layer
removals](#pending-top-layer-removals).

 Specs should use this concept, rather than [rendered in
the top
layer](#render-in-the-top-layer), when they are manipulating the top layer itself. Using
this concept avoids the behavior being different based on whether
there's an [overlay](#propdef-overlay) transition, or whether two operations
happened *between* rendering updates or *across* them.

An element `el` is [rendered in the top
layer] if `el` is
[contained](https://infra.spec.whatwg.org/#list-contain) in its [node
document's](https://dom.spec.whatwg.org/#concept-node-document) [top
layer](#document-top-layer), and `el` has [overlay:
auto](#propdef-overlay).

 Specs should use this concept, rather than [in the top
layer](#in-the-top-layer),
when they are not manipulating the top layer itself, but rather
responding to the rendering behavior of being \"on top of everything\".
For example, the presence of a
[::backdrop](#selectordef-backdrop) pseudo relies on the element being [rendered in the
top layer](#render-in-the-top-layer); even if the element is [pending
removal](#pending-top-layer-removals), it has a [::backdrop] as long as it's being displayed on top of everything.

To [add an element to the top layer], given an
[`Element`](https://dom.spec.whatwg.org/#element) `el`:

1. Let `doc` be `el`'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document).

2. If `el` is already
 [contained](https://infra.spec.whatwg.org/#list-contain) in `doc`'s [top
 layer](#document-top-layer):

 - Assert: `el` is also in `doc`'s [pending top
 layer
 removals](#pending-top-layer-removals). (Otherwise, this is a spec error.)

 - [Remove](https://infra.spec.whatwg.org/#list-remove) `el` from both `doc`'s [top
 layer](#document-top-layer) and [pending top layer
 removals](#pending-top-layer-removals).

3. [Append](https://infra.spec.whatwg.org/#set-append) `el` to `doc`'s [top
 layer](#document-top-layer).

4. At the UA !important [cascade
 origin](https://drafts.csswg.org/css-cascade-6/#origin), add a rule targeting `el` containing an
 [overlay: auto](#propdef-overlay) declaration.

To [request an element to be removed from the top
layer],
given an
[`Element`](https://dom.spec.whatwg.org/#element) `el`:

1. Let `doc` be `el`'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document).

2. If `el` is not
 [contained](https://infra.spec.whatwg.org/#list-contain) `doc`'s [top
 layer](#document-top-layer), or `el` *is* already
 [contained] in `doc`'s [pending
 top layer
 removals](#pending-top-layer-removals), return.

3. Remove the UA !important [overlay:
 auto](#propdef-overlay) rule targeting `el`.

4. [Append](https://infra.spec.whatwg.org/#set-append) `el` to `doc`'s [pending top
 layer
 removals](#pending-top-layer-removals).

To [remove an element from the top layer
immediately],
given an
[`Element`](https://dom.spec.whatwg.org/#element) `el`:

1. Let `doc` be `el`'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document).

2. [Remove](https://infra.spec.whatwg.org/#list-remove) `el` from `doc`'s [top
 layer](#document-top-layer) and [pending top layer
 removals](#pending-top-layer-removals).

3. Remove the UA !important [overlay:
 auto](#propdef-overlay) rule targeting `el`, if it exists.

 This algorithm is only intended to be used in special
cases where removing something from the top layer immediately (bypassing
things like an [overlay](#propdef-overlay) transition) is necessary, such as a
modal dialog that is removed from the document. Most of the time,
[requesting removal from the top
layer](#request-an-element-to-be-removed-from-the-top-layer) is more appropriate.

To [process top layer removals], given a
[`Document`](https://dom.spec.whatwg.org/#document) `doc`:

1. For each element `el` in `doc`'s [pending top
 layer
 removals](#pending-top-layer-removals): if `el`\'s computed value of
 [overlay](#propdef-overlay) is
 [none](#valdef-overlay-none), or `el` is [not
 rendered](https://drafts.csswg.org/css-images-4/#element-not-rendered), [remove from the top layer
 immediately](#remove-an-element-from-the-top-layer-immediately) `el`.

 This is intended to be called during the \"Update the
Rendering\" step of HTML's rendering algorithm. It is not intended to be
called by other algorithms.

 The
[overlay](#propdef-overlay) check can be delayed arbitrarily long by
author-level transitions; see [§ 3.4 Controlling the Top Layer: the
overlay property](#overlay) for details.

### 3.4. Controlling the Top Layer: the [overlay property]
Name:

[overlay]

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

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see prose

When an element is [in the top
layer](#in-the-top-layer),
the [overlay](#propdef-overlay) property determines whether it is
actually [rendered in the top
layer](#render-in-the-top-layer) or not.

[none]

: The element isn't [rendered in the top
 layer](#render-in-the-top-layer).

[auto]

: The element is [rendered in the top
 layer](#render-in-the-top-layer) if it is [in the top
 layer](#in-the-top-layer).

 Rather than generating boxes as part of its normal position in the
 document, it generates boxes as a sibling of the root element,
 rendered \"above\" it.

Note:
[overlay](#propdef-overlay) is a somewhat unusual property, as it is *only*
set by the user agent, and can't be set by authors *at all*.

However, authors *do* have the ability to affect *when*
[overlay](#propdef-overlay) changes its value, by setting a
[transition](https://drafts.csswg.org/css-transitions-1/#propdef-transition) on the property. This allows an
author to align an animation with the transition, with the element
moving in or out of the top layer only at the desired point in the
animation. This allows, for example, an animation that causes an element
to fade out of its normal position on the page, then fade in at its new
top-layer position, or vice versa.

For animation, [auto](#valdef-overlay-auto) is
[interpolated](https://drafts.csswg.org/css-values-4/#interpolation) as a discrete step where values of p such that
`0 < p < 1` map to [auto] and other
values of p map to the closer endpoint; if neither value is
[auto] then discrete animation is
used.

 This is similar to how
[visibility](https://drafts.csswg.org/css-display-4/#propdef-visibility) animates. With most [easing
functions](https://drafts.csswg.org/css-easing-2/#easing-function), this will keep the element [rendered in the top
layer](#render-in-the-top-layer) for the entire duration of the transition, whether it's
entering or leaving the top layer.
[step-start](https://drafts.csswg.org/css-easing-2/#valdef-step-easing-function-step-start)/[step-end](https://drafts.csswg.org/css-easing-2/#valdef-step-easing-function-step-end)/[linear()](https://drafts.csswg.org/css-easing-2/#funcdef-linear) can be used to control when the value flips more
precisely.

User agents must have the following rule in their UA stylesheet:

``` highlight
* { overlay: none !important; }
```

 This means that the
[overlay](#propdef-overlay) property *cannot be set by authors or users*---​it
is entirely controlled by the user agent (which sets elements to
[overlay: auto], via another
UA-!important rule, when they're in the [top
layer](#document-top-layer)).

User agents *may*, at their discretion, remove a running
[transition](https://drafts.csswg.org/css-transitions-1/#transitions) on
[overlay](#propdef-overlay). The conditions for this are intentionally
undefined. [(This is to prevent potential abuse scenarios where a
[transition: overlay
1e9s;](https://drafts.csswg.org/css-transitions-1/#propdef-transition) or similar attempts to keep an element in the
[top layer](#document-top-layer) permanently.)]

## 4. Painting Order and Stacking Contexts

This chapter describes the painting order of CSS's [box
tree](https://drafts.csswg.org/css-display-4/#box-tree).

When traversing the [box
tree](https://drafts.csswg.org/css-display-4/#box-tree), [tree
order](https://dom.spec.whatwg.org/#concept-tree-order) is often used. For
[fragments](https://drafts.csswg.org/css-break-4/#fragment), this refers to the logical order of the fragments, not
the visual order. (This can be relevant, for example, when rending
bidirectional text.)

Painting order is defined in terms of a \"painter's model\", where
elements are described as painting in a stack, with the bottom of the
stack rendered \"first\", below items higher in the stack. The user is
implied to exist above the top of the stack, looking down:

``` ascii-art
 | | |
 | | | ⇦ 🧑‍🎨
 | | user
z-index: canvas -1 0 1
```

The stacking context background and most negative positioned stacking
contexts are at the bottom of the stack, while the most positive
positioned stacking contexts are at the top of the stack.

The canvas is transparent if contained within another, and given a
UA-defined color if it is not. It is infinite in extent and contains the
root element. Initially, the viewport is anchored with its top left
corner at the canvas origin.

To [paint a document], given a document `doc` and an infinite canvas
`canvas`:

1. [Paint a stacking
 context](#paint-a-stacking-context) given `doc`'s root element and
 `canvas`.

2. For each element `el` in `doc`'s [top
 layer](#document-top-layer):

 1. [Paint a stacking
 context](#paint-a-stacking-context) given `el`\'s
 [::backdrop](#selectordef-backdrop) pseudo-element and `canvas`.

 2. [Paint a stacking
 context](#paint-a-stacking-context) given `el` and `canvas`,
 treating `el` as a [stacking
 context](https://www.w3.org/TR/CSS2/visuren.html#x43), with the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block) as its [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block).

To [paint a stacking context] given an
[element](https://dom.spec.whatwg.org/#concept-element),
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element), or
[box](https://drafts.csswg.org/css-display-4/#box) `root`, and an infinite canvas
`canvas`:

1. If `root` is an
 [element](https://dom.spec.whatwg.org/#concept-element), [paint a stacking
 context](#paint-a-stacking-context) given `root`'s [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) and `canvas`, then return.

2. Assert: `root` is a
 [box](https://drafts.csswg.org/css-display-4/#box), and generates a [stacking
 context](https://www.w3.org/TR/CSS2/visuren.html#x43).

3. If `root` is a [root
 element's](https://drafts.csswg.org/css-display-4/#root-element) [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box), paint `root`'s background over the
 entire `canvas`, with the origin of the background
 positioning area being the position on `canvas` that
 would be used if `root`'s background was being painted
 normally.

4. If `root` is a [block-level
 box](https://drafts.csswg.org/css-display-4/#block-level-box), [paint a block's
 decorations](#paint-a-blocks-decorations) given `root` and `canvas`.

5. For each of `root`'s positioned descendants with negative
 (non-zero)
 [z-index](https://drafts.csswg.org/css2/#propdef-z-index) values, sort those descendants
 by [z-index] order (most
 negative first) then [tree
 order](https://dom.spec.whatwg.org/#concept-tree-order), and [paint a stacking
 context](#paint-a-stacking-context) given each descendant and `canvas`.

6. For each of `root`'s
 [in-flow](https://drafts.csswg.org/css-display-4/#in-flow), non-positioned, block-level descendants, in [tree
 order](https://dom.spec.whatwg.org/#concept-tree-order), [paint a block's
 decorations](#paint-a-blocks-decorations) given the descendant and `canvas`.

7. For each of `root`'s non-positioned floating descendants,
 in tree order, [paint a stacking
 container](#paint-a-stacking-container) given the descendant and `canvas`.

8.

 If `root` is an [inline-level](https://drafts.csswg.org/css-display-4/#inline-level) box

 : For each line box `root` is in, [paint a box in a
 line
 box](#paint-a-box-in-a-line-box) given `root`, the line box, and
 `canvas`.

 Otherwise

 : First for `root`, then for all its
 [in-flow](https://drafts.csswg.org/css-display-4/#in-flow), non-positioned,
 [block-level](https://drafts.csswg.org/css-display-4/#block-level) descendant boxes, in [tree
 order](https://dom.spec.whatwg.org/#concept-tree-order):

 1. If the box is a [replaced
 element](https://drafts.csswg.org/css-display-4/#replaced-element), paint the replaced content into
 `canvas`, atomically.

 2. Otherwise, for each line box of the box, [paint a box in a
 line
 box](#paint-a-box-in-a-line-box) given the box, the line box, and
 `canvas`.

 3. If the UA uses [in-band
 outlines](#in-band-outline), paint the outlines of the box into
 `canvas`.

9. For each of `root`'s positioned descendants with
 [z-index:
 auto](https://drafts.csswg.org/css2/#propdef-z-index) or [z-index: 0], in [tree
 order](https://dom.spec.whatwg.org/#concept-tree-order):

 descendant has [z-index: auto](https://drafts.csswg.org/css2/#propdef-z-index)

 : [Paint a stacking
 container](#paint-a-stacking-container) given the descendant and `canvas`.

 descendant has [z-index: 0](https://drafts.csswg.org/css2/#propdef-z-index)

 : [Paint a stacking
 context](#paint-a-stacking-context) given the descendant and `canvas`.

10. For each of `root`'s positioned descendants with positive
 (non-zero)
 [z-index](https://drafts.csswg.org/css2/#propdef-z-index) values, sort those descendants
 by [z-index] order (smallest
 first) then [tree
 order](https://dom.spec.whatwg.org/#concept-tree-order), and [paint a stacking
 context](#paint-a-stacking-context) given each descendant and `canvas`.

11. If the UA uses [out-of-band
 outlines](#out-of-band-outline), draw all of `root`'s outlines (those
 that it skipped drawing due to not using [in-band
 outlines](#in-band-outline) during the current invocation of this algorithm)
 into `canvas`.

To [paint a block's decorations] given a block box
`root` and a canvas `canvas`:

1. If `root` is not a [table wrapper
 box](https://drafts.csswg.org/css-tables-3/#table-wrapper-box):

 1. Paint `root`'s background to `canvas` if
 it is not the [root
 element's](https://drafts.csswg.org/css-display-4/#root-element) [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box).

 2. Paint `root`'s border to `canvas`.

2. If `root` is a [table wrapper
 box](https://drafts.csswg.org/css-tables-3/#table-wrapper-box):

 1. Paint `root`'s background to `canvas` if
 it is not the [root
 element's](https://drafts.csswg.org/css-display-4/#root-element) [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box).

 2. For each column group of `root` in [tree
 order](https://dom.spec.whatwg.org/#concept-tree-order), paint the column group's background to
 `canvas`.

 3. For each column of `root` in [tree
 order](https://dom.spec.whatwg.org/#concept-tree-order), paint the column's background to
 `canvas`.

 4. For each row group of `root` in [tree
 order](https://dom.spec.whatwg.org/#concept-tree-order), paint the row group's background to
 `canvas`.

 5. For each row of `root` in [tree
 order](https://dom.spec.whatwg.org/#concept-tree-order), paint the row's background to
 `canvas`.

 6. For each cell of `root` in [tree
 order](https://dom.spec.whatwg.org/#concept-tree-order), paint the cell's background to
 `canvas`.

 7. Paint the borders of all of the table elements of
 `root`. If the borders are separated, do so in [tree
 order](https://dom.spec.whatwg.org/#concept-tree-order); if connected, do so as specified in
 [\[css-tables-3\]](#biblio-css-tables-3 "CSS Table Module Level 3").

To [paint a box in a line box], given a box `root`, a
line box `line box`, and a canvas `canvas`:

1. Paint the backgrounds of `root`'s
 [fragments](https://drafts.csswg.org/css-break-4/#fragment) that are in `line box` into
 `canvas`.

2. Paint the borders of `root`'s
 [fragments](https://drafts.csswg.org/css-break-4/#fragment) that are in `line box` into
 `canvas`.

3.

 If `root` is an [inline box](https://drafts.csswg.org/css-display-4/#inline-box)

 : For all `root`'s
 [in-flow](https://drafts.csswg.org/css-display-4/#in-flow), non-positioned, inline-level children that
 generate
 [fragments](https://drafts.csswg.org/css-break-4/#fragment) in `line box`, and all child [text
 sequences](https://drafts.csswg.org/css-display-4/#css-text-sequence) that generate [fragments]
 in `line box`, in [tree
 order](https://dom.spec.whatwg.org/#concept-tree-order):

 If this child is a [text sequence](https://drafts.csswg.org/css-display-4/#css-text-sequence), then:

 : 1. Paint any underlining affecting the text, in tree order
 of the elements applying the underlining (such that the
 deepest element's underlining, if any, is painted
 topmost and the root element's underlining, if any, is
 drawn bottommost) into `canvas`.

 2. Paint any overlining affecting the text, in tree order
 of the elements applying the overlining (such that the
 deepest element's overlining, if any, is painted topmost
 and the root element's overlining, if any, is drawn
 bottommost) into `canvas`.

 3. Paint the text into `canvas`.

 4. Paint any line-through affecting the text, in tree order
 of the elements applying the line-through (such that the
 deepest element's line-through, if any, is painted
 topmost and the root element's line-through, if any, is
 drawn bottommost) into `canvas`.

 If this child is a [box](https://drafts.csswg.org/css-display-4/#box):

 : [Paint a box in a line
 box](#paint-a-box-in-a-line-box) given the child, `line box`, and
 `canvas`.

 If `root` is an [inline-level](https://drafts.csswg.org/css-display-4/#inline-level) [block](https://drafts.csswg.org/css-display-4/#block-box) or [table wrapper box](https://drafts.csswg.org/css-tables-3/#table-wrapper-box)

 : [Paint a stacking
 container](#paint-a-stacking-container) given `root` and
 `canvas`.

 If `root` is an [inline-level](https://drafts.csswg.org/css-display-4/#inline-level) replaced element

 : Paint the replaced content into `canvas`, atomically.

4. If the UA uses [in-band
 outlines](#in-band-outline), paint the outlines of `root`'s
 [fragments](https://drafts.csswg.org/css-break-4/#fragment) that are in `line box` into
 `canvas`.

 Even though the visual order of inline box fragments
can be rearranged within a line due to [bidirectional
reordering](https://drafts.csswg.org/css-writing-modes-3/#bidi-box-model),
the fragments are nevertheless painted in tree order.

To [paint a stacking container], given a
[box](https://drafts.csswg.org/css-display-4/#box) `root` and a canvas `canvas`:

1. [Paint a stacking
 context](#paint-a-stacking-context) given `root` and `canvas`,
 treating `root` as if it created a new stacking context,
 but omitting any positioned descendants or descendants that actually
 create a stacking context (letting the parent stacking context paint
 them, instead).

UAs can draw outlines (from the
[outline](https://drafts.csswg.org/css-ui-4/#propdef-outline) property) either
[in-band] (painted along each element, and thus potentially
obscured/overlapping by following content) or
[out-of-band] (all outlines painted at the end of
the stacking context, so nothing in the stacking context can obscure
them). It is recommended that UAs use [out-of-band
outlines](#out-of-band-outline), as making outlines easily visible is an important
accessibility feature.

## 5. Changes

Significant changes since the [8 July 2025 First Public Working
Draft](https://www.w3.org/TR/2025/WD-css-position-4-20250708/):

- None (markup and linking fixes only).

## [Privacy Considerations]
No new privacy considerations have been reported on this specification.

## [Security Considerations]
No new security considerations have been reported on this specification.
