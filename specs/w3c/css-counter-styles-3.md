## 1. Introduction

CSS 1 defined a handful of useful counter styles based on the styles
that HTML traditionally allowed on ordered and unordered lists. While
this was expanded slightly by CSS2.1, it doesn't address the needs of
worldwide typography.

This module introduces the
[\@counter-style](#at-ruledef-counter-style) rule which allows CSS to address this in an
open-ended manner, by allowing the author to define their own counter
styles. These styles can then be used in the
[list-style-type](https://drafts.csswg.org/css-lists-3/#propdef-list-style-type) property or in the
[counter()](https://drafts.csswg.org/css-lists-3/#funcdef-counter) and
[counters()](https://drafts.csswg.org/css-lists-3/#funcdef-counters) functions. It also defines some additional
predefined counter styles, particularly ones which are common but
complicated to represent with
[\@counter-style].

## 2. Counter Styles

A [counter style] defines how to convert a counter value into a string. Counter
styles are composed of:

- a name, to identify the style
- an algorithm, which transforms integer counter values into a basic
 string representation
- a negative sign, which is prepended or appended to the representation
 of a negative counter value.
- a prefix, to prepend to the representation
- a suffix to append to the representation
- a range, which limits the values that a counter style handles
- a spoken form, which describes how to read out the counter style in a
 speech synthesizer
- and a fallback style, to render the representation with when the
 counter value is outside the counter style's range or the counter
 style otherwise can't render the counter value

### 2.1. Counter Style Names

[Counter styles](#counter-style)
are referenced by name, and represented syntactically by
[\<counter-style-name\>], which is a
[\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value) specifying a [tree-scoped
name](https://drafts.csswg.org/css-shadow-1/#css-tree-scoped-name). The keyword
[none](https://drafts.csswg.org/css-lists-3/#valdef-list-style-type-none) (including any [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) permutation of it) is not a valid
[\<counter-style-name\>](#typedef-counter-style-name).

Tests

- [name-syntax.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/name-syntax.html "css/css-counter-styles/counter-style-at-rule/name-syntax.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/name-syntax.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/name-syntax.html)

 Note that
[\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value) also automatically excludes the
[CSS-wide
keywords](https://drafts.csswg.org/css-values-4/#css-wide-keywords). In addition, some names, like
[inside](https://drafts.csswg.org/css-lists-3/#valdef-list-style-position-inside), are valid as counter style names, but conflict
with the existing values of properties like
[list-style](https://drafts.csswg.org/css-lists-3/#propdef-list-style), and so won't be usable there.

Counter style names are generally case-sensitive. However, the names
defined in this specification are ASCII lowercased on parse wherever
they are used as counter styles, e.g. in the
[list-style](https://drafts.csswg.org/css-lists-3/#propdef-list-style) set of properties, in the
[\@counter-style](#at-ruledef-counter-style) rule, and in the
[counter()](https://drafts.csswg.org/css-lists-3/#funcdef-counter) functions.

Tests

- [name-case-sensitivity.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/name-case-sensitivity.html "css/css-counter-styles/counter-style-at-rule/name-case-sensitivity.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/name-case-sensitivity.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/name-case-sensitivity.html)

### 2.2. Generating a Counter String

When asked to [generate a counter representation] using a
particular counter style for a particular counter value, follow these
steps:

1. If the counter style is unknown, exit this algorithm and instead
 [generate a counter
 representation](#generate-a-counter) using the [decimal](#decimal) style and the same counter value.
2. If the counter value is outside the
 [range](#descdef-counter-style-range) of the counter style, exit this
 algorithm and instead [generate a counter
 representation](#generate-a-counter) using the counter style's fallback style and the
 same counter value.
3. Using the counter value and the counter algorithm for the counter
 style, generate an [initial representation for the counter
 value]. If the counter value is
 negative and the counter style [uses a negative
 sign](#use-a-negative-sign), instead generate an initial representation using
 the absolute value of the counter value.
4. Prepend symbols to the representation as specified in the
 [pad](#descdef-counter-style-pad) descriptor.
5. If the counter value is negative and the counter style [uses a
 negative sign](#use-a-negative-sign), wrap the representation in the counter style's
 negative sign as specified in the
 [negative](#descdef-counter-style-negative) descriptor.
6. Return the representation.

Tests

General tests for counter styles

- [descriptor-calc.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/descriptor-calc.html "css/css-counter-styles/counter-style-at-rule/descriptor-calc.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/descriptor-calc.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/descriptor-calc.html)
- [counter-suffix.html](https://wpt.fyi/results/css/css-counter-styles/counter-suffix.html "css/css-counter-styles/counter-suffix.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-suffix.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-suffix.html)
- [idlharness.html](https://wpt.fyi/results/css/css-counter-styles/idlharness.html "css/css-counter-styles/idlharness.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/idlharness.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/idlharness.html)

------------------------------------------------------------------------

[prefix](#descdef-counter-style-prefix) and
[suffix](#descdef-counter-style-suffix) don't play a part in this algorithm.
This is intentional; the prefix and suffix aren't part of the string
returned by the counter() or counters() functions. Instead, the prefix
and suffix are added by the algorithm that constructs the value of the
[content](https://drafts.csswg.org/css-content-3/#propdef-content) property for the
[::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker) pseudo-element. This also implies that the
prefix and suffix always come from the specified counter-style, even if
the actual representation is constructed by a fallback style.

Some values of
[system](#descdef-counter-style-system)
([symbolic](#valdef-system-symbolic),
[additive](#valdef-counter-style-system-additive)) and some descriptors
([pad](#descdef-counter-style-pad)) can generate representations with size
linear to an author-supplied number. This can potentially be abused to
generate excessively large representations and consume undue amounts of
the user's memory or even hang their browser. User agents must support
representations at least 60 Unicode codepoints long, but they may choose
to instead use the fallback style for representations that would be
longer than 60 codepoints.

## 3. Defining Custom Counter Styles: the [\@counter-style rule]
The [\@counter-style] rule allows authors to define a custom
[counter style](#counter-style). The components of a [counter
style] are specified by descriptors in the
[\@counter-style](#at-ruledef-counter-style) rule. The algorithm is specified implicitly by a
combination of the [system], [symbols], and
[additive-symbols] properties.

The general form of an
[\@counter-style](#at-ruledef-counter-style) rule is:

``` prod
@counter-style <counter-style-name> { <declaration-list> }
```

Tests

- [counter-name-case-sensitive.html](https://wpt.fyi/results/css/css-counter-styles/counter-name-case-sensitive.html "css/css-counter-styles/counter-name-case-sensitive.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-name-case-sensitive.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-name-case-sensitive.html)
- [access-from-shadow-dom.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/access-from-shadow-dom.html "css/css-counter-styles/counter-style-at-rule/access-from-shadow-dom.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/access-from-shadow-dom.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/access-from-shadow-dom.html)
- [override-in-shadow-dom.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/override-in-shadow-dom.html "css/css-counter-styles/counter-style-at-rule/override-in-shadow-dom.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/override-in-shadow-dom.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/override-in-shadow-dom.html)
- [redefine-attr-mapping.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/redefine-attr-mapping.html "css/css-counter-styles/counter-style-at-rule/redefine-attr-mapping.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/redefine-attr-mapping.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/redefine-attr-mapping.html)
- [redefine-builtin.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/redefine-builtin.html "css/css-counter-styles/counter-style-at-rule/redefine-builtin.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/redefine-builtin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/redefine-builtin.html)
- [shadow-dom-part.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/shadow-dom-part.html "css/css-counter-styles/counter-style-at-rule/shadow-dom-part.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/shadow-dom-part.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/shadow-dom-part.html)

Certain [non-overridable counter-styles]---​specifically,
[decimal](#decimal) or any of
the [predefined symbolic counter
styles](#predefined-symbolic-counter-style)
([\<symbolic-glyph\>](#typedef-symbolic-glyph))---​cannot be defined by an
[\@counter-style](#at-ruledef-counter-style) rule; any rule that attempts to do so is invalid
and ignored.

Each
[\@counter-style](#at-ruledef-counter-style) rule specifies a value for every counter-style
descriptor, either implicitly or explicitly. Those not given explicit
value in the rule take the initial value listed with each descriptor in
this specification. These descriptors apply solely within the context of
the [\@counter-style] rule in
which they are defined, and do not apply to document language elements.
There is no notion of which elements the descriptors apply to or whether
the values are inherited by child elements. When a given descriptor
occurs multiple times in a given
[\@counter-style] rule, only
the last-specified valid value is used; all prior values for that
descriptor must be ignored.

Defining a
[\@counter-style](#at-ruledef-counter-style) makes it available to the entire document in
which it is included. If multiple
[\@counter-style] rules are
defined with the same name, only one wins, according to standard cascade
rules. [\@counter-style] rules
cascade \"atomically\": if one replaces another of the same name, it
replaces it *entirely*, rather than just replacing the specific
descriptors it specifies.

 Note that even the predefined counter styles can be
overridden; the UA stylesheet occurs before any other stylesheets, so
the predefined ones always lose in the cascade.

This at-rule conforms with the forward-compatible parsing requirement of
CSS; conformant parsers that don't understand these rules will ignore
them without error. Any descriptors that are not recognized or
implemented by a given user agent, or whose value does not match the
grammars given here or in a future version of this specification, must
be ignored in their entirety; they do not make the
[\@counter-style](#at-ruledef-counter-style) rule invalid.

### 3.1. Counter algorithms: the [system descriptor]
Name:

[system]

For:

[\@counter-style](#at-ruledef-counter-style)

Value:

cyclic
[\|](https://drafts.csswg.org/css-values-4/#comb-one) numeric [\|] alphabetic
[\|] symbolic [\|] additive
[\|] [\[fixed
[\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value)[?](https://drafts.csswg.org/css-values-4/#mult-opt)\]] [\|] [\[ extends
[\<counter-style-name\>](#typedef-counter-style-name) \]]

Initial:

symbolic

Tests

- [system-syntax.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/system-syntax.html "css/css-counter-styles/counter-style-at-rule/system-syntax.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/system-syntax.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/system-syntax.html)

The
[system](#descdef-counter-style-system) descriptor specifies which algorithm
will be used to construct the counter's representation based on the
counter value. For example,
[cyclic](#valdef-counter-style-system-cyclic) counter styles just cycle through their symbols
repeatedly, while
[numeric](#valdef-counter-style-system-numeric) counter styles interpret their symbols as digits
and build their representation accordingly. The systems are defined in
the following subsections.

Each
[system](#descdef-counter-style-system) value is associated with either the
[symbols](#descdef-counter-style-symbols) or
[additive-symbols](#descdef-counter-style-additive-symbols) descriptors, and has a minimum length
that the appropriate descriptor must have; each entry below defines what
this is. If a
[\@counter-style](#at-ruledef-counter-style) rule fails to meet this requirement, it does not
define a [counter style](#counter-style). (The rule is still syntactically valid, but has no
effect.)

#### 3.1.1. Cycling Symbols: the [cyclic system]
The [cyclic] counter
system cycles repeatedly through its provided symbols, looping back to
the beginning when it reaches the end of the list. It can be used for
simple bullets (just provide a single [counter
symbol](#counter-symbol)), or
for cycling through multiple symbols. The first [counter
symbol] is used as the representation of the
value 1, the second [counter symbol] (if it
exists) is used as the representation of the value 2, etc.

If the system is
[cyclic](#valdef-counter-style-system-cyclic), the
[symbols](#descdef-counter-style-symbols) descriptor must contain at least one
[counter symbol](#counter-symbol), otherwise the rule does not define a counter style
(but is still a valid rule). This system is defined over all counter
values.

A \"triangle bullet\" counter style
can be defined as:

 @counter-style triangle {
 system: cyclic;
 symbols: ‣;
 suffix: " ";
 }

It will then produce lists that look like:

 ‣ One
 ‣ Two
 ‣ Three

If there are `N` [counter
symbols](#counter-symbol) and
a representation is being constructed for the integer
`value`, the representation is the [counter
symbol] at index ( (`value`-1) mod
`N`) of the list of [counter
symbols] (0-indexed).

Tests

- [system-cyclic.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/system-cyclic.html "css/css-counter-styles/counter-style-at-rule/system-cyclic.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/system-cyclic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/system-cyclic.html)
- [system-cyclic-invalid.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/system-cyclic-invalid.html "css/css-counter-styles/counter-style-at-rule/system-cyclic-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/system-cyclic-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/system-cyclic-invalid.html)

#### 3.1.2. Exhaustible Symbols: the [fixed system]
The [fixed] counter
system runs through its list of counter symbols once, then falls back.
It is useful for representing counter styles that only have a finite
number of representations. For example, Unicode defines several
limited-length runs of special characters meant for lists, such as
circled digits.

If the system is
[fixed](#valdef-counter-style-system-fixed), the
[symbols](#descdef-counter-style-symbols) descriptor must contain at least one
[counter symbol](#counter-symbol), otherwise the rule does not define a counter style
(but is still a valid rule). This system is defined over counter values
in a finite range, starting with the [first symbol
value](#first-symbol-value)
and having a length equal to the length of the list of [counter
symbols].

When this system is specified, it may optionally have an integer
provided after it, which sets the [first symbol
value].
If it is omitted, the [first symbol
value](#first-symbol-value) is 1.

A \"box-corner\" counter style can be
defined as:

 @counter-style box-corner {
 system: fixed;
 symbols: ◰ ◳ ◲ ◱;
 suffix: ': ';
 }

It will then produce lists that look like:

 ◰: One
 ◳: Two
 ◲: Three
 ◱: Four
 5: Five
 6: Six

The first [counter symbol](#counter-symbol) is the representation for the [first symbol
value](#first-symbol-value), and subsequent counter values are represented by
subsequent [counter symbols]. Once the list
of [counter symbols] is exhausted, further
values cannot be represented by this counter style, and must instead be
represented by the fallback counter style.

Tests

- [system-fixed.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/system-fixed.html "css/css-counter-styles/counter-style-at-rule/system-fixed.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/system-fixed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/system-fixed.html)
- [system-fixed-invalid.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/system-fixed-invalid.html "css/css-counter-styles/counter-style-at-rule/system-fixed-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/system-fixed-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/system-fixed-invalid.html)

#### 3.1.3. Repeating Symbols: the [symbolic system]
The [symbolic] counter system cycles
repeatedly through its provided symbols, doubling, tripling, etc. the
symbols on each successive pass through the list. For example, if the
original symbols were \"\*\" and \"†\", then on the second pass they
would instead be \"\*\*\" and \"††\", while on the third they would be
\"\*\*\*\"and \"†††\", etc. It can be used for footnote-style markers,
and is also sometimes used for alphabetic-style lists for a slightly
different presentation than what the
[alphabetic](#valdef-counter-style-system-alphabetic) system presents.

If the system is
[symbolic](#valdef-system-symbolic), the
[symbols](#descdef-counter-style-symbols) descriptor must contain at least one
[counter symbol](#counter-symbol), otherwise the rule does not define a counter style
(but is still a valid rule). This system is defined only over strictly
positive counter values.

An \"footnote\" counter style can be
defined as:

 @counter-style footnote {
 system: symbolic;
 symbols: '*' ⁑ † ‡;
 suffix: " ";
 }

It will then produce lists that look like:

 * One
 ⁑ Two
 † Three
 ‡ Four
 ** Five
 ⁑⁑ Six

Some style guides mandate a list
numbering that looks similar to
[upper-alpha](#upper-alpha), but repeats differently after the first 26 values,
instead going \"AA\", \"BB\", \"CC\", etc. This can be achieved with the
symbolic system:

 @counter-style upper-alpha-legal {
 system: symbolic;
 symbols: A B C D E F G H I J K L M
 N O P Q R S T U V W X Y Z;
 }

This style is identical to
[upper-alpha](#upper-alpha) through the first 27 values, but they diverge after
that, with [upper-alpha] going \"AB\",
\"AC\", \"AD\", etc. Starting at the 53rd value,
[upper-alpha] goes \"BA\", \"BB\", \"BC\",
etc., while this style jumps into triple digits with \"AAA\", \"BBB\",
\"CCC\", etc.

To construct the representation, run the following algorithm:

Let `N` be the length of the list of [counter
symbols](#counter-symbol),
`value` initially be the counter value, `S`
initially be the empty string, and `symbol(n)` be the nth
[counter symbol] in the list of [counter
symbols] (0-indexed).

1. Let the `chosen symbol` be
 `symbol( (``value`` - 1) mod ``N``)`.
2. Let the `representation length` be
 `ceil( ``value`` / ``N`` )`.
3. Append the `chosen symbol` to `S` a number of
 times equal to the `representation length`.

Finally, return `S`.

Tests

- [system-symbolic.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/system-symbolic.html "css/css-counter-styles/counter-style-at-rule/system-symbolic.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/system-symbolic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/system-symbolic.html)
- [system-symbolic-invalid.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/system-symbolic-invalid.html "css/css-counter-styles/counter-style-at-rule/system-symbolic-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/system-symbolic-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/system-symbolic-invalid.html)

#### 3.1.4. Bijective Numerals: the [alphabetic system]
The [alphabetic]
counter system interprets the list of [counter
symbols](#counter-symbol) as
digits to an *alphabetic* numbering system, similar to the default
[lower-alpha](#lower-alpha)
counter style, which wraps from \"a\", \"b\", \"c\", to \"aa\", \"ab\",
\"ac\". Alphabetic numbering systems do not contain a digit representing
0; so the first value when a new digit is added is composed solely of
the first digit. Alphabetic numbering systems are commonly used for
lists, and also appear in many spreadsheet programs to number columns.
The first [counter symbol] in the list is
interpreted as the digit 1, the second as the digit 2, and so on.

If the system is
[alphabetic](#valdef-counter-style-system-alphabetic), the
[symbols](#descdef-counter-style-symbols) descriptor must contain at least two
[counter symbols](#counter-symbol), otherwise the rule does not define a counter style
(but is still a valid rule). This system is defined only over strictly
positive counter values.

A counter style using go stones can be
defined as:

 @counter-style go {
 system: alphabetic;
 symbols: url(white.svg) url(black.svg);
 suffix: " ";
 }

It will then produce lists that look like:

::: alphabetic-example
!(images/white.svg){height="16" width="16"} One\
!(images/black.svg){height="16" width="16"} Two\
!(images/white.svg){height="16"
width="16"}!(images/white.svg){height="16" width="16"} Three\
!(images/white.svg){height="16"
width="16"}!(images/black.svg){height="16" width="16"} Four\
!(images/black.svg){height="16"
width="16"}!(images/white.svg){height="16" width="16"} Five\
!(images/black.svg){height="16"
width="16"}!(images/black.svg){height="16" width="16"} Six\
!(images/white.svg){height="16"
width="16"}!(images/white.svg){height="16"
width="16"}!(images/white.svg){height="16" width="16"} Seven

 This example requires support for SVG images to display
correctly.

If there are `N` [counter
symbols](#counter-symbol),
the representation is a base `N` alphabetic number using the
[counter symbols] as digits. To construct the
representation, run the following algorithm:

Let `N` be the length of the list of [counter
symbols](#counter-symbol),
`value` initially be the counter value, `S`
initially be the empty string, and `symbol(n)` be the nth
[counter symbol] in the list of [counter
symbols] (0-indexed).

While `value` is not equal to 0:

1. Set `value` to `value`` - 1`.
2. Prepend
 `symbol( ``value`` mod ``N`` )`
 to `S`.
3. Set `value` to
 `floor( ``value`` / ``N`` )`.

Finally, return `S`.

Tests

- [system-alphabetic.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/system-alphabetic.html "css/css-counter-styles/counter-style-at-rule/system-alphabetic.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/system-alphabetic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/system-alphabetic.html)
- [system-alphabetic-invalid.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/system-alphabetic-invalid.html "css/css-counter-styles/counter-style-at-rule/system-alphabetic-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/system-alphabetic-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/system-alphabetic-invalid.html)

#### 3.1.5. Positional Numerals: the [numeric system]
The [numeric]
counter system interprets the list of [counter
symbols](#counter-symbol) as
digits to a \"place-value\" numbering system, similar to the default
[decimal](#decimal) counter
style. The first [counter symbol] in the list
is interpreted as the digit 0, the second as the digit 1, and so on.

If the system is
[numeric](#valdef-counter-style-system-numeric), the
[symbols](#descdef-counter-style-symbols) descriptor must contain at least two
[counter symbols](#counter-symbol), otherwise the rule does not define a counter style
(but is still a valid rule). This system is defined over all counter
values.

A \"trinary\" counter style can be
defined as:

 @counter-style trinary {
 system: numeric;
 symbols: '0' '1' '2';
 }

It will then produce lists that look like:

 1. One
 2. Two
 10. Three
 11. Four
 12. Five
 20. Six

If there are `N` [counter
symbols](#counter-symbol),
the representation is a base `N` number using the [counter
symbols] as digits. To construct the
representation, run the following algorithm:

Let `N` be the length of the list of [counter
symbols](#counter-symbol),
`value` initially be the counter value, `S`
initially be the empty string, and `symbol(n)` be the nth
[counter symbol] in the list of [counter
symbols] (0-indexed).

1. If `value` is 0, append `symbol(0)` to `S` and
 return `S`.
2. While `value` is not equal to 0:
 1. Prepend
 `symbol( ``value`` mod ``N`` )`
 to `S`.
 2. Set `value` to
 `floor( ``value`` / ``N`` )`.
3. Return `S`.

Tests

- [system-numeric.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/system-numeric.html "css/css-counter-styles/counter-style-at-rule/system-numeric.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/system-numeric.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/system-numeric.html)
- [system-numeric-invalid.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/system-numeric-invalid.html "css/css-counter-styles/counter-style-at-rule/system-numeric-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/system-numeric-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/system-numeric-invalid.html)

#### 3.1.6. Accumulating Numerals: the [additive system]
The [additive]
counter system is used to represent \"sign-value\" numbering systems,
which, rather than reusing digits in different positions to change their
value, define additional digits with much larger values, so that the
value of the number can be obtained by adding all the digits together.
This is used in Roman numerals and other numbering systems around the
world.

If the system is
[additive](#valdef-counter-style-system-additive), the
[additive-symbols](#descdef-counter-style-additive-symbols) descriptor must contain at least one
[additive tuple](#additive-tuple), otherwise the rule does not define a counter style
(but is still a valid rule). This system is nominally defined over all
counter values (see algorithm, below, for exact details).

A \"dice\" counter style can be
defined as:

 @counter-style dice {
 system: additive;
 additive-symbols: 6 ⚅, 5 ⚄, 4 ⚃, 3 ⚂, 2 ⚁, 1 ⚀;
 suffix: " ";
 }

It will then produce lists that look like:

 ⚀ One
 ⚁ Two
 ⚂ Three
 ...
 ⚅⚄ Eleven
 ⚅⚅ Twelve
 ⚅⚅⚀ Thirteen

To construct the representation:

1. Let `value` initially be the counter value,
 `S` initially be the empty string, and
 `symbol list` initially be the list of [additive
 tuples](#additive-tuple).

2. If `value` is zero:

 1. If `symbol list` contains a tuple with a weight of
 zero, append that tuple's [counter
 symbol](#counter-symbol) to `S` and return `S`.

 2. Otherwise, the given counter value cannot be represented by this
 counter style, and must instead be represented by the fallback
 counter style.

3. For each `tuple` in `symbol list`:

 1. Let `symbol` and `weight` be
 `tuple`'s [counter
 symbol](#counter-symbol) and weight, respectively.

 2. If `weight` is zero, or `weight` is
 greater than `value`,
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 3. Let `reps` be
 `floor( ``value`` / ``weight`` )`.

 4. Append `symbol` to `S` `reps`
 times.

 5. Decrement `value` by
 `weight`` * ``reps`.

 6. If `value` is zero, return `S`.

4. Assertion: `value` is still non-zero.

 The given counter value cannot be represented by this counter style,
 and must instead be represented by the fallback counter style.

- [system-additive.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/system-additive.html "css/css-counter-styles/counter-style-at-rule/system-additive.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/system-additive.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/system-additive.html)
- [system-additive-invalid.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/system-additive-invalid.html "css/css-counter-styles/counter-style-at-rule/system-additive-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/system-additive-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/system-additive-invalid.html)

 All of the predefined additive
[\@counter-style](#at-ruledef-counter-style) rules in this specification produce
representations for every value in their range, but it's possible to
produce values for [additive-symbols] that will fail to find a
representation with the algorithm defined above, even though
theoretically a representation could be found. For example, if a
[\@counter-style] was defined
with [additive-symbols: 3 \"a\", 2
\"b\";](#descdef-counter-style-additive-symbols), the algorithm defined above will fail to
find a representation for a counter value of 4, even though
theoretically a \"bb\" representation would work. While unfortunate,
this is required to maintain the property that the algorithm runs in
linear time relative to the size of the counter value.

#### 3.1.7. Building from Existing Counter Styles: the [extends system ]
The [extends]
system allows an author to use the algorithm of another counter style,
but alter other aspects, such as the negative sign or the suffix. If a
counter style uses the
[extends](#valdef-counter-style-system-extends) system, any unspecified descriptors must be
taken from the extended counter style specified, rather than taking
their initial values.

If a
[\@counter-style](#at-ruledef-counter-style) uses the
[extends](#valdef-counter-style-system-extends) system, it must not contain a
[symbols](#descdef-counter-style-symbols) or
[additive-symbols](#descdef-counter-style-additive-symbols) descriptor, otherwise the rule does not
define a counter style (but is still a valid rule).

If the specified
[\<counter-style-name\>](#typedef-counter-style-name) is a
[\<symbolic-glyph\>](#typedef-symbolic-glyph) (an [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for any of the [predefined symbolic counter
styles](#predefined-symbolic-counter-style)), using [extend] extends from the "standard"
definition of the rules provided in the normative stylesheet (rather
than the exception allowing them to be drawn in a different,
user-agent-specific fashion).

If the specified counter style name isn't the name of any defined
counter style, it must be treated as if it was extending the
[decimal](#decimal) counter
style. If one or more
[\@counter-style](#at-ruledef-counter-style) rules form a cycle with their
[extends](#valdef-counter-style-system-extends) values, all of the counter styles participating
in the cycle must be treated as if they were extending the
[decimal] counter style instead.

For example, if you wanted a counter
style that was identical to decimal, but used a parenthesis rather than
a period after it, like:

 1) first item
 2) second item
 3) third item

Rather than writing up an entirely new counter style, this can be done
by just extending [decimal](#decimal):

 @counter-style decimal-paren {
 system: extends decimal;
 suffix: ") ";
 }

- [dependent-builtin.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/dependent-builtin.html "css/css-counter-styles/counter-style-at-rule/dependent-builtin.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/dependent-builtin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/dependent-builtin.html)
- [system-extends.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/system-extends.html "css/css-counter-styles/counter-style-at-rule/system-extends.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/system-extends.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/system-extends.html)
- [system-extends-fixed.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/system-extends-fixed.html "css/css-counter-styles/counter-style-at-rule/system-extends-fixed.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/system-extends-fixed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/system-extends-fixed.html)
- [system-extends-invalid.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/system-extends-invalid.html "css/css-counter-styles/counter-style-at-rule/system-extends-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/system-extends-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/system-extends-invalid.html)

### 3.2. Formatting negative values: the [negative descriptor]
Name:

[negative]

For:

[\@counter-style](#at-ruledef-counter-style)

Value:

[\<symbol\>](#typedef-symbol) [\<symbol\>][?](https://drafts.csswg.org/css-values-4/#mult-opt)

Initial:

\"-\"

Tests

- [descriptor-negative.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/descriptor-negative.html "css/css-counter-styles/counter-style-at-rule/descriptor-negative.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/descriptor-negative.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/descriptor-negative.html)
- [descriptor-negative-invalid.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/descriptor-negative-invalid.html "css/css-counter-styles/counter-style-at-rule/descriptor-negative-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/descriptor-negative-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/descriptor-negative-invalid.html)
- [negative-syntax.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/negative-syntax.html "css/css-counter-styles/counter-style-at-rule/negative-syntax.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/negative-syntax.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/negative-syntax.html)

The
[negative](#descdef-counter-style-negative) descriptor defines how to alter the
representation when the counter value is negative.

The first [\<symbol\>](#typedef-symbol) in the value is prepended to the
representation when the counter value is negative. The second
[\<symbol\>], if specified, is
appended to the representation when the counter value is negative.

For example, specifying [negative:
\"(\"
\")\";](#descdef-counter-style-negative) will make negative values be wrapped in
parentheses, which is sometimes used in financial contexts, like \"(2)
(1) 0 1 2 3\...\".

Not all
[system](#descdef-counter-style-system) values use a negative sign. In
particular, a counter style [uses a negative sign] if its
[system] value is
[symbolic](#valdef-system-symbolic),
[alphabetic](#valdef-counter-style-system-alphabetic),
[numeric](#valdef-counter-style-system-numeric),
[additive](#valdef-counter-style-system-additive), or
[extends](#valdef-counter-style-system-extends) if the extended counter style itself [uses a
negative sign](#use-a-negative-sign). If a counter style does not [use a negative
sign], it ignores the negative sign when
[generating a counter
representation](#generate-a-counter).

### 3.3. Symbols before the marker: the [prefix descriptor]
Name:

[prefix]

For:

[\@counter-style](#at-ruledef-counter-style)

Value:

[\<symbol\>](#typedef-symbol)

Initial:

\"\"

Tests

- [descriptor-prefix.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/descriptor-prefix.html "css/css-counter-styles/counter-style-at-rule/descriptor-prefix.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/descriptor-prefix.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/descriptor-prefix.html)
- [descriptor-prefix-invalid.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/descriptor-prefix-invalid.html "css/css-counter-styles/counter-style-at-rule/descriptor-prefix-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/descriptor-prefix-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/descriptor-prefix-invalid.html)
- [prefix-suffix-syntax.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/prefix-suffix-syntax.html "css/css-counter-styles/counter-style-at-rule/prefix-suffix-syntax.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/prefix-suffix-syntax.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/prefix-suffix-syntax.html)

The
[prefix](#descdef-counter-style-prefix) descriptor specifies a
[\<symbol\>](#typedef-symbol) that is prepended to the marker representation.
Prefixes come before any negative sign.

 Prefixes are only added by the algorithm for
constructing the default contents of the
[::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker) pseudo-element; the prefix is not added
automatically when the
[counter()](https://drafts.csswg.org/css-lists-3/#funcdef-counter) or
[counters()](https://drafts.csswg.org/css-lists-3/#funcdef-counters) functions are used.

### 3.4. Symbols after the marker: the [suffix descriptor]
Name:

[suffix]

For:

[\@counter-style](#at-ruledef-counter-style)

Value:

[\<symbol\>](#typedef-symbol)

Initial:

\". \"

Tests

- [descriptor-suffix.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/descriptor-suffix.html "css/css-counter-styles/counter-style-at-rule/descriptor-suffix.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/descriptor-suffix.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/descriptor-suffix.html)
- [descriptor-suffix-invalid.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/descriptor-suffix-invalid.html "css/css-counter-styles/counter-style-at-rule/descriptor-suffix-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/descriptor-suffix-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/descriptor-suffix-invalid.html)

The
[suffix](#descdef-counter-style-suffix) descriptor specifies a
[\<symbol\>](#typedef-symbol) that is appended to the marker representation.
Suffixes are added to the representation after negative signs.

 Suffixes are only added by the algorithm for
constructing the default contents of the
[::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker) pseudo-element; the suffix is not added
automatically when the counter() or counters() functions are used.

### 3.5. Limiting the counter scope: the [range descriptor]
Name:

[range]

For:

[\@counter-style](#at-ruledef-counter-style)

Value:

\[ \[
[\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value)
[\|](https://drafts.csswg.org/css-values-4/#comb-one) infinite
\][{2}](https://drafts.csswg.org/css-values-4/#mult-num)
\][\#](https://drafts.csswg.org/css-values-4/#mult-comma) [\|] auto

Initial:

auto

Tests

- [descriptor-range.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/descriptor-range.html "css/css-counter-styles/counter-style-at-rule/descriptor-range.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/descriptor-range.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/descriptor-range.html)
- [descriptor-range-invalid.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/descriptor-range-invalid.html "css/css-counter-styles/counter-style-at-rule/descriptor-range-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/descriptor-range-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/descriptor-range-invalid.html)
- [range-syntax.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/range-syntax.html "css/css-counter-styles/counter-style-at-rule/range-syntax.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/range-syntax.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/range-syntax.html)

The
[range](#descdef-counter-style-range) descriptor defines the ranges over which
the counter style is defined. If a counter style is used to represent a
counter value outside of its ranges, the counter style instead drops
down to its fallback counter style.

[auto]
: The range depends on the counter system:
 - For
 [cyclic](#valdef-counter-style-system-cyclic),
 [numeric](#valdef-counter-style-system-numeric), and
 [fixed](#valdef-counter-style-system-fixed) systems, the range is negative infinity to
 positive infinity.
 - For
 [alphabetic](#valdef-counter-style-system-alphabetic) and
 [symbolic](#valdef-system-symbolic) systems, the range is 1 to positive
 infinity.
 - For
 [additive](#valdef-counter-style-system-additive) systems, the range is 0 to positive
 infinity.
 - For
 [extends](#valdef-counter-style-system-extends) systems, the range is whatever
 [auto](#valdef-counter-style-range-auto) would produce for the extended system; if
 extending a complex predefined style ([§ 7 Complex Predefined
 Counter Styles](#complex-predefined-counters)), the range is the
 style's defined range.

\[ \[ [\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value) \| infinite \]{2} \]#

: This defines a comma-separated list of ranges. For each individual
 range, the first value is the lower bound and the second value is
 the upper bound. This range is inclusive - it contains both the
 lower and upper bound numbers. If [infinite] is used as the
 first value in a range, it represents negative infinity; if used as
 the second value, it represents positive infinity. The range of the
 counter style is the union of all the ranges defined in the list.

 If the lower bound of any range is higher than the upper bound, the
 entire descriptor is invalid and must be ignored.

Implementations must support ranges with a lower bound of at least
-2^15^ and an upper bound of at least 2^15^-1 (the range of a signed
2-byte int). They may support higher ranges. If any specified bound is
outside of the implementation's supported bounds, it must be treated as
the closest bound that the implementation does support.

### 3.6. Zero-Padding and Constant-Width Representations: the [pad descriptor]
Name:

[pad]

For:

[\@counter-style](#at-ruledef-counter-style)

Value:

[\<integer
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#integer-value)
[&&](https://drafts.csswg.org/css-values-4/#comb-all)
[\<symbol\>](#typedef-symbol)

Initial:

0 \"\"

Tests

- [descriptor-pad.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/descriptor-pad.html "css/css-counter-styles/counter-style-at-rule/descriptor-pad.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/descriptor-pad.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/descriptor-pad.html)
- [descriptor-pad-invalid.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/descriptor-pad-invalid.html "css/css-counter-styles/counter-style-at-rule/descriptor-pad-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/descriptor-pad-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/descriptor-pad-invalid.html)
- [pad-syntax.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/pad-syntax.html "css/css-counter-styles/counter-style-at-rule/pad-syntax.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/pad-syntax.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/pad-syntax.html)

The
[pad](#descdef-counter-style-pad) descriptor allows an author to specify a
\"fixed-width\" counter style, where representations shorter than the
pad value are padded with a particular
[\<symbol\>](#typedef-symbol). Representations larger than the specified pad value
are constructed as normal.

[\<integer \[0,∞\]\>](https://drafts.csswg.org/css-values-4/#integer-value) && [\<symbol\>](#typedef-symbol)

: The
 [\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value) specifies a minimum length that
 all counter representations must reach.

 Let `difference` be the provided
 [\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value) minus the number of [grapheme
 clusters](https://drafts.csswg.org/css-text-3/#grapheme-cluster) in the [initial representation for the counter
 value](#initial-representation-for-the-counter-value). [(Note that, per the algorithm to [generate a
 counter
 representation](#generate-a-counter), this occurs before adding
 prefixes/suffixes/negatives.)] If the counter value is
 negative and the counter style [uses a negative
 sign](#use-a-negative-sign), further reduce `difference` by the
 number of [grapheme clusters] in the
 counter style's
 [negative](#descdef-counter-style-negative) descriptor's
 [\<symbol\>](#typedef-symbol)(s).

 If `difference` is greater than zero, prepend
 `difference` copies of the specified
 [\<symbol\>](#typedef-symbol) to the representation.

 Negative
 [\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value) values are not allowed.

The most common example of
\"fixed-width\" numbering is zero-padded decimal numbering. If an author
knows that the numbers used will be less than a thousand, for example,
it can be zero-padded with a simple [pad: 3
\"0\";](#descdef-counter-style-pad) descriptor, ensuring that all of the
representations are 3 digits wide.

This will cause, for example, 1 to be represented as \"001\", 20 to be
represented as \"020\", 300 to be represented as \"300\", 4000 to be
represented as \"4000\", and -5 to be represented as \"-05\".

[pad](#descdef-counter-style-pad) descriptor counts the number of
[grapheme
clusters](https://drafts.csswg.org/css-text-3/#grapheme-cluster) in the representation, but pads it with
[\<symbol\>](#typedef-symbol)s. If the specified
[pad]
[\<symbol\>] is multi-character,
this will likely not have the desired effect. Unfortunately, there's no
way to use the number of [grapheme clusters]
in the [pad]
[\<symbol\>] without violating
useful constraints. It is recommended that authors only specify
[\<symbol\>]s of a single
[grapheme cluster] in the
[pad] descriptor.

### 3.7. Defining fallback: the [fallback descriptor]
Name:

[fallback]

For:

[\@counter-style](#at-ruledef-counter-style)

Value:

[\<counter-style-name\>](#typedef-counter-style-name)

Initial:

decimal

Tests

- [descriptor-fallback.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/descriptor-fallback.html "css/css-counter-styles/counter-style-at-rule/descriptor-fallback.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/descriptor-fallback.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/descriptor-fallback.html)
- [descriptor-fallback-invalid.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/descriptor-fallback-invalid.html "css/css-counter-styles/counter-style-at-rule/descriptor-fallback-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/descriptor-fallback-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/descriptor-fallback-invalid.html)
- [fallback.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/fallback.html "css/css-counter-styles/counter-style-at-rule/fallback.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/fallback.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/fallback.html)
- [fallbacks-in-shadow-dom.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/fallbacks-in-shadow-dom.html "css/css-counter-styles/counter-style-at-rule/fallbacks-in-shadow-dom.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/fallbacks-in-shadow-dom.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/fallbacks-in-shadow-dom.html)

The
[fallback](#descdef-counter-style-fallback) descriptor specifies a fallback counter
style to be used when the current counter style can't create a
representation for a given counter value. For example, if a counter
style defined with a range of 1-10 is asked to represent a counter value
of 11, the counter value's representation is instead constructed with
the fallback counter style (or possibly the fallback style's fallback
style, if the fallback style can't represent that value, etc.).

If the value of the
[fallback](#descdef-counter-style-fallback) descriptor isn't the name of any defined
counter style, the used value of the
[fallback]
descriptor is [decimal](#decimal) instead. Similarly, while following fallbacks to find
a counter style that can render the given counter value, if a loop in
the specified fallbacks is detected, the [decimal] style must be used instead.

Note that it is not necessarily an error to specify fallback loops. For
example, if an author desires a counter style with significantly
different representations for even and odd counter values, they may find
it easiest to define one style that can only represent odd values and
one that can only represent even values, and specify each as the
fallback for the other one. Though the fallback graph is circular, at no
point do you encounter a loop while following these fallbacks - every
counter value is represented by one or the other counter style.

### 3.8. Marker characters: the [symbols and [additive-symbols](#descdef-counter-style-additive-symbols) descriptors]
Name:

[symbols]

For:

[\@counter-style](#at-ruledef-counter-style)

Value:

[\<symbol\>](#typedef-symbol)[+](https://drafts.csswg.org/css-values-4/#mult-one-plus)

Initial:

n/a

Name:

[additive-symbols]

For:

[\@counter-style](#at-ruledef-counter-style)

Value:

\[ [\<integer
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#integer-value)
[&&](https://drafts.csswg.org/css-values-4/#comb-all)
[\<symbol\>](#typedef-symbol)
\][\#](https://drafts.csswg.org/css-values-4/#mult-comma)

Initial:

n/a

Tests

- [additive-symbols-syntax.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/additive-symbols-syntax.html "css/css-counter-styles/counter-style-at-rule/additive-symbols-syntax.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/additive-symbols-syntax.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/additive-symbols-syntax.html)
- [descriptor-symbols.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/descriptor-symbols.html "css/css-counter-styles/counter-style-at-rule/descriptor-symbols.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/descriptor-symbols.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/descriptor-symbols.html)
- [descriptor-symbols-invalid.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/descriptor-symbols-invalid.html "css/css-counter-styles/counter-style-at-rule/descriptor-symbols-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/descriptor-symbols-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/descriptor-symbols-invalid.html)
- [symbols-syntax.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/symbols-syntax.html "css/css-counter-styles/counter-style-at-rule/symbols-syntax.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/symbols-syntax.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/symbols-syntax.html)

``` prod
<symbol> = <string> | <image> | <custom-ident>
```

Tests

- [broken-symbols.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/broken-symbols.html "css/css-counter-styles/counter-style-at-rule/broken-symbols.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/broken-symbols.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/broken-symbols.html)
- [empty-string-symbol.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/empty-string-symbol.html "css/css-counter-styles/counter-style-at-rule/empty-string-symbol.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/empty-string-symbol.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/empty-string-symbol.html)

The
[symbols](#descdef-counter-style-symbols) and
[additive-symbols](#descdef-counter-style-additive-symbols) descriptors specify the symbols used by
the marker-construction algorithm specified by the
[system](#descdef-counter-style-system) descriptor. The
[\@counter-style](#at-ruledef-counter-style) rule must have a valid
[symbols] descriptor
if the counter system is
[cyclic](#valdef-counter-style-system-cyclic),
[numeric](#valdef-counter-style-system-numeric),
[alphabetic](#valdef-counter-style-system-alphabetic),
[symbolic](#valdef-system-symbolic), or
[fixed](#valdef-counter-style-system-fixed), or a valid
[additive-symbols] descriptor if the counter system is
[additive](#valdef-counter-style-system-additive); otherwise, the
[\@counter-style] does not
define a [counter style](#counter-style) (but is still a valid
[at-rule](https://drafts.csswg.org/css-syntax-3/#at-rule)).

Some counter systems specify that the
[symbols](#descdef-counter-style-symbols) descriptor must have at least two
entries. If the counter style's system is such, and the
[symbols] descriptor
has only a single entry, the
[\@counter-style](#at-ruledef-counter-style) rule does not define a [counter
style](#counter-style).

Each entry in the
[symbols](#descdef-counter-style-symbols) descriptor's value defines a [counter
symbol],
which is interpreted differently based on the counter style's system.
Each entry in the
[additive-symbols](#descdef-counter-style-additive-symbols) descriptor's value defines an [additive
tuple],
which consists of a [counter
symbol](#counter-symbol) and
an integer weight. Each weight must be a non-negative integer, and the
[additive tuples](#additive-tuple) must be specified in order of strictly descending
weight; otherwise, the declaration is invalid and must be ignored.

[Counter symbols](#counter-symbol) may be strings, images, or identifiers, and the three
types can be mixed in a single descriptor. Counter representations are
constructed by concatenating counter symbols together. Identifiers are
rendered as strings containing the same characters. Images are rendered
as inline replaced elements. The [default object
size](https://drafts.csswg.org/css-images-3/#default-object-size) of an image [counter symbol]
is a 1em by 1em square.

 The
[\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image) syntax in
[\<symbol\>](#typedef-symbol) is currently at-risk. No implementations have plans to
implement it currently, and it complicates some usages of
[counter()](https://drafts.csswg.org/css-lists-3/#funcdef-counter) in ways that haven't been fully handled.

 If using identifiers rather than strings to define the
symbols, be aware of the syntax of identifiers. In particular, ascii
non-letters like \"\*\" are not identifiers, and so must be quoted in a
string. Hex escapes, used in several of the counter styles defined in
this specification, \"eat\" the following space (to allow a digit to
follow a hex escape without ambiguity), so two spaces must be put after
a hex escape to separate it from the following one, or else they'll be
considered adjacent, and part of the same identifier. For example,
[symbols: \\660
\\661;](#descdef-counter-style-symbols) only defines a single symbol, consisting of
the U+0660 and U+0661 characters, rather than the two that were
intended; either quote the escapes in strings, like [symbols: \"\\660\"
\"\\661\"], or put two
spaces between the escapes.

### 3.9. Speech Synthesis: the [speak-as descriptor]
Name:

[speak-as]

For:

[\@counter-style](#at-ruledef-counter-style)

Value:

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) bullets [\|] numbers
[\|] words [\|] spell-out
[\|]
[\<counter-style-name\>](#typedef-counter-style-name)

Initial:

auto

Tests

- [speak-as-manual.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/speak-as-manual.html)
- [speak-as-syntax.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/speak-as-syntax.html "css/css-counter-styles/counter-style-at-rule/speak-as-syntax.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/speak-as-syntax.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/speak-as-syntax.html)

A counter style can be constructed with a meaning that is obvious
visually, but impossible to meaningfully represent via a speech
synthesizer or other non-visual means, or possible but nonsensical when
naively read out loud. The
[speak-as](#descdef-counter-style-speak-as) descriptor describes how to synthesize
the spoken form of a counter formatted with the given counter style.
Assistive technologies should use this spoken form when reading out the
counter style, and may use the
[speak-as] value to
inform transformations to outputs other than speech. Values have the
following meanings:

[auto]
: If the counter style's
 [system](#descdef-counter-style-system) is
 [alphabetic](#valdef-counter-style-system-alphabetic), this value has the same effect as
 [spell-out](#valdef-counter-style-speak-as-spell-out). If the
 [system] is
 [cyclic](#valdef-counter-style-system-cyclic), this value has the same effect as
 [bullets](#valdef-counter-style-speak-as-bullets). If the
 [system] is
 [extends](#valdef-counter-style-system-extends), this value has the same effect as
 [auto](#valdef-counter-style-speak-as-auto) would have for the extended style.
 Otherwise, this value has the same effect as
 [numbers](#valdef-counter-style-speak-as-numbers).

[bullets]
: The UA speaks a UA-defined phrase or audio cue that represents an
 unordered list item being read out.

[numbers]
: The counter's numeric value is spoken as a number in the [content
 language](https://drafts.csswg.org/css-text-4/#content-language).

[words]
: [Generate a counter
 representation](#generate-a-counter) for the value as normal, then speak it as normal
 text in the [content
 language](https://drafts.csswg.org/css-text-4/#content-language). If the counter representation contains images,
 instead handle the value as for
 [numbers](#valdef-counter-style-speak-as-numbers).

[spell-out]

: [Generate a counter
 representation](#generate-a-counter) for the value as normal, then spell it out
 letter-by-letter in the [content
 language](https://drafts.csswg.org/css-text-4/#content-language). If the UA does not know how to pronounce the
 symbols (or the counter representation contains images), it must
 instead handle the value as for
 [numbers](#valdef-counter-style-speak-as-numbers).

 For example, [lower-greek](#lower-greek) in English would be read out as \"alpha\",
 \"beta\", \"gamma\", etc. Conversely,
 [upper-latin](#upper-latin) in French would be read out as (in phonetic
 notation) /a/, /be/, /se/, etc.

[[\<counter-style-name\>](#typedef-counter-style-name)]
: The counter's value is instead spoken out in the specified style
 (similar to the behavior of the
 [fallback](#descdef-counter-style-fallback) descriptor when generating
 representations for a counter value). If the specified style does
 not exist, this value is treated as
 [auto](#valdef-counter-style-speak-as-auto). If a loop is detected when following
 [speak-as](#descdef-counter-style-speak-as) references, this value is treated as
 [auto] for the
 counter styles participating in the loop.

The ability to defer pronunciation to
another counter style can help when the symbols being used aren't
actually letters. For example, here's a possible definition of a
[circled-lower-latin] counter-style, using some special Unicode
characters:

``` stylesheet
@counter-style circled-lower-latin {
 system: alphabetic;
 speak-as: lower-latin;
 symbols: ⓐ ⓑ ⓒ ⓓ ⓔ ⓕ ⓖ ⓗ ⓘ ⓙ ⓚ ⓛ ⓜ ⓝ ⓞ ⓟ ⓠ ⓡ ⓢ ⓣ ⓤ ⓥ ⓦ ⓧ ⓨ ⓩ;
 suffix: " ";
}
```

Setting its
[system](#descdef-counter-style-system) to
[alphabetic](#valdef-counter-style-system-alphabetic) would normally make the UA try to read out the
names of the characters, but in this case that might be something like
\"Circled Letter A\", which is unlikely to make sense. Instead,
explicitly setting
[speak-as](#descdef-counter-style-speak-as) to
[lower-latin](#lower-latin)
ensures that they get read out as their corresponding latin letters, as
intended.

## 4. Defining Anonymous Counter Styles: the [symbols() function]
The [symbols()](#funcdef-symbols) function allows a [counter
style](#counter-style) to be
defined inline in a property value, for when a style is used only once
in a stylesheet and defining a full
[\@counter-style](#at-ruledef-counter-style) rule would be overkill. It does not provide the
full feature-set of the
[\@counter-style] rule, but
provides a sufficient subset to still be useful. The syntax of the
[symbols()] rule is:

``` prod
symbols() = symbols( <symbols-type>? [ <string> | <image> ]+ )
<symbols-type> = cyclic | numeric | alphabetic | symbolic | fixed
```

Tests

The [symbols()](#funcdef-symbols) function defines an anonymous counter style with no
name, a
[prefix](#descdef-counter-style-prefix) of [\"\"] (empty string) and
[suffix](#descdef-counter-style-suffix) of [\" \"] (U+0020 SPACE), a
[range](#descdef-counter-style-range) of
[auto](#valdef-counter-style-range-auto), a
[fallback](#descdef-counter-style-fallback) of [decimal](#decimal), a
[negative](#descdef-counter-style-negative) of [\"\\2D\"] (\"-\"
hyphen-minus), a
[pad](#descdef-counter-style-pad) of [0 \"\"], and a
[speak-as](#descdef-counter-style-speak-as) of
[auto](#valdef-counter-style-speak-as-auto). The counter style's algorithm is constructed by
consulting the previous chapter using the provided system --- or
[symbolic](#valdef-system-symbolic) if the system was omitted --- and the provided
[\<string\>](https://drafts.csswg.org/css-values-4/#string-value)s and
[\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image)s as the value of the
[symbols](#descdef-counter-style-symbols) property. If the system is
[fixed](#valdef-counter-style-system-fixed), the [first symbol
value](#first-symbol-value) is [1].

If the system is
[alphabetic](#valdef-counter-style-system-alphabetic) or
[numeric](#valdef-counter-style-system-numeric), there must be at least two
[\<string\>](https://drafts.csswg.org/css-values-4/#string-value)s or
[\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image)s, or else the function is invalid.

This code:

 ol { list-style: symbols("*" "\2020" "\2021" "\A7"); }

will produce lists that look like:

 * One
 † Two
 ‡ Three
 § Four
 ** Five
 †† Six
 ‡‡ Seven

On the other hand, specifying the system of counter, like so:

 ol { list-style: symbols(cyclic "*" "\2020" "\2021" "\A7"); }

will produce lists that look like:

 * One
 † Two
 ‡ Three
 § Four
 * Five
 † Six
 ‡ Seven

[symbols()](#funcdef-symbols) function only allows strings and images, while the
[symbols](#descdef-counter-style-symbols) descriptor of a
[\@counter-style](#at-ruledef-counter-style) rule also allows identifiers.

## [5. ][ Extending [list-style-type](https://drafts.csswg.org/css-lists-3/#propdef-list-style-type), [counter()](https://drafts.csswg.org/css-lists-3/#funcdef-counter), and [counters()](https://drafts.csswg.org/css-lists-3/#funcdef-counters)]
In CSS Level 2
[\[CSS21\]](#biblio-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
the
[list-style-type](https://drafts.csswg.org/css-lists-3/#propdef-list-style-type) property and the
[counter()](https://drafts.csswg.org/css-lists-3/#funcdef-counter) and
[counters()](https://drafts.csswg.org/css-lists-3/#funcdef-counters) notations accept various pre-defined keywords,
each identifying a counter style. This module extends these features to
take instead the
[\<counter-style\>](#typedef-counter-style) type, defined below:

``` prod
<counter-style> = <counter-style-name> | <symbols()>
```

If a
[\<counter-style-name\>](#typedef-counter-style-name) is used that does not refer to any
existing counter style, it must act identically to the
[decimal](#decimal) counter
style (but does not
*[compute](https://drafts.csswg.org/css-cascade-5/#computed-value)* to [decimal]).

When used in these contexts, a
[\<counter-style-name\>](#typedef-counter-style-name) is a [tree-scoped
reference](https://drafts.csswg.org/css-shadow-1/#css-tree-scoped-reference).

## 6. Simple Predefined Counter Styles

The following stylesheet uses the
[\@counter-style](#at-ruledef-counter-style) rule to redefine all of the counter styles
defined in CSS 2 and CSS 2.1. This stylesheet is normative---​UAs must
include it in their UA stylesheet (or at least act as if these rules
were defined at that level).

### 6.1. Numeric: [decimal, [decimal-leading-zero](#decimal-leading-zero), [arabic-indic](#valdef-counter-style-name-arabic-indic), [armenian](#armenian), [upper-armenian](#valdef-counter-style-name-upper-armenian), [lower-armenian](#valdef-counter-style-name-lower-armenian), [bengali](#valdef-counter-style-name-bengali), [cambodian](#valdef-counter-style-name-cambodian), [khmer](#valdef-counter-style-name-khmer), [cjk-decimal](#cjk-decimal), [devanagari](#valdef-counter-style-name-devanagari), [georgian](#georgian), [gujarati](#valdef-counter-style-name-gujarati), [gurmukhi](#valdef-counter-style-name-gurmukhi), [hebrew](#hebrew), [kannada](#valdef-counter-style-name-kannada), [lao](#valdef-counter-style-name-lao), [malayalam](#valdef-counter-style-name-malayalam), [mongolian](#valdef-counter-style-name-mongolian), [myanmar](#valdef-counter-style-name-myanmar), [oriya](#valdef-counter-style-name-oriya), [persian](#valdef-counter-style-name-persian), [lower-roman](#lower-roman), [upper-roman](#upper-roman), [tamil](#valdef-counter-style-name-tamil), [telugu](#valdef-counter-style-name-telugu), [thai](#valdef-counter-style-name-thai), [tibetan](#valdef-counter-style-name-tibetan)]
[decimal]
: Western decimal numbers (e.g., 1, 2, 3, \..., 98, 99, 100).

[decimal-leading-zero]
: Decimal numbers padded by initial zeros (e.g., 01, 02, 03, \..., 98,
 99, 100).

[arabic-indic]
: Arabic-indic numbering (e.g., ١‎, ٢‎, ٣‎, ٤‎, \..., ٩٨‎, ٩٩‎, ١٠٠‎).
 Tests
 - [css3-counter-styles-101.html](https://wpt.fyi/results/css/css-counter-styles/arabic-indic/css3-counter-styles-101.html "css/css-counter-styles/arabic-indic/css3-counter-styles-101.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/arabic-indic/css3-counter-styles-101.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/arabic-indic/css3-counter-styles-101.html)
 - [css3-counter-styles-102.html](https://wpt.fyi/results/css/css-counter-styles/arabic-indic/css3-counter-styles-102.html "css/css-counter-styles/arabic-indic/css3-counter-styles-102.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/arabic-indic/css3-counter-styles-102.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/arabic-indic/css3-counter-styles-102.html)
 - [css3-counter-styles-103.html](https://wpt.fyi/results/css/css-counter-styles/arabic-indic/css3-counter-styles-103.html "css/css-counter-styles/arabic-indic/css3-counter-styles-103.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/arabic-indic/css3-counter-styles-103.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/arabic-indic/css3-counter-styles-103.html)

[armenian]\
[upper-armenian]
: Traditional uppercase Armenian numbering (e.g., Ա, Բ, Գ, \..., ՂԸ,
 ՂԹ, Ճ).
 Tests
 - [css3-counter-styles-006.html](https://wpt.fyi/results/css/css-counter-styles/armenian/css3-counter-styles-006.html "css/css-counter-styles/armenian/css3-counter-styles-006.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/armenian/css3-counter-styles-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/armenian/css3-counter-styles-006.html)
 - [css3-counter-styles-007.html](https://wpt.fyi/results/css/css-counter-styles/armenian/css3-counter-styles-007.html "css/css-counter-styles/armenian/css3-counter-styles-007.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/armenian/css3-counter-styles-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/armenian/css3-counter-styles-007.html)
 - [css3-counter-styles-008.html](https://wpt.fyi/results/css/css-counter-styles/armenian/css3-counter-styles-008.html "css/css-counter-styles/armenian/css3-counter-styles-008.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/armenian/css3-counter-styles-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/armenian/css3-counter-styles-008.html)
 - [css3-counter-styles-009.html](https://wpt.fyi/results/css/css-counter-styles/armenian/css3-counter-styles-009.html "css/css-counter-styles/armenian/css3-counter-styles-009.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/armenian/css3-counter-styles-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/armenian/css3-counter-styles-009.html)
 - [css3-counter-styles-107.html](https://wpt.fyi/results/css/css-counter-styles/upper-armenian/css3-counter-styles-107.html "css/css-counter-styles/upper-armenian/css3-counter-styles-107.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/upper-armenian/css3-counter-styles-107.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/upper-armenian/css3-counter-styles-107.html)
 - [css3-counter-styles-108.html](https://wpt.fyi/results/css/css-counter-styles/upper-armenian/css3-counter-styles-108.html "css/css-counter-styles/upper-armenian/css3-counter-styles-108.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/upper-armenian/css3-counter-styles-108.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/upper-armenian/css3-counter-styles-108.html)
 - [css3-counter-styles-109.html](https://wpt.fyi/results/css/css-counter-styles/upper-armenian/css3-counter-styles-109.html "css/css-counter-styles/upper-armenian/css3-counter-styles-109.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/upper-armenian/css3-counter-styles-109.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/upper-armenian/css3-counter-styles-109.html)
 - [css3-counter-styles-110.html](https://wpt.fyi/results/css/css-counter-styles/upper-armenian/css3-counter-styles-110.html "css/css-counter-styles/upper-armenian/css3-counter-styles-110.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/upper-armenian/css3-counter-styles-110.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/upper-armenian/css3-counter-styles-110.html)

[lower-armenian]
: Lowercase Armenian numbering (e.g., ա, բ, գ, \..., ղը, ղթ, ճ).
 Tests
 - [css3-counter-styles-111.html](https://wpt.fyi/results/css/css-counter-styles/lower-armenian/css3-counter-styles-111.html "css/css-counter-styles/lower-armenian/css3-counter-styles-111.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/lower-armenian/css3-counter-styles-111.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/lower-armenian/css3-counter-styles-111.html)
 - [css3-counter-styles-112.html](https://wpt.fyi/results/css/css-counter-styles/lower-armenian/css3-counter-styles-112.html "css/css-counter-styles/lower-armenian/css3-counter-styles-112.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/lower-armenian/css3-counter-styles-112.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/lower-armenian/css3-counter-styles-112.html)
 - [css3-counter-styles-114.html](https://wpt.fyi/results/css/css-counter-styles/lower-armenian/css3-counter-styles-114.html "css/css-counter-styles/lower-armenian/css3-counter-styles-114.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/lower-armenian/css3-counter-styles-114.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/lower-armenian/css3-counter-styles-114.html)
 - [css3-counter-styles-115.html](https://wpt.fyi/results/css/css-counter-styles/lower-armenian/css3-counter-styles-115.html "css/css-counter-styles/lower-armenian/css3-counter-styles-115.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/lower-armenian/css3-counter-styles-115.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/lower-armenian/css3-counter-styles-115.html)

[bengali]
: Bengali numbering (e.g., ১, ২, ৩, \..., ৯৮, ৯৯, ১০০).
 Tests
 - [css3-counter-styles-116.html](https://wpt.fyi/results/css/css-counter-styles/bengali/css3-counter-styles-116.html "css/css-counter-styles/bengali/css3-counter-styles-116.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/bengali/css3-counter-styles-116.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/bengali/css3-counter-styles-116.html)
 - [css3-counter-styles-117.html](https://wpt.fyi/results/css/css-counter-styles/bengali/css3-counter-styles-117.html "css/css-counter-styles/bengali/css3-counter-styles-117.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/bengali/css3-counter-styles-117.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/bengali/css3-counter-styles-117.html)
 - [css3-counter-styles-118.html](https://wpt.fyi/results/css/css-counter-styles/bengali/css3-counter-styles-118.html "css/css-counter-styles/bengali/css3-counter-styles-118.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/bengali/css3-counter-styles-118.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/bengali/css3-counter-styles-118.html)

[cambodian]\
[khmer]
: Cambodian/Khmer numbering (e.g., ១, ២, ៣, \..., ៩៨, ៩៩, ១០០).
 Tests
 - [css3-counter-styles-158.html](https://wpt.fyi/results/css/css-counter-styles/cambodian/css3-counter-styles-158.html "css/css-counter-styles/cambodian/css3-counter-styles-158.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cambodian/css3-counter-styles-158.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cambodian/css3-counter-styles-158.html)
 - [css3-counter-styles-159.html](https://wpt.fyi/results/css/css-counter-styles/cambodian/css3-counter-styles-159.html "css/css-counter-styles/cambodian/css3-counter-styles-159.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cambodian/css3-counter-styles-159.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cambodian/css3-counter-styles-159.html)
 - [css3-counter-styles-160.html](https://wpt.fyi/results/css/css-counter-styles/cambodian/css3-counter-styles-160.html "css/css-counter-styles/cambodian/css3-counter-styles-160.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cambodian/css3-counter-styles-160.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cambodian/css3-counter-styles-160.html)
 - [css3-counter-styles-161.html](https://wpt.fyi/results/css/css-counter-styles/khmer/css3-counter-styles-161.html "css/css-counter-styles/khmer/css3-counter-styles-161.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/khmer/css3-counter-styles-161.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/khmer/css3-counter-styles-161.html)
 - [css3-counter-styles-162.html](https://wpt.fyi/results/css/css-counter-styles/khmer/css3-counter-styles-162.html "css/css-counter-styles/khmer/css3-counter-styles-162.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/khmer/css3-counter-styles-162.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/khmer/css3-counter-styles-162.html)
 - [css3-counter-styles-163.html](https://wpt.fyi/results/css/css-counter-styles/khmer/css3-counter-styles-163.html "css/css-counter-styles/khmer/css3-counter-styles-163.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/khmer/css3-counter-styles-163.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/khmer/css3-counter-styles-163.html)

[cjk-decimal]
: Han decimal numbers (e.g., 一, 二, 三, \..., 九八, 九九, 一〇〇).
 Tests
 - [counter-cjk-decimal.html](https://wpt.fyi/results/css/css-counter-styles/cjk-decimal/counter-cjk-decimal.html "css/css-counter-styles/cjk-decimal/counter-cjk-decimal.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cjk-decimal/counter-cjk-decimal.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cjk-decimal/counter-cjk-decimal.html)
 - [css3-counter-styles-001.html](https://wpt.fyi/results/css/css-counter-styles/cjk-decimal/css3-counter-styles-001.html "css/css-counter-styles/cjk-decimal/css3-counter-styles-001.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cjk-decimal/css3-counter-styles-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cjk-decimal/css3-counter-styles-001.html)
 - [css3-counter-styles-004.html](https://wpt.fyi/results/css/css-counter-styles/cjk-decimal/css3-counter-styles-004.html "css/css-counter-styles/cjk-decimal/css3-counter-styles-004.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cjk-decimal/css3-counter-styles-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cjk-decimal/css3-counter-styles-004.html)
 - [css3-counter-styles-005.html](https://wpt.fyi/results/css/css-counter-styles/cjk-decimal/css3-counter-styles-005.html "css/css-counter-styles/cjk-decimal/css3-counter-styles-005.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cjk-decimal/css3-counter-styles-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cjk-decimal/css3-counter-styles-005.html)

[devanagari]
: devanagari numbering (e.g., १, २, ३, \..., ९८, ९९, १००).
 Tests
 - [css3-counter-styles-119.html](https://wpt.fyi/results/css/css-counter-styles/devanagari/css3-counter-styles-119.html "css/css-counter-styles/devanagari/css3-counter-styles-119.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/devanagari/css3-counter-styles-119.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/devanagari/css3-counter-styles-119.html)
 - [css3-counter-styles-120.html](https://wpt.fyi/results/css/css-counter-styles/devanagari/css3-counter-styles-120.html "css/css-counter-styles/devanagari/css3-counter-styles-120.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/devanagari/css3-counter-styles-120.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/devanagari/css3-counter-styles-120.html)
 - [css3-counter-styles-121.html](https://wpt.fyi/results/css/css-counter-styles/devanagari/css3-counter-styles-121.html "css/css-counter-styles/devanagari/css3-counter-styles-121.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/devanagari/css3-counter-styles-121.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/devanagari/css3-counter-styles-121.html)

[georgian]
: Traditional Georgian numbering (e.g., ა, ბ, გ, \..., ჟჱ, ჟთ, რ).
 Tests
 - [css3-counter-styles-010.html](https://wpt.fyi/results/css/css-counter-styles/georgian/css3-counter-styles-010.html "css/css-counter-styles/georgian/css3-counter-styles-010.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/georgian/css3-counter-styles-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/georgian/css3-counter-styles-010.html)
 - [css3-counter-styles-011.html](https://wpt.fyi/results/css/css-counter-styles/georgian/css3-counter-styles-011.html "css/css-counter-styles/georgian/css3-counter-styles-011.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/georgian/css3-counter-styles-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/georgian/css3-counter-styles-011.html)
 - [css3-counter-styles-012.html](https://wpt.fyi/results/css/css-counter-styles/georgian/css3-counter-styles-012.html "css/css-counter-styles/georgian/css3-counter-styles-012.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/georgian/css3-counter-styles-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/georgian/css3-counter-styles-012.html)
 - [css3-counter-styles-014.html](https://wpt.fyi/results/css/css-counter-styles/georgian/css3-counter-styles-014.html "css/css-counter-styles/georgian/css3-counter-styles-014.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/georgian/css3-counter-styles-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/georgian/css3-counter-styles-014.html)

[gujarati]
: Gujarati numbering (e.g., ૧, ૨, ૩, \..., ૯૮, ૯૯, ૧૦૦).
 Tests
 - [css3-counter-styles-122.html](https://wpt.fyi/results/css/css-counter-styles/gujarati/css3-counter-styles-122.html "css/css-counter-styles/gujarati/css3-counter-styles-122.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/gujarati/css3-counter-styles-122.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/gujarati/css3-counter-styles-122.html)
 - [css3-counter-styles-123.html](https://wpt.fyi/results/css/css-counter-styles/gujarati/css3-counter-styles-123.html "css/css-counter-styles/gujarati/css3-counter-styles-123.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/gujarati/css3-counter-styles-123.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/gujarati/css3-counter-styles-123.html)
 - [css3-counter-styles-124.html](https://wpt.fyi/results/css/css-counter-styles/gujarati/css3-counter-styles-124.html "css/css-counter-styles/gujarati/css3-counter-styles-124.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/gujarati/css3-counter-styles-124.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/gujarati/css3-counter-styles-124.html)

[gurmukhi]
: Gurmukhi numbering (e.g., ੧, ੨, ੩, \..., ੯੮, ੯੯, ੧੦੦).
 Tests
 - [css3-counter-styles-125.html](https://wpt.fyi/results/css/css-counter-styles/gurmukhi/css3-counter-styles-125.html "css/css-counter-styles/gurmukhi/css3-counter-styles-125.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/gurmukhi/css3-counter-styles-125.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/gurmukhi/css3-counter-styles-125.html)
 - [css3-counter-styles-126.html](https://wpt.fyi/results/css/css-counter-styles/gurmukhi/css3-counter-styles-126.html "css/css-counter-styles/gurmukhi/css3-counter-styles-126.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/gurmukhi/css3-counter-styles-126.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/gurmukhi/css3-counter-styles-126.html)
 - [css3-counter-styles-127.html](https://wpt.fyi/results/css/css-counter-styles/gurmukhi/css3-counter-styles-127.html "css/css-counter-styles/gurmukhi/css3-counter-styles-127.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/gurmukhi/css3-counter-styles-127.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/gurmukhi/css3-counter-styles-127.html)

[hebrew]
: Traditional Hebrew numbering (e.g., א‎, ב‎, ג‎, \..., צח‎, צט‎, ק‎).
 Tests
 - [counter-hebrew-nested.html](https://wpt.fyi/results/css/css-counter-styles/hebrew/counter-hebrew-nested.html "css/css-counter-styles/hebrew/counter-hebrew-nested.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/hebrew/counter-hebrew-nested.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/hebrew/counter-hebrew-nested.html)
 - [css3-counter-styles-015.html](https://wpt.fyi/results/css/css-counter-styles/hebrew/css3-counter-styles-015.html "css/css-counter-styles/hebrew/css3-counter-styles-015.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/hebrew/css3-counter-styles-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/hebrew/css3-counter-styles-015.html)
 - [css3-counter-styles-016.html](https://wpt.fyi/results/css/css-counter-styles/hebrew/css3-counter-styles-016.html "css/css-counter-styles/hebrew/css3-counter-styles-016.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/hebrew/css3-counter-styles-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/hebrew/css3-counter-styles-016.html)
 - [css3-counter-styles-016a.html](https://wpt.fyi/results/css/css-counter-styles/hebrew/css3-counter-styles-016a.html "css/css-counter-styles/hebrew/css3-counter-styles-016a.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/hebrew/css3-counter-styles-016a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/hebrew/css3-counter-styles-016a.html)
 - [css3-counter-styles-017.html](https://wpt.fyi/results/css/css-counter-styles/hebrew/css3-counter-styles-017.html "css/css-counter-styles/hebrew/css3-counter-styles-017.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/hebrew/css3-counter-styles-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/hebrew/css3-counter-styles-017.html)

[kannada]
: Kannada numbering (e.g., ೧, ೨, ೩, \..., ೯೮, ೯೯, ೧೦೦).
 Tests
 - [css3-counter-styles-128.html](https://wpt.fyi/results/css/css-counter-styles/kannada/css3-counter-styles-128.html "css/css-counter-styles/kannada/css3-counter-styles-128.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/kannada/css3-counter-styles-128.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/kannada/css3-counter-styles-128.html)
 - [css3-counter-styles-129.html](https://wpt.fyi/results/css/css-counter-styles/kannada/css3-counter-styles-129.html "css/css-counter-styles/kannada/css3-counter-styles-129.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/kannada/css3-counter-styles-129.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/kannada/css3-counter-styles-129.html)
 - [css3-counter-styles-130.html](https://wpt.fyi/results/css/css-counter-styles/kannada/css3-counter-styles-130.html "css/css-counter-styles/kannada/css3-counter-styles-130.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/kannada/css3-counter-styles-130.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/kannada/css3-counter-styles-130.html)

[lao]
: Laotian numbering (e.g., ໑, ໒, ໓, \..., ໙໘, ໙໙, ໑໐໐).
 Tests
 - [css3-counter-styles-131.html](https://wpt.fyi/results/css/css-counter-styles/lao/css3-counter-styles-131.html "css/css-counter-styles/lao/css3-counter-styles-131.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/lao/css3-counter-styles-131.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/lao/css3-counter-styles-131.html)
 - [css3-counter-styles-132.html](https://wpt.fyi/results/css/css-counter-styles/lao/css3-counter-styles-132.html "css/css-counter-styles/lao/css3-counter-styles-132.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/lao/css3-counter-styles-132.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/lao/css3-counter-styles-132.html)
 - [css3-counter-styles-133.html](https://wpt.fyi/results/css/css-counter-styles/lao/css3-counter-styles-133.html "css/css-counter-styles/lao/css3-counter-styles-133.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/lao/css3-counter-styles-133.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/lao/css3-counter-styles-133.html)

[malayalam]
: Malayalam numbering (e.g., ൧, ൨, ൩, \..., ൯൮, ൯൯, ൧൦൦).
 Tests
 - [css3-counter-styles-134.html](https://wpt.fyi/results/css/css-counter-styles/malayalam/css3-counter-styles-134.html "css/css-counter-styles/malayalam/css3-counter-styles-134.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/malayalam/css3-counter-styles-134.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/malayalam/css3-counter-styles-134.html)
 - [css3-counter-styles-135.html](https://wpt.fyi/results/css/css-counter-styles/malayalam/css3-counter-styles-135.html "css/css-counter-styles/malayalam/css3-counter-styles-135.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/malayalam/css3-counter-styles-135.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/malayalam/css3-counter-styles-135.html)
 - [css3-counter-styles-136.html](https://wpt.fyi/results/css/css-counter-styles/malayalam/css3-counter-styles-136.html "css/css-counter-styles/malayalam/css3-counter-styles-136.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/malayalam/css3-counter-styles-136.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/malayalam/css3-counter-styles-136.html)

[mongolian]
: Mongolian numbering (e.g., ᠑, ᠒, ᠓, \..., ᠙᠘, ᠙᠙, ᠑᠐᠐).
 Tests
 - [css3-counter-styles-137.html](https://wpt.fyi/results/css/css-counter-styles/mongolian/css3-counter-styles-137.html "css/css-counter-styles/mongolian/css3-counter-styles-137.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/mongolian/css3-counter-styles-137.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/mongolian/css3-counter-styles-137.html)
 - [css3-counter-styles-138.html](https://wpt.fyi/results/css/css-counter-styles/mongolian/css3-counter-styles-138.html "css/css-counter-styles/mongolian/css3-counter-styles-138.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/mongolian/css3-counter-styles-138.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/mongolian/css3-counter-styles-138.html)
 - [css3-counter-styles-139.html](https://wpt.fyi/results/css/css-counter-styles/mongolian/css3-counter-styles-139.html "css/css-counter-styles/mongolian/css3-counter-styles-139.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/mongolian/css3-counter-styles-139.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/mongolian/css3-counter-styles-139.html)

[myanmar]
: Myanmar (Burmese) numbering (e.g., ၁, ၂, ၃, \..., ၉၈, ၉၉, ၁၀၀).
 Tests
 - [css3-counter-styles-140.html](https://wpt.fyi/results/css/css-counter-styles/myanmar/css3-counter-styles-140.html "css/css-counter-styles/myanmar/css3-counter-styles-140.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/myanmar/css3-counter-styles-140.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/myanmar/css3-counter-styles-140.html)
 - [css3-counter-styles-141.html](https://wpt.fyi/results/css/css-counter-styles/myanmar/css3-counter-styles-141.html "css/css-counter-styles/myanmar/css3-counter-styles-141.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/myanmar/css3-counter-styles-141.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/myanmar/css3-counter-styles-141.html)
 - [css3-counter-styles-142.html](https://wpt.fyi/results/css/css-counter-styles/myanmar/css3-counter-styles-142.html "css/css-counter-styles/myanmar/css3-counter-styles-142.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/myanmar/css3-counter-styles-142.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/myanmar/css3-counter-styles-142.html)

[oriya]
: Oriya (Odia) numbering (e.g., ୧, ୨, ୩, \..., ୯୮, ୯୯, ୧୦୦).
 Tests
 - [css3-counter-styles-143.html](https://wpt.fyi/results/css/css-counter-styles/oriya/css3-counter-styles-143.html "css/css-counter-styles/oriya/css3-counter-styles-143.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/oriya/css3-counter-styles-143.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/oriya/css3-counter-styles-143.html)
 - [css3-counter-styles-144.html](https://wpt.fyi/results/css/css-counter-styles/oriya/css3-counter-styles-144.html "css/css-counter-styles/oriya/css3-counter-styles-144.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/oriya/css3-counter-styles-144.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/oriya/css3-counter-styles-144.html)
 - [css3-counter-styles-145.html](https://wpt.fyi/results/css/css-counter-styles/oriya/css3-counter-styles-145.html "css/css-counter-styles/oriya/css3-counter-styles-145.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/oriya/css3-counter-styles-145.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/oriya/css3-counter-styles-145.html)

[persian]
: Persian numbering (e.g., ۱, ۲, ۳, ۴, \..., ۹۸, ۹۹, ۱۰۰).
 Tests
 - [css3-counter-styles-104.html](https://wpt.fyi/results/css/css-counter-styles/persian/css3-counter-styles-104.html "css/css-counter-styles/persian/css3-counter-styles-104.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/persian/css3-counter-styles-104.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/persian/css3-counter-styles-104.html)
 - [css3-counter-styles-105.html](https://wpt.fyi/results/css/css-counter-styles/persian/css3-counter-styles-105.html "css/css-counter-styles/persian/css3-counter-styles-105.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/persian/css3-counter-styles-105.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/persian/css3-counter-styles-105.html)
 - [css3-counter-styles-106.html](https://wpt.fyi/results/css/css-counter-styles/persian/css3-counter-styles-106.html "css/css-counter-styles/persian/css3-counter-styles-106.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/persian/css3-counter-styles-106.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/persian/css3-counter-styles-106.html)

[lower-roman]
: Lowercase ASCII Roman numerals (e.g., i, ii, iii, \..., xcviii,
 xcix, c).
 Tests
 - [css3-counter-styles-019.html](https://wpt.fyi/results/css/css-counter-styles/lower-roman/css3-counter-styles-019.html "css/css-counter-styles/lower-roman/css3-counter-styles-019.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/lower-roman/css3-counter-styles-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/lower-roman/css3-counter-styles-019.html)
 - [css3-counter-styles-020.html](https://wpt.fyi/results/css/css-counter-styles/lower-roman/css3-counter-styles-020.html "css/css-counter-styles/lower-roman/css3-counter-styles-020.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/lower-roman/css3-counter-styles-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/lower-roman/css3-counter-styles-020.html)
 - [css3-counter-styles-020a.html](https://wpt.fyi/results/css/css-counter-styles/lower-roman/css3-counter-styles-020a.html "css/css-counter-styles/lower-roman/css3-counter-styles-020a.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/lower-roman/css3-counter-styles-020a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/lower-roman/css3-counter-styles-020a.html)
 - [css3-counter-styles-020b.html](https://wpt.fyi/results/css/css-counter-styles/lower-roman/css3-counter-styles-020b.html "css/css-counter-styles/lower-roman/css3-counter-styles-020b.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/lower-roman/css3-counter-styles-020b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/lower-roman/css3-counter-styles-020b.html)
 - [css3-counter-styles-021.html](https://wpt.fyi/results/css/css-counter-styles/lower-roman/css3-counter-styles-021.html "css/css-counter-styles/lower-roman/css3-counter-styles-021.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/lower-roman/css3-counter-styles-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/lower-roman/css3-counter-styles-021.html)
 - [css3-counter-styles-022.html](https://wpt.fyi/results/css/css-counter-styles/lower-roman/css3-counter-styles-022.html "css/css-counter-styles/lower-roman/css3-counter-styles-022.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/lower-roman/css3-counter-styles-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/lower-roman/css3-counter-styles-022.html)

[upper-roman]
: Uppercase ASCII Roman numerals (e.g., I, II, III, \..., XCVIII,
 XCIX, C).
 Tests
 - [css3-counter-styles-023.html](https://wpt.fyi/results/css/css-counter-styles/upper-roman/css3-counter-styles-023.html "css/css-counter-styles/upper-roman/css3-counter-styles-023.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/upper-roman/css3-counter-styles-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/upper-roman/css3-counter-styles-023.html)
 - [css3-counter-styles-024.html](https://wpt.fyi/results/css/css-counter-styles/upper-roman/css3-counter-styles-024.html "css/css-counter-styles/upper-roman/css3-counter-styles-024.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/upper-roman/css3-counter-styles-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/upper-roman/css3-counter-styles-024.html)
 - [css3-counter-styles-024a.html](https://wpt.fyi/results/css/css-counter-styles/upper-roman/css3-counter-styles-024a.html "css/css-counter-styles/upper-roman/css3-counter-styles-024a.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/upper-roman/css3-counter-styles-024a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/upper-roman/css3-counter-styles-024a.html)
 - [css3-counter-styles-025.html](https://wpt.fyi/results/css/css-counter-styles/upper-roman/css3-counter-styles-025.html "css/css-counter-styles/upper-roman/css3-counter-styles-025.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/upper-roman/css3-counter-styles-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/upper-roman/css3-counter-styles-025.html)
 - [css3-counter-styles-026.html](https://wpt.fyi/results/css/css-counter-styles/upper-roman/css3-counter-styles-026.html "css/css-counter-styles/upper-roman/css3-counter-styles-026.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/upper-roman/css3-counter-styles-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/upper-roman/css3-counter-styles-026.html)

[tamil]
: Tamil numbering (e.g., ௧, ௨, ௩, \..., ௯௮, ௯௯, ௧௦௦).
 Tests
 - [css3-counter-styles-146.html](https://wpt.fyi/results/css/css-counter-styles/tamil/css3-counter-styles-146.html "css/css-counter-styles/tamil/css3-counter-styles-146.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/tamil/css3-counter-styles-146.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/tamil/css3-counter-styles-146.html)
 - [css3-counter-styles-147.html](https://wpt.fyi/results/css/css-counter-styles/tamil/css3-counter-styles-147.html "css/css-counter-styles/tamil/css3-counter-styles-147.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/tamil/css3-counter-styles-147.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/tamil/css3-counter-styles-147.html)
 - [css3-counter-styles-148.html](https://wpt.fyi/results/css/css-counter-styles/tamil/css3-counter-styles-148.html "css/css-counter-styles/tamil/css3-counter-styles-148.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/tamil/css3-counter-styles-148.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/tamil/css3-counter-styles-148.html)

[telugu]
: Telugu numbering (e.g., ౧, ౨, ౩, \..., ౯౮, ౯౯, ౧౦౦).
 Tests
 - [css3-counter-styles-149.html](https://wpt.fyi/results/css/css-counter-styles/telugu/css3-counter-styles-149.html "css/css-counter-styles/telugu/css3-counter-styles-149.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/telugu/css3-counter-styles-149.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/telugu/css3-counter-styles-149.html)
 - [css3-counter-styles-150.html](https://wpt.fyi/results/css/css-counter-styles/telugu/css3-counter-styles-150.html "css/css-counter-styles/telugu/css3-counter-styles-150.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/telugu/css3-counter-styles-150.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/telugu/css3-counter-styles-150.html)
 - [css3-counter-styles-151.html](https://wpt.fyi/results/css/css-counter-styles/telugu/css3-counter-styles-151.html "css/css-counter-styles/telugu/css3-counter-styles-151.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/telugu/css3-counter-styles-151.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/telugu/css3-counter-styles-151.html)

[thai]
: Thai (Siamese) numbering (e.g., ๑, ๒, ๓, \..., ๙๘, ๙๙, ๑๐๐).
 Tests
 - [css3-counter-styles-152.html](https://wpt.fyi/results/css/css-counter-styles/thai/css3-counter-styles-152.html "css/css-counter-styles/thai/css3-counter-styles-152.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/thai/css3-counter-styles-152.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/thai/css3-counter-styles-152.html)
 - [css3-counter-styles-153.html](https://wpt.fyi/results/css/css-counter-styles/thai/css3-counter-styles-153.html "css/css-counter-styles/thai/css3-counter-styles-153.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/thai/css3-counter-styles-153.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/thai/css3-counter-styles-153.html)
 - [css3-counter-styles-154.html](https://wpt.fyi/results/css/css-counter-styles/thai/css3-counter-styles-154.html "css/css-counter-styles/thai/css3-counter-styles-154.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/thai/css3-counter-styles-154.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/thai/css3-counter-styles-154.html)

[tibetan]
: Tibetan numbering (e.g., ༡, ༢, ༣, \..., ༩༨, ༩༩, ༡༠༠).
 Tests
 - [css3-counter-styles-155.html](https://wpt.fyi/results/css/css-counter-styles/tibetan/css3-counter-styles-155.html "css/css-counter-styles/tibetan/css3-counter-styles-155.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/tibetan/css3-counter-styles-155.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/tibetan/css3-counter-styles-155.html)
 - [css3-counter-styles-156.html](https://wpt.fyi/results/css/css-counter-styles/tibetan/css3-counter-styles-156.html "css/css-counter-styles/tibetan/css3-counter-styles-156.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/tibetan/css3-counter-styles-156.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/tibetan/css3-counter-styles-156.html)
 - [css3-counter-styles-157.html](https://wpt.fyi/results/css/css-counter-styles/tibetan/css3-counter-styles-157.html "css/css-counter-styles/tibetan/css3-counter-styles-157.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/tibetan/css3-counter-styles-157.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/tibetan/css3-counter-styles-157.html)

The following stylesheet fragment provides the normative definition of
these predefined counter styles:

``` stylesheet

 @counter-style decimal {
 system: numeric;
 symbols: '0' '1' '2' '3' '4' '5' '6' '7' '8' '9';
 }

 @counter-style decimal-leading-zero {
 system: extends decimal;
 pad: 2 '0';
 }

 @counter-style arabic-indic {
 system: numeric;
 symbols: "\660" "\661" "\662" "\663" "\664" "\665" "\666" "\667" "\668" "\669";
 /* ٠ ١ ٢ ٣ ٤ ٥ ٦ ٧ ٨ ٩ */
 }

 @counter-style armenian {
 system: additive;
 range: 1 9999;
 additive-symbols: 9000 \554, 8000 \553, 7000 \552, 6000 \551, 5000 \550, 4000 \54F, 3000 \54E, 2000 \54D, 1000 \54C, 900 \54B, 800 \54A, 700 \549, 600 \548, 500 \547, 400 \546, 300 \545, 200 \544, 100 \543, 90 \542, 80 \541, 70 \540, 60 \53F, 50 \53E, 40 \53D, 30 \53C, 20 \53B, 10 \53A, 9 \539, 8 \538, 7 \537, 6 \536, 5 \535, 4 \534, 3 \533, 2 \532, 1 \531;
 /* 9000 Ք, 8000 Փ, 7000 Ւ, 6000 Ց, 5000 Ր, 4000 Տ, 3000 Վ, 2000 Ս, 1000 Ռ, 900 Ջ, 800 Պ, 700 Չ, 600 Ո, 500 Շ, 400 Ն, 300 Յ, 200 Մ, 100 Ճ, 90 Ղ, 80 Ձ, 70 Հ, 60 Կ, 50 Ծ, 40 Խ, 30 Լ, 20 Ի, 10 Ժ, 9 Թ, 8 Ը, 7 Է, 6 Զ, 5 Ե, 4 Դ, 3 Գ, 2 Բ, 1 Ա */
 }

 @counter-style upper-armenian {
 system: extends armenian;
 }

 @counter-style lower-armenian {
 system: additive;
 range: 1 9999;
 additive-symbols: 9000 "\584", 8000 "\583", 7000 "\582", 6000 "\581", 5000 "\580", 4000 "\57F", 3000 "\57E", 2000 "\57D", 1000 "\57C", 900 "\57B", 800 "\57A", 700 "\579", 600 "\578", 500 "\577", 400 "\576", 300 "\575", 200 "\574", 100 "\573", 90 "\572", 80 "\571", 70 "\570", 60 "\56F", 50 "\56E", 40 "\56D", 30 "\56C", 20 "\56B", 10 "\56A", 9 "\569", 8 "\568", 7 "\567", 6 "\566", 5 "\565", 4 "\564", 3 "\563", 2 "\562", 1 "\561";
 /* 9000 ք, 8000 փ, 7000 ւ, 6000 ց, 5000 ր, 4000 տ, 3000 վ, 2000 ս, 1000 ռ, 900 ջ, 800 պ, 700 չ, 600 ո, 500 շ, 400 ն, 300 յ, 200 մ, 100 ճ, 90 ղ, 80 ձ, 70 հ, 60 կ, 50 ծ, 40 խ, 30 լ, 20 ի, 10 ժ, 9 թ, 8 ը, 7 է, 6 զ, 5 ե, 4 դ, 3 գ, 2 բ, 1 ա */
 }

 @counter-style bengali {
 system: numeric;
 symbols: "\9E6" "\9E7" "\9E8" "\9E9" "\9EA" "\9EB" "\9EC" "\9ED" "\9EE" "\9EF";
 /* ০ ১ ২ ৩ ৪ ৫ ৬ ৭ ৮ ৯ */
 }

 @counter-style cambodian {
 system: numeric;
 symbols: "\17E0" "\17E1" "\17E2" "\17E3" "\17E4" "\17E5" "\17E6" "\17E7" "\17E8" "\17E9";
 /* ០ ១ ២ ៣ ៤ ៥ ៦ ៧ ៨ ៩ */
 }

 @counter-style khmer {
 system: extends cambodian;
 }

 @counter-style cjk-decimal {
 system: numeric;
 range: 0 infinite;
 symbols: \3007 \4E00 \4E8C \4E09 \56DB \4E94 \516D \4E03 \516B \4E5D;
 /* 〇 一 二 三 四 五 六 七 八 九 */
 suffix: "\3001";
 /* "、" */
 }

 @counter-style devanagari {
 system: numeric;
 symbols: "\966" "\967" "\968" "\969" "\96A" "\96B" "\96C" "\96D" "\96E" "\96F";
 /* ० १ २ ३ ४ ५ ६ ७ ८ ९ */
 }

 @counter-style georgian {
 system: additive;
 range: 1 19999;
 additive-symbols: 10000 \10F5, 9000 \10F0, 8000 \10EF, 7000 \10F4, 6000 \10EE, 5000 \10ED, 4000 \10EC, 3000 \10EB, 2000 \10EA, 1000 \10E9, 900 \10E8, 800 \10E7, 700 \10E6, 600 \10E5, 500 \10E4, 400 \10F3, 300 \10E2, 200 \10E1, 100 \10E0, 90 \10DF, 80 \10DE, 70 \10DD, 60 \10F2, 50 \10DC, 40 \10DB, 30 \10DA, 20 \10D9, 10 \10D8, 9 \10D7, 8 \10F1, 7 \10D6, 6 \10D5, 5 \10D4, 4 \10D3, 3 \10D2, 2 \10D1, 1 \10D0;
 /* 10000 ჵ, 9000 ჰ, 8000 ჯ, 7000 ჴ, 6000 ხ, 5000 ჭ, 4000 წ, 3000 ძ, 2000 ც, 1000 ჩ, 900 შ, 800 ყ, 700 ღ, 600 ქ, 500 ფ, 400 ჳ, 300 ტ, 200 ს, 100 რ, 90 ჟ, 80 პ, 70 ო, 60 ჲ, 50 ნ, 40 მ, 30 ლ, 20 კ, 10 ი, 9 თ, 8 ჱ, 7 ზ, 6 ვ, 5 ე, 4 დ, 3 გ, 2 ბ, 1 ა */
 }

 @counter-style gujarati {
 system: numeric;
 symbols: "\AE6" "\AE7" "\AE8" "\AE9" "\AEA" "\AEB" "\AEC" "\AED" "\AEE" "\AEF";
 /* ૦ ૧ ૨ ૩ ૪ ૫ ૬ ૭ ૮ ૯ */
 }

 @counter-style gurmukhi {
 system: numeric;
 symbols: "\A66" "\A67" "\A68" "\A69" "\A6A" "\A6B" "\A6C" "\A6D" "\A6E" "\A6F";
 /* ੦ ੧ ੨ ੩ ੪ ੫ ੬ ੭ ੮ ੯ */
 }

 @counter-style hebrew {
 system: additive;
 range: 1 10999;
 additive-symbols: 10000 \5D9\5F3, 9000 \5D8\5F3, 8000 \5D7\5F3, 7000 \5D6\5F3, 6000 \5D5\5F3, 5000 \5D4\5F3, 4000 \5D3\5F3, 3000 \5D2\5F3, 2000 \5D1\5F3, 1000 \5D0\5F3, 400 \5EA, 300 \5E9, 200 \5E8, 100 \5E7, 90 \5E6, 80 \5E4, 70 \5E2, 60 \5E1, 50 \5E0, 40 \5DE, 30 \5DC, 20 \5DB, 19 \5D9\5D8, 18 \5D9\5D7, 17 \5D9\5D6, 16 \5D8\5D6, 15 \5D8\5D5, 10 \5D9, 9 \5D8, 8 \5D7, 7 \5D6, 6 \5D5, 5 \5D4, 4 \5D3, 3 \5D2, 2 \5D1, 1 \5D0;
 /* 10000 י׳, 9000 ט׳, 8000 ח׳, 7000 ז׳, 6000 ו׳, 5000 ה׳, 4000 ד׳, 3000 ג׳, 2000 ב׳, 1000 א׳, 400 ת, 300 ש, 200 ר, 100 ק, 90 צ, 80 פ, 70 ע, 60 ס, 50 נ, 40 מ, 30 ל, 20 כ, 19 יט, 18 יח, 17 יז, 16 טז, 15 טו, 10 י, 9 ט, 8 ח, 7 ז, 6 ו, 5 ה, 4 ד, 3 ג, 2 ב, 1 א */
 /* This system manually specifies the values for 19-15 to force the correct display of 15 and 16, which are commonly rewritten to avoid a close resemblance to the Tetragrammaton. */
 /* Implementations MAY choose to implement this manually to a higher range; see note below. */
 }

 @counter-style kannada {
 system: numeric;
 symbols: "\CE6" "\CE7" "\CE8" "\CE9" "\CEA" "\CEB" "\CEC" "\CED" "\CEE" "\CEF";
 /* ೦ ೧ ೨ ೩ ೪ ೫ ೬ ೭ ೮ ೯ */
 }

 @counter-style lao {
 system: numeric;
 symbols: "\ED0" "\ED1" "\ED2" "\ED3" "\ED4" "\ED5" "\ED6" "\ED7" "\ED8" "\ED9";
 /* ໐ ໑ ໒ ໓ ໔ ໕ ໖ ໗ ໘ ໙ */
 }

 @counter-style malayalam {
 system: numeric;
 symbols: "\D66" "\D67" "\D68" "\D69" "\D6A" "\D6B" "\D6C" "\D6D" "\D6E" "\D6F";
 /* ൦ ൧ ൨ ൩ ൪ ൫ ൬ ൭ ൮ ൯ */
 }

 @counter-style mongolian {
 system: numeric;
 symbols: "\1810" "\1811" "\1812" "\1813" "\1814" "\1815" "\1816" "\1817" "\1818" "\1819";
 /* ᠐ ᠑ ᠒ ᠓ ᠔ ᠕ ᠖ ᠗ ᠘ ᠙ */
 }

 @counter-style myanmar {
 system: numeric;
 symbols: "\1040" "\1041" "\1042" "\1043" "\1044" "\1045" "\1046" "\1047" "\1048" "\1049";
 /* ၀ ၁ ၂ ၃ ၄ ၅ ၆ ၇ ၈ ၉ */
 }

 @counter-style oriya {
 system: numeric;
 symbols: "\B66" "\B67" "\B68" "\B69" "\B6A" "\B6B" "\B6C" "\B6D" "\B6E" "\B6F";
 /* ୦ ୧ ୨ ୩ ୪ ୫ ୬ ୭ ୮ ୯ */
 }

 @counter-style persian {
 system: numeric;
 symbols: "\6F0" "\6F1" "\6F2" "\6F3" "\6F4" "\6F5" "\6F6" "\6F7" "\6F8" "\6F9";
 /* ۰ ۱ ۲ ۳ ۴ ۵ ۶ ۷ ۸ ۹ */
 }

 @counter-style lower-roman {
 system: additive;
 range: 1 3999;
 additive-symbols: 1000 m, 900 cm, 500 d, 400 cd, 100 c, 90 xc, 50 l, 40 xl, 10 x, 9 ix, 5 v, 4 iv, 1 i;
 }

 @counter-style upper-roman {
 system: additive;
 range: 1 3999;
 additive-symbols: 1000 M, 900 CM, 500 D, 400 CD, 100 C, 90 XC, 50 L, 40 XL, 10 X, 9 IX, 5 V, 4 IV, 1 I;
 }

 @counter-style tamil {
 system: numeric;
 symbols: "\BE6" "\BE7" "\BE8" "\BE9" "\BEA" "\BEB" "\BEC" "\BED" "\BEE" "\BEF";
 /* ௦ ௧ ௨ ௩ ௪ ௫ ௬ ௭ ௮ ௯ */
 }

 @counter-style telugu {
 system: numeric;
 symbols: "\C66" "\C67" "\C68" "\C69" "\C6A" "\C6B" "\C6C" "\C6D" "\C6E" "\C6F";
 /* ౦ ౧ ౨ ౩ ౪ ౫ ౬ ౭ ౮ ౯ */
 }

 @counter-style thai {
 system: numeric;
 symbols: "\E50" "\E51" "\E52" "\E53" "\E54" "\E55" "\E56" "\E57" "\E58" "\E59";
 /* ๐ ๑ ๒ ๓ ๔ ๕ ๖ ๗ ๘ ๙ */
 }

 @counter-style tibetan {
 system: numeric;
 symbols: "\F20" "\F21" "\F22" "\F23" "\F24" "\F25" "\F26" "\F27" "\F28" "\F29";
 /* ༠ ༡ ༢ ༣ ༤ ༥ ༦ ༧ ༨ ༩ */
 }

```

Implementations must implement [hebrew](#hebrew) at least to the range specified in the
[\@counter-style](#at-ruledef-counter-style) rule above, but may implement it to a higher
range. If they do so, the corresponding
[range](#descdef-counter-style-range) descriptor must reflect the implemented
range.

### 6.2. Alphabetic: [lower-alpha, [lower-latin](#lower-latin), [upper-alpha](#upper-alpha), [upper-latin](#upper-latin), [lower-greek](#lower-greek), [hiragana](#hiragana), [hiragana-iroha](#hiragana-iroha), [katakana](#katakana), [katakana-iroha](#katakana-iroha)]
[lower-alpha]\
[lower-latin]
: Lowercase ASCII letters (e.g., a, b, c, \..., z, aa, ab).

[upper-alpha]\
[upper-latin]
: Uppercase ASCII letters (e.g., A, B, C, \..., Z, AA, AB).

[lower-greek]
: Lowercase classical Greek (e.g., α, β, γ, \..., ω, αα, αβ).
 Tests
 - [css3-counter-styles-027.html](https://wpt.fyi/results/css/css-counter-styles/lower-greek/css3-counter-styles-027.html "css/css-counter-styles/lower-greek/css3-counter-styles-027.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/lower-greek/css3-counter-styles-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/lower-greek/css3-counter-styles-027.html)
 - [css3-counter-styles-028.html](https://wpt.fyi/results/css/css-counter-styles/lower-greek/css3-counter-styles-028.html "css/css-counter-styles/lower-greek/css3-counter-styles-028.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/lower-greek/css3-counter-styles-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/lower-greek/css3-counter-styles-028.html)
 - [css3-counter-styles-029.html](https://wpt.fyi/results/css/css-counter-styles/lower-greek/css3-counter-styles-029.html "css/css-counter-styles/lower-greek/css3-counter-styles-029.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/lower-greek/css3-counter-styles-029.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/lower-greek/css3-counter-styles-029.html)

[hiragana]
: Dictionary-order hiragana lettering (e.g., あ, い, う, \..., ん,
 ああ, あい).
 Tests
 - [css3-counter-styles-030.html](https://wpt.fyi/results/css/css-counter-styles/hiragana/css3-counter-styles-030.html "css/css-counter-styles/hiragana/css3-counter-styles-030.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/hiragana/css3-counter-styles-030.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/hiragana/css3-counter-styles-030.html)
 - [css3-counter-styles-031.html](https://wpt.fyi/results/css/css-counter-styles/hiragana/css3-counter-styles-031.html "css/css-counter-styles/hiragana/css3-counter-styles-031.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/hiragana/css3-counter-styles-031.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/hiragana/css3-counter-styles-031.html)
 - [css3-counter-styles-032.html](https://wpt.fyi/results/css/css-counter-styles/hiragana/css3-counter-styles-032.html "css/css-counter-styles/hiragana/css3-counter-styles-032.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/hiragana/css3-counter-styles-032.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/hiragana/css3-counter-styles-032.html)

[hiragana-iroha]
: Iroha-order hiragana lettering (e.g., い, ろ, は, \..., す, いい,
 いろ).
 Tests
 - [css3-counter-styles-033.html](https://wpt.fyi/results/css/css-counter-styles/hiragana-iroha/css3-counter-styles-033.html "css/css-counter-styles/hiragana-iroha/css3-counter-styles-033.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/hiragana-iroha/css3-counter-styles-033.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/hiragana-iroha/css3-counter-styles-033.html)
 - [css3-counter-styles-034.html](https://wpt.fyi/results/css/css-counter-styles/hiragana-iroha/css3-counter-styles-034.html "css/css-counter-styles/hiragana-iroha/css3-counter-styles-034.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/hiragana-iroha/css3-counter-styles-034.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/hiragana-iroha/css3-counter-styles-034.html)
 - [css3-counter-styles-035.html](https://wpt.fyi/results/css/css-counter-styles/hiragana-iroha/css3-counter-styles-035.html "css/css-counter-styles/hiragana-iroha/css3-counter-styles-035.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/hiragana-iroha/css3-counter-styles-035.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/hiragana-iroha/css3-counter-styles-035.html)

[katakana]
: Dictionary-order katakana lettering (e.g., ア, イ, ウ, \..., ン,
 アア, アイ).
 Tests
 - [css3-counter-styles-036.html](https://wpt.fyi/results/css/css-counter-styles/katakana/css3-counter-styles-036.html "css/css-counter-styles/katakana/css3-counter-styles-036.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/katakana/css3-counter-styles-036.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/katakana/css3-counter-styles-036.html)
 - [css3-counter-styles-037.html](https://wpt.fyi/results/css/css-counter-styles/katakana/css3-counter-styles-037.html "css/css-counter-styles/katakana/css3-counter-styles-037.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/katakana/css3-counter-styles-037.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/katakana/css3-counter-styles-037.html)
 - [css3-counter-styles-038.html](https://wpt.fyi/results/css/css-counter-styles/katakana/css3-counter-styles-038.html "css/css-counter-styles/katakana/css3-counter-styles-038.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/katakana/css3-counter-styles-038.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/katakana/css3-counter-styles-038.html)

[katakana-iroha]
: Iroha-order katakana lettering (e.g., イ, ロ, ハ, \..., ス, イイ,
 イロ)
 Tests
 - [css3-counter-styles-039.html](https://wpt.fyi/results/css/css-counter-styles/katakana-iroha/css3-counter-styles-039.html "css/css-counter-styles/katakana-iroha/css3-counter-styles-039.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/katakana-iroha/css3-counter-styles-039.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/katakana-iroha/css3-counter-styles-039.html)
 - [css3-counter-styles-040.html](https://wpt.fyi/results/css/css-counter-styles/katakana-iroha/css3-counter-styles-040.html "css/css-counter-styles/katakana-iroha/css3-counter-styles-040.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/katakana-iroha/css3-counter-styles-040.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/katakana-iroha/css3-counter-styles-040.html)
 - [css3-counter-styles-041.html](https://wpt.fyi/results/css/css-counter-styles/katakana-iroha/css3-counter-styles-041.html "css/css-counter-styles/katakana-iroha/css3-counter-styles-041.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/katakana-iroha/css3-counter-styles-041.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/katakana-iroha/css3-counter-styles-041.html)

The following stylesheet fragment provides the normative definition of
these predefined counter styles:

``` stylesheet

 @counter-style lower-alpha {
 system: alphabetic;
 symbols: a b c d e f g h i j k l m n o p q r s t u v w x y z;
 }

 @counter-style lower-latin {
 system: extends lower-alpha;
 }

 @counter-style upper-alpha {
 system: alphabetic;
 symbols: A B C D E F G H I J K L M N O P Q R S T U V W X Y Z;
 }

 @counter-style upper-latin {
 system: extends upper-alpha;
 }

 @counter-style lower-greek {
 system: alphabetic;
 symbols: "\3B1" "\3B2" "\3B3" "\3B4" "\3B5" "\3B6" "\3B7" "\3B8" "\3B9" "\3BA" "\3BB" "\3BC" "\3BD" "\3BE" "\3BF" "\3C0" "\3C1" "\3C3" "\3C4" "\3C5" "\3C6" "\3C7" "\3C8" "\3C9";
 /* α β γ δ ε ζ η θ ι κ λ μ ν ξ ο π ρ σ τ υ φ χ ψ ω */
 }

 @counter-style hiragana {
 system: alphabetic;
 symbols: "\3042" "\3044" "\3046" "\3048" "\304A" "\304B" "\304D" "\304F" "\3051" "\3053" "\3055" "\3057" "\3059" "\305B" "\305D" "\305F" "\3061" "\3064" "\3066" "\3068" "\306A" "\306B" "\306C" "\306D" "\306E" "\306F" "\3072" "\3075" "\3078" "\307B" "\307E" "\307F" "\3080" "\3081" "\3082" "\3084" "\3086" "\3088" "\3089" "\308A" "\308B" "\308C" "\308D" "\308F" "\3090" "\3091" "\3092" "\3093";
 /* あ い う え お か き く け こ さ し す せ そ た ち つ て と な に ぬ ね の は ひ ふ へ ほ ま み む め も や ゆ よ ら り る れ ろ わ ゐ ゑ を ん */
 suffix: "、";
 }

 @counter-style hiragana-iroha {
 system: alphabetic;
 symbols: "\3044" "\308D" "\306F" "\306B" "\307B" "\3078" "\3068" "\3061" "\308A" "\306C" "\308B" "\3092" "\308F" "\304B" "\3088" "\305F" "\308C" "\305D" "\3064" "\306D" "\306A" "\3089" "\3080" "\3046" "\3090" "\306E" "\304A" "\304F" "\3084" "\307E" "\3051" "\3075" "\3053" "\3048" "\3066" "\3042" "\3055" "\304D" "\3086" "\3081" "\307F" "\3057" "\3091" "\3072" "\3082" "\305B" "\3059";
 /* い ろ は に ほ へ と ち り ぬ る を わ か よ た れ そ つ ね な ら む う ゐ の お く や ま け ふ こ え て あ さ き ゆ め み し ゑ ひ も せ す */
 suffix: "、";
 }

 @counter-style katakana {
 system: alphabetic;
 symbols: "\30A2" "\30A4" "\30A6" "\30A8" "\30AA" "\30AB" "\30AD" "\30AF" "\30B1" "\30B3" "\30B5" "\30B7" "\30B9" "\30BB" "\30BD" "\30BF" "\30C1" "\30C4" "\30C6" "\30C8" "\30CA" "\30CB" "\30CC" "\30CD" "\30CE" "\30CF" "\30D2" "\30D5" "\30D8" "\30DB" "\30DE" "\30DF" "\30E0" "\30E1" "\30E2" "\30E4" "\30E6" "\30E8" "\30E9" "\30EA" "\30EB" "\30EC" "\30ED" "\30EF" "\30F0" "\30F1" "\30F2" "\30F3";
 /* ア イ ウ エ オ カ キ ク ケ コ サ シ ス セ ソ タ チ ツ テ ト ナ ニ ヌ ネ ノ ハ ヒ フ ヘ ホ マ ミ ム メ モ ヤ ユ ヨ ラ リ ル レ ロ ワ ヰ ヱ ヲ ン */
 suffix: "、";
 }

 @counter-style katakana-iroha {
 system: alphabetic;
 symbols: "\30A4" "\30ED" "\30CF" "\30CB" "\30DB" "\30D8" "\30C8" "\30C1" "\30EA" "\30CC" "\30EB" "\30F2" "\30EF" "\30AB" "\30E8" "\30BF" "\30EC" "\30BD" "\30C4" "\30CD" "\30CA" "\30E9" "\30E0" "\30A6" "\30F0" "\30CE" "\30AA" "\30AF" "\30E4" "\30DE" "\30B1" "\30D5" "\30B3" "\30A8" "\30C6" "\30A2" "\30B5" "\30AD" "\30E6" "\30E1" "\30DF" "\30B7" "\30F1" "\30D2" "\30E2" "\30BB" "\30B9";
 /* イ ロ ハ ニ ホ ヘ ト チ リ ヌ ル ヲ ワ カ ヨ タ レ ソ ツ ネ ナ ラ ム ウ ヰ ノ オ ク ヤ マ ケ フ コ エ テ ア サ キ ユ メ ミ シ ヱ ヒ モ セ ス */
 suffix: "、";
 }

```

### 6.3. Symbolic: [disc, [circle](#circle), [square](#square), [disclosure-open](#disclosure-open), [disclosure-closed](#disclosure-closed)]
The [predefined symbolic counter
styles] each
represent a single symbol, and are defined as follows:

[disc]
: A filled circle, similar to • U+2022 BULLET.

[circle]
: A hollow circle, similar to ◦ U+25E6 WHITE BULLET.

[square]
: A filled square, similar to ▪ U+25AA BLACK SMALL SQUARE.

[disclosure-open]\
[disclosure-closed]
: Symbols appropriate for indicating an open or closed disclosure
 widget, such as the HTML
 [`details`](https://html.spec.whatwg.org/multipage/interactive-elements.html#the-details-element) element.
 Tests
 - [disclosure-styles.html](https://wpt.fyi/results/css/css-counter-styles/counter-style-at-rule/disclosure-styles.html "css/css-counter-styles/counter-style-at-rule/disclosure-styles.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/counter-style-at-rule/disclosure-styles.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/counter-style-at-rule/disclosure-styles.html)

They can be referred to syntactically using the
[\<symbolic-glyph\>](#typedef-symbolic-glyph) production:

``` prod
<symbolic-glyph> = disc | circle | square | disclosure-open | disclosure-closed
```

The following stylesheet fragment provides the normative definition of
these predefined counter styles:

``` stylesheet
@counter-style disc {
 system: cyclic;
 symbols: \2022;
 /* • */
 suffix: " ";
}

@counter-style circle {
 system: cyclic;
 symbols: \25E6;
 /* ◦ */
 suffix: " ";
}

@counter-style square {
 system: cyclic;
 symbols: \25AA;
 /* ▪ */
 suffix: " ";
}

@counter-style disclosure-open {
 system: cyclic;
 suffix: " ";
 /* for symbols, see normative text below */
}

@counter-style disclosure-closed {
 system: cyclic;
 suffix: " ";
 /* for symbols, see normative text below */
}
```

For the [disclosure-open](#disclosure-open) and
[disclosure-closed](#disclosure-closed) counter styles, the marker must be an image or
character suitable for indicating the open and closed states of a
disclosure widget, such as HTML's
[`details`](https://html.spec.whatwg.org/multipage/interactive-elements.html#the-details-element) element. If the image is directional, it must
respond to the [writing
mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) of the element, similar to the [bidi-sensitive
images](https://drafts.csswg.org/css4-images/#bidi-images) feature of
the Images 4 module. For example, in a [horizontal writing
mode](https://drafts.csswg.org/css-writing-modes-4/#horizontal-writing-mode) the [disclosure-closed] style might use the characters U+25B8 BLACK RIGHT-POINTING SMALL
TRIANGLE (▸) for
[ltr](https://drafts.csswg.org/css-writing-modes-4/#valdef-direction-ltr) elements and U+25C2 BLACK LEFT-POINTING SMALL
TRIANGLE (◂) for
[rtl](https://drafts.csswg.org/css-writing-modes-4/#valdef-direction-rtl) elements, while the
[disclosure-open] style might use the
character U+25BE BLACK DOWN-POINTING SMALL TRIANGLE (▾).

A UA may render the
[\<symbolic-glyph\>](#typedef-symbolic-glyph) styles using a UA-generated image or
a UA-chosen font instead of rendering the specified character in the
element's own font. It must look similar to the character, and must be
sized to attractively fill a 1em by 1em square. A UA that does so may
also fall back to its string definition when rendering these values in a
[\<counter\>](https://drafts.csswg.org/css-lists-3/#typedef-counter) value.

### 6.4. Fixed: [cjk-earthly-branch, [cjk-heavenly-stem](#valdef-counter-style-name-cjk-heavenly-stem)]
[cjk-earthly-branch]
: Han \"Earthly Branch\" ordinals (e.g., 子, 丑, 寅, \..., 亥).
 Tests
 - [css3-counter-styles-201.html](https://wpt.fyi/results/css/css-counter-styles/cjk-earthly-branch/css3-counter-styles-201.html "css/css-counter-styles/cjk-earthly-branch/css3-counter-styles-201.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cjk-earthly-branch/css3-counter-styles-201.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cjk-earthly-branch/css3-counter-styles-201.html)
 - [css3-counter-styles-202.html](https://wpt.fyi/results/css/css-counter-styles/cjk-earthly-branch/css3-counter-styles-202.html "css/css-counter-styles/cjk-earthly-branch/css3-counter-styles-202.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cjk-earthly-branch/css3-counter-styles-202.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cjk-earthly-branch/css3-counter-styles-202.html)
 - [css3-counter-styles-203.html](https://wpt.fyi/results/css/css-counter-styles/cjk-earthly-branch/css3-counter-styles-203.html "css/css-counter-styles/cjk-earthly-branch/css3-counter-styles-203.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cjk-earthly-branch/css3-counter-styles-203.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cjk-earthly-branch/css3-counter-styles-203.html)

[cjk-heavenly-stem]
: Han \"Heavenly Stem\" ordinals (e.g., 甲, 乙, 丙, \..., 癸)
 Tests
 - [css3-counter-styles-204.html](https://wpt.fyi/results/css/css-counter-styles/cjk-heavenly-stem/css3-counter-styles-204.html "css/css-counter-styles/cjk-heavenly-stem/css3-counter-styles-204.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cjk-heavenly-stem/css3-counter-styles-204.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cjk-heavenly-stem/css3-counter-styles-204.html)
 - [css3-counter-styles-205.html](https://wpt.fyi/results/css/css-counter-styles/cjk-heavenly-stem/css3-counter-styles-205.html "css/css-counter-styles/cjk-heavenly-stem/css3-counter-styles-205.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cjk-heavenly-stem/css3-counter-styles-205.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cjk-heavenly-stem/css3-counter-styles-205.html)
 - [css3-counter-styles-206.html](https://wpt.fyi/results/css/css-counter-styles/cjk-heavenly-stem/css3-counter-styles-206.html "css/css-counter-styles/cjk-heavenly-stem/css3-counter-styles-206.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cjk-heavenly-stem/css3-counter-styles-206.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cjk-heavenly-stem/css3-counter-styles-206.html)

The following stylesheet fragment provides the normative definition of
these predefined counter styles:

``` stylesheet

 @counter-style cjk-earthly-branch {
 system: fixed;
 symbols: "\5B50" "\4E11" "\5BC5" "\536F" "\8FB0" "\5DF3" "\5348" "\672A" "\7533" "\9149" "\620C" "\4EA5";
 /* 子 丑 寅 卯 辰 巳 午 未 申 酉 戌 亥 */
 suffix: "、";
 fallback: cjk-decimal;
 }

 @counter-style cjk-heavenly-stem {
 system: fixed;
 symbols: "\7532" "\4E59" "\4E19" "\4E01" "\620A" "\5DF1" "\5E9A" "\8F9B" "\58EC" "\7678";
 /* 甲 乙 丙 丁 戊 己 庚 辛 壬 癸 */
 suffix: "、";
 fallback: cjk-decimal;
 }

```

## 7. Complex Predefined Counter Styles

While authors may define their own counter styles using the
[\@counter-style](#at-ruledef-counter-style) rule or rely on the set of predefined counter
styles, a few counter styles are described by rules that are too complex
to be captured by the predefined algorithms. These counter styles are
described in this section.

Some of the counter styles specified in this section have custom
algorithms for generating counter values, but are otherwise identical to
a counter style defined via the
[\@counter-style](#at-ruledef-counter-style) rule. For example, an author can reference one
of these styles in an
[extends](#valdef-counter-style-system-extends) system, reusing the algorithm but swapping out
some of the other descriptors.

All of the counter styles defined in this section have a [spoken
form](#descdef-counter-style-speak-as) of
[numbers](#valdef-counter-style-speak-as-numbers), and [use a negative
sign](#use-a-negative-sign).

### 7.1. Longhand East Asian Counter Styles

Chinese, Japanese, and Korean have counter styles which have a
"longhand" nature, similar to "thirteen thousand one hundred and
twenty-three" in English. Each has both formal and informal variants.
The formal styles are typically used in financial and legal documents,
as their characters are more difficult to alter into each other.

The following table shows examples of
these styles, particularly some ways in which they differ.

Counter Style

0

1

2

3

10

11

99

100

101

6001

[japanese-informal](#japanese-informal)

〇

一

二

三

十

十一

九十九

百

百一

六千一

[japanese-formal](#japanese-formal)

零

壱

弐

参

壱拾

壱拾壱

九拾九

壱百

壱百壱

六阡壱

[korean-hangul-formal](#korean-hangul-formal)

영

일

이

삼

일십

일십일

구십구

일백

일백일

육천일

[korean-hanja-informal](#korean-hanja-informal)

零

一

二

三

十

十一

九十九

百

百一

六千一

[korean-hanja-formal](#korean-hanja-formal)

零

壹

貳

參

壹拾

壹拾壹

九拾九

壹百

壹百壹

六仟壹

[simp-chinese-informal](#simp-chinese-informal)

零

一

二

三

十

十一

九十九

一百

一百零一

六千零一

[simp-chinese-formal](#simp-chinese-formal)

零

壹

贰

叁

壹拾

壹拾壹

玖拾玖

壹佰

壹佰零壹

陆仟零壹

[trad-chinese-informal](#trad-chinese-informal)

零

一

二

三

十

十一

九十九

一百

一百零一

六千零一

[trad-chinese-formal](#trad-chinese-formal)

零

壹

貳

參

壹拾

壹拾壹

玖拾玖

壹佰

壹佰零壹

陸仟零壹

Because opinions differ on how best to represent numbers 10,000 or
greater using the longhand CJK styles, the implementation details are
split into two sections. The Korean and Japanese variants of these
counter styles can, if limited to the range of -9999 to 9999, be
expressed as
[\@counter-style](#at-ruledef-counter-style) rules. The Chinese variants use a [specialized
algorithm](#limited-chinese), regardless of range. The required
implementation is described in [§ 7.1.1 Limited-range Implementation
(required)](#limited-range-required), which defines the styles over
these limited ranges, and the optional implementation is described in
[§ 7.1.2 Extended Implementation (optional)](#extended-range-optional),
which defines them over a larger range using custom algorithms. Outside
the implementation-supported range, the fallback is
[cjk-decimal](#cjk-decimal).

#### 7.1.1. Limited-range Implementation (required)

##### 7.1.1.1. Japanese: [japanese-informal and [japanese-formal](#japanese-formal)]
[japanese-informal]
: Informal Japanese Kanji numbering (e.g., 千百十一)
 Tests
 - [counter-japanese-informal-extended.html](https://wpt.fyi/results/css/css-counter-styles/japanese-informal/counter-japanese-informal-extended.html "css/css-counter-styles/japanese-informal/counter-japanese-informal-extended.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/japanese-informal/counter-japanese-informal-extended.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/japanese-informal/counter-japanese-informal-extended.html)
 - [counter-japanese-informal.html](https://wpt.fyi/results/css/css-counter-styles/japanese-informal/counter-japanese-informal.html "css/css-counter-styles/japanese-informal/counter-japanese-informal.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/japanese-informal/counter-japanese-informal.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/japanese-informal/counter-japanese-informal.html)
 - [css3-counter-styles-042.html](https://wpt.fyi/results/css/css-counter-styles/japanese-informal/css3-counter-styles-042.html "css/css-counter-styles/japanese-informal/css3-counter-styles-042.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/japanese-informal/css3-counter-styles-042.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/japanese-informal/css3-counter-styles-042.html)
 - [css3-counter-styles-043.html](https://wpt.fyi/results/css/css-counter-styles/japanese-informal/css3-counter-styles-043.html "css/css-counter-styles/japanese-informal/css3-counter-styles-043.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/japanese-informal/css3-counter-styles-043.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/japanese-informal/css3-counter-styles-043.html)
 - [css3-counter-styles-044.html](https://wpt.fyi/results/css/css-counter-styles/japanese-informal/css3-counter-styles-044.html "css/css-counter-styles/japanese-informal/css3-counter-styles-044.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/japanese-informal/css3-counter-styles-044.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/japanese-informal/css3-counter-styles-044.html)
 - [css3-counter-styles-045.html](https://wpt.fyi/results/css/css-counter-styles/japanese-informal/css3-counter-styles-045.html "css/css-counter-styles/japanese-informal/css3-counter-styles-045.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/japanese-informal/css3-counter-styles-045.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/japanese-informal/css3-counter-styles-045.html)
 - [css3-counter-styles-046.html](https://wpt.fyi/results/css/css-counter-styles/japanese-informal/css3-counter-styles-046.html "css/css-counter-styles/japanese-informal/css3-counter-styles-046.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/japanese-informal/css3-counter-styles-046.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/japanese-informal/css3-counter-styles-046.html)

[japanese-formal]
: Formal Japanese Kanji numbering (e.g. 壱阡壱百壱拾壱)
 Tests
 - [counter-japanese-formal-extended.html](https://wpt.fyi/results/css/css-counter-styles/japanese-formal/counter-japanese-formal-extended.html "css/css-counter-styles/japanese-formal/counter-japanese-formal-extended.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/japanese-formal/counter-japanese-formal-extended.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/japanese-formal/counter-japanese-formal-extended.html)
 - [counter-japanese-formal.html](https://wpt.fyi/results/css/css-counter-styles/japanese-formal/counter-japanese-formal.html "css/css-counter-styles/japanese-formal/counter-japanese-formal.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/japanese-formal/counter-japanese-formal.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/japanese-formal/counter-japanese-formal.html)
 - [css3-counter-styles-047.html](https://wpt.fyi/results/css/css-counter-styles/japanese-formal/css3-counter-styles-047.html "css/css-counter-styles/japanese-formal/css3-counter-styles-047.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/japanese-formal/css3-counter-styles-047.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/japanese-formal/css3-counter-styles-047.html)
 - [css3-counter-styles-048.html](https://wpt.fyi/results/css/css-counter-styles/japanese-formal/css3-counter-styles-048.html "css/css-counter-styles/japanese-formal/css3-counter-styles-048.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/japanese-formal/css3-counter-styles-048.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/japanese-formal/css3-counter-styles-048.html)
 - [css3-counter-styles-049.html](https://wpt.fyi/results/css/css-counter-styles/japanese-formal/css3-counter-styles-049.html "css/css-counter-styles/japanese-formal/css3-counter-styles-049.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/japanese-formal/css3-counter-styles-049.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/japanese-formal/css3-counter-styles-049.html)
 - [css3-counter-styles-050.html](https://wpt.fyi/results/css/css-counter-styles/japanese-formal/css3-counter-styles-050.html "css/css-counter-styles/japanese-formal/css3-counter-styles-050.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/japanese-formal/css3-counter-styles-050.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/japanese-formal/css3-counter-styles-050.html)
 - [css3-counter-styles-051.html](https://wpt.fyi/results/css/css-counter-styles/japanese-formal/css3-counter-styles-051.html "css/css-counter-styles/japanese-formal/css3-counter-styles-051.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/japanese-formal/css3-counter-styles-051.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/japanese-formal/css3-counter-styles-051.html)

``` stylesheet
@counter-style japanese-informal {
 system: additive;
 range: -9999 9999;
 additive-symbols: 9000 \4E5D\5343, 8000 \516B\5343, 7000 \4E03\5343, 6000 \516D\5343, 5000 \4E94\5343, 4000 \56DB\5343, 3000 \4E09\5343, 2000 \4E8C\5343, 1000 \5343, 900 \4E5D\767E, 800 \516B\767E, 700 \4E03\767E, 600 \516D\767E, 500 \4E94\767E, 400 \56DB\767E, 300 \4E09\767E, 200 \4E8C\767E, 100 \767E, 90 \4E5D\5341, 80 \516B\5341, 70 \4E03\5341, 60 \516D\5341, 50 \4E94\5341, 40 \56DB\5341, 30 \4E09\5341, 20 \4E8C\5341, 10 \5341, 9 \4E5D, 8 \516B, 7 \4E03, 6 \516D, 5 \4E94, 4 \56DB, 3 \4E09, 2 \4E8C, 1 \4E00, 0 \3007;
 /* 9000 九千, 8000 八千, 7000 七千, 6000 六千, 5000 五千, 4000 四千, 3000 三千, 2000 二千, 1000 千, 900 九百, 800 八百, 700 七百, 600 六百, 500 五百, 400 四百, 300 三百, 200 二百, 100 百, 90 九十, 80 八十, 70 七十, 60 六十, 50 五十, 40 四十, 30 三十, 20 二十, 10 十, 9 九, 8 八, 7 七, 6 六, 5 五, 4 四, 3 三, 2 二, 1 一, 0 〇 */
 suffix: '\3001';
 /* 、 */
 negative: "\30DE\30A4\30CA\30B9";
 /* マイナス */
 fallback: cjk-decimal;
}

@counter-style japanese-formal {
 system: additive;
 range: -9999 9999;
 additive-symbols: 9000 \4E5D\9621, 8000 \516B\9621, 7000 \4E03\9621, 6000 \516D\9621, 5000 \4F0D\9621, 4000 \56DB\9621, 3000 \53C2\9621, 2000 \5F10\9621, 1000 \58F1\9621, 900 \4E5D\767E, 800 \516B\767E, 700 \4E03\767E, 600 \516D\767E, 500 \4F0D\767E, 400 \56DB\767E, 300 \53C2\767E, 200 \5F10\767E, 100 \58F1\767E, 90 \4E5D\62FE, 80 \516B\62FE, 70 \4E03\62FE, 60 \516D\62FE, 50 \4F0D\62FE, 40 \56DB\62FE, 30 \53C2\62FE, 20 \5F10\62FE, 10 \58F1\62FE, 9 \4E5D, 8 \516B, 7 \4E03, 6 \516D, 5 \4F0D, 4 \56DB, 3 \53C2, 2 \5F10, 1 \58F1, 0 \96F6;
 /* 9000 九阡, 8000 八阡, 7000 七阡, 6000 六阡, 5000 伍阡, 4000 四阡, 3000 参阡, 2000 弐阡, 1000 壱阡, 900 九百, 800 八百, 700 七百, 600 六百, 500 伍百, 400 四百, 300 参百, 200 弐百, 100 壱百, 90 九拾, 80 八拾, 70 七拾, 60 六拾, 50 伍拾, 40 四拾, 30 参拾, 20 弐拾, 10 壱拾, 9 九, 8 八, 7 七, 6 六, 5 伍, 4 四, 3 参, 2 弐, 1 壱, 0 零 */
 suffix: '\3001';
 /* 、 */
 negative: "\30DE\30A4\30CA\30B9";
 /* マイナス */
 fallback: cjk-decimal;
}
```

##### 7.1.1.2. Korean: [korean-hangul-formal, [korean-hanja-informal](#korean-hanja-informal), and [korean-hanja-formal](#korean-hanja-formal)]
[korean-hangul-formal]
: Korean Hangul numbering (e.g., 일천일백일십일)
 Tests
 - [counter-korean-hangul-formal-extended.html](https://wpt.fyi/results/css/css-counter-styles/korean-hangul-formal/counter-korean-hangul-formal-extended.html "css/css-counter-styles/korean-hangul-formal/counter-korean-hangul-formal-extended.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/korean-hangul-formal/counter-korean-hangul-formal-extended.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/korean-hangul-formal/counter-korean-hangul-formal-extended.html)
 - [counter-korean-hangul-formal.html](https://wpt.fyi/results/css/css-counter-styles/korean-hangul-formal/counter-korean-hangul-formal.html "css/css-counter-styles/korean-hangul-formal/counter-korean-hangul-formal.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/korean-hangul-formal/counter-korean-hangul-formal.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/korean-hangul-formal/counter-korean-hangul-formal.html)
 - [css3-counter-styles-052.html](https://wpt.fyi/results/css/css-counter-styles/korean-hangul-formal/css3-counter-styles-052.html "css/css-counter-styles/korean-hangul-formal/css3-counter-styles-052.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/korean-hangul-formal/css3-counter-styles-052.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/korean-hangul-formal/css3-counter-styles-052.html)
 - [css3-counter-styles-053.html](https://wpt.fyi/results/css/css-counter-styles/korean-hangul-formal/css3-counter-styles-053.html "css/css-counter-styles/korean-hangul-formal/css3-counter-styles-053.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/korean-hangul-formal/css3-counter-styles-053.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/korean-hangul-formal/css3-counter-styles-053.html)
 - [css3-counter-styles-054.html](https://wpt.fyi/results/css/css-counter-styles/korean-hangul-formal/css3-counter-styles-054.html "css/css-counter-styles/korean-hangul-formal/css3-counter-styles-054.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/korean-hangul-formal/css3-counter-styles-054.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/korean-hangul-formal/css3-counter-styles-054.html)
 - [css3-counter-styles-055.html](https://wpt.fyi/results/css/css-counter-styles/korean-hangul-formal/css3-counter-styles-055.html "css/css-counter-styles/korean-hangul-formal/css3-counter-styles-055.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/korean-hangul-formal/css3-counter-styles-055.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/korean-hangul-formal/css3-counter-styles-055.html)
 - [css3-counter-styles-056.html](https://wpt.fyi/results/css/css-counter-styles/korean-hangul-formal/css3-counter-styles-056.html "css/css-counter-styles/korean-hangul-formal/css3-counter-styles-056.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/korean-hangul-formal/css3-counter-styles-056.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/korean-hangul-formal/css3-counter-styles-056.html)

[korean-hanja-informal]
: Informal Korean Hanja numbering (e.g., 千百十一)
 Tests
 - [counter-korean-hanja-informal-extended.html](https://wpt.fyi/results/css/css-counter-styles/korean-hanja-informal/counter-korean-hanja-informal-extended.html "css/css-counter-styles/korean-hanja-informal/counter-korean-hanja-informal-extended.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/korean-hanja-informal/counter-korean-hanja-informal-extended.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/korean-hanja-informal/counter-korean-hanja-informal-extended.html)
 - [counter-korean-hanja-informal.html](https://wpt.fyi/results/css/css-counter-styles/korean-hanja-informal/counter-korean-hanja-informal.html "css/css-counter-styles/korean-hanja-informal/counter-korean-hanja-informal.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/korean-hanja-informal/counter-korean-hanja-informal.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/korean-hanja-informal/counter-korean-hanja-informal.html)
 - [css3-counter-styles-057.html](https://wpt.fyi/results/css/css-counter-styles/korean-hanja-informal/css3-counter-styles-057.html "css/css-counter-styles/korean-hanja-informal/css3-counter-styles-057.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/korean-hanja-informal/css3-counter-styles-057.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/korean-hanja-informal/css3-counter-styles-057.html)
 - [css3-counter-styles-058.html](https://wpt.fyi/results/css/css-counter-styles/korean-hanja-informal/css3-counter-styles-058.html "css/css-counter-styles/korean-hanja-informal/css3-counter-styles-058.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/korean-hanja-informal/css3-counter-styles-058.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/korean-hanja-informal/css3-counter-styles-058.html)
 - [css3-counter-styles-059.html](https://wpt.fyi/results/css/css-counter-styles/korean-hanja-informal/css3-counter-styles-059.html "css/css-counter-styles/korean-hanja-informal/css3-counter-styles-059.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/korean-hanja-informal/css3-counter-styles-059.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/korean-hanja-informal/css3-counter-styles-059.html)
 - [css3-counter-styles-060.html](https://wpt.fyi/results/css/css-counter-styles/korean-hanja-informal/css3-counter-styles-060.html "css/css-counter-styles/korean-hanja-informal/css3-counter-styles-060.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/korean-hanja-informal/css3-counter-styles-060.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/korean-hanja-informal/css3-counter-styles-060.html)
 - [css3-counter-styles-061.html](https://wpt.fyi/results/css/css-counter-styles/korean-hanja-informal/css3-counter-styles-061.html "css/css-counter-styles/korean-hanja-informal/css3-counter-styles-061.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/korean-hanja-informal/css3-counter-styles-061.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/korean-hanja-informal/css3-counter-styles-061.html)

[korean-hanja-formal]
: Formal Korean Han (Hanja) numbering (e.g., 壹仟壹百壹拾壹)
 Tests
 - [counter-korean-hanja-formal-extended.html](https://wpt.fyi/results/css/css-counter-styles/korean-hanja-formal/counter-korean-hanja-formal-extended.html "css/css-counter-styles/korean-hanja-formal/counter-korean-hanja-formal-extended.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/korean-hanja-formal/counter-korean-hanja-formal-extended.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/korean-hanja-formal/counter-korean-hanja-formal-extended.html)
 - [counter-korean-hanja-formal.html](https://wpt.fyi/results/css/css-counter-styles/korean-hanja-formal/counter-korean-hanja-formal.html "css/css-counter-styles/korean-hanja-formal/counter-korean-hanja-formal.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/korean-hanja-formal/counter-korean-hanja-formal.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/korean-hanja-formal/counter-korean-hanja-formal.html)
 - [css3-counter-styles-062.html](https://wpt.fyi/results/css/css-counter-styles/korean-hanja-formal/css3-counter-styles-062.html "css/css-counter-styles/korean-hanja-formal/css3-counter-styles-062.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/korean-hanja-formal/css3-counter-styles-062.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/korean-hanja-formal/css3-counter-styles-062.html)
 - [css3-counter-styles-063.html](https://wpt.fyi/results/css/css-counter-styles/korean-hanja-formal/css3-counter-styles-063.html "css/css-counter-styles/korean-hanja-formal/css3-counter-styles-063.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/korean-hanja-formal/css3-counter-styles-063.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/korean-hanja-formal/css3-counter-styles-063.html)
 - [css3-counter-styles-064.html](https://wpt.fyi/results/css/css-counter-styles/korean-hanja-formal/css3-counter-styles-064.html "css/css-counter-styles/korean-hanja-formal/css3-counter-styles-064.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/korean-hanja-formal/css3-counter-styles-064.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/korean-hanja-formal/css3-counter-styles-064.html)
 - [css3-counter-styles-065.html](https://wpt.fyi/results/css/css-counter-styles/korean-hanja-formal/css3-counter-styles-065.html "css/css-counter-styles/korean-hanja-formal/css3-counter-styles-065.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/korean-hanja-formal/css3-counter-styles-065.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/korean-hanja-formal/css3-counter-styles-065.html)
 - [css3-counter-styles-066.html](https://wpt.fyi/results/css/css-counter-styles/korean-hanja-formal/css3-counter-styles-066.html "css/css-counter-styles/korean-hanja-formal/css3-counter-styles-066.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/korean-hanja-formal/css3-counter-styles-066.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/korean-hanja-formal/css3-counter-styles-066.html)

``` stylesheet
@counter-style korean-hangul-formal {
 system: additive;
 range: -9999 9999;
 additive-symbols: 9000 \AD6C\CC9C, 8000 \D314\CC9C, 7000 \CE60\CC9C, 6000 \C721\CC9C, 5000 \C624\CC9C, 4000 \C0AC\CC9C, 3000 \C0BC\CC9C, 2000 \C774\CC9C, 1000 \C77C\CC9C, 900 \AD6C\BC31, 800 \D314\BC31, 700 \CE60\BC31, 600 \C721\BC31, 500 \C624\BC31, 400 \C0AC\BC31, 300 \C0BC\BC31, 200 \C774\BC31, 100 \C77C\BC31, 90 \AD6C\C2ED, 80 \D314\C2ED, 70 \CE60\C2ED, 60 \C721\C2ED, 50 \C624\C2ED, 40 \C0AC\C2ED, 30 \C0BC\C2ED, 20 \C774\C2ED, 10 \C77C\C2ED, 9 \AD6C, 8 \D314, 7 \CE60, 6 \C721, 5 \C624, 4 \C0AC, 3 \C0BC, 2 \C774, 1 \C77C, 0 \C601;
 /* 9000 구천, 8000 팔천, 7000 칠천, 6000 육천, 5000 오천, 4000 사천, 3000 삼천, 2000 이천, 1000 일천, 900 구백, 800 팔백, 700 칠백, 600 육백, 500 오백, 400 사백, 300 삼백, 200 이백, 100 일백, 90 구십, 80 팔십, 70 칠십, 60 육십, 50 오십, 40 사십, 30 삼십, 20 이십, 10 일십, 9 구, 8 팔, 7 칠, 6 육, 5 오, 4 사, 3 삼, 2 이, 1 일, 0 영 */
 suffix: ', ';
 negative: "\B9C8\C774\B108\C2A4 ";
 /* 마이너스 (followed by a space) */
 fallback: cjk-decimal;
}

@counter-style korean-hanja-informal {
 system: additive;
 range: -9999 9999;
 additive-symbols: 9000 \4E5D\5343, 8000 \516B\5343, 7000 \4E03\5343, 6000 \516D\5343, 5000 \4E94\5343, 4000 \56DB\5343, 3000 \4E09\5343, 2000 \4E8C\5343, 1000 \5343, 900 \4E5D\767E, 800 \516B\767E, 700 \4E03\767E, 600 \516D\767E, 500 \4E94\767E, 400 \56DB\767E, 300 \4E09\767E, 200 \4E8C\767E, 100 \767E, 90 \4E5D\5341, 80 \516B\5341, 70 \4E03\5341, 60 \516D\5341, 50 \4E94\5341, 40 \56DB\5341, 30 \4E09\5341, 20 \4E8C\5341, 10 \5341, 9 \4E5D, 8 \516B, 7 \4E03, 6 \516D, 5 \4E94, 4 \56DB, 3 \4E09, 2 \4E8C, 1 \4E00, 0 \96F6;
 /* 9000 九千, 8000 八千, 7000 七千, 6000 六千, 5000 五千, 4000 四千, 3000 三千, 2000 二千, 1000 千, 900 九百, 800 八百, 700 七百, 600 六百, 500 五百, 400 四百, 300 三百, 200 二百, 100 百, 90 九十, 80 八十, 70 七十, 60 六十, 50 五十, 40 四十, 30 三十, 20 二十, 10 十, 9 九, 8 八, 7 七, 6 六, 5 五, 4 四, 3 三, 2 二, 1 一, 0 零 */
 suffix: ', ';
 negative: "\B9C8\C774\B108\C2A4 ";
 /* 마이너스 (followed by a space) */
 fallback: cjk-decimal;
}

@counter-style korean-hanja-formal {
 system: additive;
 range: -9999 9999;
 additive-symbols: 9000 \4E5D\4EDF, 8000 \516B\4EDF, 7000 \4E03\4EDF, 6000 \516D\4EDF, 5000 \4E94\4EDF, 4000 \56DB\4EDF, 3000 \53C3\4EDF, 2000 \8CB3\4EDF, 1000 \58F9\4EDF, 900 \4E5D\767E, 800 \516B\767E, 700 \4E03\767E, 600 \516D\767E, 500 \4E94\767E, 400 \56DB\767E, 300 \53C3\767E, 200 \8CB3\767E, 100 \58F9\767E, 90 \4E5D\62FE, 80 \516B\62FE, 70 \4E03\62FE, 60 \516D\62FE, 50 \4E94\62FE, 40 \56DB\62FE, 30 \53C3\62FE, 20 \8CB3\62FE, 10 \58F9\62FE, 9 \4E5D, 8 \516B, 7 \4E03, 6 \516D, 5 \4E94, 4 \56DB, 3 \53C3, 2 \8CB3, 1 \58F9, 0 \96F6;
 /* 9000 九仟, 8000 八仟, 7000 七仟, 6000 六仟, 5000 五仟, 4000 四仟, 3000 參仟, 2000 貳仟, 1000 壹仟, 900 九百, 800 八百, 700 七百, 600 六百, 500 五百, 400 四百, 300 參百, 200 貳百, 100 壹百, 90 九拾, 80 八拾, 70 七拾, 60 六拾, 50 五拾, 40 四拾, 30 參拾, 20 貳拾, 10 壹拾, 9 九, 8 八, 7 七, 6 六, 5 五, 4 四, 3 參, 2 貳, 1 壹, 0 零 */
 suffix: ', ';
 negative: "\B9C8\C774\B108\C2A4 ";
 /* 마이너스 (followed by a space) */
 fallback: cjk-decimal;
}
```

##### 7.1.1.3. Chinese: [simp-chinese-informal, [simp-chinese-formal](#simp-chinese-formal), [trad-chinese-informal](#trad-chinese-informal), and [trad-chinese-formal](#trad-chinese-formal)]
[simp-chinese-informal]
: Simplified Chinese informal numbering (e.g., 一千一百一十一)
 Tests
 - [counter-simp-chinese-informal.html](https://wpt.fyi/results/css/css-counter-styles/simp-chinese-informal/counter-simp-chinese-informal.html "css/css-counter-styles/simp-chinese-informal/counter-simp-chinese-informal.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/simp-chinese-informal/counter-simp-chinese-informal.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/simp-chinese-informal/counter-simp-chinese-informal.html)
 - [css3-counter-styles-071.html](https://wpt.fyi/results/css/css-counter-styles/simp-chinese-informal/css3-counter-styles-071.html "css/css-counter-styles/simp-chinese-informal/css3-counter-styles-071.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/simp-chinese-informal/css3-counter-styles-071.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/simp-chinese-informal/css3-counter-styles-071.html)
 - [css3-counter-styles-072.html](https://wpt.fyi/results/css/css-counter-styles/simp-chinese-informal/css3-counter-styles-072.html "css/css-counter-styles/simp-chinese-informal/css3-counter-styles-072.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/simp-chinese-informal/css3-counter-styles-072.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/simp-chinese-informal/css3-counter-styles-072.html)
 - [css3-counter-styles-073.html](https://wpt.fyi/results/css/css-counter-styles/simp-chinese-informal/css3-counter-styles-073.html "css/css-counter-styles/simp-chinese-informal/css3-counter-styles-073.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/simp-chinese-informal/css3-counter-styles-073.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/simp-chinese-informal/css3-counter-styles-073.html)
 - [css3-counter-styles-074.html](https://wpt.fyi/results/css/css-counter-styles/simp-chinese-informal/css3-counter-styles-074.html "css/css-counter-styles/simp-chinese-informal/css3-counter-styles-074.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/simp-chinese-informal/css3-counter-styles-074.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/simp-chinese-informal/css3-counter-styles-074.html)
 - [css3-counter-styles-075.html](https://wpt.fyi/results/css/css-counter-styles/simp-chinese-informal/css3-counter-styles-075.html "css/css-counter-styles/simp-chinese-informal/css3-counter-styles-075.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/simp-chinese-informal/css3-counter-styles-075.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/simp-chinese-informal/css3-counter-styles-075.html)

[simp-chinese-formal]
: Simplified Chinese formal numbering (e.g. 壹仟壹佰壹拾壹)
 Tests
 - [counter-simp-chinese-formal.html](https://wpt.fyi/results/css/css-counter-styles/simp-chinese-formal/counter-simp-chinese-formal.html "css/css-counter-styles/simp-chinese-formal/counter-simp-chinese-formal.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/simp-chinese-formal/counter-simp-chinese-formal.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/simp-chinese-formal/counter-simp-chinese-formal.html)
 - [css3-counter-styles-076.html](https://wpt.fyi/results/css/css-counter-styles/simp-chinese-formal/css3-counter-styles-076.html "css/css-counter-styles/simp-chinese-formal/css3-counter-styles-076.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/simp-chinese-formal/css3-counter-styles-076.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/simp-chinese-formal/css3-counter-styles-076.html)
 - [css3-counter-styles-077.html](https://wpt.fyi/results/css/css-counter-styles/simp-chinese-formal/css3-counter-styles-077.html "css/css-counter-styles/simp-chinese-formal/css3-counter-styles-077.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/simp-chinese-formal/css3-counter-styles-077.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/simp-chinese-formal/css3-counter-styles-077.html)
 - [css3-counter-styles-078.html](https://wpt.fyi/results/css/css-counter-styles/simp-chinese-formal/css3-counter-styles-078.html "css/css-counter-styles/simp-chinese-formal/css3-counter-styles-078.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/simp-chinese-formal/css3-counter-styles-078.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/simp-chinese-formal/css3-counter-styles-078.html)
 - [css3-counter-styles-079.html](https://wpt.fyi/results/css/css-counter-styles/simp-chinese-formal/css3-counter-styles-079.html "css/css-counter-styles/simp-chinese-formal/css3-counter-styles-079.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/simp-chinese-formal/css3-counter-styles-079.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/simp-chinese-formal/css3-counter-styles-079.html)
 - [css3-counter-styles-080.html](https://wpt.fyi/results/css/css-counter-styles/simp-chinese-formal/css3-counter-styles-080.html "css/css-counter-styles/simp-chinese-formal/css3-counter-styles-080.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/simp-chinese-formal/css3-counter-styles-080.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/simp-chinese-formal/css3-counter-styles-080.html)

[trad-chinese-informal]
: Traditional Chinese informal numbering (e.g., 一千一百一十一)
 Tests
 - [counter-trad-chinese-informal.html](https://wpt.fyi/results/css/css-counter-styles/trad-chinese-informal/counter-trad-chinese-informal.html "css/css-counter-styles/trad-chinese-informal/counter-trad-chinese-informal.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/trad-chinese-informal/counter-trad-chinese-informal.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/trad-chinese-informal/counter-trad-chinese-informal.html)
 - [css3-counter-styles-081.html](https://wpt.fyi/results/css/css-counter-styles/trad-chinese-informal/css3-counter-styles-081.html "css/css-counter-styles/trad-chinese-informal/css3-counter-styles-081.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/trad-chinese-informal/css3-counter-styles-081.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/trad-chinese-informal/css3-counter-styles-081.html)
 - [css3-counter-styles-082.html](https://wpt.fyi/results/css/css-counter-styles/trad-chinese-informal/css3-counter-styles-082.html "css/css-counter-styles/trad-chinese-informal/css3-counter-styles-082.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/trad-chinese-informal/css3-counter-styles-082.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/trad-chinese-informal/css3-counter-styles-082.html)
 - [css3-counter-styles-083.html](https://wpt.fyi/results/css/css-counter-styles/trad-chinese-informal/css3-counter-styles-083.html "css/css-counter-styles/trad-chinese-informal/css3-counter-styles-083.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/trad-chinese-informal/css3-counter-styles-083.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/trad-chinese-informal/css3-counter-styles-083.html)
 - [css3-counter-styles-084.html](https://wpt.fyi/results/css/css-counter-styles/trad-chinese-informal/css3-counter-styles-084.html "css/css-counter-styles/trad-chinese-informal/css3-counter-styles-084.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/trad-chinese-informal/css3-counter-styles-084.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/trad-chinese-informal/css3-counter-styles-084.html)
 - [css3-counter-styles-085.html](https://wpt.fyi/results/css/css-counter-styles/trad-chinese-informal/css3-counter-styles-085.html "css/css-counter-styles/trad-chinese-informal/css3-counter-styles-085.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/trad-chinese-informal/css3-counter-styles-085.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/trad-chinese-informal/css3-counter-styles-085.html)

[trad-chinese-formal]
: Traditional Chinese formal numbering (e.g., 壹仟壹佰壹拾壹)
 Tests
 - [counter-trad-chinese-formal.html](https://wpt.fyi/results/css/css-counter-styles/trad-chinese-formal/counter-trad-chinese-formal.html "css/css-counter-styles/trad-chinese-formal/counter-trad-chinese-formal.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/trad-chinese-formal/counter-trad-chinese-formal.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/trad-chinese-formal/counter-trad-chinese-formal.html)
 - [css3-counter-styles-086.html](https://wpt.fyi/results/css/css-counter-styles/trad-chinese-formal/css3-counter-styles-086.html "css/css-counter-styles/trad-chinese-formal/css3-counter-styles-086.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/trad-chinese-formal/css3-counter-styles-086.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/trad-chinese-formal/css3-counter-styles-086.html)
 - [css3-counter-styles-087.html](https://wpt.fyi/results/css/css-counter-styles/trad-chinese-formal/css3-counter-styles-087.html "css/css-counter-styles/trad-chinese-formal/css3-counter-styles-087.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/trad-chinese-formal/css3-counter-styles-087.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/trad-chinese-formal/css3-counter-styles-087.html)
 - [css3-counter-styles-088.html](https://wpt.fyi/results/css/css-counter-styles/trad-chinese-formal/css3-counter-styles-088.html "css/css-counter-styles/trad-chinese-formal/css3-counter-styles-088.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/trad-chinese-formal/css3-counter-styles-088.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/trad-chinese-formal/css3-counter-styles-088.html)
 - [css3-counter-styles-089.html](https://wpt.fyi/results/css/css-counter-styles/trad-chinese-formal/css3-counter-styles-089.html "css/css-counter-styles/trad-chinese-formal/css3-counter-styles-089.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/trad-chinese-formal/css3-counter-styles-089.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/trad-chinese-formal/css3-counter-styles-089.html)
 - [css3-counter-styles-090.html](https://wpt.fyi/results/css/css-counter-styles/trad-chinese-formal/css3-counter-styles-090.html "css/css-counter-styles/trad-chinese-formal/css3-counter-styles-090.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/trad-chinese-formal/css3-counter-styles-090.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/trad-chinese-formal/css3-counter-styles-090.html)

[cjk-ideographic]
: This counter style is identical to
 [trad-chinese-informal](#trad-chinese-informal). (It exists for legacy reasons.)

The Chinese longhand styles are defined by almost identical algorithms
(specified as a single algorithm here, with the differences called out
when relevant), but use different sets of characters, as specified by
the table following the algorithm.

1. If the counter value is 0, the representation is the character for 0
 specified for the given counter style. Skip the rest of this
 algorithm.
2. If the counter value is negative, instead use the absolute value of
 the counter value for the remaining steps of this algorithm.
3. Initially represent the counter value as a decimal number. For each
 digit that is not 0, append the appropriate digit marker to the
 digit. The ones digit has no marker.
4. For the informal styles, if the counter value is between ten and
 nineteen, remove the tens digit (leave the digit marker).
5. Drop any trailing zeros and collapse any remaining zeros into a
 single zero digit.
6. Replace the digits 0-9 with the appropriate character for the given
 counter style.
7. If the counter value was negative, prepend the appropriate negative
 sign character for the given counter style as specified in the table
 of characters for each style.
8. Return the resultant string as the representation of the counter
 value.

For all of these counter styles, the
[suffix](#descdef-counter-style-suffix) is \"、\" U+3001, the
[fallback](#descdef-counter-style-fallback) is
[cjk-decimal](#cjk-decimal), the
[range](#descdef-counter-style-range) is [-9999 9999], and the
[negative](#descdef-counter-style-negative) value is given in the table of symbols
for each style.

The following tables define the characters used in these styles:

Values

Codepoints

simp-chinese-informal

simp-chinese-formal

trad-chinese-informal

trad-chinese-formal

Digit 0

零 U+96F6

零 U+96F6

零 U+96F6

零 U+96F6

Digit 1

一 U+4E00

壹 U+58F9

一 U+4E00

壹 U+58F9

Digit 2

二 U+4E8C

贰 U+8D30

二 U+4E8C

貳 U+8CB3

Digit 3

三 U+4E09

叁 U+53C1

三 U+4E09

參 U+53C3

Digit 4

四 U+56DB

肆 U+8086

四 U+56DB

肆 U+8086

Digit 5

五 U+4E94

伍 U+4F0D

五 U+4E94

伍 U+4F0D

Digit 6

六 U+516D

陆 U+9646

六 U+516D

陸 U+9678

Digit 7

七 U+4E03

柒 U+67D2

七 U+4E03

柒 U+67D2

Digit 8

八 U+516B

捌 U+634C

八 U+516B

捌 U+634C

Digit 9

九 U+4E5D

玖 U+7396

九 U+4E5D

玖 U+7396

Tens Digit Marker

十 U+5341

拾 U+62FE

十 U+5341

拾 U+62FE

Hundreds Digit Marker

百 U+767E

佰 U+4F70

百 U+767E

佰 U+4F70

Thousands Digit Marker

千 U+5343

仟 U+4EDF

千 U+5343

仟 U+4EDF

Negative Sign

负 U+8D1F

负 U+8D1F

負 U+8CA0

負 U+8CA0

For reference, here are the first 120 values for the
[simp-chinese-informal](#simp-chinese-informal) style:

 1　　　　 一 41　　 四十一 81　　 八十一
 2　　　　 二 42　　 四十二 82　　 八十二
 3　　　　 三 43　　 四十三 83　　 八十三
 4　　　　 四 44　　 四十四 84　　 八十四
 5　　　　 五 45　　 四十五 85　　 八十五
 6　　　　 六 46　　 四十六 86　　 八十六
 7　　　　 七 47　　 四十七 87　　 八十七
 8　　　　 八 48　　 四十八 88　　 八十八
 9　　　　 九 49　　 四十九 89　　 八十九
 10　　　　 十 50　　　 五十 90　　　 九十
 11　　　 十一 51　　 五十一 91　　 九十一
 12　　　 十二 52　　 五十二 92　　 九十二
 13　　　 十三 53　　 五十三 93　　 九十三
 14　　　 十四 54　　 五十四 94　　 九十四
 15　　　 十五 55　　 五十五 95　　 九十五
 16　　　 十六 56　　 五十六 96　　 九十六
 17　　　 十七 57　　 五十七 97　　 九十七
 18　　　 十八 58　　 五十八 98　　 九十八
 19　　　 十九 59　　 五十九 99　　 九十九
 20　　　 二十 60　　　 六十 100　　　 一百
 21　　 二十一 61　　 六十一 101　 一百零一
 22　　 二十二 62　　 六十二 102　 一百零二
 23　　 二十三 63　　 六十三 103　 一百零三
 24　　 二十四 64　　 六十四 104　 一百零四
 25　　 二十五 65　　 六十五 105　 一百零五
 26　　 二十六 66　　 六十六 106　 一百零六
 27　　 二十七 67　　 六十七 107　 一百零七
 28　　 二十八 68　　 六十八 108　 一百零八
 29　　 二十九 69　　 六十九 109　 一百零九
 30　　　 三十 70　　　 七十 110　 一百一十
 31　　 三十一 71　　 七十一 111 一百一十一
 32　　 三十二 72　　 七十二 112 一百一十二
 33　　 三十三 73　　 七十三 113 一百一十三
 34　　 三十四 74　　 七十四 114 一百一十四
 35　　 三十五 75　　 七十五 115 一百一十五
 36　　 三十六 76　　 七十六 116 一百一十六
 37　　 三十七 77　　 七十七 117 一百一十七
 38　　 三十八 78　　 七十八 118 一百一十八
 39　　 三十九 79　　 七十九 119 一百一十九
 40　　　 四十 80　　　 八十 120　 一百二十

#### 7.1.2. Extended Implementation (optional)

Some counter styles described in earlier chapters have been limited to
an artifically small (though still useful) range to reduce the overall
complexity of the spec and the task of implementing those styles.
However, some implementations might consider the extra complexity
worthwhile for the additional range it offers to authors. To accomodate
this, this section describes how to extend the limited counter-styles to
a larger range.

This entire section is normative, but **optional**. User-agents may
ignore it and still be conformant. If a user-agent implements some of
the extended forms described in this section, they must be implemented
as described here.

All of the Chinese, Japanese, and Korean styles are defined here for all
numbers between -10^16^ and 10^16^, exclusive. For numbers outside this
range, the [cjk-decimal](#cjk-decimal) style is used. All of the styles are defined by
almost identical algorithms (specified as a single algorithm here, with
the differences called out when relevant), but use different sets of
characters. The list following the algorithm gives the name of each
counter style using this algorithm, and the individual character sets
used by each style.

1. If the counter value is 0, the representation is the character for 0
 specified for the given counter style. Skip the rest of this
 algorithm.
2. If the counter value is negative, instead use the absolute value of
 the counter value for the remaining steps of this algorithm.
3. Initially represent the counter value as a decimal number. Starting
 from the right (ones place), split the decimal number into groups of
 four digits.
4. For each group with a non-zero value, append the appropriate group
 marker to the group. The ones group has no marker.
5. Within each group, for each digit that is not 0, append the
 appropriate digit marker to the digit. The ones digit of each group
 has no marker.
6. Drop ones:
 - For the Chinese informal styles, for any group with a value
 between ten and nineteen, remove the tens digit (leave the digit
 marker).
 - For the Japanese informal and Korean informal styles, if any of
 the digit markers are preceded by the digit 1, and that digit is
 not the first digit of the group, remove the digit (leave the
 digit marker).
 - For Korean informal styles, if the value of the ten-thousands
 group is 1, drop the digit (leave the digit marker).
7. Drop zeros:
 - For the Japanese and Korean styles, drop all zero digits.
 - For the Chinese styles, drop any trailing zeros for all non-zero
 groups and collapse (across groups) each remaining consecutive
 group of zeros into a single zero digit.
8. For the Korean styles, insert a space (\" \" U+0020) between each
 group.
9. Replace the digits 0-9 with the appropriate character for the given
 counter style.
10. If the counter value was negative, prepend the appropriate negative
 sign character for the given counter style as specified in the table
 of characters for each style.
11. Return the resultant string as the representation of the counter
 value.

For all of these counter styles, the descriptors are the same as for the
[limited range variants](#limited-range-required), except for the
[range](#descdef-counter-style-range), which is [calc(-1 \* pow(10, 16) + 1)
calc(pow(10, 16) - 1)].

The following tables define the characters used in these styles:

Values

Codepoints

simp-chinese-informal

simp-chinese-formal

trad-chinese-informal

trad-chinese-formal

Digit 0

零 U+96F6

零 U+96F6

零 U+96F6

零 U+96F6

Digit 1

一 U+4E00

壹 U+58F9

一 U+4E00

壹 U+58F9

Digit 2

二 U+4E8C

贰 U+8D30

二 U+4E8C

貳 U+8CB3

Digit 3

三 U+4E09

叁 U+53C1

三 U+4E09

參 U+53C3

Digit 4

四 U+56DB

肆 U+8086

四 U+56DB

肆 U+8086

Digit 5

五 U+4E94

伍 U+4F0D

五 U+4E94

伍 U+4F0D

Digit 6

六 U+516D

陆 U+9646

六 U+516D

陸 U+9678

Digit 7

七 U+4E03

柒 U+67D2

七 U+4E03

柒 U+67D2

Digit 8

八 U+516B

捌 U+634C

八 U+516B

捌 U+634C

Digit 9

九 U+4E5D

玖 U+7396

九 U+4E5D

玖 U+7396

Second Digit Marker

十 U+5341

拾 U+62FE

十 U+5341

拾 U+62FE

Third Digit Marker

百 U+767E

佰 U+4F70

百 U+767E

佰 U+4F70

Fourth Digit Marker

千 U+5343

仟 U+4EDF

千 U+5343

仟 U+4EDF

Second Group Marker

万 U+4E07

万 U+4E07

萬 U+842C

萬 U+842C

Third Group Marker

亿 U+4EBF

亿 U+4EBF

億 U+5104

億 U+5104

Fourth Group Marker

万亿 U+4E07 U+4EBF

万亿 U+4E07 U+4EBF

兆 U+5146

兆 U+5146

Negative Sign

负 U+8D1F

负 U+8D1F

負 U+8CA0

負 U+8CA0

Values

Codepoints

japanese-informal

japanese-formal

Digit 0

〇 U+3007

零 U+96F6

Digit 1

一 U+4E00

壱 U+58F1

Digit 2

二 U+4E8C

弐 U+5F10

Digit 3

三 U+4E09

参 U+53C2

Digit 4

四 U+56DB

四 U+56DB

Digit 5

五 U+4E94

伍 U+4f0D

Digit 6

六 U+516D

六 U+516D

Digit 7

七 U+4E03

七 U+4E03

Digit 8

八 U+516B

八 U+516B

Digit 9

九 U+4E5D

九 U+4E5D

Second Digit Marker

十 U+5341

拾 U+62FE

Third Digit Marker

百 U+767E

百 U+767E

Fourth Digit Marker

千 U+5343

阡 U+9621

Second Group Marker

万 U+4E07

萬 U+842C

Third Group Marker

億 U+5104

億 U+5104

Fourth Group Marker

兆 U+5146

兆 U+5146

Negative Sign

マイナス U+30DE U+30A4 U+30CA U+30B9

Values

Codepoints

korean-hangul-formal

korean-hanja-informal

korean-hanja-formal

Digit 0

영 U+C601

零 U+96F6

零 U+96F6

Digit 1

일 U+C77C

一 U+4E00

壹 U+58F9

Digit 2

이 U+C774

二 U+4E8C

貳 U+8CB3

Digit 3

삼 U+C0BC

三 U+4E09

參 U+53C3

Digit 4

사 U+C0AC

四 U+56DB

四 U+56DB

Digit 5

오 U+C624

五 U+4E94

五 U+4E94

Digit 6

육 U+C721

六 U+516D

六 U+516D

Digit 7

칠 U+CE60

七 U+4E03

七 U+4E03

Digit 8

팔 U+D314

八 U+516B

八 U+516B

Digit 9

구 U+AD6C

九 U+4E5D

九 U+4E5D

Second Digit Marker

십 U+C2ED

十 U+5341

拾 U+62FE

Third Digit Marker

백 U+BC31

百 U+767E

百 U+767E

Fourth Digit Marker

천 U+CC9C

千 U+5343

仟 U+4EDF

Second Group Marker

만 U+B9CC

萬 U+842C

萬 U+842C

Third Group Marker

억 U+C5B5

億 U+5104

億 U+5104

Fourth Group Marker

조 U+C870

兆 U+5146

兆 U+5146

Negative Sign

마이너스 U+B9C8 U+C774 U+B108 U+C2A4

### 7.2. Ethiopic Numeric Counter Style: [ethiopic-numeric]
The [ethiopic-numeric] counter style is defined for all positive non-zero numbers.
The following algorithm converts decimal digits to ethiopic numbers:

1. If the number is 1, return \"፩\" (U+1369).
2. Split the number into groups of two digits, starting with the least
 significant decimal digit.
3. Index each group sequentially, starting from the least significant
 as group number zero.
4. If the group has the value zero, or if the group is the most
 significant one and has the value 1, or if the group has an odd
 index (as given in the previous step) and has the value 1, then
 remove the digits (but leave the group, so it still has a separator
 appended below).
5. For each remaining digit, substitute the relevant ethiopic character
 from the list below.
 Tens
 Units
 Values
 Codepoints
 Values
 Codepoints
 10
 ፲
 U+1372
 1
 ፩
 U+1369
 20
 ፳
 U+1373
 2
 ፪
 U+136A
 30
 ፴
 U+1374
 3
 ፫
 U+136B
 40
 ፵
 U+1375
 4
 ፬
 U+136C
 50
 ፶
 U+1376
 5
 ፭
 U+136D
 60
 ፷
 U+1377
 6
 ፮
 U+136E
 70
 ፸
 U+1378
 7
 ፯
 U+136F
 80
 ፹
 U+1379
 8
 ፰
 U+1370
 90
 ፺
 U+137A
 9
 ፱
 U+1371
6. For each group with an odd index (as given in the second step),
 except groups which originally had a value of zero, append ፻ U+137B.
7. For each group with an even index (as given in the second step),
 except the group with index 0, append ፼ U+137C.
8. Concatenate the groups into one string, and return it.

For this system, the name is \"ethiopic-numeric\", the
[range](#descdef-counter-style-range) is [1 infinite], the
[suffix](#descdef-counter-style-suffix) is `"/ "` (U+002F SOLIDUS followed by a
U+0020 SPACE), and the rest of the descriptors have their initial value.

The decimal number 100, in ethiopic,
is ፻ U+137B

The decimal number 78010092, in ethiopic, is ፸፰፻፩፼፺፪ U+1378 U+1370
U+137B U+1369 U+137C U+137A U+136A.

The decimal number 780100000092, in ethiopic, is ፸፰፻፩፼፼፺፪ U+1378 U+1370
U+137B U+1369 U+137C U+137C U+137A U+136A.

- [counter-ethiopic-numeric.html](https://wpt.fyi/results/css/css-counter-styles/ethiopic-numeric/counter-ethiopic-numeric.html "css/css-counter-styles/ethiopic-numeric/counter-ethiopic-numeric.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/ethiopic-numeric/counter-ethiopic-numeric.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/ethiopic-numeric/counter-ethiopic-numeric.html)
- [css3-counter-styles-068.html (visual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/ethiopic-numeric/css3-counter-styles-068.html)
- [css3-counter-styles-069.html (visual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/ethiopic-numeric/css3-counter-styles-069.html)
- [css3-counter-styles-070.html (visual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/ethiopic-numeric/css3-counter-styles-070.html)

## 8. Additional "Ready-made" Counter Styles

The [Internationalization Working
Group](https://www.w3.org/International/) maintains a collection of
additional
[\@counter-style](#at-ruledef-counter-style) rules for various world languages in [Ready-made
Counter Styles](https://www.w3.org/TR/predefined-counter-styles/).
[\[predefined-counter-styles\]](#biblio-predefined-counter-styles "Ready-made Counter Styles")

As with the counter styles defined in [§ 6 Simple Predefined Counter
Styles](#predefined-counters), UAs must include these in their UA
stylesheet (or at least act as if these rules were defined at that
level).

 Authors can use the [Ready-made Counter
Styles](https://www.w3.org/TR/predefined-counter-styles/) even in UAs
that don't support them by copying the rules directly into their style
sheets.

## 9. APIs

### 9.1. Extensions to the `CSSRule` interface

The `CSSRule` interface is extended as follows:

```
partial interface CSSRule {
 const unsigned short COUNTER_STYLE_RULE = 11;
};
```

### 9.2. The `CSSCounterStyleRule` interface

The
[CSSCounterStyleRule](#csscounterstylerule) interface represents a
[\@counter-style](#at-ruledef-counter-style) rule.

```
[Exposed=Window]
interface CSSCounterStyleRule : CSSRule {
 attribute CSSOMString name;
 attribute CSSOMString system;
 attribute CSSOMString symbols;
 attribute CSSOMString additiveSymbols;
 attribute CSSOMString negative;
 attribute CSSOMString prefix;
 attribute CSSOMString suffix;
 attribute CSSOMString range;
 attribute CSSOMString pad;
 attribute CSSOMString speakAs;
 attribute CSSOMString fallback;
};
```

Tests

- [cssom-additive-symbols-setter-invalid.html](https://wpt.fyi/results/css/css-counter-styles/cssom/cssom-additive-symbols-setter-invalid.html "css/css-counter-styles/cssom/cssom-additive-symbols-setter-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cssom/cssom-additive-symbols-setter-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cssom/cssom-additive-symbols-setter-invalid.html)
- [cssom-additive-symbols-setter.html](https://wpt.fyi/results/css/css-counter-styles/cssom/cssom-additive-symbols-setter.html "css/css-counter-styles/cssom/cssom-additive-symbols-setter.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cssom/cssom-additive-symbols-setter.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cssom/cssom-additive-symbols-setter.html)
- [cssom-fallback-setter-invalid.html](https://wpt.fyi/results/css/css-counter-styles/cssom/cssom-fallback-setter-invalid.html "css/css-counter-styles/cssom/cssom-fallback-setter-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cssom/cssom-fallback-setter-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cssom/cssom-fallback-setter-invalid.html)
- [cssom-fallback-setter.html](https://wpt.fyi/results/css/css-counter-styles/cssom/cssom-fallback-setter.html "css/css-counter-styles/cssom/cssom-fallback-setter.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cssom/cssom-fallback-setter.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cssom/cssom-fallback-setter.html)
- [cssom-name-setter-invalid.html](https://wpt.fyi/results/css/css-counter-styles/cssom/cssom-name-setter-invalid.html "css/css-counter-styles/cssom/cssom-name-setter-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cssom/cssom-name-setter-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cssom/cssom-name-setter-invalid.html)
- [cssom-name-setter.html](https://wpt.fyi/results/css/css-counter-styles/cssom/cssom-name-setter.html "css/css-counter-styles/cssom/cssom-name-setter.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cssom/cssom-name-setter.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cssom/cssom-name-setter.html)
- [cssom-negative-setter-invalid.html](https://wpt.fyi/results/css/css-counter-styles/cssom/cssom-negative-setter-invalid.html "css/css-counter-styles/cssom/cssom-negative-setter-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cssom/cssom-negative-setter-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cssom/cssom-negative-setter-invalid.html)
- [cssom-negative-setter.html](https://wpt.fyi/results/css/css-counter-styles/cssom/cssom-negative-setter.html "css/css-counter-styles/cssom/cssom-negative-setter.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cssom/cssom-negative-setter.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cssom/cssom-negative-setter.html)
- [cssom-pad-setter-invalid.html](https://wpt.fyi/results/css/css-counter-styles/cssom/cssom-pad-setter-invalid.html "css/css-counter-styles/cssom/cssom-pad-setter-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cssom/cssom-pad-setter-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cssom/cssom-pad-setter-invalid.html)
- [cssom-pad-setter.html](https://wpt.fyi/results/css/css-counter-styles/cssom/cssom-pad-setter.html "css/css-counter-styles/cssom/cssom-pad-setter.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cssom/cssom-pad-setter.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cssom/cssom-pad-setter.html)
- [cssom-prefix-suffix-setter-invalid.html](https://wpt.fyi/results/css/css-counter-styles/cssom/cssom-prefix-suffix-setter-invalid.html "css/css-counter-styles/cssom/cssom-prefix-suffix-setter-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cssom/cssom-prefix-suffix-setter-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cssom/cssom-prefix-suffix-setter-invalid.html)
- [cssom-prefix-suffix-setter.html](https://wpt.fyi/results/css/css-counter-styles/cssom/cssom-prefix-suffix-setter.html "css/css-counter-styles/cssom/cssom-prefix-suffix-setter.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cssom/cssom-prefix-suffix-setter.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cssom/cssom-prefix-suffix-setter.html)
- [cssom-range-setter-invalid.html](https://wpt.fyi/results/css/css-counter-styles/cssom/cssom-range-setter-invalid.html "css/css-counter-styles/cssom/cssom-range-setter-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cssom/cssom-range-setter-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cssom/cssom-range-setter-invalid.html)
- [cssom-range-setter.html](https://wpt.fyi/results/css/css-counter-styles/cssom/cssom-range-setter.html "css/css-counter-styles/cssom/cssom-range-setter.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cssom/cssom-range-setter.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cssom/cssom-range-setter.html)
- [cssom-symbols-setter-invalid.html](https://wpt.fyi/results/css/css-counter-styles/cssom/cssom-symbols-setter-invalid.html "css/css-counter-styles/cssom/cssom-symbols-setter-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cssom/cssom-symbols-setter-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cssom/cssom-symbols-setter-invalid.html)
- [cssom-symbols-setter.html](https://wpt.fyi/results/css/css-counter-styles/cssom/cssom-symbols-setter.html "css/css-counter-styles/cssom/cssom-symbols-setter.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cssom/cssom-symbols-setter.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cssom/cssom-symbols-setter.html)
- [cssom-system-setter-1.html](https://wpt.fyi/results/css/css-counter-styles/cssom/cssom-system-setter-1.html "css/css-counter-styles/cssom/cssom-system-setter-1.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cssom/cssom-system-setter-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cssom/cssom-system-setter-1.html)
- [cssom-system-setter-2.html](https://wpt.fyi/results/css/css-counter-styles/cssom/cssom-system-setter-2.html "css/css-counter-styles/cssom/cssom-system-setter-2.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cssom/cssom-system-setter-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cssom/cssom-system-setter-2.html)
- [cssom-system-setter-invalid.html](https://wpt.fyi/results/css/css-counter-styles/cssom/cssom-system-setter-invalid.html "css/css-counter-styles/cssom/cssom-system-setter-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-counter-styles/cssom/cssom-system-setter-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-counter-styles/cssom/cssom-system-setter-invalid.html)

[`name`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring)

: The `name` attribute on getting must return a
 `CSSOMString` object that contains the serialization of the
 [\<counter-style-name\>](#typedef-counter-style-name) defined for the associated rule.

 On setting the `name` attribute, run the following steps:

 1. If the value is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for \"none\" or one of the
 [non-overridable counter styles], do nothing and
 return.

 2. If the value is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for any of the predefined [counter
 styles](#counter-style), lowercase it.

 3. Replace the associated rule's name with an
 [identifier](https://drafts.csswg.org/css-values-3/#css-css-identifier) equal to the value.

[`system`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring)\
[`symbols`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring)\
[`additiveSymbols`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring)\
[`negative`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring)\
[`prefix`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring)\
[`suffix`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring)\
[`range`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring)\
[`pad`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring)\
[`speakAs`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring)\
[`fallback`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring)

: The remaining attributes on getting must return a `CSSOMString`
 object that contains the serialization of the associated descriptor
 defined for the associated rule. If the descriptor was not specified
 in the associated rule, the attribute must return an empty string.

 On setting, run the following steps:

 1. [parse](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) [the given
 value](https://webidl.spec.whatwg.org/#the-given-value) as the descriptor associated with the
 attribute.

 2. If the result is invalid according to the given descriptor's
 grammar, or would cause the
 [\@counter-style](#at-ruledef-counter-style) rule to not define a counter style, do
 nothing and abort these steps. (For example, some systems
 require the
 [symbols](#descdef-counter-style-symbols) descriptor to contain two
 values.)

 3. If the attribute being set is
 [system](#dom-csscounterstylerule-system), and the new value would change the algorithm
 used, do nothing and abort these steps. [It's okay to change an
 aspect of the algorithm, like the [first symbol
 value](#first-symbol-value) of a
 [fixed](#valdef-counter-style-system-fixed) system.]

 4. Set the descriptor to the value.

## 10. Sample style sheet for HTML

This section is informative, not normative. HTML itself defines the
styles that apply to its elements, and in some cases defers to the user
agent's discretion.

 details > summary {
 display: list-item;
 list-style: disclosure-closed inside;
 }

 details[open] > summary {
 list-style: disclosure-open inside;
 }

## [ Changes]
### [ Changes since the July 2021 Candidate Recommendation]
Significant changes since the [July 27 2021 Candidate
Recommendation](https://www.w3.org/TR/2021/CR-css-counter-styles-3-20210727/):

- Added [fallback:
 cjk-decimal](#descdef-counter-style-fallback) descriptor to
 [cjk-earthly-branch](#valdef-counter-style-name-cjk-earthly-branch) and
 [cjk-heavenly-stem](#valdef-counter-style-name-cjk-heavenly-stem). ([Issue
 8975](https://github.com/w3c/csswg-drafts/issues/8975))

- Restored the [fallback: cjk-decimal] descriptor to the Korean
 styles which was accidentally dropped in [this
 commit](https://github.com/w3c/csswg-drafts/commit/20a3d9ca02f235d8af13aa2bb05f725448371ad2).
 ([Issue 8870](https://github.com/w3c/csswg-drafts/issues/8870))

- Fixed the accidental desync between disallowed name keywords in the
 syntax vs the OM. ([Issue
 8186](https://github.com/w3c/csswg-drafts/issues/8186))

- Added conformance requirement to support [Ready-made Counter
 Styles](https://www.w3.org/TR/predefined-counter-styles/). ([Issue
 8636](https://github.com/w3c/csswg-drafts/issues/8636))

- Added Web Platform Tests coverage.

- Added the
 [\<symbolic-glyph\>](#typedef-symbolic-glyph) production for easier
 cross-referencing.

### [ Changes since the December 2017 Candidate Recommendation]
Significant changes since the [December 14 2017 Candidate
Recommendation](https://www.w3.org/TR/2017/CR-css-counter-styles-3-20171214/):

- Made
 [none](https://drafts.csswg.org/css-lists-3/#valdef-list-style-type-none), [decimal](#decimal), [disc](#disc), [circle](#circle), [square](#square),
 [disclosure-open](#disclosure-open), [disclosure-close] non-overridable. ([Issue
 3584](https://github.com/w3c/csswg-drafts/issues/3584))

- Clarified counter-style lookups in Shadow DOM. ([Issue
 5693](https://github.com/w3c/csswg-drafts/issues/5693))

- Clarified what happens in various invalid
 [\@counter-style](#at-ruledef-counter-style) situations. ([Issue
 5698](https://github.com/w3c/csswg-drafts/issues/5698), [Issue
 5717](https://github.com/w3c/csswg-drafts/issues/5717))

- Fixed divide-by-zero error in additive algorithm. ([Issue
 5784](https://github.com/w3c/csswg-drafts/issues/5784))

- Fixed [square](#square)
 symbol to not use an emoji symbol. ([Issue
 6200](https://github.com/w3c/csswg-drafts/issues/6200))

- Allowed UAs to override the font choice of predefined symbolic counter
 styles. ([Issue
 6201](https://github.com/w3c/csswg-drafts/issues/6201))

- Restricted special rendering of predefined symbolic counter styles to
 usage as a list marker via
 [list-style-type](https://drafts.csswg.org/css-lists-3/#propdef-list-style-type). ([Issue
 6201](https://github.com/w3c/csswg-drafts/issues/6201))

- Clarified that
 [speak-as](#descdef-counter-style-speak-as) represents spoken output; it may be
 used for other AT. ([Issue
 6040](https://github.com/w3c/csswg-drafts/issues/6040))

 > A counter style can be constructed with a meaning that is obvious
 > visually, but impossible to meaningfully represent via a speech
 > synthesizer or other non-visual means, or possible but nonsensical
 > when naively read out [loud] . The
 > [speak-as](#descdef-counter-style-speak-as) descriptor describes how to
 > synthesize the spoken form of a counter formatted with the given
 > counter style. [Assistive technologies should use this spoken form
 > when reading out the counter style, and may use the
 > [speak-as](#descdef-counter-style-speak-as) value to inform transformations to
 > outputs other than speech.]

A [Disposition of
Comments](https://drafts.csswg.org/css-counter-styles-3/issues-cr-2017)
is available.

### [ Changes since the June 2015 Candidate Recommendation]
Significant changes since the [June 11 2015 Candidate
Recommendation](https://www.w3.org/TR/2015/CR-css-counter-styles-3-20150611/):

- Exclude
 [none](https://drafts.csswg.org/css-lists-3/#valdef-list-style-type-none) and [disc](#disc) from being the name of a counter style.

- When setting CSSCounterStyle.name, take the string directly; don't
 [parse](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) it as an ident.

- Clarify that counter styles are read out in the element's [content
 language](https://drafts.csswg.org/css-text-4/#content-language).

- Clarified that
 [additive-symbols](#descdef-counter-style-additive-symbols) tuples must be of *strictly*
 decreasing weight.

- Specified that invalid values just invalidate the declaration, not the
 whole rule.

- [\@counter-style](#at-ruledef-counter-style) rules that are invalid due to missing
 descriptors just fail to create a [counter
 style](#counter-style);
 they're otherwise still valid rules.

- Changed syntax to use [CSS bracketed range
 notation](https://drafts.csswg.org/css-values-4/#css-bracketed-range-notation) to reflect the prose restrictions on negative values.

A [Disposition of
Comments](https://drafts.csswg.org/css-counter-styles-3/issues-cr-20150611)
is available.

### [ Changes since the Feb 2015 Candidate Recommendation]
- Allowed UAs to extend the [hebrew](#hebrew) style past the spec-defined limits (since the
 current limits are mostly just an artifact of how annoying it is to go
 higher with the
 [\@counter-style](#at-ruledef-counter-style)-based definition).

## [ Acknowledgments]
The following people and documentation they wrote were very useful for
defining the numbering systems: Alexander Savenkov, Arron Eicholz, Aryeh
Gregor, Christopher Hoess, Daniel Yacob, Frank Tang, Jonathan Rosenne,
Karl Ove Hufthammer, Musheg Arakelyan, Nariné Renard Karapetyan, Randall
Bart, Richard Ishida, Simon Montagu (Mozilla, smontagu@smontagu.org)

Special thanks to Xidorn Quan for *extensive* reviews of all aspects of
the spec, and also to Simon Sapin and Håkon Wium Lie for their review
comments.

## [ Privacy Considerations]
This specification introduces no new privacy considerations.

## [ Security Considerations]
This specification introduces no new security considerations.
