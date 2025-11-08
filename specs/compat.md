# Introduction

*This section is non-normative.*

There exists an increasingly large corpus of web content that depends on web browsers supporting a number of specific vendor CSS properties and DOM APIs for functionality or layout. This holds especially true for mobile-optimized web content, which is highly dependent on `-webkit-`-prefixed properties.

This specification aims to describe the minimal set of `-webkit-`-prefixed CSS properties and DOM APIs that user agents are required to support for web compatibility, which aren't specified elsewhere.

The HTTP `User-Agent` header field as found in major browsers today is also described.


## Conformance

All diagrams, examples, and notes in this specification are non-normative, as are all sections explicitly marked non-normative. Everything else in this specification is normative.

The keywords "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in RFC 2119. For readability, these words do not appear in all uppercase letters in this specification. [RFC2119]

Requirements phrased in the imperative as part of algorithms (such as "strip any leading space characters" or "return false and terminate these steps") are to be interpreted with the meaning of the keyword ("must", "should", "may", etc.) used in introducing the algorithm.

Conformance requirements phrased as algorithms or specific steps may be implemented in any manner, so long as the end result is equivalent. (In particular, the algorithms defined in this specification are intended to be easy to follow, and not intended to be performant.)


## CSS Compatibility


### CSS At-rules

The following `-webkit-` vendor prefixed at-rules must be supported as aliases of the corresponding unprefixed at-rules:

`-webkit-` prefixed at-rule alias | unprefixed at-rule
--- | ---
`@-webkit-keyframes` | `@keyframes`


### CSS Media Queries


#### `-webkit-device-pixel-ratio`

Name:

-webkit-device-pixel-ratio

For:

@media

Value:

<number>

Type:

range

`-webkit-device-pixel-ratio` must be treated as an alias of the `resolution` range type media feature, with its value interpreted as a dppx unit.

The `min-` or `max-` prefixes on range features must not apply to `-webkit-device-pixel-ratio`, instead the following aliases must be used:

legacy `-webkit-` prefixed range media feature alias | standard prefixed range media feature
--- | ---
`-webkit-min-device-pixel-ratio` | `min-resolution`
`-webkit-max-device-pixel-ratio` | `max-resolution`


#### `-webkit-transform-3d`

Name:

-webkit-transform-3d

For:

@media

Value:

<mq-boolean>

Type:

discrete

The `-webkit-transform-3d` media feature is used to query whether the user agent supports CSS 3D transforms.

If the user agent supports 3D transforms, the value will be 1. Otherwise the value is 0.


### CSS Gradient Functions


#### `-webkit-linear-gradient()`

The `-webkit-linear-gradient()` gradient function must be treated as an alias of linear-gradient as defined in [css3-images-20110217].


#### `-webkit-radial-gradient()`

The `-webkit-radial-gradient()` gradient function must be treated as an alias of radial-gradient as defined in [css3-images-20110217].


#### `-webkit-repeating-linear-gradient()`

The `-webkit-repeating-linear-gradient()` gradient function must be treated as an alias of repeating-linear-gradient as defined in [css3-images-20110217].


#### `-webkit-repeating-radial-gradient()`

The `-webkit-repeating-radial-gradient()` gradient function must be treated as an alias of repeating-radial-gradient as defined in [css3-images-20110217].


### CSS Properties


#### Legacy name aliases

The following `-webkit-` vendor prefixed properties must be supported as legacy name aliases of the corresponding unprefixed property:

