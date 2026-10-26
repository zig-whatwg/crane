## 1. Introduction

The
[\[css-variables-1\]](#biblio-css-variables-1 "CSS Custom Properties for Cascading Variables Module Level 1")
specification defined the concept of \"cascading variables\",
author-defined variables created from the value of [custom
properties](https://drafts.csswg.org/css-variables-2/#custom-property), capable of being substituted into arbitrary other
properties via the
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) function.

This specification defines a related, but simpler, concept of
[environment
variables](#css-environment-variable). Unlike \"cascading variables\", which can change
throughout the page as their corresponding [custom
property](https://drafts.csswg.org/css-variables-2/#custom-property) takes on different values, an [environment
variable] is \"global\" to a
particular document---​its value is the same everywhere. The
[env()](#funcdef-env)
function can then be used to substitute the value into arbitrary
locations, similar to the
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) function.

These \"global\" variables have both benefits and downsides versus
cascading variables:

- Many variables aren't meant to change over the course of a page; they
 set up themes, or are helpers for particular numerical values. Using
 [environment
 variables](#css-environment-variable) instead of [custom
 properties](https://drafts.csswg.org/css-variables-2/#custom-property) to define these communicates the proper intent, which
 is good both for the author of the document (particularly when
 multiple people are collaborating on a single document), and for the
 user agent, as it can store these variables in a more optimal way.

- Because [environment
 variables](#css-environment-variable) don't depend on the value of anything drawn from a
 particular element, they can be used in places where there is no
 obvious element to draw from, such as in
 [\@media](https://drafts.csswg.org/css-conditional-3/#at-ruledef-media) rules, where the
 [var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) function would not be valid.

- Information from the user agent itself, such as the margin of the
 viewport to avoid laying out in by default (for example, to avoid
 overlapping a \"notch\" in the screen), can be retrieved via
 [env()](#funcdef-env),
 whereas the element-specific nature of
 [var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) was not an appropriate place to pipe that
 information in.

Most [environment
variables](#css-environment-variable) will have a single value at a time. Some, however, are
\"indexed\", representing multiple values at once, such as the sizes and
positions of several distinct panes of content in the
[viewport-segment-\*] variables. To refer to these indexed
variables, one or more integers must be provided alongside the variable
name, like [viewport-segment-width 1 0], to select a single value
from the list or grid of possibilities, similar to selecting one element
from a list in a traditional programming language with a syntax like
`values[0]`.

Tests

- [env-parsing.html](https://wpt.fyi/results/css/css-env/env-parsing.html "css/css-env/env-parsing.html")
 [[(live
 test)]](http://wpt.live/css/css-env/env-parsing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-env/env-parsing.html)

## 2. Environment Variables

A CSS [environment variable] is a name associated with a
[\<declaration-value\>](https://drafts.csswg.org/css-syntax-3/#typedef-declaration-value) (a sequence of zero more CSS tokens,
with almost no restrictions on what tokens can exist), similar to a
[custom
property](https://drafts.csswg.org/css-variables-2/#custom-property). [Environment
variables](#css-environment-variable) can be defined by the user agent, or by the author.

If author-defined, they are a [custom environment
variable]. The name of a [custom environment
variable](#custom-environment-variable) must conform to the
[\<custom-property-name\>](https://drafts.csswg.org/css-variables-2/#typedef-custom-property-name) grammar. This specification does not
yet define how authors can define [custom environment
variables].

Is the set of UA-defined [environment
variables](#css-environment-variable) visible to script? If so, define an API on
[`Document`](https://dom.spec.whatwg.org/#document) to expose them.

Define how authors can add [environment
variables](#css-environment-variable), preferably both via JS and via CSS. Note that mixing
CSS rules and JS-defined stuff can easily get messy, as demonstrated by
CSSFontFaceRule vs FontFace\...

The following UA-defined [environment
variables](#css-environment-variable) are officially defined and must be supported.
Additional UA-defined [environment
variables] *must not* be supported
unless/until they are added to this list.

### 2.1. Safe area inset variables

Name

Value

Number of dimensions

[safe-area-inset-top]

[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)

0 (scalar)

[safe-area-inset-right]

[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)

0 (scalar)

[safe-area-inset-bottom]

[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)

0 (scalar)

[safe-area-inset-left]

[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)

0 (scalar)

The safe area insets are four [environment
variables](#css-environment-variable) that define a rectangle by its top, right, bottom, and
left insets from the edge of the viewport. For rectangular displays,
these must all be zero, but for nonrectangular displays they must form a
rectangle, chosen by the user agent, such that all content inside the
rectangle is visible, and such that reducing any of the insets would
cause some content inside of the rectangle to be invisible due to the
nonrectangular nature of the display. This allows authors to limit the
layout of essential content to the space inside of the safe area
rectangle.

### 2.2. Safe area maximum inset variables

Name

Value

Number of dimensions

[safe-area-max-inset-top]

[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)

0 (scalar)

[safe-area-max-inset-right]

[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)

0 (scalar)

[safe-area-max-inset-bottom]

[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)

0 (scalar)

[safe-area-max-inset-left]

[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)

0 (scalar)

The safe area maximum insets are four [environment
variables](#css-environment-variable) that are tied to the [safe area inset
variables](#safe-area-insets). Unlike the safe area inset variables
which are dynamic values, the safe area maximum insets are static values
that represent the maximum value of their dynamic counterpart when
dynamic UA interfaces are retracted, making the [layout
viewport](https://drafts.csswg.org/css-viewport/#layout-viewport) size the [large viewport
size](https://drafts.csswg.org/css-values-4/#large-viewport-size).

### 2.3. Viewport segment variables

Name

Value

Number of dimensions

[viewport-segment-width]

[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)

2

[viewport-segment-height]

[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)

2

[viewport-segment-top]

[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)

2

[viewport-segment-left]

[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)

2

[viewport-segment-bottom]

[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)

2

[viewport-segment-right]

[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)

2

The viewport segments are [environment
variables](#css-environment-variable) that define the position and dimensions of a logically
separate region of the viewport. Viewport segments are created when the
viewport is split by one or more hardware features (such as a fold or a
hinge between separate displays) that act as a divider; segments are the
regions of the viewport that can be treated as logically distinct by the
author.

The viewport segment [environment
variables](#css-environment-variable) have two dimensions, which represent the x and y
position, respectively, in the two dimensional grid created by the
hardware features separating the segments. Segments along the left edge
have x position [0], those in the next column to the right have x
position [1], etc. Similarly, segments along the top edge have y
position [0], etc.

 In certain hardware configurations, the separator
itself may occupy logical space within the viewport. The dimensions of
the separator can be computed by calculating the area between the
position of the viewport segments.

When the viewport is split into two
side-by-side segments, the viewport segment on the left would have
indices (0, 0). Its width would be represented as
[env(viewport-segment-width 0 0, 300px)]. The viewport segment on
the right would have indices (1, 0). Similarly, for a viewport split
into two vertical segments, the viewport segment on the top would have
indices (0, 0) and the one on the bottom (0, 1).

These variables are only defined when there are at least two such
segments. Viewport units should be used instead when there is no
hardware feature splitting the viewport, otherwise content will not
display as intended when viewed on a device with multiple segments.

### 2.4. Preferred Text Zoom

Name

Value

Number of dimensions

[preferred-text-scale]

[\<number\>](https://drafts.csswg.org/css-values-4/#number-value)

0 (scalar)

The
[preferred-text-scale](#valdef-env-preferred-text-scale) [environment
variable](#css-environment-variable) represents the user's preferred text scale factor; aka,
the adjustment they make to the \"default\" font size of the OS and/or
user agent. (On devices where
[text-size-adjust](https://drafts.csswg.org/css-size-adjust-1/#propdef-text-size-adjust) has an effect, this is the scale
factor applied by [text-size-adjust:
auto].)

For example, if [text-size-adjust:auto] would cause text sizes to
double, then [env(preferred-text-scale)] would resolve to
[2].

This [environment
variable](#css-environment-variable) requires care to be used correctly. By default, text
scaling is applied automatically; using
[env(preferred-text-scale)] would result in the scale being
*double*-applied, making text or UI elements too large.

Typically, authors should either:

- set [text-size-adjust: calc(100% \*
 env(preferred-text-scale));](https://drafts.csswg.org/css-size-adjust-1/#propdef-text-size-adjust), to ensure that all the text in the page is
 automatically scaled to the user's preference, and when necessary
 scale non-text sizes by the scale factor as well.

- or set [text-size-adjust:none], and then consistently use this
 [environment
 variable](#css-environment-variable) to scale relevant text and UI to the user's
 preference.

## 3. Using Environment Variables: the [env() notation]
In order to substitute the value of an [environment
variable](#css-environment-variable) into a CSS context, use the
[env()](#funcdef-env)
function:

``` prod
env() = env( <custom-ident> <integer [0,∞]>*, <declaration-value>? )
```

The [env()](#funcdef-env)
function's [argument
grammar](https://drafts.csswg.org/css-values-5/#argument-grammar) is:

``` prod
<env-args> = env( <declaration-value>, <declaration-value>? )
```

Like
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var), a bare comma can be used with nothing following
it, indicating that the second
[\<declaration-value\>](https://drafts.csswg.org/css-syntax-3/#typedef-declaration-value) was passed, just as an empty
sequence.

The [env()](#funcdef-env)
function can be used in place of any part of a value in any property on
any element, or any part of a value in any descriptor on any
[at-rule](https://drafts.csswg.org/css-syntax-3/#at-rule), and in several other places where CSS values are
allowed.

Define the full set of places
[env()](#funcdef-env) can
be used.

- Should be able to replace any subset of MQ syntax, for example.

- Should be able to replace selectors, maybe?

- Should it work on a rule level, so you can insert arbitrary stuff into
 a rule, like reusing a block of declarations?

The first argument to [env()](#funcdef-env) provides the name of an [environment
variable](#css-environment-variable) to be substituted. Following the first argument are
integers that represent indices into the dimensions of the [environment
variable], if the provided name
represents an array-like [environment
variable]. The argument after the
comma, if provided, is a fallback value, which is used as the
substitution value when the referenced [environment
variable] does not exist.

 The syntax of the fallback, like that of custom
properties, allows commas. For example, [env(foo, red, blue)]
defines a fallback of [red, blue]; that is, anything between the
first comma and the end of the function is considered a fallback value.

If a property contains one or more
[env()](#funcdef-env)
functions, and those functions are syntactically valid, the entire
property's grammar must be assumed to be valid at parse time. It is only
syntax-checked at computed-time, after [env()] functions have been
[substituted](#substitute-an-env).

If a descriptor contains one or more
[env()](#funcdef-env)
functions, and those functions are syntactically valid, the entire
declaration's grammar must be assumed to be valid at parse time. It is
only syntax-checked after [env()] functions
have been [substituted](#substitute-an-env).

To [substitute an env()] in a property or
descriptor:

1. If the name provided by the first argument of the
 [env()](#funcdef-env)
 function is a recognized [environment
 variable](#css-environment-variable) name, the number of supplied integers matches the
 number of dimensions of the [environment
 variable] referenced by that
 name, and values of the indices correspond to a known sub-value,
 replace the [env()] function by the
 value of the named [environment
 variable].

2. Otherwise, if the [env()](#funcdef-env) function has a fallback value as its second
 argument, replace the [env()] function
 by the fallback value. If there are any
 [env()] references in the fallback,
 [substitute](#substitute-an-env) them as well.

3. Otherwise, the property or descriptor containing the
 [env()](#funcdef-env)
 function is [invalid at computed-value
 time](https://www.w3.org/TR/css-variables-1/#invalid-at-computed-value-time).

Define when substitution happens. It has
to be before
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) substitution. Alternately, should
[env()](#funcdef-env)
substitution happen at parse time, so unknown variable names cause it to
fail syntax checking? There's no particular reason to have it happen at
computed-value time, like [var()]
does---​that was to ensure that [custom
properties](https://drafts.csswg.org/css-variables-2/#custom-property) could inherit their value down before they were picked
up by a [var()].

When I figure out where else
[env()](#funcdef-env) can
go, define how/when it substitutes.

### 3.1. Environment Variables in Shorthand Properties

If
[env()](#funcdef-env)
substitution happens during parsing, then this is unnecessary.

The [env()](#funcdef-env)
function causes the same difficulties with [shorthand
properties](https://drafts.csswg.org/css-cascade-5/#shorthand-property) as the
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) function does. When an
[env()] is used in a [shorthand
property], then, it has the same effects
as defined in [CSS Variables 1 § 3.2 Variables in Shorthand
Properties](https://www.w3.org/TR/css-variables-1/#variables-in-shorthands).

## 4. Privacy Considerations

The [environment
variables](#css-environment-variable) defined by this specification are *potentially*
privacy-sensitive, since they represent additional information
potentially not already avaialble to the page. In particular, they
potentially represent a fingerprinting vector, by exposing additional
information about the device a user is viewing the page with.

So far, the [environment
variables](#css-environment-variable) defined by this specifcation have been reviewed and
deemed acceptable to expose by the CSSWG.

## 5. Security Considerations

This specification provides read-only access to some new types of
information about the device.

The [environment
variables](#css-environment-variable) defined by this specification do not expose any
security-sensitive information.
