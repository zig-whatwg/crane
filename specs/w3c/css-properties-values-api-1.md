## 1. Introduction

CSS defines a comprehensive set of properties that can be manipulated in
order to modify the layout, paint, or behaviour of a web document.
However, web authors frequently wish to extend this set with additional
properties.

[\[css-variables\]](#biblio-css-variables "CSS Custom Properties for Cascading Variables Module Level 1")
provides primitive means for defining user-controlled properties,
however these properties always take token lists as values, must always
inherit, and can only impact document layout or paint by being
re-incorporated into the value of other properties via a var()
reference.

This specification extends
[\[css-variables\]](#biblio-css-variables "CSS Custom Properties for Cascading Variables Module Level 1"),
allowing the registration of properties that have a value type, an
initial value, and a defined inheritance behaviour, via two methods:

- A JS API, the
 [`registerProperty()`](#dom-css-registerproperty) method

- A CSS at-rule, the
 [\@property](#at-ruledef-property) rule

This specification is complementary to
[\[css-paint-api-1\]](#biblio-css-paint-api-1 "CSS Painting API Level 1")
and
[\[css-layout-api-1\]](#biblio-css-layout-api-1 "CSS Layout API Level 1"),
which allow custom properties to directly impact paint and layout
behaviours respectively.

## 2. Registered Custom Properties

A [custom
property](https://drafts.csswg.org/css-variables-2/#custom-property) can become a [registered custom
property], making it act more like a UA-defined
property: giving it a syntax that's checked by the UA, an initial value,
and a specific inheritance behavior. This can be done by the
[\@property](#at-ruledef-property) rule, or the
[`registerProperty()`](#dom-css-registerproperty) JS function.

A [custom
property](https://drafts.csswg.org/css-variables-2/#custom-property) is considered to be registered for a
[`Document`](https://dom.spec.whatwg.org/#document) if there is a valid
[\@property](#at-ruledef-property) rule defined for its name in one of the document's
stylesheets, or its name is
[contained](https://infra.spec.whatwg.org/#map-exists) in the document's
[`[[registeredPropertySet]]`](#dom-window-registeredpropertyset-slot) slot (that is,
[`registerProperty()`](#dom-css-registerproperty) was called to register it).

A [registered custom
property](#registered-custom-property) acts similarly to an unregistered [custom
property](https://drafts.csswg.org/css-variables-2/#custom-property), except as defined below.

### 2.1. Determining the Registration

A [registered custom
property](#registered-custom-property) has a [custom property
registration] that contains all the
data necessary to treat it like a real property. It's a
[struct](https://infra.spec.whatwg.org/#struct) consisting of:

- a property name (a [custom property name
 string](https://drafts.css-houdini.org/css-typed-om-1/#custom-property-name-string))

- optionally, a syntax (a [syntax
 string](#syntax-string))
 (defaulting to `"*"`)

- optionally, an inherit flag (a
 [boolean](https://infra.spec.whatwg.org/#boolean)) (defaulting to `true`)

- optionally, an initial value (a CSS value which successfully
 [parses](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) according to the syntax) (defaulting to the
 [guaranteed-invalid
 value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value))

If the
[`Document`](https://dom.spec.whatwg.org/#document)'s
[`[[registeredPropertySet]]`](#dom-window-registeredpropertyset-slot) slot
[contains](https://infra.spec.whatwg.org/#list-contain) a record with the [custom
property's](https://drafts.csswg.org/css-variables-2/#custom-property) name, the registration is that record.

Otherwise, if the
[`Document`](https://dom.spec.whatwg.org/#document)'s active stylesheets contain at least one valid
[\@property](#at-ruledef-property) rule representing a registration with the [custom
property's](https://drafts.csswg.org/css-variables-2/#custom-property) name, the last such one in document order is the
registration.

Otherwise there is no registration, and the [custom
property](https://drafts.csswg.org/css-variables-2/#custom-property) is *not* a [registered custom
property](#registered-custom-property).

### 2.2. Parse-Time Behavior

[Registered custom
properties](#registered-custom-property) parse exactly like unregistered [custom
properties](https://drafts.csswg.org/css-variables-2/#custom-property); almost anything is allowed. The registered syntax of
the property is *not* checked at parse time.

 However, the syntax is checked at computed-value time,
before substitution via
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var). See [§ 2.4 Computed Value-Time
Behavior](#calculation-of-computed-values).

Why aren't custom properties syntax-checked?

When parsing a page's CSS, UAs commonly make a number of optimizations
to help with both speed and memory.

One of those optimizations is that they only store the properties that
will actually have an effect; they throw away invalid properties, and if
you write the same property multiple times in a single declaration
block, all but the last valid one will be thrown away. (This is an
important part of CSS's error-recovery and forward-compatibility
behavior.)

This works fine if the syntax of a property never changes over the
lifetime of a page. If a custom property is registered, however, it can
change its syntax, so that a property that was previously invalid
suddenly becomes valid.

The only ways to handle this are to either store every declaration, even
those that were initially invalid (increasing the memory cost of pages),
or to re-parse the entire page's CSS with the new syntax rules
(increasing the processing cost of registering a custom property).
Neither of these are very desirable.

Further, UA-defined properties have their syntax determined by the
version of the UA the user is viewing the page with; this is out of the
page author's control, which is the entire reason for CSS's
error-recovery behavior and the practice of writing multiple
declarations for varying levels of support. A custom property, on the
other hand, has its syntax controlled by the page author, according to
whatever stylesheet or script they've included in the page; there's no
unpredictability to be managed. Throwing away syntax-violating custom
properties would thus only be, at best, a convenience for the page
author, not a necessity like for UA-defined properties.

### [2.3. ][[Specified Value](https://drafts.csswg.org/css-cascade-5/#specified-value)-Time Behavior]
Just like unregistered [custom
properties](https://drafts.csswg.org/css-variables-2/#custom-property), all [registered custom
properties](#registered-custom-property), regardless of registered syntax, accept the [CSS-wide
keywords](https://drafts.csswg.org/css-values-4/#css-wide-keywords), such as
[inherit](https://drafts.csswg.org/css-cascade-5/#valdef-all-inherit) or
[revert](https://drafts.csswg.org/css-cascade-5/#valdef-all-revert). Their behavior is defined in [CSS Cascading 4
§ 7.3 Explicit
Defaulting](https://drafts.csswg.org/css-cascade-4/#defaulting-keywords).

### [2.4. ][[Computed Value](https://drafts.csswg.org/css-cascade-5/#computed-value)-Time Behavior]
The [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) of a [registered custom
property](#registered-custom-property) is determined by the syntax of its
[registration](#custom-property-registration).

If the
[registration's](#custom-property-registration) syntax is the [universal syntax
definition](#universal-syntax-definition), the [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) is the same as for unregistered [custom
properties](https://drafts.csswg.org/css-variables-2/#custom-property) (either the specified value with variables substituted,
or the [guaranteed-invalid
value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value)).

Otherwise, attempt to
[parse](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) the property's value according to its registered
syntax. If this fails, the declaration is [invalid at computed-value
time](https://drafts.csswg.org/css-values-5/#invalid-at-computed-value-time) and the [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) is determined accordingly. If it succeeds, the
[computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) depends on the specifics of the syntax:

For `"<length>"`, `"<length-percentage>"`, `"<angle>"`, `"<time>"`,
`"<resolution>"`, `"<integer>"`, `"<number>"`, and `"<percentage>"`
values:

- If the specified value is a
 [dimension](https://drafts.csswg.org/css-values-4/#dimension) literal (such as [50em] or [.2s]), the
 computed value is the same value, but with the unit converted to the
 corresponding [canonical
 unit](https://drafts.csswg.org/css-values-4/#canonical-unit) for the type of value.

- If the specified value is any other numeric literal (such as [5]
 or [20%]), the computed value is as specified. (In particular,
 percentages are never resolved against anything.)

- If the specified value is a function that evaluates to one of those
 types (such as a [math
 function](https://drafts.csswg.org/css-values-4/#math-function)), the computed value is defined by that function.

For `"<string>"` values, the computed value is as specified.

For `"<color>"` values, the value is computed by resolving color values,
per [CSS Color 4 §  15. Resolving \<color\>
Values](https://drafts.csswg.org/css-color-4/#resolving-color-values).

For `"<custom-ident>"`, ident, or `"*"` values, the computed value is as
specified.

For `"<url>"` values, the computed value is one of the following:

- if the URL is a relative URL, the computed value is the resolved
 absolute URL as described in
 [\[css3-values\]](#biblio-css3-values "CSS Values and Units Module Level 3").

- otherwise, the computed value is as specified.

URL behavior examples

Because URLs resolve against the base
URL of the stylesheet they appear in, we can end up with multiple
relative URLs that resolve against different base URLs, even though they
appear in the same property.

For example, suppose [\--url-foo] and [\--url-bar] are
registered custom properties with [\<url\>] syntax, and that we
have a stylesheet at `/style/foo/foo.css`:

```
div {
 --url-foo: url("foo.png");
}
```

and another stylesheet at `/style/bar/bar.css`

```
div {
 --url-bar: url("bar.png");
}
```

and finally a document at `/index.html`:

```
<link href="/style/foo/foo.css" rel="stylesheet" type="text/css">
<link href="/style/bar/bar.css" rel="stylesheet" type="text/css">
<div style="background-image: var(--url-foo), var(--url-bar);">
</div>
```

Here, the [var(\--url-foo)] reference would produce a URL that
resolves against `/style/foo`, and the [var(\--url-bar)] reference
would produce a URL that resolves against `/style/bar`.

On the other hand, if both [\--url-foo] and [\--url-bar]
were *un*registered, they would substitute their literal values
(relative URLs) into the `/index.html` stylesheet, which would then
resolve the URLs against `/index.html` instead.

For `"<image>"` values, the computed value is the [computed
\<image\>](https://drafts.csswg.org/css-images-4/#computed-image).

For `"<transform-function>"` and `"<transform-list>"` values, the
computed value is as specified but with all lengths resolved to their
computed values.

For values with [multipliers](#multipliers), the computed value is a
list of the computed values of the base type.

For syntaxes specified with [the \| combinator](#combinator), the
computed value is given by applying the computed-value rules for the
first clause that matches the value.

### 2.5. Animation Behavior

 As defined by
[\[css3-animations\]](#biblio-css3-animations "CSS Animations Level 1")
and
[\[css3-transitions\]](#biblio-css3-transitions "CSS Transitions Module Level 1"),
it is possible to specify animations and transitions that reference
custom properties.

When referenced by animations and transitions, custom property values
[interpolate](https://drafts.csswg.org/css-values-4/#interpolation) [by computed
value](https://drafts.csswg.org/web-animations-1/#by-computed-value), in accordance with the type that they parsed as.

 This implies that a list of values, such as `<color>+`
or `<color>#`, will interpolate as a simple list, matching up each
component index-by-index, and failing if the number of components
doesn't match.

As an exception to the above rule, a value that parsed as a
`<transform-list>`, a `<transform-function>`, or a
`<transform-function>+` instead interpolates as per the
[transform](https://drafts.csswg.org/css-transforms-1/#propdef-transform) property.

 If, for whatever reason, a custom property is defined
with a syntax of `<transform-function>#`, this will thus first
interpolate as a simple list, and then each list item will interpolate
as a
[transform](https://drafts.csswg.org/css-transforms-1/#propdef-transform) value.

 Registering (or changing the registration) of a custom
property can change its computed value, which can start or interrupt a
CSS transition.

### 2.6. Conditional Rules

As stated in [§ 2.2 Parse-Time Behavior](#parsing-custom-properties),
both unregistered and
[registered](#registered-custom-property) [custom
properties](https://drafts.csswg.org/css-variables-2/#custom-property) accept (almost) all possible values at parse-time.
[Registered](#registered-custom-property) [custom
properties](https://drafts.csswg.org/css-variables-2/#custom-property) only apply their syntax at [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) time.

So, all [custom
properties](https://drafts.csswg.org/css-variables-2/#custom-property), regardless of whether they're
[registered](#registered-custom-property) or unregistered, will test as \"true\" in an
[\@supports](https://drafts.csswg.org/css-conditional-3/#at-ruledef-supports) rule, so long as you don't violate the (very
liberal) generic syntax for [custom
properties](https://drafts.csswg.org/css-variables-2/#custom-property).

For example, even if a custom property
is registered with `syntax: "<color>";`, a rule like
`@supports (--foo: 1em) ` will still evaluate as true and apply
those styles, because the declaration *does* successfully parse as a
valid property.

### [2.7. ][Substitution via [var()](https://drafts.csswg.org/css-variables-2/#funcdef-var)]
Like unregistered custom properties, the value of a registered custom
property can be substituted into another value with the
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) function. However, registered custom properties
substitute as their [computed value](#calculation-of-computed-values),
rather than the original token sequence used to produce that value.

Any
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) function that references a registered custom
property must be replaced with an [equivalent token
sequence], which is equal to the token sequence that would have been
produced by
[serializing](https://drafts.csswg.org/cssom-1/#serialize-a-css-value) the computed value, and
[tokenizing](https://drafts.csswg.org/css-syntax-3/#tokenization) the
resulting string.

Suppose that [\--x] is
registered with [\<length\>] syntax, and that [\--y]is an
unregistered custom property.

```
div {
 font-size: 10px;
 --x: 8em;
 --y: var(--x);
}
```

Because the computed value of [\--x] (when serialized) is
\"80px\", the computed value of [\--y] is a
[\<dimension-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-dimension-token) with a value of \"80\" and unit
\"px\".

#### 2.7.1. Dependency Cycles via Relative Units

[Registered custom
properties](#registered-custom-property) follow the same rules for dependency cycle resolution
as unregistered [custom
properties](https://drafts.csswg.org/css-variables-2/#custom-property), with the following additional constraints:

For any registered custom property with a
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value) or
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) syntax component:

- If the property contains any of the following units:
 [em](https://drafts.csswg.org/css-values-4/#em),
 [ex](https://drafts.csswg.org/css-values-4/#ex),
 [cap](https://drafts.csswg.org/css-values-4/#cap),
 [ch](https://drafts.csswg.org/css-values-4/#ch),
 [ic](https://drafts.csswg.org/css-values-4/#ic),
 [lh](https://drafts.csswg.org/css-values-4/#lh); then add an edge between the property and the
 [font-size] of the current element.

- If the property contains the
 [lh](https://drafts.csswg.org/css-values-4/#lh) unit, add an edge between the property and the
 [line-height] of the current element.

- If the property contains any of the following units:
 [rem](https://drafts.csswg.org/css-values-4/#rem),
 [rlh](https://drafts.csswg.org/css-values-4/#rlh); then add an edge between the property and the
 [font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size)\' of the root element.

- If the property contains the
 [rlh](https://drafts.csswg.org/css-values-4/#rlh) unit, add an edge between the property and the
 [line-height](https://drafts.csswg.org/css2/#propdef-line-height)\' of the root element.

For example, given this registration:

```
CSS.registerProperty({
 name: "--my-font-size",
 syntax: "<length>",
 initialValue: "0px",
 inherits: false
});
```

the following will produce a dependency cycle:

```
div {
 --my-font-size: 10em;
 font-size: var(--my-font-size);
}
```

and [font-size] will behave as if the value
[unset](https://drafts.csswg.org/css-cascade-5/#valdef-all-unset) was specified.

### 2.8. Shadow DOM

Unlike many concepts in CSS (see [CSS Scoping Module Level 1
§ shadow-names](https://drafts.csswg.org/css-scoping/#shadow-names)),
property registrations are **not** scoped to a tree scope. All
registrations, whether they appear in the outermost document or within a
shadow tree, interact in a single global registration map for the
[`Document`](https://dom.spec.whatwg.org/#document).

Why can't registrations be scoped?

There are clear use-cases for property registrations to be scoped---​a
component using Shadow DOM and registering some custom properties for
its own internal use probably doesn't intend for the outer page to see
the registration, since the outer page doesn't even know the component
is using that property.

However, there are also reasons to not scope the registration---​custom
properties are used to pipe data *into* a component, and it's useful for
the outer page to be able to set such custom properties and have them
syntax-checked by the registration; similarly, concepts such as a
property's initial value don't make much sense unless the property
registration exists globally, so it applies to the property even at the
document's root.

But the above just means that registration scope might be something that
should be controllable, not that it should be forced to be global.

The reason registrations must be global is because elements can exist in
multiple tree scopes at the same time, with styles from each tree scope
intermingling and cascading together. This applies to the [host
element], which lives in the outer tree but is stylable from
the shadow tree by the
[:host](https://drafts.csswg.org/css-shadow-1/#selectordef-host) selector, but also elements inside a shadow DOM
that are targetable from the outer tree by the
[::part()](https://drafts.csswg.org/css-shadow-1/#selectordef-part) pseudo-element.

If registrations could be scoped to a tree scope, and a single property
was registered both inside and outside, it's not clear which
registration should be applied to parse the value. Even if we tracked
which tree a value came from (something we do for other tree-scoped
values) and applied the corresponding registration, it's not clear that
this would give a reasonable result---​the shadow DOM might expect a
property to have a particular value space, and be surprised when it
receives something completely different due to the outer tree winning
the cascade and applying its own registration.

When custom properties are exposed as part of a Shadow DOM-using
component's public API, this global registration behavior works as
intended. If the outer page is using a custom property of the same name
for different purposes, that is already a conflict that needs to be
resolved, and the registration behavior does not make it worse.

If a custom property is intended for private internal usage for a
component, however, it is recommended that the property be given a
likely-unique name, to minimize the possibility of a clash with any
other context. This can be done, for example, by including the project
name, or some short random string of text, in the name of the property.

## [3. ][The [\@property] Rule]
The [\@property](#at-ruledef-property) rule represents a [custom property
registration](#custom-property-registration) directly in a stylesheet without having to run any JS.
Valid [\@property](#at-ruledef-property) rules result in a [registered custom
property](#registered-custom-property), as if
[`registerProperty()`](#dom-css-registerproperty) had been called with equivalent parameters.

The syntax of
[\@property](#at-ruledef-property) is:

```
@property <custom-property-name># {
 <declaration-list>
}
```

A valid [\@property](#at-ruledef-property) rule represents a [custom property
registration](#custom-property-registration) for each
[\<custom-property-name\>](https://drafts.csswg.org/css-variables-2/#typedef-custom-property-name) in the rule's prelude, with the
property name being the serialization of that
[\<custom-property-name\>](https://drafts.csswg.org/css-variables-2/#typedef-custom-property-name) and all other fields identical.

The following rule registers three
properties with the same syntax, inheritance behavior, and initial
value:

```
@property --width, --height, --depth {
 syntax: "<length>";
 inherits: false;
 initial-value: 0px;
}
```

While the
[\<custom-property-name\>](https://drafts.csswg.org/css-variables-2/#typedef-custom-property-name) is required, all of the descriptors
are optional. When omitted, it matches the behavior of an *unregistered*
[custom
property](https://drafts.csswg.org/css-variables-2/#custom-property).

Unknown descriptors are invalid and ignored, but do not invalidate the
[\@property](#at-ruledef-property) rule.

 As specified in [§ 2.1 Determining the
Registration](#determining-registration), if multiple valid
[\@property](#at-ruledef-property) rules represent a registration for the same
[\<custom-property-name\>](https://drafts.csswg.org/css-variables-2/#typedef-custom-property-name), the last one in stylesheet order
\"wins\". A custom property registration from
[`CSS.registerProperty()`](#dom-css-registerproperty) further wins over any
[\@property](#at-ruledef-property) rules for the same
[\<custom-property-name\>](https://drafts.csswg.org/css-variables-2/#typedef-custom-property-name).

### 3.1. The [syntax Descriptor]
Name:

[syntax]

For:

[\@property](#at-ruledef-property)

Value:

[\<string\>](https://drafts.csswg.org/css-values-4/#string-value)

Initial:

\"\*\"

Specifies the syntax of the [custom property
registration](#custom-property-registration) represented by the
[\@property](#at-ruledef-property) rule, controlling how the property's value is parsed
at [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) time.

If the provided string is not a valid [syntax
string](#syntax-string) (if it
returns failure when [consume a syntax
definition](#consume-a-syntax-definition) is called on it), the descriptor is invalid and must be
ignored.

### 3.2. The [inherits Descriptor]
Name:

[inherits]

For:

[\@property](#at-ruledef-property)

Value:

true
[\|](https://drafts.csswg.org/css-values-4/#comb-one) false

Initial:

true

Specifies the inherit flag of the [custom property
registration](#custom-property-registration) represented by the
[\@property](#at-ruledef-property) rule, controlling whether or not the property
inherits by default.

### 3.3. The [initial-value Descriptor]
Name:

[initial-value]

For:

[\@property](#at-ruledef-property)

Value:

[\<declaration-value\>](https://drafts.csswg.org/css-syntax-3/#typedef-declaration-value)[?](https://drafts.csswg.org/css-values-4/#mult-opt)

Initial:

the [guaranteed-invalid
value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value)

Specifies the initial value of the [custom property
registration](#custom-property-registration) represented by the
[\@property](#at-ruledef-property) rule, controlling the property's [initial
value](https://drafts.csswg.org/css-cascade-5/#initial-value).

If specified, the value of the
[initial-value](#descdef-property-initial-value) descriptor must successfully
[parse](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) according to the rule's
[syntax](#descdef-property-syntax) descriptor, or else the descriptor is
invalid and ignored.

## 4. Registering Custom Properties in JS

To register a custom property via JS, the [`CSS`]
object is extended with a
[`registerProperty()`](#dom-css-registerproperty) method:

```
dictionary PropertyDefinition {
 required DOMString name;
 DOMString syntax = "*";
 boolean inherits = true;
 DOMString initialValue;
};

partial namespace CSS {
 undefined registerProperty(PropertyDefinition definition);
};
```

Additional, the
[`Document`](https://dom.spec.whatwg.org/#document) object gains a new
[`[[registeredPropertySet]]`] private slot, which is a set of records that describe
registered custom properties.

### 4.1. The [`registerProperty()` Function]
The
[`registerProperty(PropertyDefinition definition)`] method registers a custom property
according to the configuration options provided in `definition`. When it
is called, it executes the [register a custom
property](#register-a-custom-property) algorithm, passing the options in its `definition`
argument as arguments of the same names.

To [register a custom property] with `name` being a
string, and optionally `syntax` being a string,
`inherits` being a boolean, and `initialValue`
being a string, execute these steps:

1. Let `property set` be the value of
 [this's](https://webidl.spec.whatwg.org/#this) [relevant global
 object's](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) [associated
 `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window)'s
 [`[[registeredPropertySet]]`](#dom-window-registeredpropertyset-slot) slot.

2. If `name` is not a [custom property name
 string](https://drafts.css-houdini.org/css-typed-om-1/#custom-property-name-string),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror) and exit this algorithm.

 If `property set` already contains an entry with
 `name` as its property name (compared codepoint-wise),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) an
 [`InvalidModificationError`](https://webidl.spec.whatwg.org/#invalidmodificationerror) and exit this algorithm.

3. Attempt to [consume a syntax
 definition](#consume-a-syntax-definition) from `syntax`. If it returns failure,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror). Otherwise, let `syntax definition` be
 the returned [syntax
 definition](#syntax-definition).

4. If `initialValue` is not present, let
 `parsed initial value` be the [guaranteed-invalid
 value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value).

 Otherwise:

 - [parse](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) `initialValue` according to
 [`<declaration-value>`](https://drafts.csswg.org/css-syntax-3/#typedef-declaration-value)`?` if
 `syntax definition` is the [universal syntax
 definition](#universal-syntax-definition), and according to `syntax definition`
 otherwise.

 - If parsing returns failure,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror) and exit this algorithm. Otherwise, let
 `parsed initial value` be the parsed result.

 - If `parsed initial value` is not [computationally
 independent](#computationally-independent),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror) and exit this algorithm.

5. Set `inherit flag` to the value of `inherits`.

6. Let `registered property` be a
 [struct](https://infra.spec.whatwg.org/#struct) with a property name of `name`, a syntax
 of `syntax definition`, an initial value of
 `parsed initial value`, and an inherit flag of
 `inherit flag`.
 [Append](https://infra.spec.whatwg.org/#set-append) `registered property` to
 `property set`.

A property value is [computationally
independent] if it can be converted into a computed value
using only the value of the property on the element, and \"global\"
information that cannot be changed by CSS.

For example, [5px] is
[computationally
independent](#computationally-independent), as converting it into a computed value doesn't change
it at all. Similarly, [1in] is [computationally
independent](#computationally-independent), as converting it into a computed value relies only on
the \"global knowledge\" that [1in] is [96px], which can't
be altered or adjusted by anything in CSS.

On the other hand, [3em] is not [computationally
independent](#computationally-independent), because it relies on the value of
[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size) on the element (or the element's
parent). Neither is a value with a
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) function, because it relies on the value of a
[custom
property](https://drafts.csswg.org/css-variables-2/#custom-property).

When a custom property is registered with a given type, the process via
which specified values for that property are turned into computed values
is defined fully by the type selected, as described in [§ 2.4 Computed
Value-Time Behavior](#calculation-of-computed-values).

 A way to unregister properties may be added in the
future.

Registering a custom property must **not** affect the
[cascade](https://drafts.csswg.org/css-cascade-6/#cascade) in any way. Regardless of what syntax is specified for
a registered property, at parse time it is still parsed as normal for a
[custom
property](https://drafts.csswg.org/css-variables-2/#custom-property), accepting nearly anything. If the [specified
value](https://drafts.csswg.org/css-cascade-5/#specified-value) for a [registered custom
property](#registered-custom-property) violates the registered syntax, however, the property
becomes [invalid at computed-value
time](https://drafts.csswg.org/css-values-5/#invalid-at-computed-value-time) (and thus resets to the registered initial value).

By default, all custom property
declarations that can be parsed as a sequence of tokens are valid.
Hence, the result of this stylesheet:

```
.thing {
 --my-color: green;
 --my-color: url("not-a-color");
 color: var(--my-color);
}
```

is to set the
[color](https://drafts.csswg.org/css-color-4/#propdef-color) property of elements of class
\"thing\" to
[inherit](https://drafts.csswg.org/css-cascade-5/#valdef-all-inherit). The second [\--my-color] declaration
overrides the first at parse time (both are valid), and the
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) reference in the
[color](https://drafts.csswg.org/css-color-4/#propdef-color) property is found to be [invalid at
computed-value
time](https://www.w3.org/TR/css-variables-1/#invalid-at-computed-value-time) (because [url(\"not-a-color\")] is not a color).
At this stage of the CSS pipeline (computation time), the only available
fallback is the initial value of the property, which in the case of
color is
[inherit](https://drafts.csswg.org/css-cascade-5/#valdef-all-inherit). Although there was a valid usable value
(green), this was removed during parsing because it was superseded by
the URL.

If we call:

```
CSS.registerProperty({
 name: "--my-color",
 syntax: "<color>",
 initialValue: "black",
 inherits: false
});
```

the parsing doesn't significantly change, regardless of whether the
registration occurs before or after the stylesheet above. The only
difference is that it's the [\--my-color] property that becomes
[invalid at computed-value
time](https://drafts.csswg.org/css-values-5/#invalid-at-computed-value-time) instead and gets set to its initial value of
[black](https://drafts.csswg.org/css-color-4/#valdef-color-black); then
[color](https://drafts.csswg.org/css-color-4/#propdef-color) is validly set to
[black](https://drafts.csswg.org/css-color-4/#valdef-color-black), rather than being [invalid at computed-value
time](https://drafts.csswg.org/css-values-5/#invalid-at-computed-value-time) and becoming
[inherit](https://drafts.csswg.org/css-cascade-5/#valdef-all-inherit).

### 4.2. The [`PropertyDefinition` Dictionary]
A [`PropertyDefinition`] dictionary represents
author-specified configuration options for a custom property.
[`PropertyDefinition`](#dictdef-propertydefinition) dictionaries contain the following members:

[`name`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString)

: The name of the custom property being defined.

[`syntax`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString), defaulting to `"*"`

: A string representing how this custom property is parsed.

[`inherits`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `true`

: True if this custom property should inherit down the DOM tree; False
 otherwise.

[`initialValue`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString)

: A string representing the initial value of this custom property.

Only the
[`name`](#dom-propertydefinition-name) is required; the other components default to how an
unregistered [custom
property](https://drafts.csswg.org/css-variables-2/#custom-property) works. (Accepting any value, inheriting, and using the
[guaranteed-invalid
value](https://drafts.csswg.org/css-variables-2/#guaranteed-invalid-value) by default.)

## 5. Syntax Strings

A [syntax string] describes the value types accepted by a registered custom
property. Syntax strings consists of [syntax component
names](#syntax-component-name), that are optionally [multiplied](#multipliers) and
[combined](#combinator).

A syntax string can be parsed into a [syntax
definition](#syntax-definition), which is either:

1. A list of [syntax
 components](#syntax-component), each of which accept the value types specified in
 [§ 5.1 Supported Names](#supported-names), or

2. The [universal syntax
 definition](#universal-syntax-definition) ([\*]), which accepts any valid token stream.

 Regardless of the syntax specified, all custom
properties accept [CSS-wide
keywords](https://drafts.csswg.org/css-values-4/#css-wide-keywords), and process these values appropriately.

For example, the following are all
valid syntax strings.

`"<length>"`

: accepts length values

`"<length> | <percentage>"`

: accepts lengths, percentages, percentage calc expressions, and
 length calc expressions, but not calc expressions containing a
 combination of length and percentage values.

`"<length-percentage>"`

: accepts all values that `"<length> | <percentage>"` would accept, as
 well as calc expressions containing a combination of both length and
 percentage values.

`"big | bigger | BIGGER"`

: accepts the ident `big`, or the ident `bigger`, or the ident
 `BIGGER`.

`"<length>+"`

: accepts a space-separated list of length values.

\"\*\"

: accepts any valid token stream

 The internal grammar of syntax strings is a subset of
[the CSS Value Definition
Syntax](https://drafts.csswg.org/css-values-3/#value-defs). Future
levels of this specification are expected to expand the complexity of
the allowed grammar, allowing custom properties that more closely
resemble the full breadth of what CSS properties allow.

The remainder of this chapter describes the internal grammar of the
syntax strings.

### 5.1. Supported Names

This section defines the [supported syntax component
names], and the corresponding types accepted by the resulting
[syntax component](#syntax-component).

\"\<length\>\"

: Any valid
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value) value

\"\<number\>\"

: [\<number\>](https://drafts.csswg.org/css-values-4/#number-value) values

\"\<percentage\>\"

: Any valid
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) value

\"\<length-percentage\>\"

: Any valid
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value) or
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) value, any valid
 [\<calc()\>](https://drafts.csswg.org/css-values-4/#funcdef-calc) expression combining
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value) and
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) components.

\"\<string\>\"

: Any valid
 [\<string\>](https://drafts.csswg.org/css-values-4/#string-value) value

\"\<color\>\"

: Any valid
 [\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) value

\"\<image\>\"

: Any valid
 [\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image) value

\"\<url\>\"

: Any valid
 [\<url\>](https://drafts.csswg.org/css-values-4/#url-value) value

\"\<integer\>\"

: Any valid
 [\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value) value

\"\<angle\>\"

: Any valid
 [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value) value

\"\<time\>\"

: Any valid
 [\<time\>](https://drafts.csswg.org/css-values-4/#time-value) value

\"\<resolution\>\"

: Any valid
 [\<resolution\>](https://drafts.csswg.org/css-values-4/#resolution-value) value

\"\<transform-function\>\"

: Any valid
 [\<transform-function\>](https://drafts.csswg.org/css-transforms-1/#typedef-transform-function) value

\"\<custom-ident\>\"

: Any valid
 [\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value) value

Any sequence which [starts an identifier](https://drafts.csswg.org/css-syntax-3/#would-start-an-identifier), [can be consumed as a name](https://drafts.csswg.org/css-syntax-3/#consume-name), and matches the [\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value) production

: That identifier

 [\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value)s are compared codepoint-wise with
 each other; this is different than the normal behavior of UA-defined
 CSS which limits itself to ASCII and is [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive). So, specifying an ident like `Red` means that the
 precise value
 [Red](https://drafts.csswg.org/css-color-4/#valdef-color-red) is accepted;
 [red](https://drafts.csswg.org/css-color-4/#valdef-color-red),
 [RED](https://drafts.csswg.org/css-color-4/#valdef-color-red), and any other casing variants are not
 matched by this. It is recommended that idents be restricted to
 ASCII and written in lower-case, to match CSS conventions.

\"\<transform-list\>\"

: A list of valid
 [\<transform-function\>](https://drafts.csswg.org/css-transforms-1/#typedef-transform-function) values. Note that
 `"<transform-list>"` is a [pre-multiplied data type
 name](#pre-multiplied-data-type-name) equivalent to `"<transform-function>+"`

 A syntax string of `"*"` will produce the [universal
syntax
definition](#universal-syntax-definition), which is not a [syntax
component](#syntax-component). Therefore, `"*"` may not be [multiplied](#multipliers)
or [combined](#combinator) with anything else.

### 5.2. The \'+\' and \'#\' Multipliers

Any [syntax component
name](#syntax-component-name) except [pre-multiplied data type
names](#pre-multiplied-data-type-name) may be immediately followed by a multiplier:

U+002B PLUS SIGN (+)

: Indicates a space-separated list.

U+0023 NUMBER SIGN (#)

: Indicates a comma-separated list.

`"<length>+"`

: accepts a space-separated list of length values

`"<color>#"`

: accepts a comma-separated list of color values

 The multiplier must appear immediately after the
[syntax component
name](#syntax-component-name) being multiplied.

### 5.3. The \'\|\' Combinator

[Syntax strings](#syntax-string) may use U+007C VERTICAL LINE (\|) to provide multiple
[syntax component
names](#syntax-component-name). Such syntax strings will result in a [syntax
definition](#syntax-definition) with multiple [syntax
components](#syntax-component).

When a [syntax
definition](#syntax-definition) with multiple [syntax
components](#syntax-component) is used to parse a CSS value, the syntax components are
matched in the order specified.

 That is, given the syntax string `"red | <color>"`,
matching the value
[red](https://drafts.csswg.org/css-color-4/#valdef-color-red) against it will parse as an identifier, while
matching the value
[blue](https://drafts.csswg.org/css-color-4/#valdef-color-blue) will parse as a
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color).

`"<length> | auto"`

: accepts a length, or auto

`"foo | <color># | <integer>"`

: accepts foo, a comma-separated list of color values, or a single
 integer

### 5.4. Parsing The Syntax String

#### 5.4.1. Definitions

[data type name]

: A sequence of [code
 points](https://infra.spec.whatwg.org/#code-point) consisting of a U+003C LESS-THAN SIGN (\<),
 followed be zero or more [ident code
 points](https://drafts.csswg.org/css-syntax-3/#ident-code-point), and terminated by U+003E GREATER-THAN SIGN (\>).

[pre-multiplied data type name]

: A [data type name](#data-type-name) that represents another [syntax
 component](#syntax-component) with a [multiplier](#multipliers) already included.

[syntax component]

: An object consisting of a [syntax component
 name](#syntax-component-name), and an optional [multiplier](#multipliers).

[syntax component name]

: A sequence of [code
 points](https://infra.spec.whatwg.org/#code-point) which is either a [data type
 name](#data-type-name), or
 a sequence that can produce a
 [\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value).

[syntax definition]

: An object consisting of a list of [syntax
 components](#syntax-component).

[universal syntax definition]

: A special syntax definition which accepts any valid token stream.

#### 5.4.2. Consume a Syntax Definition

This section describes how to [consume a syntax
definition] from a
[string](https://infra.spec.whatwg.org/#string) `string`. It either produces a [syntax
definition](#syntax-definition) with a list of [syntax
components](#syntax-component), or the [universal syntax
definition](#universal-syntax-definition).

1. [Strip leading and trailing ASCII
 whitespace](https://infra.spec.whatwg.org/#strip-leading-and-trailing-ascii-whitespace) from `string`.

2. If `string`'s
 [length](https://infra.spec.whatwg.org/#string-length) is 0, return failure.

3. If `string`'s
 [length](https://infra.spec.whatwg.org/#string-length) is 1, and the only [code
 point](https://infra.spec.whatwg.org/#code-point) in `string` is U+002A ASTERISK (\*),
 return the [universal syntax
 definition](#universal-syntax-definition).

4. Let `stream` be an [input
 stream](https://drafts.csswg.org/css-syntax-3/#input-stream) created from the [code
 points](https://infra.spec.whatwg.org/#code-point) of `string`, preprocessed as specified
 in
 [\[css-syntax-3\]](#biblio-css-syntax-3 "CSS Syntax Module Level 3").
 Let `definition` be an initially empty
 [list](https://infra.spec.whatwg.org/#list) of [syntax
 components](#syntax-component).

5. [Consume a syntax
 component](#consume-a-syntax-component) from `stream`. If failure was returned,
 return failure; otherwise,
 [append](https://infra.spec.whatwg.org/#list-append) the returned value to `definition`.

 Consume as much
 [whitespace](https://drafts.csswg.org/css-syntax-3/#whitespace) as possible from `stream`.

 Consume the [next input code
 point](https://drafts.csswg.org/css-syntax-3/#next-input-code-point) in `stream`:

 EOF

 : return `definition`.

 U+007C VERTICAL LINE (\|)

 : Repeat step 5.

 Anything else:

 : Return failure.

#### 5.4.3. Consume a Syntax Component

To [consume a syntax component] from a stream of [code
points](https://infra.spec.whatwg.org/#code-point) `stream`:

Consume as much
[whitespace](https://drafts.csswg.org/css-syntax-3/#whitespace) as possible from `stream`.

Let `component` be a new [syntax
component](#syntax-component) with its `name` and `multiplier`
initially empty.

Consume the [next input code
point](https://drafts.csswg.org/css-syntax-3/#next-input-code-point) in `stream`:

U+003C LESS-THAN SIGN (\<)

: [Consume a data type
 name](#consume-a-data-type-name) from `stream`. If it returned a
 [string](https://infra.spec.whatwg.org/#string), set `component`'s `name` to
 the returned value. Otherwise, return failure.

[ident-start code point](https://drafts.csswg.org/css-syntax-3/#ident-start-code-point)\
U+005C REVERSE SOLIDUS (\\)

: If the stream [starts with an ident
 sequence](https://drafts.csswg.org/css-syntax-3/#check-if-three-code-points-would-start-an-ident-sequence), [reconsume the current input code
 point](https://drafts.csswg.org/css-syntax-3/#reconsume-the-current-input-code-point) from `stream` then [consume an ident
 sequence](https://drafts.csswg.org/css-syntax-3/#consume-an-ident-sequence) from `stream`, and set
 `component`'s `name` to the returned value.
 Otherwise return failure.

 If `component`'s `name` does not
 [parse](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) as a
 [\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value), return failure.

anything else

: Return failure.

If `component`'s `name` is a [pre-multiplied data
type
name](#pre-multiplied-data-type-name), return `component`.

If the [next input code
point](https://drafts.csswg.org/css-syntax-3/#next-input-code-point) in `stream` is U+002B PLUS SIGN (+) or
U+0023 NUMBER SIGN (#), consume the [next input code
point](https://drafts.csswg.org/css-syntax-3/#next-input-code-point) from `stream`, and set
`component`'s `multiplier` to the [current input
code
point](https://drafts.csswg.org/css-syntax-3/#current-input-code-point).

Return `component`.

#### 5.4.4. Consume a Data Type Name

To [consume a data type name] from a stream of [code
points](https://infra.spec.whatwg.org/#code-point):

 This algorithm assumes that a U+003C LESS-THAN SIGN
(\<) [code
point](https://infra.spec.whatwg.org/#code-point) has already been consumed from the stream.

Let `name` initially be a
[string](https://infra.spec.whatwg.org/#string) containing a single U+003C LESS-THAN SIGN (\<) [code
point](https://infra.spec.whatwg.org/#code-point).

Repeatedly consume the [next input code
point](https://drafts.csswg.org/css-syntax-3/#next-input-code-point):

U+003E GREATER-THAN SIGN (\>)

: Append the [code
 point](https://infra.spec.whatwg.org/#code-point) to `name`. If `name` is a
 [supported syntax component
 name](#css-supported-syntax-component-name), return `name`. Otherwise return
 failure.

[ident code point](https://drafts.csswg.org/css-syntax-3/#ident-code-point)

: Append the [code
 point](https://infra.spec.whatwg.org/#code-point) to `name`.

anything else

: Return failure.

## 6. CSSOM

 The value specified for a registered custom property is
not interpreted until computed-value time. This means that only APIs
that retrieve computed values are affected. Other APIs must ignore the
[`[[registeredPropertySet]]`](#dom-window-registeredpropertyset-slot) slot of the associated
[`Document`](https://dom.spec.whatwg.org/#document), and treat all custom properties as unregistered.

### [6.1. ][The [`CSSPropertyRule`] Interface]
The [`CSSPropertyRule`](#csspropertyrule) interface represents an
[\@property](#at-ruledef-property) rule.

The CSSOM for multi-name
[\@property](#at-ruledef-property) rules has not been resolved on by the CSSWG.
[\[w3c/csswg-drafts Issue
#14227\]](https://github.com/w3c/csswg-drafts/issues/14227)

```
[Exposed=Window]
interface CSSPropertyRule : CSSRule {
 readonly attribute CSSOMString name;
 readonly attribute CSSOMString syntax;
 readonly attribute boolean inherits;
 readonly attribute CSSOMString? initialValue;
};
```

[`name`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring), readonly
: The custom property name associated with the
 [\@property](#at-ruledef-property) rule.

[`syntax`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring), readonly
: The syntax associated with the
 [\@property](#at-ruledef-property), exactly as specified.

[`inherits`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), readonly
: The inherits descriptor associated with the
 [\@property](#at-ruledef-property) rule.

[`initialValue`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring), readonly, nullable
: The initial value associated with the
 [\@property](#at-ruledef-property) rule, which may not be present.

To [serialize a CSSPropertyRule], return the concatenation of the
following:

1. The string `"@property"` followed by a single SPACE (U+0020).

2. The result of performing [serialize an
 identifier](https://drafts.csswg.org/cssom-1/#serialize-an-identifier) on the rule's name, followed by a single SPACE
 (U+0020).

3. The string `"{ "`, i.e., a single LEFT CURLY BRACKET (U+007B),
 followed by a SPACE (U+0020).

4. The string `"syntax:"`, followed by a single SPACE (U+0020).

5. The result of performing [serialize a
 string](https://drafts.csswg.org/cssom-1/#serialize-a-string) on the rule's
 [syntax](#descdef-property-syntax), followed by a single SEMICOLON
 (U+003B), followed by a SPACE (U+0020).

6. The string `"inherits:"`, followed by a single SPACE (U+0020).

7. For the rule's
 [inherits](#descdef-property-inherits) attribute, one of the following
 depending on the attribute's value:

 true

 : The string `"true"` followed by a single SEMICOLON (U+003B),
 followed by a SPACE (U+0020).

 false

 : The string `"false"` followed by a single SEMICOLON (U+003B),
 followed by a SPACE (U+0020).

8. If the rule's
 [initial-value](#descdef-property-initial-value) is present, follow these substeps:

 1. The string `"initial-value:"`.

 2. The result of performing [serialize a CSS
 value](https://drafts.csswg.org/cssom-1/#serialize-a-css-value) in the rule's
 [initial-value](#descdef-property-initial-value) followed by a single SEMICOLON
 (U+003B), followed by a SPACE (U+0020).

9. A single RIGHT CURLY BRACKET (U+007D).

### [6.2. ][[`CSSStyleValue`](https://drafts.css-houdini.org/css-typed-om-1/#cssstylevalue) Reification]
To [reify a registered custom property
value] given a property `property` and
[syntax definition](#syntax-definition) `syntax`, run these steps:

For specified values, [reify a list of component
values](https://drafts.css-houdini.org/css-typed-om-1/#reify-a-list-of-component-values) from the value, and return the result.

For computed values:

1. If the value is a
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value),
 [\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value),
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value),
 [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value),
 [\<time\>](https://drafts.csswg.org/css-values-4/#time-value),
 [\<resolution\>](https://drafts.csswg.org/css-values-4/#resolution-value),
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) or
 [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage); [reify a numeric
 value](https://drafts.css-houdini.org/css-typed-om-1/#reify-a-numeric-value) from the value and return the result.

2. If the value is a
 [\<transform-function\>](https://drafts.csswg.org/css-transforms-1/#typedef-transform-function), [reify a
 \<transform-function\>](https://drafts.css-houdini.org/css-typed-om-1/#reify-a-transform-function) from the value and return the result.

3. If the value is a
 [\<transform-list\>](https://drafts.csswg.org/css-transforms-1/#typedef-transform-list), [reify a
 \<transform-list\>](https://drafts.css-houdini.org/css-typed-om-1/#reify-a-transform-list) from the value and return the result.

4. If the value is an
 [\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image), reify a CSSImageValue from the
 value and return the result.

5. If the value is an
 [identifier](https://drafts.csswg.org/css-values-4/#css-css-identifier), [reify an
 identifier](https://drafts.css-houdini.org/css-typed-om-1/#reify-an-identifier) from the value and return the result.

6. If `syntax` is the [universal syntax
 definition](#universal-syntax-definition), [reify a list of component
 values](https://drafts.css-houdini.org/css-typed-om-1/#reify-a-list-of-component-values) from the value, and return the result.

7. Otherwise, [reify as a
 CSSStyleValue](https://drafts.css-houdini.org/css-typed-om-1/#reify-as-a-cssstylevalue) with the
 [`[[associatedProperty]]`](https://drafts.css-houdini.org/css-typed-om-1/#dom-cssstylevalue-associatedproperty-slot) internal slot set to `property`, and
 return the result.

## 7. Examples

### 7.1. Example 1: Using custom properties to add animation behavior

```
<script>
CSS.registerProperty({
 name: "--stop-color",
 syntax: "<color>",
 inherits: false,
 initialValue: "rgba(0,0,0,0)"
});
</script>

<style>
.button {
 --stop-color: red;
 background: linear-gradient(var(--stop-color), black);
 transition: --stop-color 1s;
}

.button:hover {
 --stop-color: green;
}
</style>
```

### 7.2. Example 2: Using [\@property to register a property]
```
<script>
 CSS.paintWorklet.addModule('circle.js');
</script>
<style>
 @property --radius {
 syntax: "<length>";
 inherits: false;
 initial-value: 0px;
 }

 div {
 width: 100px;
 height: 100px;
 --radius: 10px;
 background: paint(circle);
 transition: --radius 1s;
 }

 div:hover {
 --radius: 50px;
 }
</style>
<div></div>
```

```
// circle.js
registerPaint('circle', class {
 static get inputProperties() { return ['--radius']; }
 paint(ctx, geom, properties) {
 let radius = properties.get('--radius').value;
 ctx.fillStyle = 'black';
 ctx.beginPath();
 ctx.arc(geom.width / 2, geom.height / 2, radius, 0, 2 * Math.PI);
 ctx.fill();
 }
});
```

## 8. Security Considerations

There are no known security issues introduced by these features.

## 9. Privacy Considerations

There are no known privacy issues introduced by these features.

## 10. Changes

### [10.1. ][ Changes since the [Working Draft of 13 October 2020](https://www.w3.org/TR/2020/WD-css-properties-values-api-1-20201013/) ]
/\* to 20 March 2024 \*/

- Made \"initial-value\" have a \<declaration-value\>?, same as custom
 properties. ([#9078](https://github.com/w3c/csswg-drafts/issues/9078))

- Allowed \@Property in shadow trees.
 ([#1085](https://github.com/w3c/css-houdini-drafts/pull/1085))

- Added section explaining why property registration is global, rather
 than shadow-scoped.

- Exported the terms \"registered custom property\" and \"universal
 syntax definition\", for use in other specifications.
 ([#1020](https://github.com/w3c/css-houdini-drafts/pull/1020))

- Used the term \"invalid at computed-value time\" rather than
 \"guaranteed-invalid value\".
