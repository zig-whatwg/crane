## 1. Introduction

This is currently an early draft of the
things that are *new* in level 5. The features in Level 3 and Level 4
are still defined in
[\[css-conditional-3\]](#biblio-css-conditional-3 "CSS Conditional Rules Module Level 3")
and
[\[css-conditional-4\]](#biblio-css-conditional-4 "CSS Conditional Rules Module Level 4")
and have not yet been copied here.

CSS Conditional Level 5 extends the
[\@supports](https://www.w3.org/TR/css-conditional-3/#at-ruledef-supports) rule and [supports
query](https://www.w3.org/TR/css-conditional-3/#supports-queries) syntax to allow testing for custom support conditions
as well as supported
[at-rules](https://www.w3.org/TR/css-syntax-3/#at-rule) and font technologies.

It also adds an [\@when](#at-ruledef-when) rule, which generalizes the concept of a
conditional rule. Anything that can be expressed in an existing
conditional rule can be expressed in [\@when] by wrapping it in an appropriate function to declare what kind of
condition it is. This allow authors to easily combine multiple types of
queries, such as media queries and supports queries, in a single boolean
expression. Without this, authors must rely on nesting separate
conditional rules, which is harder to read and write, presupposes the
conditions are to be conjoined with the "and" boolean relation (with no
easy way to indicate anything else), and restricts their utility in the
proposed [conditional rule
chains](#conditional-rule-chain).

It also adds [\@else](#at-ruledef-else) rules, which immediately follow other conditional
rules and automatically qualify their conditions as the inverse of the
immediately preceding rule's conditions, such that only the first
matching rule in a [conditional rule
chain](#conditional-rule-chain) is applied.

It also adds Container Queries. They are conceptually similar to Media
Queries, but allow testing aspects of elements within the document (such
as box dimensions or computed styles), rather than on the document as a
whole.

## [2. ][ Extensions to the [\@supports](https://www.w3.org/TR/css-conditional-3/#at-ruledef-supports) rule]
This level of the specification extends the
[\<supports-feature\>](#typedef-supports-feature) syntax as follows:

```
<supports-feature> = <supports-selector-fn>
 | <supports-font-tech-fn> | <supports-font-format-fn>
 | <supports-at-rule-fn> | <supports-named-feature-fn>
 | <supports-env-fn> | <supports-decl>
<supports-decl> = ( [ <declaration> | <supports-condition-name> ] )
<supports-font-tech-fn> = font-tech( <font-tech> )
<supports-font-format-fn> = font-format( <font-format> )
<supports-at-rule-fn> = at-rule( <at-keyword-token> )
<supports-named-feature-fn> = named-feature( <ident> )
<supports-env-fn> = env( <ident> )
```

[\<declaration\>] here matches anything that would be
successfully parsed by [consume a
declaration](https://www.w3.org/TR/css-syntax-3/#consume-a-declaration), ignoring the context-validation check at the end of
that algorithm. [Notably, this includes a trailing [!important],
which is valid but ignored for the purpose of
[\@supports](https://www.w3.org/TR/css-conditional-3/#at-ruledef-supports).]

[\<supports-condition-name\>](#typedef-supports-condition-name)

: The result is true if the UA [supports the named
 condition](#dfn-supports-condition-name).
 If the name is not recognized, the result is false.

[font-tech( [\<font-tech\>](https://www.w3.org/TR/css-fonts-4/#font-tech-values) )]

: The result is true if the UA [supports the font
 tech](#dfn-support-font-tech) provided as an argument to the function.

[font-format( [\<font-format\>](https://www.w3.org/TR/css-fonts-4/#font-format-values) )]

: The result is true if the UA [supports the font
 format](#dfn-support-font-format) provided as an argument to the function.

[at-rule( [\<at-keyword-token\>](https://www.w3.org/TR/css-syntax-3/#typedef-at-keyword-token) )]

: The result is true if the UA [supports the
 at-rule](#dfn-support-at-rule) provided as an argument to the function.

[named-feature( [\<ident\>](https://www.w3.org/TR/css-values-4/#typedef-ident) )]

: The result is true if the UA [supports the named
 feature](#dfn-support-named-feature) provided as an argument to the function.

[env( [\<ident\>](https://www.w3.org/TR/css-values-4/#typedef-ident) )]

: The result is true if the UA [supports the environment
 variable](#dfn-support-env) provided as an argument to the function.

### 2.1. Extensions to the definition of support

#### 2.1.1. Font techs and formats

A CSS processor is considered to [support a font
tech]
when it is capable of utilizing the specified [CSS Fonts 4 § 11.1 Font
tech](https://www.w3.org/TR/css-fonts-4/#font-tech-definitions) in
layout and rendering.

A CSS processor is considered to [support a font
format] when it is capable
of utilizing the specified [CSS Fonts 4 § 11.2 Font
formats](https://www.w3.org/TR/css-fonts-4/#font-format-definitions) in
layout and rendering, and this format is not specified as a
[\<string\>](https://www.w3.org/TR/css-values-4/#string-value).

#### 2.1.2. At-rules

A CSS processor is considered to [support an
at-rule]
if it would accept an
[at-rule](https://www.w3.org/TR/css-syntax-3/#at-rule) beginning with the specified at-keyword within any
context.

 Because
[\@charset](https://www.w3.org/TR/css-syntax-3/#at-ruledef-charset) is not a valid
[at-rule](https://www.w3.org/TR/css-syntax-3/#at-rule), it is not considered to be supported under this
definition.

#### 2.1.3. Named features

A CSS processor is considered to [support a named
feature] if it supports
the named feature based on the feature definition described in the
following list:

[anchor-position-follows-transforms]

: Anchoring to a transformed element automatically takes into account
 the anchor's transforms, causing the positioned element to shift to
 match it. \[CSS-ANCHOR-POSITIONING\]

 (An earlier version of the specification did not take transforms
 into account.)

[single-axis-scroll-container]

: The ability to have [single-axis scroll
 containers](https://drafts.csswg.org/css-overflow-3/#single-axis-scroll-container), where one axis is scrollable and the other is
 [clip](https://www.w3.org/TR/css-overflow-3/#valdef-overflow-clip).
 [\[CSS-OVERFLOW-4\]](#biblio-css-overflow-4 "CSS Overflow Module Level 4")

 (Previously, specifying
 [clip](https://www.w3.org/TR/css-overflow-3/#valdef-overflow-clip) alongside a scrollable value caused it to
 compute to
 [hidden](https://www.w3.org/TR/css-overflow-3/#valdef-overflow-hidden), which is still a scrollable value even if
 it doesn't generate a scrollbar.)

If the feature is not listed the processor does not support the named
feature.

 The CSS Working Group intends to add features to this
list rarely, when there is real demand for feature testing something
specific and it would be unreasonable to add a more general feature
testing mechanism that would cover the use case.

#### 2.1.4. Named conditions

A CSS processor is considered to [support a named
condition] when the
related [named supports
condition](#named-supports-condition) returns true.

#### 2.1.5. Environment variables

A CSS processor is considered to [support an environment
variable]
if the
[\<ident\>](https://www.w3.org/TR/css-values-4/#typedef-ident) is a supported [environment
variable](https://www.w3.org/TR/css-env-1/#css-environment-variable).

## 3. Generalized Conditional Rules: the [\@when rule]
The [\@when] at-rule is a [conditional group
rule](https://www.w3.org/TR/css-conditional-3/#conditional-group-rule) that generalizes the individual [conditional group
rules] such as
[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media) and
[\@supports](https://www.w3.org/TR/css-conditional-3/#at-ruledef-supports). It is defined as:

```
@when <boolean-condition> {
 <rule-list>
}
```

Where
[[\<boolean-condition\>](#typedef-boolean-condition)] is a boolean algebra a la [Media
Queries 4 § 3 Syntax](https://www.w3.org/TR/mediaqueries-4/#mq-syntax),
but with [media()](#funcdef-media) and
[supports()](#funcdef-supports) functions as leaves.

Define \"boolean algebra, with X as
leaves\" in a generic way in Conditional, so all the conditional rules
can reference it directly, rather than having to redefine boolean
algebra on their own.

The [media()](#funcdef-media) and
[supports()](#funcdef-supports) functions are defined as:

```
media() = media( [ <mf-plain> | <mf-boolean> | <mf-range> ] )
supports() = supports( <declaration> )
```

A [media()](#funcdef-media) or
[supports()](#funcdef-supports) function is associated with the boolean result that
its contained condition is associated with.

## 4. Chained Conditionals: the [\@else rule]
Usually, [conditional group
rules](https://www.w3.org/TR/css-conditional-3/#conditional-group-rule) are independent; each one has a separate condition
evaluated without direct reference to any other rule, and decides
whether or not to apply its contained rules based solely on its
condition.

This is fine for simple conditions, but makes it difficult to write a
collection of conditionals that are meant to be mutually exclusive:
authors have to very carefully craft their conditions to not activate
when the other rules are meant to, and make sure the collection of
conditionals don't accidentally *all* exclude some situation which is
then left unstyled.

The [\@else] rule is a [conditional group
rule](https://www.w3.org/TR/css-conditional-3/#conditional-group-rule) used to form [conditional rule
chains](#conditional-rule-chain), which associate multiple [conditional group
rules] and guarantee that only the
first one that matches will evaluate its condition as true. It is
defined as:

```
@else <boolean-condition>? {
 <rule-list>
}
```

[\@else](#at-ruledef-else) is interpreted identically to
[\@when](#at-ruledef-when). If its
[\<boolean-condition\>](#typedef-boolean-condition) is omitted, it's treated as having a
condition that's always true.

A [conditional rule chain] is a series of consecutive [conditional group
rules](https://www.w3.org/TR/css-conditional-3/#conditional-group-rule), starting with a [conditional group
rule] other than
[\@else](#at-ruledef-else), followed by zero or more
[\@else] rules. There cannot be anything
between the successive [conditional group
rules] other than whitespace and/or
comments; any other token "breaks" the chain.

Should we require that only the last
[\@else](#at-ruledef-else) in a chain can have an omitted condition? It's not
uncommon for me, when debugging code, to short-circuit an if-else chain
by setting one of them to \"true\"; I presume that would be similarly
useful in CSS? It's still pretty easy to see you've done something wrong
if you omit the condition accidentally.

Within a [conditional rule
chain](#conditional-rule-chain), the conditions of each [conditional group
rule](https://www.w3.org/TR/css-conditional-3/#conditional-group-rule) are evaluated in order. If one of them is true, the
conditions of all *following* [conditional group
rules] in the chain evaluate to false,
regardless of their stated condition.

An [\@else](#at-ruledef-else) rule that is not part of a [conditional rule
chain](#conditional-rule-chain) is invalid and must be ignored.

For example, here's a (somewhat silly)
conditional chain:

```
@when media(width >= 400px) and media(pointer: fine) and supports(display: flex) {
 /* A */
} @else supports(caret-color: pink) and supports(background: double-rainbow()) {
 /* B */
} @else {
 /* C */
}
```

Exactly one of the preceding rules will be chosen, even though the
second rule doesn't exclude large widths, fine points, or flexbox
support, and the last rule doesn't specify anything at all.

To achieve the same result without [conditional rule
chains](#conditional-rule-chain), you'd need to write:

```
@media (width >= 400px) and (pointer: fine) {
 @supports (display: flex) {
 /* A */
 }
 @supports not (display: flex) {
 @supports (caret-color: pink) and (background: double-rainbow()) {
 /* B */
 }
 @supports not ((caret-color: pink) and (background: double-rainbow())) {
 /* C */
 }
 }
}
@media not ((width >= 400px) and (pointer: fine)) {
 @supports (caret-color: pink) and (background: double-rainbow()) {
 /* B */
 }
 @supports not ((caret-color: pink) and (background: double-rainbow())) {
 /* C */
 }
}
```

This is simultaneously hard to read, requires significant duplication of
both conditions and contents, and is *very* difficult to write
correctly. If the conditions got any more complicated (which is not
unusual in real-world content), the example would get *significantly*
worse.

In this example, three different color
font technologies are tested, in order of preference, plus a monochrome
fallback. The most capable, COLRv1, supports both gradients and font
variations; the next best choice, SVG, supports gradients while the
least capable, COLRv0, supports flat color fill only.

The fallback has no test condition, so will always be chosen unless one
of the earlier conditions succeeds.

```
@when font-tech(color-COLRv1) and font-tech(variations) {
 @font-face { font-family: icons; src: url(icons-gradient-var.woff2); }
}
@else font-tech(color-SVG) {
 @font-face { font-family: icons; src: url(icons-gradient.woff2); }
}
@else font-tech(color-COLRv0) {
 @font-face { font-family: icons; src: url(icons-flat.woff2); }
}
@else {
 @font-face { font-family: icons; src: url(icons-fallback.woff2); }
}
```

Notice that in this example, the variable color font is only downloaded
if COLRv1 is supported and font variations are also supported.

Notice too that only one of the available options will be downloaded;
this would not be the case without
[\@when](#at-ruledef-when) and
[\@else](#at-ruledef-else), as the next example shows.

In this example, although it appears
that the fallback will not be used if COLRv1 is supported, in fact both
fonts will be downloaded, which wastes bandwidth if it is not used.

The fallback might still be used for some characters; for example, if
the color font supports only Latin, while the fallback supports Latin
and Greek.

```
@font-face { font-family: icons; src: url(icons-fallback.woff2);
@supports font-tech(color-COLRv1) {
 @font-face { font-family: icons; src: url(icons-gradient-var.woff2); }
}
```

## 5. Container Queries

While [media
queries](https://www.w3.org/TR/mediaqueries-5/#media-query) provide a method to query aspects of the user agent or
device environment that a document is being displayed in (such as
viewport dimensions or user preferences), [container
queries](#container-query)
allow testing aspects of elements within the document (such as box
dimensions or computed styles).

By default, all elements are [query containers] for the
purpose of [container style
queries](#container-style-query), and can be established as [query
containers](#query-container)
for [container size
queries](#container-size-query) and [container scroll-state
queries](#container-scroll-state-query) by specifying the additional query types using the
[container-type](#propdef-container-type) property (or the
[container](#propdef-container)
[shorthand](https://www.w3.org/TR/css-cascade-5/#shorthand-property)). Style rules applying to a [query
container]'s [flat
tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) descendants can be conditioned by querying against it,
using the
[\@container](#at-ruledef-container) [conditional group
rule](https://www.w3.org/TR/css-conditional-3/#conditional-group-rule).

An ancestor element that generates a box is not an eligible container
for [container size
queries](#container-size-query) if that box is not an ancestor box of any boxes
generated by the querying element.

There are cases where the box for a
[pseudo-element](https://www.w3.org/TR/selectors-4/#pseudo-element) is generated as a sibling box of its originating
element's box. If we allowed querying the size of a sibling box, it
would introduce layout cycles.

For example, the
[::scroll-marker-group](https://www.w3.org/TR/css-overflow-5/#selectordef-scroll-marker-group) and [::scroll-button()] pseudo-elements
generate sibling boxes of their originating element's box. These
pseudo-elements will not be able to query their originating scroller for
[container size
queries](#container-size-query). They will, however, be able to query other eligible
[query container](#query-container) ancestors.

For example, we can define the main
content area and sidebar as containers, and then describe a
[.media-object] that changes from vertical to horizontal layout
depending on the size of its container:

```
main, aside {
 container: my-layout / inline-size;
}

.media-object {
 display: grid;
 grid-template: 'img' auto 'content' auto / 100%;
}

@container my-layout (inline-size > 45em) {
 .media-object {
 grid-template: 'img content' auto / auto 1fr;
 }
}
```

Media objects in the main and sidebar areas will each respond to their
own container context.

For the
[::part()](https://drafts.csswg.org/css-shadow-1/#selectordef-part) and
[::slotted()](https://drafts.csswg.org/css-shadow-1/#selectordef-slotted)
[pseudo-element](https://www.w3.org/TR/selectors-4/#pseudo-element) selectors, which represent real elements in the DOM
tree, [query containers](#query-container) can be established by [flat
tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) ancestors of those elements. For other
[pseudo-element]s, [query
containers] can be established by inclusive
[flat tree] ancestors of their [originating
element](https://www.w3.org/TR/selectors-4/#originating-element).

It follows that:

- [::before](https://www.w3.org/TR/css-pseudo-4/#selectordef-before),
 [::after](https://www.w3.org/TR/css-pseudo-4/#selectordef-after),
 [::marker](https://www.w3.org/TR/css-pseudo-4/#selectordef-marker), and
 [::backdrop](https://www.w3.org/TR/css-position-4/#selectordef-backdrop) query their originating elements

- [::first-letter](https://www.w3.org/TR/css-pseudo-4/#selectordef-first-letter) and
 [::first-line](https://www.w3.org/TR/css-pseudo-4/#selectordef-first-line) query their originating elements, even if the
 [fictional tag
 sequence](https://www.w3.org/TR/css-pseudo-4/#fictional-tag-sequence) may push the `::first-line` past other
 elements for the purpose of inheritance and rendering

- [::slotted()](https://drafts.csswg.org/css-shadow-1/#selectordef-slotted) selectors can query containers inside the
 shadow tree, including the slot itself

- [::slotted()::before] selectors can query the slotted shadow
 host child

- [::part()](https://drafts.csswg.org/css-shadow-1/#selectordef-part) selectors can query containers inside the
 shadow tree

- [::placeholder](https://www.w3.org/TR/css-pseudo-4/#selectordef-placeholder) and
 [::file-selector-button](https://www.w3.org/TR/css-pseudo-4/#selectordef-file-selector-button) can query the input element, but do not expose
 any internal containers if the input element is implemented using a
 shadow tree

A ::before selector querying the size
of the originating element:

```
<style>
 #container {
 width: 100px;
 container-type: inline-size;
 }
 @container (inline-size < 150px) {
 #inner::before {
 content: "BEFORE";
 }
 }
</style>
<div id=container>
 <span id=inner></span>
</div>
```

A ::slotted() selector for styling a
shadow host child can query a container in the shadow tree:

```
<div id=host style="width:200px">
 <template shadowroot=open>
 <style>
 #container {
 width: 100px;
 container-type: inline-size;
 }
 @container (inline-size < 150px) {
 ::slotted(span) {
 color: green;
 }
 }
 </style>
 <div id=container>
 <slot />
 </div>
 </template>
 <span id=slotted>Green</span>
</div>
```

### 5.1. Creating Query Containers: the [container-type property]
Name:

[container-type]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

normal
[\|](https://www.w3.org/TR/css-values-4/#comb-one) \[ \[ size [\|] inline-size \]
[\|\|](https://www.w3.org/TR/css-values-4/#comb-any) scroll-state \]

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

normal

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

not animatable

The
[container-type](#propdef-container-type) property establishes the element as
a [query container](#query-container) for certain types of queries. For size [container
queries](#container-query),
which require certain types of containment, elements are explicitly made
[query containers] through this property. For
other types of [query containers] any element
can be a [query container], such as for
[container style
queries](#container-style-query).

Values have the following meanings:

[size]
: Establishes a [query
 container](#query-container) for [container size
 queries](#container-size-query) on both the
 [inline](https://www.w3.org/TR/css-writing-modes-4/#inline-axis) and [block
 axis](https://www.w3.org/TR/css-writing-modes-4/#block-axis). Applies [style
 containment](https://www.w3.org/TR/css-contain-2/#style-containment) and [size
 containment](https://www.w3.org/TR/css-contain-2/#size-containment) to the [principal
 box](https://www.w3.org/TR/css-display-4/#principal-box), and establishes an [independent formatting
 context](https://www.w3.org/TR/css-display-4/#independent-formatting-context).

[inline-size]
: Establishes a [query
 container](#query-container) for [container size
 queries](#container-size-query) on the container's own [inline
 axis](https://www.w3.org/TR/css-writing-modes-4/#inline-axis). Applies [style
 containment](https://www.w3.org/TR/css-contain-2/#style-containment) and [inline-size
 containment](https://www.w3.org/TR/css-contain-3/#inline-size-containment) to the [principal
 box](https://www.w3.org/TR/css-display-4/#principal-box), and establishes an [independent formatting
 context](https://www.w3.org/TR/css-display-4/#independent-formatting-context).

[scroll-state]

: Establishes a [query
 container](#query-container) for [container scroll-state
 queries](#container-scroll-state-query). For queries that match the state of the scroller
 itself (such as [scrollable]), the element is only a [query
 container] on the element's own
 [scrollable
 axises](https://drafts.csswg.org/css-overflow-3/#scrollable-axis).

 This means that a [scrollable] query, for
 example, could query against different containers for
 [scroll-state(scrollable: block)] and
 [scroll-state(scrollable: inline)] queries.

[normal]
: The element is not a [query
 container](#query-container) for any [container size
 queries](#container-size-query) or [container scroll-state
 queries](#container-scroll-state-query), but remains a [query
 container] for [container style
 queries](#container-style-query).

For example, authors can create
container-responsive typography, adjusting
[font-size](https://www.w3.org/TR/css-fonts-4/#propdef-font-size),
[line-height](https://www.w3.org/TR/CSS2/visudet.html#propdef-line-height), and other typographic concerns
based on the size of a container:

```
aside, main {
 container-type: inline-size;
}

h2 { font-size: 1.2em; }

@container (width > 40em) {
 h2 { font-size: 1.5em; }
}
```

The [40em] value used in the query condition is relative to the
[computed
value](https://www.w3.org/TR/css-cascade-5/#computed-value) of
[font-size](https://www.w3.org/TR/css-fonts-4/#propdef-font-size) on the relevant [query
container](#query-container).

Containers can also expose computed
style values for querying. This can be useful for toggling behavior
across multiple properties:

```
@container style(--cards: small) {
 article {
 border: thin solid silver;
 border-radius: 0.5em;
 padding: 1em;
 }
}
```

Containers can also expose state that
depends on scroll offset. This example styles a descendant of a sticky
positioned element when it is stuck to the top edge:

```
#sticky {
 container-type: scroll-state;
 position: sticky;
}
@container scroll-state(stuck: top) {
 #sticky-child {
 background-color: lime;
 }
}
```

### 5.2. Naming Query Containers: the [container-name property]
Name:

[container-name]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://www.w3.org/TR/css-values-4/#comb-one)
[\<custom-ident\>](https://www.w3.org/TR/css-values-4/#identifier-value)[+](https://www.w3.org/TR/css-values-4/#mult-one-plus)

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

the keyword
[none](#valdef-container-name-none), or an ordered list of
[identifiers](https://www.w3.org/TR/css-values-4/#css-css-identifier)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

not animatable

The
[container-name](#propdef-container-name) property specifies a list of [query
container names]. These names can be used by
[\@container](#at-ruledef-container) rules to filter which [query
containers](#query-container) are targeted. Container names are not [tree-scoped
names](https://drafts.csswg.org/css-shadow-1/#css-tree-scoped-name).

[none]
: The [query container](#query-container) has no [query container
 name](#query-container-name).

[[\<custom-ident\>](https://www.w3.org/TR/css-values-4/#identifier-value)]
: Specifies a [query container
 name](#query-container-name) as an
 [identifier](https://www.w3.org/TR/css-values-4/#css-css-identifier). The keywords
 [none](#valdef-container-name-none), [and],
 [not](https://www.w3.org/TR/mediaqueries-5/#valdef-media-not), and [or] are excluded from this
 [\<custom-ident\>](https://www.w3.org/TR/css-values-4/#identifier-value).

In some cases, we want to query
aspects of a specific container, even if it's not the nearest ancestor
container. For example, we might want to query the height of a main
content area, and the width of a more nested inline-container.

```
main {
 container-type: size;
 container-name: my-page-layout;
}

.my-component {
 container-type: inline-size;
 container-name: my-component-library;
}

@container my-page-layout (block-size > 12em) {
 .card { margin-block: 2em; }
}

@container my-component-library (inline-size > 30em) {
 .card { margin-inline: 2em; }
}
```

It is also possible to query for a container only based on its name.

```
@container my-page-layout {
 .card { padding: 1em; }
}
```

### 5.3. Creating Named Containers: the [container shorthand]
Name:

[container]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'container-name\'\>](#propdef-container-name) \[ /
[\<\'container-type\'\>](#propdef-container-type)
\][?](https://www.w3.org/TR/css-values-4/#mult-opt)

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

The [container](#propdef-container) [shorthand
property](https://www.w3.org/TR/css-cascade-5/#shorthand-property) sets both
[container-type](#propdef-container-type) and
[container-name](#propdef-container-name) in the same declaration. If
[\<\'container-type\'\>]
is omitted, it is reset to its [initial
value](https://www.w3.org/TR/css-cascade-5/#initial-value).

We can define both a
[container-type](#propdef-container-type) and
[container-name](#propdef-container-name) using the shorthand syntax:

```
main {
 container: my-layout / size;
}

.grid-item {
 container: my-component / inline-size;
}
```

### 5.4. Container Queries: the [\@container rule]
The [\@container] rule is a [conditional group
rule](https://www.w3.org/TR/css-conditional-3/#conditional-group-rule) whose condition contains a [container
query],
which is a boolean combination of [container size
queries](#container-size-query) and/or [container style
queries](#container-style-query). Style declarations within the
[\@container](#at-ruledef-container) rule are
[filtered](https://www.w3.org/TR/css-cascade-4/#filtering) by its
condition to only match when the [container
query](#container-query) is
true for their element's [query
container](#query-container).

The syntax of the
[\@container](#at-ruledef-container) rule is:

```
@container <container-condition># {
 <rule-list>
}
```

where:

```
<container-condition> = [ <container-name>? <container-query>? ]!
<container-name> = <custom-ident>
<container-query> = not <query-in-parens>
 | <query-in-parens> [ [ and <query-in-parens> ]* | [ or <query-in-parens> ]* ]
<query-in-parens> = ( <container-query> )
 | ( <size-feature> )
 | style( <style-query> )
 | scroll-state( <scroll-state-query> )
 | <general-enclosed>

<style-query> = not <style-in-parens>
 | <style-in-parens> [ [ and <style-in-parens> ]* | [ or <style-in-parens> ]* ]
 | <style-feature>
<style-in-parens> = ( <style-query> )
 | ( <style-feature> )
 | <general-enclosed>
<style-feature> = <style-feature-plain> | <style-feature-boolean> | <style-range>
<style-feature-plain> = <style-feature-name> : <style-feature-value>
<style-feature-boolean> = <style-feature-name>
<style-range> = <style-range-value> <mf-comparison> <style-range-value>
 | <style-range-value> <mf-lt> <style-range-value> <mf-lt> <style-range-value>
 | <style-range-value> <mf-gt> <style-range-value> <mf-gt> <style-range-value>
<style-range-value> = <custom-property-name> | <style-feature-value>

<scroll-state-query> = not <scroll-state-in-parens>
 | <scroll-state-in-parens> [ [ and <scroll-state-in-parens> ]* | [ or <scroll-state-in-parens> ]* ]
 | <scroll-state-feature>
<scroll-state-in-parens> = ( <scroll-state-query> )
 | ( <scroll-state-feature> )
 | <general-enclosed>
```

The keywords
[none](#valdef-container-name-none), [and],
[not](https://www.w3.org/TR/mediaqueries-5/#valdef-media-not), and [or] are excluded from the
[\<custom-ident\>](https://www.w3.org/TR/css-values-4/#identifier-value) above.

For each element, the [query
container](#query-container)
to be queried is selected from among the element's ancestor [query
containers] that are established as a valid
[query container] for all the [container
features](#container-feature) in the
[\<container-query\>](#typedef-container-query). If the
[\<container-query\>]
contains unknown or unsupported [container
feature]s, no [query
container] will be selected for that
[\<container-condition\>](#typedef-container-condition). The
[\<container-name\>](#typedef-container-name) filters the set of [query
containers] considered to just those with a
matching [query container
name](#query-container-name).

Once an eligible [query
container](#query-container)
has been selected for an element, each [container
feature](#container-feature) in the
[\<container-query\>](#typedef-container-query) is evaluated against that [query
container]. If no ancestor is an eligible
[query container], then the [container
query](#container-query) is
[unknown] for that element. As with media queries,
[\<general-enclosed\>](https://www.w3.org/TR/mediaqueries-5/#typedef-general-enclosed) evaluates to [unknown]. If the
[\<container-query\>] is
omitted, the [query container] is eligible
as long as the
[\<container-name\>](#typedef-container-name) matches.

If a [container query](#container-query) includes multiple
[\<container-condition\>](#typedef-container-condition)s, each condition will select it's own
[query container](#query-container), and evaluate independently. A [container
query] is
[true](https://www.w3.org/TR/mediaqueries-5/#valdef-custom-media-true) if *any* of its component
[\<container-condition\>]s are [true], and
[false](https://www.w3.org/TR/mediaqueries-5/#valdef-custom-media-false) only if *all* of its component
[\<container-condition\>]s are [false].

As with [media
queries](https://www.w3.org/TR/mediaqueries-5/#media-query), we can string together multiple queries in a single
condition:

```
@container card (inline-size > 30em) and style(--responsive: true) {
 /* styles */
}
```

The styles above will only be applied if there is an ancestor container
named \"card\" that meets both the
[inline-size](#descdef-container-inline-size) and
[style](#container-style-query) conditions.

We can also combine multiple conditions into a list, with each condition
evaluating against a different container:

```
@container card (inline-size > 30em), style(--large: true) {
 /* styles */
}
```

The styles above will be applied if there is an ancestor container named
\"card\" that meets the
[inline-size](#descdef-container-inline-size) condition *or* the nearest style
container meets the
[style](#container-style-query) condition.

Style rules defined on an element inside multiple nested [container
queries](#container-query)
apply when all of the wrapping [container
queries] are true for that element.

 Nested [container
queries](#container-query)
can evaluate in relation to different containers, so it is not always
possible to merge the individual
[\<container-condition\>](#typedef-container-condition)s into a single query.

Using a single comma-separated
[container query](#container-query), we can query multiple containers:

```
@container card (inline-size > 30em), style(--responsive: true) {
 /* styles */
}
```

The styles above will apply for an element inside *either* a container
named \"card\" that meets the
[inline-size](#descdef-container-inline-size) condition, *or* a container meeting the
[style](#container-style-query) condition.

In order to require that *all* conditions are met while querying
multiple containers, we would need to nest multiple queries:

```
@container card (inline-size > 30em) {
 @container style(--responsive: true) {
 /* styles */
 }
}
```

The styles above will only be applied if there is *both* an ancestor
container named \"card\" that meets the
[inline-size](#descdef-container-inline-size) condition, *and* an ancestor container
meeting the
[style](#container-style-query) condition.

Global, name-defining
[at-rules](https://www.w3.org/TR/css-syntax-3/#at-rule) such as
[\@keyframes](https://www.w3.org/TR/css-animations-1/#at-ruledef-keyframes) or
[\@font-face](https://www.w3.org/TR/css-fonts-5/#at-font-face-rule) or
[\@layer](https://www.w3.org/TR/css-cascade-5/#at-ruledef-layer) that are defined inside [container
queries](#container-query)
are not constrained by the [container query]
conditions.

### 5.5. Animated Containers

A change in the evaluation of a [container
query](#container-query)
must be part of a [style change
event](https://www.w3.org/TR/css-transitions-1/#style-change-event), even when the change occurred because of [animation
effects](https://www.w3.org/TR/web-animations-1/#effect-value).

A transition on a sibling element can
indirectly affect the size of a container, triggering [style change
events](https://www.w3.org/TR/css-transitions-1/#style-change-event) whenever container queries change their evaluation as a
result:

```
main {
 display: flex;
 width: 300px;
}

#container {
 container-type: inline-size;
 flex: 1;
}

/* Resolved width is initially 200px, but changes as the transition
 on #sibling progresses. */
#inner {
 transition: 1s background-color;
 background-color: tomato;
}

/* When this container query starts (or stops) applying, a transition
 must start on background-color on #inner. */
@container (width <= 150px) {
 #inner {
 background-color: skyblue;
 }
}

#sibling {
 width: 100px;
 transition: width 1s;
}

#sibling:hover {
 width: 200px;
}
```

```
<main>
 <div id=container>
 <div id=inner>Inner</div>
 </div>
 <div id=sibling>Sibling</div>
</main>
```

Changes in [computed
values](https://www.w3.org/TR/css-cascade-5/#computed-value) caused by [container query
length](#container-query-length) units must also be part of a [style change
event](https://www.w3.org/TR/css-transitions-1/#style-change-event).

## 6. Container Features

A [container feature] queries a specific aspect of a [query
container](#query-container).

[Container features](#container-feature) use the same rules as [media
features](https://www.w3.org/TR/mediaqueries-5/#media-feature) when evaluating in a [boolean
context](https://www.w3.org/TR/mediaqueries-5/#boolean-context).

### 6.1. Size Container Features

A [container size query] allows querying the size of the [query
container](#query-container)'s [principal
box](https://www.w3.org/TR/css-display-4/#principal-box). It is a boolean combination of individual [size
features]
([\<size-feature\>](#typedef-size-feature)) that each query a single, specific
dimensional feature of the [query
container]. The syntax of a
[[\<size-feature\>](#typedef-size-feature)] is the same as for a [media
feature](https://www.w3.org/TR/mediaqueries-5/#media-feature): a feature name, a comparator, and a value.
[\[mediaqueries-5\]](#biblio-mediaqueries-5 "Media Queries Level 5")
The boolean syntax and logic combining [size
features](#size-features) into a
[size query](#container-size-query) is the same as for [CSS feature
queries](https://www.w3.org/TR/css-conditional-3/#css-feature-queries). (See
[\@supports](https://www.w3.org/TR/css-conditional-3/#at-ruledef-supports).
[\[css-conditional-3\]](#biblio-css-conditional-3 "CSS Conditional Rules Module Level 3"))

If the [query container](#query-container) does not have a [principal
box](https://www.w3.org/TR/css-display-4/#principal-box), or the principal box is not a [layout containment
box](https://www.w3.org/TR/css-contain-2/#layout-containment-box), or the [query container]
does not support [container size
queries](#container-size-query) on the relevant axes, then the result of evaluating the
[size feature](#size-features)
is unknown.

[Relative
length](https://www.w3.org/TR/css-values-4/#relative-length) units (including [container query
length](#container-query-length) units) and [custom
properties](https://www.w3.org/TR/css-variables-1/#custom-property) in [container
query](#container-query)
conditions are evaluated based on the [computed
values](https://www.w3.org/TR/css-cascade-5/#computed-value) of the [query
container](#query-container).

Tree counting functions ([CSS Values 5 § 9 Tree Counting Functions: the
sibling-count() and sibling-index()
notations](https://www.w3.org/TR/css-values-5/#tree-counting)) are
evaluated against the container element.

 This is different from the handling of relative units
in [media
queries](https://www.w3.org/TR/mediaqueries-5/#media-query).

 If [custom
property](https://www.w3.org/TR/css-variables-1/#custom-property) substitution results in an invalid value for the [size
feature](#size-features), it is
handled the same as other invalid feature values, and the result of the
[size feature] is [unknown].

For example, [query
containers](#query-container) with different font-sizes will evaluate
[em](https://www.w3.org/TR/css-values-4/#em)-based queries relative to their own font sizes:

```
aside, main {
 container-type: inline-size;
}

aside { font-size: 16px; }
main { font-size: 24px; }

@container (width > 40em) {
 h2 { font-size: 1.5em; }
}
```

The [40em] value used in the query condition is relative to the
[computed
value](https://www.w3.org/TR/css-cascade-5/#computed-value) of
[font-size](https://www.w3.org/TR/css-fonts-4/#propdef-font-size) on the relevant [query
container](#query-container):

- For any [h2] inside [aside], the query condition will be
 true above [640px].

- For any [h2] inside [main], the query condition will be
 true above [960px].

Similarly, [query
containers](#query-container) will evaluate
[var()](https://www.w3.org/TR/css-variables-1/#funcdef-var)-based queries relative to their own [computed
value](https://www.w3.org/TR/css-cascade-5/#computed-value) of the [custom
property](https://www.w3.org/TR/css-variables-1/#custom-property):

```
aside, main {
 container-type: inline-size;
}

aside { --query: 300px; }
main { --query: 500px; }

@container (width > var(--query)) {
 h2 { font-size: 1.5em; }
}
```

The [var(\--query)] value used in the query condition is
substituted with the [computed
value](https://www.w3.org/TR/css-cascade-5/#computed-value) of the [\--query] [custom
property](https://www.w3.org/TR/css-variables-1/#custom-property) on the relevant [query
container](#query-container):

- For any [h2] inside [aside], the query condition will be
 true above [300px].

- For any [h2] inside [main], the query condition will be
 true above [500px].

#### 6.1.1. Width: the [width feature]
Name:

[width]

For:

[\@container](#at-ruledef-container)

Value:

[\<length\>](https://www.w3.org/TR/css-values-4/#length-value)

Type:

range

The [width](#descdef-container-width) [container
feature](#container-feature) queries the
[width](https://www.w3.org/TR/css-sizing-3/#width) of the [query
container](#query-container)'s [content
box](https://www.w3.org/TR/css-box-4/#content-box).

#### 6.1.2. Height: the [height feature]
Name:

[height]

For:

[\@container](#at-ruledef-container)

Value:

[\<length\>](https://www.w3.org/TR/css-values-4/#length-value)

Type:

range

The
[height](#descdef-container-height) [container
feature](#container-feature) queries the
[height](https://www.w3.org/TR/css-sizing-3/#height) of the [query
container](#query-container)'s [content
box](https://www.w3.org/TR/css-box-4/#content-box).

#### 6.1.3. Inline-size: the [inline-size feature]
Name:

[inline-size]

For:

[\@container](#at-ruledef-container)

Value:

[\<length\>](https://www.w3.org/TR/css-values-4/#length-value)

Type:

range

The
[inline-size](#descdef-container-inline-size) [container
feature](#container-feature) queries the
[size](https://www.w3.org/TR/css-sizing-3/#size) of the [query
container](#query-container)'s [content
box](https://www.w3.org/TR/css-box-4/#content-box) in the [query container]'s
[inline
axis](https://www.w3.org/TR/css-writing-modes-4/#inline-axis).

#### 6.1.4. Block-size: the [block-size feature]
Name:

[block-size]

For:

[\@container](#at-ruledef-container)

Value:

[\<length\>](https://www.w3.org/TR/css-values-4/#length-value)

Type:

range

The
[block-size](#descdef-container-block-size) [container
feature](#container-feature) queries the
[size](https://www.w3.org/TR/css-sizing-3/#size) of the [query
container](#query-container)'s [content
box](https://www.w3.org/TR/css-box-4/#content-box) in the [query container]'s
[block
axis](https://www.w3.org/TR/css-writing-modes-4/#block-axis).

#### 6.1.5. Aspect-ratio: the [aspect-ratio feature]
Name:

[aspect-ratio]

For:

[\@container](#at-ruledef-container)

Value:

[\<ratio\>](https://www.w3.org/TR/css-values-4/#ratio-value)

Type:

range

The
[aspect-ratio](#descdef-container-aspect-ratio) [container
feature](#container-feature) is defined as the ratio of the value of the
[width](#descdef-container-width) [container
feature] to the value of the
[height](#descdef-container-height) [container
feature].

#### 6.1.6. Orientation: the [orientation feature]
Name:

[orientation]

For:

[\@container](#at-ruledef-container)

Value:

portrait
[\|](https://www.w3.org/TR/css-values-4/#comb-one) landscape

Type:

discrete

[portrait]
: The
 [orientation](#descdef-container-orientation) [container
 feature](#container-feature) is
 [portrait](#valdef-container-orientation-portrait) when the value of the
 [height](#descdef-container-height) [container
 feature] is greater than or equal to
 the value of the
 [width](#descdef-container-width) [container
 feature].

[landscape]
: Otherwise
 [orientation](#descdef-container-orientation) is
 [landscape](#valdef-container-orientation-landscape).

### 6.2. Style Container Features

A [container style query] allows querying the [computed
values](https://www.w3.org/TR/css-cascade-5/#computed-value) of the [query
container](#query-container). It is a boolean combination of individual [style
features]
([\<style-feature\>](#typedef-style-feature)) that each query a single, specific
property of the [query container]. The
syntax of a [\<style-feature\>] is either the same as for a valid
[declaration](https://www.w3.org/TR/css-syntax-3/#declaration)[\[CSS-SYNTAX-3\]](#biblio-css-syntax-3 "CSS Syntax Module Level 3"),
a
[\<style-feature-name\>](#typedef-style-feature-name) or a valid [style range]
([\<style-range\>](#typedef-style-range)). The
[[\<style-feature-name\>](#typedef-style-feature-name)] can be either a [supported
CSS
property](https://www.w3.org/TR/cssom-1/#supported-css-property) or a valid
[\<custom-property-name\>](https://www.w3.org/TR/css-variables-1/#typedef-custom-property-name). The
[[\<style-feature-value\>](#typedef-style-feature-value)] production matches any
valid
[\<declaration-value\>](https://www.w3.org/TR/css-syntax-3/#typedef-declaration-value) as long as it doesn't contain
[\<mf-lt\>](https://www.w3.org/TR/mediaqueries-5/#typedef-mf-lt),
[\<mf-gt\>](https://www.w3.org/TR/mediaqueries-5/#typedef-mf-gt) and
[\<mf-eq\>](https://www.w3.org/TR/mediaqueries-5/#typedef-mf-eq) tokens.

A
[\<style-feature-plain\>](#typedef-style-feature-plain) evaluates to true if the [computed
value](https://www.w3.org/TR/css-cascade-5/#computed-value) of the given property on the [query
container](#query-container)
matches the given value (which is also
[computed] with respect to the [query
container]), and false otherwise.

A [style feature](#style-features) without a value
([\<style-feature-boolean\>](#typedef-style-feature-boolean)) evaluates to true if the [computed
value](https://www.w3.org/TR/css-cascade-5/#computed-value) is different from the [initial
value](https://www.w3.org/TR/css-cascade-5/#initial-value) for the given
[property](https://www.w3.org/TR/css-cascade-5/#css-property).

To [evaluate a
[\<style-range\>](#typedef-style-range)], the following steps needs to
be performed:

1. If
 [\<style-range-value\>](#typedef-style-range-value) is a
 [\<custom-property-name\>](https://www.w3.org/TR/css-variables-1/#typedef-custom-property-name), it needs to be substituted as if
 the
 [\<custom-property-name\>] was wrapped inside a
 [var()](https://www.w3.org/TR/css-variables-1/#funcdef-var).

2. Substitute [arbitrary substitution
 function](https://www.w3.org/TR/css-values-5/#arbitrary-substitution-function) within
 [\<style-range-value\>](#typedef-style-range-value).

3. Parse
 [\<style-range-value\>](#typedef-style-range-value) to
 [\<number\>](https://www.w3.org/TR/css-values-4/#number-value),
 [\<percentage\>](https://www.w3.org/TR/css-values-4/#percentage-value),
 [\<length\>](https://www.w3.org/TR/css-values-4/#length-value),
 [\<angle\>](https://www.w3.org/TR/css-values-4/#angle-value),
 [\<time\>](https://www.w3.org/TR/css-values-4/#time-value),
 [\<frequency\>](https://www.w3.org/TR/css-values-4/#frequency-value) or
 [\<resolution\>](https://www.w3.org/TR/css-values-4/#resolution-value). If this cannot be done, evaluate
 to false.

4. If each
 [\<style-range-value\>](#typedef-style-range-value) from the range have the same
 type, compute each and evaluate the comparison; a unitless zero must
 be treated as being a
 zero-[\<length\>](https://www.w3.org/TR/css-values-4/#length-value) when compared against a
 [\<length\>] .

5. Otherwise evaluate to false.

The boolean syntax and logic combining [style
features](#style-features)
into a [style
query](#container-style-query) is the same as for [CSS feature
queries](https://www.w3.org/TR/css-conditional-3/#css-feature-queries). (See
[\@supports](https://www.w3.org/TR/css-conditional-3/#at-ruledef-supports).
[\[css-conditional-3\]](#biblio-css-conditional-3 "CSS Conditional Rules Module Level 3"))

[Style features](#style-features) that query a [shorthand
property](https://www.w3.org/TR/css-cascade-5/#shorthand-property) are true if the [computed
values](https://www.w3.org/TR/css-cascade-5/#computed-value) match for each of its [longhand
properties](https://www.w3.org/TR/css-cascade-5/#longhand), and false otherwise.

[Cascade-dependent
keywords](https://drafts.csswg.org/css-cascade-5/#cascade-dependent-keyword), such as
[revert](https://www.w3.org/TR/css-cascade-5/#valdef-all-revert) and
[revert-layer](https://www.w3.org/TR/css-cascade-5/#valdef-all-revert-layer), are invalid as values in a [style
feature](#style-features), and
cause the [container style
query](#container-style-query) to be false.

 The remaining non-cascade-dependent [CSS-wide
keywords](https://www.w3.org/TR/css-values-4/#css-wide-keywords) are
[computed](https://www.w3.org/TR/css-cascade-5/#computed-value) with respect to the [query
container](#query-container), the same as other values.

### 6.3. Scroll State Container Features

A [container scroll-state query] allows querying a container for
state that depends on scroll position. It is a boolean combination of
individual [scroll-state features]
([\<scroll-state-feature\>](#typedef-scroll-state-feature)) that each query a single feature of
the [query container](#query-container). The syntax of a
[[\<scroll-state-feature\>](#typedef-scroll-state-feature)] is the same as for a [media
feature](https://www.w3.org/TR/mediaqueries-5/#media-feature): a feature name, a comparator, and a value.

[Scroll-state
features](#scroll-state-feature) can either match state of the scroller itself (such as
the [scrollable] feature), or an element that is affected by the
scroll position of an ancestor [scroll
container's](https://www.w3.org/TR/css-overflow-3/#scroll-container)
[scrollport](https://www.w3.org/TR/css-overflow-3/#scrollport) (such as the [snapped] feature).

#### 6.3.1. Updating Scroll State

Scroll state may cause layout cycles since queried scroll state may
cause style changes, which may lead to scroll state changes as a result
of layout.

To avoid such layout cycles,
[scroll-state](#valdef-container-type-scroll-state) [query
containers](#query-container) update their current state as part of [run snapshot
post-layout state
steps](https://www.w3.org/TR/cssom-view-1/#run-snapshot-post-layout-state-steps) which is only run at specific points in the [HTML event
loop processing
model](https://html.spec.whatwg.org/multipage/webappapis.html#event-loop-processing-model).

When asked to [run snapshot post-layout state
steps](https://www.w3.org/TR/cssom-view-1/#run-snapshot-post-layout-state-steps), update the current state of every
[scroll-state](#valdef-container-type-scroll-state) [query
container](#query-container). This snapshotted state will be used for any style and
layout updates until the next time these steps are run.

#### 6.3.2. Sticky positioning: the [stuck feature]
Name:

[stuck]

For:

[\@container](#at-ruledef-container)

Value:

none
[\|](https://www.w3.org/TR/css-values-4/#comb-one) top [\|] right
[\|] bottom [\|] left
[\|] block-start [\|]
inline-start [\|] block-end
[\|] inline-end

Type:

discrete

The [stuck](#descdef-container-stuck) [container
feature](#container-feature) queries whether a
[sticky](https://www.w3.org/TR/css-position-3/#valdef-position-sticky) positioned container is visually shifted to stay
inside the [sticky view
rectangle](https://www.w3.org/TR/css-position-3/#sticky-view-rectangle) for the given edge. The logical edges map to physical
based on the direction and writing-mode of the [query
container](#query-container). None of the values match if the [query
container] is not [sticky
positioned](https://www.w3.org/TR/css-position-3/#sticky-position).

It is possible for two values from opposite axes to match at the same
time, but not for opposite edges along the same axis.

May match:

```
@container scroll-state((stuck: top) and (stuck: left)) { ... }
```

Will never match:

```
@container scroll-state((stuck: left) and (stuck: right)) { ... }
```

[none]
: The
 [sticky](https://www.w3.org/TR/css-position-3/#valdef-position-sticky) container is not shifted in any direction.

[top]
: The
 [sticky](https://www.w3.org/TR/css-position-3/#valdef-position-sticky) container is shifted to stay inside the top
 edge.

[right]
: The
 [sticky](https://www.w3.org/TR/css-position-3/#valdef-position-sticky) container is shifted to stay inside the
 right edge.

[bottom]
: The
 [sticky](https://www.w3.org/TR/css-position-3/#valdef-position-sticky) container is shifted to stay inside the
 bottom edge.

[left]
: The
 [sticky](https://www.w3.org/TR/css-position-3/#valdef-position-sticky) container is shifted to stay inside the left
 edge.

[block-start]
: The
 [sticky](https://www.w3.org/TR/css-position-3/#valdef-position-sticky) container is shifted to stay inside the
 [block-start](https://www.w3.org/TR/css-writing-modes-4/#block-start) edge.

[inline-start]
: The
 [sticky](https://www.w3.org/TR/css-position-3/#valdef-position-sticky) container is shifted to stay inside the
 [inline-start](https://www.w3.org/TR/css-writing-modes-4/#inline-start) edge.

[block-end]
: The
 [sticky](https://www.w3.org/TR/css-position-3/#valdef-position-sticky) container is shifted to stay inside the
 [block-end](https://www.w3.org/TR/css-writing-modes-4/#block-end) edge.

[inline-end]
: The
 [sticky](https://www.w3.org/TR/css-position-3/#valdef-position-sticky) container is shifted to stay inside the
 [inline-end](https://www.w3.org/TR/css-writing-modes-4/#inline-end) edge.

#### 6.3.3. Scroll snapping: the [snapped feature]
Name:

[snapped]

For:

[\@container](#at-ruledef-container)

Value:

none
[\|](https://www.w3.org/TR/css-values-4/#comb-one) x [\|] y
[\|] block [\|] inline
[\|] both

Type:

discrete

The
[snapped](#descdef-container-snapped) [container
feature](#container-feature) queries whether a [snap
target](https://www.w3.org/TR/css-scroll-snap-2/#snap-target) is, or would be, snapped to its [scroll snap
container](https://www.w3.org/TR/css-scroll-snap-1/#scroll-snap-container) in the given axis. That is, it matches any [snap
target] that the
[`scrollsnapchanging`](https://www.w3.org/TR/css-scroll-snap-2/#eventdef-snapevent-scrollsnapchanging) event is fired for.

[none]
: The [query container](#query-container) is not a [snap
 target](https://www.w3.org/TR/css-scroll-snap-2/#snap-target).

[x]
: [snapped](#descdef-container-snapped) [container
 feature](#container-feature) matches
 [x](#valdef-container-snapped-x) if the [query
 container](#query-container) is a horizontal [snap
 target](https://www.w3.org/TR/css-scroll-snap-2/#snap-target) for its [scroll
 container](https://www.w3.org/TR/css-overflow-3/#scroll-container).

[y]
: [snapped](#descdef-container-snapped) [container
 feature](#container-feature) matches
 [y](#valdef-container-snapped-y) if the [query
 container](#query-container) is a vertical [snap
 target](https://www.w3.org/TR/css-scroll-snap-2/#snap-target) for its [scroll
 container](https://www.w3.org/TR/css-overflow-3/#scroll-container).

[block]
: [snapped](#descdef-container-snapped) [container
 feature](#container-feature) matches
 [block](#valdef-container-snapped-block) if the [query
 container](#query-container) is a [snap
 target](https://www.w3.org/TR/css-scroll-snap-2/#snap-target) for its [scroll
 container](https://www.w3.org/TR/css-overflow-3/#scroll-container). in the block direction of the [scroll snap
 container](https://www.w3.org/TR/css-scroll-snap-1/#scroll-snap-container).

[inline]
: [snapped](#descdef-container-snapped) [container
 feature](#container-feature) matches
 [inline](#valdef-container-snapped-inline) if the [query
 container](#query-container) is a [snap
 target](https://www.w3.org/TR/css-scroll-snap-2/#snap-target) for its [scroll
 container](https://www.w3.org/TR/css-overflow-3/#scroll-container) in the inline direction of the [scroll snap
 container](https://www.w3.org/TR/css-scroll-snap-1/#scroll-snap-container).

[both]
: [snapped](#descdef-container-snapped) [container
 feature](#container-feature) matches
 [both](#valdef-container-snapped-both) if the [query
 container](#query-container) is a [snap
 target](https://www.w3.org/TR/css-scroll-snap-2/#snap-target) for its [scroll
 container](https://www.w3.org/TR/css-overflow-3/#scroll-container) in both directions of the [scroll snap
 container](https://www.w3.org/TR/css-scroll-snap-1/#scroll-snap-container).

#### 6.3.4. Scrollable: the [scrollable feature]
Name:

[scrollable]

For:

[\@container](#at-ruledef-container)

Value:

none
[\|](https://www.w3.org/TR/css-values-4/#comb-one) top [\|] right
[\|] bottom [\|] left
[\|] block-start [\|]
inline-start [\|] block-end
[\|] inline-end [\|] x
[\|] y [\|] block
[\|] inline

Type:

discrete

The
[scrollable](#descdef-container-scrollable) [container
feature](#container-feature) queries whether a [scroll
container](https://www.w3.org/TR/css-overflow-3/#scroll-container) has clipped [scrollable overflow
rectangle](https://www.w3.org/TR/css-overflow-3/#scrollable-overflow-rectangle) content in the given direction which is reachable
through user initiated scrolling. That is,
[scrollable] does not
match for a
[hidden](https://www.w3.org/TR/css-overflow-3/#valdef-overflow-hidden) container, nor for a [unreachable scrollable
overflow
region](https://www.w3.org/TR/css-overflow-3/#unreachable-scrollable-overflow-region).

The logical values map to physical based on the direction and
writing-mode of the [query
container](#query-container). None of the values match if the container is not a
[scroll
container](https://www.w3.org/TR/css-overflow-3/#scroll-container).

[none]
: The [scroll
 container](https://www.w3.org/TR/css-overflow-3/#scroll-container) does not have [scrollable
 overflow](https://www.w3.org/TR/css-overflow-3/#scrollable-overflow) in any direction.

[top]
: The [scroll
 container](https://www.w3.org/TR/css-overflow-3/#scroll-container) has [scrollable
 overflow](https://www.w3.org/TR/css-overflow-3/#scrollable-overflow) past the top edge.

[right]
: The [scroll
 container](https://www.w3.org/TR/css-overflow-3/#scroll-container) has [scrollable
 overflow](https://www.w3.org/TR/css-overflow-3/#scrollable-overflow) past the right edge.

[bottom]
: The [scroll
 container](https://www.w3.org/TR/css-overflow-3/#scroll-container) has [scrollable
 overflow](https://www.w3.org/TR/css-overflow-3/#scrollable-overflow) past the bottom edge.

[left]
: The [scroll
 container](https://www.w3.org/TR/css-overflow-3/#scroll-container) has [scrollable
 overflow](https://www.w3.org/TR/css-overflow-3/#scrollable-overflow) past the left edge.

[block-start]
: The [scroll
 container](https://www.w3.org/TR/css-overflow-3/#scroll-container) has [scrollable
 overflow](https://www.w3.org/TR/css-overflow-3/#scrollable-overflow) past the
 [block-start](https://www.w3.org/TR/css-writing-modes-4/#block-start) edge.

[inline-start]
: The [scroll
 container](https://www.w3.org/TR/css-overflow-3/#scroll-container) has [scrollable
 overflow](https://www.w3.org/TR/css-overflow-3/#scrollable-overflow) past the
 [inline-start](https://www.w3.org/TR/css-writing-modes-4/#inline-start) edge.

[block-end]
: The [scroll
 container](https://www.w3.org/TR/css-overflow-3/#scroll-container) has [scrollable
 overflow](https://www.w3.org/TR/css-overflow-3/#scrollable-overflow) past the
 [block-end](https://www.w3.org/TR/css-writing-modes-4/#block-end) edge.

[inline-end]
: The [scroll
 container](https://www.w3.org/TR/css-overflow-3/#scroll-container) has [scrollable
 overflow](https://www.w3.org/TR/css-overflow-3/#scrollable-overflow) past the
 [inline-end](https://www.w3.org/TR/css-writing-modes-4/#inline-end) edge.

[x]
: The [scroll
 container](https://www.w3.org/TR/css-overflow-3/#scroll-container) has horizontally [scrollable
 overflow](https://www.w3.org/TR/css-overflow-3/#scrollable-overflow).

[y]
: The [scroll
 container](https://www.w3.org/TR/css-overflow-3/#scroll-container) has vertically [scrollable
 overflow](https://www.w3.org/TR/css-overflow-3/#scrollable-overflow).

[block]
: The [scroll
 container](https://www.w3.org/TR/css-overflow-3/#scroll-container) has [scrollable
 overflow](https://www.w3.org/TR/css-overflow-3/#scrollable-overflow) in its block direction.

[inline]
: The [scroll
 container](https://www.w3.org/TR/css-overflow-3/#scroll-container) has [scrollable
 overflow](https://www.w3.org/TR/css-overflow-3/#scrollable-overflow) in its inline direction.

#### 6.3.5. Scrolled: the [scrolled feature]
Name:

[scrolled]

For:

[\@container](#at-ruledef-container)

Value:

none
[\|](https://www.w3.org/TR/css-values-4/#comb-one) top [\|] right
[\|] bottom [\|] left
[\|] block-start [\|]
inline-start [\|] block-end
[\|] inline-end [\|] x
[\|] y [\|] block
[\|] inline

Type:

discrete

For a [query container](#query-container) that is a [scroll
container](https://www.w3.org/TR/css-overflow-3/#scroll-container), the
[scrolled](#descdef-container-scrolled) [container
feature](#container-feature) queries the direction of its most recent [relative
scroll](https://drafts.csswg.org/css-scroll-snap-1/#relative-scroll). The logical values map to physical based on the
direction and writing-mode of the [query
container]. None of the values match if the
container is not a [scroll container].

[none]
: The [query container](#query-container) has not had a [relative
 scroll](https://drafts.csswg.org/css-scroll-snap-1/#relative-scroll) yet.

[top]
: The most recent [relative
 scroll](https://drafts.csswg.org/css-scroll-snap-1/#relative-scroll) was upwards.

[right]
: The most recent [relative
 scroll](https://drafts.csswg.org/css-scroll-snap-1/#relative-scroll) was to the right.

[bottom]
: The most recent [relative
 scroll](https://drafts.csswg.org/css-scroll-snap-1/#relative-scroll) was downwards.

[left]
: The most recent [relative
 scroll](https://drafts.csswg.org/css-scroll-snap-1/#relative-scroll) was to the left.

[block-start]
: The most recent [relative
 scroll](https://drafts.csswg.org/css-scroll-snap-1/#relative-scroll) was towards the
 [block-start](https://www.w3.org/TR/css-writing-modes-4/#block-start) direction.

[inline-start]
: The most recent [relative
 scroll](https://drafts.csswg.org/css-scroll-snap-1/#relative-scroll) was towards the
 [inline-start](https://www.w3.org/TR/css-writing-modes-4/#inline-start) direction.

[block-end]
: The most recent [relative
 scroll](https://drafts.csswg.org/css-scroll-snap-1/#relative-scroll) was towards the
 [block-end](https://www.w3.org/TR/css-writing-modes-4/#block-end) direction.

[inline-end]
: The most recent [relative
 scroll](https://drafts.csswg.org/css-scroll-snap-1/#relative-scroll) was towards the
 [inline-end](https://www.w3.org/TR/css-writing-modes-4/#inline-end) direction.

[x]
: The most recent [relative
 scroll](https://drafts.csswg.org/css-scroll-snap-1/#relative-scroll) was in the horizontal direction.

[y]
: The most recent [relative
 scroll](https://drafts.csswg.org/css-scroll-snap-1/#relative-scroll) was in the vertical direction.

[block]
: The most recent [relative
 scroll](https://drafts.csswg.org/css-scroll-snap-1/#relative-scroll) was in the block direction.

[inline]
: The most recent [relative
 scroll](https://drafts.csswg.org/css-scroll-snap-1/#relative-scroll) was in the inline direction.

## [7. ][ Container Relative Lengths: the [cqw], [cqh], [cqi], [cqb], [cqmin], [cqmax] units]
[Container query length units] specify a
length relative to the dimensions of a [query
container](#query-container). Style sheets that use [container query
length](#container-query-length) units can more easily move components from one [query
container] to another.

The [container query
length](#container-query-length) units are:

Informative Summary of Container Units

unit

relative to

[cqw]

1% of a [query container](#query-container)'s
[width](https://www.w3.org/TR/css-sizing-3/#width)

[cqh]

1% of a [query container](#query-container)'s
[height](https://www.w3.org/TR/css-sizing-3/#height)

[cqi]

1% of a [query container](#query-container)'s [inline
size](https://www.w3.org/TR/css-sizing-3/#inline-size)

[cqb]

1% of a [query container](#query-container)'s [block
size](https://www.w3.org/TR/css-sizing-3/#block-size)

[cqmin]

The smaller value of [cqi] or [cqb]

[cqmax]

The larger value of [cqi] or [cqb]

For each element, [container query
length](#container-query-length) units are evaluated using the same rules as [container
size queries](#container-size-query) on the relevant axis (or axes) described by the unit.
The [query container](#query-container) for each axis is the nearest ancestor container that
accepts [container size queries] on
that axis. If no eligible [query container]
is available, then use the [small viewport
size](https://www.w3.org/TR/css-values-4/#small-viewport-size) for that axis.

 In some cases [cqi] and [cqb] units on the
same element will evaluate in relation to different [query
containers](#query-container). Similarly, [cqmin] and [cqmax] units
represent the larger or smaller of the [cqi] and [cqb]
units, even when those dimensions come from different [query
containers].

Child elements do not inherit the relative values as specified for their
parent; they inherit the [computed
values](https://www.w3.org/TR/css-cascade-5/#computed-value).

Authors can ensure that [container
query length](#container-query-length) units have an appropriate [query
container](#query-container)
by applying them inside a [container
query](#container-query)
that relies on the same [container-type]. Custom fallback values
can be defined outside the [container
query]:

```
/* The fallback value does not rely on containment */
h2 { font-size: 1.2em; }

@container (inline-size >= 0px) {
 /* only applies when an inline-size container is available */
 h2 { font-size: calc(1.2em + 1cqi); }
}
```

## 8. Defining Custom Support Queries: the [\@supports-condition rule]
The [\@supports-condition]
[at-rule](https://www.w3.org/TR/css-syntax-3/#at-rule) is a [conditional group
rule](https://www.w3.org/TR/css-conditional-3/#conditional-group-rule) that allows authors to define and name a [supports
query](https://www.w3.org/TR/css-conditional-3/#supports-queries) for later reuse, creating a [named supports
condition]. This enables complex or frequently-used feature queries to
be referenced by name, improving maintainability and readability.

```
@supports-condition <supports-condition-name> {
 <block-contents>
}
```

Where
[[\<supports-condition-name\>](#typedef-supports-condition-name)] is an
[\<extension-name\>](https://drafts.csswg.org/css-extensions-1/#typedef-extension-name) that defines the name of the supports
query.

Anything inside the block is evaluated to test whether the user agent
supports the features used. The contents do not have any effect on the
document's rendering.

Once defined, the named supports condition can be used in subsequent
[\@supports](https://www.w3.org/TR/css-conditional-3/#at-ruledef-supports) or
[\@when](#at-ruledef-when) conditions.

If multiple
[\@supports-condition](#at-ruledef-supports-condition) rules are defined with the same name, the last
one in document order wins, and all preceding ones are ignored.

For example, we can define a supports
query checking multiple properties at once:

```
@supports-condition --thicker-underlines {
 text-decoration-thickness: 0.2em;
 text-underline-offset: 0.3em;
}

/* Equivalent to (text-decoration-thickness: 0.2em) and (text-underline-offset: 0.3em) */
@supports (--thicker-underlines) {
 a {
 text-decoration: underline;
 text-decoration-thickness: 0.2em;
 text-underline-offset: 0.3em;
 }
}
```

[\@supports-condition](#at-ruledef-supports-condition) rules are allowed before
[\@import](https://www.w3.org/TR/css-cascade-5/#at-ruledef-import) and
[\@namespace](https://drafts.csswg.org/css-namespaces-3/#at-ruledef-namespace) rules (after the
[\@charset](https://www.w3.org/TR/css-syntax-3/#at-ruledef-charset) rule, if any).

As support queries can contain
arbitrary declarations, they can be used to detect support for complex
features such as nesting:

```
@supports-condition --nesting {
 &
}

@import url("nested-styles.css") supports(--nesting);
```

Support queries can also be used to
detect support for at-rules:

```
@supports-condition --stuck-container-feature {
 @container scroll-state(stuck: top)
}

@supports (--stuck-container-feature) {
 div { border-color: navy; }
}
```

The name of the at-rule is under
discussion. Alternatives include [\@supports-query],
[\@supports-test], and [\@custom-supports]. The name should
be consistent with the one chosen for custom media queries.

## 9. APIs

### 9.1. The `CSSContainerRule` interface

The
[`CSSContainerRule`](#csscontainerrule) interface represents an
[\@container](#at-ruledef-container) rule.

```
dictionary CSSContainerCondition {
 required CSSOMString name;
 required CSSOMString query;
};

[Exposed=Window]
interface CSSContainerRule : CSSConditionRule {
 readonly attribute CSSOMString containerName;
 readonly attribute CSSOMString containerQuery;
 readonly attribute FrozenArray<CSSContainerCondition> conditions;
};
```

We should try to remove
[`containerName`](#dom-csscontainerrule-containername) and
[`containerQuery`](#dom-csscontainerrule-containerquery), since they don't deal with multiple conditions
correctly.

`conditionText` of type `CSSOMString` (CSSContainerRule-specific definition for attribute on CSSConditionRule)
: The `conditionText` attribute (defined on the
 `CSSConditionRule` parent rule), on getting, must return
 a value as follows:
 :::
 1. Let `conditions` be the result of getting the
 [`conditions`](#dom-csscontainerrule-conditions) attribute.

 2. Let `first` be `true`.

 3. Let `result` be the empty string.

 4. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `condition` in
 `conditions`:

 1. If `first` is `false`, append
 `", "` to `result`.

 2. Set `first` to `false`.

 3. If `condition`'s
 [`name`](#dom-csscontainercondition-name) is not empty:

 1. Append `condition`'s
 [`name`](#dom-csscontainercondition-name) to `result`.

 2. If `condition`'s
 [`query`](#dom-csscontainercondition-query) is not empty, append a single space to
 `result`.

 4. Append `condition`'s
 [`query`](#dom-csscontainercondition-query) to `result`.

 5. Return `result`
 :::

`containerName` of type `CSSOMString`
: The `containerName` attribute, on getting, must return a
 value as follows:
 :::
 1. Let `conditions` be the result of getting the
 [`conditions`](#dom-csscontainerrule-conditions) attribute.

 2. If the length of `conditions` is 1:

 1. Return the only `conditions` item's
 [`name`](#dom-csscontainercondition-name).

 3. return `""`.
 :::

`containerQuery` of type `CSSOMString`
: The `containerQuery` attribute, on getting, must return
 a value as follows:
 :::
 1. Let `conditions` be the result of getting the
 [`conditions`](#dom-csscontainerrule-conditions) attribute.

 2. If the length of `conditions` is 1:

 1. Return the only `conditions` item's
 [`query`](#dom-csscontainercondition-query).

 3. Return `""`.
 :::

`conditions` of type `FrozenArray<CSSContainerCondition?>`
: The `conditions` attribute, on getting, must return a
 value as follows:
 :::
 1. Let `result` be an empty
 [list](https://infra.spec.whatwg.org/#list).

 2. [For
 each](https://infra.spec.whatwg.org/#list-iterate)
 [\<container-condition\>](#typedef-container-condition) `condition`
 specified in the rule:

 1. Let `dict` be a new
 [`CSSContainerCondition`](#dictdef-csscontainercondition) with
 [`name`](#dom-csscontainercondition-name) set to the
 [serialized](https://www.w3.org/TR/cssom-1/#serialize-an-identifier)
 [\<container-name\>](#typedef-container-name) of `condition`
 if specified, or `""` otherwise, and
 [`query`](#dom-csscontainercondition-query) set to the
 [\<container-query\>](#typedef-container-query) specified in
 `condition` without any logical simplifications,
 so that the returned query will evaluate to the same result
 as the specified query in any conformant implementation of
 this specification (including implementations that implement
 future extensions allowed by the
 [\<general-enclosed\>](https://www.w3.org/TR/mediaqueries-5/#typedef-general-enclosed) extensibility mechanism
 in this specification). In other words, token stream
 simplifications are allowed (such as reducing whitespace to
 a single space or omitting it in cases where it is known to
 be optional), but logical simplifications (such as removal
 of unneeded parentheses, or simplification based on
 evaluating results) are not allowed.

 2. [Append](https://infra.spec.whatwg.org/#list-append) `dict` to `result`.

 3. Return `result`.
 :::

Container Queries should have a
`matchContainer` method. This will be modeled on
[`matchMedia()`](https://www.w3.org/TR/cssom-view-1/#dom-window-matchmedia) and the
[`MediaQueryList`](https://www.w3.org/TR/cssom-view-1/#mediaquerylist) interface, but applied to Elements rather than the
Window. When measuring layout sizes, it behaves Similar to
`resizeObserver`, but it provides the additional Container
Query syntax and features. [\[Issue
#6205\]](https://github.com/w3c/csswg-drafts/issues/6205)

### 9.2. The `CSSSupportsConditionRule` interface

The
[`CSSSupportsConditionRule`](#csssupportsconditionrule) interface represents an
[\@supports-condition](#at-ruledef-supports-condition) rule.

```
[Exposed=Window]
interface CSSSupportsConditionRule : CSSGroupingRule {
 readonly attribute CSSOMString name;
};
```

`name` of type `CSSOMString`
: This attribute is the name of the [named supports
 condition](#named-supports-condition).

## [Security Considerations]
No security issues have been raised against this document

## [Privacy Considerations]
The
[font-tech()](#funcdef-supports-font-tech) and
[font-format()](#funcdef-supports-font-format) functions may provide information about the
user's software such as its version and whether it is running with
non-default settings that enable or disable certain features.

This information can also be determined through other APIs. However, the
features in this specification are one of the ways this information is
exposed on the Web.

This information can also, in aggregate, be used to improve the accuracy
of
[fingerprinting](https://www.w3.org/2001/tag/doc/unsanctioned-tracking/)
of the user.

## [ Changes]
### [ Changes since the [Working Draft of 5 November 2024](https://www.w3.org/TR/2024/WD-css-conditional-5-20241105/) ]
- Extended [supports
 queries](https://www.w3.org/TR/css-conditional-3/#supports-queries) to express [environment
 variable](https://www.w3.org/TR/css-env-1/#css-environment-variable) capabilities via
 [env()](#funcdef-supports-env).
 ([#3576](https://github.com/w3c/csswg-drafts/issues/3576))
- Clarified that the last \@supports-condition in document order wins
 ([#12973](https://github.com/w3c/csswg-drafts/issues/12973))
- Extended [supports
 queries](https://www.w3.org/TR/css-conditional-3/#supports-queries) to express
 [at-rule](https://www.w3.org/TR/css-syntax-3/#at-rule) capabilities via
 [at-rule()](#funcdef-supports-at-rule).
 ([#2463](https://github.com/w3c/csswg-drafts/issues/2463),
 [#6966](https://github.com/w3c/csswg-drafts/issues/6966),
 [#11116](https://github.com/w3c/csswg-drafts/issues/11116),
 [#11117](https://github.com/w3c/csswg-drafts/issues/11117))
- Added
 [\@supports-condition](#at-ruledef-supports-condition) at-rule and related
 [`CSSSupportsConditionRule`](#csssupportsconditionrule) interface.
 ([#12622](https://github.com/w3c/csswg-drafts/issues/12622))
- Clarified that container-names are not tree-scoped
 ([#12090](https://github.com/w3c/csswg-drafts/issues/12090))
- Defined direction feature for scroll-state() queries
 ([#6400](https://github.com/w3c/csswg-drafts/issues/6400#issuecomment-3200664309))
- Clarified that 0 and 0px are equivalent in conditions
 ([#12236](https://github.com/w3c/csswg-drafts/issues/12236#issuecomment-3204826253))
- Defined a range syntax for style container queries
 ([#8376](https://github.com/w3c/csswg-drafts/issues/8376#issuecomment-2773374483))
- Explicitly allow tree-counting functions
 ([#10982](https://github.com/w3c/csswg-drafts/issues/10982))
- Dimensional query containers no longer apply layout containment
 ([#10544](https://github.com/w3c/csswg-drafts/pull/10544))
- Added \"both\" value for snapped query
 ([#11181](https://github.com/w3c/csswg-drafts/issues/11181))
- Added axis keywords for overflowing
 ([#11183](https://github.com/w3c/csswg-drafts/issues/11183))
- Renamed overflowing to scrollable
 ([#11182](https://github.com/w3c/csswg-drafts/issues/11182))
- Made
 [\<container-query\>](#typedef-container-query) optional
 ([#9192](https://github.com/w3c/csswg-drafts/issues/9192#issuecomment-1789850349))
- Extended [supports
 queries](https://www.w3.org/TR/css-conditional-3/#supports-queries) to express named features via
 [named-feature()](#funcdef-supports-named-feature).
 ([#9875](https://github.com/w3c/csswg-drafts/issues/9875))

### [ Changes since the [Working Draft of 23 July 2024](https://www.w3.org/TR/2024/WD-css-conditional-5-20240723/) ]
- Added
 [none](#valdef-container-stuck-none)-keywords to scroll-state() features
 ([#10874](https://github.com/w3c/csswg-drafts/pull/10874))
- Added container-type:scroll-state, and scroll-state() queries for
 stuck, snapped, and scrollable features
 ([#6402](https://github.com/w3c/csswg-drafts/issues/6402#issuecomment-1812973013),
 [#10784](https://github.com/w3c/csswg-drafts/issues/10784#issuecomment-2379901508),
 [#10796](https://github.com/w3c/csswg-drafts/issues/10796#issuecomment-2379885032))
- Corrected example (there is no container-type:style)
- Specified that container queries use the flat tree
 ([#5984](https://github.com/w3c/csswg-drafts/issues/5984#issuecomment-2112977366))

### [ Changes since the [First Public Working Draft of 21 December 2021](https://www.w3.org/TR/2021/WD-css-conditional-5-20211221/) ]
- Moved container queries to this specification, from CSS Contain 3
 ([#10433](https://github.com/w3c/csswg-drafts/issues/10433))
- Imported the definitions of \<font-format\> and \<font-tech\> from CSS
 Fonts 4, rather than duplicating them in this specification
 ([#8110](https://github.com/w3c/csswg-drafts/issues/8110))
- Updated to use the new parsing algorithm names and block production
 names
- Corrected a typo in the grammar of \<font-format\>
- Corrected extra spaces in the font-tech and font-format productions
 ([#7369](https://github.com/w3c/csswg-drafts/issues/7369))

### [ Additions since Level 4]
- Added [\@when](#at-ruledef-when) and
 [\@else](#at-ruledef-else).
- Extended [supports
 queries](https://www.w3.org/TR/css-conditional-3/#supports-queries) to express font capabilities via
 [font-tech()](#funcdef-supports-font-tech) and
 [font-format()](#funcdef-supports-font-format).
- Extended [supports
 queries](https://www.w3.org/TR/css-conditional-3/#supports-queries) to express at-rule capabilities via
 [at-rule()](#funcdef-supports-at-rule).
- Extended [supports
 queries](https://www.w3.org/TR/css-conditional-3/#supports-queries) to express named features via
 [named-feature()](#funcdef-supports-named-feature).
- Moved Container Queries from
 [\[CSS-CONTAIN-3\]](#biblio-css-contain-3 "CSS Containment Module Level 3")
 to this specification. (See also the [CSS Containment 3 § A
 Changes](https://www.w3.org/TR/css-contain-3/#changes) for more
 information on the evolution of this feature.)
- Added
 [\@supports-condition](#at-ruledef-supports-condition) at-rule and related
 [`CSSSupportsConditionRule`](#csssupportsconditionrule) interface.

## [Acknowledgments]
The [\@when](#at-ruledef-when) and
[\@else](#at-ruledef-else) rules are based on a proposal by Tab Atkins.

Comments and previous work from Adam Argyle, Amelia Bellamy-Royds,
Anders Hartvoll Ruud, Brian Kardell, Chris Coyier, Christopher
Kirk-Nielsen, David Herron, Eric Portis, Ethan Marcotte, Florian Rivoal,
Geoff Graham, Gregory Wild-Smith, Ian Kilpatrick, Jen Simmons, Kenneth
Rohde Christiansen, Lea Verou, Martin Auswöger, Martine Dowden, Mike
Riethmuller, Morten Stenshorne, Nicole Sullivan, Rune Lillesveen, Scott
Jehl Scott Kellum, Stacy Kvernmo, Theresa O'Connor, Una Kravets, and
many others have contributed to this specification.
