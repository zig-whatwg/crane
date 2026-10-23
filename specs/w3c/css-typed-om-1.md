## 1. Introduction

CSS stylesheets are parsed into abstract UA-internal data structures,
the [internal representations] of CSS, which various specification
algorithms manipulate.

[Internal
representations](#css-internal-representation) can't be directly manipulated, as they are
implementation-dependent; UAs have to agree on how to *interpret* the
[internal
representations](#css-internal-representation), but the representations themselves are purposely left
undefined so that UAs can store and manipulate CSS in whatever way is
most efficient for them.

Previously, the only way to read or write to the [internal
representations](#css-internal-representation) was via strings---​stylesheets or the CSSOM allowed
authors to send strings to the UA, which were parsed into [internal
representations](#css-internal-representation), and the CSSOM allowed authors to request that the UA
serialize their [internal
representations](#css-internal-representation) back into strings.

This specification introduces a new way to interact with [internal
representations](#css-internal-representation), by representing them with specialized JS objects that
can be manipulated and understood more easily and more reliably than
string parsing/concatenation. This new approach is both easier for
authors (for example, numeric values are reflected with actual JS
numbers, and have unit-aware mathematical operations defined for them)
and in many cases are more performant, as values can be directly
manipulated and then cheaply translated back into [internal
representations](#css-internal-representation) without having to build and then parse strings of CSS.

## 2. [`CSSStyleValue` objects]
```
[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSStyleValue {
 stringifier;
 [Exposed=Window] static CSSStyleValue parse(USVString property, USVString cssText);
 [Exposed=Window] static sequence<CSSStyleValue> parseAll(USVString property, USVString cssText);
};
```

[`CSSStyleValue`](#cssstylevalue) objects are the base class of all CSS values accessible
via the Typed OM API.

The [stringification
behavior](#CSSStyleValue-stringification-behavior) of
[`CSSStyleValue`](#cssstylevalue) objects is defined in [§ 6 CSSStyleValue
Serialization](#stylevalue-serialization).

The
[`parse(``property``, ``cssText``)`] method, when invoked, must [parse a
CSSStyleValue](#parse-a-cssstylevalue) with property `property`, cssText
`cssText`, and parseMultiple set to false, and return the
result.

The
[`parseAll(``property``, ``cssText``)`] method, when invoked, must [parse a
CSSStyleValue](#parse-a-cssstylevalue) with property `property`, cssText
`cssText`, and parseMultiple set to true, and return the
result.

To [parse a CSSStyleValue] given a
[string](https://infra.spec.whatwg.org/#string) `property`, a
[string](https://infra.spec.whatwg.org/#string) `cssText`, and a `parseMultiple`
flag, run these steps:

1. If `property` is not a [custom property name
 string](#custom-property-name-string), set `property` to `property`
 [ASCII
 lowercased](https://infra.spec.whatwg.org/#ascii-lowercase).

2. If `property` is not a [valid CSS
 property](#valid-css-property),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

3. Attempt to
 [parse](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) `cssText` according to
 `property`'s grammar. If this fails,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror). Otherwise, let `whole value` be the
 parsed result.

 :::
 The behavior of custom properties are different when modified via
 JavaScript than when defined in style sheets.
 When a custom property is defined with an invalid syntax in a style
 sheet, then the value is recorded as \"unset\", to avoid having to
 reparse every style sheet when a custom property is registered.

 Conversely, when a custom property is modified via the JavaScript
 API, any parse errors are propagated to the progamming environment
 via a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror). This allows more immediate feedback of errors to
 developers.
 :::

4. [Subdivide into
 iterations](#subdivide-into-iterations) `whole value`, according to
 `property`, and let `values` be the result.

5. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `value` in `values`, replace
 it with the result of [reifying](#css-reify) `value` for `property`.

 (#issue-03265e97) Define the global.

6. If `parseMultiple` is false, return
 `values`\[0\]. Otherwise, return `values`.

To [subdivide into iterations] a CSS value
`whole value` for a property `property`, execute
the following steps:

1. If `property` is a [single-valued
 property](#single-valued-properties), return a
 [list](https://infra.spec.whatwg.org/#list) containing `whole value`.

2. Otherwise, divide `whole value` into individual
 iterations, as appropriate for `property`, and return a
 [list](https://infra.spec.whatwg.org/#list) containing the iterations in order.

How to divide a [list-valued
property](#list-valued-properties) into iterations is intentionally undefined and
hand-wavey at the moment. *Generally*, you just split it on top-level
commas (corresponding to a top-level `<foo>#` term in the grammar), but
some legacy properties (such as
[counter-reset](https://drafts.csswg.org/css-lists-3/#propdef-counter-reset)) don't separate their iterations
with commas.

It's expected to be rigorously defined in the future, but at the moment
is explicitly a \"you know what we mean\" thing.

### 2.1. Direct [`CSSStyleValue` Objects]
Values that can't yet be directly supported by a more specialized
[`CSSStyleValue`](#cssstylevalue) subclass are instead represented as
[`CSSStyleValue`](#cssstylevalue) objects.

Each [`CSSStyleValue`](#cssstylevalue) object is associated with a particular CSS property,
via its
[`[[associatedProperty]]`](#dom-cssstylevalue-associatedproperty-slot) internal slot, and a particular, immutable, [internal
representation](#css-internal-representation). These objects are said to \"represent\" the particular
[internal
representation](#css-internal-representation) they were [reified](#css-reify) from, such that if they are set back into a stylesheet
for the same property, they reproduce an equivalent [internal
representation](#css-internal-representation).

These [`CSSStyleValue`](#cssstylevalue) objects are only considered valid for the property that
they were parsed for. This is enforced by
[`CSSStyleValue`](#cssstylevalue) objects having a
[`[[associatedProperty]]`] internal slot, which is either `null` (the default) or a
[string](https://infra.spec.whatwg.org/#string) specifying a property name.

 This slot is checked by
[`StylePropertyMap`](#stylepropertymap).[`set()`](#dom-stylepropertymap-set)/[`append()`](#dom-stylepropertymap-append)

## 3. The [`StylePropertyMap`]
```
[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface StylePropertyMapReadOnly {
 iterable<USVString, sequence<CSSStyleValue>>;
 (undefined or CSSStyleValue) get(USVString property);
 sequence<CSSStyleValue> getAll(USVString property);
 boolean has(USVString property);
 readonly attribute unsigned long size;
};

[Exposed=Window]
interface StylePropertyMap : StylePropertyMapReadOnly {
 undefined set(USVString property, (CSSStyleValue or USVString)... values);
 undefined append(USVString property, (CSSStyleValue or USVString)... values);
 undefined delete(USVString property);
 undefined clear();
};
```

[`StylePropertyMap`](#stylepropertymap) is an alternate way to represent a [CSS declaration
block](https://drafts.csswg.org/cssom-1/#css-declaration-block) as an object (when fetched via the
[\[cssom\]](#biblio-cssom "CSS Object Model (CSSOM)"),
[CSS declaration
blocks](https://drafts.csswg.org/cssom-1/#css-declaration-block) are instead represented as
[`CSSStyleDeclaration`](https://drafts.csswg.org/cssom-1/#cssstyledeclaration) objects.)

[`StylePropertyMapReadOnly`](#stylepropertymapreadonly) object has a
[`[[declarations]]`] internal slot, which is a
[map](https://infra.spec.whatwg.org/#ordered-map) reflecting the [CSS declaration
block](https://drafts.csswg.org/cssom-1/#css-declaration-block)'s
[declarations](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-declarations).

 The
[declarations](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-declarations) are not yet defined using
[\[infra\]](#biblio-infra "Infra Standard")
terminology, but for the purpose of this spec it's assumed to be a
[map](https://infra.spec.whatwg.org/#ordered-map) whose keys are
[strings](https://infra.spec.whatwg.org/#string) (representing property names) and whose values are
[internal
representations](#css-internal-representation) for those properties.

Unless otherwise stated, the initial ordering of the
[`[[declarations]]`](#dom-stylepropertymapreadonly-declarations-slot) internal slot is based on the key of each entry:

1. Standardized properties (not [custom
 properties](https://drafts.csswg.org/css-variables-2/#custom-property) or vendor-prefixed properties), [ASCII
 lowercased](https://infra.spec.whatwg.org/#ascii-lowercase) and then sorted in increasing code-point order.

2. Vendor-prefixed/experimental properties (those whose name starts
 with a single dash), [ASCII
 lowercased](https://infra.spec.whatwg.org/#ascii-lowercase) and then sorted in increasing code-point order.

3. [Custom
 properties](https://drafts.csswg.org/css-variables-2/#custom-property), sorted in increasing code-point order. (These are
 never lower-cased; they are preserved exactly as written.)

The [value pairs to iterate
over](https://webidl.spec.whatwg.org/#dfn-value-pairs-to-iterate-over) for a
[`StylePropertyMapReadOnly`](#stylepropertymapreadonly) object `this` are obtained as follows:

1. Let `declarations` be `this`'s
 [`[[declarations]]`](#dom-stylepropertymapreadonly-declarations-slot) slot.

2. Let `value pairs` be an empty
 [list](https://infra.spec.whatwg.org/#list).

3. [For
 each](https://infra.spec.whatwg.org/#map-iterate) `prop` → `value` in
 `declarations`:

 1. Let `iterations` be the result of [dividing into
 iterations](#subdivide-into-iterations) `value`.

 2. [Reify](#css-reify) each
 [item](https://infra.spec.whatwg.org/#list-item) of `iterations`, and let
 `objects` be the result.

 3. Append `prop`/`objects` to
 `value pairs`.

4. Return `value pairs`.

Some CSS properties are [list-valued properties], such
as
[background-image](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-image) or
[animation](https://drafts.csswg.org/css-animations-1/#propdef-animation); their value is a list of parallel
grammar terms, almost always comma-separated (the only exceptions are
certain legacy properties like
[counter-reset](https://drafts.csswg.org/css-lists-3/#propdef-counter-reset)), indicating multiple distinct
\"values\" interpreted in the same way. Other properties, such as
[color](https://drafts.csswg.org/css-color-4/#propdef-color), are [single-valued
properties]; they take only a single (possibly
complex) value.

[w3c/css-houdini-drafts/644](https://github.com/w3c/css-houdini-drafts/issues/644)[\[css-typed-om\]Define precisely which
properties are list-valued and which aren\'t, probably in an
appendix.](https://github.com/w3c/css-houdini-drafts/issues/644)

There are multiple examples of CSS properties that have transitioned
from being
[single-valued](#single-valued-properties) to
[list-valued](#list-valued-properties). To ensure that code written at a time when a property
was
[single-valued](#single-valued-properties) does not break when it becomes
[list-valued](#list-valued-properties) in the future, the
[`StylePropertyMap`](#stylepropertymap) is a **multi-map**; it stores *list* of values for each
key, but allows you to interact with it as if there was only a single
value for each key as well.

This means that multiple values for a single property in a
[`StylePropertyMap`](#stylepropertymap) do not represent multiple successive definition of that
property's value; instead, they represent multiple comma-separated
sub-values in a single property value, like each \"layer\" in a
[background-image](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-image) property.

The [`get(``property``)`] method, when called on a
[`StylePropertyMapReadOnly`](#stylepropertymapreadonly) `this`, must perform the following steps:

1. If `property` is not a [custom property name
 string](#custom-property-name-string), set `property` to `property`
 [ASCII
 lowercased](https://infra.spec.whatwg.org/#ascii-lowercase).

2. If `property` is not a [valid CSS
 property](#valid-css-property),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

3. Let `props` be the value of `this`'s
 [`[[declarations]]`](#dom-stylepropertymapreadonly-declarations-slot) internal slot.

4. If `props`\[`property`\]
 [exists](https://infra.spec.whatwg.org/#map-exists), [subdivide into
 iterations](#subdivide-into-iterations) `props`\[`property`\], then
 [reify](#css-reify) the first
 item of the result and return it.

 Otherwise, return `undefined`.

 (#issue-03265e97①) Define the global.

[`getAll(``property``)`] method, when called on a
[`StylePropertyMapReadOnly`](#stylepropertymapreadonly) `this`, must perform the following steps:

1. If `property` is not a [custom property name
 string](#custom-property-name-string), set `property` to `property`
 [ASCII
 lowercased](https://infra.spec.whatwg.org/#ascii-lowercase).

2. If `property` is not a [valid CSS
 property](#valid-css-property),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

3. Let `props` be the value of `this`'s
 [`[[declarations]]`](#dom-stylepropertymapreadonly-declarations-slot) internal slot.

4. If `props`\[`property`\]
 [exists](https://infra.spec.whatwg.org/#map-exists), [subdivide into
 iterations](#subdivide-into-iterations) `props`\[`property`\], then
 [reify](#css-reify) each
 [item](https://infra.spec.whatwg.org/#list-item) of the result, and return the list.

 Otherwise, return an empty
 [list](https://infra.spec.whatwg.org/#list).

 (#issue-03265e97②) Define the global.

The [`has(``property``)`] method, when called on a
[`StylePropertyMapReadOnly`](#stylepropertymapreadonly) `this`, must perform the following steps:

1. If `property` is not a [custom property name
 string](#custom-property-name-string), set `property` to `property`
 [ASCII
 lowercased](https://infra.spec.whatwg.org/#ascii-lowercase).

2. If `property` is not a [valid CSS
 property](#valid-css-property),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

3. Let `props` be the value of `this`'s
 [`[[declarations]]`](#dom-stylepropertymapreadonly-declarations-slot) internal slot.

4. If `props`\[`property`\]
 [exists](https://infra.spec.whatwg.org/#map-exists), return `true`. Otherwise, return `false`.

The [`size`] attribute, on getting from a
[`StylePropertyMapReadOnly`](#stylepropertymapreadonly) `this`, must perform the following steps:

1. Return the
 [size](https://infra.spec.whatwg.org/#map-size) of the value of `this`'s
 [`[[declarations]]`](#dom-stylepropertymapreadonly-declarations-slot) internal slot.

[`set(``property``, ...``values``)`] method, when
called on a
[`StylePropertyMap`](#stylepropertymap) `this`, must perform the following steps:

1. If `property` is not a [custom property name
 string](#custom-property-name-string), set `property` to `property`
 [ASCII
 lowercased](https://infra.spec.whatwg.org/#ascii-lowercase).

2. If `property` is not a [valid CSS
 property](#valid-css-property),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

3. If `property` is a [single-valued
 property](#single-valued-properties) and `values` has more than one
 [item](https://infra.spec.whatwg.org/#list-item),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

4. If any of the
 [items](https://infra.spec.whatwg.org/#list-item) in `values` have a non-null
 [`[[associatedProperty]]`](#dom-cssstylevalue-associatedproperty-slot) internal slot, and that slot's value is anything
 other than `property`,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

5. If the
 [size](https://infra.spec.whatwg.org/#list-size) of `values` is two or more, and one or
 more of the
 [items](https://infra.spec.whatwg.org/#list-item) are a
 [`CSSUnparsedValue`](#cssunparsedvalue) or
 [`CSSVariableReferenceValue`](#cssvariablereferencevalue) object,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 Having 2+ values implies that you're setting
 multiple items of a list-valued property, but the presence of a
 [var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) function in the string-based OM disables all
 syntax parsing, including splitting into individual iterations
 (because there might be more commas inside of the
 [var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) value, so you can't tell how many items are
 actually going to show up). This step's restriction preserves the
 same semantics in the Typed OM.

6. Let `props` be the value of `this`'s
 [`[[declarations]]`](#dom-stylepropertymapreadonly-declarations-slot) internal slot.

7. If `props`\[`property`\]
 [exists](https://infra.spec.whatwg.org/#map-exists),
 [remove](https://infra.spec.whatwg.org/#map-remove) it.

8. Let `values to set` be an empty
 [list](https://infra.spec.whatwg.org/#list).

9. For each `value` in `values`, [create an
 internal
 representation](#create-an-internal-representation) for `property` and `value`,
 and append the result to `values to set`.

10. Set `props`\[`property`\] to
 `values to set`.

 The property is deleted then added back so that it gets
put at the end of the [ordered
map](https://infra.spec.whatwg.org/#ordered-map), which gives the expected behavior in the face of
[shorthand
properties](https://drafts.csswg.org/css-cascade-5/#shorthand-property).

[`append(``property``, ...``values``)`] method,
when called on a
[`StylePropertyMap`](#stylepropertymap) `this`, must perform the following steps:

1. If `property` is not a [custom property name
 string](#custom-property-name-string), set `property` to `property`
 [ASCII
 lowercased](https://infra.spec.whatwg.org/#ascii-lowercase).

2. If `property` is not a [valid CSS
 property](#valid-css-property),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

3. If `property` is not a [list-valued
 property](#list-valued-properties),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

4. If any of the
 [items](https://infra.spec.whatwg.org/#list-item) in `values` have a non-null
 [`[[associatedProperty]]`](#dom-cssstylevalue-associatedproperty-slot) internal slot, and that slot's value is anything
 other than `property`,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

5. If any of the
 [items](https://infra.spec.whatwg.org/#list-item) in `values` are a
 [`CSSUnparsedValue`](#cssunparsedvalue) or
 [`CSSVariableReferenceValue`](#cssvariablereferencevalue) object,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 When a property is set via string-based APIs, the
 presence of
 [var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) in a property prevents the entire thing from
 being interpreted. In other words, everything *besides* the
 [var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) is a plain [component
 value](https://drafts.csswg.org/css-syntax-3/#component-value), not a meaningful type. This step's restriction
 preserves the same semantics in the Typed OM.

6. Let `props` be the value of `this`'s
 [`[[declarations]]`](#dom-stylepropertymapreadonly-declarations-slot) internal slot.

7. If `props`\[`property`\] does not
 [exist](https://infra.spec.whatwg.org/#map-exists),
 [set](https://infra.spec.whatwg.org/#map-set) `props`\[`property`\] to an
 empty [list](https://infra.spec.whatwg.org/#list).

8. If `props`\[`property`\] contains a
 [var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) reference,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

9. Let `temp values` be an empty
 [list](https://infra.spec.whatwg.org/#list).

10. For each `value` in `values`, [create an
 internal
 representation](#create-an-internal-representation) with `property` and `value`,
 and
 [append](https://infra.spec.whatwg.org/#list-append) the returned value to `temp values`.

11. [Append](https://infra.spec.whatwg.org/#list-append) the entries of `temp values` to
 `props`\[`property`\].

The [`delete(``property``)`] method, when called on a
[`StylePropertyMap`](#stylepropertymap) `this`, must perform the following steps:

1. If `property` is not a [custom property name
 string](#custom-property-name-string), set `property` to `property`
 [ASCII
 lowercased](https://infra.spec.whatwg.org/#ascii-lowercase).

2. If `property` is not a [valid CSS
 property](#valid-css-property),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

3. If `this`'s
 [`[[declarations]]`](#dom-stylepropertymapreadonly-declarations-slot) internal slot
 [contains](https://infra.spec.whatwg.org/#map-exists) `property`,
 [remove](https://infra.spec.whatwg.org/#map-remove) it.

The [`clear()`] method, when
called on a
[`StylePropertyMap`](#stylepropertymap) `this`, must perform the following steps:

1. [Remove](https://infra.spec.whatwg.org/#map-remove) all of the declarations in `this`'s
 [`[[declarations]]`](#dom-stylepropertymapreadonly-declarations-slot) internal slot.

To [create an internal
representation], given a
[string](https://infra.spec.whatwg.org/#string) `property` and a
[string](https://infra.spec.whatwg.org/#string) or
[`CSSStyleValue`](#cssstylevalue) `value`:

If `value` is a direct [`CSSStyleValue`](#cssstylevalue),

: Return `value`'s associated value.

If `value` is a [`CSSStyleValue`](#cssstylevalue) subclass,

: If `value` does not [match the
 grammar](#cssstylevalue-match-a-grammar) of a [list-valued property
 iteration] of `property`,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 If any component of `property`'s CSS grammar has a
 limited numeric range, and the corresponding part of
 `value` is a
 [`CSSUnitValue`](#cssunitvalue) that is outside of that range, replace that value
 with the result of wrapping it in a fresh
 [`CSSMathSum`](#cssmathsum) whose
 [`values`](#dom-cssmathsum-values) internal slot contains only that part of
 `value`.

 If `value` is a
 [`CSSMathValue`](#cssmathvalue), replace it with the corresponding
 [simplified](https://drafts.csswg.org/css-values-4/#simplify-a-calculation-tree) value.

 Return the `value`.

If `value` is a [`USVString`](https://webidl.spec.whatwg.org/#idl-USVString),

: [Parse a
 CSSStyleValue](#parse-a-cssstylevalue) with property `property`, cssText
 `value`, and parseMultiple set to `false`, and return the
 result.

 This can throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) instead.

CSS properties express their valid inputs with grammars, which are
written with the assumption of being matched against strings parsed into
CSS tokens, as defined in [CSS Syntax 3 § 4
Tokenization](https://drafts.csswg.org/css-syntax-3/#tokenization).
[`CSSStyleValue`](#cssstylevalue) objects can also be matched against these grammars,
however.

A [`CSSStyleValue`](#cssstylevalue) is said to [match a
grammar] based on the following rules:

- A [`CSSKeywordValue`](#csskeywordvalue) matches an
 [\<ident\>](https://drafts.csswg.org/css-values-4/#typedef-ident) specified in a grammar if its
 [`value`](#dom-csskeywordvalue-value) internal slot matches the identifier.

 If case-folding rules are in effect normally for that
 [\<ident\>](https://drafts.csswg.org/css-values-4/#typedef-ident) (such as
 [Auto](https://drafts.csswg.org/css-position-3/#valdef-top-auto) matching the keyword
 [auto](https://drafts.csswg.org/css-position-3/#valdef-top-auto) specified in the grammar for
 [width](https://drafts.csswg.org/css-sizing-3/#propdef-width)), they apply to this comparison
 as well.

- A
 [`CSSTransformValue`](#csstransformvalue) matches
 [\<transform-list\>](https://drafts.csswg.org/css-transforms-1/#typedef-transform-list).

- A [`CSSNumericValue`](#cssnumericvalue) matches what its type
 [matches](#cssnumericvalue-match).

- A
 [`CSSUnparsedValue`](#cssunparsedvalue) matches any grammar.

- A direct
 [`CSSStyleValue`](#cssstylevalue) object (not a subclass) with a non-null
 [`[[associatedProperty]]`](#dom-cssstylevalue-associatedproperty-slot) slot matches the grammar of the property specified in
 its
 [`[[associatedProperty]]`](#dom-cssstylevalue-associatedproperty-slot) slot, regardless of what it is.

 As the ability to create more complex values in Typed
OM increases, this section will become more complex.

A [string](https://infra.spec.whatwg.org/#string) is a [custom property name
string] if it starts with two dashes (U+002D HYPHEN-MINUS), like
`--foo`. (This corresponds to the
[\<custom-property-name\>](https://drafts.csswg.org/css-variables-2/#typedef-custom-property-name) production, but applies to
[strings](https://infra.spec.whatwg.org/#string), rather than
[identifiers](https://drafts.csswg.org/css-values-4/#css-css-identifier); it can be used without invoking the CSS parser.)

A [string](https://infra.spec.whatwg.org/#string) is a [valid CSS property] if it is a [custom property name
string](#custom-property-name-string), or is a CSS property name recognized by the user
agent.

### 3.1. Computed [`StylePropertyMapReadOnly` objects]
```
partial interface Element {
 [SameObject] StylePropertyMapReadOnly computedStyleMap();
};
```

[Computed StylePropertyMap] objects represent the [computed
values](https://drafts.csswg.org/css-cascade-5/#computed-value) of an
[`Element`](https://dom.spec.whatwg.org/#element), and are accessed by calling the
[`computedStyleMap()`](#dom-element-computedstylemap) method.

Every
[`Element`](https://dom.spec.whatwg.org/#element) has a
[`[[computedStyleMapCache]]`] internal slot, initially set to `null`, which caches the
result of the
[`computedStyleMap()`](#dom-element-computedstylemap) method when it is first called.

The [`computedStyleMap()`]
method must, when called on an
[`Element`](https://dom.spec.whatwg.org/#element) `this`, perform the following steps:

1. If `this`'s
 [`[[computedStyleMapCache]]`](#dom-element-computedstylemapcache-slot) internal slot is set to `null`, set its value to a
 new
 [`StylePropertyMapReadOnly`](#stylepropertymapreadonly) object, whose
 [`[[declarations]]`](#dom-stylepropertymapreadonly-declarations-slot) internal slot are the name and [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) of every longhand CSS property supported by the
 User Agent, every registered [custom
 property](https://drafts.csswg.org/css-variables-2/#custom-property), and every non-registered [custom
 property](https://drafts.csswg.org/css-variables-2/#custom-property) which is not set to its initial value on
 `this`, in the standard order.

 The [computed
 values](https://drafts.csswg.org/css-cascade-5/#computed-value) in the
 [`[[declarations]]`](#dom-stylepropertymapreadonly-declarations-slot) of this object must remain up-to-date, changing as
 style resolution changes the properties on `this` and how
 they're computed.

 In practice, since the values are \"hidden\" behind
 a `.get()` method call, UAs can delay computing anything until a
 given property is actually requested.

2. Return `this`'s
 [`[[computedStyleMapCache]]`](#dom-element-computedstylemapcache-slot) internal slot.

[`Window.getComputedStyle()`](https://drafts.csswg.org/cssom-1/#dom-window-getcomputedstyle), this method can expose information from stylesheets
with the [origin-clean
flag](https://drafts.csswg.org/cssom-1/#concept-css-style-sheet-origin-clean-flag) unset.

 The
[`StylePropertyMapReadOnly`](#stylepropertymapreadonly) returned by this method represents the *actual*
[computed
values](https://drafts.csswg.org/css-cascade-5/#computed-value), not the [resolved
value](https://drafts.csswg.org/cssom-1/#resolved-value) concept used by
[`Window.getComputedStyle()`](https://drafts.csswg.org/cssom-1/#dom-window-getcomputedstyle). It can thus return different values than
[`Window.getComputedStyle()`](https://drafts.csswg.org/cssom-1/#dom-window-getcomputedstyle) for some properties (such as
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width)).

 Per [WG
resolution](https://github.com/w3c/css-houdini-drafts/issues/350#issuecomment-294690156),
pseudo-element styles are intended to be obtainable by adding this
method to the new [`PseudoElement`] interface
(rather than using a `pseudoElt` argument like
[`Window.getComputedStyle()`](https://drafts.csswg.org/cssom-1/#dom-window-getcomputedstyle) does).

### 3.2. Declared & Inline [`StylePropertyMap` objects]
```
partial interface CSSStyleRule {
 [SameObject] readonly attribute StylePropertyMap styleMap;
};

partial interface mixin ElementCSSInlineStyle {
 [SameObject] readonly attribute StylePropertyMap attributeStyleMap;
};
```

[Declared StylePropertyMap] objects represent style property-value pairs
embedded in a style rule or inline style, and are accessed via the
[`styleMap`] attribute of
[`CSSStyleRule`](https://drafts.csswg.org/cssom-1/#cssstylerule) objects, or the
[`attributeStyleMap`] attribute of objects implementing the
[`ElementCSSInlineStyle`](https://drafts.csswg.org/cssom-1/#elementcssinlinestyle) interface mixin (such as
[`HTMLElement`](https://html.spec.whatwg.org/multipage/dom.html#htmlelement)s).

When constructed, the
[`[[declarations]]`](#dom-stylepropertymapreadonly-declarations-slot) internal slot for [declared
StylePropertyMap](#declared-stylepropertymap) objects is initialized to contain an entry for each
property with a valid value inside the
[`CSSStyleRule`](https://drafts.csswg.org/cssom-1/#cssstylerule) or inline style that the object represents, in the same
order as the
[`CSSStyleRule`](https://drafts.csswg.org/cssom-1/#cssstylerule) or inline style.

## 4. [`CSSStyleValue` subclasses]
### 4.1. [`CSSUnparsedValue` objects]
```
[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSUnparsedValue : CSSStyleValue {
 constructor(sequence<CSSUnparsedSegment> members);
 iterable<CSSUnparsedSegment>;
 readonly attribute unsigned long length;
 getter CSSUnparsedSegment (unsigned long index);
 setter undefined (unsigned long index, CSSUnparsedSegment val);
};

typedef (USVString or CSSVariableReferenceValue) CSSUnparsedSegment;

[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSVariableReferenceValue {
 constructor(USVString variable, optional CSSUnparsedValue? fallback = null);
 attribute USVString variable;
 readonly attribute CSSUnparsedValue? fallback;
};
```

[`CSSUnparsedValue`](#cssunparsedvalue) objects represent property values that reference custom
properties. They are comprised of a list of string fragments and
variable references.

They have a [`[[tokens]]`] internal slot, which is a
[list](https://infra.spec.whatwg.org/#list) of
[`USVString`](https://webidl.spec.whatwg.org/#idl-USVString)s and
[`CSSVariableReferenceValue`](#cssvariablereferencevalue) objects. This list is the object's [values to iterate
over].

The [`length`] attribute
returns the
[size](https://infra.spec.whatwg.org/#list-size) of the
[`[[tokens]]`](#dom-cssunparsedvalue-tokens-slot) internal slot.

The [supported property
indexes](https://webidl.spec.whatwg.org/#dfn-supported-property-indices) of a
[`CSSUnparsedValue`](#cssunparsedvalue) `this` are the integers greater than or
equal to 0, and less than the
[size](https://infra.spec.whatwg.org/#list-size) of `this`'s
[`[[tokens]]`](#dom-cssunparsedvalue-tokens-slot) internal slot.

To [determine the value of an indexed
property](https://webidl.spec.whatwg.org/#dfn-determine-the-value-of-an-indexed-property) of a
[`CSSUnparsedValue`](#cssunparsedvalue) `this` and an index `n`, let
`tokens` be `this`'s
[`[[tokens]]`](#dom-cssunparsedvalue-tokens-slot) internal slot, and return
`tokens`\[`n`\].

To [set the value of an existing indexed
property](https://webidl.spec.whatwg.org/#dfn-set-the-value-of-an-existing-indexed-property) of a
[`CSSUnparsedValue`](#cssunparsedvalue) `this`, an index `n`, and a value
`new value`, let `tokens` be `this`'s
[`[[tokens]]`](#dom-cssunparsedvalue-tokens-slot) internal slot, and set
`tokens`\[`n`\] to `new value`.

To [set the value of a new indexed
property](https://webidl.spec.whatwg.org/#dfn-set-the-value-of-a-new-indexed-property) of a
[`CSSUnparsedValue`](#cssunparsedvalue) `this`, an index `n`, and a value
`new value`, let `tokens` be `this`'s
[`[[tokens]]`](#dom-cssunparsedvalue-tokens-slot) internal slot. If `n` is not equal to the
[size](https://infra.spec.whatwg.org/#list-size) of `tokens`,
[throw](https://webidl.spec.whatwg.org/#dfn-throw) a
[`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror). Otherwise,
[append](https://infra.spec.whatwg.org/#list-append) `new value` to `tokens`.

The getter for the [`variable`] attribute of a
[`CSSVariableReferenceValue`](#cssvariablereferencevalue) `this` must return its
[`variable`](#dom-cssvariablereferencevalue-variable) internal slot.

The
[`variable`](#dom-cssvariablereferencevalue-variable) attribute of a
[`CSSVariableReferenceValue`](#cssvariablereferencevalue) `this` must, on setting a variable
`variable`, perform the following steps:

1. If `variable` is not a [custom property name
 string](#custom-property-name-string),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

2. Otherwise, set `this`'s
 [`variable`](#dom-cssvariablereferencevalue-variable) internal slot to `variable`.

[`CSSVariableReferenceValue(``variable``, ``fallback``)`]
constructor must, when called, perform the following steps:

1. If `variable` is not a [custom property name
 string](#custom-property-name-string),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

2. Return a new
 [`CSSVariableReferenceValue`](#cssvariablereferencevalue) with its
 [`variable`](#dom-cssvariablereferencevalue-variable) internal slot set to `variable` and its
 [`fallback`](#dom-cssvariablereferencevalue-fallback) internal slot set to `fallback`.

### 4.2. [`CSSKeywordValue` objects]
[`CSSKeywordValue`](#csskeywordvalue) objects represent CSS keywords and other
[idents](https://drafts.csswg.org/css-values-4/#css-css-identifier).

```
[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSKeywordValue : CSSStyleValue {
 constructor(USVString value);
 attribute USVString value;
};
```

[`CSSKeywordValue(``value``)`] constructor must, when
called, perform the following steps:

1. If `value` is an empty string,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

2. Otherwise, return a new
 [`CSSKeywordValue`](#csskeywordvalue) with its
 [`value`](#dom-csskeywordvalue-value) internal slot set to `value`.

Any place that accepts a
[`CSSKeywordValue`](#csskeywordvalue) also accepts a raw
[`USVString`](https://webidl.spec.whatwg.org/#idl-USVString), by using the following typedef and algorithm:

```
typedef (DOMString or CSSKeywordValue) CSSKeywordish;
```

To [rectify a keywordish value] `val`, perform the
following steps:

1. If `val` is a
 [`CSSKeywordValue`](#csskeywordvalue), return `val`.

2. If `val` is a
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString), return a new
 [`CSSKeywordValue`](#csskeywordvalue) with its
 [`value`](#dom-csskeywordvalue-value) internal slot set to `val`.

The [`value`] attribute of a
[`CSSKeywordValue`](#csskeywordvalue) `this` must, on setting a value
`value`, perform the following steps:

1. If `value` is an empty string,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

2. Otherwise, set `this`'s
 [`value`](#dom-csskeywordvalue-value) internal slot, to `value`.

### 4.3. Numeric Values:

[`CSSNumericValue`](#cssnumericvalue) objects represent CSS values that are numeric in nature
([\<number\>](https://drafts.csswg.org/css-values-4/#number-value)s,
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value)s,
[\<dimension\>](https://drafts.csswg.org/css-values-4/#typedef-dimension)s). There are two interfaces that
inherit from
[`CSSNumericValue`](#cssnumericvalue):

- [`CSSUnitValue`](#cssunitvalue) objects represent values that contain a single unit
 type (for example \"42px\").

- [`CSSMathValue`](#cssmathvalue) objects represent math expressions, which can contain
 more than one value/unit (for example \"calc(56em + 10%)\").

[`CSSNumericValue`](#cssnumericvalue) objects are not range-restricted. Any valid numeric
value can be represented by a
[`CSSNumericValue`](#cssnumericvalue), and that value will not be clamped, rounded, or
rejected when set on a [declared
StylePropertyMap](#declared-stylepropertymap). Instead, clamping and/or rounding will occur during
computation of style.

The following code is valid

```
myElement.attributeStyleMap.set("opacity", CSS.number(3));
myElement.attributeStyleMap.set("z-index", CSS.number(15.4));

console.log(myElement.attributeStyleMap.get("opacity").value); // 3
console.log(myElement.attributeStyleMap.get("z-index").value); // 15.4

var computedStyle = myElement.computedStyleMap();
var opacity = computedStyle.get("opacity");
var zIndex = computedStyle.get("z-index");
```

After execution, the value of `opacity` is `1`
([opacity](https://drafts.csswg.org/css-color-4/#propdef-opacity) is range-restricted), and the value
of `zIndex` is `15`
([z-index](https://drafts.csswg.org/css2/#propdef-z-index) is rounded to an integer value).

 \"Numeric values\" which incorporate variable
references will instead be represented as
[`CSSUnparsedValue`](#cssunparsedvalue) objects, and keywords as
[`CSSKeywordValue`](#csskeywordvalue) objects.

Any place that accepts a
[`CSSNumericValue`](#cssnumericvalue) also accepts a raw
[`double`](https://webidl.spec.whatwg.org/#idl-double), by using the following typedef and algorithm:

```
typedef (double or CSSNumericValue) CSSNumberish;
```

To [rectify a numberish value] `num`, optionally to a
given unit `unit` (defaulting to \"number\"), perform the
following steps:

1. If `num` is a
 [`CSSNumericValue`](#cssnumericvalue), return `num`.

2. If `num` is a
 [`double`](https://webidl.spec.whatwg.org/#idl-double), return a new
 [`CSSUnitValue`](#cssunitvalue) with its
 [`value`](#dom-cssunitvalue-value) internal slot set to `num` and its
 [`unit`](#dom-cssunitvalue-unit) internal slot set to `unit`.

#### 4.3.1. Common Numeric Operations, and the [`CSSNumericValue` Superclass]
All numeric CSS values
([\<number\>](https://drafts.csswg.org/css-values-4/#number-value)s,
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value)s, and
[\<dimension\>](https://drafts.csswg.org/css-values-4/#typedef-dimension)s) are represented by subclasses of
the
[`CSSNumericValue`](#cssnumericvalue) interface.

```
enum CSSNumericBaseType {
 "length",
 "angle",
 "time",
 "frequency",
 "resolution",
 "flex",
 "percent",
};

dictionary CSSNumericType {
 long length;
 long angle;
 long time;
 long frequency;
 long resolution;
 long flex;
 long percent;
 CSSNumericBaseType percentHint;
};

[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSNumericValue : CSSStyleValue {
 CSSNumericValue add(CSSNumberish... values);
 CSSNumericValue sub(CSSNumberish... values);
 CSSNumericValue mul(CSSNumberish... values);
 CSSNumericValue div(CSSNumberish... values);
 CSSNumericValue min(CSSNumberish... values);
 CSSNumericValue max(CSSNumberish... values);

 boolean equals(CSSNumberish... value);

 CSSUnitValue to(USVString unit);
 CSSMathSum toSum(USVString... units);
 CSSNumericType type();

 [Exposed=Window] static CSSNumericValue parse(USVString cssText);
};
```

The methods on the
[`CSSNumericValue`](#cssnumericvalue) superclass represent operations that all numeric values
can perform.

The following are the arithmetic operations you can perform on
dimensions:

The [`add(...``values``)`] method, when called on a
[`CSSNumericValue`](#cssnumericvalue) `this`, must perform the following steps:

1. Replace each
 [item](https://infra.spec.whatwg.org/#list-item) of `values` with the result of
 [rectifying a numberish
 value](#rectify-a-numberish-value) for the
 [item](https://infra.spec.whatwg.org/#list-item).

2. If `this` is a
 [`CSSMathSum`](#cssmathsum) object,
 [prepend](https://infra.spec.whatwg.org/#list-prepend) the
 [items](https://infra.spec.whatwg.org/#list-item) in `this`'s
 [`values`](#dom-cssmathsum-values) internal slot to `values`. Otherwise,
 prepend `this` to `values`.

3. If all of the
 [items](https://infra.spec.whatwg.org/#list-item) in `values` are
 [`CSSUnitValue`](#cssunitvalue)s and have the same
 [`unit`](#dom-cssunitvalue-unit), return a new
 [`CSSUnitValue`](#cssunitvalue) whose
 [`unit`](#dom-cssunitvalue-unit) internal slot is set to that unit, and
 [`value`](#dom-cssunitvalue-value) internal slot is set to the sum of the
 [`value`](#dom-cssunitvalue-value) internal slots of the
 [items](https://infra.spec.whatwg.org/#list-item) in `values`. This addition must be done
 \"left to right\" - if `values` is « 1, 2, 3, 4 », the
 result must be (((1 + 2) + 3) + 4). (This detail is necessary to
 ensure interoperability in the presence of floating-point
 arithmetic.)

4. Let `type` be the result of
 [adding](#cssnumericvalue-add-two-types) the [types] of every
 [item](https://infra.spec.whatwg.org/#list-item) in `values`. If `type` is
 failure,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

5. Return a new [`CSSMathSum`](#cssmathsum) object whose
 [`values`](#dom-cssmathsum-values) internal slot is set to `values`.

The [`sub(...``values``)`] method, when called on a
[`CSSNumericValue`](#cssnumericvalue) `this`, must perform the following steps:

1. Replace each
 [item](https://infra.spec.whatwg.org/#list-item) of `values` with the result of
 [rectifying a numberish
 value](#rectify-a-numberish-value) for the
 [item](https://infra.spec.whatwg.org/#list-item), then
 [negating](#cssmath-negate-a-cssnumericvalue) the value.

2. Return the result of calling the
 [`add()`](#dom-cssnumericvalue-add) internal algorithm with `this` and
 `values`.

To [negate a
[`CSSNumericValue`](#cssnumericvalue)]
`this`:

1. If `this` is a
 [`CSSMathNegate`](#cssmathnegate) object, return `this`'s
 [`value`](#dom-cssmathnegate-value) internal slot.

2. If `this` is a
 [`CSSUnitValue`](#cssunitvalue) object, return a new
 [`CSSUnitValue`](#cssunitvalue) with the same
 [`unit`](#dom-cssunitvalue-unit) internal slot as `this`, and a
 [`value`](#dom-cssunitvalue-value) internal slot set to the negation of
 `this`'s.

3. Otherwise, return a new
 [`CSSMathNegate`](#cssmathnegate) object whose
 [`value`](#dom-cssmathnegate-value) internal slot is set to `this`.

The [`mul(...``values``)`] method, when called on a
[`CSSNumericValue`](#cssnumericvalue) `this`, must perform the following steps:

1. Replace each
 [item](https://infra.spec.whatwg.org/#list-item) of `values` with the result of
 [rectifying a numberish
 value](#rectify-a-numberish-value) for the
 [item](https://infra.spec.whatwg.org/#list-item).

2. If `this` is a
 [`CSSMathProduct`](#cssmathproduct) object,
 [prepend](https://infra.spec.whatwg.org/#list-prepend) the
 [items](https://infra.spec.whatwg.org/#list-item) in `this`'s
 [`values`](#dom-cssmathproduct-values) internal slot to `values`. Otherwise,
 prepend `this` to `values`.

3. If all of the
 [items](https://infra.spec.whatwg.org/#list-item) in `values` are
 [`CSSUnitValue`](#cssunitvalue)s with
 [`unit`](#dom-cssunitvalue-unit) internal slot set to \"number\", return a new
 [`CSSUnitValue`](#cssunitvalue) whose
 [`unit`](#dom-cssunitvalue-unit) internal slot is set to \"number\", and
 [`value`](#dom-cssunitvalue-value) internal slot is set to the product of the
 [`value`](#dom-cssunitvalue-value) internal slots of the
 [items](https://infra.spec.whatwg.org/#list-item) in `values`.

 This multiplication must be done \"left to right\" - if
 `values` is « 1, 2, 3, 4 », the result must be (((1 × 2)
 × 3) × 4). (This detail is necessary to ensure interoperability in
 the presence of floating-point arithmetic.)

4. If all of the
 [items](https://infra.spec.whatwg.org/#list-item) in `values` are
 [`CSSUnitValue`](#cssunitvalue)s with
 [`unit`](#dom-cssunitvalue-unit) internal slot set to \"number\" except one which is
 set to `unit`, return a new
 [`CSSUnitValue`](#cssunitvalue) whose
 [`unit`](#dom-cssunitvalue-unit) internal slot is set to `unit`, and
 [`value`](#dom-cssunitvalue-value) internal slot is set to the product of the
 [`value`](#dom-cssunitvalue-value) internal slots of the
 [items](https://infra.spec.whatwg.org/#list-item) in `values`.

 This multiplication must be done \"left to right\" - if
 `values` is « 1, 2, 3, 4 », the result must be (((1 × 2)
 × 3) × 4).

5. Let `type` be the result of
 [multiplying](#cssnumericvalue-multiply-two-types) the [types] of every
 [item](https://infra.spec.whatwg.org/#list-item) in `values`. If `type` is
 failure,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

6. Return a new
 [`CSSMathProduct`](#cssmathproduct) object whose
 [`values`](#dom-cssmathproduct-values) internal slot is set to `values`.

The [`div(...``values``)`] method, when called on a
[`CSSNumericValue`](#cssnumericvalue) `this`, must perform the following steps:

1. Replace each
 [item](https://infra.spec.whatwg.org/#list-item) of `values` with the result of
 [rectifying a numberish
 value](#rectify-a-numberish-value) for the
 [item](https://infra.spec.whatwg.org/#list-item), then
 [inverting](#cssmath-invert-a-cssnumericvalue) the value.

2. Return the result of calling the
 [`mul()`](#dom-cssnumericvalue-mul) internal algorithm with `this` and
 `values`.

To [invert a
[`CSSNumericValue`](#cssnumericvalue)]
`this`:

1. If `this` is a
 [`CSSMathInvert`](#cssmathinvert) object, return `this`'s
 [`value`](#dom-cssmathinvert-value) internal slot.

2. If `this` is a
 [`CSSUnitValue`](#cssunitvalue) object with
 [`unit`](#dom-cssunitvalue-unit) internal slot set to \"number\":

 1. If `this`'s
 [`value`](#dom-cssunitvalue-value) internal slot is set to 0 or -0,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror).

 2. Else return a new
 [`CSSUnitValue`](#cssunitvalue) with the
 [`unit`](#dom-cssunitvalue-unit) internal slot set to \"number\", and a
 [`value`](#dom-cssunitvalue-value) internal slot set to 1 divided by
 `this`'s
 [`value`](#dom-cssunitvalue-value) internal slot.

3. Otherwise, return a new
 [`CSSMathInvert`](#cssmathinvert) object whose
 [`value`](#dom-cssmathinvert-value) internal slot is set to `this`.

The [`min(...``values``)`] method, when called on a
[`CSSNumericValue`](#cssnumericvalue) `this`, must perform the following steps:

1. Replace each
 [item](https://infra.spec.whatwg.org/#list-item) of `values` with the result of
 [rectifying a numberish
 value](#rectify-a-numberish-value) for the
 [item](https://infra.spec.whatwg.org/#list-item).

2. If `this` is a
 [`CSSMathMin`](#cssmathmin) object,
 [prepend](https://infra.spec.whatwg.org/#list-prepend) the
 [items](https://infra.spec.whatwg.org/#list-item) in `this`'s
 [`values`](#dom-cssmathmin-values) internal slot to `values`. Otherwise,
 prepend `this` to `values`.

3. If all of the
 [items](https://infra.spec.whatwg.org/#list-item) in `values` are
 [`CSSUnitValue`](#cssunitvalue)s and have the same
 [`unit`](#dom-cssunitvalue-unit), return a new
 [`CSSUnitValue`](#cssunitvalue) whose
 [`unit`](#dom-cssunitvalue-unit) internal slot is set to that unit, and
 [`value`](#dom-cssunitvalue-value) internal slot is set to the minimum of the
 [`value`](#dom-cssunitvalue-value) internal slots of the
 [items](https://infra.spec.whatwg.org/#list-item) in `values`.

4. Let `type` be the result of
 [adding](#cssnumericvalue-add-two-types) the [types] of every
 [item](https://infra.spec.whatwg.org/#list-item) in `values`. If `type` is
 failure,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

5. Return a new [`CSSMathMin`](#cssmathmin) object whose
 [`values`](#dom-cssmathmin-values) internal slot is set to `values`.

The [`max(...``values``)`] method, when called on a
[`CSSNumericValue`](#cssnumericvalue) `this`, must perform the following steps:

1. Replace each
 [item](https://infra.spec.whatwg.org/#list-item) of `values` with the result of
 [rectifying a numberish
 value](#rectify-a-numberish-value) for the
 [item](https://infra.spec.whatwg.org/#list-item).

2. If `this` is a
 [`CSSMathMax`](#cssmathmax) object,
 [prepend](https://infra.spec.whatwg.org/#list-prepend) the
 [items](https://infra.spec.whatwg.org/#list-item) in `this`'s
 [`values`](#dom-cssmathmax-values) internal slot to `values`. Otherwise,
 prepend `this` to `values`.

3. If all of the
 [items](https://infra.spec.whatwg.org/#list-item) in `values` are
 [`CSSUnitValue`](#cssunitvalue)s and have the same
 [`unit`](#dom-cssunitvalue-unit), return a new
 [`CSSUnitValue`](#cssunitvalue) whose
 [`unit`](#dom-cssunitvalue-unit) internal slot is set to that unit, and
 [`value`](#dom-cssunitvalue-value) internal slot is set to the maximum of the
 [`value`](#dom-cssunitvalue-value) internal slots of the
 [items](https://infra.spec.whatwg.org/#list-item) in `values`.

4. Let `type` be the result of
 [adding](#cssnumericvalue-add-two-types) the [types] of every
 [item](https://infra.spec.whatwg.org/#list-item) in `values`. If `type` is
 failure,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

5. Return a new [`CSSMathMax`](#cssmathmax) object whose
 [`values`](#dom-cssmathmax-values) internal slot is set to `values`.

The [`equals(...``values``)`] method, when
called on a
[`CSSNumericValue`](#cssnumericvalue) `this`, must perform the following steps:

1. Replace each
 [item](https://infra.spec.whatwg.org/#list-item) of `values` with the result of
 [rectifying a numberish
 value](#rectify-a-numberish-value) for the
 [item](https://infra.spec.whatwg.org/#list-item).

2. For each
 [item](https://infra.spec.whatwg.org/#list-item) in `values`, if the
 [item](https://infra.spec.whatwg.org/#list-item) is not an [equal numeric
 value](#equal-numeric-value) to `this`, return `false`.

3. Return `true`.

This notion of equality is purposely fairly exacting; all the values
must be the exact same type and value, in the same order. For example,
`CSSMathSum(CSS.px(1), CSS.px(2))` is *not* equal to
`CSSMathSum(CSS.px(2), CSS.px(1))`.

This precise notion is used because it allows structural equality to be
tested for very quickly; if we were to use a slower and more forgiving
notion of equality, such as allowing the arguments to match in any
order, we'd probably want to go all the way and perform other
simplifications, like considering [96px] to be equal to
[1in]; this looser notion of equality might be added in the
future.

To determine whether two
[`CSSNumericValue`](#cssnumericvalue)s `value1` and `value2` are [equal
numeric values], perform the following steps:

1. If `value1` and `value2` are not members of
 the same interface, return `false`.

2. If `value1` and `value2` are both
 [`CSSUnitValue`](#cssunitvalue)s, return `true` if they have equal
 [`unit`](#dom-cssunitvalue-unit) and
 [`value`](#dom-cssunitvalue-value) internal slots, or `false` otherwise.

3. If `value1` and `value2` are both
 [`CSSMathSum`](#cssmathsum)s,
 [`CSSMathProduct`](#cssmathproduct)s,
 [`CSSMathMin`](#cssmathmin)s, or
 [`CSSMathMax`](#cssmathmax)s:

 1. If `value1`'s
 [`values`](#dom-cssmathsum-values) and `value2`s
 [`values`](#dom-cssmathsum-values) internal slots have different
 [sizes](https://infra.spec.whatwg.org/#list-size), return `false`.

 2. If any
 [item](https://infra.spec.whatwg.org/#list-item) in `value1`'s
 [`values`](#dom-cssmathsum-values) internal slot is not an [equal numeric
 value](#equal-numeric-value) to the
 [item](https://infra.spec.whatwg.org/#list-item) in `value2`'s
 [`values`](#dom-cssmathsum-values) internal slot at the same index, return
 `false`.

 3. Return `true`.

4. Assert: `value1` and `value2` are both
 [`CSSMathNegate`](#cssmathnegate)s or
 [`CSSMathInvert`](#cssmathinvert)s.

5. Return whether `value1`'s
 [`value`](#dom-cssmathnegate-value) and `value2`'s
 [`value`](#dom-cssmathnegate-value) are [equal numeric
 values](#equal-numeric-value).

The [`to(``unit``)`] method converts an existing
[`CSSNumericValue`](#cssnumericvalue) `this` into another one with the specified
`unit`, if possible. When called, it must perform the
following steps:

1. Let `type` be the result of [creating a
 type](#cssnumericvalue-create-a-type) from `unit`. If `type` is
 failure,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

2. Let `sum` be the result of [creating a sum
 value](#create-a-sum-value) from `this`. If `sum` is
 failure,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

3. If `sum` has more than one
 [item](https://infra.spec.whatwg.org/#list-item),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror). Otherwise, let `item` be the result of
 [creating a
 CSSUnitValue](#create-a-cssunitvalue-from-a-sum-value-item) from the sole
 [item](https://infra.spec.whatwg.org/#list-item) in `sum`, then
 [converting](#convert-a-cssunitvalue) it to `unit`. If `item` is
 failure,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

4. Return `item`.

When asked to [create a CSSUnitValue from a sum value
item] `item`, perform the following
steps:

1. If `item` has more than one
 [entry](https://infra.spec.whatwg.org/#map-entry) in its [unit
 map](#sum-value-unit-map), return failure.

2. If `item` has no
 [entries](https://infra.spec.whatwg.org/#map-entry) in its [unit
 map](#sum-value-unit-map), return a new
 [`CSSUnitValue`](#cssunitvalue) whose
 [`unit`](#dom-cssunitvalue-unit) internal slot is set to \"number\", and whose
 [`value`](#dom-cssunitvalue-value) internal slot is set to `item`'s
 [value](#sum-value-value).

3. Otherwise, `item` has a single
 [entry](https://infra.spec.whatwg.org/#map-entry) in its [unit
 map](#sum-value-unit-map). If that
 [entry's](https://infra.spec.whatwg.org/#map-entry)
 [value](https://infra.spec.whatwg.org/#map-value) is anything other than `1`, return failure.

4. Otherwise, return a new
 [`CSSUnitValue`](#cssunitvalue) whose
 [`unit`](#dom-cssunitvalue-unit) internal slot is set to that
 [entry's](https://infra.spec.whatwg.org/#map-entry)
 [key](https://infra.spec.whatwg.org/#map-key), and whose
 [`value`](#dom-cssunitvalue-value) internal slot is set to `item`'s
 [value](#sum-value-value).

The [`toSum(...``units``)`] method converts an existing
[`CSSNumericValue`](#cssnumericvalue) `this` into a
[`CSSMathSum`](#cssmathsum)
of only [`CSSUnitValue`](#cssunitvalue)s with the specified units, if possible. (It's like
[`to()`](#dom-cssnumericvalue-to), but allows the result to have multiple units in it.)
If called without any units, it just simplifies `this` into a
minimal sum of
[`CSSUnitValue`](#cssunitvalue)s.

When called, it must perform the following steps:

1. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `unit` in `units`, if the
 result of [creating a
 type](#cssnumericvalue-create-a-type) from `unit` is failure,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

2. Let `sum` be the result of [creating a sum
 value](#create-a-sum-value) from `this`. If `sum` is
 failure,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

3. Let `values` be the result of [creating a
 CSSUnitValue](#create-a-cssunitvalue-from-a-sum-value-item) [for
 each](https://infra.spec.whatwg.org/#list-iterate)
 [item](https://infra.spec.whatwg.org/#list-item) in `sum`. If any
 [item](https://infra.spec.whatwg.org/#list-item) of `values` is failure,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

4. If `units` is
 [empty](https://infra.spec.whatwg.org/#list-empty), sort `values` in [code
 point](https://infra.spec.whatwg.org/#code-point) order according to the
 [`unit`](#dom-cssunitvalue-unit) internal slot of its
 [items](https://infra.spec.whatwg.org/#list-item), then return a new
 [`CSSMathSum`](#cssmathsum) object whose
 [`values`](#dom-cssmathsum-values) internal slot is set to `values`.

5. Otherwise, let `result` initially be an empty
 [list](https://infra.spec.whatwg.org/#list). [For
 each](https://infra.spec.whatwg.org/#list-iterate) `unit` in `units`:

 1. Let `temp` initially be a new
 [`CSSUnitValue`](#cssunitvalue) whose
 [`unit`](#dom-cssunitvalue-unit) internal slot is set to `unit` and
 whose
 [`value`](#dom-cssunitvalue-value) internal slot is set to `0`.

 2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `value` in `values`:

 1. Let `value unit` be `value`'s
 [`unit`](#dom-cssunitvalue-unit) internal slot.

 2. If `value unit` is a [compatible
 unit](https://drafts.csswg.org/css-values-4/#compatible-units) with `unit`, then:

 1. [Convert](#convert-a-cssunitvalue) `value` to
 `unit`.

 2. Increment `temp`'s
 [`value`](#dom-cssunitvalue-value) internal slot by the value of
 `value`'s
 [`value`](#dom-cssunitvalue-value) internal slot.

 3. [Remove](https://infra.spec.whatwg.org/#list-remove) `value` from
 `values`.

 3. [Append](https://infra.spec.whatwg.org/#list-append) `temp` to `result`.

6. If `values` is not
 [empty](https://infra.spec.whatwg.org/#list-empty),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror). [`this` had units that you didn't ask
 for.]

7. Return a new [`CSSMathSum`](#cssmathsum) object whose
 [`values`](#dom-cssmathsum-values) internal slot is set to `result`.

The [`type()`] method returns a
representation of the [type] of `this`.

When called, it must perform the following steps:

1. Let `result` be a new
 [`CSSNumericType`](#dictdef-cssnumerictype).

2. For each `baseType` → `power` in the
 [type] of `this`,

 1. If `power` is not 0, set
 `result`\[`baseType`\] to
 `power`.

3. If the [percent
 hint](#cssnumericvalue-percent-hint) of `this` is not null,

 1. Set `result`\[`percentHint`\] to the
 [percent
 hint](#cssnumericvalue-percent-hint) of `this`.

4. Return `result`.

A [sum value] is an abstract
representation of a
[`CSSNumericValue`](#cssnumericvalue) as a sum of numbers with (possibly complex) units. Not
all
[`CSSNumericValue`](#cssnumericvalue)s can be expressed as a [sum
value](#cssnumericvalue-sum-value).

A [sum
value](#cssnumericvalue-sum-value) is a
[list](https://infra.spec.whatwg.org/#list). Each entry in the list is a
[tuple](https://infra.spec.whatwg.org/#tuple) of a [value], which is a number, and a
[unit map], which is a
[map](https://infra.spec.whatwg.org/#ordered-map) of units (strings) to powers (integers).

Here are a few examples of CSS values,
and their equivalent [sum
values](#cssnumericvalue-sum-value):

- [1px] becomes `«(1, «["px" → 1]»)»`

- [calc(1px + 1in)] becomes `«(97, «["px" → 1]»)»` (because
 [in](https://drafts.csswg.org/css-values-4/#in) and
 [px](https://drafts.csswg.org/css-values-4/#px) are [compatible
 units](https://drafts.csswg.org/css-values-4/#compatible-units), and
 [px](https://drafts.csswg.org/css-values-4/#px) is the [canonical
 unit](https://drafts.csswg.org/css-values-4/#canonical-unit) for them)

- [calc(1px + 2em)] becomes
 `«(1, «["px" → 1]»), (2, «["em" → 1]»)»`

- [calc(1px + 2%)] becomes
 `«(1, «["px" → 1]»), (2, «["percent" → 1]»)»` (percentages are allowed
 to add to other units, but aren't resolved into another unit, like
 they are in a [type])

- [calc(1px \* 2em)] becomes `«(2, «["em" → 1, "px" → 1]»)»`

- [calc(1px + 1deg)] can't be represented as a [sum
 value](#cssnumericvalue-sum-value) because it's an invalid computation

- [calc(1px \* 2deg)] becomes `«(2, «["deg" → 1, "px" → 1]»)»`

To [create a sum value]
from a
[`CSSNumericValue`](#cssnumericvalue) `this`, the steps differ based on
`this`'s class:

[`CSSUnitValue`](#cssunitvalue)

: :::
 1. Let `unit` be the value of `this`'s
 [`unit`](#dom-cssunitvalue-unit) internal slot, and `value` be the
 value of `this`'s
 [`value`](#dom-cssunitvalue-value) internal slot.

 2. If `unit` is a member of a set of [compatible
 units](https://drafts.csswg.org/css-values-4/#compatible-units), and is not the set's [canonical
 unit](https://drafts.csswg.org/css-values-4/#canonical-unit), multiply `value` by the conversion
 ratio between `unit` and the [canonical
 unit](https://drafts.csswg.org/css-values-4/#canonical-unit), and change `unit` to the [canonical
 unit](https://drafts.csswg.org/css-values-4/#canonical-unit).

 3. If `unit` is `"number"`, return «(`value`,
 «\[ \]»)».

 4. Otherwise, return
 `«(``value``, «[``unit`` → 1]»)»`.
 :::

[`CSSMathSum`](#cssmathsum)

: :::
 1. Let `values` initially be an empty
 [list](https://infra.spec.whatwg.org/#list).

 2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `item` in `this`'s
 [`values`](#dom-cssmathsum-values) internal slot:

 1. Let `value` be the result of [creating a sum
 value](#create-a-sum-value) from `item`. If
 `value` is failure, return failure.

 2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `subvalue` of
 `value`:

 1. If `values` already contains an
 [item](https://infra.spec.whatwg.org/#list-item) with the same [unit
 map](#sum-value-unit-map) as `subvalue`, increment
 that
 [item](https://infra.spec.whatwg.org/#list-item)'s
 [value](#sum-value-value) by the
 [value](#sum-value-value) of `subvalue`.

 2. Otherwise,
 [append](https://infra.spec.whatwg.org/#list-append) `subvalue` to
 `values`.

 3. [Create a
 type](#create-a-type-from-a-unit-map) from the [unit
 map](#sum-value-unit-map) of each
 [item](https://infra.spec.whatwg.org/#list-item) of `values`, and
 [add](#cssnumericvalue-add-two-types) all the types together. If the result is
 failure, return failure.

 4. Return `values`.
 :::

[`CSSMathNegate`](#cssmathnegate)

: :::
 1. Let `values` be the result of [creating a sum
 value](#create-a-sum-value) from `this`'s
 [`value`](#dom-cssmathnegate-value) internal slot.

 2. If `values` is failure, return failure.

 3. Negate the [value](#sum-value-value) of each
 [item](https://infra.spec.whatwg.org/#list-item) of `values`.

 4. Return `values`.
 :::

[`CSSMathProduct`](#cssmathproduct)

: :::
 1. Let `values` initially be the [sum
 value](#cssnumericvalue-sum-value) «(1, «\[ \]»)». (I.e. what you'd get from
 [1].)

 2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `item` in `this`'s
 [`values`](#dom-cssmathproduct-values) internal slot:

 1. Let `new values` be the result of [creating a sum
 value](#create-a-sum-value) from `item`. Let
 `temp` initially be an empty
 [list](https://infra.spec.whatwg.org/#list).

 2. If `new values` is failure, return failure.

 3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `item1` in `values`:

 1. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `item2` in
 `new values`:

 1. Let `item` be a
 [tuple](https://infra.spec.whatwg.org/#tuple) with its
 [value](#sum-value-value) set to the product of the
 [values](#sum-value-value) of `item1` and
 `item2`, and its [unit
 map](#sum-value-unit-map) set to the
 [product](#product-of-two-unit-maps) of the [unit
 maps](#sum-value-unit-map) of `item1` and
 `item2`, with all
 [entries](https://infra.spec.whatwg.org/#map-entry) with a zero value removed.

 2. Append `item` to `temp`.

 4. Set `values` to `temp`.

 3. Return `values`.
 :::

[`CSSMathInvert`](#cssmathinvert)

: :::
 1. Let `values` be the result of [creating a sum
 value](#create-a-sum-value) from `this`'s
 [`value`](#dom-cssmathinvert-value) internal slot.

 2. If `values` is failure, return failure.

 3. If the length of `values` is more than one, return
 failure.

 4. Invert (find the reciprocal of) the
 [value](#sum-value-value) of the
 [item](https://infra.spec.whatwg.org/#list-item) in `values`, and negate the
 [value](https://infra.spec.whatwg.org/#map-value) of each
 [entry](https://infra.spec.whatwg.org/#map-entry) in its [unit
 map](#sum-value-unit-map).

 5. Return `values`.
 :::

[`CSSMathMin`](#cssmathmin)

: :::
 1. Let `args` be the result of [creating a sum
 value](#create-a-sum-value) [for
 each](https://infra.spec.whatwg.org/#list-iterate)
 [item](https://infra.spec.whatwg.org/#list-item) in `this`'s
 [`values`](#dom-cssmathmin-values) internal slot.

 2. If any
 [item](https://infra.spec.whatwg.org/#list-item) of `args` is failure, or has a
 length greater than one, return failure.

 3. If not all of the [unit
 maps](#sum-value-unit-map) among the
 [items](https://infra.spec.whatwg.org/#list-item) of `args` are identical, return
 failure.

 4. Return the
 [item](https://infra.spec.whatwg.org/#list-item) of `args` whose sole
 [item](https://infra.spec.whatwg.org/#list-item) has the smallest
 [value](#sum-value-value).
 :::

[`CSSMathMax`](#cssmathmax)

: :::
 1. Let `args` be the result of [creating a sum
 value](#create-a-sum-value) [for
 each](https://infra.spec.whatwg.org/#list-iterate)
 [item](https://infra.spec.whatwg.org/#list-item) in `this`'s
 [`values`](#dom-cssmathmax-values) internal slot.

 2. If any
 [item](https://infra.spec.whatwg.org/#list-item) of `args` is failure, or has a
 length greater than one, return failure.

 3. If not all of the [unit
 maps](#sum-value-unit-map) among the
 [items](https://infra.spec.whatwg.org/#list-item) of `args` are identical, return
 failure.

 4. Return the
 [item](https://infra.spec.whatwg.org/#list-item) of `args` whose sole
 [item](https://infra.spec.whatwg.org/#list-item) has the largest
 [value](#sum-value-value).
 :::

To [create a type from a unit map] `unit map`:

1. Let `types` be an initially empty
 [list](https://infra.spec.whatwg.org/#list).

2. [For
 each](https://infra.spec.whatwg.org/#map-iterate) `unit` → `power` in
 `unit map`:

 1. Let `type` be the result of [creating a
 type](#cssnumericvalue-create-a-type) from `unit`.

 2. Set `type`'s sole
 [value](https://infra.spec.whatwg.org/#map-value) to `power`.

 3. [Append](https://infra.spec.whatwg.org/#list-append) `type` to `types`.

3. Return the result of
 [multiplying](#cssnumericvalue-multiply-two-types) all the
 [items](https://infra.spec.whatwg.org/#list-item) of `types`.

The [product of two unit maps] `units1` and
`units2` is the result given by the following steps:

1. Let `result` be a copy of `units1`.

2. [For
 each](https://infra.spec.whatwg.org/#map-iterate) `unit` → `power` in
 `units2`:

 1. If `result`\[`unit`\]
 [exists](https://infra.spec.whatwg.org/#map-exists), increment
 `result`\[`unit`\] by `power`.

 2. Otherwise, set `result`\[`unit`\] to
 `power`.

3. Return `result`.

[`parse()`](#dom-cssnumericvalue-parse) method allows a
[`CSSNumericValue`](#cssnumericvalue) to be constructed directly from a string containing
CSS. Note that this is a static method, existing directly on the
[`CSSNumericValue`](#cssnumericvalue) interface object, rather than on
[`CSSNumericValue`](#cssnumericvalue) instances.

The [`parse(``cssText``)`] method, when called, must perform the following steps:

1. [Parse a component
 value](https://drafts.csswg.org/css-syntax-3/#parse-a-component-value) from `cssText` and let
 `result` be the result. If `result` is a
 syntax error,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror) and abort this algorithm.

2. If `result` is not a
 [\<number-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-number-token),
 [\<percentage-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-percentage-token),
 [\<dimension-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-dimension-token), or a [math
 function](https://drafts.csswg.org/css-values-4/#math-function),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror) and abort this algorithm.

3. If `result` is a
 [\<dimension-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-dimension-token) and [creating a
 type](#cssnumericvalue-create-a-type) from `result`'s unit returns failure,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror) and abort this algorithm.

4. [Reify a numeric
 value](#reify-a-numeric-value) `result`, and return the result.

#### 4.3.2. Numeric Value Typing

Each
[`CSSNumericValue`](#cssnumericvalue) has an associated [type], which
is a
[map](https://infra.spec.whatwg.org/#ordered-map) of [base
types](#cssnumericvalue-base-type) to integers (denoting the exponent of each type, so a
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)^2^, such as from [calc(1px \*
1em)], is «\[ \"length\" → 2 \]»), and an associated [percent
hint](#cssnumericvalue-percent-hint) (indicating that the type actually holds a percentage,
but that percentage will eventually resolve to the hinted [base
type](#cssnumericvalue-base-type), and so has been replaced with it in the type).

The [base types] are
\"length\", \"angle\", \"time\", \"frequency\", \"resolution\",
\"flex\", and \"percent\". The ordering of a [type]'s
entries always matches this [base
type](#cssnumericvalue-base-type) ordering. The [percent
hint] is either null or a
[base
type](#cssnumericvalue-base-type).

 As new unit types are added to CSS, they'll be added to
this list of [base
types](#cssnumericvalue-base-type), and to the CSS [math
functions](https://drafts.csswg.org/css-values-4/#math-function).

 A [percent
hint](#cssnumericvalue-percent-hint) can be \"percent\", indicating the percentage is used
as itself (or, equivalently, evaluated against a plain number), but this
is not produced by the Typed OM methods; it only occurs when the type
machinery is used directly by CSS, where a value's context is actually
known.

To [create a type] from a string `unit`,
follow the appropriate branch of the following:

`unit` is \"number\"

: Return «\[ \]» (empty map)

`unit` is \"percent\"

: Return «\[ \"percent\" → 1 \]»

`unit` is a [\<length\>](https://drafts.csswg.org/css-values-4/#length-value) unit

: Return «\[ \"length\" → 1 \]»

`unit` is an [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value) unit

: Return «\[ \"angle\" → 1 \]»

`unit` is a [\<time\>](https://drafts.csswg.org/css-values-4/#time-value) unit

: Return «\[ \"time\" → 1 \]»

`unit` is a [\<frequency\>](https://drafts.csswg.org/css-values-4/#frequency-value) unit

: Return «\[ \"frequency\" → 1 \]»

`unit` is a [\<resolution\>](https://drafts.csswg.org/css-values-4/#resolution-value) unit

: Return «\[ \"resolution\" → 1 \]»

`unit` is a [\<flex\>](https://drafts.csswg.org/css-grid-2/#typedef-flex) unit

: Return «\[ \"flex\" → 1 \]»

anything else

: Return failure.

In all cases, the associated [percent
hint](#cssnumericvalue-percent-hint) is null.

To [add two types] `type1` and `type2`,
perform the following steps:

1. Replace `type1` with a fresh copy of `type1`,
 and `type2` with a fresh copy of `type2`. Let
 `finalType` be a new [type] with an initially
 empty [ordered
 map](https://infra.spec.whatwg.org/#ordered-map) and an initially null [percent
 hint](#cssnumericvalue-percent-hint).

2.

 If both `type1` and `type2` have non-null [percent hints](#cssnumericvalue-percent-hint) with different values

 : The types can't be added. Return failure.

 If `type1` has a non-null [percent hint](#cssnumericvalue-percent-hint) `hint` and `type2` doesn't

 : [Apply the percent
 hint](#apply-the-percent-hint) `hint` to `type2`.

 Vice versa if `type2` has a non-null [percent
 hint](#cssnumericvalue-percent-hint) and `type1` doesn't.

 Otherwise

 : Continue to the next step.

3.

 If all the [entries](https://infra.spec.whatwg.org/#map-entry) of `type1` with non-zero values are [contained](https://infra.spec.whatwg.org/#map-exists) in `type2` with the same value, and vice-versa

 : Copy all of `type1`'s
 [entries](https://infra.spec.whatwg.org/#map-entry) to `finalType`, and then copy all of
 `type2`'s
 [entries](https://infra.spec.whatwg.org/#map-entry) to `finalType` that
 `finalType` doesn't already
 [contain](https://infra.spec.whatwg.org/#map-exists). Set `finalType`'s [percent
 hint](#cssnumericvalue-percent-hint) to `type1`'s [percent
 hint](#cssnumericvalue-percent-hint). Return `finalType`.

 If `type1` and/or `type2` [contain](https://infra.spec.whatwg.org/#map-exists) \"percent\" with a non-zero value, and `type1` and/or `type2` [contain](https://infra.spec.whatwg.org/#map-exists) a key *other than* \"percent\" with a non-zero value

 : For each [base
 type](#cssnumericvalue-base-type) other than \"percent\" `hint`:

 1. Provisionally [apply the percent
 hint](#apply-the-percent-hint) `hint` to both
 `type1` and `type2`.

 2. If, afterwards, all the
 [entries](https://infra.spec.whatwg.org/#map-entry) of `type1` with non-zero values
 are
 [contained](https://infra.spec.whatwg.org/#map-exists) in `type2` with the same value,
 and vice versa, then copy all of `type1`'s
 [entries](https://infra.spec.whatwg.org/#map-entry) to `finalType`, and then copy
 all of `type2`'s
 [entries](https://infra.spec.whatwg.org/#map-entry) to `finalType` that
 `finalType` doesn't already
 [contain](https://infra.spec.whatwg.org/#map-exists). Set `finalType`'s [percent
 hint](#cssnumericvalue-percent-hint) to `hint`. Return
 `finalType`.

 3. Otherwise, revert `type1` and `type2`
 to their state at the start of this loop.

 If the loop finishes without returning `finalType`,
 then the types can't be added. Return failure.

 You can shortcut this in some cases by just
 checking the sum of all the
 [values](https://infra.spec.whatwg.org/#map-getting-the-values) of `type1` vs `type2`. If
 the sums are different, the types can't be added.

 Otherwise

 : The types can't be added. Return failure.

To [apply the percent hint] `hint` to a `type`
without a [percent
hint](#cssnumericvalue-percent-hint), perform the following steps:

1. Set `type`'s [percent
 hint](#cssnumericvalue-percent-hint) to `hint`.

2. If `type` doesn't
 [contain](https://infra.spec.whatwg.org/#map-exists) `hint`, set
 `type`\[`hint`\] to 0.

3. If `hint` is anything other than \"percent\", and
 `type`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"percent\", add `type`\[\"percent\"\]
 to `type`\[`hint`\], then set
 `type`\[\"percent\"\] to 0.

4. Return `type`.

To [multiply two types] `type1` and
`type2`, perform the following steps:

1. Replace `type1` with a fresh copy of `type1`,
 and `type2` with a fresh copy of `type2`. Let
 `finalType` be a new [type] with an initially
 empty [ordered
 map](https://infra.spec.whatwg.org/#ordered-map) and an initially null [percent
 hint](#cssnumericvalue-percent-hint).

2. If both `type1` and `type2` have non-null
 [percent
 hints](#cssnumericvalue-percent-hint) with different values, the types can't be
 multiplied. Return failure.

3. If `type1` has a non-null [percent
 hint](#cssnumericvalue-percent-hint) `hint` and `type2` doesn't,
 [apply the percent
 hint](#apply-the-percent-hint) `hint` to `type2`.

 Vice versa if `type2` has a non-null [percent
 hint](#cssnumericvalue-percent-hint) and `type1` doesn't.

4. Copy all of `type1`'s
 [entries](https://infra.spec.whatwg.org/#map-entry) to `finalType`, then [for
 each](https://infra.spec.whatwg.org/#map-iterate) `baseType` → `power` of
 `type2`:

 1. If `finalType`\[`baseType`\]
 [exists](https://infra.spec.whatwg.org/#map-exists), increment its value by `power`.

 2. Otherwise, set `finalType`\[`baseType`\]
 to `power`.

 Set `finalType`'s [percent
 hint](#cssnumericvalue-percent-hint) to `type1`'s [percent
 hint](#cssnumericvalue-percent-hint).

5. Return `finalType`.

To [invert a type] `type`,
perform the following steps:

1. Let `result` be a new [type] with an
 initially empty [ordered
 map](https://infra.spec.whatwg.org/#ordered-map) and a [percent
 hint](#cssnumericvalue-percent-hint) matching that of `type`.

2. [For
 each](https://infra.spec.whatwg.org/#map-iterate) `unit` → `exponent` of
 `type`, set `result`\[`unit`\] to
 (-1 \* `exponent`).

3. Return `result`.

A [type] is said to [match] a CSS
production in some circumstances:

- A [type] matches
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value) if its only non-zero
 [entry](https://infra.spec.whatwg.org/#map-entry) is «\[ \"length\" → 1 \]». Similarly for
 [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value),
 [\<time\>](https://drafts.csswg.org/css-values-4/#time-value),
 [\<frequency\>](https://drafts.csswg.org/css-values-4/#frequency-value),
 [\<resolution\>](https://drafts.csswg.org/css-values-4/#resolution-value), and
 [\<flex\>](https://drafts.csswg.org/css-grid-2/#typedef-flex).

 If the context in which the value is used allows
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) values, and those percentages are
 resolved against another type, then for the [type] to be
 considered
 [matching](#cssnumericvalue-match) it must either have a null [percent
 hint](#cssnumericvalue-percent-hint), or the [percent
 hint](#cssnumericvalue-percent-hint) must match the other type.

 If the context does *not* allow
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) values to be mixed with
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value)/etc values (or doesn't allow
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) values at all, such as
 [border-width](https://drafts.csswg.org/css-borders-4/#propdef-border-width)), then for the [type]
 to be considered
 [matching](#cssnumericvalue-match) the [percent
 hint](#cssnumericvalue-percent-hint) must be null.

- A [type] matches
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) if its only non-zero
 [entry](https://infra.spec.whatwg.org/#map-entry) is «\[ \"percent\" → 1 \]», and its [percent
 hint](#cssnumericvalue-percent-hint) is either null or \"percent\".

- A [type] matches
 [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) if it matches
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value) or matches
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value). Same for
 [\<angle-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-angle-percentage),
 [\<time-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-time-percentage), etc.

- A [type] matches
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value) if it has no non-zero
 [entries](https://infra.spec.whatwg.org/#map-entry).

 If the context in which the value is used allows
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) values, and those percentages are
 resolved against a type other than
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value), then for the [type] to
 be considered
 [matching](#cssnumericvalue-match) the [percent
 hint](#cssnumericvalue-percent-hint) must either be null or match the other type.

 If the context allows
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) values, but either doesn't resolve
 them against another type or resolves them against a
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value), then for the [type] to
 be considered
 [matching](#cssnumericvalue-match) the [percent
 hint](#cssnumericvalue-percent-hint) must either be null or \"percent\".

 If the context does *not* allow
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) values, then for the
 [type] to be considered
 [matching](#cssnumericvalue-match) the [percent
 hint](#cssnumericvalue-percent-hint) must be null.

 [Types] form a semi-group under addition,
and a monoid under multiplication (with the multiplicative identity
being «\[ \]» with a null [percent
hint](#cssnumericvalue-percent-hint)), meaning that they're associative and commutative.
Thus the spec can, for example,
[add](#cssnumericvalue-add-two-types) an unbounded number of types together unambiguously,
rather than having to manually
[add](#cssnumericvalue-add-two-types) them pair-wise.

#### 4.3.3. Value + Unit: [`CSSUnitValue` objects]
Numeric values that can be expressed as a single unit (or a naked number
or percentage) are represented as
[`CSSUnitValue`](#cssunitvalue)s.

For example, the value [5px] in
a stylesheet will be represented by a
[`CSSUnitValue`](#cssunitvalue) with its `value` attribute set to `5` and its `unit`
attribute set to `"px"`.

Similarly, the value [10] in a stylesheet will be represented by a
[`CSSUnitValue`](#cssunitvalue) with its `value` attribute set to `10` and its `unit`
attribute set to `"number"`.

```
[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSUnitValue : CSSNumericValue {
 constructor(double value, USVString unit);
 attribute double value;
 readonly attribute USVString unit;
};
```

[`CSSUnitValue(``value``, ``unit``)`] constructor
must, when called, perform the following steps:

1. If [creating a
 type](#cssnumericvalue-create-a-type) from `unit` returns failure,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) and abort this algorithm.

2. Return a new
 [`CSSUnitValue`](#cssunitvalue) with its
 [`value`](#dom-cssunitvalue-value) internal slot set to `value` and its
 [`unit`](#dom-cssunitvalue-unit) set to `unit`.

The [[type] of a
[`CSSUnitValue`](#cssunitvalue)] is the result of [creating a
type](#cssnumericvalue-create-a-type) from its
[`unit`](#dom-cssunitvalue-unit) internal slot.

To [create a CSSUnitValue from a
pair]
(`num`, `unit`), return a new
[`CSSUnitValue`](#cssunitvalue) object with its
[`value`](#dom-cssunitvalue-value) internal slot set to `num`, and its
[`unit`](#dom-cssunitvalue-unit) internal slot set to `unit`.

For example, creating a [new unit
value](#create-a-cssunitvalue-from-a-pair) from `(5, "px")` creates an object equivalent to
`new CSSUnitValue(5, "px")`.

 This is a spec-internal algorithm, meant simply to make
it easier to create unit values in algorithms when needed.

To [convert a CSSUnitValue] `this` to a unit `unit`,
perform the following steps:

1. Let `old unit` be the value of `this`'s
 [`unit`](#dom-cssunitvalue-unit) internal slot, and `old value` be the
 value of `this`'s
 [`value`](#dom-cssunitvalue-value) internal slot.

2. If `old unit` and `unit` are not [compatible
 units](https://drafts.csswg.org/css-values-4/#compatible-units), return failure.

3. Return a new
 [`CSSUnitValue`](#cssunitvalue) whose
 [`unit`](#dom-cssunitvalue-unit) internal slot is set to `unit`, and
 whose
 [`value`](#dom-cssunitvalue-value) internal slot is set to `old value`
 multiplied by the conversation ratio between `old unit`
 and `unit`.

#### 4.3.4. Complex Numeric Values: [`CSSMathValue` objects]
Numeric values that are more complicated than a single value+unit are
represented by a tree of
[`CSSMathValue`](#cssmathvalue) subclasses, eventually terminating in
[`CSSUnitValue`](#cssunitvalue) objects at the leaf nodes. The
[calc()](https://drafts.csswg.org/css-values-4/#funcdef-calc),
[min()](https://drafts.csswg.org/css-values-4/#funcdef-min), and
[max()](https://drafts.csswg.org/css-values-4/#funcdef-max) functions in CSS are represented in this way.

For example, the CSS value [calc(1em +
5px)] will be represented by a
[`CSSMathSum`](#cssmathsum)
like `CSSMathSum(CSS.em(1), CSS.px(5))`.

A more complex expression, like [calc(1em + 5px \* 2)], will be
represented by a nested structure like
`CSSMathSum(CSS.em(1), CSSMathProduct(CSS.px(5), 2))`.

```
[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSMathValue : CSSNumericValue {
 readonly attribute CSSMathOperator operator;
};

[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSMathSum : CSSMathValue {
 constructor(CSSNumberish... args);
 readonly attribute CSSNumericArray values;
};

[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSMathProduct : CSSMathValue {
 constructor(CSSNumberish... args);
 readonly attribute CSSNumericArray values;
};

[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSMathNegate : CSSMathValue {
 constructor(CSSNumberish arg);
 readonly attribute CSSNumericValue value;
};

[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSMathInvert : CSSMathValue {
 constructor(CSSNumberish arg);
 readonly attribute CSSNumericValue value;
};

[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSMathMin : CSSMathValue {
 constructor(CSSNumberish... args);
 readonly attribute CSSNumericArray values;
};

[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSMathMax : CSSMathValue {
 constructor(CSSNumberish... args);
 readonly attribute CSSNumericArray values;
};

[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSMathClamp : CSSMathValue {
 constructor(CSSNumberish lower, CSSNumberish value, CSSNumberish upper);
 readonly attribute CSSNumericValue lower;
 readonly attribute CSSNumericValue value;
 readonly attribute CSSNumericValue upper;
};

[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSNumericArray {
 iterable<CSSNumericValue>;
 readonly attribute unsigned long length;
 getter CSSNumericValue (unsigned long index);
};

enum CSSMathOperator {
 "sum",
 "product",
 "negate",
 "invert",
 "min",
 "max",
 "clamp",
};
```

 CSSMathValue, being a pure superclass, cannot be
directly constructed. It exists solely to host the common attributes of
all the \"math\" operations.

The [`operator`] attribute of a
[`CSSMathValue`](#cssmathvalue) `this` must, on getting, return the
following string, depending on the interface of `this`:

[`CSSMathSum`](#cssmathsum)

: `"sum"`

[`CSSMathProduct`](#cssmathproduct)

: `"product"`

[`CSSMathMin`](#cssmathmin)

: `"min"`

[`CSSMathMax`](#cssmathmax)

: `"max"`

[`CSSMathClamp`](#cssmathclamp)

: `"clamp"`

[`CSSMathNegate`](#cssmathnegate)

: `"negate"`

[`CSSMathInvert`](#cssmathinvert)

: `"invert"`

 These are all instances of the
[`CSSMathOperator`](#enumdef-cssmathoperator) enum.

The [`CSSMathSum(...``args``)`]
constructor must, when called, perform the following steps:

1. Replace each
 [item](https://infra.spec.whatwg.org/#list-item) of `args` with the result of [rectifying
 a numberish
 value](#rectify-a-numberish-value) for the
 [item](https://infra.spec.whatwg.org/#list-item).

2. If `args` [is
 empty](https://infra.spec.whatwg.org/#list-is-empty),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

3. Let `type` be the result of
 [adding](#cssnumericvalue-add-two-types) the [types] of all the
 [items](https://infra.spec.whatwg.org/#list-item) of `args`. If `type` is
 failure,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

4. Return a new [`CSSMathSum`](#cssmathsum) whose
 [`values`](#dom-cssmathsum-values) internal slot is set to `args`.

The [`CSSMathMin(...``args``)`]
and [`CSSMathMax(...``args``)`]
constructors are defined identically to the above, except that in the
last step they return a new
[`CSSMathMin`](#cssmathmin)
or [`CSSMathMax`](#cssmathmax) object, respectively.

The
[`CSSMathProduct(...``args``)`]
constructor is defined identically to the above, except that in step 3
it
[multiplies](#cssnumericvalue-multiply-two-types) the types instead of
[adding](#cssnumericvalue-add-two-types), and in the last step it returns a
[`CSSMathProduct`](#cssmathproduct).

[`CSSMathClamp(``lower``, ``value``, ``upper``)`]
constructor must, when called, perform the following steps:

1. Replace `lower`, `value`, and
 `upper` with the result of [rectifying a numberish
 value](#rectify-a-numberish-value) for each.

2. Let `type` be the result of
 [adding](#cssnumericvalue-add-two-types) the [types] of `lower`,
 `value`, and `upper`. If `type` is
 failure,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

3. Return a new
 [`CSSMathClamp`](#cssmathclamp) whose
 [`lower`](#dom-cssmathclamp-lower),
 [`value`](#dom-cssmathclamp-value), and
 [`upper`](#dom-cssmathclamp-upper) internal slots are set to `lower`,
 `value`, and `upper`, respectively.

[`CSSMathNegate(``arg``)`] constructor must, when called,
perform the following steps:

1. Replace `arg` with the result of [rectifying a numberish
 value](#rectify-a-numberish-value) for `arg`.

2. Return a new
 [`CSSMathNegate`](#cssmathnegate) whose
 [`value`](#dom-cssmathnegate-value) internal slot is set to `arg`.

The
[`CSSMathInvert(``arg``)`] constructor is defined
identically to the above, except that in the last step it returns a new
[`CSSMathInvert`](#cssmathinvert) object.

The [[type] of a CSSMathValue] depends on its class:

[`CSSMathSum`](#cssmathsum)\
[`CSSMathMin`](#cssmathmin)\
[`CSSMathMax`](#cssmathmax)

: The [type] is the result of
 [adding](#cssnumericvalue-add-two-types) the [types] of each of the
 [items](https://infra.spec.whatwg.org/#list-item) in its
 [`values`](#dom-cssmathsum-values) internal slot.

[`CSSMathClamp`](#cssmathclamp)

: The [type] is the result of
 [adding](#cssnumericvalue-add-two-types) the [types] of the
 [`lower`](#dom-cssmathclamp-lower),
 [`value`](#dom-cssmathclamp-value), and
 [`upper`](#dom-cssmathclamp-upper) internal slots.

[`CSSMathProduct`](#cssmathproduct)

: The [type] is the result of
 [multiplying](#cssnumericvalue-multiply-two-types) the [types] of each of the
 [items](https://infra.spec.whatwg.org/#list-item) in its
 [`values`](#dom-cssmathproduct-values) internal slot.

[`CSSMathNegate`](#cssmathnegate)

: The [type] is the same as the [type] of its
 [`value`](#dom-cssmathnegate-value) internal slot.

[`CSSMathInvert`](#cssmathinvert)

: The [type] is the same as the [type] of its
 [`value`](#dom-cssmathinvert-value) internal slot, but with all
 [values](https://infra.spec.whatwg.org/#map-getting-the-values) negated.

The [`length`] attribute of
[`CSSNumericArray`](#cssnumericarray) indicates how many
[`CSSNumericValue`](#cssnumericvalue)s are contained within the
[`CSSNumericArray`](#cssnumericarray).

The [[indexed property
getter](https://webidl.spec.whatwg.org/#dfn-indexed-property-getter)] of
[`CSSNumericArray`](#cssnumericarray) retrieves the
[`CSSNumericValue`](#cssnumericvalue) at the provided index.

#### 4.3.5. Numeric Factory Functions

The following factory functions can be used to create new numeric values
much less verbosely than using the constructors directly.

```
partial namespace CSS {
 CSSUnitValue number(double value);
 CSSUnitValue percent(double value);

 // <length>
 CSSUnitValue cap(double value);
 CSSUnitValue ch(double value);
 CSSUnitValue em(double value);
 CSSUnitValue ex(double value);
 CSSUnitValue ic(double value);
 CSSUnitValue lh(double value);
 CSSUnitValue rcap(double value);
 CSSUnitValue rch(double value);
 CSSUnitValue rem(double value);
 CSSUnitValue rex(double value);
 CSSUnitValue ric(double value);
 CSSUnitValue rlh(double value);
 CSSUnitValue vw(double value);
 CSSUnitValue vh(double value);
 CSSUnitValue vi(double value);
 CSSUnitValue vb(double value);
 CSSUnitValue vmin(double value);
 CSSUnitValue vmax(double value);
 CSSUnitValue svw(double value);
 CSSUnitValue svh(double value);
 CSSUnitValue svi(double value);
 CSSUnitValue svb(double value);
 CSSUnitValue svmin(double value);
 CSSUnitValue svmax(double value);
 CSSUnitValue lvw(double value);
 CSSUnitValue lvh(double value);
 CSSUnitValue lvi(double value);
 CSSUnitValue lvb(double value);
 CSSUnitValue lvmin(double value);
 CSSUnitValue lvmax(double value);
 CSSUnitValue dvw(double value);
 CSSUnitValue dvh(double value);
 CSSUnitValue dvi(double value);
 CSSUnitValue dvb(double value);
 CSSUnitValue dvmin(double value);
 CSSUnitValue dvmax(double value);
 CSSUnitValue cqw(double value);
 CSSUnitValue cqh(double value);
 CSSUnitValue cqi(double value);
 CSSUnitValue cqb(double value);
 CSSUnitValue cqmin(double value);
 CSSUnitValue cqmax(double value);
 CSSUnitValue cm(double value);
 CSSUnitValue mm(double value);
 CSSUnitValue Q(double value);
 CSSUnitValue in(double value);
 CSSUnitValue pt(double value);
 CSSUnitValue pc(double value);
 CSSUnitValue px(double value);

 // <angle>
 CSSUnitValue deg(double value);
 CSSUnitValue grad(double value);
 CSSUnitValue rad(double value);
 CSSUnitValue turn(double value);

 // <time>
 CSSUnitValue s(double value);
 CSSUnitValue ms(double value);

 // <frequency>
 CSSUnitValue Hz(double value);
 CSSUnitValue kHz(double value);

 // <resolution>
 CSSUnitValue dpi(double value);
 CSSUnitValue dpcm(double value);
 CSSUnitValue dppx(double value);

 // <flex>
 CSSUnitValue fr(double value);
};
```

All of the above methods must, when called with a double
`value`, return a new
[`CSSUnitValue`](#cssunitvalue) whose
[`value`](#dom-cssunitvalue-value) internal slot is set to `value` and whose
[`unit`](#dom-cssunitvalue-unit) internal slot is set to the name of the method as
defined here.

 The unit used does not depend on the *current* name of
the function, if it's stored in another variable;
`let foo = CSS.px; let val = foo(5);` does not return a
`{value: 5, unit: "foo"}`
[`CSSUnitValue`](#cssunitvalue). The above talk about names is just a shorthand to
avoid defining the unit individually for all \~60 functions.

The above list of methods reflects the set of CSS's valid predefined
units at one particular point in time. It will be updated over time, but
might be out-of-date at any given moment. If an implementation supports
additional CSS units that do not have a corresponding method in the
above list, but that do correspond to one of the existing
[`CSSNumericType`](#dictdef-cssnumerictype) values, it must additionally support such a method,
named after the unit in its defined canonical casing, using the generic
behavior defined above.

If an implementation supports units that do *not* correspond to one of
the existing
[`CSSNumericType`](#dictdef-cssnumerictype) values, it must not support those units in the APIs
defined in this specification; it should request the units and their
types be added explicitly to this specification, as the appropriate type
name is not implicit from the unit.

If an implementation does not support a given unit, it must not
implement its corresponding method from the list above.

For example, the CSS Speech spec
[\[CSS-SPEECH-1\]](#biblio-css-speech-1 "CSS Speech Module Level 1")
defines two additional units, the decibel [dB] and semitone
[st]. No current browser implementation supports these or has
plans to, so they're not included in the above list, but if an
implementation *does* support the Speec spec, it must also expose
`CSS.dB()` and `CSS.st()` methods.

### 4.4. [`CSSTransformValue` objects]
[`CSSTransformValue`](#csstransformvalue) objects represent
[\<transform-list\>](https://drafts.csswg.org/css-transforms-1/#typedef-transform-list) values, used by the
[transform](https://drafts.csswg.org/css-transforms-1/#propdef-transform) property. They \"contain\" one or
more
[`CSSTransformComponent`](#csstransformcomponent)s, which represent individual
[\<transform-function\>](https://drafts.csswg.org/css-transforms-1/#typedef-transform-function) values.

```
[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSTransformValue : CSSStyleValue {
 constructor(sequence<CSSTransformComponent> transforms);
 iterable<CSSTransformComponent>;
 readonly attribute unsigned long length;
 getter CSSTransformComponent (unsigned long index);
 setter undefined (unsigned long index, CSSTransformComponent val);

 readonly attribute boolean is2D;
 DOMMatrix toMatrix();
};
```

A
[`CSSTransformValue`](#csstransformvalue)'s [values to iterate over] is a
[list](https://infra.spec.whatwg.org/#list) of
[`CSSTransformComponent`](#csstransformcomponent)s.

[`CSSTransformValue(``transforms``)`] constructor
must, when called, perform the following steps:

1. If `transforms` [is
 empty](https://infra.spec.whatwg.org/#list-is-empty),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

2. Return a new
 [`CSSTransformValue`](#csstransformvalue) whose [values to iterate over] is
 `transforms`.

The [`is2D`] attribute of
a
[`CSSTransformValue`](#csstransformvalue) `this` must, on getting, return `true` if,
[for
each](https://infra.spec.whatwg.org/#list-iterate) `func` in `this`'s [values to
iterate over], the `func`'s
[`is2D`](#dom-csstransformcomponent-is2d) attribute would return `true`; otherwise, the attribute
returns `false`.

The [`toMatrix()`]
method of a
[`CSSTransformValue`](#csstransformvalue) `this` must, when called, perform the
following steps:

1. Let `matrix` be a new
 [`DOMMatrix`](https://drafts.csswg.org/geometry-1/#dommatrix), initialized to the identity matrix, with its
 [`is2D`](https://drafts.csswg.org/geometry-1/#dom-dommatrixreadonly-is2d) internal slot set to `true`.

2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `func` in `this`'s [values to
 iterate over]:

 1. Let `funcMatrix` be the
 [`DOMMatrix`](https://drafts.csswg.org/geometry-1/#dommatrix) returned by calling
 [`toMatrix()`](#dom-csstransformcomponent-tomatrix) on `func`.

 2. Set `matrix` to the result of multiplying
 `matrix` and the matrix represented by
 `funcMatrix`.

3. Return `matrix`.

The [`length`] attribute
indicates how many transform components are contained within the
[`CSSTransformValue`](#csstransformvalue).

They have a [`[[values]]`] internal slot, which is a
[list](https://infra.spec.whatwg.org/#list) of
[`CSSTransformComponent`](#csstransformcomponent) objects. This list is the object's [values to iterate
over].

The [supported property
indexes](https://webidl.spec.whatwg.org/#dfn-supported-property-indices) of a
[`CSSTransformValue`](#csstransformvalue) `this` are the integers greater than or
equal to 0, and less than the
[size](https://infra.spec.whatwg.org/#list-size) of `this`'s
[`[[values]]`](#dom-csstransformvalue-values-slot) internal slot.

To [determine the value of an indexed
property](https://webidl.spec.whatwg.org/#dfn-determine-the-value-of-an-indexed-property) of a
[`CSSTransformValue`](#csstransformvalue) `this` and an index `n`, let
`values` be `this`'s
[`[[values]]`](#dom-csstransformvalue-values-slot) internal slot, and return
`values`\[`n`\].

To [set the value of an existing indexed
property](https://webidl.spec.whatwg.org/#dfn-set-the-value-of-an-existing-indexed-property) of a
[`CSSTransformValue`](#csstransformvalue) `this`, an index `n`, and a value
`new value`, let `values` be `this`'s
[`[[values]]`](#dom-csstransformvalue-values-slot) internal slot, and set
`values`\[`n`\] to `new value`.

To [set the value of a new indexed
property](https://webidl.spec.whatwg.org/#dfn-set-the-value-of-a-new-indexed-property) of a
[`CSSTransformValue`](#csstransformvalue) `this`, an index `n`, and a value
`new value`, let `values` be `this`'s
[`[[values]]`](#dom-csstransformvalue-values-slot) internal slot. If `n` is not equal to the
[size](https://infra.spec.whatwg.org/#list-size) of `values`,
[throw](https://webidl.spec.whatwg.org/#dfn-throw) a
[`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror). Otherwise,
[append](https://infra.spec.whatwg.org/#list-append) `new value` to `values`.

```
typedef (CSSNumericValue or CSSKeywordish) CSSPerspectiveValue;

[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSTransformComponent {
 stringifier;
 attribute boolean is2D;
 DOMMatrix toMatrix();
};

[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSTranslate : CSSTransformComponent {
 constructor(CSSNumericValue x, CSSNumericValue y, optional CSSNumericValue z);
 attribute CSSNumericValue x;
 attribute CSSNumericValue y;
 attribute CSSNumericValue z;
};

[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSRotate : CSSTransformComponent {
 constructor(CSSNumericValue angle);
 constructor(CSSNumberish x, CSSNumberish y, CSSNumberish z, CSSNumericValue angle);
 attribute CSSNumberish x;
 attribute CSSNumberish y;
 attribute CSSNumberish z;
 attribute CSSNumericValue angle;
};

[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSScale : CSSTransformComponent {
 constructor(CSSNumberish x, CSSNumberish y, optional CSSNumberish z);
 attribute CSSNumberish x;
 attribute CSSNumberish y;
 attribute CSSNumberish z;
};

[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSSkew : CSSTransformComponent {
 constructor(CSSNumericValue ax, CSSNumericValue ay);
 attribute CSSNumericValue ax;
 attribute CSSNumericValue ay;
};

[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSSkewX : CSSTransformComponent {
 constructor(CSSNumericValue ax);
 attribute CSSNumericValue ax;
};

[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSSkewY : CSSTransformComponent {
 constructor(CSSNumericValue ay);
 attribute CSSNumericValue ay;
};

/* Note that skew(x,y) is *not* the same as skewX(x) skewY(y),
 thus the separate interfaces for all three. */

[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSPerspective : CSSTransformComponent {
 constructor(CSSPerspectiveValue length);
 attribute CSSPerspectiveValue length;
};

[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSMatrixComponent : CSSTransformComponent {
 constructor(DOMMatrixReadOnly matrix, optional CSSMatrixComponentOptions options = );
 attribute DOMMatrix matrix;
};

dictionary CSSMatrixComponentOptions {
 boolean is2D;
};
```

The [`is2D`]
attribute indicates whether the transform is 2D or 3D. When it's `true`,
the attributes of the transform that are relevant to 3D transforms (such
as the
[`CSSTranslate.z`](#dom-csstranslate-z) attribute) simply have no effect on the transform they
represent.

 This affects the serialization of the object, and
concepts such as the object's \"equivalent 4x4 matrix\".

[`is2D`](#dom-csstransformcomponent-is2d) Design Considerations

For legacy reasons, 2D and 3D transforms are distinct, even if they have
identical effects; a [translateZ(0px)] has observable effects on a
page, even tho it's defined to be an identity transform, as the UA
activates some 3D-based optimizations for the element.

There were several possible ways to reflect this---​nullable 3D-related
attributes, separate 2D and 3D interfaces, etc---​but we chose the
current design (an author-flippable switch that dictates the behavior)
because it allows authors to, in most circumstances, operate on
transforms without having to care whether they're 2D or 3D, but also
prevents \"accidentally\" flipping a 2D transform into becoming 3D.

The [`toMatrix()`]
method of a
[`CSSTransformComponent`](#csstransformcomponent) `this` must, when called, perform the
following steps:

1. Let `matrix` be a new
 [`DOMMatrix`](https://drafts.csswg.org/geometry-1/#dommatrix) object, initialized to `this`'s
 equivalent 4x4 transform matrix, as defined in [CSS Transforms 1
 §  12. Mathematical Description of Transform
 Functions](https://drafts.csswg.org/css-transforms-1/#mathematical-description),
 and with its
 [`is2D`](https://drafts.csswg.org/geometry-1/#dom-dommatrixreadonly-is2d) internal slot set to the same value as
 `this`'s
 [`is2D`](#dom-csstransformcomponent-is2d) internal slot.

 Recall that the
 [`is2D`](#dom-csstransformcomponent-is2d) flag affects what transform, and thus what
 equivalent matrix, a
 [`CSSTransformComponent`](#csstransformcomponent) represents.

 As the entries of such a matrix are defined relative to the
 [px](https://drafts.csswg.org/css-values-4/#px) unit, if any
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value)s in `this` involved in
 generating the matrix are not [compatible
 units](https://drafts.csswg.org/css-values-4/#compatible-units) with
 [px](https://drafts.csswg.org/css-values-4/#px) (such as [relative
 lengths](https://drafts.csswg.org/css-values-4/#relative-length) or
 [percentages](https://drafts.csswg.org/css-values-4/#percentage)),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

2. Return `matrix`.

[`CSSTranslate(``x``, ``y``, ``z``)`]
constructor must, when invoked, perform the following steps:

1. If `x` or `y` don't
 [match](#cssnumericvalue-match)
 [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

2. If `z` was passed, but doesn't
 [match](#cssnumericvalue-match)
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

3. Let `this` be a new
 [`CSSTranslate`](#csstranslate) object, with its
 [`x`](#dom-csstranslate-x) and
 [`y`](#dom-csstranslate-y) internal slots set to `x` and
 `y`.

4. If `z` was passed, set `this`'s
 [`z`](#dom-csstranslate-z) internal slot to `z`, and set
 `this`'s
 [`is2D`](#dom-csstransformcomponent-is2d) internal slot to `false`.

5. If `z` was not passed, set `this`'s
 [`z`](#dom-csstranslate-z) internal slot to a [new unit
 value](#create-a-cssunitvalue-from-a-pair) of `(0, "px")`, and set `this`'s
 [`is2D`](#dom-csstransformcomponent-is2d) internal slot to `true`.

6. Return `this`.

The [`CSSRotate(``angle``)`] constructor must,
when invoked, perform the following steps:

1. If `angle` doesn't
 [match](#cssnumericvalue-match)
 [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

2. Return a new [`CSSRotate`](#cssrotate) with its
 [`angle`](#dom-cssrotate-angle) internal slot set to `angle`, its
 [`x`](#dom-cssrotate-x) and
 [`y`](#dom-cssrotate-y) internal slots set to [new unit
 values](#create-a-cssunitvalue-from-a-pair) of `(0, "number")`, its
 [`z`](#dom-cssrotate-z) internal slot set to a [new unit
 value](#create-a-cssunitvalue-from-a-pair) of `(1, "number")`, and its
 [`is2D`](#dom-csstransformcomponent-is2d) internal slot set to `true`.

[`CSSRotate(``x``, ``y``, ``z``, ``angle``)`]
constructor must, when invoked, perform the following steps:

1. If `angle` doesn't
 [match](#cssnumericvalue-match)
 [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

2. Let `x`, `y`, and `z` be replaced
 by the result of [rectifying a numberish
 value](#rectify-a-numberish-value).

3. If `x`, `y`, or `z` don't
 [match](#cssnumericvalue-match)
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

4. Return a new [`CSSRotate`](#cssrotate) with its
 [`angle`](#dom-cssrotate-angle) internal slot set to `angle`, its
 [`x`](#dom-cssrotate-x),
 [`y`](#dom-cssrotate-y),
 [`z`](#dom-cssrotate-z) internal slots set to `x`,
 `y`, and `z`, and its
 [`is2D`](#dom-csstransformcomponent-is2d) internal slot set to `false`.

The [`x`],
[`y`], and [`z`] attributes must, on setting to a new value `val`,
[rectify a numberish
value](#rectify-a-numberish-value) from `val` and set the corresponding
internal slot to the result of that.

[`CSSScale(``x``, ``y``, ``z``)`]
constructor must, when invoked, perform the following steps:

1. Let `x`, `y`, and `z` (if passed)
 be replaced by the result of [rectifying a numberish
 value](#rectify-a-numberish-value).

2. If `x`, `y`, or `z` (if passed)
 don't
 [match](#cssnumericvalue-match)
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

3. Let `this` be a new
 [`CSSScale`](#cssscale)
 object, with its
 [`x`](#dom-cssscale-x) and
 [`y`](#dom-cssscale-y) internal slots set to `x` and
 `y`.

4. If `z` was passed, set `this`'s
 [`z`](#dom-cssscale-z) internal slot to `z`, and set
 `this`'s
 [`is2D`](#dom-csstransformcomponent-is2d) internal slot to `false`.

5. If `z` was not passed, set `this`'s
 [`z`](#dom-cssscale-z) internal slot to a [new unit
 value](#create-a-cssunitvalue-from-a-pair) of `(1, "number")`, and set `this`'s
 [`is2D`](#dom-csstransformcomponent-is2d) internal slot to `true`.

6. Return `this`.

The [`x`], [`y`], and
[`z`] attributes must, on setting to a new
value `val`, [rectify a numberish
value](#rectify-a-numberish-value) from `val` and set the corresponding
internal slot to the result of that.

[`CSSSkew(``ax``, ``ay``)`] constructor must,
when invoked, perform the following steps:

1. If `ax` or `ay` do not
 [match](#cssnumericvalue-match)
 [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

2. Return a new [`CSSSkew`](#cssskew) object with its
 [`ax`](#dom-cssskew-ax) and
 [`ay`](#dom-cssskew-ay) internal slots set to `ax` and
 `ay`, and its
 [`is2D`](#dom-csstransformcomponent-is2d) internal slot set to `true`.

The [`CSSSkewX(``ax``)`] constructor must, when
invoked, perform the following steps:

1. If `ax` does not
 [match](#cssnumericvalue-match)
 [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

2. Return a new [`CSSSkewX`](#cssskewx) object with its
 [`ax`](#dom-cssskewx-ax) internal slot set to `ax`, and its
 [`is2D`](#dom-csstransformcomponent-is2d) internal slot set to `true`.

The [`CSSSkewY(``ay``)`] constructor must, when
invoked, perform the following steps:

1. If `ay` does not
 [match](#cssnumericvalue-match)
 [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

2. Return a new [`CSSSkewY`](#cssskewy) object with its
 [`ay`](#dom-cssskewy-ay) internal slot set to `ay`, and its
 [`is2D`](#dom-csstransformcomponent-is2d) internal slot set to `true`.

The [`is2D`]
attribute of a [`CSSSkew`](#cssskew), [`CSSSkewX`](#cssskewx), or [`CSSSkewY`](#cssskewy) object must, on setting, do nothing.

[skew()](https://drafts.csswg.org/css-transforms-1/#funcdef-transform-skew),
[skewX()](https://drafts.csswg.org/css-transforms-1/#funcdef-transform-skewx), and
[skewY()](https://drafts.csswg.org/css-transforms-1/#funcdef-transform-skewy) functions always represent 2D transforms.

[`CSSPerspective(``length``)`] constructor must, when
invoked, perform the following steps:

1. If `length` is a
 [`CSSNumericValue`](#cssnumericvalue):

 1. If `length` does not
 [match](#cssnumericvalue-match)
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

2. Otherwise (that is, if `length` is not a
 [`CSSNumericValue`](#cssnumericvalue)):

 1. [Rectify a keywordish
 value](#rectify-a-keywordish-value) from `length`, then set
 `length` to the result's value.

 2. If `length` does not represent a value that is an
 [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for the keyword
 [none](https://drafts.csswg.org/css-transforms-2/#valdef-perspective-func-none),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

3. Return a new
 [`CSSPerspective`](#cssperspective) object with its
 [`length`](#dom-cssperspective-length) internal slot set to `length`, and its
 [`is2D`](#dom-csstransformcomponent-is2d) internal slot set to `false`.

The [`is2D`] attribute of a
[`CSSPerspective`](#cssperspective) object must, on setting, do nothing.

[perspective()](https://drafts.csswg.org/css-transforms-2/#funcdef-perspective) functions always represent 3D transforms.

[`CSSMatrixComponent(``matrix``, ``options``)`]
constructor must, when invoked, perform the following steps:

1. Let `this` be a new
 [`CSSMatrixComponent`](#cssmatrixcomponent) object with its
 [`matrix`](#dom-cssmatrixcomponent-matrix) internal slot set to `matrix`.

2. If `options` was passed and has a
 [`is2D`](#dom-cssmatrixcomponentoptions-is2d) field, set `this`'s
 [`is2D`](#dom-csstransformvalue-is2d) internal slot to the value of that field.

3. Otherwise, set `this`'s
 [`is2D`](#dom-csstransformvalue-is2d) internal slot to the value of `matrix`'s
 [`is2D`](https://drafts.csswg.org/geometry-1/#dom-dommatrixreadonly-is2d) internal slot.

4. Return `this`.

[`CSSTransformComponent`](#csstransformcomponent) can correspond to one of a number of underlying
transform functions. For example, a
[`CSSTranslate`](#csstranslate) with an x value of [10px] and y & z values of
[0px] could represent any of the following:

- translate(10px)

- translate(10px, 0)

- translateX(10px)

- translate3d(10px, 0, 0)

When stringified, however, it will always print out either
[translate(10px, 0px)] or [translate3d(10px, 0px, 0px)],
depending on whether its
[`is2D`](#dom-csstransformcomponent-is2d) internal slot is `true` or `false`, respectively.

### 4.5. [`CSSImageValue` objects]
```
[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSImageValue : CSSStyleValue ;
```

[`CSSImageValue`](#cssimagevalue) objects represent values for properties that take
[\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image) productions, for example
[background-image](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-image),
[list-style-image](https://drafts.csswg.org/css-lists-3/#propdef-list-style-image), and
[border-image-source](https://drafts.csswg.org/css-borders-4/#propdef-border-image-source).

 This object is intentionally opaque, and exposes no
details of what kind of image it contains, or any aspect of the image.
This is because having *something* to represent images is necessary for
Custom Paint, but there are sufficient complexities in getting
URL-handling and loading specified firmly that it's not realistically
possible to specify in the timeline of this specification. This will be
expanded on in future levels.

If a [`CSSImageValue`](#cssimagevalue) object represents an
[\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image) that involves a URL (such as
[url()](https://drafts.csswg.org/css-values-4/#funcdef-url) or
[image()](https://drafts.csswg.org/css-images-5/#funcdef-image)), the handling of such values is identical to
how CSS currently handles them. In particular, resolving relative URLs
or fragment URLs has the same behavior as in normal CSS.

For example, relative URLs are
resolved against the URL of the stylesheet they're within (or the
document's URL, if they're specified in a
[`style`](https://html.spec.whatwg.org/multipage/semantics.html#the-style-element) element or
[`style`](https://html.spec.whatwg.org/multipage/dom.html#attr-style) attribute). This resolution doesn't happen
eagerly at parse-time, but at some currently-unspecified point during
value computation.

Thus, if an element's style is set to [background-image:
url(foo);](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-image), and that specified value is extracted via
the Typed OM and then set on an element in a different document, both
the source and destination elements will resolve the URL differently, as
they provide different base URLs.

On the other hand, if the extracted value was a [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) (from
[`computedStyleMap()`](#dom-element-computedstylemap)), then it would already be resolved to an absolute URL,
and thus would act identically no matter where you later set it to.
(Unless it was a fragment URL, which CSS treats differently and never
fully resolves, so it always resolves against the current document.)

### 4.6. [`CSSColorValue` objects]
[`CSSColorValue`](#csscolorvalue) objects represent
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) values. It is an abstract superclass,
with the subclasses representing individual CSS color functions.

```
[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSColorValue : CSSStyleValue {
 [Exposed=Window] static (CSSColorValue or CSSStyleValue) parse(USVString cssText);
};
```

The [`parse(``cssText``)`] method, when called, must perform the following steps:

1. [Parse](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) `cssText` as a
 [\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) and let `result` be
 the result. If `result` is a syntax error,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror) and abort this algorithm.

2. [Reify a color
 value](#reify-a-color-value) from `result`, and return the result.

===============

Several IDL types are defined to be used in
[`CSSColorValue`](#csscolorvalue)s:

```
typedef (CSSNumberish or CSSKeywordish) CSSColorRGBComp;
typedef (CSSNumberish or CSSKeywordish) CSSColorPercent;
typedef (CSSNumberish or CSSKeywordish) CSSColorNumber;
typedef (CSSNumberish or CSSKeywordish) CSSColorAngle;
```

All of these types are the same in terms of type signature, but they
represent distinct values: `CSSColorRGBComp` represents a value that is,
canonically, either a
[\<number\>](https://drafts.csswg.org/css-values-4/#number-value),
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value), or the keyword [none];
`CSSColorPercent` represents a value that is, canonically, either a
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) or the keyword [none];
`CSSColorNumber` represents a value that is, canonically, either a
[\<number\>](https://drafts.csswg.org/css-values-4/#number-value) or the keyword [none];
`CSSColorAngle` represents a value that is, canonically, either an
[\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value) or the keyword [none].

Their corresponding rectification algorithms also all have distinct
behaviors for translating a
[`double`](https://webidl.spec.whatwg.org/#idl-double) value into a
[`CSSNumericValue`](#cssnumericvalue).

To [rectify a CSSColorRGBComp] `val`:

1. If `val` is a
 [`double`](https://webidl.spec.whatwg.org/#idl-double), replace it with a [new unit
 value](#create-a-cssunitvalue-from-a-pair) from (`val`\*100, \"percent\").

2. If `val` is a
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString), replace it with the result of [rectifying a
 keywordish
 value](#rectify-a-keywordish-value) from `val`.

3. If `val` is a
 [`CSSNumericValue`](#cssnumericvalue), and it
 [matches](#cssnumericvalue-match)
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value) or
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value), return `val`.

4. If `val` is a
 [`CSSKeywordValue`](#csskeywordvalue), and its
 [`value`](#dom-csskeywordvalue-value) internal slot is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for `"none"`, return `val`.

5. Throw a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

To [rectify a CSSColorPercent] `val`:

1. If `val` is a
 [`double`](https://webidl.spec.whatwg.org/#idl-double), replace it with a [new unit
 value](#create-a-cssunitvalue-from-a-pair) from (`val`\*100, \"percent\").

2. If `val` is a
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString), replace it with the result of [rectifying a
 keywordish
 value](#rectify-a-keywordish-value) from `val`.

3. If `val` is a
 [`CSSNumericValue`](#cssnumericvalue), and it
 [matches](#cssnumericvalue-match)
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value), return `val`.

4. If `val` is a
 [`CSSKeywordValue`](#csskeywordvalue), and its
 [`value`](#dom-csskeywordvalue-value) internal slot is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for `"none"`, return `val`.

5. Throw a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

To [rectify a CSSColorNumber] `val`:

1. If `val` is a
 [`double`](https://webidl.spec.whatwg.org/#idl-double), replace it with a [new unit
 value](#create-a-cssunitvalue-from-a-pair) from (`val`, \"number\").

2. If `val` is a
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString), replace it with the result of [rectifying a
 keywordish
 value](#rectify-a-keywordish-value) from `val`.

3. If `val` is a
 [`CSSNumericValue`](#cssnumericvalue), and it
 [matches](#cssnumericvalue-match)
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value), return `val`.

4. If `val` is a
 [`CSSKeywordValue`](#csskeywordvalue), and its
 [`value`](#dom-csskeywordvalue-value) internal slot is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for `"none"`, return `val`.

5. Throw a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror).

To [rectify a CSSColorAngle] `val`:

1. If `val` is a
 [`double`](https://webidl.spec.whatwg.org/#idl-double), replace it with a [new unit
 value](#create-a-cssunitvalue-from-a-pair) from (`val`, \"deg\").

2. If `val` is a
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString), replace it with the result of [rectifying a
 keywordish
 value](#rectify-a-keywordish-value) from `val`.

3. If `val` is a
 [`CSSNumericValue`](#cssnumericvalue), and it
 [matches](#cssnumericvalue-match)
 [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value), return `val`.

4. If `val` is a
 [`CSSKeywordValue`](#csskeywordvalue), and its
 [`value`](#dom-csskeywordvalue-value) internal slot is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for `"none"`, return `val`.

5. Throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

===============

TODO add stringifiers

```
[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSRGB : CSSColorValue {
 constructor(CSSColorRGBComp r, CSSColorRGBComp g, CSSColorRGBComp b, optional CSSColorPercent alpha = 1);
 attribute CSSColorRGBComp r;
 attribute CSSColorRGBComp g;
 attribute CSSColorRGBComp b;
 attribute CSSColorPercent alpha;
};
```

The [`CSSRGB`](#cssrgb) class
represents the CSS
[rgb()](https://drafts.csswg.org/css-color-4/#funcdef-rgb)/[rgba()](https://drafts.csswg.org/css-color-4/#funcdef-rgba) functions.

[`CSSRGB(``r``, ``g``, ``b``, optional ``alpha``)`] constructor must, when invoked, perform the following steps:

1. Let `r`, `g`, `b` be replaced by
 the result of [rectifying a
 CSSColorRGBComp](#rectify-a-csscolorrgbcomp) from each of them. Let `alpha` be
 replaced by the result of [rectifying a
 CSSColorPercent](#rectify-a-csscolorpercent) from it.

2. Return a new [`CSSRGB`](#cssrgb) with its
 [`r`](#dom-cssrgb-r),
 [`g`](#dom-cssrgb-g),
 [`b`](#dom-cssrgb-b),
 and [`alpha`](#dom-cssrgb-alpha) internal slots set to `r`,
 `g`, `b`, and `alpha`.

The [`r`], [`g`], and
[`b`] attributes of a
[`CSSRGB`](#cssrgb) value must,
on setting to a new value `val`, [rectify a
CSSColorRGBComp](#rectify-a-csscolorrgbcomp) from `val` and set the corresponding
internal slot to the result of that.

The [`alpha`] attribute of a
[`CSSRGB`](#cssrgb) value must,
on setting to a new value `val`, [rectify a
CSSColorPercent](#rectify-a-csscolorpercent) from `val` and set the corresponding
internal slot to the result of that.

```
[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSHSL : CSSColorValue {
 constructor(CSSColorAngle h, CSSColorPercent s, CSSColorPercent l, optional CSSColorPercent alpha = 1);
 attribute CSSColorAngle h;
 attribute CSSColorPercent s;
 attribute CSSColorPercent l;
 attribute CSSColorPercent alpha;
};
```

The [`CSSHSL`](#csshsl) class
represents the CSS
[hsl()](https://drafts.csswg.org/css-color-4/#funcdef-hsl)/[hsla()](https://drafts.csswg.org/css-color-4/#funcdef-hsla) functions.

[`CSSHSL(``h``, ``s``, ``l``, optional ``alpha``)`] constructor must, when invoked, perform the following steps:

1. Let `h` be replaced by the result of [rectifying a
 CSSColorAngle](#rectify-a-csscolorangle) from it. Let `s`, `l`, and
 `alpha` be replaced by the result of [rectifying a
 CSSColorPercent](#rectify-a-csscolorpercent) from each of them.

2. Return a new [`CSSHSL`](#csshsl) with its
 [`h`](#dom-csshsl-h),
 [`s`](#dom-csshsl-s),
 [`l`](#dom-csshsl-l),
 and [`alpha`](#dom-csshsl-alpha) internal slots set to `h`,
 `s`, `l`, and `alpha`.

The [`h`] attribute of a
[`CSSHSL`](#csshsl) value must,
on setting to a new value `val`, [rectify a
CSSColorAngle](#rectify-a-csscolorangle) from `val` and set the corresponding
internal slot to the result of that.

The [`s`], [`l`], and
[`alpha`] attributes of a
[`CSSHSL`](#csshsl) value must,
on setting to a new value `val`, [rectify a
CSSColorPercent](#rectify-a-csscolorpercent) from `val` and set the corresponding
internal slot to the result of that.

```
[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSHWB : CSSColorValue {
 constructor(CSSNumericValue h, CSSNumberish w, CSSNumberish b, optional CSSNumberish alpha = 1);
 attribute CSSNumericValue h;
 attribute CSSNumberish w;
 attribute CSSNumberish b;
 attribute CSSNumberish alpha;
};
```

The [`CSSHWB`](#csshwb) class
represents the CSS
[hwb()](https://drafts.csswg.org/css-color-5/#funcdef-hwb) function.

[`CSSHWB(``h``, ``w``, ``b``, optional ``alpha``)`] constructor must, when invoked, perform the following steps:

1. Let `h` be replaced by the result of [rectifying a
 CSSColorAngle](#rectify-a-csscolorangle) from it. Let `w`, `b`, and
 `alpha` be replaced by the result of [rectifying a
 CSSColorPercent](#rectify-a-csscolorpercent) from each of them.

2. Return a new [`CSSHWB`](#csshwb) with its
 [`h`](#dom-csshwb-h),
 [`w`](#dom-csshwb-w),
 [`b`](#dom-csshwb-b),
 and [`alpha`](#dom-csshwb-alpha) internal slots set to `h`,
 `w`, `b`, and `alpha`.

The [`h`] attribute of a
[`CSSHWB`](#csshwb) value must,
on setting to a new value `val`, [rectify a
CSSColorAngle](#rectify-a-csscolorangle) from `val` and set the corresponding
internal slot to the result of that.

The [`w`], [`b`], and
[`alpha`] attributes of a
[`CSSHWB`](#csshwb) value must,
on setting to a new value `val`, [rectify a
CSSColorPercent](#rectify-a-csscolorpercent) from `val` and set the corresponding
internal slot to the result of that.

```
[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSLab : CSSColorValue {
 constructor(CSSColorPercent l, CSSColorNumber a, CSSColorNumber b, optional CSSColorPercent alpha = 1);
 attribute CSSColorPercent l;
 attribute CSSColorNumber a;
 attribute CSSColorNumber b;
 attribute CSSColorPercent alpha;
};
```

The [`CSSLab`](#csslab) class
represents the CSS
[lab()](https://drafts.csswg.org/css-color-5/#funcdef-lab) function.

[`CSSLab(``l``, ``a``, ``b``, optional ``alpha``)`] constructor must, when invoked, perform the following steps:

1. Let `a` and `b` be replaced by the result of
 [rectifying a
 CSSColorNumber](#rectify-a-csscolornumber) from each of them. Let `l` and
 `alpha` be replaced by the result of [rectifying a
 CSSColorPercent](#rectify-a-csscolorpercent) from each of them.

2. Return a new [`CSSLab`](#csslab) with its
 [`l`](#dom-csslab-l),
 [`a`](#dom-csslab-a),
 [`b`](#dom-csslab-b),
 and [`alpha`](#dom-csslab-alpha) internal slots set to `l`,
 `a`, `b`, and `alpha`.

The [`l`] and [`alpha`]
attributes of a [`CSSLab`](#csslab) value must, on setting to a new value `val`,
[rectify a
CSSColorPercent](#rectify-a-csscolorpercent) from `val` and set the corresponding
internal slot to the result of that.

The [`a`], and [`b`]
attributes of a [`CSSLab`](#csslab) value must, on setting to a new value `val`,
[rectify a
CSSColorNumber](#rectify-a-csscolornumber) from `val` and set the corresponding
internal slot to the result of that.

```
[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSLCH : CSSColorValue {
 constructor(CSSColorPercent l, CSSColorPercent c, CSSColorAngle h, optional CSSColorPercent alpha = 1);
 attribute CSSColorPercent l;
 attribute CSSColorPercent c;
 attribute CSSColorAngle h;
 attribute CSSColorPercent alpha;
};
```

The [`CSSLCH`](#csslch) class
represents the CSS
[lch()](https://drafts.csswg.org/css-color-5/#funcdef-lch) function.

[`CSSLCH(``l``, ``c``, ``h``, optional ``alpha``)`] constructor must, when invoked, perform the following steps:

1. Let `h` be replaced by the result of [rectifying a
 CSSColorAngle](#rectify-a-csscolorangle) from it. Let `l`, `c`, and
 `alpha` be replaced by the result of [rectifying a
 CSSColorPercent](#rectify-a-csscolorpercent) from each of them.

2. Return a new [`CSSLCH`](#csslch) with its
 [`l`](#dom-csslch-l),
 [`c`](#dom-csslch-c),
 [`h`](#dom-csslch-h),
 and [`alpha`](#dom-csslch-alpha) internal slots set to `l`,
 `c`, `h`, and `alpha`.

The [`h`] attribute of a
[`CSSLCH`](#csslch) value must,
on setting to a new value `val`, [rectify a
CSSColorAngle](#rectify-a-csscolorangle) from `val` and set the corresponding
internal slot to the result of that.

The [`l`], [`c`], and
[`alpha`] attributes of a
[`CSSLCH`](#csslch) value must,
on setting to a new value `val`, [rectify a
CSSColorPercent](#rectify-a-csscolorpercent) from `val` and set the corresponding
internal slot to the result of that.

```
[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSOKLab : CSSColorValue {
 constructor(CSSColorPercent l, CSSColorNumber a, CSSColorNumber b, optional CSSColorPercent alpha = 1);
 attribute CSSColorPercent l;
 attribute CSSColorNumber a;
 attribute CSSColorNumber b;
 attribute CSSColorPercent alpha;
};
```

The [`CSSOKLab`](#cssoklab)
class represents the CSS
[oklab()](https://drafts.csswg.org/css-color-5/#funcdef-oklab) function.

[`CSSOKLab(``l``, ``a``, ``b``, optional ``alpha``)`] constructor must, when invoked, perform the following steps:

1. Let `a` and `b` be replaced by the result of
 [rectifying a
 CSSColorNumber](#rectify-a-csscolornumber) from each of them. Let `l` and
 `alpha` be replaced by the result of [rectifying a
 CSSColorPercent](#rectify-a-csscolorpercent) from each of them.

2. Return a new [`CSSOKLab`](#cssoklab) with its
 [`l`](#dom-cssoklab-l),
 [`a`](#dom-cssoklab-a),
 [`b`](#dom-cssoklab-b), and
 [`alpha`](#dom-cssoklab-alpha) internal slots set to `l`,
 `a`, `b`, and `alpha`.

The [`l`] and [`alpha`] attributes of a
[`CSSOKLab`](#cssoklab) value
must, on setting to a new value `val`, [rectify a
CSSColorPercent](#rectify-a-csscolorpercent) from `val` and set the corresponding
internal slot to the result of that.

The [`a`], and [`b`] attributes of a
[`CSSOKLab`](#cssoklab) value
must, on setting to a new value `val`, [rectify a
CSSColorNumber](#rectify-a-csscolornumber) from `val` and set the corresponding
internal slot to the result of that.

```
[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSOKLCH : CSSColorValue {
 constructor(CSSColorPercent l, CSSColorPercent c, CSSColorAngle h, optional CSSColorPercent alpha = 1);
 attribute CSSColorPercent l;
 attribute CSSColorPercent c;
 attribute CSSColorAngle h;
 attribute CSSColorPercent alpha;
};
```

The [`CSSOKLCH`](#cssoklch)
class represents the CSS
[lch()](https://drafts.csswg.org/css-color-5/#funcdef-lch) function.

[`CSSOKLCH(``l``, ``c``, ``h``, optional ``alpha``)`] constructor must, when invoked, perform the following steps:

1. Let `h` be replaced by the result of [rectifying a
 CSSColorAngle](#rectify-a-csscolorangle) from it. Let `l`, `c`, and
 `alpha` be replaced by the result of [rectifying a
 CSSColorPercent](#rectify-a-csscolorpercent) from each of them.

2. Return a new [`CSSOKLCH`](#cssoklch) with its
 [`l`](#dom-cssoklch-l),
 [`c`](#dom-cssoklch-c),
 [`h`](#dom-cssoklch-h), and
 [`alpha`](#dom-cssoklch-alpha) internal slots set to `l`,
 `c`, `h`, and `alpha`.

The [`h`] attribute of a
[`CSSOKLCH`](#cssoklch) value
must, on setting to a new value `val`, [rectify a
CSSColorAngle](#rectify-a-csscolorangle) from `val` and set the corresponding
internal slot to the result of that.

The [`l`], [`c`], and
[`alpha`] attributes of a
[`CSSOKLCH`](#cssoklch) value
must, on setting to a new value `val`, [rectify a
CSSColorPercent](#rectify-a-csscolorpercent) from `val` and set the corresponding
internal slot to the result of that.

```
[Exposed=(Window, Worker, PaintWorklet, LayoutWorklet)]
interface CSSColor : CSSColorValue {
 constructor(CSSKeywordish colorSpace, sequence<CSSColorPercent> channels, optional CSSNumberish alpha = 1);
 attribute CSSKeywordish colorSpace;
 attribute ObservableArray<CSSColorPercent> channels;
 attribute CSSNumberish alpha;
};
```

The [`CSSColor`](#csscolor)
class represents the CSS
[color()](https://drafts.csswg.org/css-color-4/#funcdef-color) function.

[`CSSColor(``colorSpace``, ``channels``, optional ``alpha``)`] constructor must, when invoked, perform the following steps:

1. Let `colorSpace` be replaced by the result of [rectifying
 a keywordish
 value](#rectify-a-keywordish-value) from it. Let each item in `channels` be
 replaced by the result of [rectifying a
 CSSColorPercent](#rectify-a-csscolorpercent) from the item. Let `alpha` be replaced
 by the result of [rectifying a
 CSSColorPercent](#rectify-a-csscolorpercent) from it.

2. Return a new [`CSSColor`](#csscolor) with its
 [`colorSpace`](#dom-csscolor-colorspace),
 [`channels`](#dom-csscolor-channels), and
 [`alpha`](#dom-csscolor-alpha) internal slots set to `colorSpace`,
 `channels`, and `alpha`.

The [`colorSpace`] attribute of a
[`CSSColor`](#csscolor) value
must, on setting to a new value `val`, [rectify a keywordish
value](#rectify-a-keywordish-value) from `val` and set the corresponding
internal slot to the result of that.

The [`alpha`] attribute of a
[`CSSColor`](#csscolor) value
must, on setting to a new value `val`, [rectify a
CSSColorPercent](#rectify-a-csscolorpercent) from `val` and set the corresponding
internal slot to the result of that.

To [set an indexed
value](https://webidl.spec.whatwg.org/#observable-array-attribute-set-an-indexed-value) `val` at index `i` for a
[`CSSColor`](#csscolor)
value's
[`channels`](#dom-csscolor-channels) attribute:

1. Replace `val` with the result of [rectifying a
 CSSColorPercent](#rectify-a-csscolorpercent) from `val`.

2. Set the `i`th value in
 [`channels`](#dom-csscolor-channels)'s [backing
 list](https://webidl.spec.whatwg.org/#observable-array-attribute-backing-list) to `val`.

To [delete an indexed
value](https://webidl.spec.whatwg.org/#observable-array-attribute-delete-an-indexed-value) `val` at index `i` for a
[`CSSColor`](#csscolor)
value's
[`channels`](#dom-csscolor-channels) attribute:

1. [Remove](https://infra.spec.whatwg.org/#list-remove) the `i`th value from
 [`channels`](#dom-csscolor-channels)'s [backing
 list](https://webidl.spec.whatwg.org/#observable-array-attribute-backing-list).

## 5. [`CSSStyleValue` Reification]
This section describes how Typed OM objects are constructed from
[internal
representations](#css-internal-representation), a process called [reification].

Some general principles apply to all
[reification](#css-reify), and so
aren't stated in each individual instance:

- If an [internal
 representation](#css-internal-representation) is from a
 [list-valued](#list-valued-properties) property, this list defines how to reify a single
 iteration of the property; multiple iterations are reflected by
 returning multiple values from
 [`StylePropertyMap`](#stylepropertymap).[`getAll()`](#dom-stylepropertymapreadonly-getall).

- If an [internal
 representation](#css-internal-representation) contains a
 [var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) reference, then it is reified by [reifying a
 list of component
 values](#reify-a-list-of-component-values), regardless of what property it is for.

### 5.1. Property-specific Rules

The following list defines the
[reification](#css-reify) behavior
for every single property in CSS, for both specified and computed
values.

unregistered [custom properties](https://drafts.csswg.org/css-variables-2/#custom-property)

: For both specified and computed values, [reify a list of component
 values](#reify-a-list-of-component-values) from the value, and return the result.

registered [custom properties](https://drafts.csswg.org/css-variables-2/#custom-property)

: Reified as described by [CSS Properties and Values API 1 § 6.2
 CSSStyleValue
 Reification](https://drafts.css-houdini.org/css-properties-values-api-1/#css-style-value-reification).

[align-content](https://drafts.csswg.org/css-align-3/#propdef-align-content)

:

[align-items](https://drafts.csswg.org/css-align-3/#propdef-align-items)

: For both specified and computed values:

 1. If the value is [normal] or [stretch], [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 2. If the value is [baseline] or [first baseline,],
 [reify an
 identifier](#reify-an-identifier) \"baseline\" and return the result.

 3. If the value is a
 [\<self-position\>](https://drafts.csswg.org/css-align-3/#typedef-self-position) with no
 [\<overflow-position\>](https://drafts.csswg.org/css-align-3/#typedef-overflow-position), [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 4. Otherwise, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[align-self](https://drafts.csswg.org/css-align-3/#propdef-align-self)

: For both specified and computed values:

 1. If the value is [auto], [normal], or
 [stretch], [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 2. If the value is [baseline] or [first baseline,],
 [reify an
 identifier](#reify-an-identifier) \"baseline\" and return the result.

 3. If the value is a
 [\<self-position\>](https://drafts.csswg.org/css-align-3/#typedef-self-position) with no
 [\<overflow-position\>](https://drafts.csswg.org/css-align-3/#typedef-overflow-position), [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 4. Otherwise, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[alignment-baseline](https://drafts.csswg.org/css-inline-3/#propdef-alignment-baseline)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[all](https://drafts.csswg.org/css-cascade-5/#propdef-all)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[animation-composition](https://drafts.csswg.org/css-animations-2/#propdef-animation-composition)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[appearance](https://drafts.csswg.org/css-ui-4/#propdef-appearance)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[azimuth](https://www.w3.org/TR/CSS2/aural.html#propdef-azimuth)

:

 For specified values:

 : 1. If the value is an
 [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value), [reify a numeric
 value](#reify-a-numeric-value) from the value and return the result.

 2. If the value is a single keyword, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 3. Otherwise, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

 For computed values:

 : [Reify a numeric
 value](#reify-a-numeric-value) from the angle and return the result.

[backdrop-filter](https://drafts.csswg.org/filter-effects-2/#propdef-backdrop-filter)

: For both specified and computed values:

 1. If the value is [none], [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 2. Otherwise, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[backface-visibility](https://drafts.csswg.org/css-transforms-2/#propdef-backface-visibility)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[background](https://drafts.csswg.org/css-backgrounds-3/#propdef-background)

: For both specified and computed values, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[background-attachment](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-attachment)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[background-blend-mode](https://drafts.csswg.org/compositing-2/#propdef-background-blend-mode)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[background-clip](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-clip)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[background-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-color)

: For both specified and computed values, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[background-image](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-image)

: For both specified and computed values:

 1. If the value is [none], [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 2. If the value is a
 [url()](https://drafts.csswg.org/css-values-4/#funcdef-url) function, [reify a url]
 from the value and return the result.

 3. Otherwise, [reify an image] from the value and
 return the result.

[background-position](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-position)

: For both specified and computed values, [reify a
 position] from the value and return the result.

[background-repeat](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-repeat)

: For both specified and computed values:

 1. If the value is a single keyword, or the same keyword repeated
 twice, [reify an
 identifier](#reify-an-identifier) from the keyword and return the result.

 2. If the value is [repeat no-repeat], [reify an
 identifier](#reify-an-identifier) \"repeat-x\" and return the result.

 3. If the value is [no-repeat repeat], [reify an
 identifier](#reify-an-identifier) \"repeat-y\" and return the result.

 4. Otherwise, reify to a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[baseline-shift](https://drafts.csswg.org/css-inline-3/#propdef-baseline-shift)

: For both specified and computed values:

 1. If the value is [sub] or [super], [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 2. Otherwise, [reify a numeric
 value](#reify-a-numeric-value) from the value and return the result.

[block-size](https://drafts.csswg.org/css-logical-1/#propdef-block-size)

: Same as for
 [width](https://drafts.csswg.org/css-sizing-3/#propdef-width)

[block-step](https://drafts.csswg.org/css-rhythm-1/#propdef-block-step)

: For both specified and computed values, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[block-step-align](https://drafts.csswg.org/css-rhythm-1/#propdef-block-step-align)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[block-step-insert](https://drafts.csswg.org/css-rhythm-1/#propdef-block-step-insert)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[block-step-round](https://drafts.csswg.org/css-rhythm-1/#propdef-block-step-round)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[block-step-size](https://drafts.csswg.org/css-rhythm-1/#propdef-block-step-size)

: For both specified and computed values:

 1. If the value is [none], [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 2. Otherwise, [reify a numeric
 value](#reify-a-numeric-value) from the value and return the result.

[bookmark-label](https://drafts.csswg.org/css-content-3/#propdef-bookmark-label)

: For both specified and computed values, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[bookmark-level](https://drafts.csswg.org/css-content-3/#propdef-bookmark-level)

: For both specified and computed values:

 1. If the value is [none], [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 2. Otherwise, [reify a numeric
 value](#reify-a-numeric-value) from the value and return the result.

[bookmark-state](https://drafts.csswg.org/css-content-3/#propdef-bookmark-state)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[border](https://drafts.csswg.org/css-borders-4/#propdef-border)

: For both specified and computed values, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[border-block](https://drafts.csswg.org/css-borders-4/#propdef-border-block)

: Same as
 [border-block-start](https://drafts.csswg.org/css-borders-4/#propdef-border-block-start)

[border-block-color](https://drafts.csswg.org/css-borders-4/#propdef-border-block-color)

: For both specified and computed values, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[border-block-end](https://drafts.csswg.org/css-borders-4/#propdef-border-block-end)

: Same as
 [border-block-start](https://drafts.csswg.org/css-borders-4/#propdef-border-block-start)

[border-block-end-color](https://drafts.csswg.org/css-borders-4/#propdef-border-block-end-color)

: Same as
 [border-top-color](https://drafts.csswg.org/css-borders-4/#propdef-border-top-color)

[border-block-end-style](https://drafts.csswg.org/css-borders-4/#propdef-border-block-end-style)

: Same as
 [border-top-style](https://drafts.csswg.org/css-borders-4/#propdef-border-top-style)

[border-block-end-width](https://drafts.csswg.org/css-borders-4/#propdef-border-block-end-width)

: Same as
 [border-top-width](https://drafts.csswg.org/css-borders-4/#propdef-border-top-width)

[border-block-start](https://drafts.csswg.org/css-borders-4/#propdef-border-block-start)

: Same as
 [border-top](https://drafts.csswg.org/css-borders-4/#propdef-border-top)

[border-block-start-color](https://drafts.csswg.org/css-borders-4/#propdef-border-block-start-color)

: Same as
 [border-top-color](https://drafts.csswg.org/css-borders-4/#propdef-border-top-color)

[border-block-start-style](https://drafts.csswg.org/css-borders-4/#propdef-border-block-start-style)

: Same as
 [border-top-style](https://drafts.csswg.org/css-borders-4/#propdef-border-top-style)

[border-block-start-width](https://drafts.csswg.org/css-borders-4/#propdef-border-block-start-width)

: Same as
 [border-top-width](https://drafts.csswg.org/css-borders-4/#propdef-border-top-width)

[border-block-style](https://drafts.csswg.org/css-borders-4/#propdef-border-block-style)

: For both specified and computed values, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[border-block-width](https://drafts.csswg.org/css-borders-4/#propdef-border-block-width)

: For both specified and computed values, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[border-bottom](https://drafts.csswg.org/css-borders-4/#propdef-border-bottom)

: Same as
 [border-top](https://drafts.csswg.org/css-borders-4/#propdef-border-top)

[border-bottom-color](https://drafts.csswg.org/css-borders-4/#propdef-border-bottom-color)

: Same as
 [border-top-color](https://drafts.csswg.org/css-borders-4/#propdef-border-top-color)

[border-bottom-style](https://drafts.csswg.org/css-borders-4/#propdef-border-bottom-style)

: Same as
 [border-top-style](https://drafts.csswg.org/css-borders-4/#propdef-border-top-style)

[border-bottom-width](https://drafts.csswg.org/css-borders-4/#propdef-border-bottom-width)

: Same as
 [border-top-width](https://drafts.csswg.org/css-borders-4/#propdef-border-top-width)

[border-boundary](https://drafts.csswg.org/css-round-display-1/#propdef-border-boundary)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[border-collapse](https://drafts.csswg.org/css-tables-3/#propdef-border-collapse)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[border-color](https://drafts.csswg.org/css-borders-4/#propdef-border-color)

: For both specified and computed values, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[border-inline](https://drafts.csswg.org/css-borders-4/#propdef-border-inline)

:

[border-inline-color](https://drafts.csswg.org/css-borders-4/#propdef-border-inline-color)

:

[border-inline-end](https://drafts.csswg.org/css-borders-4/#propdef-border-inline-end)

:

[border-inline-end-color](https://drafts.csswg.org/css-borders-4/#propdef-border-inline-end-color)

:

[border-inline-end-style](https://drafts.csswg.org/css-borders-4/#propdef-border-inline-end-style)

:

[border-inline-end-width](https://drafts.csswg.org/css-borders-4/#propdef-border-inline-end-width)

:

[border-inline-start](https://drafts.csswg.org/css-borders-4/#propdef-border-inline-start)

:

[border-inline-start-color](https://drafts.csswg.org/css-borders-4/#propdef-border-inline-start-color)

:

[border-inline-start-style](https://drafts.csswg.org/css-borders-4/#propdef-border-inline-start-style)

:

[border-inline-start-width](https://drafts.csswg.org/css-borders-4/#propdef-border-inline-start-width)

:

[border-inline-style](https://drafts.csswg.org/css-borders-4/#propdef-border-inline-style)

:

[border-inline-width](https://drafts.csswg.org/css-borders-4/#propdef-border-inline-width)

:

[border-left](https://drafts.csswg.org/css-borders-4/#propdef-border-left)

: Same as
 [border-top](https://drafts.csswg.org/css-borders-4/#propdef-border-top)

[border-left-color](https://drafts.csswg.org/css-borders-4/#propdef-border-left-color)

: Same as
 [border-top-color](https://drafts.csswg.org/css-borders-4/#propdef-border-top-color)

[border-left-style](https://drafts.csswg.org/css-borders-4/#propdef-border-left-style)

: Same as
 [border-top-style](https://drafts.csswg.org/css-borders-4/#propdef-border-top-style)

[border-left-width](https://drafts.csswg.org/css-borders-4/#propdef-border-left-width)

: Same as
 [border-top-width](https://drafts.csswg.org/css-borders-4/#propdef-border-top-width)

[border-radius](https://drafts.csswg.org/css-borders-4/#propdef-border-radius)

: For both specified and computed values, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[border-right](https://drafts.csswg.org/css-borders-4/#propdef-border-right)

: Same as
 [border-top](https://drafts.csswg.org/css-borders-4/#propdef-border-top)

[border-right-color](https://drafts.csswg.org/css-borders-4/#propdef-border-right-color)

: Same as
 [border-top-color](https://drafts.csswg.org/css-borders-4/#propdef-border-top-color)

[border-right-style](https://drafts.csswg.org/css-borders-4/#propdef-border-right-style)

: Same as
 [border-top-style](https://drafts.csswg.org/css-borders-4/#propdef-border-top-style)

[border-right-width](https://drafts.csswg.org/css-borders-4/#propdef-border-right-width)

: Same as
 [border-top-width](https://drafts.csswg.org/css-borders-4/#propdef-border-top-width)

[border-spacing](https://drafts.csswg.org/css2/#propdef-border-spacing)

:

[border-style](https://drafts.csswg.org/css-borders-4/#propdef-border-style)

:

[border-top](https://drafts.csswg.org/css-borders-4/#propdef-border-top)

: For both specified and computed values, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[border-top-color](https://drafts.csswg.org/css-borders-4/#propdef-border-top-color)

: For both specified and computed values:

 1. If the value is [currentcolor], [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 2. Otherwise, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[border-top-style](https://drafts.csswg.org/css-borders-4/#propdef-border-top-style)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[border-top-width](https://drafts.csswg.org/css-borders-4/#propdef-border-top-width)

: For both specified and computed values:

 1. If the value is a
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value), [reify a numeric
 value](#reify-a-numeric-value) from the value and return the result.

 2. Otherwise, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[border-width](https://drafts.csswg.org/css-borders-4/#propdef-border-width)

: For both specified and computed values, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[bottom](https://drafts.csswg.org/css-position-3/#propdef-bottom)

: For both specified and computed values:

 1. If the value is [auto], [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 2. Otherwise, [reify a numeric
 value](#reify-a-numeric-value) from the value and return the result.

[box-decoration-break](https://drafts.csswg.org/css-break-4/#propdef-box-decoration-break)

:

[box-sizing](https://drafts.csswg.org/css-sizing-3/#propdef-box-sizing)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[box-snap](https://drafts.csswg.org/css-line-grid-1/#propdef-box-snap)

:

[break-after](https://drafts.csswg.org/css-break-3/#propdef-break-after)

:

[break-before](https://drafts.csswg.org/css-break-3/#propdef-break-before)

:

[break-inside](https://drafts.csswg.org/css-break-3/#propdef-break-inside)

:

[caption-side](https://drafts.csswg.org/css-tables-3/#propdef-caption-side)

:

[caret](https://drafts.csswg.org/css-ui-4/#propdef-caret)

:

[caret-color](https://drafts.csswg.org/css-ui-4/#propdef-caret-color)

: For both specified and computed values:

 1. If the value is [currentcolor], [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 2. Otherwise, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[caret-shape](https://drafts.csswg.org/css-ui-4/#propdef-caret-shape)

:

[clear](https://drafts.csswg.org/css2/#propdef-clear)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[clip](https://drafts.csswg.org/css-masking-1/#propdef-clip)

:

[clip-path](https://drafts.csswg.org/css-masking-1/#propdef-clip-path)

:

[clip-rule](https://drafts.csswg.org/css-masking-1/#propdef-clip-rule)

:

[color](https://drafts.csswg.org/css-color-4/#propdef-color)

: For both specified and computed values:

 1. If the value is [currentcolor], [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 2. Otherwise, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[color-adjust](https://drafts.csswg.org/css-color-adjust-1/#propdef-color-adjust)

:

[color-interpolation](https://w3c.github.io/svgwg/svg2-draft/painting.html#ColorInterpolationProperty)

:

[color-rendering](https://www.w3.org/TR/SVG2/painting.html#ColorRenderingProperty)

:

[column-gap](https://www.w3.org/TR/css-align-3/#propdef-column-gap)

:

[column-span](https://drafts.csswg.org/css-multicol-2/#propdef-column-span)

:

[contain](https://drafts.csswg.org/css-contain-2/#propdef-contain)

:

[content](https://drafts.csswg.org/css-content-3/#propdef-content)

:

[continue](https://drafts.csswg.org/css-overflow-4/#propdef-continue)

:

[copy-into](https://drafts.csswg.org/css-gcpm-4/#propdef-copy-into)

:

[counter-increment](https://drafts.csswg.org/css-lists-3/#propdef-counter-increment)

:

[counter-reset](https://drafts.csswg.org/css-lists-3/#propdef-counter-reset)

:

[counter-set](https://drafts.csswg.org/css-lists-3/#propdef-counter-set)

:

[cue](https://drafts.csswg.org/css-speech-1/#propdef-cue)

:

[cue-after](https://drafts.csswg.org/css-speech-1/#propdef-cue-after)

:

[cue-before](https://drafts.csswg.org/css-speech-1/#propdef-cue-before)

:

[cursor](https://drafts.csswg.org/css-ui-4/#propdef-cursor)

:

[cx](https://w3c.github.io/svgwg/svg2-draft/geometry.html#CxProperty)

:

[cy](https://w3c.github.io/svgwg/svg2-draft/geometry.html#CyProperty)

:

[d](https://w3c.github.io/svgwg/svg2-draft/paths.html#DProperty)

:

[direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[display](https://drafts.csswg.org/css-display-4/#propdef-display)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[dominant-baseline](https://drafts.csswg.org/css-inline-3/#propdef-dominant-baseline)

:

[elevation](https://www.w3.org/TR/CSS2/aural.html#propdef-elevation)

:

[empty-cells](https://drafts.csswg.org/css-tables-3/#propdef-empty-cells)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[fill](https://w3c.github.io/svgwg/svg2-draft/painting.html#FillProperty)

:

[fill-break](https://drafts.csswg.org/fill-stroke-3/#propdef-fill-break)

:

[fill-color](https://drafts.csswg.org/fill-stroke-3/#propdef-fill-color)

:

[fill-image](https://drafts.csswg.org/fill-stroke-3/#propdef-fill-image)

:

[fill-opacity](https://w3c.github.io/svgwg/svg2-draft/painting.html#FillOpacityProperty)

:

[fill-origin](https://drafts.csswg.org/fill-stroke-3/#propdef-fill-origin)

:

[fill-position](https://drafts.csswg.org/fill-stroke-3/#propdef-fill-position)

:

[fill-repeat](https://drafts.csswg.org/fill-stroke-3/#propdef-fill-repeat)

:

[fill-rule](https://w3c.github.io/svgwg/svg2-draft/painting.html#FillRuleProperty)

:

[fill-size](https://drafts.csswg.org/fill-stroke-3/#propdef-fill-size)

:

\'filter-margin-top, filter-margin-right, filter-margin-bottom, filter-margin-left\'

:

[flex](https://drafts.csswg.org/css-flexbox-2/#propdef-flex)

:

[flex-basis](https://drafts.csswg.org/css-flexbox-2/#propdef-flex-basis)

:

[flex-direction](https://drafts.csswg.org/css-flexbox-2/#propdef-flex-direction)

:

[flex-flow](https://drafts.csswg.org/css-flexbox-2/#propdef-flex-flow)

:

[flex-grow](https://drafts.csswg.org/css-flexbox-2/#propdef-flex-grow)

:

[flex-shrink](https://drafts.csswg.org/css-flexbox-2/#propdef-flex-shrink)

:

[flex-wrap](https://drafts.csswg.org/css-flexbox-2/#propdef-flex-wrap)

:

[float](https://drafts.csswg.org/css2/#propdef-float)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[float-defer](https://drafts.csswg.org/css-page-floats-3/#propdef-float-defer)

:

[font](https://drafts.csswg.org/css-fonts-4/#propdef-font)

: For both specified and computed values, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[font-family](https://drafts.csswg.org/css-fonts-4/#propdef-font-family)

: For both specified and computed values, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[font-language-override](https://drafts.csswg.org/css-fonts-4/#propdef-font-language-override)

: For both specified and computed values:

 1. If the value is [normal], [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 2. Otherwise, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[font-optical-sizing](https://drafts.csswg.org/css-fonts-4/#propdef-font-optical-sizing)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[font-palette](https://drafts.csswg.org/css-fonts-4/#propdef-font-palette)

: For both specified and computed values:

 1. If the value is [normal], [light] or [dark],
 [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 2. Otherwise, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size)

: For both specified and computed values:

 1. If the value is an
 [\<absolute-size\>](https://drafts.csswg.org/css-fonts-4/#typedef-absolute-size) or
 [\<relative-size\>](https://drafts.csswg.org/css-fonts-4/#typedef-relative-size), [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 2. Otherwise, [reify a numeric
 value](#reify-a-numeric-value) from the value and return the result.

[font-size-adjust](https://drafts.csswg.org/css-fonts-4/#propdef-font-size-adjust)

: For both specified and computed values:

 1. If the value is [none], [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 2. Otherwise, [reify a numeric
 value](#reify-a-numeric-value) from the value and return the result.

[font-stretch](https://drafts.csswg.org/css-fonts-4/#propdef-font-stretch)

: For both specified and computed values:

 1. If the value is a
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value), [reify a numeric
 value](#reify-a-numeric-value) from the value and return the result.

 2. Otherwise, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[font-style](https://drafts.csswg.org/css-fonts-4/#propdef-font-style)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[font-synthesis](https://drafts.csswg.org/css-fonts-4/#propdef-font-synthesis)

: For both specified and computed values:

 1. If the value is [none], [weight], [style] or
 [small-caps], [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 2. Otherwise, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[font-variant](https://drafts.csswg.org/css-fonts-4/#propdef-font-variant)

: For both specified and computed values, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[font-variant-alternates](https://drafts.csswg.org/css-fonts-4/#propdef-font-variant-alternates)

: For both specified and computed values:

 1. If the value is [none] or [historical-forms], [reify
 an
 identifier](#reify-an-identifier) from the value and return the result.

 2. Otherwise, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[font-variant-emoji](https://drafts.csswg.org/css-fonts-4/#propdef-font-variant-emoji)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[font-variation-settings](https://drafts.csswg.org/css-fonts-4/#propdef-font-variation-settings)

: For both specified and computed values:

 1. If the value is [normal], [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 2. Otherwise, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[font-weight](https://drafts.csswg.org/css-fonts-4/#propdef-font-weight)

: For both specified and computed values:

 1. If the value is a
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value), [reify a numeric
 value](#reify-a-numeric-value) from the value and return the result.

 2. Otherwise, [reify an
 identifier](#reify-an-identifier) from the value

[gap](https://drafts.csswg.org/css-gaps-1/#propdef-gap)

:

[glyph-orientation-vertical](https://drafts.csswg.org/css-writing-modes-4/#propdef-glyph-orientation-vertical)

:

[grid](https://drafts.csswg.org/css-grid-2/#propdef-grid)

:

[grid-area](https://drafts.csswg.org/css-grid-2/#propdef-grid-area)

:

[grid-auto-columns](https://drafts.csswg.org/css-grid-2/#propdef-grid-auto-columns)

:

[grid-auto-flow](https://drafts.csswg.org/css-grid-2/#propdef-grid-auto-flow)

:

[grid-auto-rows](https://drafts.csswg.org/css-grid-2/#propdef-grid-auto-rows)

:

[grid-column](https://drafts.csswg.org/css-grid-2/#propdef-grid-column)

:

[grid-column-end](https://drafts.csswg.org/css-grid-2/#propdef-grid-column-end)

:

[grid-column-gap](https://drafts.csswg.org/css-gaps-1/#propdef-grid-column-gap)

:

[grid-column-start](https://drafts.csswg.org/css-grid-2/#propdef-grid-column-start)

:

[grid-gap](https://drafts.csswg.org/css-gaps-1/#propdef-grid-gap)

:

[grid-row](https://drafts.csswg.org/css-grid-2/#propdef-grid-row)

:

[grid-row-end](https://drafts.csswg.org/css-grid-2/#propdef-grid-row-end)

:

[grid-row-gap](https://drafts.csswg.org/css-gaps-1/#propdef-grid-row-gap)

:

[grid-row-start](https://drafts.csswg.org/css-grid-2/#propdef-grid-row-start)

:

[grid-template](https://drafts.csswg.org/css-grid-2/#propdef-grid-template)

:

[grid-template-areas](https://drafts.csswg.org/css-grid-2/#propdef-grid-template-areas)

:

[grid-template-columns](https://drafts.csswg.org/css-grid-2/#propdef-grid-template-columns)

:

[grid-template-rows](https://drafts.csswg.org/css-grid-2/#propdef-grid-template-rows)

:

[height](https://drafts.csswg.org/css-sizing-3/#propdef-height)

: For both specified and computed values:

 1. If the value is [auto], [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 2. If the value is a
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value) or
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value), [reify a numeric
 value](#reify-a-numeric-value) from the value and return the result.

[image-rendering](https://drafts.csswg.org/css-images-3/#propdef-image-rendering)

:

[image-resolution](https://drafts.csswg.org/css-images-4/#propdef-image-resolution)

:

[initial-letter](https://drafts.csswg.org/css-inline-3/#propdef-initial-letter)

:

[initial-letter-align](https://drafts.csswg.org/css-inline-3/#propdef-initial-letter-align)

:

[initial-letter-wrap](https://drafts.csswg.org/css-inline-3/#propdef-initial-letter-wrap)

:

[inline-size](https://drafts.csswg.org/css-logical-1/#propdef-inline-size)

:

[inset](https://drafts.csswg.org/css-position-3/#propdef-inset)

:

[inset-block](https://drafts.csswg.org/css-position-3/#propdef-inset-block)

:

[inset-block-end](https://drafts.csswg.org/css-position-3/#propdef-inset-block-end)

:

[inset-block-start](https://drafts.csswg.org/css-position-3/#propdef-inset-block-start)

:

[inset-inline](https://drafts.csswg.org/css-position-3/#propdef-inset-inline)

:

[inset-inline-end](https://drafts.csswg.org/css-position-3/#propdef-inset-inline-end)

:

[inset-inline-start](https://drafts.csswg.org/css-position-3/#propdef-inset-inline-start)

:

[isolation](https://drafts.csswg.org/compositing-2/#propdef-isolation)

:

[justify-content](https://drafts.csswg.org/css-align-3/#propdef-justify-content)

:

[justify-items](https://drafts.csswg.org/css-align-3/#propdef-justify-items)

:

[justify-self](https://drafts.csswg.org/css-align-3/#propdef-justify-self)

:

[left](https://drafts.csswg.org/css-position-3/#propdef-left)

: For both specified and computed values:

 1. If the value is [auto], [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 2. Otherwise, [reify a numeric
 value](#reify-a-numeric-value) from the value and return the result.

[letter-spacing](https://drafts.csswg.org/css-text-4/#propdef-letter-spacing)

:

[line-grid](https://drafts.csswg.org/css-line-grid-1/#propdef-line-grid)

:

[line-height](https://drafts.csswg.org/css2/#propdef-line-height)

: For both specified and computed values:

 1. If the value is [normal], [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 2. Otherwise, [reify a numeric
 value](#reify-a-numeric-value) from the value and return the result.

[line-height-step](https://drafts.csswg.org/css-rhythm-1/#propdef-line-height-step)

:

[line-snap](https://drafts.csswg.org/css-line-grid-1/#propdef-line-snap)

:

[list-style](https://drafts.csswg.org/css-lists-3/#propdef-list-style)

:

[list-style-image](https://drafts.csswg.org/css-lists-3/#propdef-list-style-image)

: For both specified and computed values:

 1. If the value is [none], [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 2. If the value is a
 [url()](https://drafts.csswg.org/css-values-4/#funcdef-url) function, [reify a url]
 from the value and return the result.

 3. Otherwise, [reify an image] from the value and
 return the result.

[list-style-position](https://drafts.csswg.org/css-lists-3/#propdef-list-style-position)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[list-style-type](https://drafts.csswg.org/css-lists-3/#propdef-list-style-type)

:

[margin](https://drafts.csswg.org/css-box-4/#propdef-margin)

: For both specified and computed values, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[margin-block](https://drafts.csswg.org/css-logical-1/#propdef-margin-block)

:

[margin-block-end](https://drafts.csswg.org/css-logical-1/#propdef-margin-block-end)

:

[margin-block-start](https://drafts.csswg.org/css-logical-1/#propdef-margin-block-start)

:

[margin-bottom](https://drafts.csswg.org/css-box-4/#propdef-margin-bottom)

: Same as
 [margin-top](https://drafts.csswg.org/css-box-4/#propdef-margin-top)

[margin-inline](https://drafts.csswg.org/css-logical-1/#propdef-margin-inline)

:

[margin-inline-end](https://drafts.csswg.org/css-logical-1/#propdef-margin-inline-end)

:

[margin-inline-start](https://drafts.csswg.org/css-logical-1/#propdef-margin-inline-start)

:

[margin-left](https://drafts.csswg.org/css-box-4/#propdef-margin-left)

: Same as
 [margin-top](https://drafts.csswg.org/css-box-4/#propdef-margin-top)

[margin-right](https://drafts.csswg.org/css-box-4/#propdef-margin-right)

: Same as
 [margin-top](https://drafts.csswg.org/css-box-4/#propdef-margin-top)

[margin-top](https://drafts.csswg.org/css-box-4/#propdef-margin-top)

: For both specified and computed values:

 1. If the value is [auto], [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 2. Otherwise, [reify a numeric
 value](#reify-a-numeric-value) from the value and return the result.

[marker](https://w3c.github.io/svgwg/svg2-draft/painting.html#MarkerProperty)

:

[marker-end](https://w3c.github.io/svgwg/svg2-draft/painting.html#MarkerEndProperty)

:

[marker-mid](https://w3c.github.io/svgwg/svg2-draft/painting.html#MarkerMidProperty)

:

[marker-side](https://drafts.csswg.org/css-lists-3/#propdef-marker-side)

:

[marker-start](https://w3c.github.io/svgwg/svg2-draft/painting.html#MarkerStartProperty)

:

[mask](https://drafts.csswg.org/css-masking-1/#propdef-mask)

:

[mask-border](https://drafts.csswg.org/css-masking-1/#propdef-mask-border)

:

[mask-border-mode](https://drafts.csswg.org/css-masking-1/#propdef-mask-border-mode)

:

[mask-border-outset](https://drafts.csswg.org/css-masking-1/#propdef-mask-border-outset)

:

[mask-border-repeat](https://drafts.csswg.org/css-masking-1/#propdef-mask-border-repeat)

:

[mask-border-slice](https://drafts.csswg.org/css-masking-1/#propdef-mask-border-slice)

:

[mask-border-source](https://drafts.csswg.org/css-masking-1/#propdef-mask-border-source)

:

[mask-border-width](https://drafts.csswg.org/css-masking-1/#propdef-mask-border-width)

:

[mask-clip](https://drafts.csswg.org/css-masking-1/#propdef-mask-clip)

:

[mask-composite](https://drafts.csswg.org/css-masking-1/#propdef-mask-composite)

:

[mask-image](https://drafts.csswg.org/css-masking-1/#propdef-mask-image)

: For both specified and computed values:

 1. If the value is [none], [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 2. Otherwise, [reify an image] from the value and
 return the result.

[mask-mode](https://drafts.csswg.org/css-masking-1/#propdef-mask-mode)

:

[mask-origin](https://drafts.csswg.org/css-masking-1/#propdef-mask-origin)

:

[mask-position](https://drafts.csswg.org/css-masking-1/#propdef-mask-position)

:

[mask-repeat](https://drafts.csswg.org/css-masking-1/#propdef-mask-repeat)

:

[mask-size](https://drafts.csswg.org/css-masking-1/#propdef-mask-size)

:

[mask-type](https://drafts.csswg.org/css-masking-1/#propdef-mask-type)

:

[max-block-size](https://drafts.csswg.org/css-logical-1/#propdef-max-block-size)

:

[max-height](https://drafts.csswg.org/css-sizing-3/#propdef-max-height)

:

[max-inline-size](https://drafts.csswg.org/css-logical-1/#propdef-max-inline-size)

:

[max-lines](https://drafts.csswg.org/css-overflow-4/#propdef-max-lines)

:

[max-width](https://drafts.csswg.org/css-sizing-3/#propdef-max-width)

:

[min-block-size](https://drafts.csswg.org/css-logical-1/#propdef-min-block-size)

:

[min-height](https://drafts.csswg.org/css-sizing-3/#propdef-min-height)

:

[min-inline-size](https://drafts.csswg.org/css-logical-1/#propdef-min-inline-size)

:

[min-width](https://drafts.csswg.org/css-sizing-3/#propdef-min-width)

:

[mix-blend-mode](https://drafts.csswg.org/compositing-2/#propdef-mix-blend-mode)

:

[nav-down](https://drafts.csswg.org/css-ui-4/#propdef-nav-down)

:

[nav-left](https://drafts.csswg.org/css-ui-4/#propdef-nav-left)

:

[nav-right](https://drafts.csswg.org/css-ui-4/#propdef-nav-right)

:

[nav-up](https://drafts.csswg.org/css-ui-4/#propdef-nav-up)

:

[object-fit](https://drafts.csswg.org/css-images-4/#propdef-object-fit)

:

[offset](https://drafts.csswg.org/motion-1/#propdef-offset)

:

[offset-anchor](https://drafts.csswg.org/motion-1/#propdef-offset-anchor)

:

[offset-distance](https://drafts.csswg.org/motion-1/#propdef-offset-distance)

:

[offset-path](https://drafts.csswg.org/motion-1/#propdef-offset-path)

:

[offset-position](https://drafts.csswg.org/motion-1/#propdef-offset-position)

:

[offset-rotate](https://drafts.csswg.org/motion-1/#propdef-offset-rotate)

:

[opacity](https://drafts.csswg.org/css-color-4/#propdef-opacity)

: For both specified and computed values, [reify a numeric
 value](#reify-a-numeric-value) from the value and return the result.

[order](https://drafts.csswg.org/css-display-4/#propdef-order)

:

[orphans](https://drafts.csswg.org/css-break-3/#propdef-orphans)

:

[outline](https://drafts.csswg.org/css-ui-4/#propdef-outline)

:

[outline-color](https://drafts.csswg.org/css-ui-4/#propdef-outline-color)

: For both specified and computed values:

 1. If the value is [currentcolor], [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 2. Otherwise, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[outline-offset](https://drafts.csswg.org/css-ui-4/#propdef-outline-offset)

:

[outline-style](https://drafts.csswg.org/css-ui-4/#propdef-outline-style)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[outline-width](https://drafts.csswg.org/css-ui-4/#propdef-outline-width)

:

[overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow)

: For both specified and computed values, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[overflow-anchor](https://drafts.csswg.org/css-scroll-anchoring-1/#propdef-overflow-anchor)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[overflow-x](https://drafts.csswg.org/css-overflow-3/#propdef-overflow-x)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[overflow-y](https://drafts.csswg.org/css-overflow-3/#propdef-overflow-y)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[padding](https://drafts.csswg.org/css-box-4/#propdef-padding)

: For both specified and computed values, reify as a
 [`CSSStyleValue`](#cssstylevalue) and return the result.

[padding-block](https://drafts.csswg.org/css-logical-1/#propdef-padding-block)

:

[padding-block-end](https://drafts.csswg.org/css-logical-1/#propdef-padding-block-end)

:

[padding-block-start](https://drafts.csswg.org/css-logical-1/#propdef-padding-block-start)

:

[padding-bottom](https://drafts.csswg.org/css-box-4/#propdef-padding-bottom)

: Same as
 [padding-top](https://drafts.csswg.org/css-box-4/#propdef-padding-top)

[padding-inline](https://drafts.csswg.org/css-logical-1/#propdef-padding-inline)

:

[padding-inline-end](https://drafts.csswg.org/css-logical-1/#propdef-padding-inline-end)

:

[padding-inline-start](https://drafts.csswg.org/css-logical-1/#propdef-padding-inline-start)

:

[padding-left](https://drafts.csswg.org/css-box-4/#propdef-padding-left)

: Same as
 [padding-top](https://drafts.csswg.org/css-box-4/#propdef-padding-top)

[padding-right](https://drafts.csswg.org/css-box-4/#propdef-padding-right)

: Same as
 [padding-top](https://drafts.csswg.org/css-box-4/#propdef-padding-top)

[padding-top](https://drafts.csswg.org/css-box-4/#propdef-padding-top)

: For both specified and computed values, [reify a numeric
 value](#reify-a-numeric-value) from the value and return the result.

[page](https://drafts.csswg.org/css-page-3/#propdef-page)

:

[page-break-after](https://drafts.csswg.org/css2/#propdef-page-break-after)

:

[page-break-before](https://drafts.csswg.org/css2/#propdef-page-break-before)

:

[page-break-inside](https://drafts.csswg.org/css2/#propdef-page-break-inside)

:

[paint-order](https://w3c.github.io/svgwg/svg2-draft/painting.html#PaintOrderProperty)

:

[pause](https://drafts.csswg.org/css-speech-1/#propdef-pause)

:

[pause-after](https://drafts.csswg.org/css-speech-1/#propdef-pause-after)

:

[pause-before](https://drafts.csswg.org/css-speech-1/#propdef-pause-before)

:

[perspective](https://drafts.csswg.org/css-transforms-2/#propdef-perspective)

:

[perspective-origin](https://drafts.csswg.org/css-transforms-2/#propdef-perspective-origin)

:

[pitch](https://www.w3.org/TR/CSS2/aural.html#propdef-pitch)

:

[pitch-range](https://www.w3.org/TR/CSS2/aural.html#propdef-pitch-range)

:

[place-content](https://drafts.csswg.org/css-align-3/#propdef-place-content)

:

[place-items](https://drafts.csswg.org/css-align-3/#propdef-place-items)

:

[place-self](https://drafts.csswg.org/css-align-3/#propdef-place-self)

:

[play-during](https://www.w3.org/TR/CSS2/aural.html#propdef-play-during)

:

[pointer-events](https://drafts.csswg.org/css-ui-4/#propdef-pointer-events)

:

[position](https://drafts.csswg.org/css-position-3/#propdef-position)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[quotes](https://drafts.csswg.org/css-content-3/#propdef-quotes)

:

[r](https://w3c.github.io/svgwg/svg2-draft/geometry.html#RProperty)

:

[region-fragment](https://drafts.csswg.org/css-regions-1/#propdef-region-fragment)

:

[resize](https://drafts.csswg.org/css-ui-4/#propdef-resize)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[rest](https://drafts.csswg.org/css-speech-1/#propdef-rest)

:

[rest-after](https://drafts.csswg.org/css-speech-1/#propdef-rest-after)

:

[rest-before](https://drafts.csswg.org/css-speech-1/#propdef-rest-before)

:

[richness](https://www.w3.org/TR/CSS2/aural.html#propdef-richness)

:

[right](https://drafts.csswg.org/css-position-3/#propdef-right)

: For both specified and computed values:

 1. If the value is [auto], [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 2. Otherwise, [reify a numeric
 value](#reify-a-numeric-value) from the value and return the result.

[rotate](https://drafts.csswg.org/css-transforms-2/#propdef-rotate)

:

[row-gap](https://drafts.csswg.org/css-gaps-1/#propdef-row-gap)

:

[ruby-align](https://drafts.csswg.org/css-ruby-1/#propdef-ruby-align)

:

[ruby-merge](https://drafts.csswg.org/css-ruby-1/#propdef-ruby-merge)

:

[ruby-position](https://drafts.csswg.org/css-ruby-1/#propdef-ruby-position)

:

[rx](https://w3c.github.io/svgwg/svg2-draft/geometry.html#RxProperty)

:

[ry](https://w3c.github.io/svgwg/svg2-draft/geometry.html#RyProperty)

:

[scale](https://drafts.csswg.org/css-transforms-2/#propdef-scale)

:

[scroll-behavior](https://drafts.csswg.org/css-overflow-3/#propdef-scroll-behavior)

:

[scroll-margin](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-margin)

:

[scroll-margin-block](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-margin-block)

:

[scroll-margin-block-end](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-margin-block-end)

:

[scroll-margin-block-start](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-margin-block-start)

:

[scroll-margin-bottom](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-margin-bottom)

:

[scroll-margin-inline](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-margin-inline)

:

[scroll-margin-inline-end](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-margin-inline-end)

:

[scroll-margin-inline-start](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-margin-inline-start)

:

[scroll-margin-left](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-margin-left)

:

[scroll-margin-right](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-margin-right)

:

[scroll-margin-top](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-margin-top)

:

[scroll-padding](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-padding)

:

[scroll-padding-block](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-padding-block)

:

[scroll-padding-block-end](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-padding-block-end)

:

[scroll-padding-block-start](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-padding-block-start)

:

[scroll-padding-bottom](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-padding-bottom)

:

[scroll-padding-inline](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-padding-inline)

:

[scroll-padding-inline-end](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-padding-inline-end)

:

[scroll-padding-inline-start](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-padding-inline-start)

:

[scroll-padding-left](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-padding-left)

:

[scroll-padding-right](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-padding-right)

:

[scroll-padding-top](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-padding-top)

:

[scroll-snap-align](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-snap-align)

:

[scroll-snap-stop](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-snap-stop)

:

[scroll-snap-type](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-snap-type)

:

[scrollbar-gutter](https://drafts.csswg.org/css-overflow-3/#propdef-scrollbar-gutter)

:

[shape-inside](https://drafts.csswg.org/css-shapes-2/#propdef-shape-inside)

:

[shape-margin](https://drafts.csswg.org/css-shapes-1/#propdef-shape-margin)

:

[shape-padding](https://drafts.csswg.org/css-shapes-2/#propdef-shape-padding)

:

[shape-rendering](https://w3c.github.io/svgwg/svg2-draft/painting.html#ShapeRenderingProperty)

:

[shape-subtract](https://www.w3.org/TR/SVG2/text.html#ShapesubtractProperty)

:

[speak](https://drafts.csswg.org/css-speech-1/#propdef-speak)

:

[speak-as](https://drafts.csswg.org/css-speech-1/#propdef-speak-as)

:

[speak-header](https://www.w3.org/TR/CSS2/aural.html#propdef-speak-header)

:

[speak-numeral](https://www.w3.org/TR/CSS2/aural.html#propdef-speak-numeral)

:

[speak-punctuation](https://www.w3.org/TR/CSS2/aural.html#propdef-speak-punctuation)

:

[speech-rate](https://www.w3.org/TR/CSS2/aural.html#propdef-speech-rate)

:

[stop-color](https://w3c.github.io/svgwg/svg2-draft/pservers.html#StopColorProperty)

:

[stop-opacity](https://w3c.github.io/svgwg/svg2-draft/pservers.html#StopOpacityProperty)

:

[stress](https://www.w3.org/TR/CSS2/aural.html#propdef-stress)

:

[stroke](https://w3c.github.io/svgwg/svg2-draft/painting.html#StrokeProperty)

:

[stroke-align](https://drafts.csswg.org/fill-stroke-3/#propdef-stroke-align)

:

[stroke-break](https://drafts.csswg.org/fill-stroke-3/#propdef-stroke-break)

:

[stroke-color](https://drafts.csswg.org/fill-stroke-3/#propdef-stroke-color)

:

[stroke-dash-corner](https://drafts.csswg.org/fill-stroke-3/#propdef-stroke-dash-corner)

:

[stroke-dash-justify](https://drafts.csswg.org/fill-stroke-3/#propdef-stroke-dash-justify)

:

[stroke-dasharray](https://w3c.github.io/svgwg/svg2-draft/painting.html#StrokeDasharrayProperty)

:

[stroke-dashoffset](https://w3c.github.io/svgwg/svg2-draft/painting.html#StrokeDashoffsetProperty)

:

[stroke-image](https://drafts.csswg.org/fill-stroke-3/#propdef-stroke-image)

:

[stroke-linecap](https://w3c.github.io/svgwg/svg2-draft/painting.html#StrokeLinecapProperty)

:

[stroke-linejoin](https://w3c.github.io/svgwg/svg2-draft/painting.html#StrokeLinejoinProperty)

:

[stroke-miterlimit](https://w3c.github.io/svgwg/svg2-draft/painting.html#StrokeMiterlimitProperty)

:

[stroke-opacity](https://w3c.github.io/svgwg/svg2-draft/painting.html#StrokeOpacityProperty)

:

[stroke-origin](https://drafts.csswg.org/fill-stroke-3/#propdef-stroke-origin)

:

[stroke-position](https://drafts.csswg.org/fill-stroke-3/#propdef-stroke-position)

:

[stroke-repeat](https://drafts.csswg.org/fill-stroke-3/#propdef-stroke-repeat)

:

[stroke-size](https://drafts.csswg.org/fill-stroke-3/#propdef-stroke-size)

:

[stroke-width](https://w3c.github.io/svgwg/svg2-draft/painting.html#StrokeWidthProperty)

:

[table-layout](https://drafts.csswg.org/css-tables-3/#propdef-table-layout)

:

[text-align](https://drafts.csswg.org/css-text-3/#propdef-text-align)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[text-anchor](https://w3c.github.io/svgwg/svg2-draft/text.html#TextAnchorProperty)

:

[text-combine-upright](https://drafts.csswg.org/css-writing-modes-4/#propdef-text-combine-upright)

:

[text-decoration](https://drafts.csswg.org/css-text-decor-4/#propdef-text-decoration)

:

[text-decoration-fill](https://www.w3.org/TR/SVG2/text.html#TextDecorationFillProperty)

:

[text-decoration-skip](https://drafts.csswg.org/css-text-decor-4/#propdef-text-decoration-skip)

:

[text-decoration-skip-ink](https://drafts.csswg.org/css-text-decor-4/#propdef-text-decoration-skip-ink)

:

[text-decoration-stroke](https://www.w3.org/TR/SVG2/text.html#TextDecorationStrokeProperty)

:

[text-decoration-thickness](https://drafts.csswg.org/css-text-decor-4/#propdef-text-decoration-thickness)

:

[text-emphasis-skip](https://drafts.csswg.org/css-text-decor-4/#propdef-text-emphasis-skip)

:

[text-indent](https://drafts.csswg.org/css-text-4/#propdef-text-indent)

:

[text-orientation](https://drafts.csswg.org/css-writing-modes-4/#propdef-text-orientation)

:

[text-overflow](https://drafts.csswg.org/css-overflow-3/#propdef-text-overflow)

:

[text-rendering](https://w3c.github.io/svgwg/svg2-draft/painting.html#TextRenderingProperty)

:

[text-size-adjust](https://drafts.csswg.org/css-size-adjust-1/#propdef-text-size-adjust)

:

[text-transform](https://drafts.csswg.org/css-text-4/#propdef-text-transform)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[text-underline-offset](https://drafts.csswg.org/css-text-decor-4/#propdef-text-underline-offset)

:

[top](https://drafts.csswg.org/css-position-3/#propdef-top)

: For both specified and computed values:

 1. If the value is [auto], [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 2. Otherwise, [reify a numeric
 value](#reify-a-numeric-value) from the value and return the result.

[transform-style](https://drafts.csswg.org/css-transforms-2/#propdef-transform-style)

:

[transition](https://drafts.csswg.org/css-transitions-1/#propdef-transition)

:

[transition-delay](https://drafts.csswg.org/css-transitions-1/#propdef-transition-delay)

:

[transition-duration](https://drafts.csswg.org/css-transitions-1/#propdef-transition-duration)

:

[transition-property](https://drafts.csswg.org/css-transitions-1/#propdef-transition-property)

:

[transition-timing-function](https://drafts.csswg.org/css-transitions-1/#propdef-transition-timing-function)

:

[translate](https://drafts.csswg.org/css-transforms-2/#propdef-translate)

:

[unicode-bidi](https://drafts.csswg.org/css-writing-modes-3/#propdef-unicode-bidi)

:

[user-select](https://drafts.csswg.org/css-ui-4/#propdef-user-select)

:

[vector-effect](https://w3c.github.io/svgwg/svg2-draft/coords.html#VectorEffectProperty)

:

[vertical-align](https://drafts.csswg.org/css-inline-3/#propdef-vertical-align)

: For both specified and computed values:

 1. If the value is [baseline], [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 2. Otherwise, [reify a numeric
 value](#reify-a-numeric-value) from the value and return the result.

[visibility](https://drafts.csswg.org/css-display-4/#propdef-visibility)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[voice-balance](https://drafts.csswg.org/css-speech-1/#propdef-voice-balance)

:

[voice-duration](https://drafts.csswg.org/css-speech-1/#propdef-voice-duration)

:

[voice-family](https://drafts.csswg.org/css-speech-1/#propdef-voice-family)

:

[voice-pitch](https://drafts.csswg.org/css-speech-1/#propdef-voice-pitch)

:

[voice-range](https://drafts.csswg.org/css-speech-1/#propdef-voice-range)

:

[voice-rate](https://drafts.csswg.org/css-speech-1/#propdef-voice-rate)

:

[voice-stress](https://drafts.csswg.org/css-speech-1/#propdef-voice-stress)

:

[voice-volume](https://drafts.csswg.org/css-speech-1/#propdef-voice-volume)

:

[volume](https://www.w3.org/TR/CSS2/aural.html#propdef-volume)

:

[white-space](https://drafts.csswg.org/css-text-4/#propdef-white-space)

: For both specified and computed values, [reify an
 identifier](#reify-an-identifier) from the value and return the result.

[widows](https://drafts.csswg.org/css-break-4/#propdef-widows)

:

[width](https://drafts.csswg.org/css-sizing-3/#propdef-width)

: For both specified and computed values:

 1. If the value is [auto], [reify an
 identifier](#reify-an-identifier) from the value and return the result.

 2. If the value is a
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value) or
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value), [reify a numeric
 value](#reify-a-numeric-value) from the value and return the result.

[will-change](https://drafts.csswg.org/css-will-change-1/#propdef-will-change)

:

[word-spacing](https://drafts.csswg.org/css-text-4/#propdef-word-spacing)

:

[writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode)

:

[x](https://w3c.github.io/svgwg/svg2-draft/geometry.html#XProperty)

:

[y](https://w3c.github.io/svgwg/svg2-draft/geometry.html#YProperty)

:

[z-index](https://drafts.csswg.org/css2/#propdef-z-index)

:

### 5.2. Unrepresentable Values

Not all [internal
representations](#css-internal-representation) are simple enough to be
[reified](#css-reify) with the
current set of
[`CSSStyleValue`](#cssstylevalue) subclasses. When this is the case, the property is
[reified as a
CSSStyleValue](#reify-as-a-cssstylevalue) for a particular property, ensuring that it can be used
as a value for that property, and nothing else.

To [reify as a CSSStyleValue] a
`value` for a `property`:

1. Return a new
 [`CSSStyleValue`](#cssstylevalue) object representing `value` whose
 [`[[associatedProperty]]`](#dom-cssstylevalue-associatedproperty-slot) internal slot is set to `property`.

### [5.3. ][Raw CSS tokens: properties with [var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) references]
Regardless of what the property's grammar is otherwise, a property value
with an un-substituted
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) reference is represented as a
[list](https://infra.spec.whatwg.org/#list) of [component
values](https://drafts.csswg.org/css-syntax-3/#component-value), which becomes a
[`CSSUnparsedValue`](#cssunparsedvalue) in the Typed OM.

To [reify a list of component values] from a `list`:

1. Replace all
 [var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) references in `list` with
 [`CSSVariableReferenceValue`](#cssvariablereferencevalue) objects, as described in [§ 5.4 var()
 References](#reify-var).

2. Replace each remaining maximal subsequence of [component
 values](https://drafts.csswg.org/css-syntax-3/#component-value) in `list` with a single string of their
 concatenated serializations.

3. Return a new
 [`CSSUnparsedValue`](#cssunparsedvalue) whose
 [`[[tokens]]`](#dom-cssunparsedvalue-tokens-slot) slot is set to `list`.

The string \"calc(42px + var(\--foo,
15em) + var(\--bar, var(\--far) + 15px))\" is converted into a
[`CSSUnparsedValue`](#cssunparsedvalue) that contains a sequence with:

- the string \"calc(42px + \"

- a
 [`CSSVariableReferenceValue`](#cssvariablereferencevalue) with:

 - [`variable`](#dom-cssvariablereferencevalue-variable) \"\--foo\"

 - [`fallback`](#dom-cssvariablereferencevalue-fallback) a
 [`CSSUnparsedValue`](#cssunparsedvalue) with a single-valued sequence containing \" 15em\"

- the string \" + \"

- a
 [`CSSVariableReferenceValue`](#cssvariablereferencevalue) with:

 - [`variable`](#dom-cssvariablereferencevalue-variable) \"\--bar\"

 - [`fallback`](#dom-cssvariablereferencevalue-fallback) a
 [`CSSUnparsedValue`](#cssunparsedvalue) with a sequence containing:

 - the string \" \"

 - a
 [`CSSVariableReferenceValue`](#cssvariablereferencevalue) with

 - [`variable`](#dom-cssvariablereferencevalue-variable) \"\--far\"

 - [`fallback`](#dom-cssvariablereferencevalue-fallback) null

 - the string \" + 15px\"

- the string \")\"

### [5.4. ][[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) References]
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) references become
[`CSSVariableReferenceValue`](#cssvariablereferencevalue)s in the Typed OM.

To [reify a
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var) reference] `var`:

1. Let `object` be a new
 [`CSSVariableReferenceValue`](#cssvariablereferencevalue).

2. Set `object`'s
 [`variable`](#dom-cssvariablereferencevalue-variable) internal slot to the serialization of the
 [\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value) providing the variable name.

3. If `var` has a fallback value, set `object`'s
 [`fallback`](#dom-cssvariablereferencevalue-fallback) internal slot to the result of [reifying the
 fallback's component
 values](#reify-a-list-of-component-values). Otherwise, set it to `null`.

4. Return `object`.

### [5.5. ][[Identifier](https://drafts.csswg.org/css-values-4/#css-css-identifier) Values]
CSS
[identifiers](https://drafts.csswg.org/css-values-4/#css-css-identifier) become
[`CSSKeywordValue`](#csskeywordvalue)s in the Typed OM.

To [reify an
[identifier](https://drafts.csswg.org/css-values-4/#css-css-identifier)] `ident`:

1. Return a new
 [`CSSKeywordValue`](#csskeywordvalue) with its
 [`value`](#dom-csskeywordvalue-value) internal slot set to the serialization of
 `ident`.

### [5.6. ][[\<number\>](https://drafts.csswg.org/css-values-4/#number-value), [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value), and [\<dimension\>](https://drafts.csswg.org/css-values-4/#typedef-dimension) values]
CSS
[\<number\>](https://drafts.csswg.org/css-values-4/#number-value),
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value), and
[\<dimension\>](https://drafts.csswg.org/css-values-4/#typedef-dimension) values become
[`CSSNumericValue`](#cssnumericvalue)s in the Typed OM.

To [reify a numeric value] `num`:

1. If `num` is a [math
 function](https://drafts.csswg.org/css-values-4/#math-function), [reify a math
 expression](#reify-a-math-expression) from `num` and return the result.

2. If `num` is the unitless value [0] and
 `num` is a
 [\<dimension\>](https://drafts.csswg.org/css-values-4/#typedef-dimension), return a new
 [`CSSUnitValue`](#cssunitvalue) with its
 [`value`](#dom-cssunitvalue-value) internal slot set to 0, and its
 [`unit`](#dom-cssunitvalue-unit) internal slot set to \"px\".

3. Return a new
 [`CSSUnitValue`](#cssunitvalue) with its
 [`value`](#dom-cssunitvalue-value) internal slot set to the numeric value of
 `num`, and its
 [`unit`](#dom-cssunitvalue-unit) internal slot set to \"number\" if `num`
 is a
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value), \"percent\" if `num`
 is a
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value), and `num`'s unit if
 `num` is a
 [\<dimension\>](https://drafts.csswg.org/css-values-4/#typedef-dimension).

 If the value being [reified](#css-reify) is a computed value, the unit used must be the
 appropriate [canonical
 unit](https://drafts.csswg.org/css-values-4/#canonical-unit) for the value's type, with the numeric value scaled
 accordingly.

 :::
 (#example-b5c7e2e8) For example, if an element has
 `style="width: 1in;"`,
 `el.attributeStyleMap.get('width')` will return
 `CSS.in(1)`, but
 `el.computedStyleMap.get('width')` will return
 `CSS.px(96)`, as
 [px](https://drafts.csswg.org/css-values-4/#px) is the [canonical
 unit](https://drafts.csswg.org/css-values-4/#canonical-unit) for absolute lengths.
 :::

To [reify a math expression] `num`:

1. If `num` is a
 [min()](https://drafts.csswg.org/css-values-4/#funcdef-min) or
 [max()](https://drafts.csswg.org/css-values-4/#funcdef-max) expression:

 1. Let `values` be the result of
 [reifying](#reify-a-math-expression) the arguments to the expression, treating each
 argument as if it were the contents of a
 [calc()](https://drafts.csswg.org/css-values-4/#funcdef-calc) expression.

 2. Return a new
 [`CSSMathMin`](#cssmathmin) or
 [`CSSMathMax`](#cssmathmax) object, respectively, with its
 [`values`](#dom-cssmathmin-values) internal slot set to `values`.

2. Assert: Otherwise, `num` is a
 [calc()](https://drafts.csswg.org/css-values-4/#funcdef-calc).

3. Turn `num`'s argument into an expression tree using
 standard PEMDAS precedence rules, with the following
 exceptions/clarification:

 - Treat subtraction as instead being addition, with the RHS argument
 instead wrapped in a special \"negate\" node.

 - Treat division as instead being multiplication, with the RHS
 argument instead wrapped in a special \"invert\" node.

 - Addition and multiplication are N-ary; each node can have any
 number of arguments.

 - If an expression has only a single value in it, and no operation,
 treat it as an addition node with the single argument.

4. Recursively transform the expression tree into objects, as follows:

 addition node

 : becomes a new
 [`CSSMathSum`](#cssmathsum) object, with its
 [`values`](#dom-cssmathsum-values) internal slot set to its list of arguments

 multiplication node

 : becomes a new
 [`CSSMathProduct`](#cssmathproduct) object, with its
 [`values`](#dom-cssmathproduct-values) internal slot set to its list of arguments

 negate node

 : becomes a new
 [`CSSMathNegate`](#cssmathnegate) object, with its
 [`value`](#dom-cssmathnegate-value) internal slot set to its argument

 invert node

 : becomes a new
 [`CSSMathInvert`](#cssmathinvert) object, with its
 [`value`](#dom-cssmathinvert-value) internal slot set to its argument

 leaf node

 : [reified](#css-reify) as
 appropriate

For example, [calc(1px - 2 \*
3em)] produces the structure:

 CSSMathSum(
 CSS.px(1),
 CSSMathNegate(
 CSSMathProduct(
 2,
 CSS.em(3)
 )
 )
 )

Note that addition and multiplication
are N-ary, so [calc(1px + 2px + 3px)] produces the structure:

 CSSMathSum(
 CSS.px(1),
 CSS.px(2),
 CSS.px(3)
 )

but [calc(calc(1px + 2px) + 3px)] produces the structure:

 CSSMathSum(
 CSSMathSum(
 CSS.px(1),
 CSS.px(2)
 ),
 CSS.px(3)
 )

 The value computation process may transform different
units into identical ones, simplifying the resulting expression. For
example, [calc(1px + 2em)] as a specified value results in a
[`CSSMathSum(CSS.px(1), CSS.em(2))`]{style=";white-space:nowrap"}, but
as a computed value will give
[`CSS.px(33)`]{style=";white-space:nowrap"} or similar (depending on the
value of an [em](https://drafts.csswg.org/css-values-4/#em) in that context).

### [5.7. ][[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) Values]
CSS
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) values become either
[`CSSColorValue`](#csscolorvalue)s (if they can be resolved to an absolute color) or
generic [`CSSStyleValue`](#cssstylevalue)s (otherwise).

To [reify a color value] `val`:

1. If `val` is a
 [\<hex-color\>](https://drafts.csswg.org/css-color-4/#typedef-hex-color), an
 [rgb()](https://drafts.csswg.org/css-color-4/#funcdef-rgb) function, or an
 [rgba()](https://drafts.csswg.org/css-color-4/#funcdef-rgba) function, then return a new
 [`CSSRGB`](#cssrgb) object
 with its [`r`](#dom-cssrgb-r), [`g`](#dom-cssrgb-g), [`b`](#dom-cssrgb-b), and
 [`alpha`](#dom-cssrgb-alpha) internal slots set to the
 [reification](#css-reify) of
 its red, green, blue, and alpha components, respectively.

2. If `val` is an
 [hsl()](https://drafts.csswg.org/css-color-4/#funcdef-hsl) or
 [hsla()](https://drafts.csswg.org/css-color-4/#funcdef-hsla) function, then return a new
 [`CSSHSL`](#csshsl) object
 with its [`h`](#dom-csshsl-h), [`s`](#dom-csshsl-s), [`l`](#dom-csshsl-l), and
 [`alpha`](#dom-csshsl-alpha) internal slots set to the
 [reification](#css-reify) of
 its hue angle, saturation, lightness, and alpha components,
 respectively.

3. If `val` is an
 [hwb()](https://drafts.csswg.org/css-color-5/#funcdef-hwb) function, then return a new
 [`CSSHWB`](#csshwb) object
 with its [`h`](#dom-csshwb-h), [`w`](#dom-csshwb-w), [`b`](#dom-csshwb-b), and
 [`alpha`](#dom-csshwb-alpha) internal slots set to the
 [reification](#css-reify) of
 its hue angle, whiteness, blackness, and alpha components,
 respectively.

4. If `val` is an
 [lch()](https://drafts.csswg.org/css-color-5/#funcdef-lch) function, then return a new
 [`CSSLCH`](#csslch) object
 with its [`l`](#dom-csslch-l), [`c`](#dom-csslch-c), [`h`](#dom-csslch-h), and
 [`alpha`](#dom-csslch-alpha) internal slots set to the
 [reification](#css-reify) of
 its lightness, chroma, hue angle, and alpha components,
 respectively.

5. If `val` is an
 [lab()](https://drafts.csswg.org/css-color-5/#funcdef-lab) function, then return a new
 [`CSSLab`](#csslab) object
 with its [`l`](#dom-csslab-l), [`a`](#dom-csslab-a), [`b`](#dom-csslab-b), and
 [`alpha`](#dom-csslab-alpha) internal slots set to the
 [reification](#css-reify) of
 its lightness, a, b, and alpha components, respectively.

6. If `val` is an
 [oklch()](https://drafts.csswg.org/css-color-5/#funcdef-oklch) function, then return a new
 [`CSSOKLCH`](#cssoklch)
 object with its
 [`l`](#dom-cssoklch-l),
 [`c`](#dom-cssoklch-c),
 [`h`](#dom-cssoklch-h), and
 [`alpha`](#dom-cssoklch-alpha) internal slots set to the
 [reification](#css-reify) of
 its lightness, chroma, hue angle, and alpha components,
 respectively.

7. If `val` is an
 [oklab()](https://drafts.csswg.org/css-color-5/#funcdef-oklab) function, then return a new
 [`CSSOKLab`](#cssoklab)
 object with its
 [`l`](#dom-cssoklab-l),
 [`a`](#dom-cssoklab-a),
 [`b`](#dom-cssoklab-b), and
 [`alpha`](#dom-cssoklab-alpha) internal slots set to the
 [reification](#css-reify) of
 its lightness, a, b, and alpha components, respectively.

8. If `val` is a
 [color()](https://drafts.csswg.org/css-color-4/#funcdef-color) function, then return a new
 [`CSSColor`](#csscolor)
 object with its
 [`colorSpace`](#dom-csscolor-colorspace) internal slot set to the result of [reifying an
 identifier](#reify-an-identifier) from `val`'s color space, its
 [`channels`](#dom-csscolor-channels) internal slot's [backing
 list](https://webidl.spec.whatwg.org/#observable-array-attribute-backing-list) set to the result of
 [reifying](#css-reify)
 `val`'s list of non-alpha components, and
 [`alpha`](#dom-csscolor-alpha) internal slot set to the result of
 [reifying](#css-reify)
 `val`'s alpha component.

9. If `val` is a
 [\<named-color\>](https://drafts.csswg.org/css-color-4/#typedef-named-color) or the keyword
 [transparent](https://drafts.csswg.org/css-color-4/#valdef-color-transparent), then return a new
 [`CSSRGB`](#cssrgb) object
 with its [`r`](#dom-cssrgb-r), [`g`](#dom-cssrgb-g), [`b`](#dom-cssrgb-b), and
 [`alpha`](#dom-cssrgb-alpha) internal slots set to the
 [reification](#css-reify) of
 its red, green, blue, and alpha components, respectively.

10. If `val` is any other color keyword, return the result of
 [reifying an
 identifier](#reify-an-identifier) from `val`.

### [5.8. ][[\<transform-list\>](https://drafts.csswg.org/css-transforms-1/#typedef-transform-list) and [\<transform-function\>](https://drafts.csswg.org/css-transforms-1/#typedef-transform-function) Values]
CSS
[\<transform-list\>](https://drafts.csswg.org/css-transforms-1/#typedef-transform-list) values become
[`CSSTransformValue`](#csstransformvalue)s in the Typed OM, while CSS
[\<transform-function\>](https://drafts.csswg.org/css-transforms-1/#typedef-transform-function) values become
[`CSSTransformComponent`](#csstransformcomponent)s.

To [reify a
[\<transform-list\>](https://drafts.csswg.org/css-transforms-1/#typedef-transform-list)] `list`:

1. Return a new
 [`CSSTransformValue`](#csstransformvalue) whose [values to iterate over] are
 the result of mapping the [reify a
 \<transform-function\>](#reify-a-transform-function) algorithm over `list`.

To [reify a
[\<transform-function\>](https://drafts.csswg.org/css-transforms-1/#typedef-transform-function)] `func`, perform the
appropriate set of steps below, based on `func`:

[matrix()](https://drafts.csswg.org/css-transforms-1/#funcdef-transform-matrix)\
[matrix3d()](https://drafts.csswg.org/css-transforms-2/#funcdef-matrix3d)

: 1. Return a new
 [`CSSMatrixComponent`](#cssmatrixcomponent) object, whose
 [`matrix`](#dom-cssmatrixcomponent-matrix) internal slot is set to a 4x4 matrix
 representing the same information as `func`, and
 whose
 [`is2D`](#dom-csstransformcomponent-is2d) internal slot is `true` if `func` is
 [matrix()](https://drafts.csswg.org/css-transforms-1/#funcdef-transform-matrix), and `false` otherwise.

[translate()](https://drafts.csswg.org/css-transforms-1/#funcdef-transform-translate)\
[translateX()](https://drafts.csswg.org/css-transforms-1/#funcdef-transform-translatex)\
[translateY()](https://drafts.csswg.org/css-transforms-1/#funcdef-transform-translatey)\
[translate3d()](https://drafts.csswg.org/css-transforms-2/#funcdef-translate3d)\
[translateZ()](https://drafts.csswg.org/css-transforms-2/#funcdef-translatez)

: 1. Return a new
 [`CSSTranslate`](#csstranslate) object, whose
 [`x`](#dom-csstranslate-x),
 [`y`](#dom-csstranslate-y), and
 [`z`](#dom-csstranslate-z) internal slots are set to the
 [reification](#reify-a-numeric-value) of the specified x/y/z offsets, or the
 [reification](#reify-a-numeric-value) of [0px] if not specified in
 `func`, and whose
 [`is2D`](#dom-csstransformcomponent-is2d) internal slot is `true` if `func` is
 [translate()](https://drafts.csswg.org/css-transforms-1/#funcdef-transform-translate),
 [translateX()](https://drafts.csswg.org/css-transforms-1/#funcdef-transform-translatex), or
 [translateY()](https://drafts.csswg.org/css-transforms-1/#funcdef-transform-translatey), and `false` otherwise.

[scale()](https://drafts.csswg.org/css-transforms-2/#funcdef-scale)\
[scaleX()](https://drafts.csswg.org/css-transforms-2/#funcdef-scalex)\
[scaleY()](https://drafts.csswg.org/css-transforms-2/#funcdef-scaley)\
[scale3d()](https://drafts.csswg.org/css-transforms-2/#funcdef-scale3d)\
[scaleZ()](https://drafts.csswg.org/css-transforms-2/#funcdef-scalez)

: 1. Return a new [`CSSScale`](#cssscale) object, whose
 [`x`](#dom-cssscale-x),
 [`y`](#dom-cssscale-y), and
 [`z`](#dom-cssscale-z) internal slots are set to the specified x/y/z
 scales, or to [1] if not specified in `func`
 and whose
 [`is2D`](#dom-csstransformcomponent-is2d) internal slot is `true` if `func` is
 [scale()](https://drafts.csswg.org/css-transforms-2/#funcdef-scale),
 [scaleX()](https://drafts.csswg.org/css-transforms-2/#funcdef-scalex), or
 [scaleY()](https://drafts.csswg.org/css-transforms-2/#funcdef-scaley), and `false` otherwise.

[rotate()](https://drafts.csswg.org/css-transforms-1/#funcdef-transform-rotate)\
[rotate3d()](https://drafts.csswg.org/css-transforms-2/#funcdef-rotate3d)\
[rotateX()](https://drafts.csswg.org/css-transforms-2/#funcdef-rotatex)\
[rotateY()](https://drafts.csswg.org/css-transforms-2/#funcdef-rotatey)\
[rotateZ()](https://drafts.csswg.org/css-transforms-2/#funcdef-rotatez)

: 1. Return a new [`CSSRotate`](#cssrotate) object, whose
 [`angle`](#dom-cssrotate-angle) internal slot is set to the
 [reification](#reify-a-numeric-value) of the specified angle, and whose
 [`x`](#dom-cssrotate-x),
 [`y`](#dom-cssrotate-y), and
 [`z`](#dom-cssrotate-z) internal slots are set to the specified
 rotation axis coordinates, or the implicit axis coordinates if
 not specified in `func` and whose
 [`is2D`](#dom-csstransformcomponent-is2d) internal slot is `true` if `func` is
 [rotate()](https://drafts.csswg.org/css-transforms-1/#funcdef-transform-rotate), and `false` otherwise.

[skew()](https://drafts.csswg.org/css-transforms-1/#funcdef-transform-skew)

: 1. Return a new [`CSSSkew`](#cssskew) object, whose
 [`ax`](#dom-cssskew-ax) and
 [`ay`](#dom-cssskew-ay) internal slots are set to the
 [reification](#reify-a-numeric-value) of the specified x and y angles, or the
 [reification](#reify-a-numeric-value) of [0deg] if not specified in
 `func`, and whose
 [`is2D`](#dom-csstransformcomponent-is2d) internal slot is `true`.

[skewX()](https://drafts.csswg.org/css-transforms-1/#funcdef-transform-skewx)

: 1. Return a new [`CSSSkewX`](#cssskewx) object, whose
 [`ax`](#dom-cssskewx-ax) internal slot is set to the
 [reification](#reify-a-numeric-value) of the specified x angle, or the
 [reification](#reify-a-numeric-value) of [0deg] if not specified in
 `func`, and whose
 [`is2D`](#dom-csstransformcomponent-is2d) internal slot is `true`.

[skewY()](https://drafts.csswg.org/css-transforms-1/#funcdef-transform-skewy)

: 1. Return a new [`CSSSkewY`](#cssskewy) object, whose
 [`ay`](#dom-cssskewy-ay) internal slot is set to the
 [reification](#reify-a-numeric-value) of the specified y angle, or the
 [reification](#reify-a-numeric-value) of [0deg] if not specified in
 `func`, and whose
 [`is2D`](#dom-csstransformcomponent-is2d) internal slot is `true`.

[perspective()](https://drafts.csswg.org/css-transforms-2/#funcdef-perspective)

: 1. Return a new
 [`CSSPerspective`](#cssperspective) object, whose
 [`length`](#dom-cssperspective-length) internal slot is set to the reification of the
 specified length (see [reify a numeric
 value](#reify-a-numeric-value) if it is a length, and [reify an
 identifier](#reify-an-identifier) if it is the keyword
 [none](https://drafts.csswg.org/css-transforms-2/#valdef-perspective-func-none)) and whose
 [`is2D`](#dom-csstransformcomponent-is2d) internal slot is `false`.

## 6. [`CSSStyleValue` Serialization]
The way that a
[`CSSStyleValue`](#cssstylevalue) serializes is dependent on how the value was
constructed.

if the value was constructed from a USVString

: the serialization is the USVString from which the value was
 constructed.

otherwise, if the value was constructed using an IDL constructor

: the serialization is specified in the sections below.

otherwise, if the value was extracted from the CSSOM

: the serialization is specified in [§ 6.7 Serialization from CSSOM
 Values](#cssom-serialization) below.

For example:

```
var length1 = CSSNumericValue.parse("42.0px");
length1.toString(); // "42.0px"

var length2 = CSS.px(42.0);
length2.toString(); // "42px";

element.style.width = "42.0px";
var length3 = element.attributeStyleMap.get('width');
length3.toString(); // "42px";
```

### 6.1. [`CSSUnparsedValue` Serialization]
To [serialize a
[`CSSUnparsedValue`](#cssunparsedvalue)] `this`:

1. Let `s` initially be the empty
 [string](https://infra.spec.whatwg.org/#string).

2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `item` in `this`'s
 [`[[tokens]]`](#dom-cssunparsedvalue-tokens-slot) internal slot:

 1. If `item` is a
 [`USVString`](https://webidl.spec.whatwg.org/#idl-USVString), append it to `s`.

 2. Otherwise, `item` is a
 [`CSSVariableReferenceValue`](#cssvariablereferencevalue). Serialize it, then append the result to
 `s`.

3. Return `s`.

To [serialize a
[`CSSVariableReferenceValue`](#cssvariablereferencevalue)] `this`:

1. Let `s` initially be \"var(\".

2. Append `this`'s
 [`variable`](#dom-cssvariablereferencevalue-variable) internal slot to `s`.

3. If `this`'s
 [`fallback`](#dom-cssvariablereferencevalue-fallback) internal slot is not `null`, append \", \" to
 `s`, then serialize the
 [`fallback`](#dom-cssvariablereferencevalue-fallback) internal slot and append it to `s`.

4. Append \")\" to `s` and return `s`.

### 6.2. [`CSSKeywordValue` Serialization]
To [serialize a
[`CSSKeywordValue`](#csskeywordvalue)] `this`:

1. Return `this`'s
 [`value`](#dom-csskeywordvalue-value) internal slot.

### 6.3. [`CSSNumericValue` Serialization]
To [serialize a
[`CSSNumericValue`](#cssnumericvalue)] `this`, given an optional
`minimum`, a numeric value, and optional
`maximum`, a numeric value:

1. If `this` is a
 [`CSSUnitValue`](#cssunitvalue), [serialize a
 CSSUnitValue](#serialize-a-cssunitvalue) from `this`, passing
 `minimum` and `maximum`. Return the result.

2. Otherwise, [serialize a
 CSSMathValue](#serialize-a-cssmathvalue) from `this`, and return the result.

### 6.4. [`CSSUnitValue` Serialization]
To [serialize a
[`CSSUnitValue`](#cssunitvalue)] `this`, with optional arguments
`minimum`, a numeric value, and `maximum`, a
numeric value:

1. Let `value` and `unit` be `this`'s
 [`value`](#dom-cssunitvalue-value) and
 [`unit`](#dom-cssunitvalue-unit) internal slots.

2. Set `s` to the result of serializing a
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value) from `value`, per
 [CSSOM § 6.7.2 Serializing CSS
 Values](https://drafts.csswg.org/cssom-1/#serializing-css-values).

3. If `unit` is:

 \"number\"

 : Do nothing.

 \"percent\"

 : Append \"%\" to `s`.

 anything else

 : Append `unit` to `s`.

4. If `minimum` was passed and `this` is less
 than `minimum`, or if `maximum` was passed and
 `this` is greater than `maximum`, or either
 `minimum` and/or `maximum` were passed and the
 relative size of `this` and
 `minimum`/`maximum` can't be determined with
 the available information at this time, prepend \"calc(\" to
 `s`, then append \")\" to `s`.

5. Return `s`.

### 6.5. [`CSSMathValue` Serialization]
To [serialize a
[`CSSMathValue`](#cssmathvalue)] `this`, with optional arguments
`nested`, a boolean (defaulting to false if unspecified),
`paren-less`, a boolean (defaulting to false if unspecified),
perform the following steps.

1. Let `s` initially be the empty
 [string](https://infra.spec.whatwg.org/#string).

2. If `this` is a
 [`CSSMathMin`](#cssmathmin) or
 [`CSSMathMax`](#cssmathmax):

 1. Append \"min(\" or \"max(\" to `s`, as appropriate.

 2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `arg` in `this`'s
 [`values`](#dom-cssmathmin-values) internal slot, serialize `arg` with
 `nested` and `paren-less` both true, and
 append the result to `s`, appending a \", \" between
 successive values.

 3. Append \")\" to `s` and return `s`.

3. Otherwise, if `this` is a
 [`CSSMathSum`](#cssmathsum):

 1. If `paren-less` is true, continue to the next step;
 otherwise, if `nested` is true, append \"(\" to
 `s`; otherwise, append \"calc(\" to `s`.

 2. Serialize the first
 [item](https://infra.spec.whatwg.org/#list-item) in `this`'s
 [`values`](#dom-cssmathsum-values) internal slot with `nested` set to
 true, and append the result to `s`.

 3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `arg` in `this`'s
 [`values`](#dom-cssmathsum-values) internal slot beyond the first:

 1. If `arg` is a
 [`CSSMathNegate`](#cssmathnegate), append \" - \" to `s`, then
 serialize `arg`'s
 [`value`](#dom-cssmathnegate-value) internal slot with `nested` set
 to true, and append the result to `s`.

 2. Otherwise, append \" + \" to `s`, then serialize
 `arg` with `nested` set to true, and
 append the result to `s`.

 4. If `paren-less` is false, append \")\" to
 `s`,

 5. Return `s`.

4. Otherwise, if `this` is a
 [`CSSMathNegate`](#cssmathnegate):

 1. If `paren-less` is true, continue to the next step;
 otherwise, if `nested` is true, append \"(\" to
 `s`; otherwise, append \"calc(\" to `s`.

 2. Append \"-\" to `s`.

 3. Serialize `this`'s
 [`value`](#dom-cssmathnegate-value) internal slot with `nested` set to
 true, and append the result to `s`.

 4. If `paren-less` is false, append \")\" to
 `s`,

 5. Return `s`.

5. Otherwise, if `this` is a
 [`CSSMathProduct`](#cssmathproduct):

 1. If `paren-less` is true, continue to the next step;
 otherwise, if `nested` is true, append \"(\" to
 `s`; otherwise, append \"calc(\" to `s`.

 2. Serialize the first
 [item](https://infra.spec.whatwg.org/#list-item) in `this`'s
 [`values`](#dom-cssmathproduct-values) internal slot with `nested` set to
 true, and append the result to `s`.

 3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `arg` in `this`'s
 [`values`](#dom-cssmathproduct-values) internal slot beyond the first:

 1. If `arg` is a
 [`CSSMathInvert`](#cssmathinvert), append \" / \" to `s`, then
 serialize `arg`'s
 [`value`](#dom-cssmathinvert-value) internal slot with `nested` set
 to true, and append the result to `s`.

 2. Otherwise, append \" \* \" to `s`, then serialize
 `arg` with `nested` set to true, and
 append the result to `s`.

 4. If `paren-less` is false, append \")\" to
 `s`,

 5. Return `s`.

6. Otherwise, if `this` is a
 [`CSSMathInvert`](#cssmathinvert):

 1. If `paren-less` is true, continue to the next step;
 otherwise, if `nested` is true, append \"(\" to
 `s`; otherwise, append \"calc(\" to `s`.

 2. Append \"1 / \" to `s`.

 3. Serialize `this`'s
 [`value`](#dom-cssmathinvert-value) internal slot with `nested` set to
 true, and append the result to `s`.

 4. If `paren-less` is false, append \")\" to
 `s`,

 5. Return `s`.

### 6.6. [`CSSTransformValue` and [`CSSTransformComponent`](#csstransformcomponent) Serialization]
To [serialize a
[`CSSTransformValue`](#csstransformvalue)] `this`:

1. Return the result of serializing each
 [item](https://infra.spec.whatwg.org/#list-item) in `this`'s [values to iterate
 over], then concatenating them separated by \" \".

To [serialize a
[`CSSTranslate`](#csstranslate)] `this`:

1. Let `s` initially be the empty
 [string](https://infra.spec.whatwg.org/#string).

2. If `this`'s
 [`is2D`](#dom-csstransformvalue-is2d) internal slot is `false`:

 1. Append \"translate3d(\" to `s`.

 2. Serialize `this`'s
 [`x`](#dom-csstranslate-x) internal slot, and append it to `s`.

 3. Append \", \" to `s`.

 4. Serialize `this`'s
 [`y`](#dom-csstranslate-y) internal slot, and append it to `s`.

 5. Append \", \" to `s`.

 6. Serialize `this`'s
 [`z`](#dom-csstranslate-z) internal slot, and append it to `s`.

 7. Append \")\" to `s`, and return `s`.

3. Otherwise:

 1. Append \"translate(\" to `s`.

 2. Serialize `this`'s
 [`x`](#dom-csstranslate-x) internal slot, and append it to `s`.

 3. Append \", \" to `s`.

 4. Serialize `this`'s
 [`y`](#dom-csstranslate-y) internal slot, and append it to `s`.

 5. Append \")\" to `s`, and return `s`.

To [serialize a [`CSSRotate`](#cssrotate)] `this`:

1. Let `s` initially be the empty
 [string](https://infra.spec.whatwg.org/#string).

2. If `this`'s
 [`is2D`](#dom-csstransformvalue-is2d) internal slot is `false`:

 1. Append \"rotate3d(\" to `s`.

 2. Serialize `this`'s
 [`x`](#dom-cssrotate-x) internal slot, and append it to `s`.

 3. Append \", \" to `s`.

 4. Serialize `this`'s
 [`y`](#dom-cssrotate-y) internal slot, and append it to `s`.

 5. Append \", \" to `s`.

 6. Serialize `this`'s
 [`z`](#dom-cssrotate-z) internal slot, and append it to `s`.

 7. Append \",\" to `s`.

 8. Serialize `this`'s
 [`angle`](#dom-cssrotate-angle) internal slot, and append it to `s`.

 9. Append \")\" to `s`, and return `s`.

3. Otherwise:

 1. Append \"rotate(\" to `s`.

 2. Serialize `this`'s
 [`angle`](#dom-cssrotate-angle) internal slot, and append it to `s`.

 3. Append \")\" to `s`, and return `s`.

To [serialize a [`CSSScale`](#cssscale)] `this`:

1. Let `s` initially be the empty
 [string](https://infra.spec.whatwg.org/#string).

2. If `this`'s
 [`is2D`](#dom-csstransformvalue-is2d) internal slot is `false`:

 1. Append \"scale3d(\" to `s`.

 2. Serialize `this`'s
 [`x`](#dom-cssscale-x) internal slot, and append it to `s`.

 3. Append \", \" to `s`.

 4. Serialize `this`'s
 [`y`](#dom-cssscale-y) internal slot, and append it to `s`.

 5. Append \", \" to `s`.

 6. Serialize `this`'s
 [`z`](#dom-cssscale-z) internal slot, and append it to `s`.

 7. Append \")\" to `s`, and return `s`.

3. Otherwise:

 1. Append \"scale(\" to `s`.

 2. Serialize `this`'s
 [`x`](#dom-cssscale-x) internal slot, and append it to `s`.

 3. If `this`'s
 [`x`](#dom-cssscale-x) and
 [`y`](#dom-cssscale-y) internal slots are [equal numeric
 values](#equal-numeric-value), append \")\" to `s` and return
 `s`.

 4. Otherwise, append \", \" to `s`.

 5. Serialize `this`'s
 [`y`](#dom-cssscale-y) internal slot, and append it to `s`.

 6. Append \")\" to `s`, and return `s`.

To [serialize a [`CSSSkew`](#cssskew)] `this`:

1. Let `s` initially be \"skew(\".

2. Serialize `this`'s
 [`ax`](#dom-cssskew-ax) internal slot, and append it to `s`.

3. If `this`'s
 [`ay`](#dom-cssskew-ay) internal slot is a
 [`CSSUnitValue`](#cssunitvalue) with a
 [`value`](#dom-cssunitvalue-value) of `0`, then append \")\" to `s` and
 return `s`.

4. Otherwise, append \", \" to `s`.

5. Serialize `this`'s
 [`ay`](#dom-cssskew-ay) internal slot, and append it to `s`.

6. Append \")\" to `s`, and return `s`.

To [serialize a [`CSSSkewX`](#cssskewx)] `this`:

1. Let `s` initially be \"skewX(\".

2. Serialize `this`'s
 [`ax`](#dom-cssskewx-ax) internal slot, and append it to `s`.

3. Append \")\" to `s`, and return `s`.

To [serialize a [`CSSSkewY`](#cssskewy)] `this`:

1. Let `s` initially be \"skewY(\".

2. Serialize `this`'s
 [`ay`](#dom-cssskewy-ay) internal slot, and append it to `s`.

3. Append \")\" to `s`, and return `s`.

To [serialize a
[`CSSPerspective`](#cssperspective)] `this`:

1. Let `s` initially be \"perspective(\".

2. Serialize `this`'s
 [`length`](#dom-cssperspective-length) internal slot, with a `minimum` of
 [0px], and append it to `s`.

3. Append \")\" to `s`, and return `s`.

To [serialize a
[`CSSMatrixComponent`](#cssmatrixcomponent)] `this`:

1. Return the [serialization] of `this`'s
 [`matrix`](#dom-cssmatrixcomponent-matrix) internal slot.

### 6.7. Serialization from CSSOM Values

[`CSSStyleValue`](#cssstylevalue) objects produced by the user agent from values in the
CSSOM, rather than directly constructed by the author, are serialized
according to the following rules, depending on the property they came
from:

[background-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-color)

: 1. If the value is the
 [currentcolor](https://drafts.csswg.org/css-color-4/#valdef-color-currentcolor) keyword, return \"currentcolor\".

 2. Otherwise, return the result of serializing the
 [\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) value.

[border-color](https://drafts.csswg.org/css-borders-4/#propdef-border-color)

: 1. If the value is the
 [currentcolor](https://drafts.csswg.org/css-color-4/#valdef-color-currentcolor) keyword, return \"currentcolor\".

 2. Otherwise, return the result of serializing the
 [\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) value.

[border-image](https://drafts.csswg.org/css-borders-4/#propdef-border-image)

: 1. Let `values` initially be the empty
 [list](https://infra.spec.whatwg.org/#list).

 2. If
 [border-image-source](https://drafts.csswg.org/css-borders-4/#propdef-border-image-source) is not [none],
 serialize
 [border-image-source](https://drafts.csswg.org/css-borders-4/#propdef-border-image-source) and append it to
 `values`.

 3. If
 [border-image-slice](https://drafts.csswg.org/css-borders-4/#propdef-border-image-slice) does not specify
 [100%] for all sides and omits the
 [fill](https://drafts.csswg.org/css-borders-4/#border-image-slice-fill) keyword, serialize
 [border-image-slice](https://drafts.csswg.org/css-borders-4/#propdef-border-image-slice) and append it to
 `values`.

 4. If
 [border-image-width](https://drafts.csswg.org/css-borders-4/#propdef-border-image-width) does not specify [1]
 for all sides, append \"/ \" (U+002F FORWARD SLASH followed by
 U+0020 SPACE) to the result of serializing
 [border-image-width](https://drafts.csswg.org/css-borders-4/#propdef-border-image-width) and append it to
 `values`.

 5. If
 [border-image-outset](https://drafts.csswg.org/css-borders-4/#propdef-border-image-outset) does not specify [0]
 for all sides:

 1. If the previous
 [border-image-width](https://drafts.csswg.org/css-borders-4/#propdef-border-image-width) step did not append
 anything to `values`, let `prefix` be
 [\"// \"]{style=";white-space:nowrap"} (two U+002F FORWARD
 SLASH characters followed by U+0020 SPACE); otherwise let
 `prefix` be [\"/ \"]{style=";white-space:nowrap"}
 (U+002F FORWARD SLASH followed by U+0020 SPACE)

 2. Append `prefix` to the result of serializing
 [border-image-outset](https://drafts.csswg.org/css-borders-4/#propdef-border-image-outset) and append it to
 `values`.

 6. If
 [border-image-repeat](https://drafts.csswg.org/css-borders-4/#propdef-border-image-repeat) is not
 [stretch](https://drafts.csswg.org/css-borders-4/#valdef-border-image-repeat-stretch) in both axises, serialize
 [border-image-repeat](https://drafts.csswg.org/css-borders-4/#propdef-border-image-repeat) and append it to
 `values`.

 7. If `values` is
 [empty](https://infra.spec.whatwg.org/#list-empty), append \"none\" to `values`.

 8. Return the result of concatenating all the items in
 `values`, separated by \" \" (U+0020 SPACE).

[bottom](https://drafts.csswg.org/css-position-3/#propdef-bottom)

: 1. If the value is the
 [auto](https://drafts.csswg.org/css-position-3/#valdef-top-auto) keyword, return \"auto\".

 2. If the value is of type
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value), return the result of
 serializing the
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value) value.

 3. Otherwise, return the result of serializing the
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) value.

[color](https://drafts.csswg.org/css-color-4/#propdef-color)

: 1. If the value is the
 [currentcolor](https://drafts.csswg.org/css-color-4/#valdef-color-currentcolor) keyword, return \"currentcolor\".

 2. Otherwise, return the result of serializing the
 [\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) value.

[left](https://drafts.csswg.org/css-position-3/#propdef-left)

: 1. If the value is the
 [auto](https://drafts.csswg.org/css-position-3/#valdef-top-auto) keyword, return \"auto\".

 2. If the value is of type
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value), return the result of
 serializing the
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value) value.

 3. Otherwise, return the result of serializing the
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) value.

[opacity](https://drafts.csswg.org/css-color-4/#propdef-opacity)

: 1. If the value is of type
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value), return the result of
 serializing the
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value) value.

 2. Otherwise, return the result of serializing the
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) value.

[right](https://drafts.csswg.org/css-position-3/#propdef-right)

: 1. If the value is the
 [auto](https://drafts.csswg.org/css-position-3/#valdef-top-auto) keyword, return \"auto\".

 2. If the value is of type
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value), return the result of
 serializing the
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value) value.

 3. Otherwise, return the result of serializing the
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) value.

[top](https://drafts.csswg.org/css-position-3/#propdef-top)

: 1. If the value is the
 [auto](https://drafts.csswg.org/css-position-3/#valdef-top-auto) keyword, return \"auto\".

 2. If the value is of type
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value), return the result of
 serializing the
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value) value.

 3. Otherwise, return the result of serializing the
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) value.

## 7. Security Considerations

There are no known security issues introduced by these features.

## 8. Privacy Considerations

There are no known privacy issues introduced by these features.

## 9. Changes

### [9.1. ][Changes since the [10 April 2018 Working Draft](https://www.w3.org/TR/2018/WD-css-typed-om-1-20180410/)]
- Fixed the type match algorithm to refer to the percent hint more
 abstractly.

- Clarified that \"invert a type\" needs to preserve the percent hint.

- Added missing font units to CSS numeric factory.
 ([#1107](https://github.com/w3c/css-houdini-drafts/pull/1107))

- Specified that the list of unit shorthand methods must be reduced or
 expanded to match the implementation's support.

- Used undefined union value for \"StylePropertyMapReadOnly.get()\".
 ([#1087](https://github.com/w3c/css-houdini-drafts/pull/1087))

- Removed .to() and the CSSColorValue.colorSpace, as conversion isn't
 really in Typed OM's remit.
 ([#1070](https://github.com/w3c/css-houdini-drafts/issues/1070))

- Added min/max to \"serialize a CSSUnitValue\", and pass it when
 serializing the argument of CSSPerspective.
 ([#1069](https://github.com/w3c/css-houdini-drafts/issues/1069))

- Changed reifying from \"a CSSStyleValue\" to \"an identifier\".
 ([#1068](https://github.com/w3c/css-houdini-drafts/pull/1068))

- Added factory functions for new viewport/container units.
 ([#1067](https://github.com/w3c/css-houdini-drafts/pull/1067))

- Added type checking to CSSNumericValue.parse.
 ([#1065](https://github.com/w3c/css-houdini-drafts/pull/1065))

- Removed CSSDeviceCMYK, add CSSOKLab and CSSOKLCH, made all the color
 classes accept the \"none\" keyword.

- Defined how to reify a color value.

- Allowed \"new unit value\" to link to \"create a CSSUnitValue from a
 pair\" since that phrasing is used everywhere already.

- Added support for perspective(none) to CSSPerspective.
 ([#1053](https://github.com/w3c/css-houdini-drafts/pull/1053))

- Fixed accidental clash of CSSClampValue.min/max with
 CSSNumericValue.min/max.
 ([#855](https://github.com/w3c/css-houdini-drafts/issues/855))

- Simplified the Abstract

- Removed CSSGray and associated spec text, since Color 4 *dropped*
 gray() some time ago.
 ([#1027](https://github.com/w3c/css-houdini-drafts/issues/1027))

- Moved .colorSpace up to the CSSColorValue superclass. Swapped the
 .to\*() color-conversion functions for a generic .to(colorSpace)
 method.
 ([#1036](https://github.com/w3c/css-houdini-drafts/issues/1036))

- Added device-cmyk() support.

- Fix the OM for CSSColor to match recent simplifications.

- Specified which color function each CSSColorValue subclass represents,
 and added CSSGray.

- Added missing parentheses for union.
 ([#1016](https://github.com/w3c/css-houdini-drafts/pull/1016))

- Added some explanatory text about the makeup of a \"type\".

- Aligned with Web IDL specification.
 ([#965](https://github.com/w3c/css-houdini-drafts/pull/965) and
 [#1006](https://github.com/w3c/css-houdini-drafts/pull/1006) )

- Fixed algorithm nesting.

- Added default dictionary value, required by update to
 [WebIDL](https://github.com/whatwg/webidl/pull/750).
 ([#936](https://github.com/w3c/css-houdini-drafts/pull/936))

- Switched term from \"underlying value\" to :internal representation\",
 as Web Animations already uses \"underlying value\" for something
 different.

- Clarified that reifying as a CSSSTyleValue requires a property.

- Defined reification behavior for registered custom properties
 ([#886](https://github.com/w3c/css-houdini-drafts/pull/886))

- Used partial interface mixin ElementCSSInlineStyle
 ([#853](https://github.com/w3c/css-houdini-drafts/pull/853))

- Used the correct name from WebIDL for indexed property getter.

- Exported a number of terms for use in other specifications

- Droped CSSPositionValue from this level.

- Added CSSMathClamp for the \"clamp()\"\" function.

- Made the \"match a grammar\" algorithm a little more precise.

- Reifying computed numeric values uses the canonical unit.
 ([#725](https://github.com/w3c/css-houdini-drafts/issues/725))

- Added note about new unit types.
 ([#734](https://github.com/w3c/css-houdini-drafts/issues/734))

- Used correct unit \"percent\", not \"percentage\"
 ([#761](https://github.com/w3c/css-houdini-drafts/issues/761)).

- Added note about custom property parsing

- Moved Naina Raisinghani to Former Editor

- Added an \'invert a type\' operation.

- Exported several numeric-type terms, so CSS Values & Units can refer
 to them.

- Moved Shane Stephens to Former Editor