`-webkit-` prefixed property alias | unprefixed property
--- | ---
`-webkit-align-items` | `align-items`
`-webkit-align-content` | `align-content`
`-webkit-align-self` | `align-self`
`-webkit-animation-name` | `animation-name`
`-webkit-animation-duration` | `animation-duration`
`-webkit-animation-timing-function` | `animation-timing-function`
`-webkit-animation-iteration-count` | `animation-iteration-count`
`-webkit-animation-direction` | `animation-direction`
`-webkit-animation-play-state` | `animation-play-state`
`-webkit-animation-delay` | `animation-delay`
`-webkit-animation-fill-mode` | `animation-fill-mode`
`-webkit-animation` | `animation`
`-webkit-backface-visibility` | `backface-visibility`
`-webkit-background-clip` | `background-clip`
`-webkit-background-origin` | `background-origin`
`-webkit-background-size` | `background-size`
`-webkit-border-bottom-left-radius` | `border-bottom-left-radius`
`-webkit-border-bottom-right-radius` | `border-bottom-right-radius`
`-webkit-border-top-left-radius` | `border-top-left-radius`
`-webkit-border-top-right-radius` | `border-top-right-radius`
`-webkit-border-radius` | `border-radius`
`-webkit-box-shadow` | `box-shadow`
`-webkit-box-sizing` | `box-sizing`
`-webkit-flex` | `flex`
`-webkit-flex-basis` | `flex-basis`
`-webkit-flex-direction` | `flex-direction`
`-webkit-flex-flow` | `flex-flow`
`-webkit-flex-grow` | `flex-grow`
`-webkit-flex-shrink` | `flex-shrink`
`-webkit-flex-wrap` | `flex-wrap`
`-webkit-filter` | `filter`
`-webkit-justify-content` | `justify-content`
`-webkit-mask` | `mask`
`-webkit-mask-box-image` | `mask-border`
`-webkit-mask-box-image-outset` | `mask-border-outset`
`-webkit-mask-box-image-repeat` | `mask-border-repeat`
`-webkit-mask-box-image-slice` | `mask-border-slice`
`-webkit-mask-box-image-source` | `mask-border-source`
`-webkit-mask-box-image-width` | `mask-border-width`
`-webkit-mask-clip` | `mask-clip`
`-webkit-mask-composite` | `mask-composite`
`-webkit-mask-image` | `mask-image`
`-webkit-mask-origin` | `mask-origin`
`-webkit-mask-position` | `mask-position`
`-webkit-mask-repeat` | `mask-repeat`
`-webkit-mask-size` | `mask-size`
`-webkit-order` | `order`
`-webkit-perspective` | `perspective`
`-webkit-perspective-origin` | `perspective-origin`
`-webkit-transform-origin` | `transform-origin`
`-webkit-transform-style` | `transform-style`
`-webkit-transform` | `transform`
`-webkit-transition-delay` | `transition-delay`
`-webkit-transition-duration` | `transition-duration`
`-webkit-transition-property` | `transition-property`
`-webkit-transition-timing-function` | `transition-timing-function`
`-webkit-transition` | `transition`

