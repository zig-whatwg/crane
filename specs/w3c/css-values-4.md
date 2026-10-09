## 1. Introduction

The value definition field of each CSS property can contain keywords,
data types (which appear between [\<] and [\>]), and
information on how they can be combined. Generic data types
([\<length\>](#length-value) being the most widely used) that can be used by many
properties are described in this specification, while more specific data
types (e.g., [\<spacing-limit\>]) are
described in the corresponding modules.

### 1.1. Module Interactions

This module replaces and extends the data type definitions in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
sections [1.4.2.1](https://www.w3.org/TR/CSS2/about.html#value-defs),
[4.3](https://www.w3.org/TR/CSS2/syndata.html#values), and
[A.2](https://www.w3.org/TR/CSS2/aural.html#aural-intro).

## 2. Value Definition Syntax

The [value definition syntax] described
here is used to define the set of valid values for CSS properties (and
the valid syntax of many other parts of CSS). A value so described can
have one or more components.

### 2.1. Component Value Types

Component value types are designated in several ways:

1. [Keyword](#keywords) values (such as `auto`,
 [disc](https://drafts.csswg.org/css-counter-styles-3/#disc), etc.) and at-keywords representing the
 start of an
 [at-rule](https://drafts.csswg.org/css-syntax-3/#at-rule), which appear literally, without quotes (e.g.
 `auto` or `@media`).

 It is possible, with
 [escaping](https://drafts.csswg.org/css-syntax-3/#escape-codepoint), to construct a [CSS
 identifier](#css-css-identifier) whose value ends with `(` or starts
 with `@`. Such a token is an
 [\<ident-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-ident-token) (i.e. a
 [keyword](#css-keyword)), not
 a
 [\<function-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-function-token) or an
 [\<at-keyword-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-at-keyword-token).

2. Basic data types, which appear between `<` and
 `>` (e.g.,
 [\<length\>](#length-value),
 [\<percentage\>](#percentage-value), etc.). For [numeric data
 types](#numeric-data-types), this type notation can annotate any range
 restrictions using the [bracketed range notation](#numeric-ranges)
 described below.

3. Property value ranges, which represent the same pattern of values as
 a property bearing the same name. These are written as the property
 name, surrounded by single quotes, between `<` and
 `>`, e.g.,
 [\<\'border-width\'\>](https://drafts.csswg.org/css-borders-4/#propdef-border-width),
 [\<\'background-attachment\'\>](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-attachment), etc.

 These types *do not* include [CSS-wide keywords](#common-keywords)
 such as
 [inherit](https://drafts.csswg.org/css-cascade-5/#valdef-all-inherit). Additionally, if the property's value
 grammar is a [comma-separated
 repetition](#mult-comma),
 the corresponding type does not include the top-level
 [comma-separated list multiplier]. (E.g. if a
 property named `pairing` is defined as
 `[ `[`<custom-ident>`](#identifier-value)` `[`<integer>`](#integer-value)`? ]#`, then
 `<'pairing'>` is equivalent to
 `[ `[`<custom-ident>`](#identifier-value)` `[`<integer>`](#integer-value)`? ]`, not
 `[ `[`<custom-ident>`](#identifier-value)` `[`<integer>`](#integer-value)`? ]#`.)

 Why remove the multiplier?

 The top-level multiplier is ripped out of these value types because
 top-level comma-separated repetitions are mostly used for
 [coordinating list
 properties](#coordinating-list-property), and when a shorthand combines several such
 properties, it needs the unmultiplied grammar so it can construct
 its *own* comma-separated repetition.

 Without this special treatment, every such longhand would have to be
 defined with an ad-hoc production just for the inner value, which
 makes the grammars harder to understand overall.

4. Functional notations and their arguments. These may be written
 literally as defined in [§ 2.6 Functional Notation
 Definitions](#component-functions), or referenced by a non-terminal
 using the function's name, followed by an empty parentheses pair,
 between `<` and `>`, e.g.
 [\<calc()\>](#funcdef-calc), and references the correspondingly-named
 [functional
 notation](#functional-notation).

5. Other non-terminals. These are written as the name of the
 non-terminal between `<` and `>`, as in
 [\<spacing-limit\>]. Notice the
 distinction between
 [\<border-width\>](https://drafts.csswg.org/css2/#value-def-border-width) and
 [\<\'border-width\'\>](https://drafts.csswg.org/css-borders-4/#propdef-border-width): the latter represents the
 grammar of the [border-width] property, the former requires an explicit expansion
 elsewhere. The definition of a non-terminal is typically located
 near its first appearance in the specification.

6. Delimiters, which represent their corresponding tokens. Slashes
 (`/`), [commas](#comb-comma) (`,`), colons (`:`),
 semicolons (`;`), parentheses (`(` and
 `)`), and braces (`{` and `}`)
 are written literally. Other delimiters must be written enclosed in
 single quotes (such as `'+'`).

**[Commas] specified in the grammar are implicitly omissible** in some
circumstances, when used to separate optional terms in the grammar.
Within a top-level list in a property or other CSS value, or a
function's argument list, a comma specified in the grammar must be
omitted if:

- all items preceding the comma have been omitted
- all items following the comma have been omitted
- multiple commas would be adjacent (ignoring [white
 space](https://www.w3.org/TR/css-syntax/#whitespace)/comments), due to
 the items between the commas being omitted.

For example, if a function can accept
three arguments in order, but all of them are optional, the grammar can
be written like:

```
example( first? , second? , third? )
```

Given this grammar, writing [example(first, second, third)] is
valid, as is [example(first, second)] or [example(first,
third)] or [example(second)]. However, [example(first, ,
third)] is invalid, as one of those commas are no longer
separating two options; similarly, [example(,second)] and
[example(first,)] are invalid. [example(first second)] is
also invalid, as commas are still required to actually separate the
options.

If commas were not implicitly omittable, the grammar would have to be
much more complicated to properly express the ways that the arguments
can be omitted, greatly obscuring the simplicity of the feature.

All CSS properties also accept the [CSS-wide keyword
values](#common-keywords) as the sole component of their property value.
For readability these are not listed explicitly in the property value
syntax definitions. For example, the full value definition of
[border-color](https://drafts.csswg.org/css-borders-4/#propdef-border-color) under [CSS Cascading and
Inheritance Level
3](#biblio-css-cascade-3 "CSS Cascading and Inheritance Level 3")
is `<color>{1,4} | inherit | initial | unset` (even though
it is listed as `<color>{1,4}`).

 This implies that, in general, combining these keywords
with other component values in the same declaration results in an
invalid declaration. For example, [background: url(corner.png)
no-repeat,
inherit;](https://drafts.csswg.org/css-backgrounds-3/#propdef-background) is invalid.

### 2.2. Component Value Combinators

Component values can be arranged into property values as follows:

- Juxtaposing components means that all of them must occur, in the given
 order.
- A double ampersand ([&&]) separates two or more components, all
 of which must occur, in any order.
- A double bar ([\|\|]) separates two or more options: one or more of them must
 occur, in any order.
- A bar ([\|])
 separates two or more alternatives: exactly one of them must occur.
- Brackets (\[ \]) are for grouping.

Juxtaposition is stronger than the double ampersand, the double
ampersand is stronger than the double bar, and the double bar is
stronger than the bar. Thus, the following lines are equivalent:

``` highlight
 a b | c || d && e f
[ a b ] | [ c || [ d && [ e f ]]]
```

For reorderable combinators (\|\|, &&), ordering of the grammar does not
matter: components in the same grouping may be interleaved in any order.
Thus, the following lines are equivalent:

``` highlight
a || b || c
b || a || c
```

 Combinators are *not* associative, so grouping is
significant. For example, [a \|\| b \|\| c] and [a \|\| \[ b \|\|
c \]] are distinct grammars: the first allows a value like [b a
c], but the second does not.

### 2.3. Component Value Multipliers

Every type, keyword, or bracketed group may be followed by one of the
following modifiers:

- An asterisk ([\*]) indicates that the preceding type, word, or group occurs
 zero or more times.
- A plus ([+]) indicates that the preceding type, word, or group occurs
 one or more times.
- A question mark ([?]) indicates that the preceding type, word, or group is
 optional (occurs zero or one times).
- A single number in curly braces ([{`A`}]) indicates that the
 preceding type, word, or group occurs `A` times.
- A comma-separated pair of numbers in curly braces
 ([{`A`,`B`}]) indicates that the preceding type,
 word, or group occurs at least `A` and at most
 `B` times. The `B` may be omitted
 ({`A`,}) to indicate that there must be at least
 `A` repetitions, with no upper bound on the number of
 repetitions.
- A hash mark ([\#]) indicates that the preceding type, word, or group occurs
 one or more times, separated by comma tokens (which may optionally be
 surrounded by [white
 space](https://www.w3.org/TR/css-syntax/#whitespace) and/or comments).
 It may optionally be followed by the curly brace forms, above, to
 indicate precisely how many times the repetition occurs, like
 [\<length\>#{1,4}].
- An exclamation point ([!]) after a group indicates that the group
 is required and must produce at least one value; even if the grammar
 of the items within the group would otherwise allow the entire
 contents to be omitted, at least one component value must not be
 omitted.

The [+] and [\#] multipliers may be stacked as [+#];
similarly, the [\#] and [?] multipliers, [{A}] and
[?] multipliers, and [{A,B}] and [?] multipliers may
be stacked as [#?], [{A}?], and [{A,B}?],
respectively. These stacks each represent the later multiplier applied
to the result of the earlier multiplier. (These same stacks can be
represented using grouping, but in complex grammars this can push the
number of brackets beyond readability.)

For repeated component values (indicated by [\*], [+], or
[\#]),
[UAs](https://drafts.csswg.org/css-2023/#user-agent) must support at least 20 repetitions of the component.
If a property value contains more than the supported number of
repetitions, the declaration must be ignored as if it were invalid.

### 2.4. Combinator and Multiplier Patterns

There are a small set of common ways to combine multiple independent
[component
values](https://drafts.csswg.org/css-syntax-3/#component-value) in particular numbers and orders. In particular, it's
common to want to express that, from a set of component value, the
author must select zero or more, one or more, or all of them, and in
either the order specified in the grammar or in any order.

All of these can be easily expressed using simple patterns of
[combinators](#component-combinators) and
[multipliers](#component-multipliers):

in order

any order

zero or more

`A? B? C?`

`A? || B? || C?`

one or more

`[ A? B? C? ]!`

`A || B || C`

all

`A B C `

`A && B && C`

Note that all of the \"any order\" possibilities are expressed using
combinators, while the \"in order\" possibilities are all variants on
juxtaposition.

### 2.5. Component Values and White Space

Unless otherwise specified, [white
space](https://www.w3.org/TR/css-syntax/#whitespace) and/or comments may
appear before, after, and/or between components combined using the above
[combinators](#component-combinators) and
[multipliers](#component-multipliers).

 In many cases, spaces will in fact be *required*
between components in order to distinguish them from each other. For
example, the value [1em2em] would be parsed as a single
[\<dimension-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-dimension-token) with the number [1] and the
identifier [em2em], which is an invalid unit. In this case, a
space would be required before the [2] to get this parsed as the
two lengths [1em] and [2em].

### 2.6. Functional Notation Definitions

The syntax of a [functional
notation](#functional-notation) is defined as a sequence of:

1. The function's name written as an identifier followed by an open
 parenthesis (such as [example(]), or the
 [\<function-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-function-token) production to indicate a function
 with an arbitrary name.

2. The function's arguments, if any, expressed using the [value
 definition
 syntax](#css-value-definition-syntax).

3. A literal closing parenthesis.

The function's arguments are considered *implicitly grouped*, as if
surrounded by brackets ([\[ \... \]]).

For example, a grammar like:

```
example( <length> , <length> )
```

will match a function whose name is \"example\" and whose arguments
match \"[\<length\>](#length-value) , [\<length\>]\".

For example, the Selectors grammar
defines pseudo-classes generically, allowing any possibly function name
after the initial colon:

```
<pseudo-class-selector> = : <ident-token> | : <function-token> <any-value> )
```

This represents *any* function name, with
[\<any-value\>](https://drafts.csswg.org/css-syntax-3/#typedef-any-value) as the function arguments.

Since the [functional
notation](#functional-notation) *implicitly groups* its contents, the effect of any
combinator inside it is scoped to the function's argument. For example,
the [functional notation] syntax
definition [example( foo \| bar )] is equivalent to [example( \[
foo \| bar \] )].

### 2.7. Property Value Examples

Below are some examples of properties with their corresponding value
definition fields

Property

Value definition field

Example value

[orphans](https://drafts.csswg.org/css-break-3/#propdef-orphans)

\<integer\>

[3]

[text-align](https://drafts.csswg.org/css-text-3/#propdef-text-align)

left \| right \| center \| justify

[center](https://drafts.csswg.org/css-text-4/#valdef-text-align-center)

[padding-top](https://drafts.csswg.org/css-box-4/#propdef-padding-top)

\<length\> \| \<percentage\>

[5%]

[outline-color](https://drafts.csswg.org/css-ui-4/#propdef-outline-color)

\<color\> \| invert

[#fefefe]

[text-decoration](https://drafts.csswg.org/css-text-decor-4/#propdef-text-decoration)

none \| underline \|\| overline \|\| line-through \|\| blink

[overline underline]

[font-family](https://drafts.csswg.org/css-fonts-4/#propdef-font-family)

\[ \<font-family-name\> \| \<generic-font-family\> \]#

[\"Gill Sans\", Futura, sans-serif]

[border-width](https://drafts.csswg.org/css-borders-4/#propdef-border-width)

\[ \<length\> \| thick \| medium \| thin \]{1,4}

[2px medium 4px]

[box-shadow](https://drafts.csswg.org/css-borders-4/#propdef-box-shadow)

\[ inset? && \<length\>{2,4} && \<color\>? \]# \| none

[3px 3px rgba(50%, 50%, 50%, 50%), lemonchiffon 0 0 4px inset]

### 2.8. Non-Terminal Definitions and Grammar Production Blocks

The precise grammar of non-terminals, like
[\<position\>](#typedef-position) or
[\<calc()\>](#funcdef-calc), is often specified in a [CSS grammar production
block]. These are conventionally represented in a preformatted block
of definitions like this:

The [\<foo\>] syntax is defined
as follows:

```
<foo> = keyword | <bar> |
 some-really-long-pattern-of-stuff
<bar> = <length>
```

Each definition starts on its own line, and consists of the non-terminal
to be defined, followed by an `=`, followed by the fragment
of [value definition
syntax](#css-value-definition-syntax) to which it expands. A definition can stretch across
multiple lines, and terminates before the next line that starts a new
grammar production or at the end of the grammar production block
(whichever comes first).

In the above example, the
[\<foo\>] definition covers two lines. The third line starts a new
definition for [\<bar\>]. (A naked `=` is never valid
in [value definition
syntax](#css-value-definition-syntax), so it's unambiguous when a new line starts a fresh
definition.)

## 3. Combining Values: Interpolation, Addition, and Accumulation

Some procedures, for example
[transitions](https://www.w3.org/TR/css-transitions/) and
[animations](https://www.w3.org/TR/css-animations/), [combine] two CSS property values. The
following combining operations---​on the two [computed
values](https://drafts.csswg.org/css-cascade-5/#computed-value) `V`~`A`~ and
`V`~`B`~ yielding the [computed
value]
`V`~`result`~---​are defined. For operations that
are not commutative (for example, matrix multiplication, or accumulation
of mismatched transform lists) `V`~`A`~ represents
the first term of the operation and `V`~`B`~
represents the second.

[interpolation]

: Given two property values `V`~`A`~ and
 `V`~`B`~, produces an intermediate value
 `V`~`result`~ at a distance of `p`
 along the interval between `V`~`A`~ and
 `V`~`B`~ such that `p` = 0 produces
 `V`~`A`~ and `p` = 1 produces
 `V`~B~.

 The range of `p` is (−∞, ∞) due to the effect of [timing
 functions](https://drafts.csswg.org/css-easing-2/#easing-function). As a result, this procedure must also define
 extrapolation behavior for `p` outside \[0, 1\].

[addition]

: Given two property values `V`~`A`~ and
 `V`~`B`~, returns the sum of the two
 properties, `V`~result~.

 While [addition](#addition) can often be expressed in terms of the same
 weighted sum function used to define
 [interpolation](#interpolation), this is not always the case. For example,
 interpolation of transform matrices involves decomposing and
 interpolating the matrix components whilst addition relies on matrix
 multiplication.

 If a value type does not define a specific procedure for
 [addition](#addition) or is
 defined as [not additive], its [addition]
 operation is simply `V`~`result`~ =
 `V`~`B`~.

[accumulation]

: Given two property values `V`~`A`~ and
 `V`~`B`~, returns the result,
 `V`~`result`~, of combining the two operands
 such that `V`~`B`~ is treated as a *delta*
 from `V`~`A`~.

 :::
 Note: For many types of animation such as numbers or lengths,
 [accumulation](#accumulation)
 is defined to be identical to
 [addition](#addition).
 A common case where the definitions differ is for list-based types
 where [addition](#addition) may
 be defined as appending to a list whilst
 [accumulation](#accumulation) may be defined as component-based addition. For
 example, the filter list values [blur(2)] and [blur(3)],
 when [added] together would produce [blur(2)
 blur(3)], but when [accumulated] would
 produce [blur(5)].
 :::

 If a value type does not define a specific procedure for
 [accumulation](#accumulation), its [accumulation]
 operation is identical to [addition](#addition).

These operations are only defined on [computed
values](https://drafts.csswg.org/css-cascade-5/#computed-value). (As a result, it is not necessary to define, for
example, how to add a [\<length\>](#length-value) value of [15pt] with
[5em] since such values will be resolved to their [canonical
unit](#canonical-unit) before
being passed to any of the above procedures.)

### 3.1. Range Checking

Interpolation can result in a value outside the valid range for a
property, even if all of the inputs to interpolation are valid; this
especially happens when `p` is outside the \[0, 1\] range,
but some [easing
functions](https://drafts.csswg.org/css-easing-2/#easing-function) can cause this to occur even within that range. If the
final result *after* interpolation, addition, and accumulation is
out-of-range for the target context the value is being used in, it does
not cause the declaration to be invalid. Instead, the value must be
clamped to the range allowed in the target context, exactly the same as
[math functions](#math-function)
(see [§ 10.12 Range Checking](#calc-range)).

 Even if interpolation results in an out-of-range value,
addition/accumulation might \"correct\" the result and bring it back
into range. Thus, clamping is only applied to the *final* result of
applying all interpolation-related operations.

## 4. Textual Data Types

The [textual data types] include various keywords and
identifiers as well as strings
([\<string\>](#string-value)) and URLs ([\<url\>](#url-value)). Aside from the casing of
[pre-defined keywords](#keywords) or as explicitly defined for a given
property, no normalization is performed, not even Unicode normalization:
the
[specified](https://drafts.csswg.org/css-cascade-5/#specified-value) and [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) of a property are exactly the provided Unicode values
after parsing (which includes character set conversion and
[escaping](https://drafts.csswg.org/css-syntax-3/#escaping)).
[\[UNICODE\]](#biblio-unicode "The Unicode Standard")
[\[CSS-SYNTAX-3\]](#biblio-css-syntax-3 "CSS Syntax Module Level 3")

[Strings](https://infra.spec.whatwg.org/#string) are quoted sequences of characters reprenting arbitrary
textual data. See [§ 4.4 Quoted Strings: the \<string\> type](#strings)
for details.

CSS [identifiers], generically
denoted by [\<ident\>], represent names, and are written as an
unquoted sequence of (potentially escaped) characters corresponding to
the
[\<ident-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-ident-token) grammar.
[\[CSS-SYNTAX-3\]](#biblio-css-syntax-3 "CSS Syntax Module Level 3")
Identifiers cannot be quoted; otherwise they would be interpreted as
strings. CSS properties accept two classes of
[identifiers](#css-css-identifier): [pre-defined keywords](#keywords) and [author-defined
identifiers](#custom-idents).

 The [\<ident\>](#typedef-ident) production is not meant for property
value
definitions---​[\<custom-ident\>](#identifier-value) should be used instead. It is
provided as a convenience for defining other syntactic constructs.

All textual data types
[interpolate](#interpolation)
as
[discrete](https://drafts.csswg.org/web-animations-1/#discrete) and are [not
additive](#not-additive).

### 4.1. Pre-defined Keywords

In the value definition fields, [keywords] with a
pre-defined meaning appear literally. Keywords are
[identifiers](#css-css-identifier) and are interpreted [ASCII
case-insensitively](https://infra.spec.whatwg.org/#ascii-case-insensitive) (i.e., \[a-z\] and \[A-Z\] are equivalent).

For example, here is the value
definition for the
[border-collapse](https://drafts.csswg.org/css2/#propdef-border-collapse) property:

``` highlight
Value: collapse | separate
```

And here is an example of its use:

``` highlight
table { border-collapse: separate }
```

#### [4.1.1. ][ CSS-wide keywords: [initial](https://drafts.csswg.org/css-cascade-5/#valdef-all-initial), [inherit](https://drafts.csswg.org/css-cascade-5/#valdef-all-inherit) and [unset](https://drafts.csswg.org/css-cascade-5/#valdef-all-unset)]
As defined [above](#component-types), all properties accept the
[CSS-wide keywords], which represent value computations common to all CSS
properties. These keywords are normatively defined in the [CSS Cascading
and Inheritance
Module](https://www.w3.org/TR/css-cascade/#defaulting-keywords).

Tests

- [multicol-inherit-002.xht](https://wpt.fyi/results/css/css-multicol/multicol-inherit-002.xht "css/css-multicol/multicol-inherit-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-inherit-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-inherit-002.xht)
- [multicol-rule-color-inherit-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-color-inherit-001.xht "css/css-multicol/multicol-rule-color-inherit-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-color-inherit-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-color-inherit-001.xht)
- [multicol-rule-color-inherit-002.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-color-inherit-002.xht "css/css-multicol/multicol-rule-color-inherit-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-color-inherit-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-color-inherit-002.xht)
- [units-008.xht](https://wpt.fyi/results/css/CSS2/values/units-008.xht "css/CSS2/values/units-008.xht")
 [[(live
 test)]](http://wpt.live/css/CSS2/values/units-008.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/CSS2/values/units-008.xht)

Other CSS specifications can define additional CSS-wide keywords.

### 4.2. Unprefixed Author-defined Identifiers: the [\<custom-ident\> type]
Some properties accept arbitrary author-defined identifiers as a
component value. This generic data type is denoted by
[\<custom-ident\>], and represents any valid [CSS
identifier](#css-css-identifier) that would not be misinterpreted as a pre-defined
keyword in that property's value definition. Such identifiers are fully
case-sensitive (meaning they're compared using the \"[identical
to](https://infra.spec.whatwg.org/#is)\"
operation), even in the ASCII range (e.g. [example] and
[EXAMPLE] are two different, unrelated user-defined identifiers).

The [CSS-wide keywords](#css-wide-keywords) are not valid
[\<custom-ident\>](#identifier-value)s. The [default] keyword is reserved
and is also not a valid [\<custom-ident\>]. Specifications using
[\<custom-ident\>] must specify
clearly what other keywords are excluded from
[\<custom-ident\>], if any---​for
example by saying that any pre-defined keywords in that property's value
definition are excluded. Excluded keywords are excluded in all [ASCII
case
permutations](https://infra.spec.whatwg.org/#ascii-case-insensitive).

When parsing positionally-ambiguous keywords in a property value, a
[\<custom-ident\>](#identifier-value) production can only claim the keyword if
no other unfulfilled production can claim it.

For example, the shorthand declaration
[animation: ease-in
ease-out](https://drafts.csswg.org/css-animations-1/#propdef-animation) is equivalent to the longhand declarations
[animation-timing-function: ease-in; animation-name:
ease-out;](https://drafts.csswg.org/css-animations-1/#propdef-animation-timing-function).
[ease-in](https://drafts.csswg.org/css-easing-2/#valdef-cubic-bezier-easing-function-ease-in) is claimed by the
[\<easing-function\>](https://drafts.csswg.org/css-easing-2/#typedef-easing-function) production belonging to
[animation-timing-function], leaving
[ease-out](https://drafts.csswg.org/css-easing-2/#valdef-cubic-bezier-easing-function-ease-out) to be claimed by the
[\<custom-ident\>](#identifier-value) production belonging to
[animation-name](https://drafts.csswg.org/css-animations-1/#propdef-animation-name).

 When designing grammars with
[\<custom-ident\>](#identifier-value), the
[\<custom-ident\>] should
always be "positionally unambiguous", so that it's impossible to
conflict with any keyword values in the property. Such conflicts can
alternatively be avoided by using
[\<dashed-ident\>](#typedef-dashed-ident).

### 4.3. Prefixed Author-defined Identifiers: the [\<dashed-ident\> type]
Some contexts accept *both* author-defined identifiers *and* CSS-defined
identifiers. If not handled carefully, this can result in difficulties
adding new CSS-defined values;
[UAs](https://drafts.csswg.org/css-2023/#user-agent) have to study existing usage and gamble that there are
sufficiently few author-defined identifiers in use matching the new
CSS-defined one, so giving the new value a special CSS-defined meaning
won't break existing pages.

While there are many legacy cases in CSS that mix these two values
spaces in exactly this fraught way, the
[\<dashed-ident\>](#typedef-dashed-ident) type is meant to be an easy way to
distinguish author-defined identifiers from CSS-defined identifiers.

The
[[\<dashed-ident\>](#typedef-dashed-ident)] production is a
[\<custom-ident\>](#identifier-value), with all the case-sensitivity that
implies, with the additional restriction that it must start with two
dashes (U+002D HYPHEN-MINUS).

[\<dashed-ident\>](#typedef-dashed-ident)s are reserved solely for use as
author-defined names. CSS will never define a
[\<dashed-ident\>] for its
own use.

For example, [custom
properties](https://drafts.csswg.org/css-variables-2/#custom-property) need to be distinguishable from CSS-defined properties,
as new properties are added to CSS regularly. To allow this, [custom
property] names are required to be
[\<dashed-ident\>](#typedef-dashed-ident)s, as in this example:

``` highlight
.foo {
 --fg-color: blue;
}
```

[\<dashed-ident\>](#typedef-dashed-ident)s are also used in the
[\@color-profile](https://drafts.csswg.org/css-color-5/#at-ruledef-profile) rule, to separate author-defined color profiles
from pre-defined ones like [device-cmyk], and allow CSS to define
more pre-defined (but overridable) profiles in the future without fear
of clashing with author-defined profiles:

``` highlight
@color-profile --foo { src: url(https://example.com/foo.icc); }
.foo {
 color: color(--foo 1 0 .5 / .2);
}
```

CSS will use
[\<dashed-ident\>](#typedef-dashed-ident) more in the future, as more
author-controlled syntax is added. CSS authoring tools, such as
preprocessors that turn custom syntax into standard CSS, *should* use
[\<dashed-ident\>] as well,
to avoid clashing with future CSS design.

For example, if a CSS preprocessor added a new \"custom\" at-rule, it
*shouldn't* spell it [\@custom], as this would clash with a future
official [\@custom] rule added by CSS. Instead, it should use
[@\--custom], which is guaranteed to never clash with anything
defined by CSS.

Even better, it should use [@\--library1-custom], so that if
Library2 adds their own \"custom\" at-rule (spelled
@\--library2-custom), there's no possibility of clash. Ideally this
prefix should be customizable, if allowed by the tooling, so authors can
manually avoid clashes on their own.

### 4.4. Quoted Strings: the [\<string\> type]
[Strings](https://infra.spec.whatwg.org/#string), denoted by [\<string\>], are sequences of characters
representing arbitrary textual data. When written literally, they are
delimited by double quotes or single quotes, and correspond to the
[\<string-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-string-token) production.
[\[CSS-SYNTAX-3\]](#biblio-css-syntax-3 "CSS Syntax Module Level 3").

Double quotes cannot occur inside
double quotes, unless
[escaped](https://www.w3.org/TR/CSS2/syndata.html#escaped-characters)
(as `"\""` or as `"\22"`). Analogously for
single quotes (`'\''` or `'\27'`).

``` highlight
content: "this is a 'string'.";
content: "this is a \"string\".";
content: 'this is a "string".';
content: 'this is a \'string\'.'
```

It is possible to break strings over several lines, for aesthetic or
other reasons, but in such a case the newline itself has to be escaped
with a backslash (\\). The newline is subsequently removed from the
string. For instance, the following two selectors are exactly the same:

Example(s):

``` highlight
a[title="a not s\
o very long title"] {/*...*/}
a[title="a not so very long title"] {/*...*/}
```

Since a string cannot directly represent a newline, to include a newline
in a string, use the escape \"\\A\". (Hexadecimal A is the line feed
character in Unicode (U+000A), but represents the generic notion of
\"newline\" in CSS.)

### 4.5. Resource Locators: the [\<url\> type]
The [\<url\>](#url-value) type, written with the [url()] and [src()] functions,
represents a
[URL](https://url.spec.whatwg.org/#concept-url), which is a pointer to a resource.

The syntax of [\<url\>](#url-value) is:

```
<url> = <url()> | <src()>

<url()> = url( <string> <url-modifier>* ) | <url-token>
<src()> = src( <string> <url-modifier>* )
```

This example shows a URL being used as
a background image:

``` highlight
body { background: url("http://www.example.com/pinkish.gif") }
```

A [url()](#funcdef-url)
can be written without quotation marks around the URL value, in which
case it is
[specially-parsed](https://drafts.csswg.org/css-syntax-3/#consume-a-url-token) as a
[\<url-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-url-token); see [CSS Syntax 3 § 4.3.6 Consume a
url token](https://drafts.csswg.org/css-syntax-3/#consume-url-token).
[\[CSS-SYNTAX-3\]](#biblio-css-syntax-3 "CSS Syntax Module Level 3")

 Because of this special parsing,
[url()](#funcdef-url) can
only express its value literally. To provide a URL by functions such as
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var), use the
[src()](#funcdef-src)
notation, which does not have this special parsing rule.

For example, the following
declarations are identical:

``` highlight
background: url("http://www.example.com/pinkish.gif");
background: url(http://www.example.com/pinkish.gif);
```

And these have the same meaning as well:

``` highlight
background: src("http://www.example.com/pinkish.gif");
--foo: "http://www.example.com/pinkish.gif";
background: src(var(--foo));
```

But this does *not* work:

``` highlight
--foo: "http://www.example.com/pinkish.gif";
background: url(var(--foo));
```

\...because the unescaped \"(\" in the value causes a parse error, so
the entire declaration is thrown out as invalid.

 The unquoted
[url()](#funcdef-url)
syntax cannot accept a
[\<url-modifier\>](#typedef-url-modifier) argument and has extra escaping
requirements: parentheses,
[whitespace](https://www.w3.org/TR/css-syntax/#whitespace) characters,
single quotes (\') and double quotes (\") appearing in a URL must be
escaped with a backslash, e.g. [url(open\\(parens)],
[url(close\\)parens)]. (In quoted
[\<string\>](#string-value) [url()]s, only newlines
and the character used to quote the string need to be escaped.)
Depending on the type of URL, it might also be possible to write these
characters as URL-escapes (e.g. [url(open%28parens)] or
[url(close%29parens)]) as described in
[\[URL\]](#biblio-url "URL Standard").

Some CSS contexts (such as
[\@import](https://drafts.csswg.org/css-cascade-6/#at-ruledef-import)) also allow a
[\<url\>](#url-value) to be represented by a bare
[\<string\>](#string-value), without the function wrapper. In such cases the
string behaves identically to a
[url()](#funcdef-url)
function containing that string.

For example, the following statements
act identically:

``` highlight
@import url("base-theme.css");
@import "base-theme.css";
```

#### 4.5.1. Relative URLs

In order to create modular style sheets that are not dependent on the
absolute location of a resource, authors should use relative URLs.
Relative URLs (as defined in
[\[URL\]](#biblio-url "URL Standard")) are resolved
to full URLs using a base URL. RFC 3986, section 3, defines the
normative algorithm for this process. For CSS style sheets, the base URL
is that of the style sheet itself, not that of the styled source
document. Style sheets embedded within a document have the base URL
associated with their container.

 For HTML documents, the [base URL is
mutable](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#dynamic-changes-to-base-urls).

When a [\<url\>](#url-value) appears in the computed value of a property, it is
[resolved to an absolute
URL](#resolve-a-style-resource-url). The computed value of a URL that the
[UA](https://drafts.csswg.org/css-2023/#user-agent) cannot resolve to an absolute URL is the specified
value.

For example, suppose the following
rule:

``` highlight
body { background: url("tile.png") }
```

is located in a style sheet designated by the URL:

``` highlight
http://www.example.org/style/basic.css
```

The background of the source document's `<body>` will be
tiled with whatever image is described by the resource designated by the
URL:

``` highlight
http://www.example.org/style/tile.png
```

The same image will be used regardless of the URL of the source document
containing the `<body>`.

##### 4.5.1.1. Fragment URLs

To enable element ID references to work in CSS regardless of base URL
changes or shadow DOM, [\<url\>](#url-value)s have special behavior when they contain
only a fragment.

If a [\<url\>](#url-value)'s value starts with a U+0023 NUMBER SIGN
(`#`) character, then the URL additionally has its [local
url flag] set, and is a [tree-scoped
reference](https://drafts.csswg.org/css-shadow-1/#css-tree-scoped-reference) for the URL's
[fragment](https://url.spec.whatwg.org/#concept-url-fragment).

When matching a [\<url\>](#url-value) with the [local url
flag](#url-local-url-flag)
set:

- if the URL's fragment is an element ID reference (rather than, say, a
 media fragment), resolve it as a [tree-scoped
 reference](https://drafts.csswg.org/css-shadow-1/#css-tree-scoped-reference) with the tree's IDs as the associated [tree-scoped
 names](https://drafts.csswg.org/css-shadow-1/#css-tree-scoped-name): specifically, resolve to the first element in [tree
 order](https://dom.spec.whatwg.org/#concept-tree-order) among the associated [node
 tree](https://dom.spec.whatwg.org/#concept-node-tree)'s descendants with the URL's
 [fragment](https://url.spec.whatwg.org/#concept-url-fragment) as its ID. (And, as usual for [tree-scoped
 references], continuing up to the
 host's tree if needed.)

 If no such element is found, the URL fails to resolve.

- otherwise, resolve the fragment against the current document.

Possibly reference [find a potential
indicated
element](https://html.spec.whatwg.org/multipage/browsing-the-web.html#find-a-potential-indicated-element), but that is defined specifically for
[`Document`](https://dom.spec.whatwg.org/#document)s, not
[`ShadowRoot`](https://dom.spec.whatwg.org/#shadowroot)s.

 This means that such fragments will resolve against the
contents of the current document (or whichever [node
tree](https://dom.spec.whatwg.org/#concept-node-tree) the stylesheet lives in, if shadow DOM is involved)
regardless of how such relative URLs would resolve elsewhere (ignoring,
for example,
[`base`](https://html.spec.whatwg.org/multipage/semantics.html#the-base-element) elements changing the base URL, or relative URLs in
linked stylesheets resolving against the stylesheet's URL).

In the following example,
`#anchor` will resolve against
`http://example.com/` whereas `#image` will
resolve against the elements in the HTML document itself:

``` highlight
<!DOCTYPE html>
<base href="http://example.com/">
...
<a href="#anchor" style="background-image: url(#image)">link</a>
```

[serializing](https://www.w3.org/TR/cssom-1/#serializing-css-values) a
[url()](#funcdef-url) with
the [local url flag](#url-local-url-flag) set, it must serialize as just the fragment.

#### 4.5.2. Empty URLs

If the value of the [\<url\>](#url-value) is the empty string (like
[url(\"\")] or [url()](#funcdef-url)), the url must resolve to an invalid resource
(similar to what the url [about:invalid] does).

Its computed value is [url(\"\")] or [src(\"\")], whichever
was specified, and it must serialize as such.

Tests

- [empty.html](https://wpt.fyi/results/css/css-values/urls/empty.html "css/css-values/urls/empty.html")
 [[(live
 test)]](http://wpt.live/css/css-values/urls/empty.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/urls/empty.html)

 This matches the behavior of empty urls for embedded
resources elsewhere in the web platform, and avoids excess traffic
re-requesting the stylesheet or host document due to editing mistakes
leaving the [url()](#funcdef-url) value empty, which are almost certain to be invalid
resources for whatever the [url()] shows up
in. Linking on the web platform *does* allow empty urls, so if/when CSS
gains some functionality to control hyperlinks, this restriction can be
relaxed in those contexts.

#### 4.5.3. URL Modifiers

[\<url\>](#url-value)s support specifying additional
[\<url-modifier\>]s, which change the meaning or the
interpretation of the URL somehow. A
[\<url-modifier\>](#typedef-url-modifier) is either an
[\<ident\>](#typedef-ident) or a [functional
notation](#functional-notation).

This specification does not define any
[\<url-modifier\>](#typedef-url-modifier)s, but other specs may do so.

 A [\<url\>](#url-value) that is either unquoted or not wrapped in
[url()](#funcdef-url)
notation cannot accept any
[\<url-modifier\>](#typedef-url-modifier)s.

#### 4.5.4. URL Processing Model

To compute the [style resource base URL] for a [CSS
rule](https://drafts.csswg.org/cssom-1/#css-rule) or a [CSS declaration
block](https://drafts.csswg.org/cssom-1/#css-declaration-block) `cssRuleOrDeclaration`:

1. Let `sheet` be null.

2. If `cssRuleOrDeclaration` is a [CSS declaration
 block](https://drafts.csswg.org/cssom-1/#css-declaration-block) whose [parent CSS
 rule](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-parent-css-rule) is not null, set `cssRuleOrDeclaration`
 to `cssRuleOrDeclaration`'s [parent CSS
 rule].

3. If `cssRuleOrDeclaration` is a [CSS
 rule](https://drafts.csswg.org/cssom-1/#css-rule), set `sheet` to
 `cssRuleOrDeclaration`'s
 [`parent style sheet`](https://drafts.csswg.org/cssom-1/#dom-cssrule-parentstylesheet).

4. If `sheet` is not null:

 1. If `sheet`'s [stylesheet base
 URL](https://drafts.csswg.org/cssom-1/#concept-css-style-sheet-stylesheet-base-url) is not null, return `sheet`'s
 [stylesheet base
 URL].

 2. If `sheet`'s
 [location](https://drafts.csswg.org/cssom-1/#concept-css-style-sheet-location) is not null, return `sheet`'s
 [location].

5. Return `cssRuleOrDeclaration`'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object)'s [API base
 URL](https://html.spec.whatwg.org/multipage/webappapis.html#api-base-url).

To [resolve a style resource URL] from a
[url](https://url.spec.whatwg.org/#concept-url) or [\<url\>](#url-value) `urlValue`, and a [CSS
rule](https://drafts.csswg.org/cssom-1/#css-rule) or a [CSS declaration
block](https://drafts.csswg.org/cssom-1/#css-declaration-block) `cssRuleOrDeclaration`:

1. Let `base` be the [style resource base
 URL](#style-resource-base-url) given `cssRuleOrDeclaration`.

2. Return the result of the [URL
 parser](https://url.spec.whatwg.org/#concept-url-parser) steps with `urlValue`'s
 [url](https://url.spec.whatwg.org/#concept-url) and `base`.

To [fetch a style resource] from a
[url](https://url.spec.whatwg.org/#concept-url) or [\<url\>](#url-value) `urlValue`, given an [CSS
rule](https://drafts.csswg.org/cssom-1/#css-rule) or a [css declaration
block](https://drafts.csswg.org/cssom-1/#css-declaration-block) `cssRuleOrDeclaration`, a string
`destination` matching a
[`RequestDestination`](https://fetch.spec.whatwg.org/#requestdestination), a \"no-cors\" or \"cors\" `corsMode`, and
an algorithm `processResponse` accepting a
[response](https://fetch.spec.whatwg.org/#concept-response) and a null, failure or byte stream:

1. Let `parsedUrl` be the result of
 [resolving](#resolve-a-style-resource-url) `urlValue` given
 `cssRuleOrDeclaration`. If that failed, return.

2. Let `settingsObject` be
 `cssRuleOrDeclaration`'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object).

3. Let `req` be a new
 [request](https://fetch.spec.whatwg.org/#concept-request) whose
 [url](https://fetch.spec.whatwg.org/#concept-request-url) is `parsedUrl`, whose
 [destination](https://fetch.spec.whatwg.org/#concept-request-destination) is `destination`,
 [mode](https://fetch.spec.whatwg.org/#concept-request-mode) is `corsMode`,
 [origin](https://fetch.spec.whatwg.org/#concept-request-origin) is `settingsObject`'s
 [origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-origin), [credentials
 mode](https://fetch.spec.whatwg.org/#concept-request-credentials-mode) is \"same-origin\", [use-url-credentials
 flag](https://fetch.spec.whatwg.org/#concept-request-use-url-credentials-flag) is set,
 [client](https://fetch.spec.whatwg.org/#concept-request-client) is `settingsObject`, and whose
 [referrer](https://fetch.spec.whatwg.org/#concept-request-referrer) is \"client\".

4. If `corsMode` is \"no-cors\", set `req`'s
 [credentials
 mode](https://fetch.spec.whatwg.org/#concept-request-credentials-mode) to \"include\".

5. Apply any [URL request modifier steps] that apply to this
 request.

 This specification does not define any URL request
 modification steps, but other specs may do so.

6. If `req`'s
 [mode](https://fetch.spec.whatwg.org/#concept-request-mode) is \"cors\", and `sheet` is not null,
 then set `req`'s
 [referrer](https://fetch.spec.whatwg.org/#concept-request-referrer) to the [style resource base
 URL](#style-resource-base-url) given `cssRuleOrDeclaration`.
 [\[CSSOM\]](#biblio-cssom "CSS Object Model (CSSOM)")

7. If `sheet`'s [origin-clean
 flag](https://drafts.csswg.org/cssom-1/#concept-css-style-sheet-origin-clean-flag) is set, set `req`'s [initiator
 type](https://fetch.spec.whatwg.org/#request-initiator-type) to \"css\".
 [\[CSSOM\]](#biblio-cssom "CSS Object Model (CSSOM)")

8. [Fetch](https://fetch.spec.whatwg.org/#concept-fetch) `req`, with
 [processResponseConsumeBody](https://fetch.spec.whatwg.org/#process-response-end-of-body) set to `processResponse`.

When interpreting
[URLs](https://url.spec.whatwg.org/#concept-url) expressed in CSS, the [URL
parser's](https://url.spec.whatwg.org/#concept-url-parser) `encoding` argument must be omitted (i.e.
use the default, UTF-8), regardless of the stylesheet encoding.

 In other words, a URL written in CSS will always
[percent-encode](https://url.spec.whatwg.org/#string-percent-encode-after-encoding) non-ASCII codepoints using UTF-8 in the
[URL](https://url.spec.whatwg.org/#concept-url) object (and thus whenever using the
[URL] value for e.g. network requests),
regardless of the stylesheet's own encoding. Note that this occurs
[after decoding the
stylesheet](https://drafts.csswg.org/css-syntax-3/#input-byte-stream)
into Unicode [code
points](https://infra.spec.whatwg.org/#code-point).

## 5. Numeric Data Types

Numeric data types are used to represent quantities, indexes, positions,
and other such values. Although many syntactic variations can exist in
expressing the quantity (numeric aspect) in a given numeric value, the
[specified](https://drafts.csswg.org/css-cascade-5/#specified-value) and [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) do not distinguish these variations: they represent the
value's abstract quantity, not its syntactic representation.

The [numeric data types] include
[\<integer\>](#integer-value), [\<number\>](#number-value),
[\<percentage\>](#percentage-value), and various
[dimensions](#dimension) including
[\<length\>](#length-value), [\<angle\>](#angle-value),
[\<time\>](#time-value),
[\<frequency\>](#frequency-value), and
[\<resolution\>](#resolution-value).

 While general-purpose
[dimensions](#dimension) are
defined here, some other modules define additional data types (e.g.
[\[css-grid-1\]](#biblio-css-grid-1 "CSS Grid Layout Module Level 1")
introduces
[fr](https://drafts.csswg.org/css-grid-2/#valdef-flex-fr) units) whose usage is more localized.

The precision and supported range of numeric values in CSS is
[implementation-defined](https://infra.spec.whatwg.org/#implementation-defined), and can vary based on the property or other context a
value is used in. However, within the CSS specifications, infinite
precision and range is assumed. When a value cannot be explicitly
supported due to range/precision limitations, it must be converted to
the closest value supported by the implementation, but how the
implementation defines \"closest\" is
[implementation-defined] as well.

If an [\<angle\>](#angle-value) must be converted due to exceeding the
implementation-defined range of supported values, it must be clamped to
the nearest supported multiple of [360deg].

### 5.1. Range Restrictions and Range Definition Notation

Properties can restrict numeric values to some range. If the value is
outside the allowed range, then unless otherwise specified, the
declaration is invalid and must be
[ignored](https://www.w3.org/TR/CSS2/conform.html#ignore). Range
restrictions can be annotated in the numeric type notation using [CSS
bracketed range notation]---​`[``min``,``max``]`---​within
the angle brackets, after the identifying keyword, indicating a closed
range between (and including) `min` and `max`. For
example, [\<integer \[0,10\]\>](#integer-value) indicates an integer between
[0] and [10], inclusive, while [\<angle
\[0,180deg\]\>](#angle-value) indicates an angle between [0deg] and
[180deg] (expressed in any unit).

 CSS values generally do not allow open ranges; thus
only square-bracket notation is used.

CSS theoretically supports infinite precision and infinite ranges for
all value types; however in reality implementations have finite
capacity.
[UAs](https://drafts.csswg.org/css-2023/#user-agent) should support reasonably useful ranges and precisions.
Range extremes that are ideally unlimited are indicated using ∞ or −∞ as
appropriate. For example, [\<length
\[0,∞\]\>](#length-value) indicates a non-negative length.

If no range is indicated, either by using the [bracketed range
notation](#css-bracketed-range-notation) or in the property description, then
`[−∞,∞]` is assumed.

Values of −∞ or ∞ must be written without units, even if the value type
uses units. Values of [0] *can* be written without units, even if
the value type doesn't allow "unitless zeroes" (such as
[\<time\>](#time-value)).

 At the time of writing, the [bracketed range
notation](#css-bracketed-range-notation) is new; thus in most CSS specifications any range
limitations are described only in prose. (For example, "Negative values
are not allowed" or "Negative values are invalid" indicate a
`[0,∞]` range.) This does not make them any less binding.

### 5.2. Integers: the [\<integer\> type]
Integer values are denoted by [\<integer\>].

When written literally, an [integer] is one or more decimal digits [0]
through [9] and corresponds to a subset of the
[\<number-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-number-token) production in the CSS Syntax Module
[\[CSS-SYNTAX-3\]](#biblio-css-syntax-3 "CSS Syntax Module Level 3").
The first digit of an integer may be immediately preceded by [-]
or [+] to indicate the integer's sign.

Tests

- [multicol-count-non-integer-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-count-non-integer-001.xht "css/css-multicol/multicol-count-non-integer-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-count-non-integer-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-count-non-integer-001.xht)
- [multicol-count-non-integer-002.xht](https://wpt.fyi/results/css/css-multicol/multicol-count-non-integer-002.xht "css/css-multicol/multicol-count-non-integer-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-count-non-integer-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-count-non-integer-002.xht)
- [multicol-count-non-integer-003.xht](https://wpt.fyi/results/css/css-multicol/multicol-count-non-integer-003.xht "css/css-multicol/multicol-count-non-integer-003.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-count-non-integer-003.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-count-non-integer-003.xht)
- [numbers-units-001.xht](https://wpt.fyi/results/css/CSS2/values/numbers-units-001.xht "css/CSS2/values/numbers-units-001.xht")
 [[(live
 test)]](http://wpt.live/css/CSS2/values/numbers-units-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/CSS2/values/numbers-units-001.xht)
- [numbers-units-004.xht](https://wpt.fyi/results/css/CSS2/values/numbers-units-004.xht "css/CSS2/values/numbers-units-004.xht")
 [[(live
 test)]](http://wpt.live/css/CSS2/values/numbers-units-004.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/CSS2/values/numbers-units-004.xht)

Unless otherwise specified, in the CSS specifications [rounding to the
nearest integer] requires rounding in the direction of
+∞ when the fractional portion is exactly 0.5. (For example, [1.5]
rounds to [2], while [-1.5] rounds to [-1].)

#### 5.2.1. Computation and Combination of [\<integer\>]
Unless otherwise specified, the [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) of a specified
[\<integer\>](#integer-value) is the specified abstract integer.

[Interpolation](#interpolation)
of [\<integer\>](#integer-value) is defined as `V`~result~ =
round((1 - `p`) × `V`~`A`~ +
`p` × `V`~`B`~); that is, interpolation
happens in the real number space as for
[\<number\>](#number-value)s, and the result is converted to an
[\<integer\>] by [rounding to the
nearest
integer](#css-round-to-the-nearest-integer).

[Addition](#addition) of
[\<integer\>](#integer-value) is defined as `V`~`result`~ =
`V`~`A`~ + `V`~`B`~

Tests

- [calc-positive-fraction-001.html](https://wpt.fyi/results/css/css-values/calc-positive-fraction-001.html "css/css-values/calc-positive-fraction-001.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-positive-fraction-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-positive-fraction-001.html)
- [rgba-011.html](https://wpt.fyi/results/css/css-values/rgba-011.html "css/css-values/rgba-011.html")
 [[(live
 test)]](http://wpt.live/css/css-values/rgba-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/rgba-011.html)

### 5.3. Real Numbers: the [\<number\> type]
Number values are denoted by [\<number\>], and represent real numbers,
possibly with a fractional component.

Tests

- [animation-iteration-count-calc.html](https://wpt.fyi/results/css/css-animations/animation-iteration-count-calc.html "css/css-animations/animation-iteration-count-calc.html")
 [[(live
 test)]](http://wpt.live/css/css-animations/animation-iteration-count-calc.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-animations/animation-iteration-count-calc.html)
- [numbers-units-002.xht (visual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/CSS2/values/numbers-units-002.xht)
- [numbers-units-003.xht](https://wpt.fyi/results/css/CSS2/values/numbers-units-003.xht "css/CSS2/values/numbers-units-003.xht")
 [[(live
 test)]](http://wpt.live/css/CSS2/values/numbers-units-003.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/CSS2/values/numbers-units-003.xht)

When written literally, a [number] is either an
[integer](#integer), or zero or more
decimal digits followed by a dot (.) followed by one or more decimal
digits; optionally, it can be concluded by the letter "e" or "E"
followed by an integer indicating the base-ten exponent in [scientific
notation](https://en.wikipedia.org/wiki/Scientific_notation). It
corresponds to the
[\<number-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-number-token) production in the [CSS Syntax
Module](https://www.w3.org/TR/css-syntax/)
[\[CSS-SYNTAX-3\]](#biblio-css-syntax-3 "CSS Syntax Module Level 3").
As with integers, the first character of a number may be immediately
preceded by [-] or [+] to indicate the number's sign.

The value [\<zero\>] represents a literal [number](#number) with the value 0. Expressions that merely evaluate to a
[\<number\>](#number-value) with the value 0 (for example, [calc(0)]) do not
match [\<zero\>](#zero-value); only literal
[\<number-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-number-token)s do.

#### 5.3.1. Computation and Combination of [\<number\>]
Unless otherwise specified, the [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) of a specified
[\<number\>](#number-value) is the specified abstract number.

[Interpolation](#interpolation)
of [\<number\>](#number-value) is defined as `V`~result~ = (1 -
`p`) × `V`~`A`~ + `p` ×
`V`~`B`~

[Addition](#addition) of
[\<number\>](#number-value) is defined as `V`~`result`~ =
`V`~`A`~ + `V`~`B`~

### 5.4. Numbers with Units: [dimension values]
The general term [dimension] refers to a number with a unit attached to it; and is denoted
by [\<dimension\>].

When written literally, a [dimension](#dimension) is a [number](#number) immediately followed by a unit identifier, which is an
[identifier](#css-css-identifier). It corresponds to the
[\<dimension-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-dimension-token) production in the [CSS Syntax
Module](https://www.w3.org/TR/css-syntax/)
[\[CSS-SYNTAX-3\]](#biblio-css-syntax-3 "CSS Syntax Module Level 3").
Like keywords, unit identifiers are [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive).

Tests

- [angle-units-003.html](https://wpt.fyi/results/css/css-values/angle-units-003.html "css/css-values/angle-units-003.html")
 [[(live
 test)]](http://wpt.live/css/css-values/angle-units-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/angle-units-003.html)

CSS uses [\<dimension\>](#typedef-dimension)s to specify distances
([\<length\>](#length-value)), durations
([\<time\>](#time-value)), frequencies
([\<frequency\>](#frequency-value)), resolutions
([\<resolution\>](#resolution-value)), and other quantities.

#### 5.4.1. Compatible Units

When
[serializing](https://www.w3.org/TR/cssom-1/#serializing-css-values)
[computed
values](https://drafts.csswg.org/css-cascade-5/#computed-value)
[\[CSSOM\]](#biblio-cssom "CSS Object Model (CSSOM)"),
[compatible units] (those related by a static
multiplicative factor, like the 96:1 factor between
[px](#px) and [in](#in), or the computed
[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size) factor between
[em](#em) and [px]) are converted into a single [canonical unit]. Each group
of compatible units defines which among them is the [canonical
unit](#canonical-unit) that
will be used for serialization.

When serializing [resolved
values](https://www.w3.org/TR/cssom-1/#resolved-values) that are [used
values](https://drafts.csswg.org/css-cascade-5/#used-value), all value types (percentages, numbers, keywords, etc.)
that represent lengths are considered
[compatible](#compatible-units) with lengths. Likewise any future API that returns
[used values] must consider any values that
represent distances/durations/frequencies/etc. as
[compatible] with the relevant class of
[dimensions](#dimension), and
canonicalize accordingly.

Tests

- [calc-serialization-002.html](https://wpt.fyi/results/css/css-values/calc-serialization-002.html "css/css-values/calc-serialization-002.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-serialization-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-serialization-002.html)

#### 5.4.2. Combination of Dimensions

[Interpolation](#interpolation)
of [compatible](#compatible-units) [dimensions](#dimension) (for example, two
[\<length\>](#length-value) values) is defined as `V`~result~ = (1 -
`p`) × `V`~`A`~ + `p` ×
`V`~`B`~

[Addition](#addition) of
[compatible](#compatible-units) [dimensions](#dimension) is defined as `V`~`result`~ =
`V`~`A`~ + `V`~`B`~

### 5.5. Percentages: the [\<percentage\> type]
Percentage values are denoted by [\<percentage\>], and indicates a value that
is some fraction of another reference value.

When written literally, a [percentage] consists of a
[number](#number) immediately followed
by a percent sign [%]. It corresponds to the
[\<percentage-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-percentage-token) production in the [CSS Syntax
Module](https://www.w3.org/TR/css-syntax/)
[\[CSS-SYNTAX-3\]](#biblio-css-syntax-3 "CSS Syntax Module Level 3").

Percentage values are always relative to another quantity, for example a
length. Each property that allows percentages also defines the quantity
to which the percentage refers. This quantity can be a value of another
property for the same element, the value of a property for an ancestor
element, a measurement of the formatting context (e.g., the width of a
[containing
block](https://drafts.csswg.org/css-display-4/#containing-block)), or something else.

Tests

- [numbers-units-016.xht](https://wpt.fyi/results/css/CSS2/values/numbers-units-016.xht "css/CSS2/values/numbers-units-016.xht")
 [[(live
 test)]](http://wpt.live/css/CSS2/values/numbers-units-016.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/CSS2/values/numbers-units-016.xht)
- [numbers-units-017.xht](https://wpt.fyi/results/css/CSS2/values/numbers-units-017.xht "css/CSS2/values/numbers-units-017.xht")
 [[(live
 test)]](http://wpt.live/css/CSS2/values/numbers-units-017.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/CSS2/values/numbers-units-017.xht)

#### 5.5.1. Computation and Combination of [\<percentage\>]
Unless otherwise specified (such as in
[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size), which computes its
[\<percentage\>](#percentage-value) values to
[\<length\>](#length-value)), the [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) of a percentage is the specified percentage.

[Interpolation](#interpolation)
of [\<percentage\>](#percentage-value) is defined as `V`~result~ =
(1 - `p`) × `V`~`A`~ + `p` ×
`V`~`B`~

[Addition](#addition) of
[\<percentage\>](#percentage-value) is defined as
`V`~`result`~ = `V`~`A`~ +
`V`~`B`~

### 5.6. Mixing Percentages and Dimensions

In cases where a
[\<percentage\>](#percentage-value) can represent the same quantity as a
[dimension](#dimension) in the same
[component
value](https://drafts.csswg.org/css-syntax-3/#component-value) position, and can therefore be combined with them in a
[calc()](#funcdef-calc)
expression, the following convenience notations may be used in the
property grammar:

[\<length-percentage\>]

: Equivalent to `[ `[`<length>`](#length-value)` `[`|`](#comb-one)` `[`<percentage>`](#percentage-value)` ]`, where the
 [\<percentage\>](#percentage-value) will resolve to a
 [\<length\>](#length-value).

[\<frequency-percentage\>]

: Equivalent to `[ `[`<frequency>`](#frequency-value)` `[`|`](#comb-one)` `[`<percentage>`](#percentage-value)` ]`, where the
 [\<percentage\>](#percentage-value) will resolve to a
 [\<frequency\>](#frequency-value).

[\<angle-percentage\>]

: Equivalent to `[ `[`<angle>`](#angle-value)` `[`|`](#comb-one)` `[`<percentage>`](#percentage-value)` ]`, where the
 [\<percentage\>](#percentage-value) will resolve to an
 [\<angle\>](#angle-value).

[\<time-percentage\>]

: Equivalent to `[ `[`<time>`](#time-value)` `[`|`](#comb-one)` `[`<percentage>`](#percentage-value)` ]`, where the
 [\<percentage\>](#percentage-value) will resolve to a
 [\<time\>](#time-value).

For example, the
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width) property can accept a
[\<length\>](#length-value) or a
[\<percentage\>](#percentage-value), both representing a measure of distance.
This means that [width: calc(500px + 50%);] is allowed---​both values are converted to absolute lengths and
added. If the containing block is [1000px] wide, then [width:
50%;] is equivalent to [width:
500px], and [width: calc(50% +
500px)] thus ends up equivalent to [width:
calc(500px + 500px)] or [width:
1000px].

On the other hand, the second and third arguments of the
[hsl()](https://drafts.csswg.org/css-color-4/#funcdef-hsl) function can only be expressed as
[\<percentage\>](#percentage-value)s. Although
[calc()](#funcdef-calc)
productions are allowed in their place, they can only combine
percentages with themselves, as in [calc(10% + 20%)].

 Specifications should never alternate
[\<percentage\>](#percentage-value) in place of a dimension in a grammar
unless they are
[compatible](#compatible-units).

 More \<`type`-percentage\> productions can
be added in the future as needed. A \<number-percentage\> will never be
added, as [\<number\>](#number-value) and
[\<percentage\>](#percentage-value) can't be combined in
[calc()](#funcdef-calc).

#### 5.6.1. Computation and Combination of Percentage and Dimension Mixes

The [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) of a percentage-dimension mix is defined as

- a computed dimension if the percentage component is zero or is defined
 specifically to compute to a dimension value

- a computed percentage if the dimension component is zero

- a [computed calc() expression](#calc-computed-value) otherwise

[Interpolation](#interpolation)
of percentage-dimension value combinations (e.g.
[\<length-percentage\>](#typedef-length-percentage),
[\<frequency-percentage\>](#typedef-frequency-percentage),
[\<angle-percentage\>](#typedef-angle-percentage),
[\<time-percentage\>](#typedef-time-percentage) or equivalent notations) is defined
as

- equivalent to [interpolation](#interpolation) of
 [\<length\>](#length-value) if both `V`~`A`~ and
 `V`~`B`~ are pure
 [\<length\>] values
- equivalent to [interpolation](#interpolation) of
 [\<percentage\>](#percentage-value) if both `V`~`A`~
 and `V`~`B`~ are pure
 [\<percentage\>] values
- equivalent to converting both values into a
 [calc()](#funcdef-calc)
 expression representing the sum of the dimension type and a percentage
 (each possibly zero) and
 [interpolating](#interpolation) each component individually (as a
 [\<length\>](#length-value)/[\<frequency\>](#frequency-value)/[\<angle\>](#angle-value)/[\<time\>](#time-value) and as a
 [\<percentage\>](#percentage-value), respectively)

[Addition](#addition) of
[\<percentage\>](#percentage-value) is defined the same as
[interpolation](#interpolation) except by [adding] each component
rather than [interpolating] it.

### 5.7. Ratios: the [\<ratio\> type]
Ratio values are denoted by [\<ratio\>], and represent the ratio of two
numeric values. It most often represents an aspect ratio, relating a
width (first) to a height (second).

When written literally, a [ratio] has the syntax:

```
<ratio> = <number [0,∞]> [ / <number [0,∞]> ]?
```

The second [\<number\>](#number-value) is optional, defaulting to [1].
However, [\<ratio\>](#ratio-value) is always serialized with both components.

The computed value of a [\<ratio\>](#ratio-value) is the pair of numbers provided.

If either number in the [\<ratio\>](#ratio-value) is 0 or infinite, it represents a
[degenerate ratio] (and, generally, won't do anything).

If two [\<ratio\>](#ratio-value)s need to be compared, divide the first number by the
second, and compare the results. For example, [3/2] is less than
[2/1], because it resolves to 1.5 while the second resolves to 2.
(In other words, "tall" aspect ratios are less than "wide" aspect
ratios.)

#### 5.7.1. Combination of [\<ratio\>]
The interpolation of a [\<ratio\>](#ratio-value) is defined by converting each
[\<ratio\>] to a number by dividing
the first value by the second (so a ratio of [3 / 2] would become
[1.5]), taking the logarithm of that result (so the [1.5]
would become approximately [0.176]), then interpolating those
values. The result during the interpolation is converted back to a
[\<ratio\>] by inverting the
logarithm, then interpreting the result as a
[\<ratio\>] with the result as the
first value and [1] as the second value.

If either [\<ratio\>](#ratio-value) is
[degenerate](#degenerate-ratio), the values cannot be interpolated.

For example, halfway through a linear
interpolation from [5 / 1] to [3 / 2], the result is
approximately the ratio [2.73 / 1] (roughly [11 / 4],
slightly taller than a [3 / 1] ratio):

``` highlight
start = log(5); // ≈ 0.69897
end = log(1.5); // ≈ 0.17609
interp = 0.69897*.5 + 0.17609*.5; // ≈ 0.43753
final = 10^interp; // ≈ 2.73
```

 Interpolating over the logarithm of the ratio means the
results are scale-independent ([5 / 1] to [300 / 200] would
give the same results as above), that they're symmetrical over \"wide\"
and \"tall\" variants (interpolating from [1 / 5] to [2 / 3]
would give a ratio approximately equal to [1 / 2.73] at the
halfway point), and that they're symmetrical over whether the width is
fixed and the height is based on the ratio or vice versa. These
properties are not shared by many other possible interpolation
strategies.

 Due to the properties of logarithms, any log can be
used; the example here uses base-10 log, but if, say, the natural log
and e was used, the intermediate results would be different but the
final result would be the same.

Addition of [\<ratio\>](#ratio-value)s is not possible.

## 6. Distance Units: the [\<length\> type]
Lengths refer to distance measurements and are denoted by
[\<length\>] in the property definitions. A length is a
[dimension](#dimension).

For zero lengths the unit identifier is optional (i.e. can be
syntactically represented as the
[\<number\>](#number-value) [0]). However, if a [0] could be parsed as
either a [\<number\>] or a
[\<length\>](#length-value) in a property (such as
[line-height](https://drafts.csswg.org/css2/#propdef-line-height)), it must parse as a
[\<number\>].

Properties may restrict the length value to some range. If the value is
outside the allowed range, the declaration is invalid and must be
[ignored](https://www.w3.org/TR/CSS2/conform.html#ignore).

Tests

- [min-width-001.xht](https://wpt.fyi/results/css/mediaqueries/min-width-001.xht "css/mediaqueries/min-width-001.xht")
 [[(live
 test)]](http://wpt.live/css/mediaqueries/min-width-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/mediaqueries/min-width-001.xht)
- [numbers-units-005.xht](https://wpt.fyi/results/css/CSS2/values/numbers-units-005.xht "css/CSS2/values/numbers-units-005.xht")
 [[(live
 test)]](http://wpt.live/css/CSS2/values/numbers-units-005.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/CSS2/values/numbers-units-005.xht)
- [numbers-units-006.xht](https://wpt.fyi/results/css/CSS2/values/numbers-units-006.xht "css/CSS2/values/numbers-units-006.xht")
 [[(live
 test)]](http://wpt.live/css/CSS2/values/numbers-units-006.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/CSS2/values/numbers-units-006.xht)

While some properties allow negative length values, this may complicate
the formatting and there may be implementation-specific limits. If a
negative length value is allowed but cannot be supported, it must be
converted to the nearest value that can be supported.

In cases where the
[used](https://drafts.csswg.org/css-cascade-5/#used-value) length cannot be supported, user agents must
approximate it in the
[actual](https://drafts.csswg.org/css-cascade-5/#actual-value) value.

There are two types of length units:
[relative](#relative-length)
and [absolute](#absolute-length). The [specified
value](https://drafts.csswg.org/css-cascade-5/#specified-value) of a length ([specified length]) is represented by its quantity
and its unit. The [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) of a length ([computed length]) is the [specified
length](#specified-length)
resolved to an [absolute length], and its
unit is not distinguished: it can be represented by any [absolute length
unit] (but will be serialized using its
[canonical unit](#canonical-unit), [px](#px)).

Tests

- [calc-unit-analysis.html](https://wpt.fyi/results/css/css-values/calc-unit-analysis.html "css/css-values/calc-unit-analysis.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-unit-analysis.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-unit-analysis.html)
- [shape-outside-circle-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-circle-002.html "css/css-shapes/shape-outside/values/shape-outside-circle-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-circle-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-circle-002.html)
- [shape-outside-circle-004.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-circle-004.html "css/css-shapes/shape-outside/values/shape-outside-circle-004.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-circle-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-circle-004.html)
- [shape-outside-ellipse-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-ellipse-002.html "css/css-shapes/shape-outside/values/shape-outside-ellipse-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-ellipse-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-ellipse-002.html)
- [shape-outside-ellipse-004.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-ellipse-004.html "css/css-shapes/shape-outside/values/shape-outside-ellipse-004.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-ellipse-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-ellipse-004.html)
- [shape-outside-inset-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-inset-003.html "css/css-shapes/shape-outside/values/shape-outside-inset-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-inset-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-inset-003.html)
- [shape-outside-polygon-004.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-polygon-004.html "css/css-shapes/shape-outside/values/shape-outside-polygon-004.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-polygon-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-polygon-004.html)

While the exact supported precision of numeric values, and how they are
rounded to match that precision, is generally
[implementation-defined](https://infra.spec.whatwg.org/#implementation-defined), [\<length\>](#length-value)s in
[border-width](https://drafts.csswg.org/css-borders-4/#propdef-border-width) and a few other properties are
rounded in a specific fashion to ensure reasonable visual display. (This
algorithm is called by individual properties explicitly.)

To [snap a length as a line width]
given a [\<length\>](#length-value) `len`:

1. If `len` is an integer number of [device
 pixels](#device-pixel), do
 nothing.

2. If the absolute value of `len` is greater than zero, but
 less than 1 [device pixel](#device-pixel), round it away from zero to 1 or -1 [device
 pixel].

3. If the absolute value of `len` is greater than 1 [device
 pixel](#device-pixel), round
 it towards zero to the nearest integer number of [device
 pixels].

### 6.1. Relative Lengths

[Relative length units]
specify a length relative to another length. Style sheets that use
relative units can more easily scale from one output environment to
another.

The relative units are:

Informative Summary of Relative Units

unit

relative to

[em](#em)

font size of the element

[ex](#ex)

x-height of the element's font

[cap](#cap)

cap height (the nominal height of capital letters) of the element's font

[ch](#ch)

typical [character
advance](#length-advance-measure) of a narrow glyph in the element's font, as represented
by the "0" (ZERO, U+0030) glyph

[ic](#ic)

typical [character
advance](#length-advance-measure) of a fullwidth glyph in the element's font, as
represented by the "水" (CJK water ideograph, U+6C34) glyph

[rem](#rem)

font size of the root element

[lh](#lh)

line height of the element

[rlh](#rlh)

line height of the root element

[vw](#vw)

1% of viewport's width

[vh](#vh)

1% of viewport's height

[vi](#vi)

1% of viewport's size in the root element's [inline
axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis)

[vb](#vb)

1% of viewport's size in the root element's [block
axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis)

[vmin](#vmin)

1% of viewport's smaller dimension

[vmax](#vmax)

1% of viewport's larger dimension

Child elements do not inherit the relative values as specified for their
parent; they inherit the [computed
values](https://drafts.csswg.org/css-cascade-5/#computed-value).

#### 6.1.1. Font-relative Lengths: the [em, [rem](#rem), [ex](#ex), [rex](#rex), [cap](#cap), [rcap](#rcap), [ch](#ch), [rch](#rch), [ic](#ic), [ric](#ric), [lh](#lh), [rlh](#rlh) units]
The [font-relative lengths] refer to the font metrics either of the
element on which they are used (for the [local font-relative
lengths]) or of the root element (for the [root font-relative
lengths]).

![Common typographic
metrics](images/Typography_Line_Terms.svg){a
height="97" width="361"}

[em]
: Equal to the computed value of the
 [font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size) property of the element on
 which it is used.
 :::
 (#example-83bc8a19) The rule:
 ``` highlight
 h1 { line-height: 1.2em }
 ```

 means that the line height of `h1` elements will be 20%
 greater than the font size of `h1` element. On the other
 hand:

 ``` highlight
 h1 { font-size: 1.2em }
 ```

 means that the font size of `h1` elements will be 20%
 greater than the computed font size inherited by `h1`
 elements.
 :::

[rem]
: Equal to the computed value of the [em](#em) unit on the root element.
 Tests
 - [calc-rem-lang.html](https://wpt.fyi/results/css/css-values/calc-rem-lang.html "css/css-values/calc-rem-lang.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-rem-lang.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-rem-lang.html)

[ex]
: Equal to the used x-height of the [first available
 font](https://www.w3.org/TR/css3-fonts/#first-available-font)
 [\[CSS3-FONTS\]](#biblio-css3-fonts "CSS Fonts Module Level 3").
 The x-height is so called because it is often equal to the height of
 the lowercase \"x\". However, an [ex](#ex) is defined even for fonts that do not contain an
 \"x\". The x-height of a font can be found in different ways. Some
 fonts contain reliable metrics for the x-height. If reliable font
 metrics are not available,
 [UAs](https://drafts.csswg.org/css-2023/#user-agent) may determine the x-height from the height of a
 lowercase glyph. One possible heuristic is to look at how far the
 glyph for the lowercase \"o\" extends below the baseline, and
 subtract that value from the top of its bounding box. In the cases
 where it is impossible or impractical to determine the x-height, a
 value of 0.5em must be assumed.
 Tests
 - [ex-unit-001.html](https://wpt.fyi/results/css/css-values/ex-unit-001.html "css/css-values/ex-unit-001.html")
 [[(live
 test)]](http://wpt.live/css/css-values/ex-unit-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/ex-unit-001.html)
 - [ex-unit-002.html](https://wpt.fyi/results/css/css-values/ex-unit-002.html "css/css-values/ex-unit-002.html")
 [[(live
 test)]](http://wpt.live/css/css-values/ex-unit-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/ex-unit-002.html)
 - [ex-unit-003.html](https://wpt.fyi/results/css/css-values/ex-unit-003.html "css/css-values/ex-unit-003.html")
 [[(live
 test)]](http://wpt.live/css/css-values/ex-unit-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/ex-unit-003.html)
 - [numbers-units-007.xht](https://wpt.fyi/results/css/CSS2/values/numbers-units-007.xht "css/CSS2/values/numbers-units-007.xht")
 [[(live
 test)]](http://wpt.live/css/CSS2/values/numbers-units-007.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/CSS2/values/numbers-units-007.xht)
 - [numbers-units-009.xht](https://wpt.fyi/results/css/CSS2/values/numbers-units-009.xht "css/CSS2/values/numbers-units-009.xht")
 [[(live
 test)]](http://wpt.live/css/CSS2/values/numbers-units-009.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/CSS2/values/numbers-units-009.xht)
 - [numbers-units-010.xht](https://wpt.fyi/results/css/CSS2/values/numbers-units-010.xht "css/CSS2/values/numbers-units-010.xht")
 [[(live
 test)]](http://wpt.live/css/CSS2/values/numbers-units-010.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/CSS2/values/numbers-units-010.xht)
 - [numbers-units-011.xht](https://wpt.fyi/results/css/CSS2/values/numbers-units-011.xht "css/CSS2/values/numbers-units-011.xht")
 [[(live
 test)]](http://wpt.live/css/CSS2/values/numbers-units-011.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/CSS2/values/numbers-units-011.xht)
 - [numbers-units-012.xht](https://wpt.fyi/results/css/CSS2/values/numbers-units-012.xht "css/CSS2/values/numbers-units-012.xht")
 [[(live
 test)]](http://wpt.live/css/CSS2/values/numbers-units-012.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/CSS2/values/numbers-units-012.xht)
 - [numbers-units-013.xht](https://wpt.fyi/results/css/CSS2/values/numbers-units-013.xht "css/CSS2/values/numbers-units-013.xht")
 [[(live
 test)]](http://wpt.live/css/CSS2/values/numbers-units-013.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/CSS2/values/numbers-units-013.xht)
 - [numbers-units-015.xht](https://wpt.fyi/results/css/CSS2/values/numbers-units-015.xht "css/CSS2/values/numbers-units-015.xht")
 [[(live
 test)]](http://wpt.live/css/CSS2/values/numbers-units-015.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/CSS2/values/numbers-units-015.xht)
 - [numbers-units-019.xht](https://wpt.fyi/results/css/CSS2/values/numbers-units-019.xht "css/CSS2/values/numbers-units-019.xht")
 [[(live
 test)]](http://wpt.live/css/CSS2/values/numbers-units-019.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/CSS2/values/numbers-units-019.xht)
 - [units-001.xht](https://wpt.fyi/results/css/CSS2/values/units-001.xht "css/CSS2/values/units-001.xht")
 [[(live
 test)]](http://wpt.live/css/CSS2/values/units-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/CSS2/values/units-001.xht)
 - [units-002.xht](https://wpt.fyi/results/css/CSS2/values/units-002.xht "css/CSS2/values/units-002.xht")
 [[(live
 test)]](http://wpt.live/css/CSS2/values/units-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/CSS2/values/units-002.xht)
 - [units-003.xht](https://wpt.fyi/results/css/CSS2/values/units-003.xht "css/CSS2/values/units-003.xht")
 [[(live
 test)]](http://wpt.live/css/CSS2/values/units-003.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/CSS2/values/units-003.xht)
 - [units-004.xht](https://wpt.fyi/results/css/CSS2/values/units-004.xht "css/CSS2/values/units-004.xht")
 [[(live
 test)]](http://wpt.live/css/CSS2/values/units-004.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/CSS2/values/units-004.xht)
 - [units-005.xht](https://wpt.fyi/results/css/CSS2/values/units-005.xht "css/CSS2/values/units-005.xht")
 [[(live
 test)]](http://wpt.live/css/CSS2/values/units-005.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/CSS2/values/units-005.xht)
 - [calc-ch-ex-lang.html](https://wpt.fyi/results/css/css-values/calc-ch-ex-lang.html "css/css-values/calc-ch-ex-lang.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-ch-ex-lang.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-ch-ex-lang.html)

[rex]
: Equal to the value of the [ex](#ex) unit on the root element.

[cap]
: Equal to the used cap-height of the [first available
 font](https://www.w3.org/TR/css3-fonts/#first-available-font)
 [\[CSS3-FONTS\]](#biblio-css3-fonts "CSS Fonts Module Level 3").
 The cap-height is so called because it is approximately equal to the
 height of a capital Latin letter. However, a
 [cap](#cap) is defined even
 for fonts that do not contain Latin letters. The cap-height of a
 font can be found in different ways. Some fonts contain reliable
 metrics for the cap-height. If reliable font metrics are not
 available,
 [UAs](https://drafts.csswg.org/css-2023/#user-agent) may determine the cap-height from the height of an
 uppercase glyph. One possible heuristic is to look at how far the
 glyph for the uppercase "O" extends below the baseline, and subtract
 that value from the top of its bounding box. In the cases where it
 is impossible or impractical to determine the cap-height, the font's
 ascent must be used.

[rcap]
: Equal to the value of the [cap](#cap) unit on the root element.

[ch]

: Represents the typical [advance
 measure](#length-advance-measure) of European alphanumeric characters, and measured
 as the used [advance measure] of
 the "0" (ZERO, U+0030) glyph in the font used to render it. (The
 [advance measure] of a glyph is its
 advance width or height, whichever is in the inline axis of the
 element.)

 This measurement is an approximation (and in
 monospace fonts, an exact measure) of a single narrow glyph's
 [advance
 measure](#length-advance-measure), thus allowing measurements based on an expected
 glyph count.

 The advance measure of a glyph depends on
 writing-mode and text-orientation as well as font settings,
 text-transform, and any other properties that affect glyph selection
 or orientation.

 In the cases where it is impossible or impractical to determine the
 measure of the "0" glyph, it must be assumed to be 0.5em wide by 1em
 tall. Thus, the [ch](#ch) unit
 falls back to [0.5em] in the general case, and to [1em]
 when it would be typeset upright (i.e.
 [writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode) is
 [vertical-rl](https://drafts.csswg.org/css-writing-modes-4/#valdef-writing-mode-vertical-rl) or
 [vertical-lr](https://drafts.csswg.org/css-writing-modes-4/#valdef-writing-mode-vertical-lr) and
 [text-orientation](https://drafts.csswg.org/css-writing-modes-4/#propdef-text-orientation) is
 [upright](https://drafts.csswg.org/css-writing-modes-4/#valdef-text-orientation-upright)).

 Tests

 - [ch-unit-001.html](https://wpt.fyi/results/css/css-values/ch-unit-001.html "css/css-values/ch-unit-001.html")
 [[(live
 test)]](http://wpt.live/css/css-values/ch-unit-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/ch-unit-001.html)
 - [ch-unit-002.html](https://wpt.fyi/results/css/css-values/ch-unit-002.html "css/css-values/ch-unit-002.html")
 [[(live
 test)]](http://wpt.live/css/css-values/ch-unit-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/ch-unit-002.html)
 - [ch-unit-003.html](https://wpt.fyi/results/css/css-values/ch-unit-003.html "css/css-values/ch-unit-003.html")
 [[(live
 test)]](http://wpt.live/css/css-values/ch-unit-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/ch-unit-003.html)
 - [ch-unit-004.html](https://wpt.fyi/results/css/css-values/ch-unit-004.html "css/css-values/ch-unit-004.html")
 [[(live
 test)]](http://wpt.live/css/css-values/ch-unit-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/ch-unit-004.html)
 - [ch-unit-008.html](https://wpt.fyi/results/css/css-values/ch-unit-008.html "css/css-values/ch-unit-008.html")
 [[(live
 test)]](http://wpt.live/css/css-values/ch-unit-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/ch-unit-008.html)
 - [ch-unit-009.html](https://wpt.fyi/results/css/css-values/ch-unit-009.html "css/css-values/ch-unit-009.html")
 [[(live
 test)]](http://wpt.live/css/css-values/ch-unit-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/ch-unit-009.html)
 - [ch-unit-010.html](https://wpt.fyi/results/css/css-values/ch-unit-010.html "css/css-values/ch-unit-010.html")
 [[(live
 test)]](http://wpt.live/css/css-values/ch-unit-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/ch-unit-010.html)
 - [ch-unit-011.html](https://wpt.fyi/results/css/css-values/ch-unit-011.html "css/css-values/ch-unit-011.html")
 [[(live
 test)]](http://wpt.live/css/css-values/ch-unit-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/ch-unit-011.html)
 - [ch-unit-012.html](https://wpt.fyi/results/css/css-values/ch-unit-012.html "css/css-values/ch-unit-012.html")
 [[(live
 test)]](http://wpt.live/css/css-values/ch-unit-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/ch-unit-012.html)
 - [ch-unit-016.html](https://wpt.fyi/results/css/css-values/ch-unit-016.html "css/css-values/ch-unit-016.html")
 [[(live
 test)]](http://wpt.live/css/css-values/ch-unit-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/ch-unit-016.html)
 - [ch-unit-017.html](https://wpt.fyi/results/css/css-values/ch-unit-017.html "css/css-values/ch-unit-017.html")
 [[(live
 test)]](http://wpt.live/css/css-values/ch-unit-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/ch-unit-017.html)
 - [line-break-ch-unit.html](https://wpt.fyi/results/css/css-values/line-break-ch-unit.html "css/css-values/line-break-ch-unit.html")
 [[(live
 test)]](http://wpt.live/css/css-values/line-break-ch-unit.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/line-break-ch-unit.html)
 - [calc-ch-ex-lang.html](https://wpt.fyi/results/css/css-values/calc-ch-ex-lang.html "css/css-values/calc-ch-ex-lang.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-ch-ex-lang.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-ch-ex-lang.html)

[rch]
: Equal to the value of the [ch](#ch) unit on the root element.

[ic]

: Represents the typical [advance
 measure](#length-advance-measure) of CJK letters, and measured as the used [advance
 measure] of the "水" (CJK water
 ideograph, U+6C34) glyph found in the font used to render it.

 This measurement is a typically an exact measure
 (in the few fonts with proportional fullwidth glyphs, an
 approximation) of a single
 [fullwidth](http://unicode.org/reports/tr11/#Definitions) glyph's
 [advance
 measure](#length-advance-measure), thus allowing measurements based on an expected
 glyph count.

 In the cases where it is impossible or impractical to determine the
 ideographic advance measure, it must be assumed to be 1em.

 Tests

 - [ic-unit-001.html](https://wpt.fyi/results/css/css-values/ic-unit-001.html "css/css-values/ic-unit-001.html")
 [[(live
 test)]](http://wpt.live/css/css-values/ic-unit-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/ic-unit-001.html)
 - [ic-unit-002.html](https://wpt.fyi/results/css/css-values/ic-unit-002.html "css/css-values/ic-unit-002.html")
 [[(live
 test)]](http://wpt.live/css/css-values/ic-unit-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/ic-unit-002.html)
 - [ic-unit-003.html](https://wpt.fyi/results/css/css-values/ic-unit-003.html "css/css-values/ic-unit-003.html")
 [[(live
 test)]](http://wpt.live/css/css-values/ic-unit-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/ic-unit-003.html)
 - [ic-unit-004.html](https://wpt.fyi/results/css/css-values/ic-unit-004.html "css/css-values/ic-unit-004.html")
 [[(live
 test)]](http://wpt.live/css/css-values/ic-unit-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/ic-unit-004.html)
 - [ic-unit-008.html](https://wpt.fyi/results/css/css-values/ic-unit-008.html "css/css-values/ic-unit-008.html")
 [[(live
 test)]](http://wpt.live/css/css-values/ic-unit-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/ic-unit-008.html)
 - [ic-unit-009.html](https://wpt.fyi/results/css/css-values/ic-unit-009.html "css/css-values/ic-unit-009.html")
 [[(live
 test)]](http://wpt.live/css/css-values/ic-unit-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/ic-unit-009.html)
 - [ic-unit-010.html](https://wpt.fyi/results/css/css-values/ic-unit-010.html "css/css-values/ic-unit-010.html")
 [[(live
 test)]](http://wpt.live/css/css-values/ic-unit-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/ic-unit-010.html)
 - [ic-unit-011.html](https://wpt.fyi/results/css/css-values/ic-unit-011.html "css/css-values/ic-unit-011.html")
 [[(live
 test)]](http://wpt.live/css/css-values/ic-unit-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/ic-unit-011.html)
 - [ic-unit-012.html](https://wpt.fyi/results/css/css-values/ic-unit-012.html "css/css-values/ic-unit-012.html")
 [[(live
 test)]](http://wpt.live/css/css-values/ic-unit-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/ic-unit-012.html)

[ric]
: Equal to the value of the [ic](#ic) unit on the root element.

[lh]
: Equal to the computed value of the
 [line-height](https://drafts.csswg.org/css2/#propdef-line-height) property of the element on
 which it is used, converting
 [normal](https://drafts.csswg.org/css-inline-3/#valdef-line-height-normal) to an absolute length by using only the
 metrics of the [first available
 font](https://www.w3.org/TR/css3-fonts/#first-available-font).
 Tests
 - [lh-rlh-on-root-001.html](https://wpt.fyi/results/css/css-values/lh-rlh-on-root-001.html "css/css-values/lh-rlh-on-root-001.html")
 [[(live
 test)]](http://wpt.live/css/css-values/lh-rlh-on-root-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/lh-rlh-on-root-001.html)
 - [lh-unit-001.html](https://wpt.fyi/results/css/css-values/lh-unit-001.html "css/css-values/lh-unit-001.html")
 [[(live
 test)]](http://wpt.live/css/css-values/lh-unit-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/lh-unit-001.html)
 - [lh-unit-002.html](https://wpt.fyi/results/css/css-values/lh-unit-002.html "css/css-values/lh-unit-002.html")
 [[(live
 test)]](http://wpt.live/css/css-values/lh-unit-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/lh-unit-002.html)

[rlh]

: Equal to the value of the [lh](#lh) unit on the root element.

 Setting the
 [height](https://drafts.csswg.org/css-sizing-3/#propdef-height) of an element using either the
 [lh](#lh) or the
 [rlh](#rlh) units does not
 enable authors to control the actual number of lines in that
 element. These units only enable length calculations based on the
 theoretical size of an ideal empty line; the size of actual lines
 boxes may differ based on their content. In cases where an author
 wants to limit the number of actual lines in an element, the
 [max-lines](https://drafts.csswg.org/css-overflow-4/#propdef-max-lines) property can be used instead.

 Tests

 - [lh-rlh-on-root-001.html](https://wpt.fyi/results/css/css-values/lh-rlh-on-root-001.html "css/css-values/lh-rlh-on-root-001.html")
 [[(live
 test)]](http://wpt.live/css/css-values/lh-rlh-on-root-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/lh-rlh-on-root-001.html)

Properties that affect the font size or font metrics of an element are
[font-affecting properties]. When used in the
value of any [font-affecting
property](#font-affecting-property) on the element they refer to, the [font-relative
lengths](#font-relative-length) resolve against the computed metrics of the parent
element---​or against the computed metrics corresponding to the initial
values of the
[font](https://drafts.csswg.org/css-fonts-4/#propdef-font) and
[line-height](https://drafts.csswg.org/css2/#propdef-line-height) properties, if the element has no
parent. Similarly, when [lh](#lh)
or [rlh](#rlh) units are used in
the value of the [line-height]
property or [font-affecting
properties] on the element they refer
to, they resolve against the computed
[line-height] and font metrics
of the parent element---​or the computed metrics corresponding to the
initial values of the [font] and
[line-height] properties, if
the element has no parent. (The other font-relative lengths continue to
resolve against the element's own metrics when used in
[line-height].)

 Most properties defined in
[\[css-fonts-4\]](#biblio-css-fonts-4 "CSS Fonts Module Level 4")
are [font-affecting
properties](#font-affecting-property), as is
[math-style](https://w3c.github.io/mathml-core/#propdef-math-style) and
[math-depth](https://w3c.github.io/mathml-core/#propdef-math-depth). (This isn't necessarily an
exhaustive list.)

When used outside the context of an element (such as in [media
queries](https://drafts.csswg.org/mediaqueries-5/#media-query)), the [font-relative
lengths](#font-relative-length) units refer to the metrics corresponding to the initial
values of the
[font](https://drafts.csswg.org/css-fonts-4/#propdef-font) and
[line-height](https://drafts.csswg.org/css2/#propdef-line-height) properties. Similarly, when
specified in a document with no root element, the [root font-relative
lengths](#root-font-relative-lengths) are resolved assuming the initial values of the
[font] and
[line-height] properties.

 Font-relative units such as [ch](#ch) and [ic](#ic)
can trigger font downloads, if a required font is not yet loaded.

The [font-relative
lengths](#font-relative-length) are calculated in the absence of shaping.

Some user-agents allow users to apply additional restrictions to font
sizes in a document, such as setting minimum font sizes to ensure
readability. Such restrictions must be applied to the [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) of the affected properties only; they *must not* affect
the resolution of [font-relative
lengths](#font-relative-length) used in properties. However, in other contexts (such as
in [media
queries](https://drafts.csswg.org/mediaqueries-5/#media-query)), to the extent that they would impact the used font
metrics, such restrictions *do* affect the resolution of [font-relative
lengths].

 In general, respecting a user's preferences, like
minimum font sizes, is desirable; it's useful for a media query like
[(min-width: 40em)] to use the actual font size the document will
be displayed in. However, having these preferences affect font-relative
lengths *in properties on an element* was found to not be
Web-compatible; too many pages expect these units to be exact multiples
of the specified
[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size), rather than the *actual* font-size
after applying user preferences.

Some user-agents apply restrictions to the
[line-height](https://drafts.csswg.org/css2/#propdef-line-height) values on form controls. These must
have no effect on the [lh](#lh) and
[rlh](#rlh) units. The effect on
their descendants, however, is
[implementation-defined](https://infra.spec.whatwg.org/#implementation-defined).

#### [6.1.2. ][ Viewport-percentage Lengths: the [\*vw], [\*vh], [\*vi], [\*vb], [\*vmin], [\*vmax] units]
The [viewport-percentage lengths] are relative to the size of the
[initial containing
block](https://www.w3.org/TR/CSS2/visudet.html#containing-block-details)---​which
is itself based on the size of either the viewport (for [continuous
media](https://drafts.csswg.org/mediaqueries-5/#continuous-media)) or the [page
area](https://drafts.csswg.org/css-page-3/#page-area) (for [paged
media](https://drafts.csswg.org/mediaqueries-5/#paged-media)). When the height or width of the initial containing
block is changed, they are scaled accordingly.

##### 6.1.2.1. The Large, Small, and Dynamic Viewport Sizes

There are four variants of the [viewport-percentage
length](#viewport-percentage-lengths) units, corresponding to three (possibly identical)
notions of the viewport size.

large viewport

: The [large viewport-percentage
 units] ([lv\*]) and [default
 viewport-percentage units] ([v\*]) are defined
 with respect to the [large viewport size]: the viewport sized assuming
 any
 [UA](https://drafts.csswg.org/css-2023/#user-agent) interfaces that are dynamically expanded and
 retracted to be retracted. This allows authors to size content such
 that it is guaranteed to fill the viewport, noting that such content
 might be hidden behind such interfaces when they are expanded.

 The sizes of the [large viewport-percentage
 units](#large-viewport-percentage-units) are fixed (and therefore stable) unless the
 viewport itself is resized.

 :::
 (#example-18205b29) For example, on phones, where
 screen real-estate is at a premium, browsers will often hide part or
 all of the title and address bar once the user starts scrolling the
 page. The [large viewport-percentage
 units](#large-viewport-percentage-units) are sized relative to this larger
 everything-retracted space, so content using these units will fill
 the entire visible page when these UI elements are hidden. However,
 when these retractable elements are shown, they can obscure content
 that is sized or positioned using these units.
 :::

small viewport

: The [small viewport-percentage
 units] ([sv\*]) are defined with respect to
 the [small viewport size]: the viewport sized assuming any
 [UA](https://drafts.csswg.org/css-2023/#user-agent) interfaces that are dynamically expanded and
 retracted to be expanded. This allows authors to size content such
 that it can fit within the viewport even when such interfaces are
 present, noting that such content might not fill the viewport when
 such interfaces are retracted.

 The sizes of the [small viewport-percentage
 units](#small-viewport-percentage-units) are fixed (and therefore stable) unless the
 viewport itself is resized.

 :::
 (#example-c1ac496e) An element that is sized as
 [height:
 100svh](https://drafts.csswg.org/css-sizing-3/#propdef-height), for example, will fill the screen
 perfectly, without any of its content being obscured, when all the
 dynamic UI elements of the UA are shown.
 Once those UI elements start being hidden, however, there will be
 extra space around the element. The [small viewport-percentage
 units](#small-viewport-percentage-units) units are thus "safer" in general, but might not
 produce the most attractive layout once the user starts interacting
 with the page.
 :::

dynamic viewport

: The [dynamic viewport-percentage
 units] ([dv\*]) are defined with respect to
 the [dynamic viewport size]: the viewport sized with dynamic
 consideration of any
 [UA](https://drafts.csswg.org/css-2023/#user-agent) interfaces that are dynamically expanded and
 retracted. This allows authors to size content such that it can
 exactly fit within the viewport whether or not such interfaces are
 present.

 The sizes of the [dynamic viewport-percentage
 units](#dynamic-viewport-percentage-units) *are not stable* even while the viewport itself is
 unchanged. Using these units can cause content to resize e.g. while
 the user scrolls the page. Depending on usage, this can be
 disturbing to the user and/or costly in terms of performance.

 The UA is not required to animate the [dynamic viewport-percentage
 units](#dynamic-viewport-percentage-units) while expanding and retracting any relevant
 interfaces, and may instead calculate the units as if the relevant
 interface was fully expanded or retracted during the UI animation.
 (It is recommended that UAs assume the fully-retracted size for this
 duration.)

Whether the expansion/retraction of a particular interface (A) changes
the sizes of all of the [viewport-percentage
lengths](#viewport-percentage-lengths) (and the [initial containing
block](https://drafts.csswg.org/css-display-4/#initial-containing-block)) simultaneously or (B) contributes to the differences
between the [large viewport
size](#large-viewport-size) and [small viewport
size](#small-viewport-size) is largely UA-dependent. However:

- Changes in interface that happen as a result of scrolling or other
 frequent page interactions that would disturb the user if they
 resulted in substantial layout changes must be categorized as the
 latter (B).

- Changes in interface that have a sufficiently steady state that
 re-laying out the document into the adjusted space would be beneficial
 to the user must be categorized as the former (A).

- Additionally, UAs may have some dynamically-shown interfaces that
 intentionally overlay content and do not cause any shifts in
 layout---​and therefore have no effect on any of the
 [viewport-percentage
 lengths](#viewport-percentage-lengths). (Typically on-screen keyboards will fit into this
 category.)

In all cases, if the value of
[overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) or
[scrollbar-gutter](https://drafts.csswg.org/css-overflow-3/#propdef-scrollbar-gutter) on the [root
element](https://drafts.csswg.org/css-display-4/#root-element) in either axis would cause scrollbars to appear (or
space to be reserved for them) unconditionally (for example, [overflow:
scroll], but not [overflow:
auto]), the [computed
values](https://drafts.csswg.org/css-cascade-5/#computed-value) of the [viewport-percentage
lengths](#viewport-percentage-lengths) in that axis are reduced in accordance with the
[initial containing
block](https://drafts.csswg.org/css-display-4/#initial-containing-block). Otherwise, and always in the case of [media
queries](https://drafts.csswg.org/mediaqueries-5/#media-query), the [viewport-percentage
lengths] are sized assuming that
scrollbars do not exist (even if this diverges from the [initial
containing block]).

 The value of
[overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) on [the body
element](https://html.spec.whatwg.org/multipage/dom.html#the-body-element-2) can sometimes affect the presence of scrollbars on the
[root
element](https://drafts.csswg.org/css-display-4/#root-element). This *does not* affect the size of viewport units,
however.

##### 6.1.2.2. The Various Viewport-relative Units

The [viewport-percentage
length](#viewport-percentage-lengths) units are:

[vw]\
[svw]\
[lvw]\
[dvw]
: Equal to 1% of the width of the [large viewport
 size](#large-viewport-size), [small viewport
 size](#small-viewport-size), [large viewport
 size], and [dynamic viewport
 size](#dynamic-viewport-size), respectively.
 :::
 (#example-6068ee5d) In the example below, if the width
 of the viewport is 200mm, the font size of `h1` elements
 will be 16mm (i.e. (8×200mm)/100).
 ``` highlight
 h1 { font-size: 8vw }
 ```
 :::

[vh]\
[svh]\
[lvh]\
[dvh]
: Equal to 1% of the height of the [large viewport
 size](#large-viewport-size), [small viewport
 size](#small-viewport-size), [large viewport
 size], and [dynamic viewport
 size](#dynamic-viewport-size), respectively.

[vi]\
[svi]\
[lvi]\
[dvi]
: Equal to 1% of the size of the [large viewport
 size](#large-viewport-size), [small viewport
 size](#small-viewport-size), [large viewport
 size], and [dynamic viewport
 size](#dynamic-viewport-size) (respectively) in the box's [inline
 axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis).

[vb]\
[svb]\
[lvb]\
[dvb]
: Equal to 1% of the size of the initial containing block [large
 viewport size](#large-viewport-size), [small viewport
 size](#small-viewport-size), [large viewport
 size], and [dynamic viewport
 size](#dynamic-viewport-size) (respectively) in the box's [block
 axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis).

[vmin]\
[svmin]\
[lvmin]\
[dvmin]
: Equal to the smaller of [\*vw] or [\*vh].

[vmax]\
[svmax]\
[lvmax]\
[dvmax]
: Equal to the larger of [\*vw] or [\*vh].

Tests

- [vh-calc-support-pct.html](https://wpt.fyi/results/css/css-values/vh-calc-support-pct.html "css/css-values/vh-calc-support-pct.html")
 [[(live
 test)]](http://wpt.live/css/css-values/vh-calc-support-pct.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/vh-calc-support-pct.html)
- [vh-calc-support.html](https://wpt.fyi/results/css/css-values/vh-calc-support.html "css/css-values/vh-calc-support.html")
 [[(live
 test)]](http://wpt.live/css/css-values/vh-calc-support.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/vh-calc-support.html)
- [vh-em-inherit.html](https://wpt.fyi/results/css/css-values/vh-em-inherit.html "css/css-values/vh-em-inherit.html")
 [[(live
 test)]](http://wpt.live/css/css-values/vh-em-inherit.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/vh-em-inherit.html)
- [vh-inherit.html](https://wpt.fyi/results/css/css-values/vh-inherit.html "css/css-values/vh-inherit.html")
 [[(live
 test)]](http://wpt.live/css/css-values/vh-inherit.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/vh-inherit.html)
- [vh-interpolate-pct.html](https://wpt.fyi/results/css/css-values/vh-interpolate-pct.html "css/css-values/vh-interpolate-pct.html")
 [[(live
 test)]](http://wpt.live/css/css-values/vh-interpolate-pct.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/vh-interpolate-pct.html)
- [vh-interpolate-px.html](https://wpt.fyi/results/css/css-values/vh-interpolate-px.html "css/css-values/vh-interpolate-px.html")
 [[(live
 test)]](http://wpt.live/css/css-values/vh-interpolate-px.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/vh-interpolate-px.html)
- [vh-interpolate-vh.html](https://wpt.fyi/results/css/css-values/vh-interpolate-vh.html "css/css-values/vh-interpolate-vh.html")
 [[(live
 test)]](http://wpt.live/css/css-values/vh-interpolate-vh.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/vh-interpolate-vh.html)
- [vh-support.html](https://wpt.fyi/results/css/css-values/vh-support.html "css/css-values/vh-support.html")
 [[(live
 test)]](http://wpt.live/css/css-values/vh-support.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/vh-support.html)
- [vh-support-margin.html](https://wpt.fyi/results/css/css-values/vh-support-margin.html "css/css-values/vh-support-margin.html")
 [[(live
 test)]](http://wpt.live/css/css-values/vh-support-margin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/vh-support-margin.html)
- [vh-support-transform-origin.html](https://wpt.fyi/results/css/css-values/vh-support-transform-origin.html "css/css-values/vh-support-transform-origin.html")
 [[(live
 test)]](http://wpt.live/css/css-values/vh-support-transform-origin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/vh-support-transform-origin.html)
- [vh-support-transform-translate.html](https://wpt.fyi/results/css/css-values/vh-support-transform-translate.html "css/css-values/vh-support-transform-translate.html")
 [[(live
 test)]](http://wpt.live/css/css-values/vh-support-transform-translate.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/vh-support-transform-translate.html)
- [vh-zero-support.html](https://wpt.fyi/results/css/css-values/vh-zero-support.html "css/css-values/vh-zero-support.html")
 [[(live
 test)]](http://wpt.live/css/css-values/vh-zero-support.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/vh-zero-support.html)
- [viewport-relative-lengths-scaled-viewport.html](https://wpt.fyi/results/css/css-values/viewport-relative-lengths-scaled-viewport.html "css/css-values/viewport-relative-lengths-scaled-viewport.html")
 [[(live
 test)]](http://wpt.live/css/css-values/viewport-relative-lengths-scaled-viewport.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/viewport-relative-lengths-scaled-viewport.html)
- [viewport-unit-011.html](https://wpt.fyi/results/css/css-values/viewport-unit-011.html "css/css-values/viewport-unit-011.html")
 [[(live
 test)]](http://wpt.live/css/css-values/viewport-unit-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/viewport-unit-011.html)
- [viewport-units-css2-001.html](https://wpt.fyi/results/css/css-values/viewport-units-css2-001.html "css/css-values/viewport-units-css2-001.html")
 [[(live
 test)]](http://wpt.live/css/css-values/viewport-units-css2-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/viewport-units-css2-001.html)

 The original (unprefixed) viewport units [were
defined](https://www.w3.org/TR/css-values-3/#viewport-relative-lengths)
relative to the [initial containing
block](https://drafts.csswg.org/css-display-4/#initial-containing-block), which in [continuous
media](https://drafts.csswg.org/mediaqueries-5/#continuous-media) always matched the (singular) viewport size. The
dynamism of browser chrome shifting in and out during scrolling was
invented later, and following Safari's lead, most UAs mapped these units
to the larger size. Defining it this way is prettier in many cases, but
can also block critical content (such as toolbars, headers, and footers)
in others. It's therefore not entirely clear whether this was the best
mapping, and thus earlier editions of this specifications allowed UAs to
choose the mapping of these default units. However at this point the
mapping to the [large viewport-percentage
units](#large-viewport-percentage-units) is presumed to be required for Web compatibility.

In situations where there is no element or it hasn't yet been styled
(such as when evaluating [media
queries](https://drafts.csswg.org/mediaqueries-5/#media-query)), the [\*vi] and [\*vb] units use the
initial value of the
[writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode) property to determine which axis
they correspond to.

### 6.2. Absolute Lengths: the [cm, [mm](#mm), [Q](#Q), [in](#in), [pt](#pt), [pc](#pc), [px](#px) units]
The [absolute length units]
are fixed in relation to each other and
[anchored](#anchor-unit) to some
physical measurement. They are mainly useful when the output environment
is known. The absolute units consist of the [physical
units] ([in](#in),
[cm](#cm), [mm](#mm), [pt](#pt),
[pc](#pc), [Q](#Q)) and the [visual angle unit (pixel
unit)] ([px](#px)):

unit

name

equivalence

[cm]

centimeters

1cm = 96px/2.54

[mm]

millimeters

1mm = 1/10th of 1cm

[Q]

quarter-millimeters

1Q = 1/40th of 1cm

[in]

inches

1in = 2.54cm = 96px

[pc]

picas

1pc = 1/6th of 1in

[pt]

points

1pt = 1/72nd of 1in

[px]

pixels

1px = 1/96th of 1in

``` highlight
h1 { margin: 0.5in } /* inches */
h2 { line-height: 3cm } /* centimeters */
h3 { word-spacing: 4mm } /* millimeters */
h3 { letter-spacing: 1Q } /* quarter-millimeters */
h4 { font-size: 12pt } /* points */
h4 { font-size: 1pc } /* picas */
p { font-size: 12px } /* px */
```

 Lengths in publishing contexts are sometimes written
like `2p3`, indicating a length of 2 picas and 3 points.
These can be written in CSS as [calc(2pc + 3pt)] (see [§ 10.1
Basic Arithmetic: calc()](#calc-func)).

All of the absolute length units are
[compatible](#compatible-units), and [px](#px) is
their [canonical unit](#canonical-unit).

For a CSS device, these dimensions are [anchored]
either

i. by relating the [physical
 units](#physical-unit) to
 their physical measurements, or
ii. by relating the [pixel
 unit](#visual-angle-unit) to the [reference
 pixel](#reference-pixel).

For print media at typical viewing distances, the [anchor
unit](#anchor-unit) should be one
of the [physical units](#physical-unit) (inches, centimeters, etc). For screen media (including
high-resolution devices), low-resolution devices, and devices with
unusual viewing distances, it is recommended instead that the [anchor
unit] be the [pixel
unit](#visual-angle-unit).
For such devices it is recommended that the [pixel
unit] refer to the whole number of [device
pixels](#device-pixel) that best
approximates the reference pixel.

 If the [anchor
unit](#anchor-unit) is the [pixel
unit](#visual-angle-unit),
the [physical units](#physical-unit) might not match their physical measurements.
Alternatively if the [anchor unit] is a [physical
unit], the [pixel
unit] might not map to a whole number of
[device pixels](#device-pixel).

 This definition of the [pixel
unit](#visual-angle-unit)
and the [physical units](#physical-unit) differs from the earlier editions of CSS1 and CSS2. In
particular, in previous versions of CSS the [pixel
unit] and the [physical
units] were not related by a fixed ratio: the
[physical units] were always tied to their
physical measurements while the [pixel
unit] would vary to most closely match the
reference pixel. (This unfortunate change was made because too much
existing content relies on the assumption of 96dpi, and breaking that
assumption broke the content.)

 Units are [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) and serialize as lowercase, for example 1Q serializes
as 1q.

Tests

- [absolute-length-units-001.html](https://wpt.fyi/results/css/css-values/absolute-length-units-001.html "css/css-values/absolute-length-units-001.html")
 [[(live
 test)]](http://wpt.live/css/css-values/absolute-length-units-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/absolute-length-units-001.html)
- [q-unit-case-insensitivity-001.html](https://wpt.fyi/results/css/css-values/q-unit-case-insensitivity-001.html "css/css-values/q-unit-case-insensitivity-001.html")
 [[(live
 test)]](http://wpt.live/css/css-values/q-unit-case-insensitivity-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/q-unit-case-insensitivity-001.html)
- [q-unit-case-insensitivity-002.html](https://wpt.fyi/results/css/css-values/q-unit-case-insensitivity-002.html "css/css-values/q-unit-case-insensitivity-002.html")
 [[(live
 test)]](http://wpt.live/css/css-values/q-unit-case-insensitivity-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/q-unit-case-insensitivity-002.html)
- [units-001.xht](https://wpt.fyi/results/css/CSS2/values/units-001.xht "css/CSS2/values/units-001.xht")
 [[(live
 test)]](http://wpt.live/css/CSS2/values/units-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/CSS2/values/units-001.xht)
- [units-006.xht](https://wpt.fyi/results/css/CSS2/values/units-006.xht "css/CSS2/values/units-006.xht")
 [[(live
 test)]](http://wpt.live/css/CSS2/values/units-006.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/CSS2/values/units-006.xht)
- [units-008.xht](https://wpt.fyi/results/css/CSS2/values/units-008.xht "css/CSS2/values/units-008.xht")
 [[(live
 test)]](http://wpt.live/css/CSS2/values/units-008.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/CSS2/values/units-008.xht)
- [units-009.xht](https://wpt.fyi/results/css/CSS2/values/units-009.xht "css/CSS2/values/units-009.xht")
 [[(live
 test)]](http://wpt.live/css/CSS2/values/units-009.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/CSS2/values/units-009.xht)

The [reference pixel] is the visual angle of one pixel on a device with a [device
pixel](#device-pixel) density of
96dpi and a distance from the reader of an arm's length. For a nominal
arm's length of 28 inches, the visual angle is therefore about 0.0213
degrees. For reading at arm's length, 1px thus corresponds to about
0.26 mm (1/96 inch).

The image below illustrates the effect of viewing distance on the size
of a reference pixel: a reading distance of 71 cm (28 inches) results in
a reference pixel of 0.26 mm, while a reading distance of 3.5 m
(12 feet) results in a reference pixel of 1.3 mm.

![Showing that pixels must become larger if the viewing distance
increases](images/pixel1.png){a
height="360" width="500"}

This second image illustrates the effect of a device's resolution on the
pixel unit: an area of 1px by 1px is covered by a single dot in a
low-resolution device (e.g. a typical computer display), while the same
area is covered by 16 dots in a higher resolution device (such as a
printer).

![Showing that more device pixels (dots) are needed to cover a 1px by
1px area on a high-resolution device than on a lower-resolution one (of
the same approximate viewing
distance)](images/pixel2.png){a
height="321" width="412"}

Tests

- [absolute-length-units-001.html](https://wpt.fyi/results/css/css-values/absolute-length-units-001.html "css/css-values/absolute-length-units-001.html")
 [[(live
 test)]](http://wpt.live/css/css-values/absolute-length-units-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/absolute-length-units-001.html)

A [device pixel] is the smallest unit of area on the device output capable of
displaying its full range of colors. For typical color screens, it's a
square or somewhat rectangular region containing a red, green, and blue
subpixel. Many non-traditional outputs exist that can blur this
definition, such as by displaying some colors at higher resolutions.
Such devices still expose some equivalent notion of \"device pixel\",
however.

## 7. Other Quantities

### 7.1. Angle Units: the [\<angle\> type and [deg](#deg), [grad](#grad), [rad](#rad), [turn](#turn) units]
Angle values are
[\<dimension\>](#typedef-dimension)s denoted by [\<angle\>]. The angle unit identifiers
are:

[deg]
: Degrees. There are 360 degrees in a full circle.

[grad]
: Gradians, also known as \"gons\" or \"grades\". There are 400
 gradians in a full circle.

[rad]
: Radians. There are 2π radians in a full circle.

[turn]
: Turns. There is 1 turn in a full circle.

For example, a right angle is [90deg] or [100grad] or
[0.25turn] or approximately [1.57rad].

All [\<angle\>](#angle-value) units are
[compatible](#compatible-units), and [deg](#deg)
is their [canonical unit](#canonical-unit).

By convention, when an angle denotes a direction in CSS, it is typically
interpreted as a [bearing angle], where 0deg is \"up\" or \"north\" on the
screen, and larger angles are more clockwise (so 90deg is \"right\" or
\"east\").

For example, in the
[linear-gradient()](https://drafts.csswg.org/css-images-3/#funcdef-linear-gradient) function, the
[\<angle\>](#angle-value) that determines the direction of the gradient is
interpreted as a bearing angle.

 For legacy reasons, some uses of
[\<angle\>](#angle-value) allow a bare [0] to mean [0deg]. This is
not true in general, however, and will not occur in future uses of the
[\<angle\>] type.

Tests

- [angle-units-001.html](https://wpt.fyi/results/css/css-values/angle-units-001.html "css/css-values/angle-units-001.html")
 [[(live
 test)]](http://wpt.live/css/css-values/angle-units-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/angle-units-001.html)
- [angle-units-002.html](https://wpt.fyi/results/css/css-values/angle-units-002.html "css/css-values/angle-units-002.html")
 [[(live
 test)]](http://wpt.live/css/css-values/angle-units-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/angle-units-002.html)
- [angle-units-003.html](https://wpt.fyi/results/css/css-values/angle-units-003.html "css/css-values/angle-units-003.html")
 [[(live
 test)]](http://wpt.live/css/css-values/angle-units-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/angle-units-003.html)
- [angle-units-004.html](https://wpt.fyi/results/css/css-values/angle-units-004.html "css/css-values/angle-units-004.html")
 [[(live
 test)]](http://wpt.live/css/css-values/angle-units-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/angle-units-004.html)
- [angle-units-005.html](https://wpt.fyi/results/css/css-values/angle-units-005.html "css/css-values/angle-units-005.html")
 [[(live
 test)]](http://wpt.live/css/css-values/angle-units-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/angle-units-005.html)
- [calc-angle-values.html](https://wpt.fyi/results/css/css-values/calc-angle-values.html "css/css-values/calc-angle-values.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-angle-values.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-angle-values.html)

### 7.2. Duration Units: the [\<time\> type and [s](#s), [ms](#ms) units]
Time values are [dimensions](#dimension) denoted by [\<time\>]. The time unit identifiers are:

[s]
: Seconds.

[ms]
: Milliseconds. There are 1000 milliseconds in a second.

All [\<time\>](#time-value) units are
[compatible](#compatible-units), and [s](#s) is
their [canonical unit](#canonical-unit).

Properties may restrict the time value to some range. If the value is
outside the allowed range, the declaration is invalid and must be
[ignored](https://www.w3.org/TR/CSS2/conform.html#ignore).

Tests

- [calc-time-values.html](https://wpt.fyi/results/css/css-values/calc-time-values.html "css/css-values/calc-time-values.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-time-values.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-time-values.html)
- [transition-delay-001.html](https://wpt.fyi/results/css/css-transitions/transition-delay-001.html "css/css-transitions/transition-delay-001.html")
 [[(live
 test)]](http://wpt.live/css/css-transitions/transition-delay-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-transitions/transition-delay-001.html)
- [transition-duration-001.html](https://wpt.fyi/results/css/css-transitions/transition-duration-001.html "css/css-transitions/transition-duration-001.html")
 [[(live
 test)]](http://wpt.live/css/css-transitions/transition-duration-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-transitions/transition-duration-001.html)

### 7.3. Frequency Units: the [\<frequency\> type and [Hz](#Hz), [kHz](#kHz) units]
Frequency values are [dimensions](#dimension) denoted by [\<frequency\>]. The frequency unit identifiers
are:

[Hz]
: Hertz. It represents the number of occurrences per second.

[kHz]
: KiloHertz. A kiloHertz is 1000 Hertz.

For example, when representing sound pitches, 200Hz (or 200hz) is a bass
sound, and 6kHz (or 6khz) is a treble sound.

All [\<frequency\>](#frequency-value) units are
[compatible](#compatible-units), and [hz](#Hz) is
their [canonical unit](#canonical-unit).

 Units are [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) and serialize as lowercase, for example 1Hz serializes
as 1hz.

### 7.4. Resolution Units: the [\<resolution\> type and [dpi](#dpi), [dpcm](#dpcm), [dppx](#dppx) units]
Resolution units are [dimensions](#dimension) denoted by [\<resolution\>]. The resolution unit identifiers
are:

[dpi]
: Dots per inch.

[dpcm]
: Dots per centimeter.

[dppx]\
[x]
: Dots per [px](#px) unit.

The [\<resolution\>](#resolution-value) unit represents the size of a single
\"dot\" in a graphical representation by indicating how many of these
dots fit in a CSS [in](#in),
[cm](#cm), or
[px](#px). For uses, see e.g. the
[resolution] media query in
[\[MEDIAQ\]](#biblio-mediaq "Media Queries Level 4")
or the
[image-resolution](https://drafts.csswg.org/css-images-4/#propdef-image-resolution) property defined in
[\[CSS3-IMAGES\]](#biblio-css3-images "CSS Images Module Level 3").

All [\<resolution\>](#resolution-value) units are
[compatible](#compatible-units), and [dppx](#dppx) is their [canonical
unit](#canonical-unit).

The allowed range of
[\<resolution\>](#resolution-value) values *always* excludes negative values,
in addition to any explicit ranges that might be specified.

Note that due to the 1:96 fixed ratio of CSS [in](#in) to CSS [px](#px), [1dppx] is equivalent to [96dpi]. This
corresponds to the default resolution of images displayed in CSS: see
[image-resolution](https://drafts.csswg.org/css-images-4/#propdef-image-resolution).

The following \@media rule uses Media
Queries
[\[MEDIAQ\]](#biblio-mediaq "Media Queries Level 4")
to assign some special style rules to devices that use two or more
device pixels per CSS [px](#px)
unit:

``` highlight
@media (min-resolution: 2dppx) { ... }
```

## 8. Data Types Defined Elsewhere

Some data types are defined in their own modules. This example talks
about some of the most common ones used across several specifications.

### [8.1. ][ Colors: the [\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) type]
The
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) data type is defined in
[\[CSS-COLOR-4\]](#biblio-css-color-4 "CSS Color Module Level 4").
UAs must interpret [\<color\>] as
defined therein.

#### [8.1.1. ][ Combination of [\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color)]
[Interpolation](#interpolation) of
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) is defined in [CSS Color 4 §  13.
Color
Interpolation](https://drafts.csswg.org/css-color-4/#interpolation).
Interpolation is done between premultiplied colors, as defined in [CSS
Color 4 § 13.4 Interpolating with
Alpha](https://drafts.csswg.org/css-color-4/#interpolation-alpha).

The
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) type is [not
additive](#not-additive).

 the CSS WG is interested to
[hear](https://github.com/w3c/csswg-drafts/issues/new) use-cases for
addition of
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color), and may consider making
[\<color\>] additive in the future.

### [8.2. ][ Images: the [\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image) type]
The
[\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image) data type is defined in
[\[CSS3-IMAGES\]](#biblio-css3-images "CSS Images Module Level 3").
UAs that support CSS Images Level 3 or its successor must interpret
[\<image\>] as defined therein. UAs
that do not yet support CSS Images Level 3 must interpret
[\<image\>] as
[\<url\>](#url-value).

#### [8.2.1. ][ Combination of [\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image)]
 Interpolation of
[\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image) is defined in [CSS Images 3 § 6
Interpolation](https://drafts.csswg.org/css-images-3/#interpolation).

Images are [not additive](#not-additive).

### 8.3. 2D Positioning: the [\<position\> type]
The [[\<position\>](#typedef-position)] value specifies the position of a object area
(e.g. background image) inside a positioning area (e.g. background
positioning area). It is computed and interpreted as specified for
[background-position](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-position).
[\[CSS3-BACKGROUND\]](#biblio-css3-background "CSS Backgrounds and Borders Module Level 3")

```
<position> = [
 [ left | center | right | top | bottom | <length-percentage> ]
|
 [ left | center | right ] && [ top | center | bottom ]
|
 [ left | center | right | <length-percentage> ]
 [ top | center | bottom | <length-percentage> ]
|
 [ [ left | right ] <length-percentage> ] &&
 [ [ top | bottom ] <length-percentage> ]
]
```

 The
[background-position](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-position) property also accepts a three-value
syntax. This has been disallowed generically because it creates parsing
ambiguities when combined with other length or percentage components in
a property value.

#### 8.3.1. Parsing [\<position\>]
When specified in a grammar alongside other keywords,
[\<length\>](#length-value)s, or
[\<percentage\>](#percentage-value)s,
[\<position\>](#typedef-position) is *greedily* parsed; it consumes as many
components as possible.

For example,
[transform-origin](https://drafts.csswg.org/css-transforms-1/#propdef-transform-origin) defines a 3D position as
(effectively)
[[\<position\>](#typedef-position)
[\<length\>](#length-value)?]. A value such as [left 50px] will be
parsed as a 2-value
[\<position\>](#typedef-position), with an omitted z-component; on the other
hand, a value such as [top 50px] will be parsed as a single-value
[\<position\>] followed by a
[\<length\>](#length-value).

#### 8.3.2. Serializing [\<position\>]
When serializing the [specified
value](https://drafts.csswg.org/css-cascade-5/#specified-value) of a
[\<position\>](#typedef-position):

If only one component is specified:

: - The implied
 [center](https://drafts.csswg.org/css-backgrounds-3/#valdef-background-position-center) keyword is added, and a 2-component value
 is serialized.

If two components are specified:

: - Keywords are serialized as keywords.

 - [\<length-percentage\>](#typedef-length-percentage)s are serialized as
 [\<length-percentage\>]s.

 - Components are serialized horizontal first, then vertical.

If four components are specified:

: - Keywords and offsets are both serialized.

 - Components are serialized horizontal first, then vertical.

[\<position\>](#typedef-position) values are never serialized as a single
value, even when a single value would produce the same behavior, to
avoid causing parsing ambiguities in some grammars where a
[\<position\>] is placed next
to a [\<length\>](#length-value), such as
[transform-origin](https://drafts.csswg.org/css-transforms-1/#propdef-transform-origin).

 [Computed
values](https://drafts.csswg.org/css-cascade-5/#computed-value) are always serialized as two offsets (without keywords)
because the [computed value] does not
preserve syntactic distinctions.

#### 8.3.3. Combination of [\<position\>]
[Interpolation](#interpolation) of
[\<position\>](#typedef-position) is defined as the independent
interpolation of each component (x, y) normalized as an offset from the
top left corner as a
[\<length-percentage\>](#typedef-length-percentage).

[Addition](#addition) of
[\<position\>](#typedef-position) is likewise defined as the independent
[addition] each component (x, y) normalized as an
offset from the top left corner as a
[\<length-percentage\>](#typedef-length-percentage).

## 9. Functional Notations

A [functional notation] is a type of component value that can
represent more complex types or invoke special processing. The syntax
starts with the name of the function immediately followed by a left
parenthesis (i.e. a
[\<function-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-function-token)) followed by the argument(s) to the
notation followed by a right parenthesis. Like keywords, function names
are [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive). [White
space](https://www.w3.org/TR/css-syntax/#whitespace) is allowed, but
optional, immediately inside the parentheses. Functions can take
multiple arguments, which are formatted similarly to a CSS property
value. See [§ 2.6 Functional Notation
Definitions](#component-functions).

 Some legacy [functional
notations](#functional-notation), such as
[rgba()](https://drafts.csswg.org/css-color-4/#funcdef-rgba), use commas unnecessarily, but generally commas
are only used to separate items in a list, or pieces of a grammar that
would be ambiguous otherwise. If a comma is used to separate arguments,
[white space](https://www.w3.org/TR/css-syntax/#whitespace) is optional
before and after the comma.

``` highlight
background: url(http://www.example.org/image);
color: rgb(100, 200, 50 );
content: counter(list-item) ". ";
width: calc(50% - 2em);
```

The [math functions](#math-function) are defined below. Other [functional
notations](#functional-notation) are defined in their own modules; for example the
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) functions are defined in
[\[CSS-COLOR-4\]](#biblio-css-color-4 "CSS Color Module Level 4")
and
[\[CSS-COLOR-5\]](#biblio-css-color-5 "CSS Color Module Level 5").

### 9.1. Numeric Functions

Any [functional
notation](#functional-notation) that resolves solely to a [numeric data
type](#numeric-data-types)
is a [numeric function].

As the value of a [numeric
function](#numeric-function)
can't, generally, be known at parse time when range restrictions are
enforced, [numeric functions] returning
out-of-range values never cause a declaration to become invalid.
Instead, the value of a [numeric function]
is clamped to the range allowed in the context it is used at [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) time if possible, and at [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) time otherwise.

Similarly, if a [numeric
function](#numeric-function)
returns a non-integer value, but is used in a position that expects an
[\<integer\>](#integer-value), the [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) and [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) are [rounded to the nearest
integer](#css-round-to-the-nearest-integer).

 All [math
functions](#math-function) are
[numeric functions](#numeric-function), but functions like
[sibling-index()](https://drafts.csswg.org/css-values-5/#funcdef-sibling-index) are also [numeric
functions] without being [math
functions].

Since widths smaller than 0px are not
allowed, these three declarations are equivalent:

``` highlight
width: calc(5px - 10px);
width: calc(-5px);
width: 0px;
```

Note however that [width:
-5px](https://drafts.csswg.org/css-sizing-3/#propdef-width) is not equivalent to [width:
calc(-5px)]! Out-of-range values specified
*literally* are invalid at parse-time, and cause the entire declaration
to be dropped.

 While CSS intentionally leaves numeric precision/range
UA-defined, extremely large values (including, notably, ±∞) will clamp
to the minimum/maximum value allowed. Even properties that can
explicitly represent infinity as a keyword value, such as
[animation-iteration-count](https://drafts.csswg.org/css-animations-1/#propdef-animation-iteration-count), will end up clamping ±∞, as [math
functions](#math-function)
can't resolve to keyword values; the *numeric* part of the property's
syntax still has an implicit minimum/maximum value.

Tests

- [calc-integer.html](https://wpt.fyi/results/css/css-values/calc-integer.html "css/css-values/calc-integer.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-integer.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-integer.html)
- [calc-z-index-fractions-001.html](https://wpt.fyi/results/css/css-values/calc-z-index-fractions-001.html "css/css-values/calc-z-index-fractions-001.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-z-index-fractions-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-z-index-fractions-001.html)

### 9.2. Serialization of Functional Notations

Unless otherwise specified, to [serialize a functional
notation]:

1. Let `s` be a string containing the function's name in
 lowercase, followed by "(" (U+0028 LEFT PARENTHESIS).

2. Append to `s` the serializations of the arguments of the
 [functional
 notation](#functional-notation) per their individual grammars, in the order the
 grammars are written in, joining space-separated tokens with a
 single space, and following each serialized comma, colon,
 semi-colon, or slash with a single space (U+0020 SPACE). When
 serializing the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) or its derivatives (not
 [specified](https://drafts.csswg.org/css-cascade-5/#specified-value) or
 [declared](https://drafts.csswg.org/css-cascade-5/#declared-value) values), omit components when possible without
 changing the meaning.

3. Append ")" (U+0029 RIGHT PARENTHESIS) to `s`.

We are inconsistent in how we handled
[specified
values](https://drafts.csswg.org/css-cascade-5/#specified-value). [\[Issue
#9720\]](https://github.com/w3c/csswg-drafts/issues/9720)

For example, given a function like
[LINEAR-GRADIENT( to bottom , red calc( 1em + 5% ) , green calc(130px /
2) , blue 100% )]:

as a [specified value](https://drafts.csswg.org/css-cascade-5/#specified-value)

: it will serialize as [linear-gradient(to bottom, red calc(5% + 1em),
 green calc(65px), blue 100%)]

 - Function names and [keywords](#css-keyword) become lowercase.

 - Whitespace is normalized: one space between most tokens, but no
 space after left parentheses/brackets, before right
 parentheses/brackets, or before commas

 - [calc()](#funcdef-calc) arguments are simplified and sorted per
 [§ 10.13 Serialization](#calc-serialize)

as a [computed value](https://drafts.csswg.org/css-cascade-5/#computed-value)

: it will serialize as [linear-gradient(red calc(5% + 16px), green
 calc(65px), blue)]

 - In addition to any [specified
 value](https://drafts.csswg.org/css-cascade-5/#specified-value) simplifications, any additional value
 [computations](https://drafts.csswg.org/css-cascade-5/#computed-value) are also applied, such as converting [specified
 lengths](#specified-length) to [computed
 lengths](#computed-length).

 - Values that match the default (e.g. [to bottom], the
 [100%] stop position on the final stop) are omitted
 entirely.

## 10. Mathematical Expressions

The [math functions]
([calc()](#funcdef-calc),
[clamp()](#funcdef-clamp), [sin()](#funcdef-sin), and others defined in this chapter) allow numeric
CSS values to be written as mathematical expressions.

A [math function](#math-function) represents a numeric value, one of:

- [\<length\>](#length-value),

- [\<frequency\>](#frequency-value),

- [\<angle\>](#angle-value),

- [\<time\>](#time-value),

- [\<flex\>](https://drafts.csswg.org/css-grid-2/#typedef-flex),

- [\<resolution\>](#resolution-value),

- [\<percentage\>](#percentage-value),

- [\<number\>](#number-value),

- [\<integer\>](#integer-value)

\...or the
[\<length-percentage\>](#typedef-length-percentage)/etc mixed types, and can be used
wherever such a value would be valid.

 [Math
functions](#math-function)
differ from the more general [numeric
functions](#numeric-function) because they automatically inherit the [calculation
context](#calculation-contexts) where they're used, letting you use all the values you
could use \"normally\" in that position, with the same meaning they'd
normally have.

### 10.1. Basic Arithmetic: [calc()]
The [calc()] function is a [math
function](#math-function) that
allows basic arithmetic to be performed on numerical values, using
addition ([+]), subtraction ([-]), multiplication
([\*]), division ([/]), and parentheses.

A [calc()](#funcdef-calc)
function contains a single [calculation], which is a
sequence of values interspersed with operators, and possibly grouped by
parentheses (matching the
[\<calc-sum\>](#typedef-calc-sum) grammar), which represents the result of
evaluating the expression using standard operator precedence rules
([\*] and [/] bind tighter than [+] and [-], and
operators are otherwise evaluated left-to-right). The
[calc()] function represents the result of
its contained [calculation](#calc-calculation).

Components of a
[calculation](#calc-calculation) can be literal values (such as [5px]), other
[math functions](#math-function), or other expressions, such as
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var), that evaluate to a valid argument type (like
[\<length\>](#length-value)).

[Math functions](#math-function) can be used to combine value that use different units.
In this example the author wants the *margin box* of each section to
take up 1/3 of the space, so they start with [100%/3], then
subtract the element's borders and margins.
([box-sizing](https://drafts.csswg.org/css-sizing-3/#propdef-box-sizing) can automatically achieve this
effect for borders and padding, but a [math
function] is needed if you want to include
margins.)

```
section {
 float: left;
 margin: 1em; border: solid 1px;
 width: calc(100% / 3 - 2 * 1em - 2 * 1px);
}
```

Similarly, in this example the gradient will show a color transition
only in the first and last [20px] of the element:

```
.fade {
 background-image: linear-gradient(silver 0%, white 20px,
 white calc(100% - 20px), silver 100%);
}
```

[Math functions](#math-function) can also be useful just to express values in a more
natural, readable fashion, rather than as an obscure decimal. For
example, the following sets the
[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size) so that exactly 35em fits within
the viewport, ensuring that roughly the same amount of text always fills
the screen no matter the screen size.

```
:root {
 font-size: calc(100vw / 35);
}
```

Functionality-wise, this is identical to just writing [font-size:
2.857vw](https://drafts.csswg.org/css-fonts-5/#descdef-font-face-font-size), but then the intent (that [35em] fills
the viewport) is much less clear to someone reading the code; the later
reader will have to reverse the math themselves to figure out that 2.857
is meant to approximate 100/35.

Standard mathematical precedence rules for the operators apply:
[calc(2 + 3 \* 4)] is equal to [14], not [20].

Parentheses can be used to manipulate precedence: [calc((2 + 3) \*
4)] is instead equal to [20].

Parentheses and nesting additional
[calc()](#funcdef-calc)
functions are equivalent; the preceding expression could equivalently
have been written as [calc(calc(2 + 3) \* 4)]. This can be useful
when building up values piecemeal via
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var), such as in the following example:

```
.aspect-ratio-box {
 --ar: calc(16 / 9);
 --w: calc(100% / 3);
 --h: calc(var(--w) / var(--ar));
 width: var(--w);
 height: var(--h);
}
```

Although [\--ar] *could* have been written as simply [\--ar: (16 /
9);], [\--w] is used both on its own
(in
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width)) and as a
[calc()](#funcdef-calc)
component (in [\--h]), so it has to be written as a full
[calc()] function itself.

- [calc-ch-ex-lang.html](https://wpt.fyi/results/css/css-values/calc-ch-ex-lang.html "css/css-values/calc-ch-ex-lang.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-ch-ex-lang.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-ch-ex-lang.html)
- [calc-in-color-001.html](https://wpt.fyi/results/css/css-values/calc-in-color-001.html "css/css-values/calc-in-color-001.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-in-color-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-in-color-001.html)
- [calc-in-font-feature-settings.html](https://wpt.fyi/results/css/css-values/calc-in-font-feature-settings.html "css/css-values/calc-in-font-feature-settings.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-in-font-feature-settings.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-in-font-feature-settings.html)
- [calc-rem-lang.html](https://wpt.fyi/results/css/css-values/calc-rem-lang.html "css/css-values/calc-rem-lang.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-rem-lang.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-rem-lang.html)
- [calc-rounding-001.html](https://wpt.fyi/results/css/css-values/calc-rounding-001.html "css/css-values/calc-rounding-001.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-rounding-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-rounding-001.html)
- [ex-calc-expression-001.html](https://wpt.fyi/results/css/css-values/ex-calc-expression-001.html "css/css-values/ex-calc-expression-001.html")
 [[(live
 test)]](http://wpt.live/css/css-values/ex-calc-expression-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/ex-calc-expression-001.html)

### 10.2. Comparison Functions: [min(), [max()](#funcdef-max), and [clamp()](#funcdef-clamp)]
The comparison functions of [min()](#funcdef-min), [max()](#funcdef-max), and
[clamp()](#funcdef-clamp) compare multiple
[calculations](#calc-calculation) and represent the value of one of them.

The [min()] or [max()] functions contain one or more
comma-separated
[calculations](#calc-calculation), and represent the smallest (most negative) or largest
(most positive) of them, respectively.

The [clamp()] function takes three
[calculations](#calc-calculation)---​a minimum value, a central value, and a maximum
value---​and represents its central calculation, clamped according to its
min and max calculations, favoring the min calculation if it conflicts
with the max. (That is, given [clamp(MIN, VAL, MAX)], it
represents exactly the same value as [max(MIN, min(VAL, MAX))]).

Either the min or max calculations (or even both) can instead be the
keyword [none], which indicates the value
is *not* clamped from that side. (That is, [clamp(MIN, VAL, none)]
is equivalent to [max(MIN, VAL)], [clamp(none, VAL, MAX)] is
equivalent to [min(VAL, MAX)], and [clamp(none, VAL, none)]
is equivalent to just [calc(VAL)].)

For all three functions, the argument
[calculations](#calc-calculation) can resolve to any
[\<number\>](#number-value),
[\<dimension\>](#typedef-dimension), or
[\<percentage\>](#percentage-value), but must have a [consistent
type](#css-consistent-type) or else the function is invalid; the result's type will
be the [consistent type].

[min()](#funcdef-min),
[max()](#funcdef-max), and
[clamp()](#funcdef-clamp) can be used to make sure a value doesn't exceed a
\"safe\" limit: For example, \"responsive type\" that sets
[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size) with viewport units might still
want a minimum size to ensure readability:

```
.type {
 /* Set font-size to 10x the average of vw and vh,
 but don't let it go below 12px. */
 font-size: max(10 * (1vw + 1vh) / 2, 12px);
}
```

 Full math expressions are allowed in each of the
arguments; there's no need to nest a
[calc()](#funcdef-calc)
inside! You can also provide more than two arguments, if you have
multiple constraints to apply.

An occasional point of confusion when
using [min()](#funcdef-min)/[max()](#funcdef-max) is that you use [max()]
to impose a minimum value on something (that is, properties like
[min-width](https://drafts.csswg.org/css-sizing-3/#propdef-min-width) effectively use
[max()]), and [min()] to impose a maximum value on something; it's easy to accidentally
reach for the opposite function and try to use
[min()] to add a minimum size. Using
[clamp()](#funcdef-clamp) can make the code read more naturally, as the value
is nestled between its minimum and maximum:

```
.type {
 /* Force the font-size to stay between 12px and 100px */
 font-size: clamp(12px, 10 * (1vw + 1vh) / 2, 100px);
}
```

Or, if you only wanted to impose a minimum size, but allow the font-size
to grow as large as it wants:

```
.type {
 /* Force the font-size to be at least 12px */
 font-size: clamp(12px, 10 * (1vw + 1vh) / 2, none);
}
```

Note that [clamp()](#funcdef-clamp), matching CSS conventions elsewhere, has its minimum
value \"win\" over its maximum value if the two are in the \"wrong
order\". That is, [clamp(100px, \..., 50px)] will resolve to
[100px], exceeding its stated \"max\" value.

If alternate resolution mechanics are desired they can be achieved by
combining [clamp()](#funcdef-clamp) with [min()](#funcdef-min) or [max()](#funcdef-max):

To have MAX win over MIN:

: [clamp(min(MIN, MAX), VAL, MAX)]. If you want to avoid
 repeating the MAX calculation, you can just reverse the nesting of
 functions that [clamp()](#funcdef-clamp) is defined against---​[min(MAX, max(MIN,
 VAL))].

To have MAX and MIN \"swap\" when they're in the wrong order:

: [clamp(min(MIN, MAX), VAL, max(MIN, MAX))]. Unfortunately,
 there's no easy way to do this without repeating the MIN and MAX
 terms.

### 10.3. Stepped Value Functions: [round(), [mod()](#funcdef-mod), and [rem()](#funcdef-rem)]
The stepped-value functions,
[round()](#funcdef-round), [mod()](#funcdef-mod), and [rem()](#funcdef-rem), all transform a given value according to another
\"step value\", in different ways.

The
[round([\<rounding-strategy\>](#typedef-rounding-strategy)?, A, B?)] function
contains an optional rounding strategy, and two
[calculations](#calc-calculation) A and B, and returns the value of A, rounded according
to the rounding strategy, to the nearest integer multiple of B either
above or below A. The argument
[calculations] can resolve to any
[\<number\>](#number-value),
[\<dimension\>](#typedef-dimension), or
[\<percentage\>](#percentage-value), but must have a [consistent
type](#css-consistent-type) or else the function is invalid; the result's type will
be the [consistent type].

If A is exactly equal to an integer multiple of B,
[round()](#funcdef-round) resolves to A exactly (preserving whether A is 0⁻ or
0⁺, if relevant). Otherwise, there are two integer multiples of B that
are potentially \"closest\" to A, `lower B` which is closer
to −∞ and `upper B` which is closer to +∞. The following
[[\<rounding-strategy\>](#typedef-rounding-strategy)]s dictate how to choose between
them:

[nearest]

: Choose whichever of `lower B` and `upper B`
 that has the smallest absolute difference from A. If both have an
 equal difference (A is exactly between the two values), choose
 `upper B`.

[up]

: Choose `upper B`.

[down]

: Choose `lower B`.

[to-zero]

: Choose whichever of `lower B` and `upper B`
 that has the smallest absolute difference from 0.

[line-width]

: If B is omitted, A is [snapped as a line
 width](#snap-as-a-line-width).

 Otherwise round as for
 [nearest](#valdef-rounding-strategy-nearest), except that if one of `lower B`
 or `upper B` is zero, the non-zero one is chosen, and the
 final result is [snapped as a line
 width](#snap-as-a-line-width).

If `lower B` would be zero, it is specifically equal to 0⁺;
if `upper B` would be zero, it is specifically equal to 0⁻.

If
[\<rounding-strategy\>](#typedef-rounding-strategy) is omitted, it defaults to
[nearest](#valdef-rounding-strategy-nearest). (Aka [rounding to the nearest
integer](#css-round-to-the-nearest-integer).) If
[\<rounding-strategy\>]
is
[line-width](#valdef-rounding-strategy-line-width), the
[type](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-type) of A must match
[\<length\>](#length-value).

If the
[type](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-type) of A matches
[\<number\>](#number-value), then B may be omitted, and defaults to [1]. If
[\<rounding-strategy\>](#typedef-rounding-strategy) is
[line-width](#valdef-rounding-strategy-line-width), B may also be omitted and has special behavior
(defined above) essentially defaulting it to one device pixel. In all
other cases, omitting B is invalid.

**While [round(line-width, \...)] attempts to ensure that non-zero
values never round to zero, passing a sufficiently small A value might
cause it to be represented as 0 internally anyway. Use caution when
writing very small values; [round(line-width, 0.1px)] is safer
than [round(line-width, 0.0001px)], and the difference between the
two is almost certainly nil in practice.**

CSSOM needs to specify how it rounds,
and it's probably good for CSS functions to round the same way by
default. What behavior should be used? [\[Issue
#5689\]](https://github.com/w3c/csswg-drafts/issues/5689)

Unlike languages like JavaScript which
have a natural \"precision\" to round to (integers), CSS values have no
such precision because values can be written in many different
compatible units. As such, the precision has to be given explicitly; to
round a width to the nearest [50px], one can write
[round(var(\--width), 50px)].

 JavaScript and other programming languages sometimes
separate out the rounding strategies into separate rounding functions.
JS's `Math.floor()` is equivalent to CSS's [round(down,
\...)]; JS's `Math.ceil()` is equivalent to CSS's
[round(up, \...)]; JS's `Math.trunc()` is equivalent
to CSS's [round(to-zero, \...)]; and JS's
`Math.round()` is equivalent to CSS's [round(nearest,
\...)], or just [round(\...)].

 The
[\<rounding-strategy\>](#typedef-rounding-strategy) keywords are the same as the keywords
in
[block-step-size](https://drafts.csswg.org/css-rhythm-1/#propdef-block-step-size) and have the same behavior.
([block-step-size] just
lacks
[to-zero](#valdef-rounding-strategy-to-zero); since block sizes are always non-negative,
[to-zero] and
[down](#valdef-rounding-strategy-down) would be identical.)

The modulus functions [mod(A, B)] and [rem(A, B)]
similarly contain two
[calculations](#calc-calculation) A and B, and return the difference between A and the
nearest integer multiple of B either above or below A. The argument
[calculations] can resolve to any
[\<number\>](#number-value),
[\<dimension\>](#typedef-dimension), or
[\<percentage\>](#percentage-value), but must have the *same*
[type](#determine-the-type-of-a-calculation), or else the function is invalid; the result will have
the same
[type](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-type) as the arguments.

The two functions are very similar, and in fact return identical results
if both arguments are positive or both are negative: the value of the
function is equal to the value of A shifted by the integer multiple of B
that brings the value [between zero and B]. (Specifically, the range
includes zero and excludes B. More specifically, if B is positive the
range starts at 0⁺, and if B is negative it starts at 0⁻.)

For example, [mod(18px, 5px)]
resolves to the value [3px], because subtracting [5px \* 3]
from [18px] yields [3px], which is the only such value
between [0px] and [5px].

Similarly, [mod(-140deg, -90deg)] resolves to the value
[-50deg], because adding [-90deg \* 1] to [-140deg]
yields [-50deg], which is the only such value between [0deg]
and [-90deg].

Evaluating either of these examples with
[rem()](#funcdef-rem)
yields the exact same results.

Their behavior diverges if the A value and the B step are on opposite
sides of zero: [mod()](#funcdef-mod) (short for "modulus") continues to choose the integer
multiple of B that puts the value [between zero and
B](#between-zero-and-b), as
above (guaranteeing that the result will either be zero or share the
sign of B, not A), while [rem()](#funcdef-rem) (short for \"remainder\") chooses the integer
multiple of B that puts the value [between zero and
-B], avoiding changing the sign of the
value.

For example, [mod(-18px, 5px)]
resolves to the value [2px]: adding [5px \* 4] to
[-18px] yields [2px], which is between [0px] and
[5px].

On the other hand, [rem(-18px, 5px)] resolves to the value
[-3px]: adding [5px \* 3] to [-18px] yields
[-3px], which has the same sign as [-18px] but is between
[0px] and [-5px].

Similarly, [mod(140deg, -90deg)] resolves to the value
[-40deg] (adding [-90deg \* 2] to [140deg], bringing
it to between [0deg] and [-90deg]), but [rem(140deg,
-90deg)] resolves to the value [50deg].

When should I choose [mod()](#funcdef-mod) vs [rem()](#funcdef-rem)?

Typically, users of this operation are in control of the step value (B),
and are modifying an unknown value A. As a result, it's *usually* more
expected that the result is between 0 and B, regardless of A's sign,
meaning [mod()](#funcdef-mod) should be chosen.

For example, if an author wants to know whether a length is an even or
odd number of pixels, [mod(A, 2px)] will return either [0px]
or [1px] (assuming the value is a whole number of pixels to begin
with), regardless of the value of a. [rem(A, 2px)], on the other
hand, will return [0px] if A is an even number of pixels, but will
return *either* [1px] or [-1px] if it's odd, depending on
whether A is positive or negative.

The opposite situation does sometimes occur, however, and so
[rem()](#funcdef-rem) is
provided to cater to that. As well, [rem()]
is the behavior of JavaScript's `%` operator, so if an exact
match between CSS and JS code is desired, [rem()] can be useful.

 [mod()](#funcdef-mod) and [rem()](#funcdef-rem) can also be defined directly in terms of other
functions: [mod(A, B)] is equivalent to [calc(A -
sign(B)\*round(down, A\*sign(B), B))] (a hacky way to say
\"round(down) when B is positive, round(up) when B is negative), while
[rem(A, B)] is equivalent to [calc(A - round(to-zero, A,
B))]. (These expressions don't always handle 0⁺ and 0⁻ correctly,
though, because 0⁻ semantics aren't commutative for addition.)

#### 10.3.1. Argument Ranges

In [round(A, B)], if B is 0, the result is NaN. If A and B are
both infinite, the result is NaN.

If A is infinite but B is finite, the result is the same infinity.

If A is finite but B is infinite, the result depends on the
[\<rounding-strategy\>](#typedef-rounding-strategy) and the sign of A:

[nearest](#valdef-rounding-strategy-nearest)\
[to-zero](#valdef-rounding-strategy-to-zero)

: If A is positive or 0⁺, return 0⁺. Otherwise, return 0⁻.

[up](#valdef-rounding-strategy-up)

: If A is positive (not zero), return +∞. If A is 0⁺, return 0⁺.
 Otherwise, return 0⁻.

[down](#valdef-rounding-strategy-down)

: If A is negative (not zero), return −∞. If A is 0⁻, return 0⁻.
 Otherwise, return 0⁺.

In [mod(A, B)] or [rem(A, B)], if B is 0, the result is NaN.
If A is infinite, the result is NaN.

In [mod(A, B)] only, if B is infinite and A has opposite sign to B
(including an oppositely-signed zero), the result is NaN.

 All other \"infinite B\" cases are valid, and just
return A immediately.

### 10.4. Trigonometric Functions: [sin(), [cos()](#funcdef-cos), [tan()](#funcdef-tan), [asin()](#funcdef-asin), [acos()](#funcdef-acos), [atan()](#funcdef-atan), and [atan2()](#funcdef-atan2)]
The trigonometric
functions---​[sin()](#funcdef-sin), [cos()](#funcdef-cos), [tan()](#funcdef-tan), [asin()](#funcdef-asin), [acos()](#funcdef-acos), [atan()](#funcdef-atan), and
[atan2()](#funcdef-atan2)---​compute the various basic trigonometric
relationships.

The [sin(A)], [cos(A)], and [tan(A)]
functions all contain a single
[calculation](#calc-calculation) which must resolve to either a
[\<number\>](#number-value) or an [\<angle\>](#angle-value), and compute their corresponding
function by interpreting the result of their argument as radians. (That
is, [sin(45deg)], [sin(.125turn)], and [sin(3.14159 /
4)] all represent the same value, approximately [.707].)
They all represent a [\<number\>],
with the return type [made
consistent](#css-make-a-type-consistent) with the input
[calculation's] type.
[sin()](#funcdef-sin) and
[cos()](#funcdef-cos) will
always return a number between −1 and 1, while
[tan()](#funcdef-tan) can
return any number between −∞ and +∞. (See [§ 10.9 Type
Checking](#calc-type-checking) for details on how [math
functions](#math-function)
handle ∞.)

The [asin(A)], [acos(A)], and [atan(A)]
functions are the \"arc\" or \"inverse\" trigonometric functions,
representing the inverse function to their corresponding \"normal\" trig
functions. All of them contain a single
[calculation](#calc-calculation) which must resolve to a
[\<number\>](#number-value), and compute their corresponding function,
interpreting their result as a number of radians, representing an
[\<angle\>](#angle-value) with the return type [made
consistent](#css-make-a-type-consistent) with the input
[calculation's] type. The angle returned by
[asin()](#funcdef-asin)
must be normalized to the range \[[-90deg], [90deg]\]; the
angle returned by [acos()](#funcdef-acos) to the range \[[0deg], [180deg]\]; and
the angle returned by [atan()](#funcdef-atan) to the range \[[-90deg], [90deg]\].

The [atan2(A, B)] function contains two
comma-separated
[calculations](#calc-calculation), A and B. A and B can resolve to any
[\<number\>](#number-value),
[\<dimension\>](#typedef-dimension), or
[\<percentage\>](#percentage-value), but must have a [consistent
type](#css-consistent-type) or else the function is invalid. The function returns
the [\<angle\>](#angle-value) between the positive X-axis and the point (B,A), with
the return type [made
consistent](#css-make-a-type-consistent) with the input
[calculation's] type. The returned angle
must be normalized to the interval ([-180deg], [180deg]\]
(that is, greater than [-180deg], and less than or equal to
[180deg]).

 [atan2(Y, X)] is *generally* equivalent to
[atan(Y / X)], but it gives a better answer when the point in
question may include negative components. [atan2(1, -1)],
corresponding to the point (-1, 1), returns [135deg], distinct
from [atan2(-1, 1)], corresponding to the point (1, -1), which
returns [-45deg]. In contrast, [atan(1 / -1)] and [atan(-1 /
1)] both return[-45deg], because the internal calculation
resolves to [-1] for both.

#### 10.4.1. Argument Ranges

In [sin(A)], [cos(A)], or [tan(A)], if A is infinite,
the result is NaN. (See [§ 10.9 Type Checking](#calc-type-checking) for
details on how [math functions](#math-function) handle NaN.)

In [sin(A)] or [tan(A)], if A is 0⁻, the result is 0⁻.

In [tan(A)], if A is one of the asymptote values (such as
[90deg], [270deg], etc), the numeric result is
[implementation-defined](https://infra.spec.whatwg.org/#implementation-defined). If an implementation is capable of exactly
representing these inputs, it *should* return +∞ for the asymptotes at
`90deg + N*360deg`, and −∞ for the asymptotes at
`-90deg + N*360deg`, but implementations are not required to
be able to exactly represent these inputs (and if they can't, will
return whatever the correct numeric answer is for the closest
approximation to the input they are capable of representing). Authors
*must not* rely on [tan()](#funcdef-tan) returning any particular value for these inputs.

Why are these
[implementation-defined](https://infra.spec.whatwg.org/#implementation-defined)?

The tangent function is *discontinuous* at its asymptotes: it approaches
infinity from one side *and* negative infinity from the other side, and
isn't defined at the exact values of the asymptote.

Further, whether or not the asymptotic values are exactly representable
in implementations depends on how they internally store and manipulate
angles; when written in degrees the values are simple ([90deg],
etc), but in radians the values are transcendental ([pi / 2], etc)
and cannot be exactly represented. So, even defining a specific behavior
for these values is difficult; if an implementation uses radians
internally, it would have to do some fuzzy matching to return the
defined value when the input is *sufficiently close* to the asymptote.

The other major language for the Web, JavaScript, exposes these
functions as taking radians only, so it can't hit the exact asymptotes
either (and this true for most other computer languages, too). Authors
writing code in JS, then, can't rely on any specific behavior for these
values either, and it's unlikely that their needs in CSS are
significantly different.

The suggested behavior for implementations that can exactly represent
the asymptote values preserves round-tripping with the
[atan()](#funcdef-atan)
function: [tan(atan(X))] and [atan(tan(X))] will both return
(approximately) X for all possible X values, given this definition. It
also means that within the supported output range of
[atan()], the function is continuous.

In [asin(A)] or [acos(A)], if A is less than -1 or greater
than 1, the result is NaN.

In [acos(A)], if A is exactly 1, the result is 0.

In [asin(A)] or [atan(A)], if A is 0⁻, the result is 0⁻.

In [atan(A)], if A is +∞, the result is [90deg]; if A is −∞,
the result is [-90deg].

In [atan2(Y, X)], the following table gives the results for all
unusual argument combinations:

X

−∞

-finite

0⁻

0⁺

+finite

+∞

Y

−∞

-135deg

-90deg

-90deg

-90deg

-90deg

-45deg

-finite

-180deg

(normal)

-90deg

-90deg

(normal)

0⁻deg

0⁻

-180deg

-180deg

-180deg

0⁻deg

0⁻deg

0⁻deg

0⁺

180deg

180deg

180deg

0⁺deg

0⁺deg

0⁺deg

+finite

180deg

(normal)

90deg

90deg

(normal)

0⁺deg

+∞

135deg

90deg

90deg

90deg

90deg

45deg

 All of these behaviors are intended to match the
\"standard\" definitions of these functions as implemented by most
programming languages, in particular as implemented in JS.

### 10.5. Exponential Functions: [pow(), [sqrt()](#funcdef-sqrt), [hypot()](#funcdef-hypot), [log()](#funcdef-log), [exp()](#funcdef-exp)]
The exponential functions---​[pow()](#funcdef-pow), [sqrt()](#funcdef-sqrt),
[hypot()](#funcdef-hypot), [log()](#funcdef-log), and [exp()](#funcdef-exp)---​compute various exponential functions with their
arguments.

The [pow(A, B)] function contains two comma-separated
[calculations](#calc-calculation) A and B, both of which must resolve to
[\<number\>](#number-value)s, and returns the result of raising A to the power of
B, returning the value as a [\<number\>]. The input [calculations] must
have a [consistent
type](#css-consistent-type) or else the function is invalid; the result's type will
be the [consistent type].

The [sqrt(A)] function contains a single
[calculation](#calc-calculation) which must resolve to a
[\<number\>](#number-value), and returns the square root of the value as a
[\<number\>], with the return type
[made
consistent](#css-make-a-type-consistent) with the input
[calculation's] type. ([sqrt(X)] and
[pow(X, .5)] are basically equivalent, differing only in some
error-handling; [sqrt()](#funcdef-sqrt) is a common enough function that it is provided as a
convenience.)

The [hypot(A, ...)] function contains one or
more comma-separated
[calculations](#calc-calculation), and returns the length of an N-dimensional vector with
components equal to each of the
[calculations]. (That is, the square root
of the sum of the squares of its arguments.) The argument
[calculations] can resolve to any
[\<number\>](#number-value),
[\<dimension\>](#typedef-dimension), or
[\<percentage\>](#percentage-value), but must have a [consistent
type](#css-consistent-type) or else the function is invalid; the result's type will
be the [consistent type].

Why does [hypot()](#funcdef-hypot) allow dimensions (values with units), but
[pow()](#funcdef-pow) and
[sqrt()](#funcdef-sqrt)
only work on numbers?

You are allowed to write expressions like [hypot(30px, 40px)],
which resolves to [50px], but you aren't allowed to write the
expression [sqrt(pow(30px, 2) + pow(40px, 2))], despite the two
being equivalent in most mathematical systems.

There are two reasons for this: numeric precision in the exponents, and
clashing expectations from authors.

First, numerical precision. For a
[type](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-type) to
[match](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-match) a CSS production like
[\<length\>](#length-value), it needs to have a single unit with its exponent set
to exactly 1. Theoretically, expressions like [pow(pow(30px, 3),
1/3)] should result in exactly that: the inner [pow(30px,
3)] would resolve to a value of 27000 with a
[type] of «\[ \"length\" → 3 \]» (aka
[\<length\>]³), and then the
[pow(X, 1/3)] would cube-root the value back down to 30 and
multiply the exponent by 1/3, giving «\[ \"length\" → 1 \]», which
[matches]
[\<length\>].

In the realm of pure mathematics, that's guaranteed to work out; in the
real-world of computers using binary floating-point arithmetic, in some
cases the powers might not exactly cancel out, leaving you with an
invalid [math function](#math-function) for confusing, hard-to-track-down reasons. (For a JS
example, evaluate `Math.pow(Math.pow(30, 10/3), .1+.1+.1)`;
the result is not exactly 30, because `.1+.1+.1` is not
exactly 3/10. Instead, `(10/3) * (.1 + .1 + .1)` is
*slightly greater* than 1.)

Requiring authors to cast their value down into a number, do all the
math on the raw number, then finally send it back to the desired unit,
while inconvenient, ensures that numerical precision won't bite anyone:
[calc(pow(pow(30px / 1px, 3), 1/3) \* 1px)] is guaranteed to
resolve to a [\<length\>](#length-value), with a value that, if not exactly 30, is
at least very close to 30, even if numerical precision actually prevents
the powers from exactly canceling.

Second, clashing expectations. It's not uncommon for authors to expect
[pow(30px, 2)] to result in [900px] (such as in [this Sass
issue](https://github.com/sass/sass/issues/684)); that is, just squaring
the numerical value and leaving the unit alone. This, however, means the
result is dependent on what unit you're expressing the argument in; if
[1em] is [16px], then [pow(1em, 2)] would give
[1em], while [pow(16px, 2)] would give [256px], or
[16em], which are very different values for what should otherwise
be identical input arguments! This sort of input dependency is
troublesome for CSS, which generally allows values to be
[canonicalized](#canonical-unit) freely; it also makes more complex expressions like
[pow(2em + 10px, 2)] difficult to interpret.

Again, requiring authors to cast their value down into a number and then
back up again into the desired unit sidesteps these issues; [pow(30,
2)] is indeed [900], and the author can interpret that
however they wish.

------------------------------------------------------------------------

On the other hand, [hypot()](#funcdef-hypot) doesn't suffer from these problems. Numerical
precision in units isn't a concern, as the inputs and output all have
the same type. The result isn't unit-dependent, either, due to the
nature of the operation; [hypot(3em, 4em)] and [hypot(48px,
64px)] both result in the same length when [1em] equals
[16px]: [5em] or [80px]. Thus it's fine to let author
use dimensions directly in [hypot()].

The [log(A, B?)] function contains one or two
[calculations](#calc-calculation) (representing the value to be logarithmed, and the base
of the logarithm, defaulting to e), which must resolve to
[\<number\>](#number-value)s, and returns the logarithm base B of the value A, as
a [\<number\>] with the return type
[made
consistent](#css-make-a-type-consistent) with the input
[calculation's] type.

The [exp(A)] function contains one
[calculation](#calc-calculation) which must resolve to a
[\<number\>](#number-value), and returns the same value as [pow(e, A)] as a
[\<number\>] with the return type
[made
consistent](#css-make-a-type-consistent) with the input
[calculation's] type.

The
[pow()](#funcdef-pow)
function can be useful for strategies like [CSS Modular
Scale](https://www.modularscale.com/), which relates all the font-sizes
on a page to each other by a fixed ratio.

These sizes can be easily written into custom properties like:

```
:root {
 --h6: calc(1rem * pow(1.5, -1));
 --h5: calc(1rem * pow(1.5, 0));
 --h4: calc(1rem * pow(1.5, 1));
 --h3: calc(1rem * pow(1.5, 2));
 --h2: calc(1rem * pow(1.5, 3));
 --h1: calc(1rem * pow(1.5, 4));
}
```

\...rather than writing out the values in pre-calculated numbers like
[5.0625rem] (what [calc(1rem \* pow(1.5, 4))] resolves to)
which have less clear provenance when encountered in a stylesheet.

With a single argument,
[hypot()](#funcdef-hypot) gives the absolute value of its input;
[hypot(2em)] and [hypot(-2em)] both resolve to [2em].

With more arguments, it gives the size of the main diagonal of a box
whose side lengths are given by the arguments. This can be useful for
transform-related things, giving the distance that an element will
actually travel when it's translated by a particular X, Y, and Z amount.

For example, [hypot(30px, 40px)] resolves to [50px], which
is indeed the distance between an element's starting and ending
positions when it's translated by a [translate(30px, 40px)]
transform. If an author wanted elements to get smaller as they moved
further away from their starting point (drawing some sort of word cloud,
for example), they could then use this distance in their scaling factor
calculations.

With a single argument,
[log()](#funcdef-log)
provides the "natural log" of its argument, or the log base e, same as
JavaScript.

If one instead wants log base 10 (to, for example, count the number of
digits in a value) or log base 2 (counting the number of bits in a
value), [log(X, 10)] or [log(X, 2)] provide those values.

#### 10.5.1. Argument Ranges

In [pow(A, B)], if A is negative and finite, and B is finite, B
must be an integer, or else the result is NaN.

If A or B are infinite or 0, the following tables give the results:

A is −∞

A is 0⁻

A is 0⁺

A is +∞

B is −finite

0⁻ if B is an odd integer, 0⁺ otherwise

−∞ if B is an odd integer, +∞ otherwise

+∞

0⁺

B is 0

always 1

B is +finite

−∞ if B is an odd integer, +∞ otherwise

0⁻ if B is an odd integer, 0⁺ otherwise

0⁺

+∞

A is \< -1

A is -1

-1 \< A \< 1

A is 1

A is \> 1

B is +∞

result is +∞

result is NaN

result is 0⁺

result is NaN

result is +∞

B is −∞

result is 0⁺

result is NaN

result is +∞

result is NaN

result is 0⁺

In [sqrt(A)], if A is +∞, the result is +∞. If A is 0⁻, the result
is 0⁻. If A is less than 0, the result is NaN.

In [hypot(A, ...)], if any of the inputs are infinite, the result
is +∞.

In [log(A, B)], if B is 1 or negative, [ B values *between* 0 and
1, or greater than 1, are valid. ] the result is NaN. If A is
negative, the result is NaN. If A is 0⁺ or 0⁻, the result is −∞. If A is
1, the result is 0⁺. If A is +∞, the result is +∞.

In [exp(A)], if A is +∞, the result is +∞. If A is −∞, the result
is 0⁺.

(See [§ 10.9 Type Checking](#calc-type-checking) for details on how
[math functions](#math-function) handle NaN and infinities.)

All of these behaviors are intended to match the \"standard\"
definitions of these functions as implemented by most programming
languages, in particular as implemented in JS.

The only divergences from the behavior of the equivalent JS functions
are that NaN is \"infectious\" in *every* function, forcing the function
to return NaN if any argument calculation is NaN.

Details of the JS Behavior

There are two cases in JS where a NaN is not \"infectious\" to the math
function it finds itself in:

- `Math.hypot(Infinity, NaN)` will return
 `Infinity`.

- `Math.pow(NaN, 0)` will return `1`.

The logic appears to be that, if you replace the NaN with *any* Number,
the return value will be the same. However, this logic is not applied
consistently to the `Math` functions:
`Math.max(Infinity, NaN)` returns `NaN`, not
`Infinity`; the same is true of
`Math.min(-Infinity, NaN)`.

Because this is an error corner case, JS isn't consistent on the matter,
and NaN recognition/handling of
[calculations](#calc-calculation) is likely done at a higher CSS level rather than in the
internal math functions anyway, consistency in CSS was chosen to be more
important, so all functions were defined to have \"infectious\" NaN.

### 10.6. Sign-Related Functions: [abs(), [sign()](#funcdef-sign)]
The sign-related functions---​[abs()](#funcdef-abs) and
[sign()](#funcdef-sign)---​compute various functions related to the sign of
their argument.

The [abs(A)] function contains one
[calculation](#calc-calculation) A, and returns the absolute value of A, as the same
[type](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-type) as the input: if A's numeric value is positive or 0⁺,
just A again; otherwise [-1 \* A].

The [sign(A)] function contains one
[calculation](#calc-calculation) A, and returns -1 if A's numeric value is negative, +1
if A's numeric value is positive, 0⁺ if A's numeric value is 0⁺, and 0⁻
if A's numeric value is 0⁻. The return type is a
[\<number\>](#number-value), [made
consistent](#css-make-a-type-consistent) with the input
[calculation's] type.

 Both of these functions operate on the fully
simplified/resolved form of their arguments, which may give unintuitive
results at first glance. In particular, an expression like [10%]
might be positive *or* negative once it's resolved, depending on what
value it's resolved against. For example, in
[background-position](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-position) positive percentages resolve to a
negative length, and vice versa, if the background image is larger than
the background area. Thus [sign(10%)] might return [1] *or*
[-1], depending on how the percentage is resolved! (Or even
[0], if it's resolved against a zero length.)

### 10.7. Numeric Keywords

Keywords in
[calculations](#calc-calculation) provide access to values that are difficult or
impossible to represent as literals. Each keyword defines its value, its
[type](#determine-the-type-of-a-calculation), and when it can be resolved.

#### 10.7.1. Numeric Constants: [e, [pi](#valdef-calc-pi)]
While the trigonometric and exponential functions handle many complex
numeric operations, some reasonable calculations must be put together
more manually, and many times these include well-known constants, such
as *e* and *π*.

Rather than require authors to manually type out several digits of these
constants, a few of them are provided directly:

[e]

: the base of the natural logarithm, approximately equal to
 2.7182818284590452354.

[pi]

: the ratio of a circle's circumference to its diameter, approximately
 equal to 3.1415926535897932.

Both of these keywords are
[\<number\>](#number-value)s, and resolve at parse time.

 These keywords are only usable within a calculation,
such as [calc(pow(e, pi) - pi)], or [min(pi, 5, e)]. If used
outside of a calculation, they're treated like any other keyword:
[animation-name:
pi;](https://drafts.csswg.org/css-animations-1/#propdef-animation-name) refers to an animation named \"pi\";
[line-height:
e;](https://drafts.csswg.org/css2/#propdef-line-height) is invalid (*not* similar to [line-height:
2.7], but [line-height:
calc(e);] is).

#### 10.7.2. Degenerate Numeric Constants: [infinity, [[-infinity](#valdef-calc--infinity)]{style=";white-space:nowrap"}, [NaN](#valdef-calc-nan)]
When a [calculation](#calc-calculation) or a subtree of a
[calculation] becomes
[infinite](#css-infinity) or
[NaN](#css-nan), representing it with
a numeric value is no longer possible. A UA may have an
[implementation-defined limit for values approaching
infinity].

To aid in serialization of these degenerate values, the following
additional math constants are defined:

[infinity]

: the value positive infinity (+∞)

[-infinity]

: the value negative infinity (−∞)

[NaN]

: the value NaN

All of these keywords are
[\<number\>](#number-value)s, and resolve at parse time.

As usual for CSS keywords, these are [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive). [ Thus, [calc(InFiNiTy)] is perfectly valid.
] However, [NaN](#valdef-calc-nan) must be serialized with this canonical casing.

 As these keywords are
[\<number\>](#number-value)s, to get an infinite length, for example, requires an
expression like [calc(infinity \* 1px)].

 These constants are defined *mostly* to make
serialization of infinite/NaN values simpler and more obvious, but *can*
be used to indicate a \"largest possible value\", since an infinite
value gets clamped to the allowed range. It's rare for this to be
reasonable, but when it is, using
[infinity](#valdef-calc-infinity) is clearer in its intent than just putting an
enormous number in one's stylesheet.

#### 10.7.3. Numeric Variables

Other specifications can define additional keywords which are usable in
[calculations](#calc-calculation) in certain contexts. For example, [relative
color](https://drafts.csswg.org/css-color-5/#relative-color) syntax defines a number of color-channel keywords
representing the value of each color channel as a
[\<number\>](#number-value).

Each specifications defining such keywords must define for each keyword:

- its value

- its
 [type](#determine-the-type-of-a-calculation) ([\<number\>](#number-value),
 [\<length\>](#length-value), etc)

- when it resolves (parse time, computed-value time, or used-value time)

### 10.8. Syntax

The syntax of a [math function](#math-function) is:

```
<calc()> = calc( <calc-sum> )
<min()> = min( <calc-sum># )
<max()> = max( <calc-sum># )
<clamp()> = clamp( [ <calc-sum> | none ], <calc-sum>, [ <calc-sum> | none ] )
<round()> = round( <rounding-strategy>?, <calc-sum>, <calc-sum>? )
<mod()> = mod( <calc-sum>, <calc-sum> )
<rem()> = rem( <calc-sum>, <calc-sum> )
<sin()> = sin( <calc-sum> )
<cos()> = cos( <calc-sum> )
<tan()> = tan( <calc-sum> )
<asin()> = asin( <calc-sum> )
<acos()> = acos( <calc-sum> )
<atan()> = atan( <calc-sum> )
<atan2()> = atan2( <calc-sum>, <calc-sum> )
<pow()> = pow( <calc-sum>, <calc-sum> )
<sqrt()> = sqrt( <calc-sum> )
<hypot()> = hypot( <calc-sum># )
<log()> = log( <calc-sum>, <calc-sum>? )
<exp()> = exp( <calc-sum> )
<abs()> = abs( <calc-sum> )
<sign()> = sign( <calc-sum> )
<calc-sum> = <calc-product> [ [ '+' | '-' ] <calc-product> ]*
<calc-product> = <calc-value> [ [ '*' | / ] <calc-value> ]*
<calc-value> = <number> | <dimension> | <percentage> |
 <calc-keyword> | ( <calc-sum> )
<calc-keyword> = e | pi | infinity | -infinity | NaN
<rounding-strategy> = nearest | up | down | to-zero | line-width
```

In some contexts, additional
[\<calc-keyword\>](#typedef-calc-keyword) values can be defined to be valid.
(For example, in [relative
color](https://drafts.csswg.org/css-color-5/#relative-color) syntax, appropriate channel keywords are allowed.)

In addition,
[whitespace](https://drafts.csswg.org/css-syntax-3/#whitespace) is required on both sides of the [+] and
[-] operators. (The [\*] and [/] operators can be used
without white space around them.)

Several of the math functions above have additional constraints on what
their [\<calc-sum\>](#typedef-calc-sum) arguments can contain. Check the
definitions of the individual functions for details.

UAs must support
[calculations](#calc-calculation) of at least 32
[\<calc-value\>](#typedef-calc-value) terms and at least 32 levels of nesting
(parentheses and/or functions). For functions that support an arbitrary
number of arguments (such as [min()](#funcdef-min)), it must also support at least 32 arguments. If
a [calculation] contains more than the
supported number of terms, arguments, or nesting it must be treated as
if it were invalid.

### 10.9. Type Checking

A [math function](#math-function) can be many possible types, such as
[\<length\>](#length-value), [\<number\>](#number-value), etc., depending on the
[calculations](#calc-calculation) it contains, as defined below. It can be used anywhere
a value of that type is allowed.

For example, the
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width) property accepts
[\<length\>](#length-value) values, so a [math
function](#math-function) that
resolves to a [\<length\>], such as
[calc(5px + 1em)], can be used in [width].

Additionally, [math functions](#math-function) that resolve to
[\<number\>](#number-value) can be used in any place that only accepts
[\<integer\>](#integer-value); the value is [rounded to the nearest
integer](#css-round-to-the-nearest-integer) as it resolves.

Operators form sub-expressions, which gain types based on their
arguments.

 In previous versions of this specification,
multiplication and division were limited in what arguments they could
take, to avoid producing more complex intermediate results (such as [1px
\* 1em], which is
[\<length\>](#length-value)²) and to make division-by-zero detectable at parse
time. This version now relaxes those restrictions.

To [determine the type of a
[calculation](#calc-calculation)]:

- At a [+] or [-] sub-expression, attempt to [add the
 types](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-add-two-types) of the left and right arguments. If this returns
 failure, the entire
 [calculation's](#calc-calculation) type is failure. Otherwise, the sub-expression's
 [type](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-type) is the returned type.

- At a [\*] sub-expression, [multiply the
 types](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-multiply-two-types) of the left and right arguments. The sub-expression's
 [type](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-type) is the returned result.

- At a [/] sub-expression, let `left type` be the
 result of finding the
 [types](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-type) of its left argument, and `right type` be
 the result of finding the [types] of
 its right argument and then
 [inverting](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-invert-a-type) it.

 The sub-expression's
 [type](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-type) is the result of
 [multiplying](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-multiply-two-types) the `left type` and
 `right type`.

- Anything else is a terminal value, whose
 [type](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-type) is determined based on its CSS type. (Unless
 otherwise specified, the type's associated [percent
 hint](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-percent-hint) is null.)

 [\<number\>](#number-value)\
 [\<integer\>](#integer-value)

 : the
 [type](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-type) is «\[ \]» (empty map)

 [\<length\>](#length-value)

 : the
 [type](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-type) is «\[ \"length\" → 1 \]»

 [\<angle\>](#angle-value)

 : the
 [type](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-type) is «\[ \"angle\" → 1 \]»

 [\<time\>](#time-value)

 : the
 [type](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-type) is «\[ \"time\" → 1 \]»

 [\<frequency\>](#frequency-value)

 : the
 [type](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-type) is «\[ \"frequency\" → 1 \]»

 [\<resolution\>](#resolution-value)

 : the
 [type](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-type) is «\[ \"resolution\" → 1 \]»

 [\<flex\>](https://drafts.csswg.org/css-grid-2/#typedef-flex)

 : the
 [type](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-type) is «\[ \"flex\" → 1 \]»

 [\<calc-keyword\>](#typedef-calc-keyword)

 : the
 [type](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-type) is as defined by the keyword

 [\<percentage\>](#percentage-value)

 : If, in the context in which the [math
 function](#math-function) containing this
 [calculation](#calc-calculation) is placed,
 [\<percentage\>](#percentage-value)s are resolved relative to
 another type of value (such as in
 [width](https://drafts.csswg.org/css-sizing-3/#propdef-width), where
 [\<percentage\>] is
 resolved against a
 [\<length\>](#length-value)), and that other type is *not*
 [\<number\>](#number-value), the
 [type](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-type) is determined as the other type, but with a
 [percent
 hint](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-percent-hint) set to that other type.

 Otherwise, the
 [type](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-type) is «\[ \"percent\" → 1 \]», with a [percent
 hint](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-percent-hint) of \"percent\".

 anything else

 : The [calculation's](#calc-calculation) type is failure.

A value [contains a percentage] if its
[type](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-type) is «\[ \"percent\" → 1 \]», or its type's [percent
hint](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-percent-hint) is non-null.

Two or more calculations have a [consistent type] if [adding the
types](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-add-two-types) doesn't result in failure. The [consistent
type](#css-consistent-type) is the result of the type addition.

To [make a type `base`
consistent] with
another type `input`:

1. If both `base` and `input` have different
 non-null [percent
 hints](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-percent-hint), they can't be made consistent. Return failure.

2. If `base` has a null [percent
 hint](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-percent-hint) set `base`'s [percent
 hint] to
 `input`'s [percent
 hint].

3. Return `base`.

[Math functions](#math-function) themselves have
[types](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-type), according to their contained
[calculations](#calc-calculation):

[calc()](#funcdef-calc)\
[abs()](#funcdef-abs)

: The
 [type](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-type) of its contained
 [calculation](#calc-calculation).

[min()](#funcdef-min)\
[max()](#funcdef-max)\
[clamp()](#funcdef-clamp)\
[hypot()](#funcdef-hypot)\
[round()](#funcdef-round)\
[mod()](#funcdef-mod)\
[rem()](#funcdef-rem)

: The result of [adding the
 types](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-add-two-types) of its comma-separated
 [calculations](#calc-calculation).

[asin()](#funcdef-asin)\
[acos()](#funcdef-acos)\
[atan()](#funcdef-atan)\
[atan2()](#funcdef-atan2)

: «\[ \"angle\" → 1 \]».

[sign()](#funcdef-sign)\
[sin()](#funcdef-sin)\
[cos()](#funcdef-cos)\
[tan()](#funcdef-tan)\
[pow()](#funcdef-pow)\
[sqrt()](#funcdef-sqrt)\
[log()](#funcdef-log)\
[exp()](#funcdef-exp)

: «\[ \]» (empty map).

For each of the above, if the
[type](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-type) is failure, the [math
function](#math-function) is
invalid.

A [math function](#math-function) resolves to
[\<number\>](#number-value), [\<length\>](#length-value),
[\<angle\>](#angle-value), [\<time\>](#time-value),
[\<frequency\>](#frequency-value),
[\<resolution\>](#resolution-value),
[\<flex\>](https://drafts.csswg.org/css-grid-2/#typedef-flex), or
[\<percentage\>](#percentage-value) according to which of those productions
its
[type](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-type)
[matches](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-match). (These categories are mutually exclusive.) If it can't
[match] any of these, the [math
function] is invalid.

 Algebraic simplifications do not affect the validity of
a [math function](#math-function) or its resolved type. For example, [calc(5px - 5px +
10s)] and [calc(0 \* 5px + 10s)] are both invalid due to the
attempt to add a length and a time.

 Note that
[\<percentage\>](#percentage-value)s relative to
[\<number\>](#number-value)s, such as in
[opacity](https://drafts.csswg.org/css-color-4/#propdef-opacity), are not *combinable* with those
numbers---​[opacity: calc(.25 + 25%)] is
invalid. Allowing this causes significant problems with \"unit algebra\"
(allowing multiplication/division of
[\<dimension\>](#typedef-dimension)s), and in every case so far, doesn't
provide any new functionality. (For example, [opacity:
25%] is identical to [opacity:
.25]; it's just a trivial syntax
transform.) You can still perform other operations with them, such as
[opacity: calc(100% / 3);], which is
valid.

 Because
[\<number-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-number-token)s are always interpreted as
[\<number\>](#number-value)s or
[\<integer\>](#integer-value)s, \"unitless 0\"
[\<length\>](#length-value)s aren't supported in [math
functions](#math-function).
That is, [width: calc(0 +
5px);](https://drafts.csswg.org/css-sizing-3/#propdef-width) is invalid, because it's trying to add a
[\<number\>] to a
[\<length\>], even though both
[width: 0;] and [width:
5px;] are valid.

 Although there are a few properties in which a bare
[\<number\>](#number-value) becomes a
[\<length\>](#length-value) at used-value time (specifically,
[line-height](https://drafts.csswg.org/css2/#propdef-line-height) and
[tab-size](https://drafts.csswg.org/css-text-4/#propdef-tab-size)),
[\<number\>]s never become
\"length-like\" in [calc()](#funcdef-calc). They always stay as
[\<number\>]s.

 In Quirks Mode
[\[QUIRKS\]](#biblio-quirks "Quirks Mode Standard"),
some properties that would normally only accept
[\<length\>](#length-value)s are defined to also accept
[\<number\>](#number-value)s, interpreting them as [px](#px) lengths. Like unitless zeroes, this has no effect on
the parsing or behavior of [math
functions](#math-function),
though a [math function] that resolves to a
[\<number\>] value might become
valid in Quirks Mode (and have its result interpreted as a
[px] length).

#### 10.9.1. Calculation Contexts

Numeric values can be interpreted in various [calculation
contexts], depending on where they are used, which defines how
[\<percentage\>](#percentage-value) values resolve, etc.

For example, in
[top](https://drafts.csswg.org/css-position-3/#propdef-top), a
[\<percentage\>](#percentage-value) value is resolved against the size of the
containing block, making it act as a
[\<length\>](#length-value). A single property can define multiple [calculation
contexts](#calculation-contexts); for example, in
[background-size](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-size) one value resolves
[\<percentage\>]s against the
width of the [background positioning
area](https://drafts.csswg.org/css-backgrounds-3/#background-positioning-area) while the other resolves them against the height.

[Math functions](#math-function) always inherit the [calculation
context](#calculation-contexts) from wherever they're used. That is, in [top:
calc(25% +
50px)](https://drafts.csswg.org/css-position-3/#propdef-top), the
[\<percentage\>](#percentage-value) is resolved *as normal* for
[top], as if [top:
25%] were specified (and then has
[50px] added to its value).

Unless otherwise defined, all other functions **do not inherit a
[calculation
context](#calculation-contexts)**, and instead define their own [calculation
contexts](#calculation-contexts) for their numeric arguments. For example, in [top:
anchor(25%)](https://drafts.csswg.org/css-position-3/#propdef-top), the
[\<percentage\>](#percentage-value) in the
[anchor()](https://drafts.csswg.org/css-anchor-position-1/#funcdef-anchor) function is instead defined to resolve in a
completely different manner (against the height of the default anchor
element).

#### 10.9.2. Infinities, NaN, and Signed Zero

[Math functions](#math-function) follow IEEE-754 semantics, which means they recognize
the concepts of positive and negative zero, positive and negative
infinity, and NaN (not a number).

However, these concepts are only retained within a [calculation
tree](#calculation-tree); if
a [top-level calculation] (a [math
function](#math-function) not
nested directly inside of another [math
function]) would result in one of these
special values, they're instead \"censored\" into a standard
representable value, as defined below.

[Signed zeros]
(indicated here as 0⁺ or 0⁻) can not be written directly in CSS;
[0], [+0] and [-0] all produce the standard
\"unsigned\" zero, which is considered positive (0⁺) for the purposes of
these rules.

[Signed zeroes](#css-signed-zero) are produced in the following ways:

- Negative zero (0⁻) can be produced by a multiplication or division
 that produces zero with exactly one negative argument (such as [-5 \*
 0] or [1 / -infinity]).

- [0⁻ + 0⁻] or [0⁻ - 0⁺] produces 0⁻. All other additions or
 subtractions that would produce a zero produce 0⁺.

- Multiplying or dividing 0⁻ with a positive number (including 0⁺)
 produces a negative result (either 0⁻ or −∞), while multiplying or
 dividing 0⁻ with a negative number produces a positive result.

 (In other words, multiplying or dividing with 0⁻ follows standard sign
 rules.)

- When comparing 0⁺ and 0⁻, 0⁻ is less than 0⁺. For example, [min(0⁺,
 0⁻)] must produce 0⁻, [max(0⁺, 0⁻)] must produce 0⁺, and
 [clamp(0⁺, 0⁻, 1)] must produce 0⁺.

- Certain argument combinations in [math
 functions](#math-function)
 are defined to produce 0⁻ (for example, [round(-1, infinity)]).
 All other operations that produce a zero produce positive zero (0⁺).

[Signed zeroes](#css-signed-zero) do not escape a [top-level
calculation](#top-level-calculation); they're censored into the \"unsigned\" zero.

[Infinities] (indicated
here as +∞ or −∞) can be written directly using the [math
constants](#calc-error-constants)
[infinity](#valdef-calc-infinity) and
[-infinity](#valdef-calc--infinity), or produced as a result of some calculations:

- Dividing a value by zero produces either +∞ or −∞, according to the
 standard sign rules.

- Adding or subtracting ±∞ to anything produces the appropriate
 infinity.

- Multiplying any value by ±∞ produces the appropriate infinity.

- Dividing any value by ±∞ produces zero.

- Certain argument combinations in [math
 functions](#math-function)
 are defined to produce
 [infinities](#css-infinity)
 (for example, [pow(0, -1)] produces +∞).

 The rules for producing
[NaN](#css-nan), below, supersede the
above rules for producing
[infinities](#css-infinity).

[Infinities](#css-infinity) do
not escape a [top-level
calculation](#top-level-calculation); they're clamped to the minimum or maximum value
allowed in the context, as defined in [§ 10.12 Range
Checking](#calc-range).

[NaN]
(short for \"not a number\") is the result of certain operations that
don't have a well-defined value. It can be written directly using the
[math constants](#calc-error-constants)
[NaN](#valdef-calc-nan), or produced as a result of some calculations:

- Dividing zero by zero, dividing ±∞ by ±∞, multiplying 0 by ±∞, adding
 +∞ to −∞, or subtracting two infinities of the same sign produces NaN.

 These rules override any other result, if there's a conflict. For
 example, [0 / 0] is NaN, not +∞.

- Certain argument combinations in [math
 functions](#math-function)
 are defined to produce [NaN](#css-nan) (for example, [asin(2)] produces NaN).

- Any operation with at least one NaN argument produces NaN.

[NaN](#css-nan) does not escape a
[top-level
calculation](#top-level-calculation); it's censored into a zero value

For example, [calc(-5 \* 0)]
produces an unsigned zero---​the calculation resolves to 0⁻, but as it's
a [top-level
calculation](#top-level-calculation), it's then censored to an unsigned zero.

On the other hand, [calc(1 / calc(-5 \* 0))] produces −∞, same as
[calc(1 / (-5 \* 0))]---​the inner calc resolves to 0⁻, and as it's
not a [top-level
calculation](#top-level-calculation), it passes it up unchanged to the outer calc to produce
−∞. If it was censored into an unsigned zero, it would instead produce
+∞.

### 10.10. Internal Representation

The [internal
representation](https://drafts.css-houdini.org/css-typed-om-1/#css-internal-representation) of a [math
function](#math-function) is a
[calculation tree]: a tree where the branch nodes are [operator
nodes] corresponding
either to [math functions] (such as Min, Cos,
Sqrt, etc) or to operators in a
[calculation](#calc-calculation) (Sum, Product, Negate, and Invert, the [calc-operator
nodes]), and the leaf
nodes are either numeric values (such as numbers, dimensions, and
percentages) or non-[math functions] that
resolve to a numeric type.

[Math functions](#math-function) are turned into [calculation
trees](#calculation-tree)
depending on the function:

calc()

: The [internal
 representation](https://drafts.css-houdini.org/css-typed-om-1/#css-internal-representation) of a
 [calc()](#funcdef-calc) function is the result of [parsing a
 calculation](#parse-a-calculation) from its argument.

any other [math function](#math-function)

: The [internal
 representation](https://drafts.css-houdini.org/css-typed-om-1/#css-internal-representation) is an [operator
 node](#calculation-tree-operator-nodes) with the same name as the function, whose children
 are the result of [parsing a
 calculation](#parse-a-calculation) from each of the function's arguments, in the order
 they appear.

To [parse a calculation], given a
[calculation](#calc-calculation) `values` represented as a list of [component
values](https://drafts.csswg.org/css-syntax-3/#component-value), and returning a [calculation
tree](#calculation-tree):

1. Discard any
 [\<whitespace-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-whitespace-token)s from `values`.

2. An item in `values` is an "operator" if it's a
 [\<delim-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-delim-token) with the value \"+\", \"-\",
 \"\*\", or \"/\". Otherwise, it's a "value".

3. Collect children into Product and Invert nodes.

 For every consecutive run of value items in `values`
 separated by \"\*\" or \"/\" operators:

 1. For each \"/\" operator in the run, replace its right-hand value
 item `rhs` with an Invert node containing
 `rhs` as its child.

 2. Replace the entire run with a Product node containing the value
 items of the run as its children.

4. Collect children into Sum and Negate nodes.

 1. For each \"-\" operator item in `values`, replace its
 right-hand value item `rhs` with a Negate node
 containing `rhs` as its child.

 2. If `values` has only one item, and it is a Product
 node or a parenthesized [simple
 block](https://drafts.csswg.org/css-syntax-3/#simple-block), replace `values` with that item.

 Otherwise, replace `values` with a Sum node
 containing the value items of `values` as its
 children.

5. At this point `values` is a tree of Sum, Product, Negate,
 and Invert nodes, with other types of values at the leaf nodes.
 Process the leaf nodes.

 For every leaf node `leaf` in `values`:

 1. If `leaf` is a parenthesized [simple
 block](https://drafts.csswg.org/css-syntax-3/#simple-block), replace `leaf` with the result of
 [parsing a
 calculation](#parse-a-calculation) from `leaf`'s contents.

 2. If `leaf` is a [math
 function](#math-function), replace `leaf` with the [internal
 representation](https://drafts.css-houdini.org/css-typed-om-1/#css-internal-representation) of that math function.

6. Return the result of [simplifying a calculation
 tree](#simplify-a-calculation-tree) from `values`.

#### 10.10.1. Simplification

[Internal
representations](https://drafts.css-houdini.org/css-typed-om-1/#css-internal-representation) of [math
functions](#math-function) are
eagerly simplified to the extent possible, using standard algebraic
simplifications (distributing multiplication over sums, combining
similar units, etc.).

When used in non-property contexts (such as in
[\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule) descriptors, for example), [math
functions](#math-function) are
simplified as if they were [specified
values](https://drafts.csswg.org/css-cascade-5/#specified-value).

To [simplify a calculation tree]
`root`:

1. If `root` is a numeric value:

 1. If `root` is a percentage that will be resolved
 against another value, and there is enough information available
 to resolve it, do so, and express the resulting numeric value in
 the appropriate [canonical
 unit](#canonical-unit). Return the value.

 2. If `root` is a dimension that is not expressed in its
 [canonical unit](#canonical-unit), and there is enough information available to
 convert it to the [canonical unit],
 do so, and return the value.

 3. If `root` is a
 [\<calc-keyword\>](#typedef-calc-keyword) that can be resolved, return
 what it resolves to,
 [simplified](#simplify-a-calculation-tree).

 4. Otherwise, return `root`.

2. If `root` is any other leaf node (not an operator node):

 1. If there is enough information available to determine its
 numeric value, return its value, expressed in the value's
 [canonical unit](#canonical-unit).

 2. Otherwise, return `root`.

3. At this point, `root` is an [operator
 node](#calculation-tree-operator-nodes).
 [Simplify](#simplify-a-calculation-tree) all the
 [calculation](#calc-calculation) children of `root`.

4. If `root` is an [operator
 node](#calculation-tree-operator-nodes) that's not one of the [calc-operator
 nodes](#calculation-tree-calc-operator-nodes), and all of its
 [calculation](#calc-calculation) children are numeric values with enough information
 to compute the operation `root` represents, return the
 result of running `root`'s operation using its children,
 expressed in the result's [canonical
 unit](#canonical-unit).

 :::
 If a percentage is left at this point, it will *usually* block
 simplification of the node, since it needs to be resolved against
 another value using information not currently available. (Otherwise,
 it would have been converted to a different value in an earlier
 step.) This includes operations such as \"min\", since percentages
 might resolve against a negative basis, and thus end up with an
 opposite comparative relationship than the raw percentage value
 would seem to indicate.

 However, \"raw\" percentages---​ones which do not resolve against
 another value, such as in
 [opacity](https://drafts.csswg.org/css-color-4/#propdef-opacity)---​might not block
 simplification.
 :::

5. If `root` is a Min or Max node, attempt to *partially*
 simplify it:

 1. [For
 each](https://infra.spec.whatwg.org/#list-iterate) node `child` of `root`'s
 children:

 If `child` is a numeric value with enough information
 to compare magnitudes with another child of the same unit (see
 note in previous step), and there are other children of
 `root` that are numeric values with the same unit,
 combine all such children with the appropriate operator per
 `root`, and replace `child` with the
 result, removing all other child nodes involved.

 2. If `root` has only one child, return the child.

 Otherwise, return `root`.

6. If `root` is a Negate node:

 1. If `root`'s child is a numeric value, return an
 equivalent numeric value, but with the value negated (0 -
 value).

 2. If `root`'s child is a Negate node, return the
 child's child.

 3. If `root`'s child is a Sum node:

 1. Let `negated grandchildren` be an empty list

 2. For each `grandchild` of the child's children:

 1. If `grandchild` is a numeric value, create an
 equivalent numeric value, but with the value negated
 (0 - value), and append the result to
 `negated grandchildren`.

 2. If `grandchild` is a Negate node append
 `grandchild`'s child to
 `negated grandchildren`

 3. Otherwise, create a Negate node with
 `grandchild` as its child, and append the
 result to `negated grandchildren`

 3. Return a Sum node with `negated grandchildren` as
 its children

 4. Return `root`.

7. If `root` is an Invert node:

 1. If `root`'s child is a number (not a percentage or
 dimension) return the reciprocal of the child's value.

 2. If `root`'s child is an Invert node, return the
 child's child.

 3. Return `root`.

8. If `root` is a Sum node:

 1. For each of `root`'s children that are Sum nodes,
 replace them with their children.

 2. For each set of `root`'s children that are numeric
 values with identical units, remove those children and replace
 them with a single numeric value containing the sum of the
 removed nodes, and with the same unit.

 (E.g. combine numbers, combine percentages, combine px values,
 etc.)

 3. If `root` has only a single child at this point,
 return the child. Otherwise, return `root`.

 Zero-valued terms cannot be simply removed from a
 Sum; they can only be combined with other values that have identical
 units. (This is because the mere presence of a unit, even with a
 zero value, can sometimes imply a change in behavior.)

9. If `root` is a Product node:

 1. For each of `root`'s children that are Product nodes,
 replace them with their children.

 2. If `root` has multiple children that are numbers (not
 percentages or dimensions), remove them and replace them with a
 single number containing the product of the removed nodes.

 3. If `root` contains only two children, one of which is
 a number (not a percentage or dimension) and the other of which
 is a Sum whose children are all numeric values, multiply all of
 the Sum's children by the number, then return the Sum.

 4. If `root` contains only numeric values and/or Invert
 nodes containing numeric values, and [multiplying the
 types](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-multiply-two-types) of all the children (noting that the type of an
 Invert node is the
 [inverse](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-invert-a-type) of its child's type) results in a type that
 [matches](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-match) any of the types that a [math
 function](#math-function) can resolve to, return the result of
 multiplying all the values of the children (noting that the
 value of an Invert node is the reciprocal of its child's value),
 expressed in the result's [canonical
 unit](#canonical-unit).

 5. Return `root`.

10. Return `root`.

### 10.11. Computed Value

The [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) of a [math
function](#math-function) is
its [calculation tree](#calculation-tree)
[simplified](#simplify-a-calculation-tree), using all the information available at [computed
value] time. (Such as the
[em](#em) to
[px](#px) ratio, how to resolve
percentages in some properties, etc.)

Where percentages are not resolved at computed-value time, they are not
resolved in [math functions](#math-function), e.g. [calc(100% - 100% + 1px)] resolves to
[calc(0% + 1px)], not to [1px]. If there are special rules
for computing percentages in a value (e.g. [the [height]
property](https://www.w3.org/TR/CSS2/visudet.html#the-height-property)),
they apply whenever a [math function] contains
percentages.

The [calculation tree](#calculation-tree) is again simplified at [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) time; with [used value] time
information, a [math function](#math-function) always simplifies down to a single numeric value.

For example, whereas
[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size) computes percentage values at
[computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) time so that [font-relative
length](#font-relative-length) units can be computed,
[background-position](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-position) has layout-dependent behavior for
percentage values, and thus does not resolve percentages until
used-value time.

Due to this,
[background-position](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-position) computation preserves the
percentage in a [calc()](#funcdef-calc) whereas
[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size) will compute such expressions
directly into a length.

Given the complexities of width and height calculations on table cells
and table elements, math expressions mixing both percentages and
non-zero lengths for widths and heights on table columns, table column
groups, table rows, table row groups, and table cells in both auto and
fixed layout tables MUST be treated as if
[auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto) had been specified.

### 10.12. Range Checking

The clamping/rounding behavior of [numeric
functions](#numeric-function) is, for [math
functions](#math-function),
only performed on the results of a [top-level
calculation](#top-level-calculation). Nested [math functions]
forming a [calculation
tree](#calculation-tree)
neither clamp nor round.

### 10.13. Serialization

To [serialize a math function] `fn`:

1. If the root of the [calculation
 tree](#calculation-tree)
 `fn` represents is an unresolved [numeric
 function](#numeric-function) that is not a [math
 function](#math-function),
 serialize that function as normal and return the result.

2. If the root of the [calculation
 tree](#calculation-tree)
 `fn` represents is a numeric value (number, percentage,
 or dimension), and the serialization being produced is of a
 [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) or later, then clamp the value to the range allowed
 for its context (if necessary), then serialize the value as normal
 and return the result.

3. If `fn` represents an infinite or NaN value:

 1. Let `s` be the
 [string](https://infra.spec.whatwg.org/#string) \"calc(\".

 2. Serialize the keyword
 [infinity](#valdef-calc-infinity),
 [-infinity](#valdef-calc--infinity), or
 [NaN](#valdef-calc-nan), as appropriate to represent the value, and
 append it to `s`.

 3. If `fn`'s
 [type](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-type) is anything other than «\[ \]» (empty,
 representing a
 [\<number\>](#number-value)), append \" \* \" to
 `s`. Create a numeric value in the [canonical
 unit](#canonical-unit) for `fn`'s
 [type] (such as
 [px](#px) for
 [\<length\>](#length-value)), with a value of 1. Serialize
 this numeric value and append it to `s`.

 4. Append \")\" to `s`, then return it.

4. If the [calculation
 tree's](#calculation-tree) root node is a numeric value, or a [calc-operator
 node](#calculation-tree-calc-operator-nodes), let `s` be a string initially
 containing \"calc(\".

 Otherwise, let `s` be a string initially containing the
 name of the root node, lowercased (such as \"sin\" or \"max\"),
 followed by a \"(\" (open parenthesis).

5. For each child of the root node, [serialize the calculation
 tree](#serialize-a-calculation-tree). If a result of this serialization starts with a
 \"(\" (open parenthesis) and ends with a \")\" (close parenthesis),
 remove those characters from the result.
 [Concatenate](https://infra.spec.whatwg.org/#string-concatenate) all of the results using \", \" (comma followed by
 space), then append the result to `s`.

6. Append \")\" (close parenthesis) to `s`.

7. Return `s`.

To [serialize a calculation tree]:

1. Let `root` be the root node of the [calculation
 tree](#calculation-tree).

2. If `root` is a numeric value, or a non-[math
 function](#math-function),
 serialize `root` per the normal rules for it and return
 the result.

3. If `root` is anything but a Sum, Negate, Product, or
 Invert node, [serialize a math
 function](#serialize-a-math-function) for the function corresponding to the node type,
 treating the node's children as the function's comma-separated
 [calculation](#calc-calculation) arguments, and return the result.

4. If `root` is a Negate node:

 1. Let `s` be a
 [string](https://infra.spec.whatwg.org/#string) initially containing \"(-1 \* \".

 2. [Serialize](#serialize-a-calculation-tree) `root`'s child, and append it to
 `s`.

 3. Append \")\" to `s`, then return it.

5. If `root` is an Invert node:

 1. Let `s` be a
 [string](https://infra.spec.whatwg.org/#string) initially containing \"(1 / \".

 2. [Serialize](#serialize-a-calculation-tree) `root`'s child, and append it to
 `s`.

 3. Append \")\" to `s`, then return it.

6. If `root` is a Sum node:

 1. Let `s` be a
 [string](https://infra.spec.whatwg.org/#string) initially containing \"(\".

 2. [Sort root's
 children](#sort-a-calculations-children).

 3. [Serialize](#serialize-a-calculation-tree) `root`'s first child, and append it
 to `s`.

 4. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `child` of `root` beyond
 the first:

 1. If `child` is a Negate node, append \" - \" to
 `s`, then
 [serialize](#serialize-a-calculation-tree) the Negate's child and append the result to
 `s`.

 2. If `child` is a negative numeric value, append
 \" - \" to `s`, then serialize the negation of
 `child` as normal and append the result to
 `s`.

 3. Otherwise, append \" + \" to `s`, then
 [serialize](#serialize-a-calculation-tree) `child` and append the result to
 `s`.

 5. Append \")\" to `s` and return it.

7. If `root` is a Product node:

 1. Let `s` be a
 [string](https://infra.spec.whatwg.org/#string) initially containing \"(\".

 2. [Sort root's
 children](#sort-a-calculations-children).

 3. [Serialize](#serialize-a-calculation-tree) `root`'s first child, and append it
 to `s`.

 4. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `child` of `root` beyond
 the first:

 1. If `child` is an Invert node, append \" / \" to
 `s`, then
 [serialize](#serialize-a-calculation-tree) the Invert's child and append the result to
 `s`.

 2. Otherwise, append \" \* \" to `s`, then
 [serialize](#serialize-a-calculation-tree) `child` and append the result to
 `s`.

 5. Append \")\" to `s` and return it.

To [sort a calculation's children] `nodes`:

1. Let `ret` be an empty list.

2. If `nodes` contains a number, remove it from
 `nodes` and append it to `ret`.

3. If `nodes` contains a percentage, remove it from
 `nodes` and append it to `ret`.

4. If `nodes` contains any dimensions, remove them from
 `nodes`, sort them by their units, ordered [ASCII
 case-insensitively](https://infra.spec.whatwg.org/#ascii-case-insensitive), and append them to `ret`.

5. If `nodes` still contains any items, append them to
 `ret` in the same order.

6. Return `ret`.

- [calc-rgb-percent-001.html](https://wpt.fyi/results/css/css-values/calc-rgb-percent-001.html "css/css-values/calc-rgb-percent-001.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-rgb-percent-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-rgb-percent-001.html)
- [calc-serialization.html](https://wpt.fyi/results/css/css-values/calc-serialization.html "css/css-values/calc-serialization.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-serialization.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-serialization.html)
- [calc-serialization-002.html](https://wpt.fyi/results/css/css-values/calc-serialization-002.html "css/css-values/calc-serialization-002.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-serialization-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-serialization-002.html)
- [getComputedStyle-border-radius-001.html](https://wpt.fyi/results/css/css-values/getComputedStyle-border-radius-001.html "css/css-values/getComputedStyle-border-radius-001.html")
 [[(live
 test)]](http://wpt.live/css/css-values/getComputedStyle-border-radius-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/getComputedStyle-border-radius-001.html)
- [getComputedStyle-border-radius-003.html](https://wpt.fyi/results/css/css-values/getComputedStyle-border-radius-003.html "css/css-values/getComputedStyle-border-radius-003.html")
 [[(live
 test)]](http://wpt.live/css/css-values/getComputedStyle-border-radius-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/getComputedStyle-border-radius-003.html)
- [calc-background-position-003.html](https://wpt.fyi/results/css/css-values/calc-background-position-003.html "css/css-values/calc-background-position-003.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-background-position-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-background-position-003.html)

<!-- -->

- [calc-nesting-002.html](https://wpt.fyi/results/css/css-values/calc-nesting-002.html "css/css-values/calc-nesting-002.html")
 [[(live
 test)]](http://wpt.live/css/css-values/calc-nesting-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-values/calc-nesting-002.html)

For example, [calc(20px + 30px)]
would serialize as [calc(50px)] as a specified value, or as
[50px] as a computed value.

A value like [calc(20px + 0%)] would serialize as [calc(0% +
20px)], maintaining both terms in the serialized value. (It's
important to maintain zero-valued terms, so the
[calc()](#funcdef-calc)
doesn't suddenly \"change shape\" in the middle of a transition when one
of the values happens to have a zero value temporarily. This also
removes the need to \"pick a unit\" when all the terms are zero.)

A value like [calc(20px + 2em)] would serialize as [calc(2em +
20px)] as a specified value (maintaining both units as they're
incompatible at specified-value time, but sorting them alphabetically),
or as something like [52px] as a computed value
([em](#em) values are converted to
absolute lengths at computed-value time, so assuming [1em] =
[16px], they combine into [52px], which then drops the
[calc()](#funcdef-calc)
wrapper.)

When used in non-property contexts (such as in
[\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule) descriptors, for example), [math
functions](#math-function) are
simplified as if they were [specified
values](https://drafts.csswg.org/css-cascade-5/#specified-value).

See
[\[CSSOM\]](#biblio-cssom "CSS Object Model (CSSOM)")
for further information on serialization.

### 10.14. Combination of Math Functions

[Interpolation](#interpolation) of [math
functions](#math-function),
with each other or with numeric values and other numeric-valued
functions, is defined as V~result~ = calc((1 - p) \* V~A~ + p \* V~B~).
([Simplification](#simplify-a-calculation-tree) of the value might then reduce the expression to a
smaller, simpler form.)

[Addition](#addition) of [math
functions](#math-function),
with each other or with numeric values and other numeric-valued
functions, is defined as V~result~ = calc(V~A~ + V~B~).
([Simplification](#simplify-a-calculation-tree) of the value might then reduce the expression to a
smaller, simpler form.)

## [ Appendix A: Coordinating List-Valued Properties]
Some list-valued properties have coordinated effects: each item in their
value list applies to a distinct effect, and corresponding entries in
each property's list all refer to the same effect. Often the
coordinating values can also be specified together as a single entry in
a list-valued [shorthand
property](https://drafts.csswg.org/css-cascade-5/#shorthand-property).

A typical example is the list-valued [background-\*] properties,
which can specify [multiple background image
layers](https://www.w3.org/TR/css-backgrounds-3/#layering). For each
property controlling how the image is sized, tiled, placed, etc., the
`N`th item in its list describes some effect that applies to
the `N`th background image.

A [coordinating list property group]
creates a [coordinated value list], which has, for each entry, a
value from each property in the group; these are used together to define
a single effect, such as a background image layer or an animation. The
[used](https://drafts.csswg.org/css-cascade-5/#used-value) [coordinated value
list](#coordinated-value-list) is assembled as follows:

- The length of the [coordinated value
 list](#coordinated-value-list) is determined by the number of items specified in one
 particular [coordinating list
 property](#coordinating-list-property), the [coordinating list base
 property]. (In the case of backgrounds, this is the
 [background-image](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-image) property.)

- The `N`th value of the [coordinated value
 list](#coordinated-value-list) is constructed by collecting the `N`th
 [use
 value](https://drafts.csswg.org/css-cascade-5/#used-value) of each [coordinating list
 property](#coordinating-list-property)

- If a [coordinating list
 property](#coordinating-list-property) has too many values specified, excess values at the
 end of its list are not
 [used](https://drafts.csswg.org/css-cascade-5/#used-value).

- If a [coordinating list
 property](#coordinating-list-property) has too few values specified, its value list is
 repeated to add more [used
 values](https://drafts.csswg.org/css-cascade-5/#used-value).

- The [computed
 values](https://drafts.csswg.org/css-cascade-5/#computed-value) of the [coordinating list
 properties](#coordinating-list-property) are not affected by such truncation or repetition.

A shorthand that represents a [coordinated value
list](#coordinated-value-list) as a single list collecting corresponding values into
each item cannot represent [coordinating list
property](#coordinating-list-property) longhands that have varying list lengths in their
values. Thus, if any longhands have mismatched list lengths (excepting
any longhands that have their initial value, and thus can be omitted
from the shorthand syntax), the CSSOM representation of the shorthand's
value will return the empty string.

In the
[background](https://drafts.csswg.org/css-backgrounds-3/#propdef-background) shorthand, the first value in the
list combines the first values from
[background-image](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-image), \'background-position,
[background-attachment](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-attachment), etc; the second value combines the
second values; and so on. This syntax can only represent its longhands
when they have equal-length lists (or are their initial value); if the
longhands are individually set to different lengths, the CSSOM
representation of [background]
is just `""` (the empty string).

## [ Appendix B: IANA Considerations]
### [ Registration for the `about:invalid` URL scheme]
This sections defines and registers the `about:invalid` URL,
in accordance with the registration procedure defined in
[\[RFC6694\]](#biblio-rfc6694 "The "about" URI Scheme").

The official record of this registration can be found at
<http://www.iana.org/assignments/about-uri-tokens/about-uri-tokens.xhtml>.

Registered Token

`invalid`

Intended Usage

The `about:invalid` URL references a non-existent document
with a generic error condition. It can be used when a URL is necessary,
but the default value shouldn't be resolvable as any type of document.

Contact/Change controller

CSS WG \<<www-style@w3.org>\> (on behalf of W3C)

Specification

[CSS Values and Units Module Level
3](https://www.w3.org/TR/css3-values/)

## [ Appendix C: Quirky Lengths]
When CSS is being parsed in [quirks
mode](https://dom.spec.whatwg.org/#concept-document-quirks),
[[\<quirky-length\>](#typedef-quirky-length)] is a type of
[\<length\>](#length-value) that is only valid in certain properties:

- [background-position](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-position)

- [border-spacing](https://drafts.csswg.org/css2/#propdef-border-spacing)

- [border-top-width](https://drafts.csswg.org/css-borders-4/#propdef-border-top-width)

- [border-right-width](https://drafts.csswg.org/css-borders-4/#propdef-border-right-width)

- [border-bottom-width](https://drafts.csswg.org/css-borders-4/#propdef-border-bottom-width)

- [border-left-width](https://drafts.csswg.org/css-borders-4/#propdef-border-left-width)

- [border-width](https://drafts.csswg.org/css-borders-4/#propdef-border-width)

- [bottom](https://drafts.csswg.org/css-position-3/#propdef-bottom)

- [clip](https://drafts.csswg.org/css-masking-1/#propdef-clip)

- [font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size)

- [height](https://drafts.csswg.org/css-sizing-3/#propdef-height)

- [left](https://drafts.csswg.org/css-position-3/#propdef-left)

- [letter-spacing](https://drafts.csswg.org/css-text-4/#propdef-letter-spacing)

- [margin-right](https://drafts.csswg.org/css-box-4/#propdef-margin-right)

- [margin-left](https://drafts.csswg.org/css-box-4/#propdef-margin-left)

- [margin-top](https://drafts.csswg.org/css-box-4/#propdef-margin-top)

- [margin-bottom](https://drafts.csswg.org/css-box-4/#propdef-margin-bottom)

- [margin](https://drafts.csswg.org/css-box-4/#propdef-margin)

- [max-height](https://drafts.csswg.org/css-sizing-3/#propdef-max-height)

- [max-width](https://drafts.csswg.org/css-sizing-3/#propdef-max-width)

- [min-height](https://drafts.csswg.org/css-sizing-3/#propdef-min-height)

- [min-width](https://drafts.csswg.org/css-sizing-3/#propdef-min-width)

- [padding-top](https://drafts.csswg.org/css-box-4/#propdef-padding-top)

- [padding-right](https://drafts.csswg.org/css-box-4/#propdef-padding-right)

- [padding-bottom](https://drafts.csswg.org/css-box-4/#propdef-padding-bottom)

- [padding-left](https://drafts.csswg.org/css-box-4/#propdef-padding-left)

- [padding](https://drafts.csswg.org/css-box-4/#propdef-padding)

- [right](https://drafts.csswg.org/css-position-3/#propdef-right)

- [text-indent](https://drafts.csswg.org/css-text-4/#propdef-text-indent)

- [top](https://drafts.csswg.org/css-position-3/#propdef-top)

- [vertical-align](https://drafts.csswg.org/css-inline-3/#propdef-vertical-align)

- [width](https://drafts.csswg.org/css-sizing-3/#propdef-width)

- [word-spacing](https://drafts.csswg.org/css-text-4/#propdef-word-spacing)

It is *not* valid in properties that include or reference these
properties, such as the
[background](https://drafts.csswg.org/css-backgrounds-3/#propdef-background) shorthand, or inside [functional
notations](#functional-notation) such as [calc()](#funcdef-calc), except that they must be allowed in
[rect()](https://drafts.csswg.org/css-shapes-1/#funcdef-basic-shape-rect) in the
[clip](https://drafts.csswg.org/css-masking-1/#propdef-clip) property.

Additionally, while
[\<quirky-length\>](#typedef-quirky-length) must be valid as a
[\<length\>](#length-value) when parsing the affected properties in the
[\@supports](https://drafts.csswg.org/css-conditional-3/#at-ruledef-supports) rule, it is *not* valid for those properties
when used in the
[`CSS.supports()`](https://drafts.csswg.org/css-conditional-3/#dom-css-supports-conditiontext) method.

A
[\<quirky-length\>](#typedef-quirky-length) is syntactically identical to a
[\<number-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-number-token), and is interpreted as a
[px](#px) length with the same
value.

(In other words, Quirks Mode allows all [px](#px) lengths in the affected properties to be written
without a unit, similar to unitless zero lengths.)

## [ Acknowledgments]
Firstly, the editors would like to thank all of the contributors to the
[previous level](http://www.w3.org/TR/css-values-3/#acknowledgments) of
this module.

Secondly, we would like to acknowledge Anthony Frehner, Emilio Cobos
Álvarez, Guillaume Lebas, Koji Ishii, Noam Rosenthal, and Xidorn Quan
for their comments and suggestions, which have improved Level 4.

## [ Changes]
### [ Recent Changes]
(This is a subset of [Additions Since Level 3](#additions-L3).)

Substantial changes since [12 March 2024 Working
Draft](https://www.w3.org/TR/2024/WD-css-values-4-20240312/):

- Adapt the [snap as a line
 width](#snap-as-a-line-width) algorithm to handle negative numbers. ([Issue
 13795](https://github.com/w3c/csswg-drafts/issues/13795))

Finish this list.

Substantial changes since [18 December 2023
WD](https://www.w3.org/TR/2023/WD-css-values-4-20231218/):

- Added the [none](#valdef-clamp-none) values to
 [clamp()](#funcdef-clamp), ([Issue
 9713](https://github.com/w3c/csswg-drafts/issues/9713))

- Generally fixed how type inference handles percentages. ([Issue
 10017](https://github.com/w3c/csswg-drafts/issues/10017))

- Restored dependency of [viewport-percentage
 lengths](#viewport-percentage-lengths) on [overflow:
 scroll](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) and added one on
 [scrollbar-gutter](https://drafts.csswg.org/css-overflow-3/#propdef-scrollbar-gutter) to make it possible for 100 of
 these units to actually match the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block). ([Issue
 6026](https://github.com/w3c/csswg-drafts/issues/6026))

- Allow B to be omitted in
 [round()](#funcdef-round) if the A's type is
 [\<number\>](#number-value). ([Issue
 9668](https://github.com/w3c/csswg-drafts/issues/9668))

Substantial changes since [27 October 2023
WD](https://www.w3.org/TR/2023/WD-css-values-4-20231027/):

- Pinned the [default viewport-percentage
 units](#default-viewport-percentage-units) to the [large viewport-percentage
 units](#large-viewport-percentage-units)---​despite violation of the "avoid dataloss by default
 principle"---​given existing interoperability and presumed Web-compat
 restriction. ([Issue
 6452](https://github.com/w3c/csswg-drafts/issues/6454))

- Added an explicit definition for the [CSS grammar production
 block](#css-grammar-production-block) convention. ([Issue
 2921](https://github.com/w3c/csswg-drafts/issues/2921))

- Clarified character encoding of percent-encoded URLs. ([Issue
 9301](https://github.com/w3c/csswg-drafts/issues/9301))

Substantial changes since [6 April 2023
WD](https://www.w3.org/TR/2023/WD-css-values-4-20230406/):

- Punted
 [mix()](https://www.w3.org/TR/css-values-5/#funcdef-mix) to
 [\[css-values-5\]](#biblio-css-values-5 "CSS Values and Units Module Level 5").
 ([Issue 9343](https://github.com/w3c/csswg-drafts/issues/9343))

- Color type defined to be non-additive. ([Issue
 8576](https://github.com/w3c/csswg-drafts/issues/8576))

- Non-property contexts treat [math
 functions](#math-function)
 as specified values. ([Issue
 7964](https://github.com/w3c/csswg-drafts/issues/7964))

- Specified that URLs from CSS are always transmitted as UTF-8. ([Issue
 9301](https://github.com/w3c/csswg-drafts/issues/9301))

- Fixed [addition](#addition)/[accumulation](#accumulation) to use the \*second\* value, when the two values
 aren't additive/accumulative. ([Issue
 9070](https://github.com/w3c/csswg-drafts/issues/9070))

- Specified that [font-relative
 lengths](#font-relative-length) are always resolved against the parent element when
 used in a [font-\*] property. ([Issue
 8169](https://github.com/w3c/csswg-drafts/issues/8169))

- Simplify away single-argument
 [min()](#funcdef-min)
 and [max()](#funcdef-max) functions. ([Issue
 9559](https://github.com/w3c/csswg-drafts/issues/9559))

Substantial changes since [19 October 2022
WD](https://www.w3.org/TR/2022/WD-css-values-4-20221019/):

- Added [§ 2.6 Functional Notation Definitions](#component-functions) to
 formally define the way that [functional
 notation](#functional-notation) syntaxes are defined. ([Issue
 2921](https://github.com/w3c/csswg-drafts/issues/2921))
- Added algorithm for [snap as a line
 width](#snap-as-a-line-width), to reflect the interoperable rules for rendering
 consistent stroke widths. ([Issue
 5210](https://github.com/w3c/csswg-drafts/issues/5210))
- Clarified grammar and [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) of
 [mix()](https://www.w3.org/TR/css-values-5/#funcdef-mix). ([Issue
 8096](https://github.com/w3c/csswg-drafts/issues/8096))
- Undefined the behavior of [tan()](#funcdef-tan) at the asymptote values. ([Issue
 8527](https://github.com/w3c/csswg-drafts/issues/8527))
- Specified that negative
 [\<resolution\>](#resolution-value) values are out-of-range by definition.
 ([Issue 8532](https://github.com/w3c/csswg-drafts/issues/8532))
- Clarified that fully omitted
 [mix()](https://www.w3.org/TR/css-values-5/#funcdef-mix) arguments are valid. ([Issue
 8556](https://github.com/w3c/csswg-drafts/issues/8556))
- Clarified that range clamping happens specifically to [top-level
 calculations](#top-level-calculation) (rather than the unclear term \"expressions\").
 ([Issue 8158](https://github.com/w3c/csswg-drafts/issues/8158))
- Added formal definitions for
 [\<url()\>](#funcdef-url) and
 [\<src()\>](#funcdef-src) (in addition to
 [\<url\>](#url-value)).
- Rephrased fragment-only URLs in terms of tree-scoped references.
 ([Issue 3320](https://github.com/w3c/csswg-drafts/issues/3320))

Substantial changes since [16 December 2021
WD](https://www.w3.org/TR/2021/WD-css-values-4-20211216/):

- Changed resolution of a [url()](#funcdef-url) with the [local url
 flag](#url-local-url-flag) to reference the current [node
 tree](https://dom.spec.whatwg.org/#concept-node-tree) (regardless of document base URL modifications).
 ([Issue 3320](https://github.com/w3c/csswg-drafts/issues/3320))
- Switched censoring of
 [NaN](#valdef-calc-nan) that escapes a [math
 function](#math-function)
 from infinity to zero. ([Issue
 7067](https://github.com/w3c/csswg-drafts/issues/7067))
- Added [Appendix A: Coordinating List-Valued
 Properties](#linked-properties) to allow this property pattern to be
 easily referenced. ([Issue
 7164](https://github.com/w3c/csswg-drafts/issues/7164))
- Restricted
 [mix()](https://www.w3.org/TR/css-values-5/#funcdef-mix) to be the sole value of a declaration. ([Issue
 6700](https://github.com/w3c/csswg-drafts/issues/6700))
- Updated to match latest Fetch terminology. ([Fetch PR
 1413](https://github.com/whatwg/fetch/pull/1413), [CSS PR
 7160](https://github.com/w3c/csswg-drafts/pull/7160))
- Clarified that the [font-relative
 lengths](#font-relative-length) are calculated without text shaping.
- Defined serialization of empty urls to be `url("")`.
 ([Issue 6447](https://github.com/w3c/csswg-drafts/issues/6447))
- Defined serialization of
 [\<position\>](#typedef-position) [specified
 values](https://drafts.csswg.org/css-cascade-5/#specified-value). ([Issue
 2274](https://github.com/w3c/csswg-drafts/issues/2274))
- Fixed definition of [numbers](#number) to allow decimals in combination with scientific
 notation, as originally intended and as defined in
 [\[CSS-SYNTAX-3\]](#biblio-css-syntax-3 "CSS Syntax Module Level 3").
 ([Issue 7248](https://github.com/w3c/csswg-drafts/issues/7248))
- Corrected various functions to return an empty map for their
 [type](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-type) instead of «\[ \"number\" → 1 \]». ([Issue
 7486](https://github.com/w3c/csswg-drafts/issues/7486))
- Clarified effect of special UA restrictions on
 [line-height](https://drafts.csswg.org/css2/#propdef-line-height) on [lh](#lh) and [rlh](#rlh). ([Issue
 3257](https://github.com/w3c/csswg-drafts/issues/3257))
- Defined `<function()>` notation to refer to functional
 notations. ([Issue
 5728](https://github.com/w3c/csswg-drafts/issues/5728))

Substantial changes since [16 October 2021
WD](https://www.w3.org/TR/2021/WD-css-values-4-20211016/):

- Switched [\*vi] and [\*vb] units to resolve against the
 computed [writing
 mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) of the element itself. ([Issue
 6873](https://github.com/w3c/csswg-drafts/issues/6873))

- Added [§ 4.5.4 URL Processing Model](#url-processing) to define
 integration with CORS, etc. ([Issue
 562](https://github.com/w3c/csswg-drafts/issues/562))

- Fixed the inverted assignment of [viewport-percentage
 length](#viewport-percentage-lengths) behaviors to types of interface changes (A vs. B).

 > - Changes in interface that happen as a result of scrolling or other
 > frequent page interactions that would disturb the user if they
 > resulted in substantial layout changes must be categorized as the
 > ~~former (A)~~ [latter (B)] .
 > - Changes in interface that have a sufficiently steady state that
 > re-laying out the document into the adjusted space would be
 > beneficial to the user must be categorized as the ~~latter (B)~~
 > [former (A)] .

- Defined minimum number of
 [calc()](#funcdef-calc) terms, arguments, and nesting as 32. ([Issue
 3462](https://github.com/w3c/csswg-drafts/issues/3462))

- Defined that [mod(-0, infinity)] returns
 [NaN](#valdef-calc-nan). ([Issue
 4723](https://github.com/w3c/csswg-drafts/issues/4723))

- Deferred
 [toggle()](https://www.w3.org/TR/css-values-5/#funcdef-toggle) and
 [attr()](https://drafts.csswg.org/css-values-5/#funcdef-attr) to Level 5.

Changes since [30 September 2021
WD](https://www.w3.org/TR/2021/WD-css-values-4-20210930/):

- Added [rex](#rex),
 [rcap](#rcap),
 [rch](#rch), and
 [ric](#ric) units.
- Switched
 [toggle()](https://www.w3.org/TR/css-values-5/#funcdef-toggle) to use semicolons, matching with
 [mix()](https://www.w3.org/TR/css-values-5/#funcdef-mix). ([Issue
 6701](https://github.com/w3c/csswg-drafts/issues/6701))
- Fixed some wording errors in the definition of
 [calc()](#funcdef-calc). ([Issue
 6506](https://github.com/w3c/csswg-drafts/issues/6506))
- Imported definition of
 [\<quirky-length\>](#typedef-quirky-length) from
 [\[QUIRKS\]](#biblio-quirks "Quirks Mode Standard").
 ([Issue 6100](https://github.com/w3c/csswg-drafts/issues/6100))

Changes since [7 July 2021
WD](https://www.w3.org/TR/2021/WD-css-values-4-20210715/):

- Added
 [mix()](https://www.w3.org/TR/css-values-5/#funcdef-mix) notation for representing interpolated values.
- Defined generically the computation of
 [\<integer\>](#integer-value),
 [\<number\>](#number-value),
 [\<percentage\>](#percentage-value), and
 [\<length\>](#length-value).
- Clarified that only non-zero lengths create a percentage+length mix
 that switches table cells to
 [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto) sizing.

Changes since [11 November 2020
WD](https://www.w3.org/TR/2020/WD-css-values-4-20201111/):

- Updated interpolation of colors to reference
 [\[CSS-COLOR-4\]](#biblio-css-color-4 "CSS Color Module Level 4")
 instead of
 [\[CSS-COLOR-3\]](#biblio-css-color-3 "CSS Color Module Level 3").
- Added the [svh](#svh),
 [svw](#svw),
 [svi](#svi),
 [svb](#svb),
 [svmin](#svmin), and
 [svmax](#svmax) [small
 viewport-percentage
 units](#small-viewport-percentage-units); [lvh](#lvh),
 [lvw](#lvw),
 [lvi](#lvi),
 [lvb](#lvb),
 [lvmin](#lvmin), and
 [lvmax](#lvmax) [large
 viewport-percentage
 units](#large-viewport-percentage-units); and [dvh](#dvh), [dvw](#dvw),
 [dvi](#dvi),
 [dvb](#dvb),
 [dvmin](#dvmin), and
 [dvmax](#dvmax) [dynamic
 viewport-percentage
 units](#dynamic-viewport-percentage-units). ([Issue
 4329](https://github.com/w3c/csswg-drafts/issues/4329) and [Issue
 6113](https://github.com/w3c/csswg-drafts/issues/6113))
- Clamped excessively large
 [\<angle\>](#angle-value) values to multiples of [360deg]. ([Issue
 6105](https://github.com/w3c/csswg-drafts/issues/6105))
- Added back [rules on range-checking combined values](#combining-range)
 lost during move from the [CSS
 Transitions](https://www.w3.org/TR/css-transitions-1/) specification.
 ([Issue 6097](https://github.com/w3c/csswg-drafts/issues/6097))
- Specified that UA-imposed minimum font sizes apply to the used
 [font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size) and not to resolution of
 [font-relative
 lengths](#font-relative-length). ([Issue
 5858](https://github.com/w3c/csswg-drafts/issues/5858))
- Clarified how [min()](#funcdef-min) and [max()](#funcdef-max) percentages can partially simplify. ([Issue
 6293](https://github.com/w3c/csswg-drafts/issues/6298))

### [ Additions Since Level 3]
Changes since [CSS Values and Units Level
3](http://www.w3.org/TR/css-values-3/):

- Explicitly undefined numeric precision/range.
- Added rules for interpolation per value type, and their clarified
 computed values.
- Updated interpolation of colors to reference
 [\[CSS-COLOR-4\]](#biblio-css-color-4 "CSS Color Module Level 4").

Additions since [CSS Values and Units Level
3](http://www.w3.org/TR/css-values-3/):

- Defined the
 [\<dashed-ident\>](#typedef-dashed-ident) type.
- Defined the [\<ratio\>](#ratio-value) type.
- Added [src()](#funcdef-src) to the [\<url\>](#url-value) type.
- Added the [vi](#vi),
 [vb](#vb), [ic](#ic), [cap](#cap), [lh](#lh) and
 [rlh](#rlh) length units.
- Added the [svh](#svh),
 [svw](#svw),
 [svi](#svi),
 [svb](#svb),
 [svmin](#svmin), and
 [svmax](#svmax) [small
 viewport-percentage
 units](#small-viewport-percentage-units) and [dvh](#dvh), [dvw](#dvw),
 [dvi](#dvi),
 [dvb](#dvb),
 [dvmin](#dvmin), and
 [dvmax](#dvmax) [dynamic
 viewport-percentage
 units](#dynamic-viewport-percentage-units).
- Added the [x](#x) alias to
 [dppx](#dppx).
- Added [min()](#funcdef-min), [max()](#funcdef-max), and
 [clamp()](#funcdef-clamp) [comparison functions](#comp-func).
- Added [round()](#funcdef-round), [mod()](#funcdef-mod), [rem()](#funcdef-rem), [sin()](#funcdef-sin), [cos()](#funcdef-cos), [tan()](#funcdef-tan), [asin()](#funcdef-asin),
 [acos()](#funcdef-acos), [atan()](#funcdef-atan),
 [atan2()](#funcdef-atan2), [pow()](#funcdef-pow), [sqrt()](#funcdef-sqrt),
 [hypot()](#funcdef-hypot), [log()](#funcdef-log), [exp()](#funcdef-exp), [abs()](#funcdef-abs), [sign()](#funcdef-sign) math functions.
- Added [e](#valdef-calc-e), [pi](#valdef-calc-pi),
 [infinity](#valdef-calc-infinity),
 [-infinity](#valdef-calc--infinity),
 [NaN](#valdef-calc-nan) constants for use in
 [calc()](#funcdef-calc).
- Added [unit algebra](#calc-type-checking) to
 [calc()](#funcdef-calc), allowing multiplication and division of
 [dimensions](#dimension).
- A non-integer in a calc() automatically rounds to the nearest integer
 when used where an
 [\<integer\>](#integer-value) is required.
- Defined [serialization](#calc-serialize) of [math
 functions](#math-function).
- Added a genericized definition of [coordinating list property
 groups](#coordinating-list-property), to make it easier to reference the coordinating
 behavior of the
 [background](https://drafts.csswg.org/css-backgrounds-3/#propdef-background) properties.

## [ Security Considerations]
This specification presents no new security considerations.

This specification defines the
[url()](#funcdef-url) and
[src()](#funcdef-src)
functions ([\<url\>](#url-value)), which allow CSS to make network requests. Depending
on what features they are used in, these can potentially expose whether
or not the user has access to resources on a network, and expose
information about their contents (such as the rules within a style
sheet, the size of an image, the metrics of a font). They can also allow
exfiltrating data via URL.

## [ Privacy Considerations]
This specification defines units that expose the user's screen size (the
[viewport-percentage
lengths](#viewport-percentage-lengths)), default font size, and potentially some information
about which fonts are available on the user's system (the [font-relative
lengths](#font-relative-length)).

This specification defines the
[url()](#funcdef-url) and
[src()](#funcdef-src)
functions ([\<url\>](#url-value)), which allow CSS to make network requests. Depending
on what features they are used in, these can potentially expose whether
or not the user has access to resources on a network, and expose
information about their contents (such as the rules within a style
sheet, the size of an image, the metrics of a font). They can also allow
exfiltrating data via URL.
