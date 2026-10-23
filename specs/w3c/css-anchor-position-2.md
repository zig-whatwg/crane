## 1. Delta specification

This is a delta specification, meaning that it currently contains only
the differences from CSS Anchor Positioning Level 1
[\[CSS-ANCHOR-POSITION-1\]](#biblio-css-anchor-position-1 "CSS Anchor Positioning Module Level 1").

## 2. Container Queries for Anchor Positioning

This section extends [container
queries](https://drafts.csswg.org/css-conditional-5/#container-query) from
[\[css-conditional-5\]](#biblio-css-conditional-5 "CSS Conditional Rules Module Level 5")
to allow querying certain aspects of elements using [anchor
positioning](https://drafts.csswg.org/css-anchor-position-1/#anchor-positioning).

### [2.1. ][Extending [container-type](https://drafts.csswg.org/css-conditional-5/#propdef-container-type) with [anchored](#valdef-container-type-anchored)]
This specification extends the [container-type] property defined
in [CSS Conditional 5 § 5.1 Creating Query Containers: the
container-type
property](https://drafts.csswg.org/css-conditional-5/#container-type)
with a new
[anchored](#valdef-container-type-anchored) keyword.
[anchored] can be
combined with existing container types such as
[scroll-state](https://drafts.csswg.org/css-conditional-5/#valdef-container-type-scroll-state) and
[size](https://drafts.csswg.org/css-conditional-5/#valdef-container-type-size):

``` prod
normal | [ [ size | inline-size ] || scroll-state || anchored ]
```

[anchored]

: Establishes a [query
 container](https://drafts.csswg.org/css-conditional-5/#query-container) for [container
 queries](https://drafts.csswg.org/css-conditional-5/#container-query), allowing for descendants of an anchor positioned
 element to be styled based on certain features of the anchoring.
 (Currently, limited to which of the
 [position-try-fallbacks](https://drafts.csswg.org/css-anchor-position-1/#propdef-position-try-fallbacks) are applied, if any.)

 The
 [anchored](#valdef-container-type-anchored) container-type applies [style
 containment](https://drafts.csswg.org/css-contain-2/#style-containment) to the [query
 container](https://drafts.csswg.org/css-conditional-5/#query-container).

 :::
 NOTE: [Style
 containment](https://drafts.csswg.org/css-contain-2/#style-containment) is necessary to avoid a layout cycle for the
 following case using
 [counters](https://www.w3.org/TR/CSS2/generate.html#counters):
 - We have an
 [anchored](#valdef-container-type-anchored) container

 - A
 [counter](https://drafts.csswg.org/css-lists-3/#counter) is incremented by a descendant of the anchored
 container based on a fallback query.

 - An
 [in-flow](https://drafts.csswg.org/css-display-4/#in-flow) element, following the anchored container in tree
 order, generates content, with the counter, affecting the size of
 the [in-flow] element.

 - The
 [in-flow](https://drafts.csswg.org/css-display-4/#in-flow) element affects the position / size of the
 [anchor
 element](https://drafts.csswg.org/css-anchor-position-1/#anchor-element). In fact, the [in-flow] may be
 the [anchor element] itself.

 - The changed position / size of the [anchor
 element](https://drafts.csswg.org/css-anchor-position-1/#anchor-element) may change which fallback is chosen, which in
 turn affects the anchored query evaluation, hence the counter
 increment.
 :::

A container can be just
[anchored](#valdef-container-type-anchored), or combined with other container types:

```
#anchored { container-type: anchored; }
#anchored-size { container-type: anchored inline-size; }
```

### [2.2. ][Extending [\@container](https://drafts.csswg.org/css-conditional-5/#at-ruledef-container) syntax for [anchored](#valdef-container-type-anchored) queries]
To query an
[anchored](#valdef-container-type-anchored) container, a new `anchored()` function is added
to the
[\@container](https://drafts.csswg.org/css-conditional-5/#at-ruledef-container) syntax. It extends the container query syntax by
adding the following production to the
\'[\<query-in-parens\>](https://drafts.csswg.org/css-conditional-5/#typedef-query-in-parens)\' grammar:

```
<query-in-parens> = ...
 | anchored( <anchored-query> )

<anchored-query> = not <anchored-in-parens>
 | <anchored-in-parens> [ [ and <anchored-in-parens> ]* | [ or <anchored-in-parens> ]* ]
 | <anchored-feature>
<anchored-in-parens> = ( <anchored-query> )
 | ( <anchored-feature> )
 | <general-enclosed>
```

### 2.3. Anchored Container Features

#### [2.3.1. ][ Applied [position-try-fallbacks](https://drafts.csswg.org/css-anchor-position-1/#propdef-position-try-fallbacks): the [fallback](#descdef-container-fallback) feature]
Name:

[fallback]

For:

[\@container](https://drafts.csswg.org/css-conditional-5/#at-ruledef-container)

Value:

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) \[
\[[\<dashed-ident\>](https://drafts.csswg.org/css-values-4/#typedef-dashed-ident)
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any)
[\<try-tactic\>](https://drafts.csswg.org/css-anchor-position-1/#typedef-position-try-fallbacks-try-tactic)\] [\|]
[\<position-area-query\>](#typedef-position-area-query) \]

Type:

discrete

The
[fallback](#descdef-container-fallback) [container
feature](https://drafts.csswg.org/css-conditional-5/#container-feature) queries whether an anchor positioned element has any of
its computed
[position-try-fallbacks](https://drafts.csswg.org/css-anchor-position-1/#propdef-position-try-fallbacks) options applied.

[none]
: The
 [anchored](#valdef-container-type-anchored) container does not have any
 [position-try-fallbacks](https://drafts.csswg.org/css-anchor-position-1/#propdef-position-try-fallbacks) applied.

[\<dashed-ident\>](https://drafts.csswg.org/css-values-4/#typedef-dashed-ident) \|\| [\<try-tactic\>](https://drafts.csswg.org/css-anchor-position-1/#typedef-position-try-fallbacks-try-tactic)

: The
 [anchored](#valdef-container-type-anchored) container matches a combination of
 [\<dashed-ident\>](https://drafts.csswg.org/css-values-4/#typedef-dashed-ident) and
 [\<try-tactic\>](https://drafts.csswg.org/css-anchor-position-1/#typedef-position-try-fallbacks-try-tactic) applied from
 [position-try-fallbacks](https://drafts.csswg.org/css-anchor-position-1/#propdef-position-try-fallbacks). If any of the
 [[\<dashed-ident\>](https://drafts.csswg.org/css-values-4/#typedef-dashed-ident)] or
 [[\<try-tactic\>](https://drafts.csswg.org/css-anchor-position-1/#typedef-position-try-fallbacks-try-tactic)] are left out of the query
 value, they need to be left out in the applied value from
 [position-try-fallbacks], and vice versa, in order to match.

 The
 [[\<dashed-ident\>](https://drafts.csswg.org/css-values-4/#typedef-dashed-ident)] try rule name is not
 considered to be a [tree-scoped
 name](https://drafts.csswg.org/css-shadow-1/#css-tree-scoped-name) for the sake of matching
 [fallback](#descdef-container-fallback).

 The order of
 [\<try-tactic\>](https://drafts.csswg.org/css-anchor-position-1/#typedef-position-try-fallbacks-try-tactic)s is significant. For instance
 `flip-start flip-block` is not the same as `flip-block flip-start`.
 Hence, the order must match for
 [fallback](#descdef-container-fallback) queries.

[\<position-area-query\>](#typedef-position-area-query)

: The
 [anchored](#valdef-container-type-anchored) container has a
 [[\<position-area\>](https://drafts.csswg.org/css-anchor-position-1/#typedef-position-area)] applied from
 [position-try-fallbacks](https://drafts.csswg.org/css-anchor-position-1/#propdef-position-try-fallbacks). The query matches if the
 applied
 [[\<position-area\>](https://drafts.csswg.org/css-anchor-position-1/#typedef-position-area)] from the fallback and the
 query value represent the same physical area. That is,
 [block-start](#valdef-position-area-query-block-start) will match
 [top](https://drafts.csswg.org/css-anchor-position-1/#valdef-position-area-top) when the
 [writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode) is
 [horizontal-tb](https://drafts.csswg.org/css-writing-modes-4/#valdef-writing-mode-horizontal-tb).

 A query value of
 [any](#valdef-position-area-query-any) always matches for the given axis.

Add an arrow whose direction depends
on whether an element is positioned to the left or right of its anchor:

```
#container {
 container-type: anchored;
 position: absolute;
 position-anchor: --a;
 position-area: left;
 position-try-fallbacks: right;
 &::before { content: ">"; }

 @container anchored(fallback: right) {
 &::before { content: "<"; };
 }
}
```

Matching named fallback option with
\'[\<try-tactic\>](https://drafts.csswg.org/css-anchor-position-1/#typedef-position-try-fallbacks-try-tactic)\':

```
.anchored {
 container-type: anchored;
 position-try-fallbacks: --foo, --bar flip-inline;

 @container anchored(fallback: --bar flip-inline) {
 /* Applies if the '--bar' fallback applies */
 .inner { background-color: green; }
 }
 @container anchored(fallback: --bar) {
 /* Does not apply because the try-tactic also must match */
 .inner { background-color: red; }
 }
}
```

Matching
\'[\<position-area\>](https://drafts.csswg.org/css-anchor-position-1/#typedef-position-area)\' fallback option in vertical
[writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode):

```
.anchored {
 container-type: anchored;
 position-anchor: --a;
 position-try-fallbacks: right;
 writing-mode: vertical-rl;

 @container anchored(fallback: self-block-start) {
 /* Applies if the 'right' fallback applies since block-start is 'right'
 in 'vertical-rl'. */
 .inner { background-color: green; }
 }
}
```

Matching
\'[\<position-area\>](https://drafts.csswg.org/css-anchor-position-1/#typedef-position-area)\' fallback option with
[any](#valdef-position-area-query-any):

```
.anchored {
 container-type: anchored;
 position-anchor: --a;
 position-try-fallbacks: bottom right;
 writing-mode: vertical-rl;

 @container anchored(fallback: bottom any) {
 /* Applies because 'any' matches 'right'. */
 .inner { color: lime; }
 }
 @container anchored(fallback: right) {
 /* Applies because implicit 'any' in the vertical axis matches 'bottom'. */
 .inner { background-color: green; }
 }
}
```

#### 2.3.2. Syntax of [\<position-area-query\> Values]
Values for querying position-area fallbacks have the same syntax as
[\<position-area\>](https://drafts.csswg.org/css-anchor-position-1/#typedef-position-area), with an additional
[any](#valdef-position-area-query-any) keyword added to every production:

``` prod
<position-area-query> = [
 [ left | center | right | span-left | span-right
 | x-start | x-end | span-x-start | span-x-end
 | self-x-start | self-x-end | span-self-x-start | span-self-x-end
 | span-all | any ]
 ||
 [ top | center | bottom | span-top | span-bottom
 | y-start | y-end | span-y-start | span-y-end
 | self-y-start | self-y-end | span-self-y-start | span-self-y-end
 | span-all | any ]
|
 [ block-start | center | block-end | span-block-start | span-block-end | span-all | any ]
 ||
 [ inline-start | center | inline-end | span-inline-start | span-inline-end
 | span-all | any ]
|
 [ self-block-start | center | self-block-end | span-self-block-start
 | span-self-block-end | span-all | any ]
 ||
 [ self-inline-start | center | self-inline-end | span-self-inline-start
 | span-self-inline-end | span-all | any ]
|
 [ start | center | end | span-start | span-end | span-all | any ]{1,2}
|
 [ self-start | center | self-end | span-self-start | span-self-end | span-all | any ]{1,2}
]
```

[any]

: [any](#valdef-position-area-query-any) can be used for one or both of the axes. It
 is ambiguous about which axis it refers to, and is handled like
 other ambiguous keywords for
 \'[\<position-area\>](https://drafts.csswg.org/css-anchor-position-1/#typedef-position-area)\' such as
 [start](#valdef-position-area-query-start) or
 [center](#valdef-position-area-query-center) when it comes to assigning axis and
 duplicating single keyword values.

[start], [end], [self-start], [self-end]\
[top], [bottom], [left], [right]\
[y-start], [y-end], [self-y-start], [self-y-end]\
[x-start], [x-end], [self-x-start], [self-x-end]\
[block-start], [block-end], [self-block-start], [self-block-end]\
[inline-start], [inline-end], [self-inline-start], [self-inline-end]\
[center]\
[span-start], [span-end], [span-self-start], [span-self-end]\
[span-top], [span-bottom], [span-left], [span-right]\
[span-y-start], [span-y-end], [span-self-y-start], [span-self-y-end]\
[span-x-start], [span-x-end], [span-self-x-start], [span-self-x-end]\
[span-block-start], [span-block-end], [span-self-block-start], [span-self-block-end]\
[span-inline-start], [span-inline-end], [span-self-inline-start], [span-self-inline-end]\
[span-all]

: See respective definitions for
 \'[\<position-area\>](https://drafts.csswg.org/css-anchor-position-1/#typedef-position-area)\'.

If only a single keyword is given,
\'[\<position-area-query\>](#typedef-position-area-query)\' behaves as if the second keyword is
[any](#valdef-position-area-query-any) if the given keyword is unambigous about its
axis. This is different from how single keywords are handled for
\'[\<position-area\>](https://drafts.csswg.org/css-anchor-position-1/#typedef-position-area)\', which behaves as if the second
keyword is
[span-all](#valdef-position-area-query-span-all). Otherwise,
\'[\<position-area-query\>]\' behaves as
\'[\<position-area\>]\'
when it comes to assigning axes.

## 3. Security Considerations

No Security issues have been raised against this document.

## 4. Privacy Considerations

No Privacy issues have been raised against this document.