Note: `-webkit-background-size` is not really a legacy name alias. See [issue #28](https://github.com/whatwg/compat/issues/28).


#### Prefixed legacy name aliases

The following `-webkit-` vendor prefixed properties must be supported as legacy name aliases of the corresponding unprefixed properties. If the user agent does not ship the unprefixed equivalent, the `-webkit-` prefixed property must be treated as an alias of the user agent's own vendor prefixed property.

`-webkit-` prefixed property alias | (vendor prefixed) property
--- | ---
`-webkit-text-size-adjust` | `(-prefix-)text-size-adjust`

For example, `-webkit-text-size-adjust` is treated as an alias of `-moz-text-size-adjust` in Firefox.

Note: As soon as each property is unprefixable it can be defined as a legacy name alias.


#### Non-aliased vendor prefixed properties

Note: This section used to specify the -webkit-appearance property. This is now defined in CSS Basic User Interface Module.


#### Property mappings

The following `-webkit-` vendor prefixed properties must be supported as mappings to the corresponding unprefixed property:

`-webkit-` prefixed property | unprefixed property
--- | ---
`-webkit-box-align` | `align-items`
`-webkit-box-flex` | `flex-grow`
`-webkit-box-ordinal-group` | `order`
`-webkit-box-orient` | `flex-direction`
`-webkit-box-pack` | `justify-content`

These definitions of `-webkit-box-*` are known to not be web compatible. [Issue #87]


#### Keyword mappings

The following `-webkit-` vendor prefixed keywords must be supported as mappings to the corresponding unprefixed keyword:

`-webkit-` prefixed keyword | unprefixed property keyword
--- | ---
`-webkit-box` | `flex`
`-webkit-flex` | `flex`
`-webkit-inline-box` | `inline-flex`
`-webkit-inline-flex` | `inline-flex`

This definition of `-webkit-box` is known to not be web compatible. [Issue #87]


#### Text Fill and Stroking


##### Foreground Text Color: the `-webkit-text-fill-color` property

Name:

-webkit-text-fill-color

Value:

<color>

Initial:

currentcolor

Applies to:

all elements

Inherited:

yes

Percentages:

N/A

Computed value:

an RGBA color

Canonical order:

per grammar

Animation type:

by computed value type

Media:

visual

The -webkit-text-fill-color property defines the foreground fill color of an element's text content.

Here's an example showing `-webkit-text-fill-color` will always determine the foreground fill color of an element's text.

```css
.one {
  color: blue;
  /* the following can be omitted because it's the initial value:
  -webkit-text-fill-color: currentcolor; */
}

.two {
  color: red;
  -webkit-text-fill-color: blue;
}
```

Elements with the `one` or `two` classes will have blue text.


##### Text Stroke Color: the `-webkit-text-stroke-color` property

Name:

-webkit-text-stroke-color

Value:

<color>

Initial:

currentcolor

Applies to:

all elements

Inherited:

yes

Percentages:

N/A

Computed value:

an RGBA color

Canonical order:

per grammar

Animation type:

by computed value type

Media:

visual

The -webkit-text-stroke-color property specifies a stroke color for an element's text.


##### Text Stroke Thickness: the `-webkit-text-stroke-width` property

Name:

-webkit-text-stroke-width

Value:

<line-width>

Initial:

0

Applies to:

all elements

Inherited:

yes

Percentages:

N/A

Computed value:

absolute length

Canonical order:

per grammar

Animation type:

discrete

Media:

visual

The -webkit-text-stroke-width property specifies the width of the stroke drawn at the edge of each glyph of an element's text. A zero value results in no stroke being painted. A negative value is invalid.


##### Text Stroke Shorthand: the `-webkit-text-stroke` property

Name:

-webkit-text-stroke

Value:

<line-width> || <color>

Initial:

See individual properties

Applies to:

See individual properties

Inherited:

yes

Percentages:

N/A

Computed value:

See individual properties

Canonical order:

per grammar

Animation type:

See individual properties

Media:

visual

The -webkit-text-stroke property is a shorthand property for the -webkit-text-stroke-width and -webkit-text-stroke-color properties, for setting the stroke width and stroke color of an element's text.

Here are two examples showing how to use the longhand and shorthand `-webkit-text-stroke` properties to achieve white text with a black stroked text effect.

```css
.stroked-text-longhand {
  color: #fff;
  -webkit-text-stroke-color: #000;
  -webkit-text-stroke-width: 1px;
}

.stroked-text-shorthand {
  -webkit-text-fill-color: #fff;
  -webkit-text-stroke: thin #000;
}
```

The element

    <p class="stroked-text-longhand">Serious typography</p>

would be rendered as follows:

![image of stroked text]


### CSS Property values


#### Additional `touch-action` values

This section augments the definition of `touch-action` from [pointerevents2] to add the `pinch-zoom` value.

Name:

touch-action

Value:

auto | none | [ [ pan-x | pan-left | pan-right ] || [ pan-y | pan-up | pan-down ] || pinch-zoom ] | manipulation

Initial:

auto

Applies to:

all elements except: non-replaced inline elements, table rows, row groups, table columns, and column groups.

Inherited:

no

Percentages:

N/A

Computed value:

Same as specified value

Canonical order:

per grammar

Animation type:

not animatable

Media:

visual

When specified, the `pinch-zoom` token enables multi-finger panning and zooming of the page. For zooming to occur, all fingers must start on an element that has the pinch-zoom behavior enabled (via one of the `pinch-zoom`, `manipulation`, or `auto` values on itself or an ancestor).

Note: Scenarios like image carousels which wish to disable only horizontal panning can use "`touch-action: pan-y pinch-zoom`" to avoid disabling zooming unnecessarily.

`manipulation` is an alias for "`pan-x pan-y pinch-zoom`".


## DOM Compatibility


### The WebKitCSSMatrix interface

Note: `WebKitCSSMatrix` is now defined by the DOM Geometry specification. [geometry-1].


### `window.orientation` API

```idl
partial interface Window {
    readonly attribute short orientation;
    attribute EventHandler onorientationchange;
};

partial interface HTMLBodyElement {
    attribute EventHandler onorientationchange;
};
```

When getting the `orientation` attribute, the user agent must run the following steps:

1. Let `document` be this's relevant global object's associated Document.

2. Return `document`'s current `window.orientation` angle.

Whenever the viewport is drawn at a different angle compared to the device's natural orientation, the user agent must run the following steps:

1. Fire an event named `orientationchange` at the `Window` object of the active document.

User agents implementing the `window.orientation` attribute and its associated `orientationchange` event must not expose them on non-Mobile platforms.

Note: iOS Safari also fires an `orientationchange` event on the `body` element, but other implementations do not, suggesting it's not necessary for compatibility with the web.


#### `window.orientation` angle

The possible integer values for the `window.orientation` angle are: `-90`, `0`, `90`, `180`. User agents must support the `-90`, `0` and `90` values and may optionally support `180`.

`0` represents the natural orientation. `-90` represents a rotation 90 degrees clockwise from the natural orientation. `90` represents a rotation 90 degrees counterclockwise from the natural orientation. `180` represents a rotation 180 degrees from the natural orientation.

In order to determine the current `window.orientation` angle, the user agent must run the following steps:

1. Let `orientationAngle` be the current orientation angle.
    1. If `orientationAngle` is less than 180, return `orientationAngle`.
    2. If `orientationAngle` is 180, and the user agent supports that value, return `orientationAngle`, else return 0.
    3. If `orientationAngle` is greater than 180, return `orientationAngle` - 360.


#### Event Handlers on `Window` objects and `body` elements

The following are the event handlers and their corresponding event handler event types that must be supported on all `Window` objects and `body` elements as attributes:

event handler | event handler event type
--- | ---
`onorientationchange` | `orientationchange`


## The User-Agent String

The `User-Agent` header field syntax is formally defined by [HTTP-SEMANTICS](#biblio-http-semantics) and provides SHOULD-level guidance on its value. This section serves as a descriptive record of the `User-Agent` patterns found in the so-called major web browsers, but much of it will apply to other browsers with a shared heritage (i.e., forks and embedders) as well as any user agent in the more general sense that send a `User-Agent` header.


### User-Agent Tokens

A User-Agent **token** is a string that represents an abstraction over a semantic unit in the `User-Agent` string. This document formalizes a token as a string that begins with an opening bracket "<" and ends with a closing ">" bracket, e.g., `<version>`. A token may also contain other tokens.

A User-Agent **constant** is a string whose value does not change.

When a token's value is made up from one or more tokens, and optionally constants, it is said to **decompose** to those tokens and constants.


#### User-Agent Token Reference

This is a non-exhaustive list of common User-Agent tokens.

Tokens | Description
---|---
`<deviceCompat>` | Represents the form-factor of the device. Primarily this is "`Mobile `", or just the empty string, for Desktop or non-mobile devices. Some browsers have also sent token values such as "`Tablet`", "`TV`", "`Mobile VR`", etc., or included build information as well.
`<majorVersion>` | Represents the browser's major version number.
`<minorVersion>` | Represents the browser's non-major version numbers.
`<oscpu>` | Represents the device operating system and (optionally) CPU architecture.
`<platform>` | Represents the underlying device platform.


### Meta Structure

The User-Agent strings that follow share the common meta structure:

"`Mozilla/5.0` (`a`) `b`"

Where `a` is one or more tokens representing device information and `b` is one or more tokens representing browser information.


### Chrome


#### Chrome User-Agent pattern

"`Mozilla/5.0 (<unifiedPlatform>) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/<majorVersion>.0.0.0 <deviceCompat>Safari/537.36`"

**Example**

**Desktop**: "`Mozilla/5.0 (`Macintosh; Intel Mac OS X 10_15_7`) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/`110`.0.0.0 Safari/537.36`"

**Mobile**: "`Mozilla/5.0 (`Linux; Android 10; K`) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/`110`.0.0.0 `Mobile` Safari/537.36`"


#### Chrome-specific tokens

Tokens | Description
---|---
`<unifiedPlatform>` | Per-platform constant that is one of the following values:<br><br>"`Linux; Android 10; K`"<br>"`Windows NT 10.0; Win64; x64`"<br>"`Macintosh; Intel Mac OS X 10_15_7`"<br>"`X11; Linux x86_64`"<br>"`X11; CrOS x86_64 14541.0.0`"<br>"`Fuchsia`"


### Firefox


#### Firefox User-Agent pattern

"`Mozilla/5.0 (<firefoxPlatform>; rv: <firefoxVersion>) Gecko/<geckoVersion> Firefox/<firefoxVersion>`"

**Example**

**Desktop**: "`Mozilla/5.0 (`Windows NT 10.0`; `Win64; x64;` rv:`100`.0) Gecko/20100101 Firefox/`100`.0`"

**Mobile**: "`Mozilla/5.0 (`Android 10`; `Mobile;` rv:`100`.0) Gecko/`100`.0 Firefox/`100`.0`"


#### Firefox-specific tokens

`<firefoxVersion>` decomposes to the following:

"`<majorVersion>.0`"

In Firefox on desktop platforms (Windows, macOS, Linux, etc.), `<geckoVersion>` is the frozen build date "`20100101`". In Firefox for Android, `<geckoVersion>` is the same value as `<firefoxVersion>`.

`<firefoxPlatform>` decomposes to the following:

On desktop platforms, "`<platform>; <oscpu>`".

On Firefox for Android, "`<platform>; <deviceCompat>`".

Tokens | Description
---|---
`<deviceCompat>` (Firefox) | The string "`Mobile`", without any leading or trailing spaces.


### Safari


#### Safari User-Agent pattern

"`Mozilla/5.0 (<safariPlatform>) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/<safariVersion> <deviceCompat> Safari/<webkitVersion>`"

**Example**

**Desktop**: "`Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/`15.6` Safari/`605.1.15`"

**Mobile**: "`Mozilla/5.0 (`iPhone`; CPU `iPhone OS` `15_6` like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/`15.6` `Mobile/15E148` Safari/`604.1`"`


#### Safari-specific tokens

`<safariVersion>` decomposes to the following:

"`<majorVersion>.<minorVersion>`", where `<minorVersion>` is a single digit.

`<safariPlatform>` decomposes to the following:

On desktop and larger iPad form factors, the constant "`Macintosh; Intel Mac OS X 10_15_7`".

On mobile platforms, including smaller iPad form factors "`<appleProduct>; CPU <mobileOSName> <iOSVersion> like Mac OS X`".

Tokens | Description
---|---
`<appleProduct>` | Represents the marketing product name of the mobile device, which is one of "`iPad`", "`iPhone`", and "`iPod`".
`<iOSVersion>` | Represents the iOS version number, delimited by an underscore (for historical compatibility reasons).
`<mobileOSName>` | A constant that is one of two values: "`OS`" (for iPad-like devices) or "`iPhone OS`" (non-iPad-like devices).
`<webkitVersion>` | A constant that is one of two values: "`605.1.15`" (for larger devices, including non-mini iPad) or "`604.1`" (for smaller mobile devices, including iPad mini).