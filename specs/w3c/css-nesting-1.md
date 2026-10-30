## 1. Introduction

*This section is not normative.*

This module describes support for nesting a style rule within another
style rule, allowing the inner rule's selector to reference the elements
matched by the outer rule. This feature allows related styles to be
aggregated into a single structure within the CSS document, improving
readability and maintainability.

Tests

General tests for nesting

- [block-skipping.html](https://wpt.fyi/results/css/css-nesting/block-skipping.html "css/css-nesting/block-skipping.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/block-skipping.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/block-skipping.html)
- [delete-other-rule-crash.html](https://wpt.fyi/results/css/css-nesting/delete-other-rule-crash.html "css/css-nesting/delete-other-rule-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/delete-other-rule-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/delete-other-rule-crash.html)
- [double-parent-pseudo-in-placeholder-crash.html](https://wpt.fyi/results/css/css-nesting/double-parent-pseudo-in-placeholder-crash.html "css/css-nesting/double-parent-pseudo-in-placeholder-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/double-parent-pseudo-in-placeholder-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/double-parent-pseudo-in-placeholder-crash.html)
- [has-nesting.html](https://wpt.fyi/results/css/css-nesting/has-nesting.html "css/css-nesting/has-nesting.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/has-nesting.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/has-nesting.html)
- [invalidation-001.html](https://wpt.fyi/results/css/css-nesting/invalidation-001.html "css/css-nesting/invalidation-001.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/invalidation-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/invalidation-001.html)
- [invalidation-002.html](https://wpt.fyi/results/css/css-nesting/invalidation-002.html "css/css-nesting/invalidation-002.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/invalidation-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/invalidation-002.html)
- [invalidation-003.html](https://wpt.fyi/results/css/css-nesting/invalidation-003.html "css/css-nesting/invalidation-003.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/invalidation-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/invalidation-003.html)
- [invalidation-004.html](https://wpt.fyi/results/css/css-nesting/invalidation-004.html "css/css-nesting/invalidation-004.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/invalidation-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/invalidation-004.html)
- [nested-error-recovery.html](https://wpt.fyi/results/css/css-nesting/nested-error-recovery.html "css/css-nesting/nested-error-recovery.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/nested-error-recovery.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/nested-error-recovery.html)
- [nesting-basic.html](https://wpt.fyi/results/css/css-nesting/nesting-basic.html "css/css-nesting/nesting-basic.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/nesting-basic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/nesting-basic.html)
- [parent-pseudo-in-placeholder-crash.html](https://wpt.fyi/results/css/css-nesting/parent-pseudo-in-placeholder-crash.html "css/css-nesting/parent-pseudo-in-placeholder-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/parent-pseudo-in-placeholder-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/parent-pseudo-in-placeholder-crash.html)
- [pseudo-part-crash.html](https://wpt.fyi/results/css/css-nesting/pseudo-part-crash.html "css/css-nesting/pseudo-part-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/pseudo-part-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/pseudo-part-crash.html)
- [pseudo-where-crash.html](https://wpt.fyi/results/css/css-nesting/pseudo-where-crash.html "css/css-nesting/pseudo-where-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/pseudo-where-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/pseudo-where-crash.html)
- [supports-is-consistent.html](https://wpt.fyi/results/css/css-nesting/supports-is-consistent.html "css/css-nesting/supports-is-consistent.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/supports-is-consistent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/supports-is-consistent.html)

------------------------------------------------------------------------

### 1.1. Module Interactions

This module introduces new parser rules that extend the
[\[CSS21\]](#biblio-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
parser model. It introduces selectors that extend the
[\[SELECTORS-4\]](#biblio-selectors-4 "Selectors Level 4")
module. It extends and modifies some IDL and algorithms defined in the
[\[CSSOM-1\]](#biblio-cssom-1 "CSS Object Model (CSSOM)")
module.

### 1.2. Values

This specification does not define any new properties or values.

## 2. Explainer

*This section is non-normative.*

Imagine you have some CSS that you'd like to write in a more compact
way.

``` highlight
.foo {
 color: green;
}
.foo .bar {
 font-size: 1.4rem;
}
```

With Nesting, you can write such code as:

``` highlight
.foo {
 color: green;
 .bar {
 font-size: 1.4rem;
 }
}
```

If you've been nesting styles in Sass or other CSS preprocessors, you
will find this very familiar.

You can nest any rules inside of a parent style rule:

``` highlight
main {
 div { ... }
 .bar { ... }
 #baz { ...}
 :has(p) { ... }
 ::backdrop { ... }
 [lang|="zh"] { ... }
 * { ... }
}
```

By default, the child rule's selector is assumed to connect to the
parent rule by a [descendant
combinator](https://drafts.csswg.org/selectors-4/#descendant-combinator), but you can start the nested selector with any
combinator to change that:

``` highlight
main {
 + article { ... }
 > p { ... }
 ~ main { ... }
}
```

The new [&](#selectordef-)
selector lets you refer to the elements matched by the parent selector
explictly, so the previous examples could have been written as:

``` highlight
main {
 & + article { ... }
 & > p { ... }
 & ~ main { ... }
}
```

But you can place the [&](#selectordef-) in other locations within the nested selector, to
indicate other types of relationships between the parent and child rule.
For example, this CSS:

``` highlight
ul {
 padding-left: 1em;
}
.component ul {
 padding-left: 0;
}
```

Can be rewritten using Nesting as:

``` highlight
ul {
 padding-left: 1em;
 .component & {
 padding-left: 0;
 }
}
```

Again, the [&](#selectordef-) gives you a way to say "this is where I want the
nested selector to go".

It's also handy when you don't want a space between your selectors. For
example:

``` highlight
a {
 color: blue;
 &:hover {
 color: lightblue;
 }
}
```

Such code yields the same result as `a:hover {`. Without the
[&](#selectordef-), you'd
get `a :hover {`---​notice the space between `a`
and `:hover`---​which would fail to style your hover link.

You can nest more than one layer deep---​nesting CSS inside
already-nested CSS---​in as many levels as you desire. You can mix
Nesting with Container Queries, Supports Queries, Media Queries, and/or
Cascade Layers however you want. (Nearly) anything can go inside of
anything.

## 3. Nesting Style Rules

Style rules can be nested inside of other styles rules. These [nested
style rules] act exactly like
ordinary style rules---​associating properties with elements via
selectors---​but they \"inherit\" their parent rule's selector context,
allowing them to further build on the parent's selector without having
to repeat it, possibly multiple times.

A [nested style rule](#nested-style-rule) is exactly like a normal style rule, except that it can
use [relative
selectors](https://drafts.csswg.org/selectors-4/#relative-selector), which are implicitly relative to the elements matched
by the parent rule.

Tests

- [implicit-nesting.html](https://wpt.fyi/results/css/css-nesting/implicit-nesting.html "css/css-nesting/implicit-nesting.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/implicit-nesting.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/implicit-nesting.html)
- [implicit-nesting-ident.html](https://wpt.fyi/results/css/css-nesting/implicit-nesting-ident.html "css/css-nesting/implicit-nesting-ident.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/implicit-nesting-ident.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/implicit-nesting-ident.html)
- [implicit-nesting-ident-recovery.html](https://wpt.fyi/results/css/css-nesting/implicit-nesting-ident-recovery.html "css/css-nesting/implicit-nesting-ident-recovery.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/implicit-nesting-ident-recovery.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/implicit-nesting-ident-recovery.html)
- [implicit-parent-insertion-crash.html](https://wpt.fyi/results/css/css-nesting/implicit-parent-insertion-crash.html "css/css-nesting/implicit-parent-insertion-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/implicit-parent-insertion-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/implicit-parent-insertion-crash.html)

That is, a nested style rule like:

```
.foo {
 color: red;

 a {
 color: blue;
 }
}
```

is valid, and equivalent to:

```
.foo {
 color: red;
}
.foo a {
 color: blue;
}
```

The nested rule can also use the [nesting
selector](#nesting-selector)
to directly refer to the parent rule's matched elements, or use
[relative
selector](https://drafts.csswg.org/selectors-4/#relative-selector) syntax to specify relationships other than
\"descendant\".

```
.foo {
 color: red;

 &:hover {
 color: blue;
 }
}

/* equivalent to: */

.foo { color: red; }
.foo:hover { color: blue; }
```

```
.foo {
 color: red;

 + .bar {
 color: blue;
 }
}

/* equivalent to: */

.foo { color: red; }
.foo + .bar { color: blue; }
```

- [nested-rule-cssom-invalidation.html](https://wpt.fyi/results/css/css-nesting/nested-rule-cssom-invalidation.html "css/css-nesting/nested-rule-cssom-invalidation.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/nested-rule-cssom-invalidation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/nested-rule-cssom-invalidation.html)

### 3.1. Syntax

The contents of [style
rules](https://drafts.csswg.org/css-syntax-3/#style-rule) now accepts [nested style
rules](#nested-style-rule)
and
[at-rules](https://drafts.csswg.org/css-syntax-3/#at-rule), in addition to the existing
[declarations](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-declarations).

[Nested style rules](#nested-style-rule) differ from non-nested rules in the following ways:

- A [nested style rule](#nested-style-rule) accepts a
 [\<relative-selector-list\>](https://drafts.csswg.org/selectors-4/#typedef-relative-selector-list) as its prelude (rather than just a
 [\<selector-list\>](https://drafts.csswg.org/selectors-4/#typedef-selector-list)). Any [relative
 selectors](https://drafts.csswg.org/selectors-4/#relative-selector) are relative to the elements represented by the
 [nesting selector](#nesting-selector).

- If a selector in the
 [\<relative-selector-list\>](https://drafts.csswg.org/selectors-4/#typedef-relative-selector-list) does not start with a
 [combinator](https://drafts.csswg.org/selectors-4/#selector-combinator) but does [contain the nesting
 selector](#contain-the-nesting-selector), it is interpreted as a non-[relative
 selector](https://drafts.csswg.org/selectors-4/#relative-selector).

The precise details of how nested style rules are parsed are defined in
[\[CSS-SYNTAX-3\]](#biblio-css-syntax-3 "CSS Syntax Module Level 3").

An invalid [nested style
rule](#nested-style-rule)
is ignored, along with its contents, but does not invalidate its parent
rule.

Nested rules with [relative
selectors](https://drafts.csswg.org/selectors-4/#relative-selector) include the specificity of their implied [nesting
selector](#nesting-selector). For example, [.foo { \> .bar {\...}}] and [.foo
{ & \> .bar {\...}}] have the same specificity for their inner
rule.

Some CSS-generating tools that preprocess nesting will concatenate
selectors as strings, allowing authors to build up a *single* [simple
selector](https://drafts.csswg.org/selectors-4/#simple) across nesting levels. This is sometimes used with
hierarchical name patterns like [BEM](https://getbem.com/introduction/)
to reduce repetition across a file, when the selectors themselves have
significant repetition internally.

For example, if one component uses the class [.foo], and a nested
component uses [.fooBar], you could write this in
[Sass](https://sass-lang.com/) as:

```
.foo {
 color: blue;
 &Bar { color: red; }
}
/* In Sass, this is equivalent to
 .foo { color: blue; }
 .fooBar { color: red; }
*/
```

This is not allowed in CSS, as nesting is not a syntax transformation,
but rather matches on the actual elements the parent selector matches.

It is also true that the selector [&Bar] is invalid in CSS in the
first place, as the
[Bar](https://drafts.csswg.org/css-ui-4/#valdef-caret-shape-bar) part is a type selector, which must come first
in the compound selector. (That is, it must be written as [Bar&].)
So, luckily, there is no overlap between CSS Nesting and the
preprocessor syntax.

A selector is said to [contain the nesting
selector] if, when it was
[parsed](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) as any type of selector, a
[\<delim-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-delim-token) with the value \"&\" (U+0026
AMPERSAND) was encountered.

 This is phrased in this explicit manner so as to catch
cases like [:is(:unknown(&), .bar)], where an unknown selector
(which, being unknown, we have no way of knowing whether the argument is
*meant* to be parsed as a selector or not) is the only part of the
selector that contains an [&](#selectordef-). As that *might* be a perfectly valid selector that's
only supported by newer browsers, and we don't want parsing to be
dependent on unrelated versioning issues, we treat it as still
[containing the nesting
selector](#contain-the-nesting-selector).

If a
[\<forgiving-selector-list\>](https://drafts.csswg.org/selectors-4/#typedef-forgiving-selector-list) has an item that [contains the
nesting
selector](#contain-the-nesting-selector) but is invalid, that item is preserved exactly as-is
rather than being discarded. (This does not change the matching behavior
of the selector---​an invalid selector still fails to match
anything---​just the serialization of the selector.)

Tests

- [nest-containing-forgiving.html](https://wpt.fyi/results/css/css-nesting/nest-containing-forgiving.html "css/css-nesting/nest-containing-forgiving.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/nest-containing-forgiving.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/nest-containing-forgiving.html)
- [parsing.html](https://wpt.fyi/results/css/css-nesting/parsing.html "css/css-nesting/parsing.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/parsing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/parsing.html)

The preceding paragraph needs to move to
Selectors when we move [&](#selectordef-) itself to Selectors; I'm monkey-patching for
convenience here.

### 3.2. Examples

```
/* & can be used on its own */
.foo {
 color: blue;
 & > .bar { color: red; }
 > .baz { color: green; }
}
/* equivalent to
 .foo { color: blue; }
 .foo > .bar { color: red; }
 .foo > .baz { color: green; }
*/

/* or in a compound selector,
 refining the parent's selector */
.foo {
 color: blue;
 &.bar { color: red; }
}
/* equivalent to
 .foo { color: blue; }
 .foo.bar { color: red; }
*/

/* multiple selectors in the list are all
 relative to the parent */
.foo, .bar {
 color: blue;
 + .baz, &.qux { color: red; }
}
/* equivalent to
 .foo, .bar { color: blue; }
 :is(.foo, .bar) + .baz,
 :is(.foo, .bar).qux { color: red; }
*/

/* & can be used multiple times in a single selector */
.foo {
 color: blue;
 & .bar & .baz & .qux { color: red; }
}
/* equivalent to
 .foo { color: blue; }
 .foo .bar .foo .baz .foo .qux { color: red; }
*/

/* & doesn't have to be at the beginning of the selector */

.foo {
 color: red;
 .parent & {
 color: blue;
 }
}
/* equivalent to
 .foo { color: red; }
 .parent .foo { color: blue; }
*/

.foo {
 color: red;
 :not(&) {
 color: blue;
 }
}
/* equivalent to
 .foo { color: red; }
 :not(.foo) { color: blue; }
*/

/* But if you use a relative selector,
 an initial & is implied automatically */

.foo {
 color: red;
 + .bar + & { color: blue; }
}

/* equivalent to
 .foo { color: red; }
 .foo + .bar + .foo { color: blue; }
*/

/* Somewhat silly, but & can be used all on its own, as well. */
.foo {
 color: blue;
 & { padding: 2ch; }
}
/* equivalent to
 .foo { color: blue; }
 .foo { padding: 2ch; }

 // or

 .foo {
 color: blue;
 padding: 2ch;
 }
*/

/* Again, silly, but can even be doubled up. */
.foo {
 color: blue;
 && { padding: 2ch; }
}
/* equivalent to
 .foo { color: blue; }
 .foo.foo { padding: 2ch; }
*/

/* The parent selector can be arbitrarily complicated */
.error, #404 {
 &:hover > .baz { color: red; }
}
/* equivalent to
 :is(.error, #404):hover > .baz { color: red; }
*/

.ancestor .el {
 .other-ancestor & { color: red; }
}
/* equivalent to
 .other-ancestor :is(.ancestor .el) { color: red; }

/* As can the nested selector */
.foo {
 & :is(.bar, &.baz) { color: red; }
}
/* equivalent to
 .foo :is(.bar, .foo.baz) { color: red; }
*/

/* Multiple levels of nesting "stack up" the selectors */
figure {
 margin: 0;

 > figcaption {
 background: hsl(0 0% 0% / 50%);

 > p {
 font-size: .9rem;
 }
 }
}
/* equivalent to
 figure { margin: 0; }
 figure > figcaption { background: hsl(0 0% 0% / 50%); }
 figure > figcaption > p { font-size: .9rem; }
*/

/* Example usage with Cascade Layers */
@layer base {
 html {
 block-size: 100%;

 body {
 min-block-size: 100%;
 }
 }
}
/* equivalent to
 @layer base {
 html { block-size: 100%; }
 html body { min-block-size: 100%; }
 }
*/

/* Example nesting Cascade Layers */
@layer base {
 html {
 block-size: 100%;

 @layer support {
 body {
 min-block-size: 100%;
 }
 }
 }
}
/* equivalent to
 @layer base {
 html { block-size: 100%; }
 }
 @layer base.support {
 html body { min-block-size: 100%; }
 }
*/

/* Example usage with Scoping */
@scope (.card) to (> header) {
 :scope {
 inline-size: 40ch;
 aspect-ratio: 3/4;

 > header {
 border-block-end: 1px solid white;
 }
 }
}
/* equivalent to
 @scope (.card) to (> header) {
 :scope { inline-size: 40ch; aspect-ratio: 3/4; }
 :scope > header { border-block-end: 1px solid white; }
 }
*/

/* Example nesting Scoping */
.card {
 inline-size: 40ch;
 aspect-ratio: 3/4;

 @scope (&) to (> header > *) {
 :scope > header {
 border-block-end: 1px solid white;
 }
 }
}

/* equivalent to
 .card { inline-size: 40ch; aspect-ratio: 3/4; }
 @scope (.card) to (> header > *) {
 :scope > header { border-block-end: 1px solid white; }
 }
*/
```

### 3.3. Nesting Other At-Rules

In addition to [nested style
rules](#nested-style-rule),
this specification allows [nested group rules] inside of [style
rules](https://drafts.csswg.org/css-syntax-3/#style-rule): any at-rule whose body contains [style
rules] can be nested inside of a [style
rule] as well, unless otherwise specified.

When nested in this way, the contents of a [nested group
rule](#nested-group-rules)'s block are parsed as
[\<block-contents\>](https://drafts.csswg.org/css-syntax-3/#typedef-block-contents) rather than
[\<rule-list\>](https://drafts.csswg.org/css-syntax-3/#typedef-rule-list):

- [Style
 rules](https://drafts.csswg.org/css-syntax-3/#style-rule) are [nested style
 rules](#nested-style-rule), with their [nesting
 selector](#nesting-selector) taking its definition from the nearest ancestor
 [style rule].

- Properties can be directly used, acting as if they were nested in a
 [nested declarations
 rule](#nested-declarations-rule).

Specifically, these rules are capable of being [nested group
rules](#nested-group-rules):

- all the [conditional group
 rules](https://drafts.csswg.org/css-conditional-3/#conditional-group-rule)
 ([\@container](https://drafts.csswg.org/css-conditional-5/#at-ruledef-container),
 [\@media](https://drafts.csswg.org/css-conditional-3/#at-ruledef-media),
 [\@supports](https://drafts.csswg.org/css-conditional-3/#at-ruledef-supports))

- [\@layer](https://drafts.csswg.org/css-cascade-5/#at-ruledef-layer)

- [\@scope](https://drafts.csswg.org/css-cascade-6/#at-ruledef-scope)

- [conditional-properties.html](https://wpt.fyi/results/css/css-nesting/conditional-properties.html "css/css-nesting/conditional-properties.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/conditional-properties.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/conditional-properties.html)
- [conditional-rules.html](https://wpt.fyi/results/css/css-nesting/conditional-rules.html "css/css-nesting/conditional-rules.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/conditional-rules.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/conditional-rules.html)
- [invalid-inner-rules.html](https://wpt.fyi/results/css/css-nesting/invalid-inner-rules.html "css/css-nesting/invalid-inner-rules.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/invalid-inner-rules.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/invalid-inner-rules.html)
- [supports-rule.html](https://wpt.fyi/results/css/css-nesting/supports-rule.html "css/css-nesting/supports-rule.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/supports-rule.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/supports-rule.html)

The meanings and behavior of such [nested group
rules](#nested-group-rules) is otherwise unchanged, unless otherwise specified.

For example, the following conditional
nestings are valid:

```
/* Properties can be directly used */
.foo {
 display: grid;

 @media (orientation: landscape) {
 grid-auto-flow: column;
 }
}

/* equivalent to: */
.foo {
 display: grid;
}
@media (orientation: landscape) {
 .foo {
 grid-auto-flow: column
 }
}

/* and also equivalent to the unnested: */
.foo { display: grid; }

@media (orientation: landscape) {
 .foo {
 grid-auto-flow: column;
 }
}

/* Conditionals can be further nested */
.foo {
 display: grid;

 @media (orientation: landscape) {
 grid-auto-flow: column;

 @media (min-width > 1024px) {
 max-inline-size: 1024px;
 }
 }
}

/* equivalent to */
.foo { display: grid; }

@media (orientation: landscape) {
 .foo {
 grid-auto-flow: column;
 }
}

@media (orientation: landscape) and (min-width > 1024px) {
 .foo {
 max-inline-size: 1024px;
 }
}

/* Example nesting Cascade Layers */
html {
 @layer base {
 block-size: 100%;

 @layer support {
 & body {
 min-block-size: 100%;
 }
 }
 }
}

/* equivalent to */
@layer base {
 html { block-size: 100%; }
}
@layer base.support {
 html body { min-block-size: 100%; }
}

/* Example nesting Scoping */
.card {
 inline-size: 40ch;
 aspect-ratio: 3/4;

 @scope (&) {
 :scope {
 border: 1px solid white;
 }
 }
}

/* equivalent to */
.card { inline-size: 40ch; aspect-ratio: 3/4; }
@scope (.card) {
 :scope { border-block-end: 1px solid white; }
}
```

Runs of consecutive directly-nested properties are automatically wrapped
in [nested declarations
rules](#nested-declarations-rule). (This is observable in the CSSOM.)

Tests

- [nesting-layer.html](https://wpt.fyi/results/css/css-nesting/nesting-layer.html "css/css-nesting/nesting-layer.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/nesting-layer.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/nesting-layer.html)

#### [3.3.1. ][ Nested [\@scope](https://drafts.csswg.org/css-cascade-6/#at-ruledef-scope) Rules]
When the
[\@scope](https://drafts.csswg.org/css-cascade-6/#at-ruledef-scope) rule is a [nested group
rule](#nested-group-rules), an [&](#selectordef-) in the
[\<scope-start\>](https://drafts.csswg.org/css-cascade-6/#typedef-scope-start) selector refers to the elements
matched by the nearest ancestor style rule.

That is, the following code:

``` highlight
.parent {
 color: blue;

 @scope (& > .scope) to (& .limit) {
 & .content {
 color: red;
 }
 }
}
```

is equivalent to:

``` highlight
.parent { color: blue; }
@scope (.parent > .scope) to (:where(:scope) .limit) {
 :where(:scope) .content {
 color: red;
 }
}
```

The [&](#selectordef-)
selector behaves like `:where(:scope)` in
[\@scope](https://drafts.csswg.org/css-cascade-6/#at-ruledef-scope) rules.

### 3.4. Mixing Nesting Rules and Declarations

When a style rule contains both declarations and [nested style
rules](#nested-style-rule)
or [nested group
rules](#nested-group-rules), all three can be arbitrarily mixed. Declarations
coming after or between rules are implicitly wrapped in [nested
declarations
rules](#nested-declarations-rule), to preserve their order relative to the other rules.

For example, in the following code:

```
article {
 color: green;
 & { color: blue; }
 color: red;
}

/* equivalent to */
article { color: green; }
:is(article) { color: blue; }
article { color: red; }

/* NOT equivalent to */
article { color: green; }
article { color: red; }
:is(article) { color: blue; }
```

For the purpose of determining the [Order Of
Appearance](https://drafts.csswg.org/css-cascade-4/#cascade-sort),
[nested style rules](#nested-style-rule) and [nested group
rules](#nested-group-rules) are considered to come *after* their parent rule.

For example:

```
article {
 color: blue;
 & { color: red; }
}
```

Both declarations have the same specificity (0,0,1), but the nested rule
is considered to come *after* its parent rule, so the [color:
red](https://drafts.csswg.org/css-color-4/#propdef-color) declarations wins the cascade.

On the other hand, in this example:

```
article {
 color: blue;
 :where(&) { color: red; }
}
```

The
[:where()](https://drafts.csswg.org/selectors-4/#where-pseudo) pseudoclass reduces the specificity of the
[nesting selector](#nesting-selector) to 0, so the [color:
red](https://drafts.csswg.org/css-color-4/#propdef-color) declaration now has a specificity of (0,0,0),
and loses to the [color: blue] declaration
before \"Order Of Appearance\" comes into consideration.

 While one *can* freely intermix declarations and nested
rules, it's harder to read and somewhat confusing to do so, since the
later properties are automatically wrapped in a [nested declarations
rule](#nested-declarations-rule) that doesn't appear in the source text. For
readability's sake, it's recommended that authors put all their
properties first in a style rule, before any nested rules. (This also
happens to act slightly better in older user agents: due to specifics of
how parsing and error-recovery work, properties appearing after nested
rules can get skipped.)

## 4. Nesting Selector: the [& selector]
When using a [nested style
rule](#nested-style-rule),
one must be able to refer to the elements matched by the parent rule;
that is, after all, *the entire point of nesting*. To accomplish that,
this specification defines a new selector, the [nesting
selector],
written as [&] (U+0026 AMPERSAND).

When used in the selector of a [nested style
rule](#nested-style-rule),
the [nesting selector](#nesting-selector) represents the elements matched by the parent rule.
When used in any other context, it represents the same elements as
[:scope](https://drafts.csswg.org/selectors-4/#scope-pseudo) in that context (unless otherwise defined).

Tests

- [top-level-is-scope.html](https://wpt.fyi/results/css/css-nesting/top-level-is-scope.html "css/css-nesting/top-level-is-scope.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/top-level-is-scope.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/top-level-is-scope.html)

The [nesting selector](#nesting-selector) can be desugared by replacing it with the parent style
rule's selector, wrapped in an
[:is()](https://drafts.csswg.org/selectors-4/#matches-pseudo) selector. For example,

```
a, b {
 & c { color: blue; }
}
```

is equivalent to

```
:is(a, b) c { color: blue; }
```

The [nesting selector](#nesting-selector) cannot represent pseudo-elements (identical to the
behavior of the
[:is()](https://drafts.csswg.org/selectors-4/#matches-pseudo) pseudo-class).

For example, in the following style
rule:

```
.foo, .foo::before, .foo::after {
 color: red;

 &:hover { color: blue; }
}
```

the [&](#selectordef-)
only represents the elements matched by [.foo]; in other words,
it's equivalent to:

```
.foo, .foo::before, .foo::after {
 color: red;
}
.foo:hover {
 color: blue;
}
```

We'd like to relax this restriction, but
need to do so simultaneously for both
[:is()](https://drafts.csswg.org/selectors-4/#matches-pseudo) and [&](#selectordef-), since they're intentionally built on the same
underlying mechanisms. ([Issue
7433](https://github.com/w3c/csswg-drafts/issues/7433))

The
[specificity](https://drafts.csswg.org/selectors-4/#specificity) of the [nesting
selector](#nesting-selector)
is equal to the largest specificity among the complex selectors in the
parent style rule's selector list (identical to the behavior of
[:is()](https://drafts.csswg.org/selectors-4/#matches-pseudo)), or zero if no such selector list exists.

Tests

- [top-level-parent-pseudo-specificity.html](https://wpt.fyi/results/css/css-nesting/top-level-parent-pseudo-specificity.html "css/css-nesting/top-level-parent-pseudo-specificity.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/top-level-parent-pseudo-specificity.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/top-level-parent-pseudo-specificity.html)

For example, given the following style
rules:

```
#a, b {
 & c { color: blue; }
}
.foo c { color: red; }
```

Then in a DOM structure like

```
<b class=foo>
 <c>Blue text</c>
</b>
```

The text will be blue, rather than red. The specificity of the
[&](#selectordef-) is
the larger of the specificities of [#a] (\[1,0,0\]) and [b]
(\[0,0,1\]), so it's \[1,0,0\], and the entire [& c] selector thus
has specificity \[1,0,1\], which is larger than the specificity of [.foo
c] (\[0,1,1\]).

Notably, this is *different* than the result you'd get if the nesting
were manually expanded out into non-nested rules, since the [color:
blue](https://drafts.csswg.org/css-color-4/#propdef-color) declaration would then be matching due to the
[b c] selector (\[0,0,2\]) rather than [#a c] (\[1,0,1\]).

Why is the specificity different than non-nested rules?

The [nesting selector](#nesting-selector) intentionally uses the same specificity rules as the
[:is()](https://drafts.csswg.org/selectors-4/#matches-pseudo) pseudoclass, which just uses the largest
specificity among its arguments, rather than tracking *which* selector
actually matched.

This is required for performance reasons; if a selector has multiple
possible specificities, depending on how precisely it was matched, it
makes selector matching much more complicated and slower.

That skirts the question, tho: why *do* we define
[&](#selectordef-) in
terms of
[:is()](https://drafts.csswg.org/selectors-4/#matches-pseudo)? Some non-browser implementations of
Nesting-like functionality do *not* desugar to
[:is()], largely because they predate the
introduction of [:is()] as well. Instead,
they desugar directly; however, this comes with its own *significant*
problems, as some (reasonably common) cases can accidentally produce
*massive* selectors, due to the exponential explosion of possibilities.

```
.a1, .a2, .a3 {
 .b1, .b2, .b3 {
 .c1, .c2, .c3 {
 ...;
 }
 }
}

/* naively desugars to */
.a1 .b1 .c1,
.a1 .b1 .c2,
.a1 .b1 .c3,
.a1 .b2 .c1,
.a1 .b2 .c2,
.a1 .b2 .c3,
.a1 .b3 .c1,
.a1 .b3 .c2,
.a1 .b3 .c3,
.a2 .b1 .c1,
.a2 .b1 .c2,
.a2 .b1 .c3,
.a2 .b2 .c1,
.a2 .b2 .c2,
.a2 .b2 .c3,
.a2 .b3 .c1,
.a2 .b3 .c2,
.a2 .b3 .c3,
.a3 .b1 .c1,
.a3 .b1 .c2,
.a3 .b1 .c3,
.a3 .b2 .c1,
.a3 .b2 .c2,
.a3 .b2 .c3,
.a3 .b3 .c1,
.a3 .b3 .c2,
.a3 .b3 .c3
```

Here, three levels of nesting, each with three selectors in their lists,
produced 27 desugared selectors. Adding more selectors to the lists,
adding more levels of nesting, or making the nested rules more complex
can make a relatively small rule expand into multiple megabytes of
selectors (or much, much more!).

Some CSS tools avoid the worst of this by heuristically discarding some
variations, so they don't have to output as much but are still
*probably* correct, but that's not an option available to UAs.

Desugaring with
[:is()](https://drafts.csswg.org/selectors-4/#matches-pseudo) instead eliminates this problem entirely, at the
cost of making specificity slightly less useful, which was judged a
reasonable trade-off.

The [nesting selector](#nesting-selector) is capable of matching
[featureless](https://drafts.csswg.org/selectors-4/#featureless) elements, if they were matched by the parent rule.

While the position of a [nesting
selector](#nesting-selector) in a [compound
selector](https://drafts.csswg.org/selectors-4/#compound) does not make a difference in its behavior (that is,
[&.foo] and [.foo&] match the same elements), the existing
rule that a [type
selector](https://drafts.csswg.org/selectors-4/#type-selector), if present, must be first in the [compound
selector] continues to apply (that is, [&div]
is illegal, and must be written [div&] instead).

Tests

- [contextually-invalid-selectors-001.html](https://wpt.fyi/results/css/css-nesting/contextually-invalid-selectors-001.html "css/css-nesting/contextually-invalid-selectors-001.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/contextually-invalid-selectors-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/contextually-invalid-selectors-001.html)
- [contextually-invalid-selectors-002.html](https://wpt.fyi/results/css/css-nesting/contextually-invalid-selectors-002.html "css/css-nesting/contextually-invalid-selectors-002.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/contextually-invalid-selectors-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/contextually-invalid-selectors-002.html)
- [contextually-invalid-selectors-003.html](https://wpt.fyi/results/css/css-nesting/contextually-invalid-selectors-003.html "css/css-nesting/contextually-invalid-selectors-003.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/contextually-invalid-selectors-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/contextually-invalid-selectors-003.html)
- [host-nesting-001.html](https://wpt.fyi/results/css/css-nesting/host-nesting-001.html "css/css-nesting/host-nesting-001.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/host-nesting-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/host-nesting-001.html)
- [host-nesting-002.html](https://wpt.fyi/results/css/css-nesting/host-nesting-002.html "css/css-nesting/host-nesting-002.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/host-nesting-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/host-nesting-002.html)
- [host-nesting-003.html](https://wpt.fyi/results/css/css-nesting/host-nesting-003.html "css/css-nesting/host-nesting-003.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/host-nesting-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/host-nesting-003.html)
- [host-nesting-004.html](https://wpt.fyi/results/css/css-nesting/host-nesting-004.html "css/css-nesting/host-nesting-004.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/host-nesting-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/host-nesting-004.html)
- [host-nesting-005.html](https://wpt.fyi/results/css/css-nesting/host-nesting-005.html "css/css-nesting/host-nesting-005.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/host-nesting-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/host-nesting-005.html)
- [nesting-type-selector.html](https://wpt.fyi/results/css/css-nesting/nesting-type-selector.html "css/css-nesting/nesting-type-selector.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/nesting-type-selector.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/nesting-type-selector.html)

## 5. The Nested Declarations Rule

For somewhat-technical reasons, it's important to be able to distinguish
properties that appear at the start of a style rule's contents from
those that appear interspersed with other rules.

For example, in the following two
rules:

```
.foo {
 color: red;
 @media (...)
 background: blue;
}
```

We need to treat the [color:
red](https://drafts.csswg.org/css-color-4/#propdef-color) and [background:
blue](https://drafts.csswg.org/css-backgrounds-3/#propdef-background) slightly differently. In particular, in the
CSSOM, the [color: red] is exposed in the
style rule's
[`style`](https://drafts.csswg.org/cssom-1/#dom-cssstylerule-style) attribute, while the [background:
blue] needs to instead show up in its
[`cssRules`](https://drafts.csswg.org/cssom-1/#dom-cssgroupingrule-cssrules) list.

To accomplish this, CSS parsing *automatically* wraps such properties in
a special child rule to contain them. However, if we were to wrap them
in a [style
rule](https://drafts.csswg.org/css-syntax-3/#style-rule) with an [&](#selectordef-) selector, it would have somewhat unfortunate
behavior:

For example, in

```
.foo, .foo::before {
 color: red;
 & {
 background: blue;
 }
}
```

the nested rule *does not* apply the
[background](https://drafts.csswg.org/css-backgrounds-3/#propdef-background) property to the
[.foo::before] elements, because the
[&](#selectordef-) can't
represent pseudo-elements.

Similarly, child declarations in nested non-style rules need to be
exposed as
[rules](https://drafts.csswg.org/css-syntax-3/#css-rule) in some way, because these sorts of rules (like
[\@media](https://drafts.csswg.org/css-conditional-3/#at-ruledef-media)) have never had
[`style`](https://drafts.csswg.org/cssom-1/#dom-cssstylerule-style) properties. These run into the same problems as above.

To address all of these issue, we instead wrap runs of consecutive
directly-nested properties in a [nested declarations
rule].

Unless otherwise specified, a [nested declarations
rule](#nested-declarations-rule) is a [nested style
rule](#nested-style-rule),
and acts identically to any other style rule. It matches the exact same
elements and pseudo-elements as its parent style rule, with the same
specificity behavior. [(This is *similar to* being a style rule with an
[&](#selectordef-)
selector, but slightly more powerful, as explained above.)]

Why does the [nested declarations
rule](#nested-declarations-rule) exist?

Originally, this specification grouped all declarations in style rules
together, \"moving\" them from their original location to act as if they
were placed at the front of the rule. It also automatically wrapped raw
declarations inside of [nested group
rules](#nested-group-rules) in plain style rules, using the
[&](#selectordef-)
selector.

There are two major reasons we switched to instead use the [nested
declarations
rule](#nested-declarations-rule).

First, using an [& {\...}] rule to implicitly wrap declarations in
a [nested group rule](#nested-group-rules) also changed the behavior. As shown in the example
following this note, it breaks cases where the parent style rule
contains pseudo-elements, and even when that's not the case, it
potentially changes the specificity behavior of the nested declarations.
Switching to the [nested declarations
rule](#nested-declarations-rule) avoids these problems, making the behavior of nested
[\@media](https://drafts.csswg.org/css-conditional-3/#at-ruledef-media)/etc identical to the behavior of \*non\*-nested
[\@media]/etc.

Second, there are some details of future CSS features (notably,
\"mixins\") that simply won't work correctly if interleaved declarations
are automatically moved to the front of the style rule. We need to keep
their relative order with other rules, and in order to actually make
that representable in the CSSOM, that means they have to be wrapped in
some kind of rule. The same issues as the previous paragraph apply if we
just use a normal [& {\...}] rule, so the [nested declarations
rule](#nested-declarations-rule) lets us do so without side effects.

For example, in the following
stylesheet snippet:

```
.foo, .foo::before, .foo::after {
 color: black;
 @media (prefers-color-scheme: dark) {
 & {
 color: white;
 }
 }
}
```

In a darkmode page, the [.foo] element would have its text color
changed to white, but its
[::before](https://drafts.csswg.org/css-pseudo-4/#selectordef-before) and
[::after](https://drafts.csswg.org/css-pseudo-4/#selectordef-after) pseudos would remain black, because the
[&](#selectordef-)
selector can't represent pseudo-elements.

However, it was instead written as:

```
.foo, .foo::before, .foo::after {
 color: black;
 @media (prefers-color-scheme: dark) {
 color: white;
 }
}
```

Then the [color:
white](https://drafts.csswg.org/css-color-4/#propdef-color) is implicitly wrapped in a [nested
declarations
rule](#nested-declarations-rule), which is guaranteed to match *exactly* the same as its
parent style rule, so the element *and* its pseudo-elements would all
have white text in a darkmode page.

Declarations interleaved with rules
get implicitly wrapped in a [nested declarations
rule](#nested-declarations-rule), which makes them part of a separate style rule. For
example, given this CSS:

```
.foo {
 color: black;
 @media (...)
 background: silver;
}
```

If the [.foo] rule's CSSOM object is examined, its
[`style`](https://drafts.csswg.org/cssom-1/#dom-cssstylerule-style) attribute will contain only one declaration: the
[color:
black](https://drafts.csswg.org/css-color-4/#propdef-color) one.

The [background:
silver](https://drafts.csswg.org/css-backgrounds-3/#propdef-background) declaration will instead be found in the
implicitly-created [nested declarations child
rule](#nested-declarations-rule), at `fooRule.cssRules[1].style`.

- [mixed-declarations-rules.html](https://wpt.fyi/results/css/css-nesting/mixed-declarations-rules.html "css/css-nesting/mixed-declarations-rules.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/mixed-declarations-rules.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/mixed-declarations-rules.html)
- [nested-declarations-cssom-whitespace.html](https://wpt.fyi/results/css/css-nesting/nested-declarations-cssom-whitespace.html "css/css-nesting/nested-declarations-cssom-whitespace.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/nested-declarations-cssom-whitespace.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/nested-declarations-cssom-whitespace.html)
- [nested-declarations-cssom.html](https://wpt.fyi/results/css/css-nesting/nested-declarations-cssom.html "css/css-nesting/nested-declarations-cssom.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/nested-declarations-cssom.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/nested-declarations-cssom.html)
- [nested-declarations-matching.html](https://wpt.fyi/results/css/css-nesting/nested-declarations-matching.html "css/css-nesting/nested-declarations-matching.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/nested-declarations-matching.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/nested-declarations-matching.html)

## 6. CSSOM

[\[CSSOM-1\]](#biblio-cssom-1 "CSS Object Model (CSSOM)")
now defines that
[`CSSStyleRule`](https://drafts.csswg.org/cssom-1/#cssstylerule) can have child rules.

When serializing a [relative
selector](https://drafts.csswg.org/selectors-4/#relative-selector) in a [nested style
rule](#nested-style-rule),
the selector must be absolutized, with the implied [nesting
selector](#nesting-selector) inserted.

For example, the selector [\>
.foo] will serialize as [& \> .foo].

- [cssom.html](https://wpt.fyi/results/css/css-nesting/cssom.html "css/css-nesting/cssom.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/cssom.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/cssom.html)
- [set-selector-text.html](https://wpt.fyi/results/css/css-nesting/set-selector-text.html "css/css-nesting/set-selector-text.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/set-selector-text.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/set-selector-text.html)

### 6.1. The [`CSSNestedDeclarations` Interface]
The
[`CSSNestedDeclarations`](#cssnesteddeclarations) interface represents a [nested declarations
rule](#nested-declarations-rule).

```
[Exposed=Window]
interface CSSNestedDeclarations : CSSRule {
 [SameObject, PutForwards=cssText] readonly attribute CSSStyleProperties style;
};
```

The [`style`] attribute must return a
[`CSSStyleProperties`](https://drafts.csswg.org/cssom-1/#cssstyleproperties) object for the rule, with the following properties:

[computed flag](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-computed-flag)

: Unset

[readonly flag](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-readonly-flag)

: Unset

[declarations](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-declarations)

: The declared declarations in the rule, in [specified
 order](https://drafts.csswg.org/cssom-1/#concept-declarations-specified-order).

[parent CSS rule](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-parent-css-rule)

: [this](https://webidl.spec.whatwg.org/#this)

[owner node](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-owner-node)

: Null

[`CSSNestedDeclarations`](#cssnesteddeclarations) rule
[serializes](https://drafts.csswg.org/cssom-1/#serialize-a-css-rule) as if its [declaration
block](https://drafts.csswg.org/cssom-1/#css-declaration-block) had been
[serialized](https://drafts.csswg.org/cssom-1/#serialize-a-css-declaration-block) directly.

Tests

- [serialize-group-rules-with-decls.html](https://wpt.fyi/results/css/css-nesting/serialize-group-rules-with-decls.html "css/css-nesting/serialize-group-rules-with-decls.html")
 [[(live
 test)]](http://wpt.live/css/css-nesting/serialize-group-rules-with-decls.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-nesting/serialize-group-rules-with-decls.html)

 This means that multiple adjacent [nested declarations
rules](#nested-declarations-rule) (which is possible to create with e.g.
[`insertRule`](https://drafts.csswg.org/cssom-1/#dom-cssgroupingrule-insertrule)) will collapse into a single rule when serialized and
parsed again.

## [Privacy Considerations]
No new privacy considerations have been reported on this specification.

## [Security Considerations]
No new security considerations have been reported on this specification.

## 7. Changes

Significant changes since the [Feb 14, 2023 Working
Draft](https://www.w3.org/TR/2023/WD-css-nesting-1-20230214/):

- The
 [\<scope-start\>](https://drafts.csswg.org/css-cascade-6/#typedef-scope-start) selector of a
 [\@scope](https://drafts.csswg.org/css-cascade-6/#at-ruledef-scope) rule no longer acts as the parent rule for
 nesting. ([Issue
 9740](https://github.com/w3c/csswg-drafts/issues/9740))

- Clarified that the [nesting
 selector](#nesting-selector) is allowed to match featureless elements.

- Switched [&div] back to being invalid; now that Syntax does
 \"infinite lookahead\", we no longer need to allow it. Plus, doing so
 avoids a clash with preprocessors. ([Issue
 8662](https://github.com/w3c/csswg-drafts/issues/8662))

- CSSOM now defines that CSSStyleRule is a CSSGroupingRule subclass, so
 the manual definition of the `cssRules` attribute and
 related machinery was removed. ([Issue
 8940](https://github.com/w3c/csswg-drafts/issues/8940))

- Clarified the effect of the *implied* nesting selector on specificity.
 ([Issue 9069](https://github.com/w3c/csswg-drafts/issues/9069))

- Declarations intermixed with rules (or all declarations in nested
 group rules) are now automatically wrapped in `@nest`
 rules. (Also the `@nest` rule was added.) ([Issue
 8738](https://github.com/w3c/csswg-drafts/issues/8738))

- Replaced `@nest` with [nested declarations
 rules](#nested-declarations-rule). ([Issue
 10234](https://github.com/w3c/csswg-drafts/issues/10234))

- Added Web Platform Tests coverage.
