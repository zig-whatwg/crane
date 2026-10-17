## 1. Introduction

This specification introduces three new features related to controlling
how/when colors are auto-adjusted by the user agent:

- [Color schemes](#color-scheme)
 and the
 [color-scheme](#propdef-color-scheme) property, which controls whether
 or not browser-provided parts of the page's UI respect the user's
 chosen [color scheme].

- [Forced colors mode](#forced-colors-mode) and the
 [forced-color-adjust](#propdef-forced-color-adjust) property, which controls whether
 or not [forced colors mode] is allowed
 to apply to a given element.

- The
 [print-color-adjust](#propdef-print-color-adjust) property, which controls whether
 the browser is allowed to automatically adjust colors to the user's
 assumed performance preferences, such as suppressing background colors
 when printing to save ink.

Together with the
[prefers-color-scheme](https://www.w3.org/TR/mediaqueries-5/#descdef-media-prefers-color-scheme),
[prefers-contrast](https://www.w3.org/TR/mediaqueries-5/#descdef-media-prefers-contrast), and
[forced-colors](https://www.w3.org/TR/mediaqueries-5/#descdef-media-forced-colors) [media
queries](https://www.w3.org/TR/mediaqueries-5/#media-query)
[\[MEDIAQUERIES-5\]](#biblio-mediaqueries-5 "Media Queries Level 5"),
this module allows color scheme negotiation between the author and the
user.

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
keywords](https://www.w3.org/TR/css-values-4/#css-wide-keywords) as their property value. For readability they have not
been repeated explicitly.

## 2. Preferred Color Schemes

Operating systems and user agents often give users the ability to choose
their [preferred color scheme] for user interface elements. This [color
scheme] is
typically reflected in the user agent's rendering of its navigation
interface as well as in-page interface elements such as form controls
and scrollbars.

A UA can also allow the user to indicate a preference for the [color
scheme](#color-scheme) of the
pages they view, requesting that the author adapt the page to those
color preferences. (It is not required to express such a preference;
users can have preferences for operating system interface colors that
they do not want imposed on pages.)

The most common [color scheme](#color-scheme) preferences are:

- A [light color scheme] (\"day mode\") consists of
 light background colors and dark foreground/text colors.

- A [dark color scheme] (\"night mode\") consists of
 the opposite, with dark background colors and light foreground/text
 colors.

[Light](#light-color-scheme) and
[dark](#dark-color-scheme)
[color schemes](#color-scheme)
are not specific color palettes, but a range of possible palettes. For
example, a stark black-on-white scheme and a sepia dark-on-tan scheme
would both be considered [light color
schemes]. To guarantee specific colors,
authors must specify those colors themselves. Note also that,
consequently, pairing default or
[\<system-color\>](https://www.w3.org/TR/css-color-4/#typedef-system-color) colors with author-specified colors
cannot guarantee any particular contrast level; to ensure legibility,
generally either both foreground and background should be paired [system
colors](https://www.w3.org/TR/css-color-4/#css-system-colors) or both be manually specified colors.
[\[WCAG22\]](#biblio-wcag22 "Web Content Accessibility Guidelines (WCAG) 2.2")

The user's [preferred color
scheme](#preferred-color-scheme) is then combined with the [page's supported color
schemes](#pages-supported-color-scheme) to produce a [page color scheme]. The [page color
scheme](#page-color-scheme)
also records whether it's [default] or not.
The [page color scheme] is queryable with
the
[prefers-color-scheme](https://www.w3.org/TR/mediaqueries-5/#descdef-media-prefers-color-scheme) [media
query](https://www.w3.org/TR/mediaqueries-5/#media-query).
[\[MEDIAQUERIES-5\]](#biblio-mediaqueries-5 "Media Queries Level 5")

Individual elements have an [element color scheme], which by default matches
the [page color scheme](#page-color-scheme), but can be overriden using the
[color-scheme](#propdef-color-scheme) property. The [element color
scheme](#element-color-scheme) affects things such as the value of [system
colors](https://www.w3.org/TR/css-color-4/#css-system-colors) on the element, the value of the
[light-dark()](https://www.w3.org/TR/css-color-5/#funcdef-light-dark) function, and how user interface elements (like
scrollbars) render. (See [§ 2.4 Effects of the Used Color
Scheme](#color-scheme-effect).)

User agents *may* support additional [color
schemes](#color-scheme), however
CSS does not support negotiation of additional [color
schemes]: user agents should pursue
standardization of these schemes, so that
[prefers-color-scheme](https://www.w3.org/TR/mediaqueries-5/#descdef-media-prefers-color-scheme) and
[color-scheme](#propdef-color-scheme) can reflect the additional values.

 Because many pages were authored before [color
scheme](#color-scheme) support
existed, and thus pages were authored with the assumption of the default
([light](#light-color-scheme)) color scheme, user agents cannot automatically adapt
the colors used in elements under their control, as it might cause
unreadable color contrast with the surrounding page. Pages *have to* opt
into [color scheme] support by setting the [page
color scheme](#page-color-scheme), or manually setting the
[color-scheme](#propdef-color-scheme) property on individual elements.

### 2.1. Opting Into a Preferred Color Scheme

The [page color scheme](#page-color-scheme) represents the [color
scheme](#color-scheme) that will
be used for the page overall (queryable with the
[prefers-color-scheme] [media
feature](https://www.w3.org/TR/mediaqueries-5/#media-feature)) and for all elements that don't specifically override
the [page color scheme] with the
[color-scheme](#propdef-color-scheme) property. See [§ 2.4 Effects of the
Used Color Scheme](#color-scheme-effect) for a full description of what
the [color scheme] effects.

 In HTML, the
[`color-scheme <meta>`](https://html.spec.whatwg.org/multipage/semantics.html#meta-color-scheme) sets the [page color
scheme](#page-color-scheme).

Authors *should* generally set the [page color
scheme](#page-color-scheme), rather than using the
[color-scheme](#propdef-color-scheme) property, so that the
[prefers-color-scheme](https://www.w3.org/TR/mediaqueries-5/#descdef-media-prefers-color-scheme) [media
feature](https://www.w3.org/TR/mediaqueries-5/#media-feature) is consistent with the elements on the page.

The [page color scheme](#page-color-scheme) is determined by finding the [used color
scheme](#used-color-scheme),
given the [preferred color
scheme](#preferred-color-scheme) and the [page's supported color
schemes] (a [color scheme
support](#color-scheme-support)).

In embedded documents (such as an
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) or an SVG
[`img`](https://html.spec.whatwg.org/multipage/embedded-content.html#the-img-element)), the embedding element's [element color
scheme](#element-color-scheme) is used as the embedded document's [preferred color
scheme](#preferred-color-scheme) (treated as a normal [color scheme
preference](#color-scheme-preference)), rather than the user's preference. [This allows
embedded documents to match the negotiated color scheme for the page or
an element, similar to other elements in the parent document.]

A page that responds to user
preferences for light or dark display by using the
[prefers-color-scheme] media feature to alter the colors it uses
can easily opt the browser-controlled UI (scrollbars, inputs, etc) to
match with a simple global declaration:

``` highlight
<meta name=color-scheme contents="light dark">
```

(Or, in languages that don't have a way to set the [page color
scheme](#page-color-scheme)
directly, a [:root { color-scheme: light dark;}] rule.)

If a page limits itself to using *only* the
[\<system-color\>](https://www.w3.org/TR/css-color-4/#typedef-system-color)s, the
[color-scheme](#propdef-color-scheme) declaration will support the user's
preferred color scheme even without the author needing to use
[\@media](https://www.w3.org/TR/css-conditional-3/#at-ruledef-media) at all.

If a page cannot reasonably
accommodate all color schemes, such as for branding or theatrical
reasons,
[`color-scheme`](https://html.spec.whatwg.org/multipage/semantics.html#meta-color-scheme) or
[color-scheme](#propdef-color-scheme) can still indicate which color
schemes the page *can* support, causing the UI to match.

If the page's color scheme is primarily light, the following will
indicate that explicitly:

``` highlight
<meta name=color-scheme contents="light">
```

While if the page is primarily dark, indicating that explicitly will
make the page look more coherent as well:

``` highlight
<meta name=color-scheme contents="dark">
```

However, it is better to support both color schemes, of course.

### 2.2. Overriding the Page Color Scheme: the [color-scheme property]
Name:

[color-scheme]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

normal
[\|](https://www.w3.org/TR/css-values-4/#comb-one) \[ light [\|] dark
[\|]
[\<custom-ident\>](https://www.w3.org/TR/css-values-4/#identifier-value)
\][+](https://www.w3.org/TR/css-values-4/#mult-one-plus)
[&&](https://www.w3.org/TR/css-values-4/#comb-all)
only[?](https://www.w3.org/TR/css-values-4/#mult-opt)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

normal

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements and text

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the keyword
[normal](#valdef-color-scheme-normal), or a [color scheme
support](#color-scheme-support)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

While the [page color
scheme](#page-color-scheme) should generally be used to control what [color
scheme](#color-scheme) a page
uses, occasionally there is need to override that [color
scheme] on a particular subtree. The
[color-scheme](#propdef-color-scheme) property allows this, manually
setting the [element color
scheme](#element-color-scheme) for an element and its descendants. Values are defined
as follows:

[normal]

: The [element color
 scheme](#element-color-scheme) is the same as the [page color
 scheme](#page-color-scheme). (This includes noting whether the [color
 scheme](#color-scheme) was
 [defaulted](#color-scheme-default).)

[light]\
[dark]

: Indicates that the element supports a
 [light](#light-color-scheme) and/or
 [dark](#dark-color-scheme) color scheme, as appropriate. The element's [color
 scheme
 support](#color-scheme-support) will include the keywords, in the order they're
 specified.

[only]

: Forbids the user agent from [overriding the color
 scheme](#override-the-color-scheme) for the element. The element's [color scheme
 support](#color-scheme-support) will have a flag indicating sole support.

[[\<custom-ident\>](https://www.w3.org/TR/css-values-4/#identifier-value)]

: [\<custom-ident\>](https://www.w3.org/TR/css-values-4/#identifier-value) values are meaningless, and exist
 only for future compatibility, so that future added color schemes do
 not invalidate the
 [color-scheme](#propdef-color-scheme) declaration in legacy user
 agents. User agents *must not* interpret any
 [\<custom-ident\>] values as
 having a meaning; any additional recognized color schemes must be
 explicitly added to this property's grammar.

 To avoid confusion, authoring tutorials and
 references should omit
 [\<custom-ident\>](https://www.w3.org/TR/css-values-4/#identifier-value) from their materials.

 The
 [normal](#valdef-color-scheme-normal),
 [light](#valdef-color-scheme-light),
 [dark](#valdef-color-scheme-dark), and
 [only](#valdef-color-scheme-only) keywords are not valid
 [\<custom-ident\>](https://www.w3.org/TR/css-values-4/#identifier-value)s in this property.

If an element has any value other than [color-scheme:
normal](#propdef-color-scheme), its [element color
scheme](#element-color-scheme) is determined by finding the [used color
scheme](#used-color-scheme), given the user's [preferred color
scheme](#preferred-color-scheme) and the element's [color scheme
support](#color-scheme-support) specified by this property.

A page might be generally capable of
handling multiple color schemes, while still having a sub-section that
needs to be rendered in a particular color scheme.

For example, a style guide might give several UI examples that are using
light or dark colors, showing off the light or dark theme specifically.
This can be indicated as:

``` highlight
<meta name=color-scheme content="light dark">
<style>
.light-theme-example {
 color-scheme: light;
}

.dark-theme-example {
 color-scheme: dark;
}
</style>
```

Only the subsections rooted at [.light-theme-example] or
[.dark-theme-example] will be opted into the
[light](#light-color-scheme) or
[dark](#dark-color-scheme)
themes specifically; the rest of the page will respect the user's
preference.

 Repeating a keyword, such as [color-scheme: light
light](#propdef-color-scheme), is valid but has no additional effect beyond what
the first instance of the keyword provides.

### 2.3. Resolving Color Schemes

While it's important for a page to respect the user's preferred [color
scheme](#color-scheme), it's
also important to only use a [color scheme] the
page author *expects*, or else it is very easy to render a page
unreadable by causing the foreground and background elements to
accidentally have minimal (or zero!) contrast.

For example, an author expecting the default light color scheme might
set the page background to a light cream while leaving the text color
unset, expecting it to use the default black text color. If the page
unexpectedly opted into a user's preferred [dark color
scheme](#dark-color-scheme), however, and adjusted the default text color to white,
that would make the text virtually unreadable.

To balance these competing concerns, a user's [color scheme
preference](#color-scheme-preference) is compared against a page's [color scheme
support](#color-scheme-support) to produce a used [color
scheme](#color-scheme).

A [color scheme preference] is either no preference, a [color
scheme](#color-scheme)
preference ([light](#light-color-scheme) or
[dark](#dark-color-scheme)), or an
[overriding] [color scheme] preference.

A [color scheme support] is null, or an ordered list of one or more
supported [color schemes](#color-scheme), along with a flag indicating whether or not it
*solely* supports the indicated [color
schemes].

To determine the [used color scheme], given a [color scheme
support](#color-scheme-support) `support` and a [color scheme
preference](#color-scheme-preference) `preference`:

1. If `support` is null, or none of the [color
 schemes](#color-scheme) in
 `support` are supported by the UA, return the UA default
 [color scheme], and annotate that this
 [color scheme] was
 [defaulted](#color-scheme-default).

2. If `preference` is no preference, return the first
 supported [color scheme](#color-scheme) in `support`.

3. If `preference`'s [color
 scheme](#color-scheme) is
 in `support` and supported by the UA, return that [color
 scheme].

4. If `support` is flagged as sole support, return the first
 supported [color scheme](#color-scheme) in `support`.

5. If `preference` is an [overriding
 preference](#color-scheme-overriding-preference), return `preference`'s [color
 scheme](#color-scheme). If
 this [color scheme] is used as an [element
 color scheme](#element-color-scheme), also [override the color
 scheme](#override-the-color-scheme) on the element to this [color
 scheme].

6. Otherwise, return the first supported [color
 scheme](#color-scheme) in
 `support`.

 The basic logic here is that, if the page hasn't opted
into color schemes at all (null `supports`), we go with the
safe UA default that it was probably implicitly designed for. If there
*is* a usable `supports`, and it matches
`preference`, we use the preference. Otherwise
`preference` and `supports` disagree, and we go
back and forth down the preference hierarchy to see who wins: sole
support in `support` wins, then overriding preference in
`preference` wins (and we adjust the element's colors to make
sure this actually *works*), then `support` finally wins.

 User agents are **not required** to support any
particular [color scheme](#color-scheme), so only using a single keyword, such as [color-scheme:
dark](#propdef-color-scheme), to indicate a required [color
scheme] is still not guaranteed to have any
effect on the rendering of the element.

 User agents might not actually support preference
levels in a [color scheme
preferences](#color-scheme-preference). At the time of writing, UAs generally only support an
ordinary [light](#light-color-scheme) or
[dark](#dark-color-scheme)
preference, which considerably simplifies the above logic.

### 2.4. Effects of the Used Color Scheme

For all elements, the user agent must match the following to the
[element color
scheme](#element-color-scheme):

- the default colors of scrollbars and other interaction UI

- the default colors of form controls and other \"specially-rendered\"
 elements

- the default colors of other browser-provided UI, such as
 \"spellcheck\" underlines

- the value of [system
 colors](https://www.w3.org/TR/css-color-4/#css-system-colors)

- the value of the
 [light-dark()](https://www.w3.org/TR/css-color-5/#funcdef-light-dark) function

On the root element, the [element color
scheme](#element-color-scheme) additionally must affect the surface color of the
[canvas](https://www.w3.org/TR/CSS2/intro.html#canvas), and the viewport's scrollbars.

In order to preserve expected color contrasts, in the case of embedded
documents typically rendered over a transparent
[canvas](https://www.w3.org/TR/CSS2/intro.html#canvas) (such as provided via an HTML
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) element), if the [element color
scheme](#element-color-scheme) of the element and the [element color
scheme] of the embedded document's root
element do not match, then the UA must use an opaque
[canvas] of the
[Canvas](https://www.w3.org/TR/css-color-4/#valdef-color-canvas) color appropriate to the embedded document's
root element's [element color scheme]
instead of a transparent canvas. This rule does not apply to documents
embedded via elements intended for graphics (such as
[`img`](https://html.spec.whatwg.org/multipage/embedded-content.html#the-img-element) elements embedding an SVG document); their canvases
remain the default transparent regardless.

 Aside from the small list of adjustments given above,
user agents generally do not further adjust a page to match the user's
preferred [color scheme](#color-scheme), because the chance of accidentally ruining a page is
too high. However, when particular color choices are required by the
user (for accessibility reasons, for example), more invasive changes
might be applied; see [§ 3 Forced Color Palettes](#forced).

### 2.5. Overriding the Color Scheme

If the user has indicated an [overriding
preference](#color-scheme-overriding-preference) for a particular color scheme that the author does not
explicitly support, and the author has not disallowed this (by using the
[only](#valdef-color-scheme-only) keyword), the user agent must [override the
color scheme]: in addition to the effects described in
[§ 2.4 Effects of the Used Color Scheme](#color-scheme-effect), it must
also auto-adjust *other* colors into this chosen [color
scheme](#color-scheme), such as
by inverting their brightness, while preserving any color contrast
necessary for readability of the page. In this case, UA may also
auto-adjust colors within replaced elements, background images, and
other external resources as appropriate.

 The specifics of such auto-adjustments are UA-defined,
and can differ from UA to UA. But it is not intended to force all colors
into a fixed palette, as [forced colors
mode](#forced-colors-mode)
does, only to force all colors on the page to conform to either a
[dark](#dark-color-scheme)
or [light](#light-color-scheme) color scheme.

For example, a UA might have a "dark
room" mode, which forces all pages into a
[dark](#dark-color-scheme)
color scheme.

For pages that already support
[dark](#dark-color-scheme)
color schemes, and have indicated so using the
[color-scheme](#propdef-color-scheme) property or
[`color-scheme`](https://html.spec.whatwg.org/multipage/semantics.html#meta-color-scheme)
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta) name, this has no effect other than reporting a
[dark](https://www.w3.org/TR/mediaqueries-5/#valdef-media-prefers-color-scheme-dark) value for the
[prefers-color-scheme](https://www.w3.org/TR/mediaqueries-5/#descdef-media-prefers-color-scheme) [media
query](https://www.w3.org/TR/mediaqueries-5/#media-query) and selecting a [dark]
[used color scheme](#used-color-scheme).

But for pages that do not explicitly support a
[dark](#dark-color-scheme)
color scheme, and have not explicitly forbidden this auto-adjustment by
specifying [color-scheme: only
light](#propdef-color-scheme), this mode triggers auto-adjustment of the page's
colors to *force* the page to conform to the desired
[dark] color scheme.

## 3. Forced Color Palettes

[Forced colors mode] is an accessibility feature intended to
increase the readability of text through color contrast. Individuals
with limited vision often find it more comfortable to read content when
there is a particular type of contrast between foreground and background
colors.

Operating systems can provide built-in color themes, such as Windows'
high contrast black-on-white and high-contrast white-on-black themes.
Users can also customize their own themes, for example to provide low
contrast or hue contrast.

In [forced colors
mode](#forced-colors-mode), the user agent enforces the user's preferred color
palette on the page, overriding the author's chosen colors for specific
properties, see [§ 3.1 Properties Affected by Forced Colors
Mode](#forced-colors-properties). It may also enforce a "backplate"
underneath text (similar to the way backgrounds are painted on the
[::selection](https://www.w3.org/TR/css-pseudo-4/#selectordef-selection) pseudo-element) to ensure adequate contrast for
readability.

To enable pages to adapt to [forced colors
mode](#forced-colors-mode)
user agents will match the
[forced-colors](https://www.w3.org/TR/mediaqueries-5/#descdef-media-forced-colors) media query and must provide the
required color palette through the CSS system colors (see
[\[CSS-COLOR-4\]](#biblio-css-color-4 "CSS Color Module Level 4")).
Additionally, if the UA determines, based on Lab lightness, that the
[Canvas](https://www.w3.org/TR/css-color-4/#valdef-color-canvas) color is clearly either dark (L \< 33%) or light
(L \> 67%), then it must match the appropriate value of the
[prefers-color-scheme](https://www.w3.org/TR/mediaqueries-5/#descdef-media-prefers-color-scheme) media query and express a corresponding
user preference for
[color-scheme](#propdef-color-scheme). This will allow pages that support
light/dark color schemes to automatically adjust to more closely match
the forced color scheme. Behavior between the above dark vs. light
thresholds is UA-defined, and may result in assuming either
[light] or [dark] as the user's preferred color scheme.

If [get emulated forced colors theme
data](#get-emulated-forced-colors-theme-data) is not
\"[`none`](#dom-forcedcolorsmodeautomationtheme-none)\", the user agent should bypass the above operating
system color themes, and instead act as if the user has enabled [forced
colors mode](#forced-colors-mode) with the [forced colors mode emulation color
palette](#forced-colors-mode-emulation-color-palettes) defined for the resulting value of [emulated forced
colors theme
data](#emulated-forced-colors-theme-data).

### 3.1. Properties Affected by Forced Colors Mode

When [forced colors
mode](#forced-colors-mode)
is active and
[forced-color-adjust](#propdef-forced-color-adjust) is
[auto](#valdef-forced-color-adjust-auto) (see below) on an element, the
[\<color\>](https://www.w3.org/TR/css-color-5/#typedef-color) components of all properties on the
element are force-adjusted to the user's preferred color palette.

Specifically, [forced colors
mode](#forced-colors-mode)
applies to the following color properties, along with their shorthands.
This is the list of color properties existing at the time of writing,
but it may not be an exhaustive list as more properties get added over
time:

- [accent-color](https://www.w3.org/TR/css-ui-4/#propdef-accent-color)
- [background-color](https://www.w3.org/TR/css-backgrounds-3/#propdef-background-color)
- [border-color](https://www.w3.org/TR/css-backgrounds-3/#propdef-border-color)
- [caret-color](https://www.w3.org/TR/css-ui-4/#propdef-caret-color)
- [color](https://www.w3.org/TR/css-color-4/#propdef-color)
- [flood-color](https://www.w3.org/TR/filter-effects-1/#propdef-flood-color)
- [fill](https://www.w3.org/TR/fill-stroke-3/#propdef-fill)
- [lighting-color](https://www.w3.org/TR/filter-effects-1/#propdef-lighting-color)
- [outline-color](https://www.w3.org/TR/css-ui-4/#propdef-outline-color)
- [rule-color](https://www.w3.org/TR/css-gaps-1/#propdef-rule-color)
- [scrollbar-color](https://www.w3.org/TR/css-scrollbars-1/#propdef-scrollbar-color)
- [stop-color](https://www.w3.org/TR/SVG2/pservers.html#StopColorProperty)
- [stroke](https://www.w3.org/TR/fill-stroke-3/#propdef-stroke)
- [text-decoration-color](https://www.w3.org/TR/css-text-decor-4/#propdef-text-decoration-color)
- [text-emphasis-color](https://www.w3.org/TR/css-text-decor-4/#propdef-text-emphasis-color)
- [-webkit-tap-highlight-color]

For each
[\<color\>](https://www.w3.org/TR/css-color-5/#typedef-color) component of a property, if its
[computed
value](https://www.w3.org/TR/css-cascade-5/#computed-value) is a color other than a [system
color](https://www.w3.org/TR/css-color-4/#css-system-colors), its [used
value](https://www.w3.org/TR/css-cascade-5/#used-value) is instead forced to a [system
color] as follows:

- For
 [background-color](https://www.w3.org/TR/css-backgrounds-3/#propdef-background-color) in particular, it is forced to
 the color opposite the
 [color](https://www.w3.org/TR/css-color-4/#propdef-color) property's [system
 color](https://www.w3.org/TR/css-color-4/#css-system-colors) value in the [system color
 pairings](https://www.w3.org/TR/css-color-4/#system-color-pairings), using
 [CanvasText](https://www.w3.org/TR/css-color-4/#valdef-color-canvastext) as the opposite of
 [Canvas](https://www.w3.org/TR/css-color-4/#valdef-color-canvas). However, its alpha channel is taken from the
 original [background-color] value so that transparent backgrounds remain transparent.

- In all other cases, the UA determines the appropriate forced [system
 color](https://www.w3.org/TR/css-color-4/#css-system-colors)---​which should match the color that would result from
 an empty [author style
 sheet](https://www.w3.org/TR/css-cascade-5/#cascade-origin-author) whenever all of the element's affected properties are
 likewise UA-determined.

 :::
 UAs need to be careful about inheritance when forcing colors. For
 example, suppose the UA's button
 [color](https://www.w3.org/TR/css-color-4/#propdef-color) and
 [background-color](https://www.w3.org/TR/css-backgrounds-3/#propdef-background-color) are the opposite of its canvas
 [color] and
 [background-color].
 Given markup such as
 ``` highlight
 <button>Push <em>this</em> button</button>
 ```

 Normally,
 [`em`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-em-element) will inherit from
 [`button`](https://html.spec.whatwg.org/multipage/form-elements.html#the-button-element), ensuring its readability. However in [forced
 colors mode](#forced-colors-mode), the
 [color](https://www.w3.org/TR/css-color-4/#propdef-color) of both
 [`button`](https://html.spec.whatwg.org/multipage/form-elements.html#the-button-element) and
 [`em`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-em-element) will need to be forced. It's easy to see that
 [`button`](https://html.spec.whatwg.org/multipage/form-elements.html#the-button-element)'s color should be forced to the button color, but
 [`em`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-em-element) also needs to be forced to the button color; if
 it were forced to the canvas [color] like it is everywhere else in the document, its text will
 be unreadable.
 :::

Additionally:

- [box-shadow](https://www.w3.org/TR/css-backgrounds-3/#propdef-box-shadow) and
 [text-shadow](https://www.w3.org/TR/css-text-decor-4/#propdef-text-shadow) compute to
 [none](https://www.w3.org/TR/css-backgrounds-3/#box-shadow-none)

- [background-image](https://www.w3.org/TR/css-backgrounds-3/#propdef-background-image) computes to
 [none](https://www.w3.org/TR/css-backgrounds-3/#valdef-background-image-none) unless the original value contains a
 [url()](https://www.w3.org/TR/css-values-4/#funcdef-url) function

- [color-scheme](#propdef-color-scheme) computes to [light dark]

- [scrollbar-color](https://www.w3.org/TR/css-scrollbars-1/#propdef-scrollbar-color) computes to
 [auto](https://www.w3.org/TR/css-scrollbars-1/#valdef-scrollbar-color-auto)

- [accent-color](https://www.w3.org/TR/css-ui-4/#propdef-accent-color) computes to
 [auto](https://www.w3.org/TR/css-ui-4/#valdef-accent-color-auto)

- If
 [font-variant-emoji](https://www.w3.org/TR/css-fonts-4/#propdef-font-variant-emoji) computes to
 [normal](https://www.w3.org/TR/css-fonts-4/#valdef-font-variant-emoji-normal) or
 [unicode](https://www.w3.org/TR/css-fonts-4/#valdef-font-variant-emoji-unicode), UAs should force any emoji on the page to its
 monochrome variant, if available, by forcing the [computed
 value](https://www.w3.org/TR/css-cascade-5/#computed-value) of
 [font-variant-emoji]
 to
 [text](https://www.w3.org/TR/css-fonts-4/#valdef-font-variant-emoji-text).

UAs may further tweak these [forced colors
mode](#forced-colors-mode)
heuristics to provide better user experience.

Authors may still use features such as
[color-mix()](https://www.w3.org/TR/css-color-5/#funcdef-color-mix) in [forced colors
mode](#forced-colors-mode). In such cases, the [computed
value](https://www.w3.org/TR/css-cascade-5/#computed-value) will behave as it would normally, but the [used
value](https://www.w3.org/TR/css-cascade-5/#used-value) will be overridden with an appropriate [system
color](https://www.w3.org/TR/css-color-4/#css-system-colors).

``` highlight
.example {
 color: color-mix(in srgb, CanvasText, Canvas);
}
```

The [computed
value](https://www.w3.org/TR/css-cascade-5/#computed-value) for
[color](https://www.w3.org/TR/css-color-4/#propdef-color) will be a 50-50 blend of the
[CanvasText](https://www.w3.org/TR/css-color-4/#valdef-color-canvastext) and
[Canvas](https://www.w3.org/TR/css-color-4/#valdef-color-canvas) [system
colors](https://www.w3.org/TR/css-color-4/#css-system-colors). That value will inherit to descendants and be
observable via APIs such as
[`computedStyleMap()`](https://www.w3.org/TR/css-typed-om-1/#dom-element-computedstylemap).

The [used
value](https://www.w3.org/TR/css-cascade-5/#used-value) for
[color](https://www.w3.org/TR/css-color-4/#propdef-color) will be a system color chosen by
the UA, for example
[CanvasText](https://www.w3.org/TR/css-color-4/#valdef-color-canvastext).

### 3.2. Opting Out of a Forced Color Palette: the [forced-color-adjust property]
Name:

[forced-color-adjust]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://www.w3.org/TR/css-values-4/#comb-one) none [\|] preserve-parent-color

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements and text

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

The
[forced-color-adjust](#propdef-forced-color-adjust) property allows authors to opt
particular elements out of [forced colors
mode](#forced-colors-mode), restoring full control over the colors to CSS. Values
have the following meanings:

[auto]

: The element's colors are automatically adjusted by the UA in [forced
 colors mode](#forced-colors-mode).

[none]

: The element's colors are not automatically adjusted by the UA in
 [forced colors
 mode](#forced-colors-mode).

 **Authors should only use this value when they are themselves
 adjusting the colors to support the user's color and contrast needs
 and need to make changes to the UA's default adjustments to provide
 a more appropriate user experience for those elements.**

[preserve-parent-color]

: In [forced colors
 mode](#forced-colors-mode), if the
 [color](https://www.w3.org/TR/css-color-4/#propdef-color) property inherits from its
 parent (i.e. there is no [cascaded
 value](https://www.w3.org/TR/css-cascade-5/#cascaded-value) or the [cascaded value]
 is
 [currentColor](https://www.w3.org/TR/css-color-4/#valdef-color-currentcolor),
 [inherit](https://www.w3.org/TR/css-cascade-5/#valdef-all-inherit), or another keyword that inherits from the
 parent), then it computes to the
 [used](https://www.w3.org/TR/css-cascade-5/#used-value) color of its parent's
 [color] value.

 In all other respects, behaves the same as
 [none](#valdef-forced-color-adjust-none).

 This value is intended solely to get a reasonable
 behavior from embedded SVG elements that expect to receive the outer
 document's text color (and stay consistent with adjustments from
 [forced colors
 mode](#forced-colors-mode)), while otherwise defaulting SVGs to preserving
 their exact colors, as [forced colors
 mode] can't generally be usefully
 applied to illustrations.

In order to not break SVG content, UAs are expected to add the following
rules to their UA style sheet:

``` highlight
@namespace "http://www.w3.org/2000/svg";
svg|svg { forced-color-adjust: preserve-parent-color; }
svg|foreignObject { forced-color-adjust: auto; }
```

UAs must propagate the
[forced-color-adjust](#propdef-forced-color-adjust) value set on the root element to
the document viewport (where it can affect e.g. the canvas background).
Note that [forced-color-adjust] is *not* propagated from HTML
[`body`](https://html.spec.whatwg.org/multipage/sections.html#the-body-element).

## 4. Performance-based Color Adjustments

On most monitors, the color choices that authors make have no
significant difference in terms of how the device performs; displaying a
document with a white background or a black background is approximately
equally easy.

However, some devices have limitations and other qualities that make
this assumption untrue. For example, printers tend to print on white
paper; a document with a white background thus has to spend no ink on
drawing that background, while a document with a black background will
have to expend a large amount of ink filling in the background color.
This tends to look fairly bad, and sometimes has deleterious physical
effects on the paper, not to mention the vastly increased printing cost
from expending the extra ink. Even fairly small differences, such as
coloring text black versus dark gray, can be quite different when
printing, as it switches from using a single black ink to a mixture of
cyan, magenta, and yellow ink, resulting in higher ink usage and lower
resolution.

As a result, in some circumstances user agents will alter the styles an
author specifies in some particular context, adjusting them to be more
appropriate for the output device and to accommodate what they assume
the user would prefer. However, in some cases the document may be using
colors in important, well-thought-out ways that the user would
appreciate, and so the document would like some way to hint to the user
agent that it might want to respect the page's color choices. This
section defines properties for controlling these automatic adjustments.

### 4.1. Ink Economy: the [print-color-adjust property]
Name:

[print-color-adjust]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

economy
[\|](https://www.w3.org/TR/css-values-4/#comb-one) exact

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

economy

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

The
[print-color-adjust](#propdef-print-color-adjust) property provides a hint to the
user-agent about how it should treat color and style choices that might
be expensive or generally unwise on a printer or similar device, such as
using light text on a dark background. If user agents allow users to
control this aspect of the document's display, the user preference
**must** be respected more strongly than the hint provided by
[print-color-adjust]. It
has the following values:

[economy]

: The user agent should make adjustments to the page's styling as it
 deems necessary and prudent for the output device.

 For example, if the document is being printed, a user agent might
 ignore any backgrounds and adjust text color to be sufficiently
 dark, to minimize ink usage.

[exact]

: This value indicates that the page is using color and styling on the
 specified element in a way which is important and significant, and
 which should not be tweaked or changed except at the user's request.

 For example, a mapping website offering printed directions might
 \"zebra-stripe\" the steps in the directions, alternating between
 white and light gray backgrounds. Losing this zebra-striping and
 having a pure-white background would make the directions harder to
 read with a quick glance when distracted in a car.

UAs must propagate the
[print-color-adjust](#propdef-print-color-adjust) value set on the root element to
the document viewport (where it can affect e.g. the canvas background).
Note that [print-color-adjust] is *not* propagated from HTML
[`body`](https://html.spec.whatwg.org/multipage/sections.html#the-body-element).

### 4.2. The [color-adjust Shorthand]
Name:

[color-adjust]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'print-color-adjust\'\>](#propdef-print-color-adjust)

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

The [color-adjust](#propdef-color-adjust) shorthand allows an author to set
all of the performance-motivated color adjustment properties in one
declaration. (Currently, there is only one such
property---​[print-color-adjust](#propdef-print-color-adjust)---​but more might be added in the
future.)

**The
[color-adjust](#propdef-color-adjust) shorthand is currently
*deprecated*. Authors should use the more specific
[print-color-adjust](#propdef-print-color-adjust) property, to avoid accidentally
resetting performance-based color adjustments in other contexts than the
one intended.**

## 5. Emulation

For the purposes of user agent automation and application testing, this
document defines the below emulations.

### 5.1. Emulate Forced Colors Mode

Each [top-level
traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) has an associated [emulated forced colors theme
data], which is data representing
[`ForcedColorsModeAutomationTheme`](#enumdef-forcedcolorsmodeautomationtheme), initially
\"[`none`](#dom-forcedcolorsmodeautomationtheme-none)\".

```
enum ForcedColorsModeAutomationTheme {
 "none",
 "light",
 "dark"
};
```

To [set emulated forced colors theme
data], given
[navigable](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window-navigable) `navigable` and an
`emulatedThemeData`:

1. Assert `emulatedThemeData` is
 [`ForcedColorsModeAutomationTheme`](#enumdef-forcedcolorsmodeautomationtheme).

2. Let `traversable` be `navigable`'s [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top).

3. If `traversable` is not null:

 1. Set `traversable`'s associated [emulated forced
 colors theme
 data](#emulated-forced-colors-theme-data) to `emulatedThemeData`.

 2. UAs must consider this a change that requires style
 recalculation.

To [get emulated forced colors theme
data], given
[`ForcedColorsModeAutomationTheme`](#enumdef-forcedcolorsmodeautomationtheme) `theme`:

1. Let `navigable` be `theme`'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [associated
 Document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window)'s [node
 navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#node-navigable).

2. If `navigable` is null, return null.

3. Let `traversable` be `navigable`'s [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top).

4. If `traversable` is null, return null.

5. Return `traversable`'s associated [emulated forced colors
 theme
 data](#emulated-forced-colors-theme-data).

### 5.2. Forced Colors Mode Color Palettes

For the purposes of user agent automation and application testing, this
document defines the below [forced colors mode emulation color
palettes].

[System
color](https://www.w3.org/TR/css-color-4/#css-system-colors) mappings for
\"[`light`](#dom-forcedcolorsmodeautomationtheme-light)\"

[\<system-color\>](https://www.w3.org/TR/css-color-4/#typedef-system-color) keyword

Value

[AccentColor](https://www.w3.org/TR/css-color-4/#valdef-color-accentcolor)

  #FFFFFF

[AccentColorText](https://www.w3.org/TR/css-color-4/#valdef-color-accentcolortext)

  #000000

[ActiveText](https://www.w3.org/TR/css-color-4/#valdef-color-activetext)

  #00009F

[ButtonBorder](https://www.w3.org/TR/css-color-4/#valdef-color-buttonborder)

  #000000

[ButtonFace](https://www.w3.org/TR/css-color-4/#valdef-color-buttonface)

  #FFFFFF

[ButtonText](https://www.w3.org/TR/css-color-4/#valdef-color-buttontext)

  #000000

[Canvas](https://www.w3.org/TR/css-color-4/#valdef-color-canvas)

  #FFFFFF

[CanvasText](https://www.w3.org/TR/css-color-4/#valdef-color-canvastext)

  #000000

[Field](https://www.w3.org/TR/css-color-4/#valdef-color-field)

  #FFFFFF

[FieldText](https://www.w3.org/TR/css-color-4/#valdef-color-fieldtext)

  #000000

[GrayText](https://www.w3.org/TR/css-color-4/#valdef-color-graytext)

  #600000

[Highlight](https://www.w3.org/TR/css-color-4/#valdef-color-highlight)

  #37006E

[HighlightText](https://www.w3.org/TR/css-color-4/#valdef-color-highlighttext)

  #FFFFFF

[LinkText](https://www.w3.org/TR/css-color-4/#valdef-color-linktext)

  #00009F

[Mark](https://www.w3.org/TR/css-color-4/#valdef-color-mark)

N/A - this [system
color](https://www.w3.org/TR/css-color-4/#css-system-colors) keyword should not be adjusted.

[MarkText](https://www.w3.org/TR/css-color-4/#valdef-color-marktext)

N/A - this [system
color](https://www.w3.org/TR/css-color-4/#css-system-colors) keyword should not be adjusted.

[SelectedItem](https://www.w3.org/TR/css-color-4/#valdef-color-selecteditem)

  #37006E

[SelectedItemText](https://www.w3.org/TR/css-color-4/#valdef-color-selecteditemtext)

  #FFFFFF

[VisitedText](https://www.w3.org/TR/css-color-4/#valdef-color-visitedtext)

  #00009F

[System
color](https://www.w3.org/TR/css-color-4/#css-system-colors) mappings for
\"[`dark`](#dom-forcedcolorsmodeautomationtheme-dark)\"

[\<system-color\>](https://www.w3.org/TR/css-color-4/#typedef-system-color) keyword

Value

[AccentColor](https://www.w3.org/TR/css-color-4/#valdef-color-accentcolor)

  #000000

[AccentColorText](https://www.w3.org/TR/css-color-4/#valdef-color-accentcolortext)

  #FFFFFF

[ActiveText](https://www.w3.org/TR/css-color-4/#valdef-color-activetext)

  #FFFF00

[ButtonBorder](https://www.w3.org/TR/css-color-4/#valdef-color-buttonborder)

  #000000

[ButtonFace](https://www.w3.org/TR/css-color-4/#valdef-color-buttonface)

  #000000

[ButtonText](https://www.w3.org/TR/css-color-4/#valdef-color-buttontext)

  #FFFFFF

[Canvas](https://www.w3.org/TR/css-color-4/#valdef-color-canvas)

  #000000

[CanvasText](https://www.w3.org/TR/css-color-4/#valdef-color-canvastext)

  #FFFFFF

[Field](https://www.w3.org/TR/css-color-4/#valdef-color-field)

  #000000

[FieldText](https://www.w3.org/TR/css-color-4/#valdef-color-fieldtext)

  #FFFFFF

[GrayText](https://www.w3.org/TR/css-color-4/#valdef-color-graytext)

  #3FF23F

[Highlight](https://www.w3.org/TR/css-color-4/#valdef-color-highlight)

  #1AEBFF

[HighlightText](https://www.w3.org/TR/css-color-4/#valdef-color-highlighttext)

  #000000

[LinkText](https://www.w3.org/TR/css-color-4/#valdef-color-linktext)

  #FFFF00

[Mark](https://www.w3.org/TR/css-color-4/#valdef-color-mark)

N/A - this [system
color](https://www.w3.org/TR/css-color-4/#css-system-colors) keyword should not be adjusted.

[MarkText](https://www.w3.org/TR/css-color-4/#valdef-color-marktext)

N/A - this [system
color](https://www.w3.org/TR/css-color-4/#css-system-colors) keyword should not be adjusted.

[SelectedItem](https://www.w3.org/TR/css-color-4/#valdef-color-selecteditem)

  #1AEBFF

[SelectedItemText](https://www.w3.org/TR/css-color-4/#valdef-color-selecteditemtext)

  #000000

[VisitedText](https://www.w3.org/TR/css-color-4/#valdef-color-visitedtext)

  #FFFF00

## 6. Privacy Considerations

Applying user color preferences via [color
schemes](#color-scheme) or
[forced colors mode](#forced-colors-mode) exposes the user's color preferences to the page via
[`getComputedStyle()`](https://www.w3.org/TR/cssom-1/#dom-window-getcomputedstyle), which can increase fingerprinting surface.

Avoiding this comes with unfortunate drawbacks that were deemed too
significant to be ignored. Namely:

- preserving system colors as keywords until actual-value time would
 break a significant amount of deployed script, as the initial value of
 [color](https://www.w3.org/TR/css-color-4/#propdef-color) is a system color already (but a
 huge amount of script implicitly expects to see an RGB color from
 [color])

- lying about system colors from the scripting APIs (pretending they're
 always some static values) can result in any colors calculated *from*
 page colors in script being unreadable when used with the *actual*
 system colors.

See [Issue
5710](https://github.com/w3c/csswg-drafts/issues/5710#issuecomment-840772752)
for discussion on this topic.

Embedded documents (even cross-origin ones) recieve their embedding
element's [element color
scheme](#element-color-scheme) as their [preferred color
scheme](#preferred-color-scheme), which is technically a bit of cross-site
communication. This was not considered a significant problem by browser
security reviewers, and the user benefit of having pages and,
particularly, SVG images automatically adapt to the parent page's color
scheme was considered valuable enought to warrant it.

## 7. Security Considerations

It may be possible for an embedded document to use timing attacks to
determine whether its own
[color-scheme](#propdef-color-scheme) matches that of its embedding
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) or not.

## 8. Acknowledgements

This specification would not be possible without the development efforts
of various color adjustment features at Apple, Google, and Microsoft as
well as discussions about print adjustments on www-style. In particular,
the CSS Working Group would like to thank: François Remy,
イアンフェッティ

List additional MSFT / Apple / Google
people here.

## 9. Changes

Changes since the [10 February 2022 Candidate Recommendation
Snapshot](https://www.w3.org/TR/2022/CR-css-color-adjust-1-20220210/):

- Removed special handling of
 [color()](https://www.w3.org/TR/css-color-5/#funcdef-color) fallback system colors, since the feature was
 removed from
 [\[CSS-COLOR-4\]](#biblio-css-color-4 "CSS Color Module Level 4").
 ([Issue 7007](https://github.com/w3c/csswg-drafts/issues/7007))
- Added emulation support for improved testing of [forced colors
 mode](#forced-colors-mode). ([Issue
 11824](https://github.com/w3c/csswg-drafts/issues/11824#issuecomment-2769343959))
- Updated the properties that apply in [forced colors
 mode](#forced-colors-mode) to more generically apply to the
 [\<color\>](https://www.w3.org/TR/css-color-5/#typedef-color) components of all properties, with
 specific known properties moved to a note. ([Issue
 11857](https://github.com/w3c/csswg-drafts/issues/11857))
- Added font emoji fallback logic for [forced colors
 mode](#forced-colors-mode). ([Issue
 8064](https://github.com/w3c/csswg-drafts/issues/8064))

**See also [Changes prior to Candidate
Recommendation](https://www.w3.org/TR/2022/CR-css-color-adjust-1-20220210/#changes).**
