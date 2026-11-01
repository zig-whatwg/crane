## 1. Introduction

This is a diff spec over
[\[css-images-4\]](#biblio-css-images-4 "CSS Images Module Level 4").

## [2. ][2D Image Values: the [\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image) type]
\...

### 2.1. Image Fallbacks and Annotations: the [image() notation]
[\[css-images-4\]](#biblio-css-images-4 "CSS Images Module Level 4")
defines a simple form of the
[image()](#funcdef-image) function, which generates a solid-color dimensionless
image. This level introduces a number of additional functions.

The [image()](#funcdef-image) function allows an author to:

- use [media fragments](https://www.w3.org/TR/media-frags/) to clip out
 a portion of an image

- use a solid color as an image

- fallback to a solid-color image, when the image at the specified url
 can't be downloaded or decoded

- automatically respect the image orientation specified in the image's
 metadata

The [image()](#funcdef-image) notation is defined as:

```
image() = image( <image-tags>? [ <image-src>? , <color>? ]! )
<image-tags> = [ ltr | rtl ]
<image-src> = [ <url> | <string> ]
```

A
[\<string\>](https://drafts.csswg.org/css-values-4/#string-value) used in
[image()](#funcdef-image) represents a
[\<url\>](https://drafts.csswg.org/css-values-4/#url-value). As usual for URLs in CSS, relative
URLs are resolved to an absolute URL (as described in Values & Units
[\[CSS-VALUES-3\]](#biblio-css-values-3 "CSS Values and Units Module Level 3"))
when a specified [image()] value is
computed.

If the image has an orientation specified in its metadata, such as EXIF,
the UA must rotate or flip the image to correctly orient it as the
metadata specifies.

#### 2.1.1. Image Fallbacks

If both a URL and a
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) are specified in
[image()](#funcdef-image), then whenever the URL represents an [invalid
image](https://drafts.csswg.org/css-images-4/#invalid-image) or [loading
image](https://drafts.csswg.org/css-images-4/#loading-image), the [image()] function
renders as if the URL were not specified at all; it generates a
solid-color image as specified in [§ 2.1.3 Solid-color
Images](#color-images).

If just a URL is specified (no
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color)) and it represents an [invalid
image](https://drafts.csswg.org/css-images-4/#invalid-image) or [loading
image](https://drafts.csswg.org/css-images-4/#loading-image), the [image()](#funcdef-image) function represents the same.

Tests

The fallback color can be used to ensure
that text is still readable even when the image fails to load. For
example, the following legacy code works fine if the image is
rectangular and has no transparency:

```
body { color: black; background: white; }
p.special { color: white; background: url("dark.png") black; }
```

When the image doesn't load, the background color is still there to
ensure that the white text is readable. However, if the image has some
transparency, the black will be visible behind it, which is probably not
desired. The [image()](#funcdef-image) function addresses this:

```
body { color: black; background: white; }
p.special { color: white; background: image("dark.png", black); }
```

Now, the black won't show at all if the image loads, but if for whatever
reason the image fails, it'll pop in and prevent the white text from
being set against a white background.

#### 2.1.2. Image Fragments

When a URL specified in
[image()](#funcdef-image) represents a portion of a resource (e.g. by the use
of [media fragment
identifiers](https://www.w3.org/TR/media-frags/#naming-space)) that
portion is clipped out of its context and used as a standalone image.

For example, given the following
image and CSS:

[![\[9 circles, with 0 to 8 eighths filled
in\]](images/sprites.svg){height="20" width="180"}](images/sprites.svg)

```
background-image: image('sprites.svg#xywh=40,0,20,20')
```

\...the background of the element will be the portion of the image that
starts at (40px,0px) and is 20px wide and tall, which is just the circle
with a quarter filled in.

So that authors can take advantage of CSS's forwards-compatible parsing
rules to provide a fallback for image slices, implementations that
support the [image()](#funcdef-image) notation *must* support the
`xywh=#,#,#,#` form of media fragment identifiers for images
specified via [image()].
[\[MEDIA-FRAGS\]](#biblio-media-frags "Media Fragments URI 1.0 (basic)")

Note that image fragments
can also be used with the
[url()](https://drafts.csswg.org/css-values-4/#funcdef-url) notation. However, a legacy UA that doesn't
understand the media fragments notation will ignore the fragment and
simply display the entirety of the image.

Since the [image()](#funcdef-image) notation requires UAs to support media fragments,
authors can take advantage of CSS's forward-compatible parsing rules to
provide a fallback when using an image fragment URL:

```
background-image: url('swirl.png'); /* old UAs */
background-image: image('sprites.png#xywh=10,30,60,20'); /* new UAs */
```

If a URL uses a fragment identifier syntax that the implementation does
not understand, or does not consider valid for that type of image, the
URL must be treated as representing an [invalid
image](https://drafts.csswg.org/css-images-4/#invalid-image).

 This error-handling is limited to
[image()](#funcdef-image), and not in the definition of URL, for legacy compat
reasons.

#### 2.1.3. Solid-color Images

If the [image()](#funcdef-image) function is specified with only a
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) argument (no URL), it represents a
solid-color image of the specified color with no [natural
dimensions](https://drafts.csswg.org/css-images-3/#natural-dimensions).

For example, one can use this as a
simple way to \"tint\" a background image, by overlaying a
partially-transparent color over the top of the other image:

```
background-image: image(rgba(0, 0, 255, .5)), url("bg-image.png");
```

This is equivalent to a single color stop gradient:

```
background-image: linear-gradient(rgba(0, 0, 255, .5)), url("bg-image.png");
```

[background-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-color) does not work for this, as the
solid color it generates always lies *beneath* all the background
images.

#### 2.1.4. Bidi-sensitive Images

Before listing any `<image-src>s`, the author may specify a
directionality for the image, similar to adding a `dir`
attribute to an element in HTML. If a directional image is used on or in
an element with opposite
[direction](https://www.w3.org/TR/CSS21/visuren.html#propdef-direction),
the image must be flipped in the inline direction (as if it was
transformed by, e.g., `scaleX(-1)`, if the inline direction
is the X axis).

 Absent this declaration, images default to no
directionality at all, and thus don't care about the directionality of
the surrounding element.

A list may use an arrow for a
bullet that points into the content. If the list can contain both LTR
and RTL text, though, the bullet may be on the left or the right, and an
image designed to point into the text on one side will point out of the
text on the other side. This can be fixed with code like:

```
<ul style="list-style-image: image(ltr 'arrow.png');">
 <li dir='ltr'>My bullet is on the left!</li>
 <li dir='rtl'>MY BULLET IS ON THE RIGHT!</li>
</ul>
```

This should render something like:

```
⇒ My bullet is on the left!
 !THGIR EHT NO SI TELLUB YM ⇐
```

In LTR list items, the image will be used as-is. In the RTL list items,
however, it will be flipped in the inline direction, so it still points
into the content.

## 3. Sizing Images and Objects in CSS

### 3.1. Setting The Viewbox: the [object-view-box property]
Name:

[object-view-box]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<basic-shape-rect\>](https://drafts.csswg.org/css-shapes-1/#typedef-basic-shape-rect)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[replaced
elements](https://drafts.csswg.org/css-display-4/#replaced-element)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword, or computed
[\<basic-shape\>](https://drafts.csswg.org/css-shapes-1/#typedef-basic-shape) function

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

as
[\<basic-shape\>](https://drafts.csswg.org/css-shapes-1/#typedef-basic-shape) if possible, otherwise discrete

The
[object-view-box](#propdef-object-view-box) property specifies a \"view box\"
over an element, which allows zooming or panning over the element's
contents. It maps to the
[`<svg viewBox>`](https://w3c.github.io/svgwg/svg2-draft/coords.html#TermViewBox) attribute in SVG.
[\[SVG2\]](#biblio-svg2 "Scalable Vector Graphics (SVG) 2")

Make sure behavior is [properly
consistent for
SVG](https://github.com/w3c/csswg-drafts/issues/7058#issuecomment-1057553833).

[none]

: The element does not have a view box.

[[\<basic-shape-rect\>](https://drafts.csswg.org/css-shapes-1/#typedef-basic-shape-rect)]

: If the element does not have both a [natural
 width](https://drafts.csswg.org/css-images-3/#natural-width) and a [natural
 height](https://drafts.csswg.org/css-images-3/#natural-height), this value has no effect, similar to
 [none](#valdef-object-view-box-none).

 Otherwise, specifies a view box for the element.

 First, resolve the
 [\<basic-shape-rect\>](https://drafts.csswg.org/css-shapes-1/#typedef-basic-shape-rect) against a [reference
 box](https://drafts.csswg.org/css-shapes-1/#basic-shape-reference-box) formed by the element's [natural
 sizes](https://drafts.csswg.org/css-images-3/#natural-size) to obtain the element's view box.

 For all purposes, the element is now treated as having [natural
 sizes](https://drafts.csswg.org/css-images-3/#natural-size) equal to the view box's width and height. If the
 element had a [natural aspect
 ratio](https://drafts.csswg.org/css-images-3/#natural-aspect-ratio), it's now treated as instead having the same ratio
 as the view box. Further adjustments to the size/position of the
 element's contents, such as
 [object-position](https://drafts.csswg.org/css-images-3/#propdef-object-position) or
 [object-fit](https://drafts.csswg.org/css-images-4/#propdef-object-fit), are similarly performed on the
 view box instead.

 When the element is painted, its contents are scaled and translated
 such that the element's contents retain the same position and size,
 relative to the view box's final size and position, that they had
 when the view box was determined (above).

 (#issue-61524b01) Have not yet defined what happens if
 the view box is zero-area. It's an error case, so precise behavior
 isn't important; just need to see what impls want to do about it.

 Some replaced elements might have a built-in notion of
a \"view box\", such as the
[`svg`](https://w3c.github.io/svgwg/svg2-draft/struct.html#elementdef-svg) element. Unless otherwise specified, this property
does not interact with such notions; the built-in notion has its effect
as normal, producing a replaced element with [natural
sizes](https://drafts.csswg.org/css-images-3/#natural-size), then this property applies on top of that.

Issue: example here. Need a basic one
showing off zooming in, one showing off zooming out, and one showing off
interaction with object-fit to display how the parts outside the viewbox
can still be painted.

## 4. Privacy Considerations

No new privacy considerations have been reported on this specification.

## 5. Security Considerations

No new security considerations have been reported on this specification.
