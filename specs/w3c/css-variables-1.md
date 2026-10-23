## 1. Introduction

*This section is not normative.*

Large documents or applications (and even small ones) can contain quite
a bit of CSS. Many of the values in the CSS file will be duplicate data;
for example, a site may establish a color scheme and reuse three or four
colors throughout the site. Altering this data can be difficult and
error-prone, since it's scattered throughout the CSS file (and possibly
across multiple files), and may not be amenable to Find-and-Replace.

This module introduces a family of custom author-defined properties
known collectively as [custom
properties](#custom-property),
which allow an author to assign arbitrary values to a property with an
author-chosen name, and the [var()](#funcdef-var) function, which allow an author to then use
those values in other properties elsewhere in the document. This makes
it easier to read large files, as seemingly-arbitrary values now have
informative names, and makes editing such files much easier and less
error-prone, as one only has to change the value once, in the [custom
property], and the change will propagate to
all uses of that variable automatically.

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
keywords](https://drafts.csswg.org/css-values-4/#css-wide-keywords) as their property value. For readability they have not
been repeated explicitly.

## [2. ][ Defining Custom Properties: the [\--\*] family of properties]
This specification defines an open-ended set of properties called
[custom properties](#custom-property), which, among other things, are used to define the
[substitution
value](https://drafts.csswg.org/css-values-5/#substitute-arbitrary-substitution-function) of [var()](#funcdef-var) functions.

Name:

[\--\*]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<declaration-value\>](https://drafts.csswg.org/css-syntax-3/#typedef-declaration-value)[?](https://drafts.csswg.org/css-values-4/#mult-opt)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

the [guaranteed-invalid
value](#guaranteed-invalid-value)

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements and all pseudo-elements (including those with restricted
property lists)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified value with variables substituted, or the [guaranteed-invalid
value](#guaranteed-invalid-value)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

*User agents are expected to support this property on all media,
including non-visual ones.*

A [custom property] is any property whose name starts with two dashes (U+002D
HYPHEN-MINUS), like [\--foo]. The
[\<custom-property-name\>] production corresponds to this:
it's defined as any
[\<dashed-ident\>](https://drafts.csswg.org/css-values-4/#typedef-dashed-ident) (a valid
[identifier](https://drafts.csswg.org/css-values-4/#css-css-identifier) that starts with two dashes), except [\--]
itself, which is reserved for future use by CSS. [Custom
properties](#custom-property)
are solely for use by authors and users; CSS will never give them a
meaning beyond what is presented here.

Tests

- [variable-declaration-29.html](https://wpt.fyi/results/css/css-variables/variable-declaration-29.html "css/css-variables/variable-declaration-29.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-29.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-29.html)
- [variable-declaration-31.html](https://wpt.fyi/results/css/css-variables/variable-declaration-31.html "css/css-variables/variable-declaration-31.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-31.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-31.html)
- [variable-declaration-32.html](https://wpt.fyi/results/css/css-variables/variable-declaration-32.html "css/css-variables/variable-declaration-32.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-32.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-32.html)
- [variable-declaration-33.html](https://wpt.fyi/results/css/css-variables/variable-declaration-33.html "css/css-variables/variable-declaration-33.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-33.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-33.html)
- [variable-declaration-34.html](https://wpt.fyi/results/css/css-variables/variable-declaration-34.html "css/css-variables/variable-declaration-34.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-34.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-34.html)
- [variable-declaration-35.html](https://wpt.fyi/results/css/css-variables/variable-declaration-35.html "css/css-variables/variable-declaration-35.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-35.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-35.html)
- [variable-declaration-36.html](https://wpt.fyi/results/css/css-variables/variable-declaration-36.html "css/css-variables/variable-declaration-36.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-36.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-36.html)
- [variable-declaration-40.html](https://wpt.fyi/results/css/css-variables/variable-declaration-40.html "css/css-variables/variable-declaration-40.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-40.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-40.html)
- [variable-declaration-41.html](https://wpt.fyi/results/css/css-variables/variable-declaration-41.html "css/css-variables/variable-declaration-41.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-41.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-41.html)
- [variable-declaration-42.html](https://wpt.fyi/results/css/css-variables/variable-declaration-42.html "css/css-variables/variable-declaration-42.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-42.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-42.html)
- [variable-empty-name-reserved.html](https://wpt.fyi/results/css/css-variables/variable-empty-name-reserved.html "css/css-variables/variable-empty-name-reserved.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-empty-name-reserved.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-empty-name-reserved.html)

Custom properties define variables,
referenced with the [var()](#funcdef-var) notation, which can be used for many purposes. For
example, a page that consistently uses a small set of colors in its
design can store the colors in custom properties and use them with
variables:

``` highlight
:root {
 --main-color: #06c;
 --accent-color: #006;
}
/* The rest of the CSS file */
#foo h1 {
 color: var(--main-color);
}
```

The naming provides a mnemonic for the colors, prevents
difficult-to-spot typos in the color codes, and if the theme colors are
ever changed, focuses the change on one simple spot (the custom property
value) rather than requiring many edits across all stylesheets in the
webpage.

Unlike other CSS properties, custom property names are *not* [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive). Instead, custom property names are only equal to each
other if they are [identical
to](https://infra.spec.whatwg.org/#is) each
other.

Tests

- [css-vars-custom-property-case-sensitive-001.html](https://wpt.fyi/results/css/css-variables/css-vars-custom-property-case-sensitive-001.html "css/css-variables/css-vars-custom-property-case-sensitive-001.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/css-vars-custom-property-case-sensitive-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/css-vars-custom-property-case-sensitive-001.html)

While both [\--foo] and
[\--FOO] are valid, they are distinct properties ---​using
[var(\--foo)] will refer to the first one, while using
[var(\--FOO)] will refer to the second.

Perhaps more surprisingly, [\--foó] and [\--foó] are
distinct properties. The first is spelled with U+00F3 (LATIN SMALL
LETTER O WITH ACUTE) while the second is spelled with an ASCII \"o\"
followed by U+0301 (COMBINING ACUTE ACCENT), and the \"[identical
to](https://infra.spec.whatwg.org/#is)\"
relation uses direct codepoint-by-codepoint comparison to determine if
two strings are equal, to avoid the complexities and pitfalls of unicode
normalization and locale-specific collation.

Operating systems, keyboards, or input methods sometimes encode
visually-identical text using different codepoint sequences. Authors are
advised to choose variable names that avoid potential confusion or to
use escapes and other means to ensure that similar appearing sequences
are identical. See Section 2.3 in
[\[CHARMOD-NORM\]](#biblio-charmod-norm "Character Model for the World Wide Web: String Matching")
for examples.

Developers maintaining the following
CSS might be confused why the test patch is red:

``` highlight
--fijord: red;
--fĳord: green;
--ﬁjord: blue;

.test {
 background-color: var(--fijord);
}
```

The reason is that the first custom property uses the character sequence
LATIN SMALL LETTER F + LATIN SMALL LETTER I + LATIN SMALL LETTER J; the
second, identical-looking one uses the character sequence LATIN SMALL
LETTER F + LATIN SMALL LIGATURE IJ while the third uses the character
sequence LATIN SMALL LIGATURE FI + LATIN SMALL LETTER J.

So the CSS contains three distinct custom properties, two of which are
unused.

Custom properties are **not** reset by the
[all](https://drafts.csswg.org/css-cascade-5/#propdef-all) property. [We may define a property
in the future that resets all variables.]

The [CSS-wide
keywords](https://drafts.csswg.org/css-values-4/#css-wide-keywords) can be used in custom properties, with the same meaning
as in any another property.

Tests

- [variable-declaration-43.html](https://wpt.fyi/results/css/css-variables/variable-declaration-43.html "css/css-variables/variable-declaration-43.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-43.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-43.html)
- [variable-declaration-44.html](https://wpt.fyi/results/css/css-variables/variable-declaration-44.html "css/css-variables/variable-declaration-44.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-44.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-44.html)
- [variable-declaration-45.html](https://wpt.fyi/results/css/css-variables/variable-declaration-45.html "css/css-variables/variable-declaration-45.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-45.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-45.html)
- [variable-declaration-46.html](https://wpt.fyi/results/css/css-variables/variable-declaration-46.html "css/css-variables/variable-declaration-46.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-46.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-46.html)
- [variable-declaration-47.html](https://wpt.fyi/results/css/css-variables/variable-declaration-47.html "css/css-variables/variable-declaration-47.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-47.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-47.html)
- [variable-declaration-56.html](https://wpt.fyi/results/css/css-variables/variable-declaration-56.html "css/css-variables/variable-declaration-56.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-56.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-56.html)
- [variable-declaration-57.html](https://wpt.fyi/results/css/css-variables/variable-declaration-57.html "css/css-variables/variable-declaration-57.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-57.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-57.html)
- [variable-declaration-58.html](https://wpt.fyi/results/css/css-variables/variable-declaration-58.html "css/css-variables/variable-declaration-58.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-58.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-58.html)
- [variable-declaration-60.html](https://wpt.fyi/results/css/css-variables/variable-declaration-60.html "css/css-variables/variable-declaration-60.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-60.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-60.html)
- [variable-definition-keywords.html](https://wpt.fyi/results/css/css-variables/variable-definition-keywords.html "css/css-variables/variable-definition-keywords.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-definition-keywords.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-definition-keywords.html)
- [variable-css-wide-keywords.html](https://wpt.fyi/results/css/css-variables/variable-css-wide-keywords.html "css/css-variables/variable-css-wide-keywords.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-css-wide-keywords.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-css-wide-keywords.html)

 That is, they're interpreted at cascaded-value time as
normal, and are not preserved as the custom property's value, and thus
are not substituted in by the corresponding variable.

 While this module focuses on the use of [custom
properties](#custom-property)
with the [var()](#funcdef-var) function to create "variables", they can also be used
as actual custom properties, parsed by and acted on by script. It's
expected that the CSS Extensions spec
[\[CSS-EXTENSIONS\]](#biblio-css-extensions "CSS Extensions")
will expand on these use-cases and make them easier to do.

Custom properties are ordinary properties, so they can be declared on
any element, are resolved with the normal inheritance and cascade rules,
can be made conditional with
[\@media](https://drafts.csswg.org/css-conditional-3/#at-ruledef-media) and other conditional rules, can be used in
HTML's `style` attribute, can be read or set using the
CSSOM, etc.

Tests

- [css-vars-custom-property-inheritance.html](https://wpt.fyi/results/css/css-variables/css-vars-custom-property-inheritance.html "css/css-variables/css-vars-custom-property-inheritance.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/css-vars-custom-property-inheritance.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/css-vars-custom-property-inheritance.html)
- [variable-created-document.html](https://wpt.fyi/results/css/css-variables/variable-created-document.html "css/css-variables/variable-created-document.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-created-document.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-created-document.html)
- [variable-created-element.html](https://wpt.fyi/results/css/css-variables/variable-created-element.html "css/css-variables/variable-created-element.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-created-element.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-created-element.html)
- [variable-cssText.html](https://wpt.fyi/results/css/css-variables/variable-cssText.html "css/css-variables/variable-cssText.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-cssText.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-cssText.html)
- [variable-declaration-06.html](https://wpt.fyi/results/css/css-variables/variable-declaration-06.html "css/css-variables/variable-declaration-06.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-06.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-06.html)
- [variable-definition-cascading.html](https://wpt.fyi/results/css/css-variables/variable-definition-cascading.html "css/css-variables/variable-definition-cascading.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-definition-cascading.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-definition-cascading.html)
- [variable-external-declaration-01.html](https://wpt.fyi/results/css/css-variables/variable-external-declaration-01.html "css/css-variables/variable-external-declaration-01.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-external-declaration-01.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-external-declaration-01.html)
- [variable-external-reference-01.html](https://wpt.fyi/results/css/css-variables/variable-external-reference-01.html "css/css-variables/variable-external-reference-01.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-external-reference-01.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-external-reference-01.html)
- [variable-external-supports-01.html](https://wpt.fyi/results/css/css-variables/variable-external-supports-01.html "css/css-variables/variable-external-supports-01.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-external-supports-01.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-external-supports-01.html)
- [variable-first-letter.html](https://wpt.fyi/results/css/css-variables/variable-first-letter.html "css/css-variables/variable-first-letter.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-first-letter.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-first-letter.html)
- [variable-first-line.html](https://wpt.fyi/results/css/css-variables/variable-first-line.html "css/css-variables/variable-first-line.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-first-line.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-first-line.html)
- [variable-pseudo-element.html](https://wpt.fyi/results/css/css-variables/variable-pseudo-element.html "css/css-variables/variable-pseudo-element.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-pseudo-element.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-pseudo-element.html)
- [variable-reference-13.html](https://wpt.fyi/results/css/css-variables/variable-reference-13.html "css/css-variables/variable-reference-13.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-13.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-13.html)
- [variable-reference-14.html](https://wpt.fyi/results/css/css-variables/variable-reference-14.html "css/css-variables/variable-reference-14.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-14.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-14.html)
- [variable-reference-shorthands.html](https://wpt.fyi/results/css/css-variables/variable-reference-shorthands.html "css/css-variables/variable-reference-shorthands.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-shorthands.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-shorthands.html)
- [variable-reference-visited.html](https://wpt.fyi/results/css/css-variables/variable-reference-visited.html "css/css-variables/variable-reference-visited.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-visited.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-visited.html)

Notably, they can even be animated, but since the UA has no way to
interpret their contents, they always use the \"flips at 50%\" behavior
that is used for any other pair of values that can't be intelligently
interpolated. However, any [custom
property](#custom-property)
used in a
[\@keyframes](https://drafts.csswg.org/css-animations-1/#at-ruledef-keyframes) rule becomes
[animation-tainted], which affects how it is treated when referred to via the
[var()](#funcdef-var)
function in an animation property.

Tests

- [variable-animation-from-to.html](https://wpt.fyi/results/css/css-variables/variable-animation-from-to.html "css/css-variables/variable-animation-from-to.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-animation-from-to.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-animation-from-to.html)
- [variable-animation-over-transition.html](https://wpt.fyi/results/css/css-variables/variable-animation-over-transition.html "css/css-variables/variable-animation-over-transition.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-animation-over-transition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-animation-over-transition.html)
- [variable-animation-substitute-into-keyframe-shorthand.html](https://wpt.fyi/results/css/css-variables/variable-animation-substitute-into-keyframe-shorthand.html "css/css-variables/variable-animation-substitute-into-keyframe-shorthand.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-animation-substitute-into-keyframe-shorthand.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-animation-substitute-into-keyframe-shorthand.html)
- [variable-animation-substitute-into-keyframe-transform.html](https://wpt.fyi/results/css/css-variables/variable-animation-substitute-into-keyframe-transform.html "css/css-variables/variable-animation-substitute-into-keyframe-transform.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-animation-substitute-into-keyframe-transform.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-animation-substitute-into-keyframe-transform.html)
- [variable-animation-substitute-into-keyframe.html](https://wpt.fyi/results/css/css-variables/variable-animation-substitute-into-keyframe.html "css/css-variables/variable-animation-substitute-into-keyframe.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-animation-substitute-into-keyframe.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-animation-substitute-into-keyframe.html)
- [variable-animation-substitute-within-keyframe-fallback.html](https://wpt.fyi/results/css/css-variables/variable-animation-substitute-within-keyframe-fallback.html "css/css-variables/variable-animation-substitute-within-keyframe-fallback.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-animation-substitute-within-keyframe-fallback.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-animation-substitute-within-keyframe-fallback.html)
- [variable-animation-substitute-within-keyframe-multiple.html](https://wpt.fyi/results/css/css-variables/variable-animation-substitute-within-keyframe-multiple.html "css/css-variables/variable-animation-substitute-within-keyframe-multiple.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-animation-substitute-within-keyframe-multiple.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-animation-substitute-within-keyframe-multiple.html)
- [variable-animation-substitute-within-keyframe.html](https://wpt.fyi/results/css/css-variables/variable-animation-substitute-within-keyframe.html "css/css-variables/variable-animation-substitute-within-keyframe.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-animation-substitute-within-keyframe.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-animation-substitute-within-keyframe.html)
- [variable-animation-to-only.html](https://wpt.fyi/results/css/css-variables/variable-animation-to-only.html "css/css-variables/variable-animation-to-only.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-animation-to-only.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-animation-to-only.html)

 Like any other property that animates discretely,
custom properties can't be transitioned. [Registered custom
properties](https://drafts.css-houdini.org/css-properties-values-api-1/#registered-custom-property) can, however, if given a syntax that has non-discrete
animation behavior.

[Animation-tainted](#animation-tainted) is \"infectious\": custom properties which reference
[animation-tainted] properties also become
[animation-tainted].

This style rule:

``` highlight
:root {
 --header-color: #06c;
}
```

declares a [custom property](#custom-property) named [\--header-color] on the root element, and
assigns to it the value \"#06c\". This property is then inherited to the
elements in the rest of the document. Its value can be referenced with
the [var()](#funcdef-var)
function:

``` highlight
h1 { background-color: var(--header-color); }
```

The preceding rule is equivalent to writing [background-color:
#06c;](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-color), except that the variable name makes the
origin of the color clearer, and if [var(\--header-color)] is used
on other elements in the document, all of the uses can be updated at
once by changing the [\--header-color] property on the root
element.

If a [custom
property](#custom-property)
is declared multiple times, the standard cascade rules help resolve it.
Variables always draw from the computed value of the associated custom
property on the same element:

``` highlight
:root { --color: blue; }
div { --color: green; }
#alert { --color: red; }
* { color: var(--color); }

<p>I inherited blue from the root element!</p>
<div>I got green set directly on me!</div>
<div id='alert'>
 While I got red set directly on me!
 <p>I'm red too, because of inheritance!</p>
</div>
```

A real-world example of [custom
property](#custom-property)
usage is easily separating out strings from where they're used, to aid
in maintenance of internationalization:

```
:root,
:root:lang(en) {--external-link: "external link";}
:root:lang(el) {--external-link: "εξωτερικός σύνδεσμος";}

a[href^="http"]::after {content: " (" var(--external-link) ")"}
```

The variable declarations can even be kept in a separate file, to make
maintaining the translations simpler.

### 2.1. Custom Property Value Syntax

The allowed syntax for [custom
properties](#custom-property)
is extremely permissive. The
[\<declaration-value\>](https://drafts.csswg.org/css-syntax-3/#typedef-declaration-value) production matches *any* sequence of
one or more tokens, so long as the sequence does not contain
[\<bad-string-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-bad-string-token),
[\<bad-url-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-bad-url-token), unmatched
[\<)-token\>](https://drafts.csswg.org/css-syntax-3/#tokendef-close-paren),
[\<\]-token\>](https://drafts.csswg.org/css-syntax-3/#tokendef-close-square), or
[\<}-token\>](https://drafts.csswg.org/css-syntax-3/#tokendef-close-curly), or top-level
[\<semicolon-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-semicolon-token) tokens or
[\<delim-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-delim-token) tokens with a value of \"!\".

Tests

- [long-variable-reference-crash.html](https://wpt.fyi/results/css/css-variables/long-variable-reference-crash.html "css/css-variables/long-variable-reference-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/long-variable-reference-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/long-variable-reference-crash.html)
- [test_variable_legal_values.html](https://wpt.fyi/results/css/css-variables/test_variable_legal_values.html "css/css-variables/test_variable_legal_values.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/test_variable_legal_values.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/test_variable_legal_values.html)
- [variable-declaration-15.html](https://wpt.fyi/results/css/css-variables/variable-declaration-15.html "css/css-variables/variable-declaration-15.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-15.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-15.html)
- [variable-declaration-24.html](https://wpt.fyi/results/css/css-variables/variable-declaration-24.html "css/css-variables/variable-declaration-24.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-24.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-24.html)
- [variable-declaration-25.html](https://wpt.fyi/results/css/css-variables/variable-declaration-25.html "css/css-variables/variable-declaration-25.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-25.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-25.html)
- [variable-declaration-26.html](https://wpt.fyi/results/css/css-variables/variable-declaration-26.html "css/css-variables/variable-declaration-26.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-26.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-26.html)
- [variable-declaration-59.html](https://wpt.fyi/results/css/css-variables/variable-declaration-59.html "css/css-variables/variable-declaration-59.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-59.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-59.html)

In addition, if the value of a [custom
property](#custom-property)
contains a [var()](#funcdef-var) reference, the [var()]
reference must be valid according to the specified
[var()] grammar. If not, the [custom
property] is invalid and must be ignored.

 This definition, along with the general CSS syntax
rules, implies that a custom property value never includes an unmatched
quote or bracket, and so cannot have any effect on larger syntax
constructs, like the enclosing style rule, when reserialized.

 Custom properties can contain a trailing
[!important], but this is automatically removed from the
property's value by the CSS parser, and makes the custom property
\"important\" in the CSS cascade. In other words, the prohibition on
top-level \"!\" characters does not prevent [!important] from
being used, as the [!important] is removed before syntax checking
happens.

Tests

- [variable-declaration-20.html](https://wpt.fyi/results/css/css-variables/variable-declaration-20.html "css/css-variables/variable-declaration-20.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-20.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-20.html)
- [variable-declaration-23.html](https://wpt.fyi/results/css/css-variables/variable-declaration-23.html "css/css-variables/variable-declaration-23.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-23.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-23.html)

For example, the following is a valid
custom property:

``` highlight
--foo: if(x > 5) this.width = 10;
```

While this value is obviously useless as a *variable*, as it would be
invalid in any normal property, it might be read and acted on by
JavaScript.

The values of custom properties, and the values of
[var()](#funcdef-var)
functions substituted into custom properties, are *case-sensitive*, and
must be preserved in their original author-given casing. (Many CSS
values are [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive), which user agents can take advantage of by
\"canonicalizing\" them into a single casing, but that isn't allowed for
custom properties.)

Tests

- [variable-declaration-38.html](https://wpt.fyi/results/css/css-variables/variable-declaration-38.html "css/css-variables/variable-declaration-38.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-38.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-38.html)
- [variable-declaration-39.html](https://wpt.fyi/results/css/css-variables/variable-declaration-39.html "css/css-variables/variable-declaration-39.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-39.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-39.html)

Because custom properties can contain *anything*, there is no general
way to know how to interpret what's inside of them (until they're
substituted into a known property with
[var()](#funcdef-var)).
Rather than have them *partially* resolve in some cases but not others,
they're left completely unresolved; they're a bare stream of [CSS
tokens](https://drafts.csswg.org/css-syntax-3/#tokenization)
interspersed with [var()] functions.

This has some knock-on implications. For example, relative URLs in CSS
are resolved against the base URL of the stylesheet the value appears
in. However, if a custom property like [\--my-image: url(foo.jpg);] shows up in an `"/a/style.css"`
stylesheet, it will not resolve into an absolute URL immediately; if
that variable is later used in a *different*
`"/b/style.css"` stylesheet like [background:
var(\--my-image);](https://drafts.csswg.org/css-backgrounds-3/#propdef-background), it will resolve *at that point* to
`"/b/foo.jpg"`.

### 2.2. Guaranteed-Invalid Values

The initial value of a [custom
property](#custom-property)
is a [guaranteed-invalid value].

The [guaranteed-invalid
value](#guaranteed-invalid-value) is, well, guaranteed to be invalid. If it ever appears
in a property value, then at [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) time that property becomes [invalid at computed-value
time](https://drafts.csswg.org/css-values-5/#invalid-at-computed-value-time).

Non-property contexts will define their own behavior for the
[guaranteed-invalid
value](#guaranteed-invalid-value), but it will always be \"invalid\" in some sense.

The [guaranteed-invalid
value](#guaranteed-invalid-value) serializes as the empty string, but actually writing an
empty value into a custom property, like
[[\--foo:;]]{style=";white-space:nowrap"}, is a valid (empty)
value, not the [guaranteed-invalid
value]. If, for whatever reason, one
wants to manually reset a [custom
property](#custom-property)
to the [guaranteed-invalid value],
using the keyword
[initial](https://drafts.csswg.org/css-cascade-5/#valdef-all-initial) will do this.

 Other than invoking the [initial
value](https://drafts.csswg.org/css-cascade-5/#initial-value) of a non-registered [custom
property](#custom-property),
the only way to create the [guaranteed-invalid
value](#guaranteed-invalid-value) is by having an invalid [arbitrary substitution
function](https://drafts.csswg.org/css-values-5/#arbitrary-substitution-function).

## 3. Using Cascading Variables: the [var() notation]
The value of a [custom
property](#custom-property)
can be substituted into the value of another property with the
[var()](#funcdef-var)
function. The syntax of [var()] is:

```
var() = var( <custom-property-name> , <declaration-value>? )
```

The [var()](#funcdef-var)
function is an [arbitrary substitution
function](https://drafts.csswg.org/css-values-5/#arbitrary-substitution-function), and its [argument
grammar](https://drafts.csswg.org/css-values-5/#argument-grammar) is:

```
<var-args> = var( <declaration-value> , <declaration-value>? )
```

Tests

- [variable-reference-07.html](https://wpt.fyi/results/css/css-variables/variable-reference-07.html "css/css-variables/variable-reference-07.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-07.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-07.html)
- [variable-reference-08.html](https://wpt.fyi/results/css/css-variables/variable-reference-08.html "css/css-variables/variable-reference-08.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-08.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-08.html)
- [variable-reference-09.html](https://wpt.fyi/results/css/css-variables/variable-reference-09.html "css/css-variables/variable-reference-09.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-09.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-09.html)
- [variable-reference-10.html](https://wpt.fyi/results/css/css-variables/variable-reference-10.html "css/css-variables/variable-reference-10.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-10.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-10.html)
- [variable-reference-17.html](https://wpt.fyi/results/css/css-variables/variable-reference-17.html "css/css-variables/variable-reference-17.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-17.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-17.html)
- [variable-reference-20.html](https://wpt.fyi/results/css/css-variables/variable-reference-20.html "css/css-variables/variable-reference-20.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-20.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-20.html)
- [variable-reference-21.html](https://wpt.fyi/results/css/css-variables/variable-reference-21.html "css/css-variables/variable-reference-21.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-21.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-21.html)
- [variable-reference-22.html](https://wpt.fyi/results/css/css-variables/variable-reference-22.html "css/css-variables/variable-reference-22.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-22.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-22.html)
- [variable-reference-23.html](https://wpt.fyi/results/css/css-variables/variable-reference-23.html "css/css-variables/variable-reference-23.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-23.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-23.html)
- [variable-reference-24.html](https://wpt.fyi/results/css/css-variables/variable-reference-24.html "css/css-variables/variable-reference-24.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-24.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-24.html)
- [variable-reference-25.html](https://wpt.fyi/results/css/css-variables/variable-reference-25.html "css/css-variables/variable-reference-25.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-25.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-25.html)
- [variable-reference-28.html](https://wpt.fyi/results/css/css-variables/variable-reference-28.html "css/css-variables/variable-reference-28.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-28.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-28.html)
- [variable-reference-29.html](https://wpt.fyi/results/css/css-variables/variable-reference-29.html "css/css-variables/variable-reference-29.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-29.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-29.html)
- [variable-reference-31.html](https://wpt.fyi/results/css/css-variables/variable-reference-31.html "css/css-variables/variable-reference-31.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-31.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-31.html)
- [variable-reference-32.html](https://wpt.fyi/results/css/css-variables/variable-reference-32.html "css/css-variables/variable-reference-32.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-32.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-32.html)
- [variable-reference-33.html](https://wpt.fyi/results/css/css-variables/variable-reference-33.html "css/css-variables/variable-reference-33.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-33.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-33.html)
- [variable-reference-34.html](https://wpt.fyi/results/css/css-variables/variable-reference-34.html "css/css-variables/variable-reference-34.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-34.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-34.html)
- [variable-reference-35.html](https://wpt.fyi/results/css/css-variables/variable-reference-35.html "css/css-variables/variable-reference-35.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-35.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-35.html)
- [variable-reference.html](https://wpt.fyi/results/css/css-variables/variable-reference.html "css/css-variables/variable-reference.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference.html)

\@supports

- [variable-supports-01.html](https://wpt.fyi/results/css/css-variables/variable-supports-01.html "css/css-variables/variable-supports-01.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-01.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-01.html)
- [variable-supports-02.html](https://wpt.fyi/results/css/css-variables/variable-supports-02.html "css/css-variables/variable-supports-02.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-02.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-02.html)
- [variable-supports-03.html](https://wpt.fyi/results/css/css-variables/variable-supports-03.html "css/css-variables/variable-supports-03.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-03.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-03.html)
- [variable-supports-04.html](https://wpt.fyi/results/css/css-variables/variable-supports-04.html "css/css-variables/variable-supports-04.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-04.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-04.html)
- [variable-supports-05.html](https://wpt.fyi/results/css/css-variables/variable-supports-05.html "css/css-variables/variable-supports-05.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-05.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-05.html)
- [variable-supports-06.html](https://wpt.fyi/results/css/css-variables/variable-supports-06.html "css/css-variables/variable-supports-06.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-06.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-06.html)
- [variable-supports-07.html](https://wpt.fyi/results/css/css-variables/variable-supports-07.html "css/css-variables/variable-supports-07.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-07.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-07.html)
- [variable-supports-08.html](https://wpt.fyi/results/css/css-variables/variable-supports-08.html "css/css-variables/variable-supports-08.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-08.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-08.html)
- [variable-supports-09.html](https://wpt.fyi/results/css/css-variables/variable-supports-09.html "css/css-variables/variable-supports-09.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-09.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-09.html)
- [variable-supports-10.html](https://wpt.fyi/results/css/css-variables/variable-supports-10.html "css/css-variables/variable-supports-10.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-10.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-10.html)
- [variable-supports-11.html](https://wpt.fyi/results/css/css-variables/variable-supports-11.html "css/css-variables/variable-supports-11.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-11.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-11.html)
- [variable-supports-12.html](https://wpt.fyi/results/css/css-variables/variable-supports-12.html "css/css-variables/variable-supports-12.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-12.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-12.html)
- [variable-supports-13.html](https://wpt.fyi/results/css/css-variables/variable-supports-13.html "css/css-variables/variable-supports-13.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-13.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-13.html)
- [variable-supports-14.html](https://wpt.fyi/results/css/css-variables/variable-supports-14.html "css/css-variables/variable-supports-14.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-14.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-14.html)
- [variable-supports-15.html](https://wpt.fyi/results/css/css-variables/variable-supports-15.html "css/css-variables/variable-supports-15.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-15.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-15.html)
- [variable-supports-16.html](https://wpt.fyi/results/css/css-variables/variable-supports-16.html "css/css-variables/variable-supports-16.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-16.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-16.html)
- [variable-supports-17.html](https://wpt.fyi/results/css/css-variables/variable-supports-17.html "css/css-variables/variable-supports-17.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-17.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-17.html)
- [variable-supports-18.html](https://wpt.fyi/results/css/css-variables/variable-supports-18.html "css/css-variables/variable-supports-18.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-18.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-18.html)
- [variable-supports-19.html](https://wpt.fyi/results/css/css-variables/variable-supports-19.html "css/css-variables/variable-supports-19.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-19.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-19.html)
- [variable-supports-20.html](https://wpt.fyi/results/css/css-variables/variable-supports-20.html "css/css-variables/variable-supports-20.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-20.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-20.html)
- [variable-supports-21.html](https://wpt.fyi/results/css/css-variables/variable-supports-21.html "css/css-variables/variable-supports-21.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-21.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-21.html)
- [variable-supports-22.html](https://wpt.fyi/results/css/css-variables/variable-supports-22.html "css/css-variables/variable-supports-22.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-22.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-22.html)
- [variable-supports-23.html](https://wpt.fyi/results/css/css-variables/variable-supports-23.html "css/css-variables/variable-supports-23.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-23.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-23.html)
- [variable-supports-24.html](https://wpt.fyi/results/css/css-variables/variable-supports-24.html "css/css-variables/variable-supports-24.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-24.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-24.html)
- [variable-supports-25.html](https://wpt.fyi/results/css/css-variables/variable-supports-25.html "css/css-variables/variable-supports-25.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-25.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-25.html)
- [variable-supports-26.html](https://wpt.fyi/results/css/css-variables/variable-supports-26.html "css/css-variables/variable-supports-26.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-26.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-26.html)
- [variable-supports-27.html](https://wpt.fyi/results/css/css-variables/variable-supports-27.html "css/css-variables/variable-supports-27.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-27.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-27.html)
- [variable-supports-28.html](https://wpt.fyi/results/css/css-variables/variable-supports-28.html "css/css-variables/variable-supports-28.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-28.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-28.html)
- [variable-supports-29.html](https://wpt.fyi/results/css/css-variables/variable-supports-29.html "css/css-variables/variable-supports-29.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-29.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-29.html)
- [variable-supports-30.html](https://wpt.fyi/results/css/css-variables/variable-supports-30.html "css/css-variables/variable-supports-30.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-30.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-30.html)
- [variable-supports-31.html](https://wpt.fyi/results/css/css-variables/variable-supports-31.html "css/css-variables/variable-supports-31.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-31.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-31.html)
- [variable-supports-32.html](https://wpt.fyi/results/css/css-variables/variable-supports-32.html "css/css-variables/variable-supports-32.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-32.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-32.html)
- [variable-supports-33.html](https://wpt.fyi/results/css/css-variables/variable-supports-33.html "css/css-variables/variable-supports-33.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-33.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-33.html)
- [variable-supports-34.html](https://wpt.fyi/results/css/css-variables/variable-supports-34.html "css/css-variables/variable-supports-34.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-34.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-34.html)
- [variable-supports-35.html](https://wpt.fyi/results/css/css-variables/variable-supports-35.html "css/css-variables/variable-supports-35.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-35.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-35.html)
- [variable-supports-36.html](https://wpt.fyi/results/css/css-variables/variable-supports-36.html "css/css-variables/variable-supports-36.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-36.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-36.html)
- [variable-supports-37.html](https://wpt.fyi/results/css/css-variables/variable-supports-37.html "css/css-variables/variable-supports-37.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-37.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-37.html)
- [variable-supports-38.html](https://wpt.fyi/results/css/css-variables/variable-supports-38.html "css/css-variables/variable-supports-38.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-38.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-38.html)
- [variable-supports-39.html](https://wpt.fyi/results/css/css-variables/variable-supports-39.html "css/css-variables/variable-supports-39.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-39.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-39.html)
- [variable-supports-40.html](https://wpt.fyi/results/css/css-variables/variable-supports-40.html "css/css-variables/variable-supports-40.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-40.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-40.html)
- [variable-supports-41.html](https://wpt.fyi/results/css/css-variables/variable-supports-41.html "css/css-variables/variable-supports-41.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-41.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-41.html)
- [variable-supports-42.html](https://wpt.fyi/results/css/css-variables/variable-supports-42.html "css/css-variables/variable-supports-42.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-42.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-42.html)
- [variable-supports-43.html](https://wpt.fyi/results/css/css-variables/variable-supports-43.html "css/css-variables/variable-supports-43.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-43.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-43.html)
- [variable-supports-44.html](https://wpt.fyi/results/css/css-variables/variable-supports-44.html "css/css-variables/variable-supports-44.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-44.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-44.html)
- [variable-supports-45.html](https://wpt.fyi/results/css/css-variables/variable-supports-45.html "css/css-variables/variable-supports-45.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-45.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-45.html)
- [variable-supports-46.html](https://wpt.fyi/results/css/css-variables/variable-supports-46.html "css/css-variables/variable-supports-46.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-46.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-46.html)
- [variable-supports-47.html](https://wpt.fyi/results/css/css-variables/variable-supports-47.html "css/css-variables/variable-supports-47.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-47.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-47.html)
- [variable-supports-48.html](https://wpt.fyi/results/css/css-variables/variable-supports-48.html "css/css-variables/variable-supports-48.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-48.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-48.html)
- [variable-supports-49.html](https://wpt.fyi/results/css/css-variables/variable-supports-49.html "css/css-variables/variable-supports-49.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-49.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-49.html)
- [variable-supports-50.html](https://wpt.fyi/results/css/css-variables/variable-supports-50.html "css/css-variables/variable-supports-50.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-50.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-50.html)
- [variable-supports-51.html](https://wpt.fyi/results/css/css-variables/variable-supports-51.html "css/css-variables/variable-supports-51.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-51.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-51.html)
- [variable-supports-52.html](https://wpt.fyi/results/css/css-variables/variable-supports-52.html "css/css-variables/variable-supports-52.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-52.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-52.html)
- [variable-supports-53.html](https://wpt.fyi/results/css/css-variables/variable-supports-53.html "css/css-variables/variable-supports-53.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-53.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-53.html)
- [variable-supports-54.html](https://wpt.fyi/results/css/css-variables/variable-supports-54.html "css/css-variables/variable-supports-54.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-54.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-54.html)
- [variable-supports-55.html](https://wpt.fyi/results/css/css-variables/variable-supports-55.html "css/css-variables/variable-supports-55.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-55.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-55.html)
- [variable-supports-56.html](https://wpt.fyi/results/css/css-variables/variable-supports-56.html "css/css-variables/variable-supports-56.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-56.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-56.html)
- [variable-supports-57.html](https://wpt.fyi/results/css/css-variables/variable-supports-57.html "css/css-variables/variable-supports-57.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-57.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-57.html)
- [variable-supports-58.html](https://wpt.fyi/results/css/css-variables/variable-supports-58.html "css/css-variables/variable-supports-58.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-58.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-58.html)
- [variable-supports-59.html](https://wpt.fyi/results/css/css-variables/variable-supports-59.html "css/css-variables/variable-supports-59.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-59.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-59.html)
- [variable-supports-60.html](https://wpt.fyi/results/css/css-variables/variable-supports-60.html "css/css-variables/variable-supports-60.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-60.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-60.html)
- [variable-supports-61.html](https://wpt.fyi/results/css/css-variables/variable-supports-61.html "css/css-variables/variable-supports-61.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-61.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-61.html)
- [variable-supports-62.html](https://wpt.fyi/results/css/css-variables/variable-supports-62.html "css/css-variables/variable-supports-62.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-62.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-62.html)
- [variable-supports-63.html](https://wpt.fyi/results/css/css-variables/variable-supports-63.html "css/css-variables/variable-supports-63.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-63.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-63.html)
- [variable-supports-64.html](https://wpt.fyi/results/css/css-variables/variable-supports-64.html "css/css-variables/variable-supports-64.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-64.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-64.html)
- [variable-supports-65.html](https://wpt.fyi/results/css/css-variables/variable-supports-65.html "css/css-variables/variable-supports-65.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-65.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-65.html)
- [variable-supports-66.html](https://wpt.fyi/results/css/css-variables/variable-supports-66.html "css/css-variables/variable-supports-66.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-66.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-66.html)
- [variable-supports-67.html](https://wpt.fyi/results/css/css-variables/variable-supports-67.html "css/css-variables/variable-supports-67.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-supports-67.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-supports-67.html)

------------------------------------------------------------------------

The first argument to the function is the name of the [custom
property](#custom-property)
to be substituted. The second argument to the function, if provided, is
a fallback value, which is used as the substitution value when the value
of the referenced [custom property] is the
[guaranteed-invalid
value](#guaranteed-invalid-value).

Tests

- [variable-declaration-08.html](https://wpt.fyi/results/css/css-variables/variable-declaration-08.html "css/css-variables/variable-declaration-08.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-08.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-08.html)
- [variable-declaration-09.html](https://wpt.fyi/results/css/css-variables/variable-declaration-09.html "css/css-variables/variable-declaration-09.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-09.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-09.html)
- [variable-declaration-10.html](https://wpt.fyi/results/css/css-variables/variable-declaration-10.html "css/css-variables/variable-declaration-10.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-10.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-10.html)
- [variable-declaration-11.html](https://wpt.fyi/results/css/css-variables/variable-declaration-11.html "css/css-variables/variable-declaration-11.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-11.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-11.html)
- [variable-declaration-12.html](https://wpt.fyi/results/css/css-variables/variable-declaration-12.html "css/css-variables/variable-declaration-12.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-12.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-12.html)
- [variable-declaration-13.html](https://wpt.fyi/results/css/css-variables/variable-declaration-13.html "css/css-variables/variable-declaration-13.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-13.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-13.html)
- [variable-declaration-22.html](https://wpt.fyi/results/css/css-variables/variable-declaration-22.html "css/css-variables/variable-declaration-22.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-22.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-22.html)

In an exception to the usual [comma elision
rules](https://drafts.csswg.org/css-values-4/#comb-comma), which require commas to be omitted when they're
not separating values, a bare comma, with nothing following it, must be
treated as valid in [var()](#funcdef-var), indicating an empty fallback value.

Tests

- [variable-declaration-07.html](https://wpt.fyi/results/css/css-variables/variable-declaration-07.html "css/css-variables/variable-declaration-07.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-07.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-07.html)
- [variable-declaration-37.html](https://wpt.fyi/results/css/css-variables/variable-declaration-37.html "css/css-variables/variable-declaration-37.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-37.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-37.html)
- [variable-reference-06.html](https://wpt.fyi/results/css/css-variables/variable-reference-06.html "css/css-variables/variable-reference-06.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-06.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-06.html)
- [variable-reference-11.html](https://wpt.fyi/results/css/css-variables/variable-reference-11.html "css/css-variables/variable-reference-11.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-11.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-11.html)
- [variable-reference-26.html](https://wpt.fyi/results/css/css-variables/variable-reference-26.html "css/css-variables/variable-reference-26.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-26.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-26.html)
- [variable-reference-27.html](https://wpt.fyi/results/css/css-variables/variable-reference-27.html "css/css-variables/variable-reference-27.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-27.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-27.html)

 That is, [var(\--a,)] is a valid function,
specifying that if the [\--a] custom property is invalid or
missing, the [var()](#funcdef-var) should be replaced with nothing.

 The syntax of the fallback, like that of [custom
properties](#custom-property), allows commas. For example, [var(\--foo, red,
blue)] defines a fallback of [red, blue]; that is, anything
between the first comma and the end of the function is considered a
fallback value.

The fallback value allows for some
types of defensive coding. For example, an author may create a component
intended to be included in a larger application, and use variables to
style it so that it's easy for the author of the larger application to
theme the component to match the rest of the app.

Without fallback, the app author must supply a value for every variable
that your component uses. With fallback, the component author can supply
defaults, so the app author only needs to supply values for the
variables they wish to override.

``` highlight
/* In the component's style: */
.component .header {
 color: var(--header-color, blue);
}
.component .text {
 color: var(--text-color, black);
}

/* In the larger application's style: */
.component {
 --text-color: #080;
 /* header-color isn't set,
 and so remains blue,
 the fallback value */
}
```

To [[replace a var()
function](https://drafts.csswg.org/css-values-5/#replace-an-arbitrary-substitution-function)], given a list of `arguments`:

1. Let `el` be the element that the style containing the
 [var()](#funcdef-var)
 function is being applied to. Let `first arg` be the
 first
 [\<declaration-value\>](https://drafts.csswg.org/css-syntax-3/#typedef-declaration-value) in `arguments`. Let
 `second arg` be the
 [\<declaration-value\>]? passed after the comma, or null if there was no comma.

2. [Substitute arbitrary substitution
 functions](https://drafts.csswg.org/css-values-5/#substitute-arbitrary-substitution-function) in `first arg`, then
 [parse](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) it as a
 [\<custom-property-name\>](#typedef-custom-property-name). If parsing returned a
 [\<custom-property-name\>], let `result` be the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) of the corresponding [custom
 property](#custom-property) on `el`. Otherwise, let
 `result` be the [guaranteed-invalid
 value](#guaranteed-invalid-value).

 Determining the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) for the [custom
 property](#custom-property) implies that [property
 replacement](https://drafts.csswg.org/css-values-5/#property-replacement) takes place, which may cause a
 [cycle](https://drafts.csswg.org/css-values-5/#cyclic-substitution-contexts).

3. If the [custom
 property](#custom-property) named by the
 [var()](#funcdef-var)'s first argument is
 [animation-tainted](#animation-tainted), and the [var()] is
 being used in a property that is [not
 animatable](https://drafts.csswg.org/web-animations-1/#not-animatable), set `result` to the [guaranteed-invalid
 value](#guaranteed-invalid-value).

4. If `result` contains the [guaranteed-invalid
 value](#guaranteed-invalid-value), and `second arg` was provided, set
 `result` to the result of [substitute arbitrary
 substitution
 functions](https://drafts.csswg.org/css-values-5/#substitute-arbitrary-substitution-function) on `second arg`.

5. Return `result`.

Due to [property
replacement](https://drafts.csswg.org/css-values-5/#property-replacement), [custom
properties](#custom-property) can form
[cycles](https://drafts.csswg.org/css-values-5/#cyclic-substitution-contexts):

``` highlight
:root {
 --one: calc(var(--two) + 20px);
 --two: calc(var(--one) - 20px);
}
```

In the above, both [\--one] and [\--two] compute to the
[guaranteed-invalid
value](#guaranteed-invalid-value), since their [substitution
contexts](https://drafts.csswg.org/css-values-5/#substitution-context) have been marked as
[cyclic].

- [variable-cycles.html](https://wpt.fyi/results/css/css-variables/variable-cycles.html "css/css-variables/variable-cycles.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-cycles.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-cycles.html)
- [variable-declaration-30.html](https://wpt.fyi/results/css/css-variables/variable-declaration-30.html "css/css-variables/variable-declaration-30.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-30.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-30.html)
- [variable-declaration-48.html](https://wpt.fyi/results/css/css-variables/variable-declaration-48.html "css/css-variables/variable-declaration-48.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-48.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-48.html)
- [variable-declaration-49.html](https://wpt.fyi/results/css/css-variables/variable-declaration-49.html "css/css-variables/variable-declaration-49.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-49.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-49.html)
- [variable-declaration-50.html](https://wpt.fyi/results/css/css-variables/variable-declaration-50.html "css/css-variables/variable-declaration-50.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-50.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-50.html)
- [variable-reference-39.html](https://wpt.fyi/results/css/css-variables/variable-reference-39.html "css/css-variables/variable-reference-39.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-39.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-39.html)

Note that the [custom
property](#custom-property)
name looked up by a [var()](#funcdef-var) may itself come from a [var()] function:

``` highlight
:root {
 --other: 10px;
 --myvar: --other;
 --result: var(var(--myvar));
}
```

Since the inner [var()] is resolved before
the outer [var()], the computed value of
[\--result] becomes 10px.

## 4. APIs

All [custom property](#custom-property)
[declarations](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-declarations) have the [case-sensitive
flag](https://drafts.csswg.org/cssom-1/#css-declaration-case-sensitive-flag) set.

Tests

- [variable-definition.html](https://wpt.fyi/results/css/css-variables/variable-definition.html "css/css-variables/variable-definition.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-definition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-definition.html)
- [variable-invalidation.html](https://wpt.fyi/results/css/css-variables/variable-invalidation.html "css/css-variables/variable-invalidation.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-invalidation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-invalidation.html)

 Custom properties do not appear on a
CSSStyleDeclaration object in camel-cased form, because their names may
have both upper and lowercase letters which indicate distinct custom
properties. The sort of text transformation that automatic camel-casing
performs is incompatible with this. They can still be accessed by their
proper name via
[getPropertyValue()](https://drafts.csswg.org/cssom-1/#dom-cssstyledeclaration-getpropertyvalue)/etc.

### 4.1. Serializing Custom Properties

Custom property names must be serialized as the exact code point
sequence provided by the author, including not altering the case.

 For non-custom properties, property names are
restricted to the ASCII range and are [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive), so implementations typically serialize the name
lowercased.

Specified values of [custom
properties](#custom-property) must be serialized *exactly as specified by the author*
(with one exception, below). Simplifications that might occur in other
properties, such as dropping comments, normalizing whitespace,
reserializing numeric tokens from their value, etc., must not occur.

Computed values of [custom
properties](#custom-property) must similarly be serialized *exactly as specified by
the author* (with the same one exception, below), save for the
replacement of any [var()](#funcdef-var) functions.

The one exception to serialization being precisely as specified in the
source file is that an *empty* custom property (such as
[\--foo:;]) must serialize with a single space as its value.

Tests

- [variable-reference-shorthands-cssom.html](https://wpt.fyi/results/css/css-variables/variable-reference-shorthands-cssom.html "css/css-variables/variable-reference-shorthands-cssom.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-shorthands-cssom.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-shorthands-cssom.html)
- [variable-reference-variable.html](https://wpt.fyi/results/css/css-variables/variable-reference-variable.html "css/css-variables/variable-reference-variable.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-variable.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-variable.html)

For example, given the following
properties:

``` highlight
--y: /* baz */;
--x: /* foo */ var(--y) /* bar */;
```

the serialization of the specified value of [\--x] must be
`"/* foo */ var(--y) /* bar */"`, while the serialization of
the computed value of [\--x] must be
`"/* foo */ /* baz */ /* bar */"`.

(Note that the leading whitespace on the value is automatically trimmed
by the CSS parser; it's not preserved here.)

This \"exactly as specified\" requirement exists because authors
sometimes store non-CSS information in custom properties, and
\"normalizing\" this information can change it in ways that break author
code.

For example, storing a UUID in a custom property, like [\--uuid:
12345678-12e3-8d9b-a456-426614174000],
requires the UUID to be echoed back out as written when it's accessed by
script.

This value is technically parsed by CSS as a series of adjacent numbers
and dimensions. In particular, the segment \"-12e3\" parses as a number,
equal to -12000. Reserializing it in that form, as required by CSSOM in
other contexts, would fatally break the author's use of the value.

The requirement to serialize an empty custom property as a string with a
single space in it instead is due to compatibility with the existing
CSSOM API.
[`setProperty()`](https://drafts.csswg.org/cssom-1/#dom-cssstyledeclaration-setproperty) specifies that if the passed value is an empty string
it instead acts as
[`removeProperty()`](https://drafts.csswg.org/cssom-1/#dom-cssstyledeclaration-removeproperty).

This is a frankly weird behavior, and not something we would do in new
APIs. But we can't change the past, and letting empty properties
accurately serialize as the empty string would mean that round-tripping
a custom property value, or reading a property on one element and
setting a property on another element to the same value, wouldn't work
as intended. Using a single space preserves the author-intended behavior
as much as possible, while having the smallest chance of accidentally
breaking things, since authors working with custom property values in JS
are probably calling
[`trim()`](https://tc39.es/ecma262/multipage/text-processing.html#sec-string.prototype.trim) on the values anyway.

## 5. Changes

### 5.1. Changes Since the 16 June 2022 CR Snapshot

- Clarified that the comment-insertion can happen with 0+ comments
 between the original tokens, not just exactly 1.

- Clarified the transition behavior of custom properties, in a note

- Made [var()](#funcdef-var) short-circuiting. ([Issue
 11500](https://github.com/w3c/csswg-drafts/issues/11500))

### 5.2. Changes Since the 11 November 2021 CR Draft

- Clarified that custom properties apply all pseudo-elements (including
 those with restricted property lists)

- Added example to illustrate issues with combining characters,
 ligatures, etc

- Strengthened wording around similar-appearing variable names that use
 distinct codepoint sequences

- Clarified an example by using more visually distinct languages as
 examples (English and Greek)

- Split Security and Privacy into separate sections

### 5.3. Changes Since the 03 December 2015 CR

- Now that
 [\[css-syntax-3\]](#biblio-css-syntax-3 "CSS Syntax Module Level 3")
 auto-trims whitespace from declaration values, made
 [\<declaration-value\>](https://drafts.csswg.org/css-syntax-3/#typedef-declaration-value) optional in the custom property
 grammar, so that empty variables are still allowed. ([Issue
 774](https://github.com/w3c/csswg-drafts/issues/774#issuecomment-434571254))

- Similarly, made empty fallbacks valid in
 [var()](#funcdef-var).

- The [\--] property is reserved for future use by CSS.

- Added concept of \"animation-tainted\", to prevent non-animatable
 properties from using a variable to smuggle in some animatability.

- Defined the [guaranteed-invalid
 value](#guaranteed-invalid-value) to make the initial value of custom properties and
 the result of cycles or substitution failure more straightforward, and
 allow failure to propagate thru substitutions until finally
 intercepted by a fallback.

- Defined that cycles trigger [invalid at computed-value
 time](https://drafts.csswg.org/css-values-5/#invalid-at-computed-value-time) behavior.

- Allowed variables to resolve to a CSS-wide keyword (only possible by
 providing it as a fallback).

- Clarified that [registered custom
 properties](https://drafts.css-houdini.org/css-properties-values-api-1/#registered-custom-property) act like non-custom properties when they're [invalid
 at computed-value
 time](https://drafts.csswg.org/css-values-5/#invalid-at-computed-value-time).

- Made longhands with [var()](#funcdef-var)s also trigger their shorthands to be
 unserializable, like longhands with pending-substitution values
 already did.

- Required UAs to defend against exponential substitution attacks.

- Defined how to serialize the *values* of custom properties
 (previously, only the property name's serialization was specified).

### 5.4. Changes since the May 6 2014 Last Call Working Draft

- Serialization of longhands when shorthand uses a variable was defined.

- Link to DOM's definition of \"case-sensitive\".

- Added example of using variables with
 [:lang()](https://drafts.csswg.org/selectors-4/#lang-pseudo) to do simple i18n.

- Clarified that usage of [var()](#funcdef-var) in a custom property must be valid per the
 [var()] grammar.

## 6. Acknowledgments

Many thanks to several people in the CSS Working Group for keeping the
dream of variables alive over the years, particularly Daniel Glazman and
David Hyatt. Thanks to multiple people on the mailing list for helping
contribute to the development of this incarnation of variables,
particularly Brian Kardell, David Baron, François Remy, Roland Steiner,
and Shane Stephens.

## 7. Privacy Considerations

This specification defines a purely author-level mechanism for passing
styling information around within a page they control. As such, there
are no new privacy considerations.

## 8. Security Considerations

[CSS Values 5 §  Safely Handling Overly-Long
Substitution](https://drafts.csswg.org/css-values-5/#long-substitution)
calls out a long-standing Denial-of-Service attack that can be mounted
against \"macro-expansion\"-like mechanisms, such as the
[var()](#funcdef-var)
function, and mandates a defense against that attack.

Tests

- [revert-in-fallback.html](https://wpt.fyi/results/css/css-variables/revert-in-fallback.html "css/css-variables/revert-in-fallback.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/revert-in-fallback.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/revert-in-fallback.html)
- [revert-layer-in-fallback.html](https://wpt.fyi/results/css/css-variables/revert-layer-in-fallback.html "css/css-variables/revert-layer-in-fallback.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/revert-layer-in-fallback.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/revert-layer-in-fallback.html)
- [variables-animation-math-functions.html](https://wpt.fyi/results/css/css-variables/variables-animation-math-functions.html "css/css-variables/variables-animation-math-functions.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variables-animation-math-functions.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variables-animation-math-functions.html)
- [variable-recalc-with-initial.html](https://wpt.fyi/results/css/css-variables/variable-recalc-with-initial.html "css/css-variables/variable-recalc-with-initial.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-recalc-with-initial.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-recalc-with-initial.html)

Tests

- [missing-closing-nested-fallback-crash.html](https://wpt.fyi/results/css/css-variables/missing-closing-nested-fallback-crash.html "css/css-variables/missing-closing-nested-fallback-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/missing-closing-nested-fallback-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/missing-closing-nested-fallback-crash.html)
- [url-syntax-crash.html](https://wpt.fyi/results/css/css-variables/url-syntax-crash.html "css/css-variables/url-syntax-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/url-syntax-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/url-syntax-crash.html)
- [whitespace-in-fallback-crash.html](https://wpt.fyi/results/css/css-variables/whitespace-in-fallback-crash.html "css/css-variables/whitespace-in-fallback-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/whitespace-in-fallback-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/whitespace-in-fallback-crash.html)
- [registered-property-light-dark.html](https://wpt.fyi/results/css/css-variables/registered-property-light-dark.html "css/css-variables/registered-property-light-dark.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/registered-property-light-dark.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/registered-property-light-dark.html)
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
- [variable-declaration-14.html](https://wpt.fyi/results/css/css-variables/variable-declaration-14.html "css/css-variables/variable-declaration-14.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-14.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-14.html)
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
- [variable-declaration-51.html](https://wpt.fyi/results/css/css-variables/variable-declaration-51.html "css/css-variables/variable-declaration-51.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-51.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-51.html)
- [variable-declaration-52.html](https://wpt.fyi/results/css/css-variables/variable-declaration-52.html "css/css-variables/variable-declaration-52.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-declaration-52.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-declaration-52.html)
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
- [variable-generated-content-dynamic-001.html](https://wpt.fyi/results/css/css-variables/variable-generated-content-dynamic-001.html "css/css-variables/variable-generated-content-dynamic-001.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-generated-content-dynamic-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-generated-content-dynamic-001.html)
- [variable-invalid-recovery.html](https://wpt.fyi/results/css/css-variables/variable-invalid-recovery.html "css/css-variables/variable-invalid-recovery.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-invalid-recovery.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-invalid-recovery.html)
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
- [variable-reference-15.html](https://wpt.fyi/results/css/css-variables/variable-reference-15.html "css/css-variables/variable-reference-15.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-15.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-15.html)
- [variable-reference-16.html](https://wpt.fyi/results/css/css-variables/variable-reference-16.html "css/css-variables/variable-reference-16.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-16.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-16.html)
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
- [variable-reference-40.html](https://wpt.fyi/results/css/css-variables/variable-reference-40.html "css/css-variables/variable-reference-40.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-40.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-40.html)
- [variable-reference-without-whitespace.html](https://wpt.fyi/results/css/css-variables/variable-reference-without-whitespace.html "css/css-variables/variable-reference-without-whitespace.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-without-whitespace.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-without-whitespace.html)
- [vars-background-shorthand-001.html](https://wpt.fyi/results/css/css-variables/vars-background-shorthand-001.html "css/css-variables/vars-background-shorthand-001.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/vars-background-shorthand-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/vars-background-shorthand-001.html)
- [vars-font-shorthand-001.html](https://wpt.fyi/results/css/css-variables/vars-font-shorthand-001.html "css/css-variables/vars-font-shorthand-001.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/vars-font-shorthand-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/vars-font-shorthand-001.html)
- [wide-keyword-fallback-001.html](https://wpt.fyi/results/css/css-variables/wide-keyword-fallback-001.html "css/css-variables/wide-keyword-fallback-001.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/wide-keyword-fallback-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/wide-keyword-fallback-001.html)
- [wide-keyword-fallback-002.html](https://wpt.fyi/results/css/css-variables/wide-keyword-fallback-002.html "css/css-variables/wide-keyword-fallback-002.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/wide-keyword-fallback-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/wide-keyword-fallback-002.html)
- [css-variable-change-style-001.html](https://wpt.fyi/results/css/css-variables/css-variable-change-style-001.html "css/css-variables/css-variable-change-style-001.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/css-variable-change-style-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/css-variable-change-style-001.html)
- [css-variable-change-style-002.html](https://wpt.fyi/results/css/css-variables/css-variable-change-style-002.html "css/css-variables/css-variable-change-style-002.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/css-variable-change-style-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/css-variable-change-style-002.html)
- [custom-properties-inherit.html](https://wpt.fyi/results/css/css-variables/custom-properties-inherit.html "css/css-variables/custom-properties-inherit.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/custom-properties-inherit.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/custom-properties-inherit.html)
- [missing-closing-nested-fallback.html](https://wpt.fyi/results/css/css-variables/missing-closing-nested-fallback.html "css/css-variables/missing-closing-nested-fallback.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/missing-closing-nested-fallback.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/missing-closing-nested-fallback.html)
- [revert-rule-in-fallback.html](https://wpt.fyi/results/css/css-variables/revert-rule-in-fallback.html "css/css-variables/revert-rule-in-fallback.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/revert-rule-in-fallback.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/revert-rule-in-fallback.html)
- [revert-rule-to-var.html](https://wpt.fyi/results/css/css-variables/revert-rule-to-var.html "css/css-variables/revert-rule-to-var.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/revert-rule-to-var.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/revert-rule-to-var.html)
- [transition-with-attribute-taint.html](https://wpt.fyi/results/css/css-variables/transition-with-attribute-taint.html "css/css-variables/transition-with-attribute-taint.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/transition-with-attribute-taint.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/transition-with-attribute-taint.html)
- [url-token-serialization.html](https://wpt.fyi/results/css/css-variables/url-token-serialization.html "css/css-variables/url-token-serialization.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/url-token-serialization.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/url-token-serialization.html)
- [var-ident-function.html](https://wpt.fyi/results/css/css-variables/var-ident-function.html "css/css-variables/var-ident-function.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/var-ident-function.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/var-ident-function.html)
- [var-parsing.html](https://wpt.fyi/results/css/css-variables/var-parsing.html "css/css-variables/var-parsing.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/var-parsing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/var-parsing.html)
- [variable-animation-guaranteed-invalid.html](https://wpt.fyi/results/css/css-variables/variable-animation-guaranteed-invalid.html "css/css-variables/variable-animation-guaranteed-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-animation-guaranteed-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-animation-guaranteed-invalid.html)
- [variable-css-wide-keywords-after-substitution.html](https://wpt.fyi/results/css/css-variables/variable-css-wide-keywords-after-substitution.html "css/css-variables/variable-css-wide-keywords-after-substitution.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-css-wide-keywords-after-substitution.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-css-wide-keywords-after-substitution.html)
- [variable-definition-border-shorthand-serialize.html](https://wpt.fyi/results/css/css-variables/variable-definition-border-shorthand-serialize.html "css/css-variables/variable-definition-border-shorthand-serialize.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-definition-border-shorthand-serialize.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-definition-border-shorthand-serialize.html)
- [variable-exponential-blowup.html](https://wpt.fyi/results/css/css-variables/variable-exponential-blowup.html "css/css-variables/variable-exponential-blowup.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-exponential-blowup.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-exponential-blowup.html)
- [variable-presentation-attribute.html](https://wpt.fyi/results/css/css-variables/variable-presentation-attribute.html "css/css-variables/variable-presentation-attribute.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-presentation-attribute.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-presentation-attribute.html)
- [variable-reference-cssom.html](https://wpt.fyi/results/css/css-variables/variable-reference-cssom.html "css/css-variables/variable-reference-cssom.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-cssom.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-cssom.html)
- [variable-reference-name-substitution-attr-taint.html](https://wpt.fyi/results/css/css-variables/variable-reference-name-substitution-attr-taint.html "css/css-variables/variable-reference-name-substitution-attr-taint.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-name-substitution-attr-taint.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-name-substitution-attr-taint.html)
- [variable-reference-name-substitution.html](https://wpt.fyi/results/css/css-variables/variable-reference-name-substitution.html "css/css-variables/variable-reference-name-substitution.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-name-substitution.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-name-substitution.html)
- [variable-reference-perspective-origin.html](https://wpt.fyi/results/css/css-variables/variable-reference-perspective-origin.html "css/css-variables/variable-reference-perspective-origin.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-perspective-origin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-perspective-origin.html)
- [variable-reference-refresh.html](https://wpt.fyi/results/css/css-variables/variable-reference-refresh.html "css/css-variables/variable-reference-refresh.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-reference-refresh.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-reference-refresh.html)
- [variable-resolution-during-prioritary-properties.html](https://wpt.fyi/results/css/css-variables/variable-resolution-during-prioritary-properties.html "css/css-variables/variable-resolution-during-prioritary-properties.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-resolution-during-prioritary-properties.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-resolution-during-prioritary-properties.html)
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
- [variable-substitution-shorthands.html](https://wpt.fyi/results/css/css-variables/variable-substitution-shorthands.html "css/css-variables/variable-substitution-shorthands.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-substitution-shorthands.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-substitution-shorthands.html)
- [variable-substitution-variable-declaration.html](https://wpt.fyi/results/css/css-variables/variable-substitution-variable-declaration.html "css/css-variables/variable-substitution-variable-declaration.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-substitution-variable-declaration.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-substitution-variable-declaration.html)
- [variable-transitions-transition-property-all-before-value.html](https://wpt.fyi/results/css/css-variables/variable-transitions-transition-property-all-before-value.html "css/css-variables/variable-transitions-transition-property-all-before-value.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-transitions-transition-property-all-before-value.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-transitions-transition-property-all-before-value.html)
- [variable-transitions-value-before-transition-property-all.html](https://wpt.fyi/results/css/css-variables/variable-transitions-value-before-transition-property-all.html "css/css-variables/variable-transitions-value-before-transition-property-all.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variable-transitions-value-before-transition-property-all.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variable-transitions-value-before-transition-property-all.html)
- [variables-substitute-guaranteed-invalid.html](https://wpt.fyi/results/css/css-variables/variables-substitute-guaranteed-invalid.html "css/css-variables/variables-substitute-guaranteed-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/variables-substitute-guaranteed-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/variables-substitute-guaranteed-invalid.html)
- [vars-border-shorthand-serialize.html](https://wpt.fyi/results/css/css-variables/vars-border-shorthand-serialize.html "css/css-variables/vars-border-shorthand-serialize.html")
 [[(live
 test)]](http://wpt.live/css/css-variables/vars-border-shorthand-serialize.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-variables/vars-border-shorthand-serialize.html)
