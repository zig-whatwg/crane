## 1. Introduction

CSS [absolute
positioning](https://www.w3.org/TR/css-position-3/#absolute-position) allows authors to place boxes anywhere on the page,
without regard to the layout of other boxes besides their containing
block. This flexibility can be very useful, but also very
limiting---​often you want to position relative to *some* other box.
[Anchor positioning] (via the
[position-anchor](#propdef-position-anchor) and
[position-area](#propdef-position-area) properties and/or the [anchor
functions]
[anchor()](#funcdef-anchor) and
[anchor-size()](#funcdef-anchor-size)) allows authors to achieve this, "anchoring" an
[absolutely positioned box] to one or more
other boxes on the page (its [anchor references], while also
allowing them to try several possible positions to find the "best" one
that avoids overlap/overflow.

For example, an author might want to
position a tooltip centered and above the targeted element, unless that
would place the tooltip offscreen, in which case it should be below the
targeted element. This can be done with the following CSS:

```
.anchor {
 anchor-name: --tooltip;
}
.tooltip {
 /* Fixpos means we don't need to worry about
 containing block relationships;
 the tooltip can live anywhere in the DOM. */
 position: fixed;

 /* All the anchoring behavior will default to
 referring to the --tooltip anchor. */
 position-anchor: --tooltip;

 /* Align the tooltip's bottom to the top of the anchor;
 this also defaults to horizontally center-aligning
 the tooltip and the anchor (in horizontal writing modes). */
 position-area: block-start;

 /* Automatically swap if this overflows the window
 so the tooltip's top aligns to the anchor's bottom
 instead. */
 position-try: flip-block;

 /* Prevent getting too wide */
 max-inline-size: 20em;
}
```

Note that using the [Popover
API](https://html.spec.whatwg.org/multipage/popover.html#the-popover-attribute)
will automatically set
[position](https://www.w3.org/TR/css-position-3/#propdef-position) and create the anchoring
relationship without setting
[anchor-name](#propdef-anchor-name) or
[position-anchor](#propdef-position-anchor) value (by defining an [implicit
anchor
element](#implicit-anchor-element)), so those properties wouldn't need to be explicitly
set again. So with the correct markup, this example can be simplified
to:

```
.tooltip {
 /* Using the popover + popovertarget attributes sets 'position: fixed'
 and creates the necessary position-anchor relationship already. */
 position-area: block-start;
 position-try: flip-block;
 max-inline-size: 20em;
}
```

### 1.1. Value Definitions

This specification follows the [CSS property definition
conventions](https://www.w3.org/TR/CSS2/about.html#property-defs) from
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
using the [value definition
syntax](https://www.w3.org/TR/css-values-3/#value-defs) from
[\[CSS-VALUES-3\]](#biblio-css-values-3 "CSS Values and Units Module Level 3").
Value types not defined in this specification are defined in CSS Values
& Units
[\[CSS-VALUES-3\]](#biblio-css-values-3 "CSS Values and Units Module Level 3").
Combination with other CSS modules may expand the definitions of these
value types.

In addition to the property-specific values listed in their definitions,
all properties defined in this specification also accept the [CSS-wide
keywords](https://www.w3.org/TR/css-values-4/#css-wide-keywords) as their property value. For readability they have not
been repeated explicitly.

Like most operations in CSS besides selector matching, features in this
specification operate over the [flattened element
tree](https://drafts.csswg.org/css-shadow-1/#flat-tree).

## 2. Determining the Anchor

Several features of this specification refer to the position and size of
an [anchor box]. Unless otherwise specified, this refers
to the [border
box](https://www.w3.org/TR/css-box-4/#border-box) edge of the [principal
box](https://www.w3.org/TR/css-display-4/#principal-box) of relevant [anchor
element](#anchor-element). In
most cases the relevant [anchor element] is
specified as the [default anchor
element](#default-anchor-element) using the
[position-anchor](#propdef-position-anchor) property, which can refer to an
[implicit anchor
element](#implicit-anchor-element) defined by the host language or an anchor named via the
CSS [anchor-name](#propdef-anchor-name) and
[anchor-scope](#propdef-anchor-scope) properties. (The
[anchor()](#funcdef-anchor) functions can also reference a named anchor
directly.)

The [anchor box](#anchor-box)'s
position and size is determined after layout. This position and size
includes
[zoom](https://drafts.csswg.org/css-viewport/#propdef-zoom) and
[position](https://www.w3.org/TR/css-position-3/#propdef-position)-based adjustments (such as
[position: relative] or [position:
sticky]) as well as transforms (such as
[transform](https://www.w3.org/TR/css-transforms-1/#propdef-transform) or
[offset-path](https://www.w3.org/TR/motion-1/#propdef-offset-path)). In these cases, the axis-aligned
bounding rectangle of the [anchor box] in the
coordinate space of the [absolutely
positioned](https://www.w3.org/TR/css-position-3/#absolute-position) element's [containing
block](https://www.w3.org/TR/css-display-4/#containing-block) is used instead. Transforms are often optimized onto a
different thread, so transform-based updates to an [anchor
box's] position may be delayed by a few frames.
Authors can avoid this delay by using absolute or relative positioning
instead where practical.

If the [anchor box](#anchor-box)
is
[fragmented](https://www.w3.org/TR/css-break-4/#fragment), and the [containing
block](https://www.w3.org/TR/css-display-4/#containing-block) of the [absolutely
positioned](https://www.w3.org/TR/css-position-3/#absolute-position) box referring to that [anchor
box] is outside the relevant [fragmentation
context](https://www.w3.org/TR/css-break-4/#fragmentation-context), the axis-aligned bounding rectangle of its [box
fragments](https://www.w3.org/TR/css-break-4/#box-fragment) is used instead. (If the [absolutely
positioned] box is inside the
[fragmentation context], it sees the
[anchor box] as unfragmented---​and can be itself
fragmented by the [fragmentation
context].)

For performance reasons, scrolling is handled specially, see [§ 3.3
Taking Scroll Into Account](#scroll). Other post-layout effects, such as
filters, do not affect the [anchor
box's](#anchor-box) position.

### 2.1. Creating an Anchor: the [anchor-name property]
Name:

[anchor-name]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://www.w3.org/TR/css-values-4/#comb-one)
[\<anchor-name\>](#typedef-anchor-name)[\#](https://www.w3.org/TR/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements that generate a [principal
box](https://www.w3.org/TR/css-display-4/#principal-box)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

``` prod
<anchor-name> = <dashed-ident>
```

The [anchor-name](#propdef-anchor-name) property declares that an element
is an [anchor element], whose [principal
box](https://www.w3.org/TR/css-display-4/#principal-box) is an [anchor box](#anchor-box), and gives it a list of [anchor names] to be
targeted by. Values are defined as follows:

[none]

: The property has no effect.

[[\<anchor-name\>](#typedef-anchor-name)\#]

: If the element generates a [principal
 box](https://www.w3.org/TR/css-display-4/#principal-box), the element is an [anchor
 element](#anchor-element),
 with a list of [anchor names](#anchor-name) as specified. Each [anchor
 name] is a [loosely
 matched](https://drafts.csswg.org/css-shadow-1/#tree-scoped-name-loosely-matched) [tree-scoped
 name](https://drafts.csswg.org/css-shadow-1/#css-tree-scoped-name).

 Otherwise, the property has no effect.

[Anchor names](#anchor-name) do
not need to be unique. Not all elements are capable of being the [target
anchor element](#target-anchor-element) of a given box. Thus a name can be reused in multiple
places if the usages are scoped appropriately.

 If multiple elements share an [anchor
name](#anchor-name) and are all
visible to a given positioned box, the [target anchor
element](#target-anchor-element) will be the nearest ancestor (if one exists) or else
the last one in DOM order. The
[anchor-scope](#propdef-anchor-scope) property can be used to further
limit what names are visible to a given referencing box.

[Anchor names](#anchor-name) are
*not* scoped by
[containment](https://www.w3.org/TR/css-contain-2/#containment) by default; even if an element has
[style](https://www.w3.org/TR/css-contain-2/#style-containment) or [layout
containment](https://www.w3.org/TR/css-contain-2/#layout-containment) (or any similar sort of containment), the [anchor
names] of its descendants are visible to elements
elsewhere in the page.

 While an element is in the [skipped
contents](https://www.w3.org/TR/css-contain-2/#skips-its-contents) of another element (due to [content-visibility:
hidden](https://www.w3.org/TR/css-contain-2/#propdef-content-visibility), for instance), it's not an [acceptable
anchor
element](#acceptable-anchor-element), effectively acting as if it had no names.

 Positioned elements in [shadow
trees](https://dom.spec.whatwg.org/#concept-shadow-tree) can reference [anchor
names](#anchor-name) defined in
"higher" trees. Currently, they cannot reference [anchor
names] defined in "lower" shadow trees, though.

### 2.2. Scoping Anchor Names: the [anchor-scope property]
Name:

[anchor-scope]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://www.w3.org/TR/css-values-4/#comb-one) all [\|]
[\<anchor-name\>](#typedef-anchor-name)[\#](https://www.w3.org/TR/css-values-4/#mult-comma)

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

discrete

This property scopes the specified [anchor
names](#anchor-name), and lookups
for these [anchor names], to this element's
subtree. See [§ 2 Determining the Anchor](#determining).

Values have the following meanings:

[none]
: No changes in [anchor name](#anchor-name) scope.

[all]

: Specifies that all [anchor
 names](#anchor-name) defined
 by this element or its descendants---​whose scope is not already
 limited by a descendant using
 [anchor-scope](#propdef-anchor-scope)---​to be in scope only for this
 element's descendants; and limits descendants to only match [anchor
 names] to [anchor
 elements](#anchor-element)
 within this subtree.

 This value only affects [anchor
 names](#anchor-name) in the
 same tree scope, as if it were a [strictly
 matched](https://drafts.csswg.org/css-shadow-1/#tree-scoped-name-strictly-matched) [tree-scoped
 name](https://drafts.csswg.org/css-shadow-1/#css-tree-scoped-name). (That is, [anchor-scope:
 all](#propdef-anchor-scope) acts identically to [anchor-scope: \--foo,
 \--bar, \...], listing all
 relevant [anchor names].)

[[\<anchor-name\>](#typedef-anchor-name)]

: Specifies that a matching [anchor
 name](#anchor-name) defined
 by this element or its descendants---​whose scope is not already
 limited by a descendant using
 [anchor-scope](#propdef-anchor-scope)---​to be in scope only for this
 element's descendants; and limits descendants to only match these
 [anchor names] to [anchor
 elements](#anchor-element)
 within this subtree.

 The
 [\<anchor-name\>](#typedef-anchor-name) represents a [strictly
 matched](https://drafts.csswg.org/css-shadow-1/#tree-scoped-name-strictly-matched) [tree-scoped
 name](https://drafts.csswg.org/css-shadow-1/#css-tree-scoped-name), i.e. it can only match against [anchor
 names](#anchor-name) in the
 same shadow
 tree.[\[CSS-SCOPING-1\]](#biblio-css-scoping-1 "CSS Scoping Module Level 1")

This property has no effect on [implicit anchor
elements](#implicit-anchor-element).

 Since ancestors of the positioned element are checked
first, there's usually no need to use
[anchor-scope](#propdef-anchor-scope) if the desired anchor is an
ancestor. It's only needed when the desired anchor is not an ancestor,
or you explicitly want to \"hide\" an anchor from being referenced
elsewhere in the page.

When a design pattern is re-used,
[anchor-scope](#propdef-anchor-scope) can prevent naming clashes across
identical components. For example, if a list contains positioned
elements within each list item, which want to position themselves
relative to the list item they're in,

```
li {
 anchor-name: --list-item;
 anchor-scope: --list-item;
}
li .positioned {
 position: absolute;
 position-anchor: --list-item;
 position-area: inline-start;
}
```

Without
[anchor-scope](#propdef-anchor-scope), all of the
[`li`](https://html.spec.whatwg.org/multipage/grouping-content.html#the-li-element) elements would be visible to all of the positioned
elements, and so they'd all positioned themselves relative to the
*final*
[`li`](https://html.spec.whatwg.org/multipage/grouping-content.html#the-li-element), stacking up on top of each other.

Fix the above example, since the
use-case is now automatic.

### 2.3. Finding an Anchor

Several things in this specification find a [target anchor
element](#target-anchor-element), given an [anchor specifier], which is either a
[\<dashed-ident\>](https://www.w3.org/TR/css-values-4/#typedef-dashed-ident) (and a [tree-scoped
reference](https://drafts.csswg.org/css-shadow-1/#css-tree-scoped-reference)) that should match an
[anchor-name](#propdef-anchor-name) value elsewhere on the page, or the
keyword
[auto](#valdef-position-anchor-auto), or nothing (a missing specifier).

 The general rule captured by these conditions is that
an element can only be a positioned box's [target anchor
element](#target-anchor-element) if its own box is fully laid out before the positioned
box that wants to reference it is laid out. CSS's layout rules provide
some useful guarantees about this, depending on the anchor and
positioned box's relationship with each other and their containing
blocks. The list of conditions below exactly rephrases the stacking
context rules into just what's relevant for this purpose, ensuring there
is no possibility of circularity in anchor positioning.

To determine the [target [anchor
element](#anchor-element)] given a querying element
`query el` and an optional [anchor
specifier](#anchor-specifier)
`anchor spec`:

1. If `anchor spec` was not passed, return the [default
 anchor
 element](#default-anchor-element) if it exists, otherwise return nothing.

2. If `anchor spec` is
 [auto](#valdef-position-anchor-auto):

 1. If `query el` has an [implicit anchor
 element](#implicit-anchor-element) that is an [acceptable anchor
 element](#acceptable-anchor-element), return that element.

 2. Otherwise, return nothing.

 Future APIs might also define implicit anchor
 elements. When they do, they'll be explicitly handled in this
 algorithm, to ensure coordination.

3. Otherwise, `anchor spec` is a
 [\<dashed-ident\>](https://www.w3.org/TR/css-values-4/#typedef-dashed-ident).

 If an ancestor of `query el` satisfies the following
 conditions, return the nearest such element to
 `query el`. Otherwise, return the last element
 `el` in tree order that satisfies the conditions.

 - `el` is an [anchor
 element](#anchor-element) with an [anchor
 name](#anchor-name) of
 `anchor spec`.

 - `el`'s [anchor
 name](#anchor-name)
 [loosely
 matches](https://drafts.csswg.org/css-shadow-1/#tree-scoped-name-loosely-matched) `anchor spec`.

 The [anchor
 name](#anchor-name) is a
 [tree-scoped
 name](https://drafts.csswg.org/css-shadow-1/#css-tree-scoped-name), while `anchor spec` is a [tree-scoped
 reference](https://drafts.csswg.org/css-shadow-1/#css-tree-scoped-reference).

 - `el` is an [acceptable anchor
 element](#acceptable-anchor-element) for `query el`.

 If no element satisfies these conditions, return nothing.

 [anchor-scope](#propdef-anchor-scope) can restrict the visibility of
 certain [anchor names](#anchor-name), which can affect what elements can be [anchor
 elements](#anchor-element)
 for a given lookup.

 An
[anchor-name](#propdef-anchor-name) defined by styles in one [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree) won't be seen by [anchor
functions](#anchor-functions)
in styles in a different [shadow tree],
preserving encapsulation. However, *elements* in different [shadow
trees] can still anchor to each other, so
long as both the [anchor-name]
and [anchor function] come from styles in
the same tree, such as by using
[::part()](https://drafts.csswg.org/css-shadow-1/#selectordef-part) to style an element inside a shadow. ([Implicit
anchor
elements](#implicit-anchor-element) also aren't intrinsically limited to a single tree, but
the details of that will depend on the API assigning them.)

An element `possible anchor` is an [acceptable anchor
element] for an [absolutely
positioned](https://www.w3.org/TR/css-position-3/#absolute-position) element `positioned el` if all of the
following are true:

- `possible anchor` is either an
 [element](https://www.w3.org/TR/css-display-3/#elements) or a [fully styleable
 pseudo-elements](https://www.w3.org/TR/css-pseudo-4/#fully-styleable).

- `possible anchor` is in scope for
 `positioned el`, per the effects of
 [anchor-scope](#propdef-anchor-scope) on `possible anchor`
 or its ancestors.

- `possible anchor` is laid out strictly before
 `positioned el`, aka one of the following is true:

 - `possible anchor` and `positioned el` have the
 same [original containing
 block](https://www.w3.org/TR/css-position-3/#original-containing-block) and either

 - `possible anchor` is [in a lower top
 layer](https://www.w3.org/TR/css-position-4/#in-a-higher-top-layer) than `positioned el`, or

 - they both exist in the same [top
 layer](https://www.w3.org/TR/css-position-4/#document-top-layer), but `possible anchor` is either not
 [absolutely
 positioned](https://www.w3.org/TR/css-position-3/#absolute-position) or occurs earlier in the [flat
 tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) order than `positioned el`

 - The element generating `possible anchor`'s [containing
 block](https://www.w3.org/TR/css-display-4/#containing-block) (if one exists) is an [acceptable anchor
 element](#acceptable-anchor-element) for `positioned el`

- If `possible anchor` is in the [skipped
 contents](https://www.w3.org/TR/css-contain-2/#skips-its-contents) of another element, then `positioned el`
 is in the [skipped contents] of that
 same element.

 In other words, `positioned el` can anchor
 to `possible anchor` if they're both in the same skipped
 \"leaf\", but it can't anchor \"across\" leafs. This means skipping an
 element that contains both of them won't suddenly cause the
 `positioned el` to move to another anchor, but still
 prevents positioned elements *elsewhere* in the page from anchoring to
 the skipped element.

### 2.4. Default Anchors: the [position-anchor property]
Name:

[position-anchor]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

normal
[\|](https://www.w3.org/TR/css-values-4/#comb-one) none [\|] auto
[\|]
[\<anchor-name\>](#typedef-anchor-name) [\|] match-parent

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

normal

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[absolutely positioned
boxes](https://www.w3.org/TR/css-position-3/#absolute-position)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

The
[position-anchor](#propdef-position-anchor) property specifies the [default
anchor element], which is used by
[position-area](#propdef-position-area),
[position-try](#propdef-position-try), and (by default) all [anchor
functions](#anchor-functions) applied to this element.
[position-anchor] is a
[reset-only
sub-property](https://www.w3.org/TR/css-cascade-5/#reset-only-sub-property) of
[position](https://www.w3.org/TR/css-position-3/#propdef-position).

[normal]

: If
 [position-area](#propdef-position-area) is
 [none](#valdef-position-area-none), behaves as
 [none](#valdef-position-anchor-none). Otherwise, behaves as
 [auto](#valdef-position-anchor-auto).

[none]

: The box has no [default anchor
 element](#default-anchor-element).

[auto]

: Use the [implicit anchor
 element](#implicit-anchor-element) if it exists; otherwise the box has no [default
 anchor
 element](#default-anchor-element).

[[\<anchor-name\>](#typedef-anchor-name)]

: The [target anchor
 element](#target-anchor-element) selected by the specified
 [\<anchor-name\>](#typedef-anchor-name) is the box's [default anchor
 element](#default-anchor-element).

[match-parent]

: Uses the same [default anchor
 element](#default-anchor-element) as the parent---​or [originating
 element](https://www.w3.org/TR/selectors-4/#originating-element), if this is a
 [pseudo-element](https://www.w3.org/TR/selectors-4/#pseudo-element)---​if any, and if that would be an [acceptable
 anchor
 element](#acceptable-anchor-element). Otherwise, the box has no [default anchor
 element].

The [principal
box](https://www.w3.org/TR/css-display-4/#principal-box) of the [default anchor
element](#default-anchor-element) is the box's [default anchor box].

For example, in the following code
both [.foo] and [.bar] elements can use the same positioning
properties, just changing the anchor element they're referring to:

``` highlight
.anchored {
 position: absolute;
 top: calc(.5em + anchor(outside));
 /* Since no anchor name was specified,
 this automatically refers to the
 default anchor box. */
}

.foo.anchored {
 position-anchor: --foo;
}
.bar.anchored {
 position-anchor: --bar;
}
```

If an element has a [default anchor
element](#default-anchor-element), then the [scrollable containing
block](https://www.w3.org/TR/css-position-4/#scrollable-containing-block) is used in place of the [local containing
block](https://www.w3.org/TR/css-position-4/#local-containing-block) when the [absolute-position containing
block](https://www.w3.org/TR/css-position-3/#absolute-position-containing-block) is generated by a [scroll
container](https://www.w3.org/TR/css-overflow-3/#scroll-container), so that the entire [scrollable overflow
area](https://www.w3.org/TR/css-overflow-3/#scrollable-overflow-region) (typically) is available for positioning.

#### 2.4.1. Implicit Anchor Elements

Some specifications can define that, in certain circumstances, a
particular element is an [implicit anchor
element] for another element.

TODO: Fill in an example new
popover-related details (once that finally lands in the HTML spec).

[Implicit anchor
elements](#implicit-anchor-element) can be referenced with the
[auto](#valdef-position-anchor-auto) keyword in
[position-anchor](#propdef-position-anchor), or by omitting the anchor
reference in [anchor
functions](#anchor-functions).

The [implicit anchor
element](#implicit-anchor-element) of a
[pseudo-element](https://www.w3.org/TR/selectors-4/#pseudo-element) is its [originating
element](https://www.w3.org/TR/selectors-4/#originating-element), unless otherwise specified.

### 2.5. Anchor Relevance

When determining whether an element `el` is [relevant to the
user](https://www.w3.org/TR/css-contain-2/#relevant-to-the-user), if a descendant of `el` is a [target anchor
element](#target-anchor-element) for a positioned box (which itself is not
[skipped](https://www.w3.org/TR/css-contain-2/#skips-its-contents) and whose [containing
block](https://www.w3.org/TR/css-display-4/#containing-block) is not `el` or a descendant of
`el`), then `el` must be considered [relevant to
the user].

 This means that, for example, an anchor in a
[content-visibility:
auto](https://www.w3.org/TR/css-contain-2/#propdef-content-visibility) subtree will prevent its subtree from
[skipping its
contents](https://www.w3.org/TR/css-contain-2/#skips-its-contents) as long as the positioned box relying on it is also not
[skipped]. (Unless the anchor and the
positioned box are both under the same [content-visibility:
auto] element; they can't
cyclicly keep each other visible.)

## 3. Anchor-Based Positioning

An [absolutely positioned
box](https://www.w3.org/TR/css-position-3/#absolute-position) can position itself relative to one or more [anchor
boxes](#anchor-box) on the page.

The
[position-area](#propdef-position-area) property offers a convenient
grid-based concept for positioning relative to the [default anchor
box](#default-anchor-box);
for more complex positioning or positioning relative to multiple boxes,
the [anchor()](#funcdef-anchor) function can be used in the [inset
properties](https://www.w3.org/TR/css-logical-1/#inset-properties) to explicitly refer to edges of an [anchor
box](#anchor-box).

### 3.1. The [position-area Property]
Name:

[position-area]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://www.w3.org/TR/css-values-4/#comb-one)
[\<position-area\>](#typedef-position-area)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

positioned boxes with a [default anchor
box](#default-anchor-box)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the keyword
[none](#valdef-position-area-none) or a pair of keywords, see [§ 3.1.3 Computed
Value and Serialization of \<position-area\>](#position-area-computed)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Most common use-cases of [anchor
positioning](#anchor-positioning) are only concerned with the edges of the positioned
box's [containing
block](https://www.w3.org/TR/css-display-4/#containing-block) and the edges of the [default anchor
box](#default-anchor-box).
These lines can be thought of as defining a 3×3 grid;
[position-area](#propdef-position-area) lets you easily specify what area
of this [position-area
grid](#position-area-grid)
to lay out the positioned box in.

![An example of [position-area: top
left](#propdef-position-area) positioning in a
[horizontal-tb](https://www.w3.org/TR/css-writing-modes-4/#valdef-writing-mode-horizontal-tb) [ltr] [writing
mode](https://www.w3.org/TR/css-writing-modes-4/#writing-mode).](images/position-area-example.png){width="400"}

[none]

: The property has no effect.

[[\<position-area\>](#typedef-position-area)]

: If the box does not have a [default anchor
 box](#default-anchor-box), or is not an [absolutely positioned
 box](https://www.w3.org/TR/css-position-3/#absolute-position), this value has no effect.

 Otherwise, selects a region of the [position-area
 grid](#position-area-grid), and makes that the box's [containing
 block](https://www.w3.org/TR/css-display-4/#containing-block).

 This means that the [inset
 properties](https://www.w3.org/TR/css-logical-1/#inset-properties) specify offsets from the position-area, and some
 property values, like [max-height:
 100%](https://www.w3.org/TR/css-sizing-3/#propdef-max-height), will be relative to the position-area as
 well.

Values other than
[none](#valdef-position-area-none) have the following additional effects:

- The [used
 value](https://www.w3.org/TR/css-cascade-5/#used-value) of any
 [auto](https://www.w3.org/TR/css-position-3/#valdef-top-auto) [inset
 properties](https://www.w3.org/TR/css-logical-1/#inset-properties) and [auto] [margin
 properties](https://www.w3.org/TR/css-box-4/#margin-properties) resolves to [0].

- The
 [normal](https://www.w3.org/TR/css-align-3/#valdef-align-self-normal) value for the [self-alignment
 properties](https://www.w3.org/TR/css-align-3/#self-alignment-properties) resolves to a corresponding value, see [§ 4.1
 Area-specific Default Alignment](#position-area-alignment).

#### 3.1.1. Resolving the Position Area Grid

The [position-area grid] is a 3×3 grid, composed of four grid lines in
each axis. In order (using the [writing
mode](https://www.w3.org/TR/css-writing-modes-4/#writing-mode) of the [containing
block](https://www.w3.org/TR/css-display-4/#containing-block)):

- the
 [start](https://www.w3.org/TR/css-writing-modes-4/#start) edge of the box's pre-modification [containing
 block](https://www.w3.org/TR/css-display-4/#containing-block), or the start edge of the [default anchor
 box](#default-anchor-box) if that is more [start]-ward

- the
 [start](https://www.w3.org/TR/css-writing-modes-4/#start) edge of the [default anchor
 box](#default-anchor-box)

- the [end](https://www.w3.org/TR/css-writing-modes-4/#end) edge of the [default anchor
 box](#default-anchor-box)

- the
 [end](https://www.w3.org/TR/css-writing-modes-4/#end) edge of the box's pre-modification [containing
 block](https://www.w3.org/TR/css-display-4/#containing-block), or the end edge of the [default anchor
 box](#default-anchor-box) if that is more [end]-ward.

 When the [default anchor
box](#default-anchor-box)
is partially or completely outside of the pre-modified [containing
block](https://www.w3.org/TR/css-display-4/#containing-block), some of the [position-area
grid's](#position-area-grid) rows or columns can be zero-sized.

#### 3.1.2. Syntax of [\<position-area\> Values]
Positions are specified as a pair of values, which can be expressed in
[flow-relative](https://www.w3.org/TR/css-writing-modes-4/#flow-relative) or
[physical](https://www.w3.org/TR/css-writing-modes-4/#physical) terms. The allowed syntax of a
[\<position-area\>](#typedef-position-area) value is:

``` prod
<position-area> = [
 [ left | center | right | span-left | span-right
 | x-start | x-end | span-x-start | span-x-end
 | self-x-start | self-x-end | span-self-x-start | span-self-x-end
 | span-all ]
 ||
 [ top | center | bottom | span-top | span-bottom
 | y-start | y-end | span-y-start | span-y-end
 | self-y-start | self-y-end | span-self-y-start | span-self-y-end
 | span-all ]
|
 [ block-start | center | block-end | span-block-start | span-block-end | span-all ]
 ||
 [ inline-start | center | inline-end | span-inline-start | span-inline-end
 | span-all ]
|
 [ self-block-start | center | self-block-end | span-self-block-start
 | span-self-block-end | span-all ]
 ||
 [ self-inline-start | center | self-inline-end | span-self-inline-start
 | span-self-inline-end | span-all ]
|
 [ start | center | end | span-start | span-end | span-all ]{1,2}
|
 [ self-start | center | self-end | span-self-start | span-self-end | span-all ]{1,2}
]
```

The
[\<position-area\>](#typedef-position-area) value selects a region of the
[position-area grid](#position-area-grid) by specifying the rows and columns the region occupies
as follows:

[start], [end], [self-start], [self-end]\
[top], [bottom], [left], [right]\
[y-start], [y-end], [self-y-start], [self-y-end]\
[x-start], [x-end], [self-x-start], [self-x-end]\
[block-start], [block-end], [self-block-start], [self-block-end]\
[inline-start], [inline-end], [self-inline-start], [self-inline-end]\
[center]

: The single corresponding row or column, depending on which axis this
 keyword is specifying.

 Like in [anchor()](#funcdef-anchor), the plain logical keywords
 ([start](#valdef-position-area-start),
 [end](#valdef-position-area-end), etc) refer to the [writing
 mode](https://www.w3.org/TR/css-writing-modes-4/#writing-mode) of the box's [containing
 block](https://www.w3.org/TR/css-display-4/#containing-block). The
 [x-start](#valdef-position-area-x-start)/etc determine their direction in the same
 way, but in the specified physical axis.

 The [self-\*] logical keywords
 ([self-start](#valdef-position-area-self-start),
 [self-x-end](#valdef-position-area-self-x-end), etc) are identical, but refer to the box's
 own [writing
 mode](https://www.w3.org/TR/css-writing-modes-4/#writing-mode).

[span-start], [span-end], [span-self-start], [span-self-end]\
[span-top], [span-bottom], [span-left], [span-right]\
[span-y-start], [span-y-end], [span-self-y-start], [span-self-y-end]\
[span-x-start], [span-x-end], [span-self-x-start], [span-self-x-end]\
[span-block-start], [span-block-end], [span-self-block-start], [span-self-block-end]\
[span-inline-start], [span-inline-end], [span-self-inline-start], [span-self-inline-end]

: Two adjacent rows or columns, depending on which axis this keyword
 is specifying: the center row/column, and the row/column
 corresponding to the other half of the keyword as per the
 single-track keywords.

 (For example,
 [span-top](#valdef-position-area-span-top) spans the first two rows---​the center row
 and the top row.)

[span-all]

: All three rows or columns, depending on which axis this keyword is
 specifying.

Some keywords are ambiguous about what axis they refer to:
[center](#valdef-position-area-center),
[span-all](#valdef-position-area-span-all), and the
[start](#valdef-position-area-start)/etc keywords that don't specify the block or
inline axis explicitly. If the other keyword is unambiguous about its
axis, then the ambiguous keyword is referring to the opposite axis. (For
example, in [block-start center], the
[center] keyword is
referring to the inline axis.) If both keywords are ambiguous, however,
then the first refers to the [block
axis](https://www.w3.org/TR/css-writing-modes-4/#block-axis) of the box's [containing
block](https://www.w3.org/TR/css-display-4/#containing-block), and the second to the [inline
axis](https://www.w3.org/TR/css-writing-modes-4/#inline-axis). (For example, [span-all start] is equivalent to
[span-all inline-start].)

If only a single keyword is given, it behaves as if the second keyword
is
[span-all](#valdef-position-area-span-all) if the given keyword is unambigous about its
axis; otherwise, it behaves as if the given keyword was repeated. (For
example,
[top](#valdef-position-area-top) is equivalent to [top span-all], but
[center](#valdef-position-area-center) is equivalent to [center center].)

#### 3.1.3. Computed Value and Serialization of [\<position-area\>]
The [computed
value](https://www.w3.org/TR/css-cascade-5/#computed-value) of a
[\<position-area\>](#typedef-position-area) value is the two keywords indicating
the selected tracks in each axis, with the long
([block-start](#valdef-position-area-block-start)) and short
([start](#valdef-position-area-start)) logical keywords treated as equivalent. It
serializes in the order given in the grammar (above), with the logical
keywords serialized in their short forms (e.g. [start start]
instead of [block-start inline-start]).

### 3.2. Anchor-relative Insets: the [anchor() function]
An [absolutely positioned
box](https://www.w3.org/TR/css-position-3/#absolute-position) can use the [anchor()] function as a value in its
[inset
properties](https://www.w3.org/TR/css-logical-1/#inset-properties) to refer to the position of one or more [anchor
boxes](#anchor-box). The
[anchor()](#funcdef-anchor) function resolves to a
[\<length\>](https://www.w3.org/TR/css-values-4/#length-value). It is only allowed in the [inset
properties] (and is otherwise invalid).

Name:

[top](https://www.w3.org/TR/css-position-3/#propdef-top),
[left](https://www.w3.org/TR/css-position-3/#propdef-left),
[right](https://www.w3.org/TR/css-position-3/#propdef-right),
[bottom](https://www.w3.org/TR/css-position-3/#propdef-bottom)

[New values:](https://www.w3.org/TR/css-values/#value-defs)

[\<anchor()\>](#funcdef-anchor)

``` prod
<anchor()> = anchor( <anchor-name>? && <anchor-side>, <length-percentage>? )
<anchor-side> = inside | outside
 | top | left | right | bottom
 | start | end | self-start | self-end
 | <percentage> | center
```

The [anchor()](#funcdef-anchor) function has three arguments:

- the
 [\<anchor-name\>](#typedef-anchor-name) value specifies how to find the
 [anchor element](#anchor-element) it will be drawing positioning information from. Its
 possible values are:

 [[\<dashed-ident\>](https://www.w3.org/TR/css-values-4/#typedef-dashed-ident)]

 : Specifies the [anchor name](#anchor-name) it will look for. This name is a [tree-scoped
 reference](https://drafts.csswg.org/css-shadow-1/#css-tree-scoped-reference).

 omitted

 : Selects the [default anchor
 element](#default-anchor-element) defined for the box, if possible.

 See [target anchor
 element](#target-anchor-element) for details.

- the
 [\<anchor-side\>](#typedef-anchor-side) value refers to the position of the
 corresponding side of the [target anchor
 element](#target-anchor-element). Its possible values are:

 [inside]\
 [outside]

 : Resolves to one of the [anchor
 box's](#anchor-box) sides,
 depending on which [inset
 property](https://www.w3.org/TR/css-logical-1/#inset-properties) it's used in.
 [inside](#valdef-anchor-inside) refers to the same side as the [inset
 property] (attaching the positioned
 box to the \"inside\" of the [anchor box]),
 while
 [outside](#valdef-anchor-outside) refers to the opposite.

 [top]\
 [right]\
 [bottom]\
 [left]

 : Refers to the specified side of the [anchor
 box](#anchor-box).

 These are only usable in the [inset
 properties](https://www.w3.org/TR/css-logical-1/#inset-properties) in the matching axis. For example,
 [left](#valdef-anchor-left) is usable in
 [left](https://www.w3.org/TR/css-position-3/#propdef-left),
 [right](https://www.w3.org/TR/css-position-3/#propdef-right), or the logical [inset
 properties] that refer to the
 horizontal axis.

 [start]\
 [end]\
 [self-start]\
 [self-end]

 : Refers to one of the sides of the [anchor
 box](#anchor-box) in the
 same axis as the [inset
 property](https://www.w3.org/TR/css-logical-1/#inset-properties) it's used in, by resolving the keyword against
 the [writing
 mode](https://www.w3.org/TR/css-writing-modes-4/#writing-mode) of either the positioned box (for
 [self-start](#valdef-anchor-self-start) and
 [self-end](#valdef-anchor-self-end)) or the positioned box's containing block
 (for [start](#valdef-anchor-start) and
 [end](#valdef-anchor-end)).

 [[\<percentage\>](https://www.w3.org/TR/css-values-4/#percentage-value)]\
 [center]

 : Refers to a position a corresponding percentage between the
 [start](#valdef-anchor-start) and
 [end](#valdef-anchor-end) sides, with [0%] being equivalent to
 [start] and [100%] being
 equivalent to [end].

 [center](#valdef-anchor-center) is equivalent to [50%].

- the optional
 [\<length-percentage\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage) final argument is a fallback value,
 specifying what the function should compute to if it's an
 [unresolvable anchor
 function](#resolvable-anchor-function).

An [anchor()](#funcdef-anchor) function representing a [resolvable anchor
function](#resolvable-anchor-function) resolves at [computed
value](https://www.w3.org/TR/css-cascade-5/#computed-value) time (using [style & layout
interleaving](#style--layout-interleave)) to the
[\<length\>](https://www.w3.org/TR/css-values-4/#length-value) that would align the edge of the
positioned boxes\' [inset-modified containing
block](https://www.w3.org/TR/css-position-3/#inset-modified-containing-block) corresponding to the property the function appears in
with the specified edge of the [target anchor
element's](#target-anchor-element) [anchor box](#anchor-box).

 This means that
[transitions](https://www.w3.org/TR/css-transitions-1/#transitions) or
[animations](https://www.w3.org/TR/web-animations-1/#concept-animation) of a property using an [anchor
function](#anchor-functions)
will work \"as expected\" for all sorts of possible changes: the [anchor
box](#anchor-box) moving, [anchor
elements](#anchor-element)
being added or removed from the document, the
[anchor-name](#propdef-anchor-name) property being changed on anchors, etc.

For example, in [.bar {
inset-block-start: anchor(\--foo block-start); }], the
[anchor()](#funcdef-anchor) will resolve to the length that'll line up the `.bar`
element's block-start edge with the [\--foo] anchor's block-start
edge.

On the other hand, in [.bar { inset-block-end: anchor(\--foo
block-start); }], it will instead resolve to the length that'll
line up the `.bar` element's *block-end* edge with the [\--foo]
anchor's block-start edge.

Since
[inset-block-start](https://www.w3.org/TR/css-position-3/#propdef-inset-block-start) and
[inset-block-end](https://www.w3.org/TR/css-position-3/#propdef-inset-block-end) values specify insets from
different edges (the block-start and block-end of the element's
[containing
block](https://www.w3.org/TR/css-display-4/#containing-block), respectively), the same
[anchor()](#funcdef-anchor) will usually resolve to different lengths in each.

Because the
[anchor()](#funcdef-anchor) function resolves to a
[\<length\>](https://www.w3.org/TR/css-values-4/#length-value), it can be used in [math
functions](https://www.w3.org/TR/css-values-4/#math-function) like any other length.

For example, in the following chart, the three bars are set up as
possible anchors, and the min/max lines and tooltips use
[min()](https://www.w3.org/TR/css-values-4/#funcdef-min) and
[max()](https://www.w3.org/TR/css-values-4/#funcdef-max) to combine
[anchor()](#funcdef-anchor) functions referring to all three to find where to
position themselves. You can use the range inputs below each column to
adjust the heights, and see that the anchored lines and tooltips
dynamically adjust to whichever bar is the highest/lowest.

<figure>

<figcaption><a href="examples/calc-anchor.html">Full
Example</a></figcaption>
</figure>

The important fragment of the code to accomplish this is:

``` highlight
#bar-1 { anchor-name: --anchor-1; }
#bar-2 { anchor-name: --anchor-2; }
#bar-3 { anchor-name: --anchor-3; }
.line {
 position: absolute;
 left: anchor(--chart left);
 right: anchor(--chart right);
 &.max {
 bottom: max(
 anchor(--anchor-1 top),
 anchor(--anchor-2 top),
 anchor(--anchor-3 top)
 );
 }
 &.min {
 bottom: min(
 anchor(--anchor-1 top),
 anchor(--anchor-2 top),
 anchor(--anchor-3 top)
 );
 }
}
```

#### 3.2.1. Resolution of [anchor()]
An [anchor()](#funcdef-anchor) function is a [resolvable anchor
function] only if all the following conditions are true:

- It's applied to an [absolutely positioned
 box](https://www.w3.org/TR/css-position-3/#absolute-position).

- If its
 [\<anchor-side\>](#typedef-anchor-side) specifies a physical keyword, it's
 specified in an [inset
 property](https://www.w3.org/TR/css-logical-1/#inset-properties) applicable to that axis. (For example,
 [left](#valdef-anchor-left) can only be used in
 [left](https://www.w3.org/TR/css-position-3/#propdef-left),
 [right](https://www.w3.org/TR/css-position-3/#propdef-right), or a logical [inset
 property] in the horizontal axis.)

- There is a [target anchor
 element](#target-anchor-element) for the box it's used on, and the
 [\<anchor-name\>](#typedef-anchor-name) value specified in the function.

If any of these conditions are false, the
[anchor()](#funcdef-anchor) function
[computes](https://www.w3.org/TR/css-cascade-5/#computed-value) to its specified fallback value. If no fallback value
is specified, it makes the declaration referencing it [invalid at
computed-value
time](https://www.w3.org/TR/css-values-5/#invalid-at-computed-value-time).

### 3.3. Taking Scroll Into Account

For performance reasons, implementations usually perform scrolling on a
separate scrolling/\"compositing\" thread, which has very limited
capabilities (simple movement/transforms/etc., but no layout or similar
expensive operations) and thus can be relied upon to respond to
scrolling fast enough to be considered \"instant\" to human perception.

If scrolling just causes an anchor-positioned element to *move*, there
is in theory no issue; the movement can be performed on the scrolling
thread so the positioned element moves smoothly with the scrolling
content. However, [anchor
positioning](#anchor-positioning) allows an element to make the positions of its own
opposite edges depend on things in *different* scrolling contexts, which
means scrolling could move just *one* edge and cause a size change, and
thus perform layout. This can't be performed on the scrolling thread!

To compensate for this, while still allowing as much freedom to anchor
to various elements as possible, [anchor
positioning](#anchor-positioning) uses a combination of [remembered scroll
offsets](#remembered-scroll-offset) and [compensating for
scroll](#compensate-for-scroll).

The details here are technical, but the gist is:

- When a positioned element is first displayed, or when it [changes
 fallbacks](#fallback), its position is correctly calculated according
 to the up-to-date position of all [anchor
 references](#anchor-reference).

 If these [anchor
 references](#anchor-reference) are in a different scroll context, their total scroll
 offsets are *memorized*, and layout will continue using those
 memorized offsets, even if those elements are scrolled later. (Only
 the scroll offsets are memorized; their actual laid-out positions are
 freshly calculated each time and remain accurate.) They'll only
 recalculate if the positioned element stops being displayed and starts
 again, or changes fallbacks.

- The one exception to this is the [default anchor
 element](#default-anchor-element); if it's scrolled away from its [remembered scroll
 offset](#remembered-scroll-offset), the positioned element moves with it. Because this
 is \*purely\* a shift in position, the positioned element can't change
 size or otherwise require layout in response.

The end result is that [anchor
positioning](#anchor-positioning) should generally \"just work\", regardless of what the
element is anchoring to, but it might be limited in how it can respond
to scrolling.

An [anchor recalculation point] occurs for an [absolutely
positioned
element](https://www.w3.org/TR/css-position-3/#absolute-position) whenever that element begins generating boxes (aka
switches from [display:none] or [display:contents] to any
other
[display](https://www.w3.org/TR/css-display-4/#propdef-display) value), identical to when it starts
running CSS animations.

An [anchor recalculation
point](#anchor-recalculation-point) also occurs for an element when [determining position
fallback
styles](#determine-position-fallback-styles) for that element; if it changes fallback styles as a
result, it uses the result of the [anchor recalculation
point] associated with the chosen
set of fallback styles.

When an [anchor recalculation
point](#anchor-recalculation-point) occurs for an element `abspos`, then for
every element `anchor` referenced by one of
`abspos`'s [anchor
references](#anchor-reference), it associates a [remembered scroll
offset] equal to the *current* sum of the [scroll
offsets](https://www.w3.org/TR/css-overflow-3/#scroll-offset) of all [scroll
container](https://www.w3.org/TR/css-overflow-3/#scroll-container) ancestors of `anchor`, up to but not
including `abspos`'s [containing
block](https://www.w3.org/TR/css-display-4/#containing-block). The [remembered scroll
offset](#remembered-scroll-offset) also accounts for other scroll-dependent positioning
changes, such as [position:
sticky](https://www.w3.org/TR/css-position-3/#propdef-position). If `abspos` has a [default anchor
element](#default-anchor-element), it always calculates a [remembered scroll
offset] for it, even if
`abspos` doesn't actually have an [anchor
reference] to it.

All [anchor references](#anchor-reference) are calculated as if all [scroll
containers](https://www.w3.org/TR/css-overflow-3/#scroll-container) were at their [initial scroll
position](https://www.w3.org/TR/css-overflow-3/#initial-scroll-position), and then have their associated [remembered scroll
offset](#remembered-scroll-offset) added to them.

Transforms have the same issue as
scrolling, so Anchor Positioning similarly doesn't pay attention to them
normally. Can we go ahead and incorporate the effects of transforms
here?

The above allows a positioned element to respond to the scroll positions
of its [anchor references](#anchor-reference) *once*, but if any of them are scrolled, the positioned
element will no longer appear to be anchored to them (tho it will
continue to respond to their non-scrolling movement). While this problem
can't be solved *in general*, we *can* respond to the scrolling of *one*
[anchor reference]; specifically, the
[default anchor
element](#default-anchor-element):

An [absolutely positioned
box](https://www.w3.org/TR/css-position-3/#absolute-position) `abspos` [compensates for
scroll] in the horizontal or vertical axis
if both of the following conditions are true:

- `abspos` has a [default anchor
 box](#default-anchor-box).

- `abspos` has an [anchor
 reference](#anchor-reference) to its [default anchor
 box](#default-anchor-box) or at least to something in the same scrolling
 context, aka at least one of:

 - `abspos`'s used [self-alignment
 property](https://www.w3.org/TR/css-align-3/#self-alignment-properties) value in that axis is
 [anchor-center](#valdef-justify-self-anchor-center);

 - `abspos` has a
 non-[none](#valdef-position-area-none) value for
 [position-area](#propdef-position-area)

 - at least one [anchor()](#funcdef-anchor) function on `abspos`'s
 [used](https://www.w3.org/TR/css-cascade-5/#used-value) [inset
 properties](https://www.w3.org/TR/css-logical-1/#inset-properties) in the axis refers to a [target anchor
 element](#target-anchor-element) with the same nearest [scroll
 container](https://www.w3.org/TR/css-overflow-3/#scroll-container) ancestor with that axis as a [scrollable
 axis](https://drafts.csswg.org/css-overflow-3/#scrollable-axis) as `abspos`'s [default anchor
 box](#default-anchor-box).

 If `abspos` has a [position options
list](#position-options-list), then whether it [compensates for
scroll](#compensate-for-scroll) in an axis is also affected by the applied fallback
style.

`abspos`'s [default scroll shift] is a pair of lengths for the
horizontal and vertical axises, respectively. Each length is calculated
as:

- If `abspos` is [compensating for
 scroll](#compensate-for-scroll) in the axis, then the length is the difference
 between the [remembered scroll
 offset](#remembered-scroll-offset) of the [default anchor
 element](#default-anchor-element) and what its current [remembered scroll
 offset] would be if it were
 recalculated.

- Otherwise, the length is 0.

After layout has been performed for `abspos`, it is
additionally shifted by the [default scroll
shift](#default-scroll-shift), as if affected by a
[transform](https://streams.spec.whatwg.org/#generictransformstream-transform) (before any other transforms).

Define the precise timing of the
snapshot: updated each frame, before style recalc.

Similar to [remembered scroll
offset](#remembered-scroll-offset), can we pay attention to transforms on the [default
anchor
element](#default-anchor-element)?

 While [remembered scroll
offsets](#remembered-scroll-offset) affect the value of
[anchor()](#funcdef-anchor) functions, [default scroll
shift](#default-scroll-shift) directly shifts the element, *after* determining the
value of its [inset
properties](https://www.w3.org/TR/css-logical-1/#inset-properties), applying alignment, etc. This is *usually*
indistinguishable, but cases like [round(anchor(outside), 50px)],
which transform the [default anchor
element's](#default-anchor-element) position in a non-linear fashion, will expose the
difference in behavior.

## 4. Anchor-Based Alignment

### 4.1. Area-specific Default Alignment

When
[position-area](#propdef-position-area) is not
[none](#valdef-position-area-none), the [used
value](https://www.w3.org/TR/css-cascade-5/#used-value) of
[normal](https://www.w3.org/TR/css-align-3/#valdef-align-self-normal)
[self-alignment](https://www.w3.org/TR/css-align-3/#self-align) changes depending on the
[\<position-area\>](#typedef-position-area) value, to align the box towards the
anchor:

- If the only the center track in an axis is selected, the default
 alignment in that axis is
 [center](https://www.w3.org/TR/css-align-3/#valdef-self-position-center).

- If all three tracks are selected, the default alignment in that axis
 is
 [anchor-center](#valdef-justify-self-anchor-center).

- Otherwise, the default alignment in that axis is toward the
 non-specified side track: if it's specifying the "start" track of its
 axis, the default alignment in that axis is
 [end](https://www.w3.org/TR/css-align-3/#valdef-self-position-end); etc.

However, if only one [inset
property](https://www.w3.org/TR/css-logical-1/#inset-properties) in the relevant axis is
[auto](https://www.w3.org/TR/css-position-3/#valdef-top-auto), the default alignment is instead towards the
edge with the non-[auto] inset; and this
is an [unsafe] alignment.

 This
single-[auto](https://www.w3.org/TR/css-position-3/#valdef-top-auto) behavior preserves the way a single specified
inset controls the position of an [absolutely
positioned](https://www.w3.org/TR/css-position-3/#absolute-position) box.

For example, assuming an
English-equivalent writing mode (horizontal-tb, ltr), then the value
[span-x-start top] resolves to the
[start](#valdef-position-area-start) region of the vertical axis, and the
[start] and
[center](#valdef-position-area-center) regions of the horizontal axis, so the default
alignments will be [align-self:
end](#propdef-align-self) (making the box's bottom [margin
edge](https://www.w3.org/TR/css-box-4/#margin-edge) flush with the bottom of the
[top](#valdef-position-area-top) region) and [justify-self:
end](#propdef-justify-self) (making the box's end-side [margin
edge] flush with the end side of the
[span-start](#valdef-position-area-span-start) region).

If the box overflows its [inset-modified containing
block](https://www.w3.org/TR/css-position-3/#inset-modified-containing-block), but would still fit within its [original containing
block](https://www.w3.org/TR/css-position-3/#original-containing-block), by default it will "shift" to stay within its
[original containing block], even
if that violates its normal alignment. See [CSS Box Alignment 3 § 4.4
Overflow Alignment: the safe and unsafe keywords and scroll safety
limits](https://www.w3.org/TR/css-align-3/#overflow-values) for details.

This behavior makes it more likely that positioned boxes remain visible
and within their intended bounds, even when their [containing
block](https://www.w3.org/TR/css-display-4/#containing-block) ends up smaller than anticipated.

For example, a [position-area: bottom
span-right](#propdef-position-area) value lets the positioned box stretch from its
anchor's left edge to its containing block's right edge, and left-aligns
it in that space by default. But if the positioned box is larger than
that space (such as if the anchor is very close to the right edge of the
screen), it will shift leftwards to stay visible.

### 4.2. Centering on the Anchor: the [anchor-center alignment value]
Name:

[justify-self], [align-self]

[New values:](https://www.w3.org/TR/css-values/#value-defs)

anchor-center

The [self-alignment
properties](https://www.w3.org/TR/css-align-3/#self-alignment-properties) allow an [absolutely positioned
box](https://www.w3.org/TR/css-position-3/#absolute-position) to align itself within the [inset-modified containing
block](https://www.w3.org/TR/css-position-3/#inset-modified-containing-block). The existing values, plus carefully chosen [inset
properties](https://www.w3.org/TR/css-logical-1/#inset-properties), are usually enough for useful alignment, but a common
case for anchored positioning---​centering over the [anchor
box](#anchor-box)---​requires
careful and somewhat complex set-up to achieve.

The new [anchor-center] value makes this case extremely simple: if the positioned box
has a [default anchor
box](#default-anchor-box), then it is centered (insofar as possible) over the
[default anchor box] in the relevant
axis. Additionally:

- The [used
 value](https://www.w3.org/TR/css-cascade-5/#used-value) of any
 [auto](https://www.w3.org/TR/css-position-3/#valdef-top-auto) [inset
 properties](https://www.w3.org/TR/css-logical-1/#inset-properties) and [auto] [margin
 properties](https://www.w3.org/TR/css-box-4/#margin-properties) resolves to [0].

If the box is not [absolutely
positioned](https://www.w3.org/TR/css-position-3/#absolute-position), or does not have a [default anchor
box](#default-anchor-box), this value behaves as
[center](https://www.w3.org/TR/css-align-3/#valdef-self-position-center) and has no additional effect on how [inset
properties](https://www.w3.org/TR/css-logical-1/#inset-properties) resolve.

 When using
[anchor-center](#valdef-justify-self-anchor-center), by default if the anchor is too close to the
edge of the box's [original containing
block](https://www.w3.org/TR/css-position-3/#original-containing-block), it will "shift" from being purely centered, in order
to remain within the [original containing
block]. See [CSS Box Alignment 3
§ 4.4 Overflow Alignment: the safe and unsafe keywords and scroll safety
limits](https://www.w3.org/TR/css-align-3/#overflow-values) for more
details.

## 5. Anchor-Based Sizing

An [absolutely positioned
box](https://www.w3.org/TR/css-position-3/#absolute-position) can use the [anchor-size()] function in its [sizing
properties](https://www.w3.org/TR/css-sizing-3/#sizing-property) to refer to the size of one or more [anchor
boxes](#anchor-box). The
[anchor-size()](#funcdef-anchor-size) function resolves to a
[\<length\>](https://www.w3.org/TR/css-values-4/#length-value). It is only allowed in the [accepted
\@position-try
properties](#accepted-position-try-properties) (and is otherwise invalid).

### 5.1. The [anchor-size() Function]
Name:

[block-size](https://www.w3.org/TR/css-logical-1/#propdef-block-size),
[inline-size](https://www.w3.org/TR/css-logical-1/#propdef-inline-size),
[width](https://www.w3.org/TR/css-sizing-3/#propdef-width),
[height](https://www.w3.org/TR/css-sizing-3/#propdef-height),
[min-block-size](https://www.w3.org/TR/css-logical-1/#propdef-min-block-size),
[min-inline-size](https://www.w3.org/TR/css-logical-1/#propdef-min-inline-size),
[min-width](https://www.w3.org/TR/css-sizing-3/#propdef-min-width),
[min-height](https://www.w3.org/TR/css-sizing-3/#propdef-min-height),
[max-block-size](https://www.w3.org/TR/css-logical-1/#propdef-max-block-size),
[max-inline-size](https://www.w3.org/TR/css-logical-1/#propdef-max-inline-size),
[max-width](https://www.w3.org/TR/css-sizing-3/#propdef-max-width),
[max-height](https://www.w3.org/TR/css-sizing-3/#propdef-max-height),
[top](https://www.w3.org/TR/css-position-3/#propdef-top),
[left](https://www.w3.org/TR/css-position-3/#propdef-left),
[right](https://www.w3.org/TR/css-position-3/#propdef-right),
[bottom](https://www.w3.org/TR/css-position-3/#propdef-bottom),
[margin-top](https://www.w3.org/TR/css-box-4/#propdef-margin-top),
[margin-left](https://www.w3.org/TR/css-box-4/#propdef-margin-left),
[margin-right](https://www.w3.org/TR/css-box-4/#propdef-margin-right),
[margin-bottom](https://www.w3.org/TR/css-box-4/#propdef-margin-bottom)

[New values:](https://www.w3.org/TR/css-values/#value-defs)

[\<anchor-size()\>](#funcdef-anchor-size)

``` prod
anchor-size() = anchor-size( [ <anchor-name> || <anchor-size> ]? , <length-percentage>? )
<anchor-size> = width | height | block | inline | self-block | self-inline
```

The [anchor-size()](#funcdef-anchor-size) function is similar to
[anchor()](#funcdef-anchor), and takes the same arguments, save that the
[\<anchor-side\>](#typedef-anchor-side) keywords are replaced with
[\<anchor-size\>](#typedef-anchor-size), referring to the distance between
two opposing sides.

The physical
[\<anchor-size\>](#typedef-anchor-size) keywords
([width] and
[height]) refer to the width
and height, respectively, of the [target anchor
element](#target-anchor-element). Unlike
[anchor()](#funcdef-anchor), there is no restriction on having to match axises;
for example, [width: anchor-size(\--foo
height);](https://www.w3.org/TR/css-sizing-3/#propdef-width) is valid.

The logical
[\<anchor-size\>](#typedef-anchor-size) keywords
([block],
[inline],
[self-block], and
[self-inline]) map to one of the
physical keywords according to either the [writing
mode](https://www.w3.org/TR/css-writing-modes-4/#writing-mode) of the box (for
[self-block](#valdef-anchor-size-self-block) and
[self-inline](#valdef-anchor-size-self-inline)) or the [writing mode]
of the box's [containing
block](https://www.w3.org/TR/css-display-4/#containing-block) (for
[block](#valdef-anchor-size-block) and
[inline](#valdef-anchor-size-inline)).

If the
[\<anchor-size\>](#typedef-anchor-size) keyword is omitted, it defaults to
behaving as whatever keyword matches the axis of the property that
[anchor-size()](#funcdef-anchor-size) is used in. (For example, [width:
anchor-size()](https://www.w3.org/TR/css-sizing-3/#propdef-width) is equivalent to [width:
anchor-size(width)].)

An [anchor-size()](#funcdef-anchor-size) function representing a [resolvable anchor-size
function](#resolvable-anchor-size-function) resolves at [computed
value](https://www.w3.org/TR/css-cascade-5/#computed-value) time (via [style & layout
interleaving](#style--layout-interleave)) to the
[\<length\>](https://www.w3.org/TR/css-values-4/#length-value) separating the relevant edges (either
left and right, or top and bottom, whichever is in the specified axis)
of the [target anchor
element's](#target-anchor-element) [anchor box](#anchor-box).

#### 5.1.1. Resolution of [anchor-size()]
An [anchor-size()](#funcdef-anchor-size) function is a [resolvable anchor-size
function] only if all the following conditions are true:

- It's applied to an [absolutely positioned
 box](https://www.w3.org/TR/css-position-3/#absolute-position).

- There is a [target anchor
 element](#target-anchor-element) for the box it's used on, and the
 [\<anchor-name\>](#typedef-anchor-name) value specified in the function.

If any of these conditions are false, the
[anchor-size()](#funcdef-anchor-size) function resolves to its specified fallback value. If
no fallback value is specified, it makes the declaration referencing it
[invalid at computed-value
time](https://www.w3.org/TR/css-values-5/#invalid-at-computed-value-time).

## 6. Overflow Management

Anchor positioning, while powerful, can also be unpredictable. The
[anchor box](#anchor-box) might
be anywhere on the page, so positioning a box in any particular fashion
(such as above the anchor, or the right of the anchor) might result in
the positioned box overflowing its [containing
block](https://www.w3.org/TR/css-display-4/#containing-block) or being positioned partially off screen.

To ameliorate this, an [absolutely
positioned](https://www.w3.org/TR/css-position-3/#absolute-position) box can use the
[position-try-fallbacks](#propdef-position-try-fallbacks) property to specify additional
[position options] (variant sets of positioning/alignment properties generated
from the box's existing styles, or specified in
[\@position-try](#at-ruledef-position-try) rules) that the UA can try if the box overflows
its initial position. Each [position
option](#position-options) is
applied to the box, one by one in the order specified by
[position-try-order](#propdef-position-try-order), and the first that doesn't cause
the box to overflow its [containing
block](https://www.w3.org/TR/css-display-4/#containing-block) is taken as the winner.

Once an option has been chosen, the element keeps those styles until it
overflows again, even if an earlier (and presumably more desirable)
option again becomes available without causing overflow. (See [record
the last successful position
option](#record-the-last-successful-position-option).)

For example, the following CSS will
first attempt to position a \"popover\" below the element, but if it
doesn't fit on-screen will switch to being above. It defaults to
start-aligning with the anchor, but will switch to end-aligning if that
doesn't fit. If it doesn't fit on *either* side, it will take the whole
horizontal space, while centering on the anchor as much as possible
(thanks to [§ 4.1 Area-specific Default
Alignment](#position-area-alignment)).

``` highlight
#myPopover {
 position: fixed;
 position-anchor: --button;
 position-area: bottom span-x-end;
 position-try-fallbacks: flip-x, flip-y, flip-x flip-y, bottom, top;

 /* The popover is at least as wide as the button */
 min-width: anchor-size(width);

 /* The popover is at least as tall as 2 menu items */
 min-height: 6em;
}
```

Add a picture!

### 6.1. Giving Fallback Options: the [position-try-fallbacks property]
Name:

[position-try-fallbacks]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://www.w3.org/TR/css-values-4/#comb-one) \[
\[[\<dashed-ident\>](https://www.w3.org/TR/css-values-4/#typedef-dashed-ident)
[\|\|](https://www.w3.org/TR/css-values-4/#comb-any)
[\<try-tactic\>](#typedef-position-try-fallbacks-try-tactic)\] [\|]
[\<position-area\>](#typedef-position-area)
\][\#](https://www.w3.org/TR/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[absolutely positioned
boxes](https://www.w3.org/TR/css-position-3/#absolute-position)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

This property provides a list of additional, alternative [position
options](#position-options)
to try in order to prevent the [absolutely positioned
box](https://www.w3.org/TR/css-position-3/#absolute-position) from overflowing its [inset-modified containing
block](https://www.w3.org/TR/css-position-3/#inset-modified-containing-block).

Each comma-separated entry in the list is a separate [position
option](#position-options):
either the name of a
[\@position-try](#at-ruledef-position-try) block, or a
[\<try-tactic\>](#typedef-position-try-fallbacks-try-tactic) representing an automatic
transformation of the box's existing computed style (its [fallback base
styles]). Together with the [fallback base
styles](#fallback-base-styles), these options form the [position options
list]
from which the effective style is chosen, see [§ 6.5 Applying Position
Fallback](#fallback-apply).

Values have the following meanings:

[none]

: The property has no effect; the box's [position options
 list](#position-options-list) consists only of the [fallback base
 styles](#fallback-base-styles).

[[\<dashed-ident\>](https://www.w3.org/TR/css-values-4/#typedef-dashed-ident)]

: If there is a
 [\@position-try](#at-ruledef-position-try) rule with the given name, its associated
 [position option](#position-options) is added to the [position options
 list](#position-options-list).

 Otherwise, this value has no effect.

[[\<try-tactic\>](#typedef-position-try-fallbacks-try-tactic)]

: Automatically creates a [position
 option](#position-options) by [executing the specified try
 tactic](#execute-a-try-tactic) on the box's [base
 styles](#fallback-base-styles), then adding this constructed [position
 option] to the box's [position options
 list](#position-options-list).

 ``` prod
 <try-tactic> = flip-block || flip-inline || flip-start || flip-x || flip-y
 ```

 [flip-block]

 : swaps the values in the [block
 axis](https://www.w3.org/TR/css-writing-modes-4/#block-axis) (between, for example,
 [margin-block-start](https://www.w3.org/TR/css-logical-1/#propdef-margin-block-start) and
 [margin-block-end](https://www.w3.org/TR/css-logical-1/#propdef-margin-block-end)), essentially mirroring
 across an
 [inline-axis](https://www.w3.org/TR/css-writing-modes-4/#inline-axis) line.

 [flip-inline]

 : swaps the values in the [inline
 axis](https://www.w3.org/TR/css-writing-modes-4/#inline-axis), essentially mirroring across a
 [block-axis](https://www.w3.org/TR/css-writing-modes-4/#block-axis) line.

 [flip-x]

 : swaps the values in the [horizontal
 axis](https://www.w3.org/TR/css-writing-modes-4/#x-axis) (between, for example,
 [margin-left](https://www.w3.org/TR/css-box-4/#propdef-margin-left) and
 [margin-right](https://www.w3.org/TR/css-box-4/#propdef-margin-right)), essentially mirroring
 across a
 [vertical-axis](https://drafts.csswg.org/css-writing-modes-4/#y-axis) line.

 [flip-y]

 : swaps the values in the [vertical
 axis](https://www.w3.org/TR/css-writing-modes-4/#y-axis), essentially mirroring across a
 [horizontal-axis](https://drafts.csswg.org/css-writing-modes-4/#x-axis) line.

 [flip-start]

 : swaps the values of the
 [start](https://www.w3.org/TR/css-writing-modes-4/#start) properties with each other, and the
 [end](https://www.w3.org/TR/css-writing-modes-4/#end) properties with each other (between, for
 example,
 [margin-block-start](https://www.w3.org/TR/css-logical-1/#propdef-margin-block-start) and
 [margin-inline-start](https://www.w3.org/TR/css-logical-1/#propdef-margin-inline-start)), essentially mirroring
 across a diagonal drawn from the
 [start](https://www.w3.org/TR/css-writing-modes-4/#block-start)-[start](https://www.w3.org/TR/css-writing-modes-4/#inline-start) corner to the
 [end](https://www.w3.org/TR/css-writing-modes-4/#block-end)-[end](https://www.w3.org/TR/css-writing-modes-4/#inline-end) corner.

 If multiple keywords are given, the transformations are composed in
 order to produce a single [position
 option](#position-options). Logical directions are resolved against the
 [writing
 mode](https://www.w3.org/TR/css-writing-modes-4/#writing-mode) of the [containing
 block](https://www.w3.org/TR/css-display-4/#containing-block).

[[\<dashed-ident\>](https://www.w3.org/TR/css-values-4/#typedef-dashed-ident) \|\| [\<try-tactic\>](#typedef-position-try-fallbacks-try-tactic)]

: Combines the effects of the previous two options: if there is a
 [\@position-try](#at-ruledef-position-try) rule with the given name, applies its
 [position option](#position-options) to the base style, then transforms it according to
 the specified
 [\<try-tactic\>](#typedef-position-try-fallbacks-try-tactic) and adds the result to the box's
 [position options
 list](#position-options-list).

 Otherwise, does nothing.

[[\<position-area\>](#typedef-position-area)]

: Automatically creates a [position
 option](#position-options) composed solely of a
 [position-area](#propdef-position-area) property with the given value.

### 6.2. Determining Fallback Order: the [position-try-order property]
Name:

[position-try-order]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

normal
[\|](https://www.w3.org/TR/css-values-4/#comb-one)
[\<try-size\>](#typedef-try-size)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

normal

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[absolutely positioned
boxes](https://www.w3.org/TR/css-position-3/#absolute-position)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

This property allows an element to sort its [position option
list] by the available space they produce. This allows the
box to prioritize having more layout space over strictly following the
order declared in
[position-try-fallbacks](#propdef-position-try-fallbacks).

``` prod
<try-size> = most-width | most-height | most-block-size | most-inline-size
```

[normal]

: Try the [position
 options](#position-options) in the order specified by
 [position-try-fallbacks](#propdef-position-try-fallbacks).

[most-width]\
[most-height]\
[most-block-size]\
[most-inline-size]

: For each entry in the [position options
 list](#position-options-list), [apply that position
 option](#apply-a-position-option) to the box, and find the [inset-modified containing
 block](https://www.w3.org/TR/css-position-3/#inset-modified-containing-block) size that results from those styles (treating
 [auto](https://www.w3.org/TR/css-position-3/#valdef-top-auto)
 [inset](https://www.w3.org/TR/css-position-3/#propdef-inset) values as zero). Stably sort
 the [position options list]
 according to this size, with the largest coming first.

 Logical directions are resolved against the [writing
 mode](https://www.w3.org/TR/css-writing-modes-4/#writing-mode) of the [containing
 block](https://www.w3.org/TR/css-display-4/#containing-block).

For example, the following styles will
initially position the popup list either above or below its anchoring
button, depending on which option gives it the most space.

``` highlight
.anchor { anchor-name: --foo; }
.list {
 position: fixed;
 position-anchor: --foo;
 position-area: block-end span-inline-end;
 position-try-fallbacks: --bottom-scrollable, flip-block, --top-scrollable;
 position-try-order: most-height;
}
@position-try --bottom-scrollable {
 align-self: stretch;
}
@position-try --top-scrollable {
 position-area: block-start span-inline-end;
 align-self: stretch;
}
```

The [base styles](#fallback-base-styles) and the [\--bottom-scrollable] option have the
same available height, since in both cases the [inset-modified
containing
block](https://www.w3.org/TR/css-position-3/#inset-modified-containing-block) stretches from the anchor to the edge of the containing
block. Likewise the
[flip-block](#valdef-position-try-fallbacks-flip-block) option and the [\--top-scrollable] options
have the same available height. Because
[position-try-order](#propdef-position-try-order) uses a stable sort, these pairs
will each retain their relative positions in the list, with the
[\*-scrollable] option coming later; and the pair that has the
most space available will come first.

This causes the box to first try to align against the anchor at its
natural height on whichever side is larger (using the [base
styles](#fallback-base-styles) or
[flip-block](#valdef-position-try-fallbacks-flip-block) styles) but if that causes overflow, it'll fall
back to just filling the same space and being scrollable instead (using
the matching [\*-scrollable] styles), thus never overflowing and
trying to move to the smaller space.

### 6.3. The [position-try Shorthand]
Name:

[position-try]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'position-try-order\'\>](#propdef-position-try-order)[?](https://www.w3.org/TR/css-values-4/#mult-opt)
[\<\'position-try-fallbacks\'\>](#propdef-position-try-fallbacks)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

see individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

see individual properties

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

This shorthand sets both
[position-try-fallbacks](#propdef-position-try-fallbacks) and
[position-try-order](#propdef-position-try-order). If
[\<\'position-try-order\'\>] is omitted, it's set to the property's initial value.

### 6.4. The [\@position-try Rule]
The [\@position-try] rule defines a [position
option](#position-options)
with a given name, specifying one or more sets of positioning properties
that can be applied to a box via
[position-try-fallbacks](#propdef-position-try-fallbacks).

The syntax of the
[\@position-try](#at-ruledef-position-try) rule is:

``` prod
@position-try <dashed-ident> {
 <declaration-list>
}
```

The
[\<dashed-ident\>](https://www.w3.org/TR/css-values-4/#typedef-dashed-ident) specified in the prelude is the
rule's name. If multiple
[\@position-try](#at-ruledef-position-try) rules are declared with the same name, they
[cascade](https://www.w3.org/TR/css-cascade-6/#cascade) (overriding each other) the same as
[\@keyframes](https://www.w3.org/TR/css-animations-1/#at-ruledef-keyframes) rules do.

The
[\@position-try](#at-ruledef-position-try) rule only accepts the following [accepted
\@position-try properties]:

- [inset
 properties](https://www.w3.org/TR/css-logical-1/#inset-properties)

- [margin
 properties](https://www.w3.org/TR/css-box-4/#margin-properties)

- [sizing
 properties](https://www.w3.org/TR/css-sizing-3/#sizing-property)

- [self-alignment
 properties](https://www.w3.org/TR/css-align-3/#self-alignment-properties)

- [position-anchor](#propdef-position-anchor)

- [position-area](#propdef-position-area)

It is invalid to use [!important] on the properties in the
[\<declaration-list\>](https://www.w3.org/TR/css-syntax-3/#typedef-declaration-list). Doing so causes the property it is
used on to become invalid, but does not invalidate the
[\@property-try] rule as a whole.

All of the properties in a
[\@position-try](#at-ruledef-position-try) are applied to the box as part of the [Position
Fallback Origin], a new [cascade
origin](https://www.w3.org/TR/css-cascade-6/#origin) that lies between the [Author
Origin](https://www.w3.org/TR/css-cascade-5/#cascade-origin-author) and the [Animation
Origin](https://www.w3.org/TR/css-cascade-5/#cascade-origin-animation).

Similar to the [Animation
Origin](https://www.w3.org/TR/css-cascade-5/#cascade-origin-animation), use of the
[revert](https://www.w3.org/TR/css-cascade-5/#valdef-all-revert) value acts as if the property was part of the
[Author
Origin](https://www.w3.org/TR/css-cascade-5/#cascade-origin-author), so that it instead reverts back to the [User
Origin](https://www.w3.org/TR/css-cascade-5/#cascade-origin-user). (As with the [Animation
Origin], however,
[revert-layer](https://www.w3.org/TR/css-cascade-5/#valdef-all-revert-layer) has no special behavior and acts as specified.)

 The [accepted \@position-try
properties](#accepted-position-try-properties) are the smallest group of properties that affect just
the size and position of the box itself, without otherwise changing its
contents or styling. This significantly simplifies the implementation of
position fallback while addressing the fundamental need to move an
anchor-positioned box in response to available space. Since these rules
override normal declarations in the [Author
Origin](https://www.w3.org/TR/css-cascade-5/#cascade-origin-author), this also limits the poor interactions of
[\@position-try](#at-ruledef-position-try) declarations with the normal cascading and
inheritance of other properties. It is expected that a future extension
to [container
queries](https://www.w3.org/TR/css-conditional-5/#container-query) will allow querying an element based on the position
fallback it's using, enabling the sort of conditional styling not
allowed by this restricted list.

 If multiple elements want to use the same
[\@position-try](#at-ruledef-position-try) rules, but relative to their own anchor
elements, omit the
[\<anchor-name\>](#typedef-anchor-name) in
[anchor()](#funcdef-anchor) and specify each box's anchor in
[position-anchor](#propdef-position-anchor) instead.

 The most common types of fallback positioning (putting
the positioned box on one side of the anchor normally, but flipping to
the opposite side if needed) can be done automatically with keywords in
[position-try-fallbacks](#propdef-position-try-fallbacks), without using
[\@position-try](#at-ruledef-position-try) at all.

### 6.5. Applying Position Fallback

When a positioned box (after applying any [default scroll
shift](#default-scroll-shift)) overflows its [inset-modified containing
block](https://www.w3.org/TR/css-position-3/#inset-modified-containing-block), and has more than one [position
option](#position-options)
in its [position options
list](#position-options-list), it [determines position fallback
styles](#determine-position-fallback-styles) to attempt to find an option that avoids overflow. The
resulting styles are applied to the element via
[interleaving](#style--layout-interleave), so they affect [computed
values](https://www.w3.org/TR/css-cascade-5/#computed-value) (and can trigger transitions/etc) even though they
depend on layout and [used
values](https://www.w3.org/TR/css-cascade-5/#used-value).

Implementations may choose to impose an implementation-defined limit on
the length of [position options
lists](#position-options-list), to limit the amount of excess layout work that may be
required. This limit must be *at least* five.

To [determine position fallback
styles] for an element `abspos`:

1. Let `current styles` be the current used styles of
 `abspos`, as derived from the [computed base
 style](#computed-base-style) (which might be the result of earlier fallback).

2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `option` in the [position options
 list](#position-options-list):

 1. If `option` is currently `abspos`'s [last
 successful position
 option](#last-successful-position-option),
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 2. Let `adjusted styles` be the result of [applying a
 position
 option](#apply-a-position-option) `option` to `abspos`.

 3. Let `el rect` be the size and position of
 `abspos`'s margin box, and `cb rect` be
 the size and position of `abspos`'s [inset-modified
 containing
 block](https://www.w3.org/TR/css-position-3/#inset-modified-containing-block), when laid out with
 `adjusted styles`.

 4. If `cb rect` was negative-size in either axis and
 corrected into zero-size,
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 This prevents a zero-size `el rect`
 from still being considered \"inside\" a negative-size
 `cb rect` and getting selected as a successful
 option.

 5. If `el rect` is not fully contained within
 `cb rect`,
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 6. Return `adjusted styles`, along with the associated
 set of [remembered scroll
 offsets](#remembered-scroll-offset) that were hypothetically calculated for them.

3. Assert: The previous step finished without finding a [position
 option](#position-options) that avoids overflow.

4. Return `current styles`.

 Descendants overflowing `el` don't affect
this calculation, only `el`'s own [margin
box](https://www.w3.org/TR/css-box-4/#margin-box).

 Because we purposely skip the [position
option](#position-options)
currently in effect, it doesn't get its [remembered scroll
offsets](#remembered-scroll-offset) updated; if none of the other fallbacks work and we
stick with the current styles, all the [remembered scroll
offsets] stay the same.

During a full layout pass, once a box has determined its fallback styles
(or determined it's not using any), laying out later boxes cannot change
this decision.

For example, say you have two
positioned boxes, A and B, with A laid out before B. If B overflows and
causes A's containing block to gain scrollbars, this *does not* cause A
to go back and re-determine its fallback styles in an attempt to avoid
overflowing. (At best, this can result in exponential layout costs; at
worst, it's cyclic and will never settle.)

Layout does not \"go backward\", in other words.

#### 6.5.1. Maintaining and Clearing Fallback Choices

Some changes to a box have a particularly direct effect on [determining
position fallback
styles](#determine-position-fallback-styles) and thus trigger special behavior. These
[fallback-sensitive changes] include:

- Its computed
 [position](https://www.w3.org/TR/css-position-3/#propdef-position) value has changed, its
 [containing
 block](https://www.w3.org/TR/css-display-4/#containing-block) association has changed, or it no longer generates a
 box.

- Its computed value for any
 [longhand](https://www.w3.org/TR/css-cascade-5/#longhand) of
 [position-try](#propdef-position-try) has changed.

- Its computed value for any [accepted \@position-try
 property](#accepted-position-try-properties) has changed.

- Any of the
 [\@position-try](#at-ruledef-position-try) rules referenced by it have been added,
 removed, or mutated.

For this purpose, only changes to the [computed base
style] are considered, i.e. the [computed
value](https://www.w3.org/TR/css-cascade-5/#computed-value) ignoring any declarations originating from the
Transitions or Animations [cascade
origins](https://www.w3.org/TR/css-cascade-6/#origin).

##### 6.5.1.1. Recording the [last successful position option]
In order to maintain layout stability as much as possible, [determining
position fallback
styles](#determine-position-fallback-styles) prioritizes the [last successful position
option](#last-successful-position-option), which is determined as follows:

At the time that
[`ResizeObserver`](https://www.w3.org/TR/resize-observer-1/#resizeobserver) events are determined and delivered, the box must
[record the last successful position
option] as follows:

- If `el` has a [last successful position
 option](#last-successful-position-option) remove its [last successful position
 option] if any
 [fallback-sensitive
 changes](#fallback-sensitive-changes) have occurred. Then, [determine position fallback
 styles](#determine-position-fallback-styles) for `el` and set its [last successful
 position option] to the set
 of [accepted \@position-try
 properties](#accepted-position-try-properties) (and values) that it's now using.

- Otherwise, if a box `el` is [absolutely
 positioned](https://www.w3.org/TR/css-position-3/#absolute-position), set its [last successful position
 option] to the set of [accepted \@position-try
 properties](#accepted-position-try-properties) (and values) that it's currently using.

 The timing of this recording/removal is intentionally
identical to the treatment of [last remembered
sizes](https://www.w3.org/TR/css-sizing-4/#last-remembered).

#### 6.5.2. Applying Position Options

To [apply a position option] to a box's element `el`, given a
[position option](#position-options) `new styles`:

1. With `new styles` inserted into the cascade in the
 [position fallback
 origin](#position-fallback-origin), resolve the cascade, and perform enough layout to
 determine `el`'s [used
 styles](https://www.w3.org/TR/css-cascade-5/#used-value).

 For the purpose of calculating these styles, a *hypothetical*
 [anchor recalculation
 point](#anchor-recalculation-point) is calculated, and the resulting hypothetical
 [remembered scroll
 offsets](#remembered-scroll-offset) are used to determine `el`'s styles.

2. Return `el`'s [used
 styles](https://www.w3.org/TR/css-cascade-5/#used-value).

To [execute a try-tactic] to a set of `styles` of a box's
element `el`, between two directions `directions`,
returning a set of transformed styles:

0. If `directions` are opposites along the same axis, they
 are "opposing". Otherwise (when they are specifying different
 axises), they are "perpendicular".

1. Determine the specified values of the [accepted \@position-try
 properties](#accepted-position-try-properties) on `el`, and let `styles` be
 the result.

2. [Substitute
 variables](https://www.w3.org/TR/css-variables-1/#substitute-a-var),
 [env()](https://www.w3.org/TR/css-env-1/#funcdef-env) functions, and similar [arbitrary
 substitution
 functions](https://www.w3.org/TR/css-values-5/#arbitrary-substitution-function) in `styles`.

 For
 [env()](https://www.w3.org/TR/css-env-1/#funcdef-env) functions, if the referenced [environment
 variable](https://www.w3.org/TR/css-env-1/#css-environment-variable) is associated with a direction or axis (such as
 [safe-area-inset-top](https://www.w3.org/TR/css-env-1/#valdef-env-safe-area-inset-top)), switch the referenced [environment
 variable] corresponding to
 `directions`.

 :::
 (#example-cf4633b5) For example, if [top:
 env(safe-area-inset-top);](https://www.w3.org/TR/css-position-3/#propdef-top) is specified, and `directions`
 are up and left, the
 [env()](https://www.w3.org/TR/css-env-1/#funcdef-env) will resolve as if
 [env(safe-area-inset-left)] had been specified instead. (And
 then, in the next step, will actually swap into the
 [left](https://www.w3.org/TR/css-position-3/#propdef-left) property.)
 :::

3. Swap the values of the `styles` between the associated
 properties corresponding to `directions`.

 :::
 (#example-6de96d49) For example, if \"top\" and
 \"left\" are being swapped, then the values of
 [margin-top](https://www.w3.org/TR/css-box-4/#propdef-margin-top) and
 [margin-left](https://www.w3.org/TR/css-box-4/#propdef-margin-left) are swapped,
 [width](https://www.w3.org/TR/css-sizing-3/#propdef-width) and
 [height](https://www.w3.org/TR/css-sizing-3/#propdef-height) are swapped, etc.
 :::

 If the directions are opposites along the same
 axis, some properties (like
 [width](https://www.w3.org/TR/css-sizing-3/#propdef-width) or
 [align-self](#propdef-align-self)) wont\' swap, since they're
 associated with themselves across the two directions, but their
 values might be changed by the next step.

4. Modify the values of the properties as they swap to match the new
 directions, as follows:

 - For [inset
 properties](https://www.w3.org/TR/css-logical-1/#inset-properties), change the specified side in
 [anchor()](#funcdef-anchor) functions to maintain the same relative
 relationship to the new direction that they had to the old.

 If a
 [\<percentage\>](https://www.w3.org/TR/css-values-4/#percentage-value) is used, and
 `directions` are opposing, change it to [100%]
 minus the original percentage.

 :::
 (#example-0646df49) For example, if \"top\" and
 \"left\" are being swapped, then [margin-top:
 anchor(bottom)](https://www.w3.org/TR/css-box-4/#propdef-margin-top) will become [margin-left:
 anchor(right)](https://www.w3.org/TR/css-box-4/#propdef-margin-left).
 If \"top\" and \"bottom\" are being swapped, then [margin-top:
 anchor(20%)](https://www.w3.org/TR/css-box-4/#propdef-margin-top) will become [margin-bottom:
 anchor(80%)](https://www.w3.org/TR/css-box-4/#propdef-margin-bottom).
 :::

 - For [sizing
 properties](https://www.w3.org/TR/css-sizing-3/#sizing-property), change the specified axis in
 [anchor-size()](#funcdef-anchor-size) functions to maintain the same relative
 relationship to the new direction that they had to the old.

 :::
 (#example-07698d48) For example, if \"top\" and
 \"left\" are being swapped, then [width:
 anchor-size(width)](https://www.w3.org/TR/css-sizing-3/#propdef-width) will become [height:
 anchor-size(height)](https://www.w3.org/TR/css-sizing-3/#propdef-height).
 :::

 - For the [self-alignment
 properties](https://www.w3.org/TR/css-align-3/#self-alignment-properties), if `directions` are opposing, change
 the specified
 [\<self-position\>](https://www.w3.org/TR/css-align-3/#typedef-self-position) (or [left]/[right]
 keywords), if any, to maintain the same relative relationship to
 the new direction that they had to the old.

 :::
 (#example-fc13ccd1) For example, if \"top\" and
 \"bottom\" are being swapped, then [align-self:
 start](#propdef-align-self) will become [align-self:
 end].
 However, [align-self:
 center](#propdef-align-self) will remain unchanged, as it has the same
 relationship to both directions.

 Similarly, [align-self: first
 baseline](#propdef-align-self) will remain unchanged, as it's a
 [\<baseline-position\>](https://www.w3.org/TR/css-align-3/#typedef-baseline-position) rather than a
 [\<self-position\>](https://www.w3.org/TR/css-align-3/#typedef-self-position).
 :::

 - For
 [position-area](#propdef-position-area), change the value so that the
 selected rows/columns of the [position-area
 grid](#position-area-grid) maintain the same relative relationship to the
 new direction that they had to the old.

 :::
 (#example-5641c582) For example, if \"top\" and
 \"left\" are being swapped, then [position-area: left
 span-bottom](#propdef-position-area) will become [position-area: top
 span-right].
 :::

5. Return `styles`.

### 6.6. Conditional Hiding: the [position-visibility property]
Name:

[position-visibility]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

always
[\|](https://www.w3.org/TR/css-values-4/#comb-one) \[ anchor-valid
[\|\|](https://www.w3.org/TR/css-values-4/#comb-any) anchor-visible [\|\|]
no-overflow \]

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

anchor-visible

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[absolutely positioned
boxes](https://www.w3.org/TR/css-position-3/#absolute-position)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

There are some conditions in which it might not make sense to display an
[absolutely positioned
box](https://www.w3.org/TR/css-position-3/#absolute-position). This property allows such boxes to be made
conditionally visible, depending on some commonly needed layout
conditions.

[always]

: This property has no effect. (The box is displayed without regard
 for its anchors or its overflowing status.)

[anchor-valid]

: If the box references the [default anchor
 box](#default-anchor-box) (e.g. using
 [position-area](#propdef-position-area), \'anchor()\' or
 \'anchor-size()\' functions, or
 [anchor-center](#valdef-justify-self-anchor-center)), but the [default anchor
 box] cannot be resolved, the box's
 [visibility](https://www.w3.org/TR/css-display-4/#propdef-visibility) property computes to
 [force-hidden](https://www.w3.org/TR/css-display-4/#valdef-visibility-force-hidden).

[anchor-visible]

: If the box has a [default anchor
 box](#default-anchor-box) but that [anchor
 box](#anchor-box) is
 [invisible] or [clipped by intervening
 boxes](#clipped-by-intervening-boxes), the box's
 [visibility](https://www.w3.org/TR/css-display-4/#propdef-visibility) property computes to
 [force-hidden](https://www.w3.org/TR/css-display-4/#valdef-visibility-force-hidden).

[no-overflow]

: If the box overflows its [inset-modified containing
 block](https://www.w3.org/TR/css-position-3/#inset-modified-containing-block) even after applying
 [position-try](#propdef-position-try), the box's
 [visibility](https://www.w3.org/TR/css-display-4/#propdef-visibility) property computes to
 [force-hidden](https://www.w3.org/TR/css-display-4/#valdef-visibility-force-hidden).

An anchor box `anchor` is [clipped by intervening
boxes] relative to a positioned box `abspos` relying on
it if `anchor`'s [ink overflow
rectangle](https://www.w3.org/TR/css-overflow-3/#ink-overflow-rectangle) is fully clipped by a box which is an ancestor of
`anchor` but a descendant of `abspos`'s containing
block. Clipping in this case refers only to the same clipping effects
that are (by default) checked by
[`IntersectionObserver`](https://www.w3.org/TR/intersection-observer/#intersectionobserver), i.e. clipping due to
[clip-path](https://www.w3.org/TR/css-masking-1/#propdef-clip-path),
[overflow](https://www.w3.org/TR/css-overflow-3/#propdef-overflow), or other effects (such as [paint
containment](https://www.w3.org/TR/css-contain-2/#paint-containment)) that clip to the [overflow clip
edge](https://www.w3.org/TR/css-overflow-4/#overflow-clip-edge). If `anchor` has non-zero area, it must also
have a non-zero intersection area to be considered not fully clipped.

Whether or not `anchor` is [clipped by intervening
boxes](#clipped-by-intervening-boxes) must be checked after [updating content relevancy for a
document](https://drafts.csswg.org/css-contain-2/#update-content-relevancy-for-a-document) (see
[content-visibility](https://www.w3.org/TR/css-contain-2/#propdef-content-visibility) in
[\[css-contain-2\]](#biblio-css-contain-2 "CSS Containment Module Level 2"))
and running any
[`ResizeObserver`](https://www.w3.org/TR/resize-observer-1/#resizeobserver), but before running any
[`IntersectionObserver`](https://www.w3.org/TR/intersection-observer/#intersectionobserver). It may also be checked at other times to improve
responsiveness.

 This means that if an abspos is next to its anchor in
the DOM, for example, it'll remain visible even if its default anchor is
scrolled off, since it's clipped by the same scroller anyway.

Make sure this definition of clipped is
consistent with View Transitions, which wants a similar concept.

 This ensures that in a "chained anchor" situation, if
the first abspos is hidden due to this property (due to its anchor being
scrolled off), then another abspos using it as an anchor will also be
hidden, rather than *also* floating in a nonsensical location.

User agents may recognize [anchors-valid] and
[anchors-visible] as [legacy value
aliases](https://www.w3.org/TR/css-cascade-5/#css-legacy-value-alias) of
[anchor-valid](#valdef-position-visibility-anchor-valid) and
[anchor-visible](#valdef-position-visibility-anchor-visible) (but are not required to).

## 7. Accessibility Implications

**CSS Anchor Positioning does not create, delete, or alter any
accessibility bindings between elements. Authors must use appropriate
markup features to control such bindings.**

Because it can be used in many different ways for many different use
cases, CSS Anchor Positioning does not automatically establish any
semantic relationship between a positioned box and any of its anchors.
For example, the *visual* anchoring relationship in a design might be
between an element and its *semantic* anchor, or it might connect the
element to an ancestor, sibling, or descendant of the semantic anchor,
depending on the desired visual effect. Siimilarly, a design might opt
out of a visual anchoring relationship even while there is a semantic
one, or vice versa.

Authors must not rely on the visual connections implied by CSS
positioning to link elements together semantically. Without appropriate
markup, the elements linked visually have *no* meaningful DOM
relationship---​which if there *is* a meaningful relationship, can make
them difficult or impossible to use in non-visual user agents, like
screen readers, or in non-graphical navigation modes, such as tab
navigation.

Many features on the web platform, both existing and upcoming, allow
establishing semantic connections explicitly, so that non-visual user
agents can also benefit. For example, the [Popover API in
HTML](https://html.spec.whatwg.org/multipage/popover.html#the-popover-attribute)
automatically links the invoker button to the popover element, including
automatically adjusting tabbing order; it *also* establishes the invoker
button as the [implicit anchor
element](#implicit-anchor-element) for the popover, making it easy to use Anchor
Positioning as well.

Add a popover example.

In more general cases, ARIA features such as the
[`aria-details`](https://w3c.github.io/aria/#aria-details) or
[`aria-describedby`](https://w3c.github.io/aria/#aria-describedby)
attributes on an anchor element can create connections in a slightly
more manual fashion. In concert with the
[`role`](https://w3c.github.io/aria/#host_general_role) attribute on the positioned element, it allows
non-visual user agents to tell their users about the relationship
between the elements and let them automatically navigate between them.

However, authors should not overuse such features either, since
overburdening the page with extra, unnecessary semantic connections can
also make the page difficult to comprehend.

Suggestions for ways to improve this
section, especially author guidance and examples of best practices for
common use cases, is welcome. [\[Issue
#10311\]](https://github.com/w3c/csswg-drafts/issues/10311)

## 8. DOM Interfaces

### 8.1. The CSSPositionTryRule interface

The
[`CSSPositionTryRule`](#csspositiontryrule) interface represents the
[\@position-try](#at-ruledef-position-try) rule:

```
[Exposed=Window]
interface CSSPositionTryRule : CSSRule {
 readonly attribute CSSOMString name;
 [SameObject, PutForwards=cssText] readonly attribute CSSPositionTryDescriptors style;
};

[Exposed=Window]
interface CSSPositionTryDescriptors : CSSStyleDeclaration {
 attribute CSSOMString margin;
 attribute CSSOMString marginTop;
 attribute CSSOMString marginRight;
 attribute CSSOMString marginBottom;
 attribute CSSOMString marginLeft;
 attribute CSSOMString marginBlock;
 attribute CSSOMString marginBlockStart;
 attribute CSSOMString marginBlockEnd;
 attribute CSSOMString marginInline;
 attribute CSSOMString marginInlineStart;
 attribute CSSOMString marginInlineEnd;
 attribute CSSOMString margin-top;
 attribute CSSOMString margin-right;
 attribute CSSOMString margin-bottom;
 attribute CSSOMString margin-left;
 attribute CSSOMString margin-block;
 attribute CSSOMString margin-block-start;
 attribute CSSOMString margin-block-end;
 attribute CSSOMString margin-inline;
 attribute CSSOMString margin-inline-start;
 attribute CSSOMString margin-inline-end;
 attribute CSSOMString inset;
 attribute CSSOMString insetBlock;
 attribute CSSOMString insetBlockStart;
 attribute CSSOMString insetBlockEnd;
 attribute CSSOMString insetInline;
 attribute CSSOMString insetInlineStart;
 attribute CSSOMString insetInlineEnd;
 attribute CSSOMString top;
 attribute CSSOMString left;
 attribute CSSOMString right;
 attribute CSSOMString bottom;
 attribute CSSOMString inset-block;
 attribute CSSOMString inset-block-start;
 attribute CSSOMString inset-block-end;
 attribute CSSOMString inset-inline;
 attribute CSSOMString inset-inline-start;
 attribute CSSOMString inset-inline-end;
 attribute CSSOMString width;
 attribute CSSOMString minWidth;
 attribute CSSOMString maxWidth;
 attribute CSSOMString height;
 attribute CSSOMString minHeight;
 attribute CSSOMString maxHeight;
 attribute CSSOMString blockSize;
 attribute CSSOMString minBlockSize;
 attribute CSSOMString maxBlockSize;
 attribute CSSOMString inlineSize;
 attribute CSSOMString minInlineSize;
 attribute CSSOMString maxInlineSize;
 attribute CSSOMString min-width;
 attribute CSSOMString max-width;
 attribute CSSOMString min-height;
 attribute CSSOMString max-height;
 attribute CSSOMString block-size;
 attribute CSSOMString min-block-size;
 attribute CSSOMString max-block-size;
 attribute CSSOMString inline-size;
 attribute CSSOMString min-inline-size;
 attribute CSSOMString max-inline-size;
 attribute CSSOMString placeSelf;
 attribute CSSOMString alignSelf;
 attribute CSSOMString justifySelf;
 attribute CSSOMString place-self;
 attribute CSSOMString align-self;
 attribute CSSOMString justify-self;
 attribute CSSOMString positionAnchor;
 attribute CSSOMString position-anchor;
 attribute CSSOMString positionArea;
 attribute CSSOMString position-area;
};
```

Its [`name`] attribute
represents the name declared in the rule's prelude.

Its [`style`] attribute
represents the properties declared in the rule's body, in the specified
order. On getting, it must return a
[`CSSPositionTryDescriptors`](#csspositiontrydescriptors) object for the
[\@position-try](#at-ruledef-position-try) at-rule, with the following properties:

[computed flag](https://www.w3.org/TR/cssom-1/#cssstyledeclaration-computed-flag)

: Unset

[readonly flag](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-readonly-flag)

: Unset

[declarations](https://www.w3.org/TR/cssom-1/#cssstyledeclaration-declarations)

: The declared descriptors in the rule, in [specified
 order](https://www.w3.org/TR/cssom-1/#concept-declarations-specified-order).

[parent CSS rule](https://www.w3.org/TR/cssom-1/#cssstyledeclaration-parent-css-rule)

: The context object

[owner node](https://www.w3.org/TR/cssom-1/#cssstyledeclaration-owner-node)

: Null

## 9. Appendix: Style & Layout Interleaving

[Style & layout interleaving] is a technique where a style update can
occur on a subtree during the layout process, resulting in retroactive
updates to elements' [computed
styles](https://www.w3.org/TR/css-cascade-5/#computed-value).

This is not the correct spec for this
concept, it should probably go in
[Cascade](https://www.w3.org/TR/css-cascade/), but I need a sketch of it
to refer to.

 [Style & layout
interleaving](#style--layout-interleave) is already used with [container
queries](https://www.w3.org/TR/css-conditional-5/#container-query) and [container query
lengths](https://www.w3.org/TR/css-conditional-5/#container-query-length). A length like [10cqw] is resolved into a
[computed
length](https://www.w3.org/TR/css-values-4/#computed-length) using layout information about the query container's
size, which can thus trigger
[transitions](https://www.w3.org/TR/css-transitions-1/) when the
container changes size between layouts.

The [accepted \@position-try
properties](#accepted-position-try-properties) are also
[interleaved](#style--layout-interleave) when resolving fallback (see
[position-try](#propdef-position-try)).

Obviously this needs way more details
filled in, but for now \"act like you already do for container queries\"
suffices. That behavior is also undefined, but at least it's
interoperable (to some extent?).

## 10. Security Considerations

No Security issues have been raised against this document.

## 11. Privacy Considerations

No Privacy issues have been raised against this document.

## 12. Changes

Significant changes since the [27 March 2026 Working
Draft](https://www.w3.org/TR/2026/WD-css-anchor-position-1-20260327/):

- Defined
 [anchor-valid](#valdef-position-visibility-anchor-valid) to (like
 [anchor-valid]) only check the [default anchor
 box](#default-anchor-box). ([Issue
 10201](https://github.com/w3c/csswg-drafts/issues/10201))

- Renamed [anchors-valid] and [anchors-visible] to
 [anchor-valid](#valdef-position-visibility-anchor-valid) and
 [anchor-visible](#valdef-position-visibility-anchor-visible) since they only reference the [default anchor
 box](#default-anchor-box). ([Issue
 10201](https://github.com/w3c/csswg-drafts/issues/10201))

Significant changes since the [30 January 2026 Working
Draft](https://www.w3.org/TR/2026/WD-css-anchor-position-1-20260130/):

- Added [match-parent] value to
 [position-area](#propdef-position-area). ([Issue
 8913](https://github.com/w3c/csswg-drafts/issues/8913))

- Marked
 [position-area](#propdef-position-area) as discretely animatable. ([Issue
 13577](https://github.com/w3c/csswg-drafts/issues/13577))

- Removed
 [anchor-center](#valdef-justify-self-anchor-center) from
 [align-items](https://www.w3.org/TR/css-align-3/#propdef-align-items) and
 [justify-items](https://www.w3.org/TR/css-align-3/#propdef-justify-items) because those properties have no
 effect on absolutely-positioned boxes anyway. ([Issue
 13514](https://github.com/w3c/csswg-drafts/issues/13514))

Significant changes since the [22 December 2025 Working
Draft](https://www.w3.org/TR/2025/WD-css-anchor-position-1-20251222/):

- Clarify position fallback interaction with transitions and animation.
 ([Issue 13048](https://github.com/w3c/csswg-drafts/issues/13048))

- Clarify that intersection must be non-zero (when anchor box is
 non-zero) for
 [anchors-visible](https://www.w3.org/TR/css-anchor-position-1/#valdef-position-visibility-anchors-visible). ([Issue
 13176](https://github.com/w3c/csswg-drafts/issues/13176))

- Change anchor-finding to first look at ancestors, then only look at
 other elements if that fails. This is more consistent with timeline
 name lookups. ([Issue
 13364](https://github.com/w3c/csswg-drafts/issues/13364))

- Added [position-anchor:
 normal](#propdef-position-anchor) as the new initial value. ([Issue
 13067](https://github.com/w3c/csswg-drafts/issues/13067))

Significant changes since the [7 October 2025 Working
Draft](https://www.w3.org/TR/2025/WD-css-anchor-position-1-20251007/):

- Add
 [flip-x](#valdef-position-try-fallbacks-flip-x) and
 [flip-y](#valdef-position-try-fallbacks-flip-y) to
 [position-try-fallbacks](#propdef-position-try-fallbacks). ([Issue
 12869](https://github.com/w3c/csswg-drafts/issues/12869))

- Define
 [anchor-center](#valdef-justify-self-anchor-center) to also use the [scrollable containing
 block](https://www.w3.org/TR/css-position-4/#scrollable-containing-block) so that it doesn't trigger overflow alignment when
 positioned outside the [local containing
 block](https://www.w3.org/TR/css-position-4/#local-containing-block). ([Issue
 12952](https://github.com/w3c/csswg-drafts/issues/12952))

- Resolve [auto] margins to zero when
 [position-area](#propdef-position-area) or
 [anchor-center](#valdef-justify-self-anchor-center) is in effect, due to the ill-considered HTML
 UA default stylesheet rules for popovers. Also drop the [dialog]
 alignment value which was the previous attempt to address this
 problem. ([Issue
 10258](https://github.com/w3c/csswg-drafts/issues/10258))

- Add
 [none](#valdef-position-anchor-none) value to
 [position-anchor](#propdef-position-anchor) and make it the initial value to
 avoid switching all absolutely positioned boxes that have an [implicit
 anchor
 element](#implicit-anchor-element) to using the [scrollable containing
 block](https://www.w3.org/TR/css-position-4/#scrollable-containing-block). Note the initial value may change again, as the
 discussion is still open\... ([Issue
 13067](https://github.com/w3c/csswg-drafts/issues/13067))

- Clarify that
 [flip-block](#valdef-position-try-fallbacks-flip-block),
 [flip-inline](#valdef-position-try-fallbacks-flip-inline), and
 [flip-start](#valdef-position-try-fallbacks-flip-start) use the [writing
 mode](https://www.w3.org/TR/css-writing-modes-4/#writing-mode) of the [containing
 block](https://www.w3.org/TR/css-display-4/#containing-block). ([Issue
 12869](https://github.com/w3c/csswg-drafts/issues/12869), [Issue
 13076](https://github.com/w3c/csswg-drafts/issues/13076))

- Clarify that
 [auto](https://www.w3.org/TR/css-position-3/#valdef-top-auto)
 [inset](https://www.w3.org/TR/css-position-3/#propdef-inset) values are treated as zero when
 finding the [inset-modified containing
 block](https://www.w3.org/TR/css-position-3/#inset-modified-containing-block) size for comparing [position
 options](#position-options) in
 [position-try-order](#propdef-position-try-order). ([Issue
 12942](https://github.com/w3c/csswg-drafts/issues/12942))

- Add
 [clip-path](https://www.w3.org/TR/css-masking-1/#propdef-clip-path) to the list of clipping effects
 considered for
 [anchors-visible](https://www.w3.org/TR/css-anchor-position-1/#valdef-position-visibility-anchors-visible) and clarify the timing of its checks. ([Issue
 12732](https://github.com/w3c/csswg-drafts/issues/12732))

- Fix error where base styles were accidentally left out of the
 [position options
 list](#position-options-list). ([Issue
 12890](https://github.com/w3c/csswg-drafts/issues/12890))

- Clarify timing of
 [anchors-visible](https://www.w3.org/TR/css-anchor-position-1/#valdef-position-visibility-anchors-visible) checks. ([Issue
 12732](https://github.com/w3c/csswg-drafts/issues/12732))

- Clarify that the
 [normal](https://www.w3.org/TR/css-align-3/#valdef-align-self-normal) alignment resolution based on the
 [position-area](#propdef-position-area) value affects the [used
 value](https://www.w3.org/TR/css-cascade-5/#used-value) (which then keys into how overflow is handled per
 [\[CSS-ALIGN-3\]](#biblio-css-align-3 "CSS Box Alignment Module Level 3")).

- Fix algorithm error requiring matching tree roots for anchor name
 matching, since it is sometimes possible to match across shadow tree
 boundaries. ([Issue
 12941](https://github.com/w3c/csswg-drafts/issues/12941))

- Clarify that
 [auto](https://www.w3.org/TR/css-position-3/#valdef-top-auto)
 [inset](https://www.w3.org/TR/css-position-3/#propdef-inset) values are treated as zero when
 finding the [inset-modified containing
 block](https://www.w3.org/TR/css-position-3/#inset-modified-containing-block) size for
 [position-try-order](#propdef-position-try-order). ([Issue
 12942](https://github.com/w3c/csswg-drafts/issues/12942))

- Reorganize prose in [§ 6 Overflow Management](#fallback) and [§ 2
 Determining the Anchor](#determining) for better readability. ([Issue
 12818](https://github.com/w3c/csswg-drafts/issues/12811), [Issue
 11022](https://github.com/w3c/csswg-drafts/issues/12811))

- Improve guidance in [§ 7 Accessibility Implications](#accessibility)
 and clarify UA requirements. ([Issue
 10311](https://github.com/w3c/csswg-drafts/issues/10311))

- Improve examples.

See also [Previous
Changes](https://www.w3.org/TR/2025/WD-css-anchor-position-1-20251007/#changes).
