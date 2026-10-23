## 1. Introduction

CSS allows authors to load custom fonts from the web via the
[\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule) rule. While this is easy to use when authoring a
stylesheet, it's much more difficult to use dynamically via scripting.

Further, CSS allows the user agent to choose when to actually load a
font; if a font face isn't *currently* used by anything on a page, most
user agents will not download its associated file. This means that later
use of the font face will incur a delay as the user agent finally
notices a usage and begins downloading and parsing the font file.

This specification defines a scripting interface to font faces in CSS,
allowing font faces to be easily created (via the
[`FontFace`](#fontface)
interface) and loaded from script (via
[document.fonts](#font-face-source)). It also provides methods to track
the loading status of an individual font, or of all the fonts on an
entire page.

Several things in this spec use normal
ES objects to define behavior, such as various things using Promises
internally, and FontFaceSet using a Set internally. I believe the
intention here is that these objects (and their prototype chains) are
pristine, unaffected by anything the author has done. Is this a good
intention? If so, how should I indicate this in the spec?

### 1.1. Values

This specification uses
[`Promise`](https://webidl.spec.whatwg.org/#idl-promise)s, which are defined in [ECMAScript
6](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-promise-objects).
MDN has some [good tutorial material introducing
Promises](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise).

### 1.2. Task Sources

Whenever this specification queues a task, it queues it onto the \"font
loading\" [task
source](https://html.spec.whatwg.org/multipage/webappapis.html#task-source).

## 2. The `FontFace` Interface

The [`FontFace`](#fontface)
interface represents a single usable font face. CSS
[\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule) rules implicitly define FontFace objects, or
they can be constructed manually from a url or a buffer source.

```
dictionary FontFaceDescriptors {
 CSSOMString style = "normal";
 CSSOMString weight = "normal";
 CSSOMString width;
 CSSOMString stretch = "normal"; // alias for width, sets the same attribute
 CSSOMString unicodeRange = "U+0-10FFFF";
 CSSOMString featureSettings = "normal";
 CSSOMString variationSettings = "normal";
 CSSOMString display = "auto";
 CSSOMString ascentOverride = "normal";
 CSSOMString descentOverride = "normal";
 CSSOMString lineGapOverride = "normal";
};

enum FontFaceLoadStatus { "unloaded", "loading", "loaded", "error" };

[Exposed=(Window,Worker)]
interface FontFace {
 [Throws]
 constructor(CSSOMString family,
 (CSSOMString or BufferSource) source,
 optional FontFaceDescriptors descriptors = );

 [SetterThrows] attribute CSSOMString family;
 [SetterThrows] attribute CSSOMString style;
 [SetterThrows] attribute CSSOMString weight;
 [SetterThrows, BindingAlias="stretch"] attribute CSSOMString width;
 [SetterThrows] attribute CSSOMString unicodeRange;
 [SetterThrows] attribute CSSOMString variant;
 [SetterThrows] attribute CSSOMString featureSettings;
 [SetterThrows, Pref="layout.css.font-variations.enabled"] attribute CSSOMString variationSettings;
 [SetterThrows] attribute CSSOMString display;
 [SetterThrows] attribute CSSOMString ascentOverride;
 [SetterThrows] attribute CSSOMString descentOverride;
 [SetterThrows] attribute CSSOMString lineGapOverride;
 [SetterThrows] attribute CSSOMString sizeAdjust;

 readonly attribute FontFaceLoadStatus status;
```

Tests

- [fontface-descriptor-updates.html](https://wpt.fyi/results/css/css-font-loading/fontface-descriptor-updates.html "css/css-font-loading/fontface-descriptor-updates.html")
 [[(live
 test)]](http://wpt.live/css/css-font-loading/fontface-descriptor-updates.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-font-loading/fontface-descriptor-updates.html)
- [fontface-override-descriptor-getter-setter.sub.html](https://wpt.fyi/results/css/css-font-loading/fontface-override-descriptor-getter-setter.sub.html "css/css-font-loading/fontface-override-descriptor-getter-setter.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-font-loading/fontface-override-descriptor-getter-setter.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-font-loading/fontface-override-descriptor-getter-setter.sub.html)
- [fontface-override-descriptors.html](https://wpt.fyi/results/css/css-font-loading/fontface-override-descriptors.html "css/css-font-loading/fontface-override-descriptors.html")
 [[(live
 test)]](http://wpt.live/css/css-font-loading/fontface-override-descriptors.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-font-loading/fontface-override-descriptors.html)
- [fontface-size-adjust-descriptor.html](https://wpt.fyi/results/css/css-font-loading/fontface-size-adjust-descriptor.html "css/css-font-loading/fontface-size-adjust-descriptor.html")
 [[(live
 test)]](http://wpt.live/css/css-font-loading/fontface-size-adjust-descriptor.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-font-loading/fontface-size-adjust-descriptor.html)

Clarify all mentions of \"the document\"
to be clear about which document is being referenced, since objects can
move between documents.

[`family`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring)\
[`style`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring)\
[`weight`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring)\
[`width`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring)\
[`stretch`], \
[`unicodeRange`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring)

: These attributes all represent the corresponding aspects of a font
 face, as defined by the descriptors defined in the CSS
 [\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule) rule. They are parsed the same as the
 corresponding [\@font-face]
 descriptors. They are used by the font matching algorithm, but
 otherwise have no effect.

 For example, a [`FontFace`](#fontface) with a
 [`style`](#dom-fontface-style) of `"italic"` *represents* an italic font face; it
 does not **make** the font face italic.

 On getting, return the string associated with this attribute.

 On setting,
 [parse](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) the string according to the grammar for the
 corresponding
 [\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule) descriptor. If it does not match the
 grammar, throw a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror); otherwise, set the attribute to the serialization
 of the parsed value.

 Note that
 [stretch](https://drafts.csswg.org/css-align-3/#valdef-align-content-stretch) is a legacy name alias of
 [width](https://drafts.csswg.org/css-anchor-position-1/#valdef-anchor-size-width) and therefore they set the same attribute.

[`featureSettings`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring)\
[`variationSettings`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring)\
[`display`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring)\
[`ascentOverride`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring)\
[`descentOverride`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring)\
[`lineGapOverride`], of type [CSSOMString](https://drafts.csswg.org/cssom-1/#cssomstring)

: These attributes have the same meaning, and are parsed the same as,
 the corresponding descriptors in the CSS
 [\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule) rules.

 They turn on or off specific features in fonts that support them.
 Unlike the previous attributes, these attributes actually affect the
 font face.

 On getting, return the string associated with this attribute.

 On setting,
 [parse](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) the string according to the grammar for the
 corresponding
 [\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule) descriptor. If it does not match the
 grammar, throw a
 [`SyntaxError`](https://webidl.spec.whatwg.org/#syntaxerror); otherwise, set the attribute to the serialization
 of the parsed value.

[`status`], of type [FontFaceLoadStatus](#enumdef-fontfaceloadstatus), readonly

: This attribute reflects the current status of the font face. It must
 be \"unloaded\" for a newly-created
 [`FontFace`](#fontface).

 It can change due to an author explicitly requesting a font face to
 load, such as through the
 [`load()`](#dom-fontface-load) method on
 [`FontFace`](#fontface),
 or implicitly by the user agent, due to it detecting that the font
 face is needed to draw some text on the screen.

[`loaded`],

: This attribute reflects the
 [`[[FontStatusPromise]]`](#dom-fontface-fontstatuspromise-slot) of the font face.

All [`FontFace`](#fontface)
objects contain an internal
[`[[FontStatusPromise]]`] slot, which tracks the status of the font. It starts out
pending, and fulfills or rejects when the font is successfully loaded
and parsed, or hits an error.

All [`FontFace`](#fontface)
objects also contain internal [`[[Urls]]`] and [`[[Data]]`] slots, of
which one is `null` and the other is not `null` (the non-null one is set
by the constructor, based on which data is passed in).

### 2.1. The Constructor

A [`FontFace`](#fontface) can
be constructed either from a URL pointing to a font face file, or from a
[`BufferSource`](https://webidl.spec.whatwg.org/#BufferSource) containing the binary representation of a font face.

When the
[`FontFace(family, source, descriptors)`]
method is called, execute these steps:

1. Let `font face` be a fresh
 [`FontFace`](#fontface)
 object. Set `font face’s`
 [`status`](#dom-fontface-status) attribute to `"unloaded"`, Set its internal
 [`[[FontStatusPromise]]`](#dom-fontface-fontstatuspromise-slot) slot to a fresh pending
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) object.

 [Parse](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) the
 [`family`](#dom-fontface-fontface-family-source-descriptors-family) argument, and the members of the
 [`descriptors`](#dom-fontface-fontface-family-source-descriptors-descriptors) argument, according to the grammars
 of the corresponding descriptors of the CSS
 [\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule) rule. If the
 [`source`](#dom-fontface-fontface-family-source-descriptors-source) argument is a
 [`CSSOMString`](https://drafts.csswg.org/cssom-1/#cssomstring), parse it according to the grammar of the CSS
 [src] descriptor of the
 [\@font-face] rule. If any of them
 fail to parse correctly, reject `font face’s`
 [`[[FontStatusPromise]]`](#dom-fontface-fontstatuspromise-slot) with a DOMException named \"SyntaxError\", set
 `font face’s` corresponding attributes to the empty
 string, and set `font face’s`
 [`status`](#dom-fontface-status) attribute to \"error\". Otherwise, set
 `font face’s` corresponding attributes to the
 serialization of the parsed values.

 Note that this means that passing a naked url as
 the source argument, like `"http://example.com/myFont.woff"`, won't
 work - it needs to be at least wrapped in a
 [url()](https://drafts.csswg.org/css-values-4/#funcdef-url) function, like
 `"url(http://example.com/myFont.woff)"`. In return for this
 inconvenience, you get to specify multiple fallbacks, specify the
 type of font each fallback is, and refer to local fonts easily.

 (#issue-65bdbf2d) Need to define the base url, so
 relative urls can resolve. Should it be the url of the document? Is
 that correct for workers too, or should they use their worker url?
 Is that always defined?

 Return `font face`. If `font face’s`
 [`status`](#dom-fontface-status) is \"error\", terminate this algorithm; otherwise,
 complete the rest of these steps asynchronously.

2. If the
 [`source`](#dom-fontface-fontface-family-source-descriptors-source) argument was a
 [`CSSOMString`](https://drafts.csswg.org/cssom-1/#cssomstring), set `font face’s` internal
 [`[[Urls]]`](#dom-fontface-urls-slot) slot to the string.

 If the
 [`source`](#dom-fontface-fontface-family-source-descriptors-source) argument was a
 [`BufferSource`](https://webidl.spec.whatwg.org/#BufferSource), set `font face’s` internal
 [`[[Data]]`](#dom-fontface-data-slot) slot to the passed argument.

3. If `font face’s`
 [`[[Data]]`](#dom-fontface-data-slot) slot is not `null`, queue a task to run the
 following steps synchronously:

 1. Set `font face’s`
 [`status`](#dom-fontface-status) attribute to \"loading\".

 2. For each
 [`FontFaceSet`](#fontfaceset) `font face` is in:

 1. If the
 [`FontFaceSet`](#fontfaceset)'s
 [`[[LoadingFonts]]`](#dom-fontfaceset-loadingfonts-slot) list is empty, [switch the FontFaceSet to
 loading](#switch-the-fontfaceset-to-loading).

 2. Append `font face` to the
 [`FontFaceSet`](#fontfaceset)'s
 [`[[LoadingFonts]]`](#dom-fontfaceset-loadingfonts-slot) list.

 Asynchronously, attempt to parse the data in it as a font. When this
 is completed, successfully or not, queue a task to run the following
 steps synchronously:

 1. If the load was successful, `font face` now
 represents the parsed font; fulfill `font face’s`
 [`[[FontStatusPromise]]`](#dom-fontface-fontstatuspromise-slot) with `font face`, and set its
 [`status`](#dom-fontface-status) attribute to \"loaded\".

 For each
 [`FontFaceSet`](#fontfaceset) `font face` is in:

 1. Add `font face` to the
 [`FontFaceSet`](#fontfaceset)'s
 [`[[LoadedFonts]]`](#dom-fontfaceset-loadedfonts-slot) list.

 2. Remove `font face` from the
 [`FontFaceSet`](#fontfaceset)'s
 [`[[LoadingFonts]]`](#dom-fontfaceset-loadingfonts-slot) list. If `font` was the last
 item in that list (and so the list is now empty), [switch
 the FontFaceSet to
 loaded](#switch-the-fontfaceset-to-loaded).

 2. Otherwise, reject `font face’s`
 [`[[FontStatusPromise]]`](#dom-fontface-fontstatuspromise-slot) with a DOMException named \"SyntaxError\" and
 set `font face’s`
 [`status`](#dom-fontface-status) attribute to \"error\".

 For each
 [`FontFaceSet`](#fontfaceset) `font face` is in:

 1. Add `font face` to the
 [`FontFaceSet`](#fontfaceset)'s
 [`[[FailedFonts]]`](#dom-fontfaceset-failedfonts-slot) list.

 2. Remove `font face` from the
 [`FontFaceSet`](#fontfaceset)'s
 [`[[LoadingFonts]]`](#dom-fontfaceset-loadingfonts-slot) list. If `font` was the last
 item in that list (and so the list is now empty), [switch
 the FontFaceSet to
 loaded](#switch-the-fontfaceset-to-loaded).

 Newly constructed FontFace objects are not
automatically added to the FontFaceSet associated with a document or a
context for a worker thread. This means that while newly constructed
fonts can be preloaded, they cannot actually be used until they are
explicitly added to a FontFaceSet. See the following section for a more
complete description of FontFaceSet.

### 2.2. The `load()` method

The [`load()`](#dom-fontface-load) method of
[`FontFace`](#fontface) forces
a url-based font face to request its font data and load. For fonts
constructed from a buffer source, or fonts that are already loading or
loaded, it does nothing.

When the [`load()`] method is called,
execute these steps:

1. Let `font face` be the
 [`FontFace`](#fontface)
 object on which this method was called.
2. If `font face’s`
 [`[[Urls]]`](#dom-fontface-urls-slot) slot is `null`, or its
 [`status`](#dom-fontface-status) attribute is anything other than `"unloaded"`,
 return `font face’s`
 [`[[FontStatusPromise]]`](#dom-fontface-fontstatuspromise-slot) and abort these steps.
3. Otherwise, set `font face’s`
 [`status`](#dom-fontface-status) attribute to \"loading\", return
 `font face’s`
 [`[[FontStatusPromise]]`](#dom-fontface-fontstatuspromise-slot), and continue executing the rest of this algorithm
 asynchronously.
4. Using the value of `font face’s`
 [`[[Urls]]`](#dom-fontface-urls-slot) slot, attempt to load a font as defined in
 [\[CSS-FONTS-3\]](#biblio-css-fonts-3 "CSS Fonts Module Level 3"),
 as if it was the value of a
 [\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule) rule's [src] descriptor.
5. When the load operation completes, successfully or not, queue a task
 to run the following steps synchronously:
 1. If the attempt to load fails, reject `font face’s`
 [`[[FontStatusPromise]]`](#dom-fontface-fontstatuspromise-slot) with a DOMException whose name is
 \"NetworkError\" and set `font face’s`
 [`status`](#dom-fontface-status) attribute to \"error\".

 For each
 [`FontFaceSet`](#fontfaceset) `font face` is in:

 1. Add `font face` to the
 [`FontFaceSet`](#fontfaceset)'s
 [`[[FailedFonts]]`](#dom-fontfaceset-failedfonts-slot) list.

 2. Remove `font face` from the
 [`FontFaceSet`](#fontfaceset)'s
 [`[[LoadingFonts]]`](#dom-fontfaceset-loadingfonts-slot) list. If `font` was the last
 item in that list (and so the list is now empty), [switch
 the FontFaceSet to
 loaded](#switch-the-fontfaceset-to-loaded).

 2. Otherwise, `font face` now represents the loaded
 font; fulfill `font face’s`
 [`[[FontStatusPromise]]`](#dom-fontface-fontstatuspromise-slot) with `font face` and set
 `font face’s`
 [`status`](#dom-fontface-status) attribute to \"loaded\".

 For each
 [`FontFaceSet`](#fontfaceset) `font face` is in:

 1. Add `font face` to the
 [`FontFaceSet`](#fontfaceset)'s
 [`[[LoadedFonts]]`](#dom-fontfaceset-loadedfonts-slot) list.

 2. Remove `font face` from the
 [`FontFaceSet`](#fontfaceset)'s
 [`[[LoadingFonts]]`](#dom-fontfaceset-loadingfonts-slot) list. If `font` was the last
 item in that list (and so the list is now empty), [switch
 the FontFaceSet to
 loaded](#switch-the-fontfaceset-to-loaded).

User agents can initiate font loads on their own, whenever they
determine that a given font face is necessary to render something on the
page. When this happens, they must act as if they had called the
corresponding [`FontFace`](#fontface)'s
[`load()`](#dom-fontface-load) method described here.

 Some UAs utilize a \"font cache\" which avoids having
to download the same font multiple times on a page or on multiple pages
within the same origin. Multiple
[`FontFace`](#fontface)
objects can be mapped to the same entry in the font cache, which means
that a [`FontFace`](#fontface) object might start loading unexpectedly, even if it's
not in a [`FontFaceSet`](#fontfaceset), because some other
[`FontFace`](#fontface)
object pointing to the same font data (perhaps on a different page
entirely!) has been loaded.

Tests

- [empty-family-load.html](https://wpt.fyi/results/css/css-font-loading/empty-family-load.html "css/css-font-loading/empty-family-load.html")
 [[(live
 test)]](http://wpt.live/css/css-font-loading/empty-family-load.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-font-loading/empty-family-load.html)
- [font-face-reject.html](https://wpt.fyi/results/css/css-font-loading/font-face-reject.html "css/css-font-loading/font-face-reject.html")
 [[(live
 test)]](http://wpt.live/css/css-font-loading/font-face-reject.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-font-loading/font-face-reject.html)
- [fontface-load-in-modal-dialog.html](https://wpt.fyi/results/css/css-font-loading/fontface-load-in-modal-dialog.html "css/css-font-loading/fontface-load-in-modal-dialog.html")
 [[(live
 test)]](http://wpt.live/css/css-font-loading/fontface-load-in-modal-dialog.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-font-loading/fontface-load-in-modal-dialog.html)

### [2.3. ][ Interaction with CSS's [\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule) Rule]
A CSS
[\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule) rule automatically defines a corresponding
[`FontFace`](#fontface)
object, which is automatically placed in the document's [font
source](#font-source) when the
rule is parsed. This [`FontFace`](#fontface) object is [CSS-connected].

The [`FontFace`](#fontface)
object corresponding to a
[\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule) rule has its
[`family`](#dom-fontface-family),
[`style`](#dom-fontface-style),
[`weight`](#dom-fontface-weight),
[`width`](#dom-fontface-width),
[`unicodeRange`](#dom-fontface-unicoderange),
[`variant`](#dom-fontface-variant), and
[`featureSettings`](#dom-fontface-featuresettings) attributes set to the same value as the corresponding
descriptors in the [\@font-face]
rule. There is a two-way connection between the two: any change made to
a [\@font-face] descriptor is
immediately reflected in the corresponding
[`FontFace`](#fontface)
attribute, and vice versa.

When a FontFace is transferred between
documents, it's no longer CSS-connected.

The internal
[`[[Urls]]`](#dom-fontface-urls-slot) slot of the
[`FontFace`](#fontface)
object is set to the value of the
[\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule) rule's [src] descriptor, and reflects any changes made to the
[src] descriptor.

Otherwise, a [`FontFace`](#fontface) object created by a CSS
[\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule) rule is identical to one created manually.

If a
[\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule) rule is removed from the document, its
corresponding [`FontFace`](#fontface) object is no longer
[CSS-connected](#css-connected).
The connection is not restorable by any means (but adding the
[\@font-face] back to the stylesheet
will create a brand new
[`FontFace`](#fontface)
object which *is* [CSS-connected]).

If a
[\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule) rule has its
[src](https://drafts.csswg.org/css-fonts-4/#descdef-font-face-src) descriptor changed to a new value, the
original connected [`FontFace`](#fontface) object must stop being
[CSS-connected](#css-connected). A new
[`FontFace`](#fontface)
reflecting its new [src] must
be created and [CSS-connected] to the
[\@font-face]. (This will also remove
the old and add the new
[`FontFace`](#fontface)
objects from any [font sources](#font-source) they appear in.)

Tests

- [nonexistent-file-url.html](https://wpt.fyi/results/css/css-font-loading/nonexistent-file-url.html "css/css-font-loading/nonexistent-file-url.html")
 [[(live
 test)]](http://wpt.live/css/css-font-loading/nonexistent-file-url.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-font-loading/nonexistent-file-url.html)

### 2.4. Discovery of information about a font

A [`FontFace`](#fontface)
object includes a variety of read-only information about the contents of
the font file.

```
[Exposed=(Window,Worker)]
interface FontFaceFeatures {
 /* The CSSWG is still discussing what goes in here */
};

[Exposed=(Window,Worker)]
interface FontFaceVariationAxis {
 readonly attribute DOMString name;
 readonly attribute DOMString axisTag;
 readonly attribute double minimumValue;
 readonly attribute double maximumValue;
 readonly attribute double defaultValue;
};

[Exposed=(Window,Worker)]
interface FontFaceVariations {
 readonly setlike<FontFaceVariationAxis>;
};

[Exposed=(Window,Worker)]
interface FontFacePalette {
 iterable<DOMString>;
 readonly attribute unsigned long length;
 getter DOMString (unsigned long index);
 readonly attribute boolean usableWithLightBackground;
 readonly attribute boolean usableWithDarkBackground;
};

[Exposed=(Window,Worker)]
interface FontFacePalettes {
 iterable<FontFacePalette>;
 readonly attribute unsigned long length;
 getter FontFacePalette (unsigned long index);
};

partial interface FontFace {
 readonly attribute FontFaceFeatures features;
 readonly attribute FontFaceVariations variations;
 readonly attribute FontFacePalettes palettes;
};
```

 This read-only data is intended to help authors know
which values are accepted by
[font-feature-settings](https://drafts.csswg.org/css-fonts-4/#propdef-font-feature-settings),
[font-variation-settings](https://drafts.csswg.org/css-fonts-4/#propdef-font-variation-settings), and
[\@font-palette-values](https://drafts.csswg.org/css-fonts-4/#at-ruledef-font-palette-values).

## 3. The `FontFaceSet` Interface

```
dictionary FontFaceSetLoadEventInit : EventInit {
 sequence<FontFace> fontfaces = ;
};

[Exposed=(Window,Worker)]
interface FontFaceSetLoadEvent : Event {
 constructor(CSSOMString type, optional FontFaceSetLoadEventInit eventInitDict = );
 [SameObject] readonly attribute FrozenArray<FontFace> fontfaces;
};

enum FontFaceSetLoadStatus { "loading", "loaded" };

[Exposed=(Window,Worker)]
interface FontFaceSet : EventTarget {
 setlike<FontFace>;
 FontFaceSet add(FontFace font);
 boolean delete(FontFace font);
 undefined clear();

 // events for when loading state changes
 attribute EventHandler onloading;
 attribute EventHandler onloadingdone;
 attribute EventHandler onloadingerror;

 // check and start loads if appropriate
 // and fulfill promise when all loads complete
 Promise<sequence<FontFace>> load(CSSOMString font, optional CSSOMString text = " ");

 // return whether all fonts in the fontlist are loaded
 // (does not initiate load if not available)
 boolean check(CSSOMString font, optional CSSOMString text = " ");

 // async notification that font loading and layout operations are done
 readonly attribute Promise<FontFaceSet> ready;

 // loading state, "loading" while one or more fonts loading, "loaded" otherwise
 readonly attribute FontFaceSetLoadStatus status;
};
```

Tests

- [fontfaceset-has.html](https://wpt.fyi/results/css/css-font-loading/fontfaceset-has.html "css/css-font-loading/fontfaceset-has.html")
 [[(live
 test)]](http://wpt.live/css/css-font-loading/fontfaceset-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-font-loading/fontfaceset-has.html)
- [fontfacesetloadevent-constructor.html](https://wpt.fyi/results/css/css-font-loading/fontfacesetloadevent-constructor.html "css/css-font-loading/fontfacesetloadevent-constructor.html")
 [[(live
 test)]](http://wpt.live/css/css-font-loading/fontfacesetloadevent-constructor.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-font-loading/fontfacesetloadevent-constructor.html)
- [idlharness.https.html](https://wpt.fyi/results/css/css-font-loading/idlharness.https.html "css/css-font-loading/idlharness.https.html")
 [[(live
 test)]](https://wpt.live/css/css-font-loading/idlharness.https.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-font-loading/idlharness.https.html)

[`ready`], of type Promise\<[FontFaceSet](#fontfaceset)\>, readonly

: This attribute reflects the
 [`FontFaceSet`](#fontfaceset)'s
 [`[[ReadyPromise]]`](#dom-fontfaceset-readypromise-slot) slot.

 See [§ 3.4 The ready attribute](#font-face-set-ready) for more
 details on this
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) and its use.

[iteration order]

: When iterated over, all
 [CSS-connected](#css-connected) [`FontFace`](#fontface) objects must come first, in document order of their
 connected
 [\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule) rules, followed by the
 non-[CSS-connected]
 [`FontFace`](#fontface)
 objects, in insertion order.

[set entries]

: If a [`FontFaceSet`](#fontfaceset) is a [font
 source](#font-source), its
 [set
 entries](https://webidl.spec.whatwg.org/#dfn-set-entries) are initialized as specified in [§ 4.2 Interaction
 with CSS's \@font-face Rule](#document-font-face-set).

 Otherwise, its [set
 entries](https://webidl.spec.whatwg.org/#dfn-set-entries) are initially empty.

[`add(font)`]

: When the
 [`add()`](#dom-fontfaceset-add) method is called, execute the following steps:

 1. If `font` is already in the
 [`FontFaceSet`](#fontfaceset)'s [set
 entries](#fontfaceset-set-entries), skip to the last step of this algorithm
 immediately.

 2. If `font` is
 [CSS-connected](#css-connected), throw an
 [`InvalidModificationError`](https://webidl.spec.whatwg.org/#invalidmodificationerror) exception and exit this algorithm immediately.

 3. Add the `font` argument to the
 [`FontFaceSet`](#fontfaceset)'s [set
 entries](#fontfaceset-set-entries).

 4. If `font`'s
 [`status`](#dom-fontface-status) attribute is \"loading\":

 1. If the
 [`FontFaceSet`](#fontfaceset)'s
 [`[[LoadingFonts]]`](#dom-fontfaceset-loadingfonts-slot) list is empty, [switch the FontFaceSet to
 loading](#switch-the-fontfaceset-to-loading).

 2. Append `font` to the
 [`FontFaceSet`](#fontfaceset)'s
 [`[[LoadingFonts]]`](#dom-fontfaceset-loadingfonts-slot) list.

 5. Return the
 [`FontFaceSet`](#fontfaceset).

 Tests

[`delete(font)`]

: When the
 [`delete()`](#dom-fontfaceset-delete) method is called, execute the following steps:

 1. If `font` is
 [CSS-connected](#css-connected), return `false`
 and exit this algorithm immediately.

 2. Let `deleted` be the result of removing
 `font` from the
 [`FontFaceSet`](#fontfaceset)'s [set
 entries](#fontfaceset-set-entries).

 3. If `font` is present in the
 [`FontFaceSet`](#fontfaceset)'s
 [`[[LoadedFonts]]`](#dom-fontfaceset-loadedfonts-slot), or
 [`[[FailedFonts]]`](#dom-fontfaceset-failedfonts-slot) lists, remove it.

 4. If `font` is present in the
 [`FontFaceSet`](#fontfaceset)'s
 [`[[LoadingFonts]]`](#dom-fontfaceset-loadingfonts-slot) list, remove it. If `font` was the
 last item in that list (and so the list is now empty), [switch
 the FontFaceSet to
 loaded](#switch-the-fontfaceset-to-loaded).

 5. Return `deleted`.

 Tests

 - [fontfaceset-delete-css-connected-2.html](https://wpt.fyi/results/css/css-font-loading/fontfaceset-delete-css-connected-2.html "css/css-font-loading/fontfaceset-delete-css-connected-2.html")
 [[(live
 test)]](http://wpt.live/css/css-font-loading/fontfaceset-delete-css-connected-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-font-loading/fontfaceset-delete-css-connected-2.html)
 - [fontfaceset-delete-css-connected.html](https://wpt.fyi/results/css/css-font-loading/fontfaceset-delete-css-connected.html "css/css-font-loading/fontfaceset-delete-css-connected.html")
 [[(live
 test)]](http://wpt.live/css/css-font-loading/fontfaceset-delete-css-connected.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-font-loading/fontfaceset-delete-css-connected.html)

[`clear()`]

: When the
 [`clear()`](#dom-fontfaceset-clear) method is called, execute the following steps:

 1. Remove all
 non-[CSS-connected](#css-connected) items from the
 [`FontFaceSet`](#fontfaceset)'s [set
 entries](#fontfaceset-set-entries), its
 [`[[LoadedFonts]]`](#dom-fontfaceset-loadedfonts-slot) list, and its
 [`[[FailedFonts]]`](#dom-fontfaceset-failedfonts-slot) list.

 2. If the
 [`FontFaceSet`](#fontfaceset)'s
 [`[[LoadingFonts]]`](#dom-fontfaceset-loadingfonts-slot) list is non-empty, remove all items from it,
 then [switch the FontFaceSet to
 loaded](#switch-the-fontfaceset-to-loaded).

Tests

- [fontfaceset-clear-css-connected-2.html](https://wpt.fyi/results/css/css-font-loading/fontfaceset-clear-css-connected-2.html "css/css-font-loading/fontfaceset-clear-css-connected-2.html")
 [[(live
 test)]](http://wpt.live/css/css-font-loading/fontfaceset-clear-css-connected-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-font-loading/fontfaceset-clear-css-connected-2.html)
- [fontfaceset-clear-css-connected.html](https://wpt.fyi/results/css/css-font-loading/fontfaceset-clear-css-connected.html "css/css-font-loading/fontfaceset-clear-css-connected.html")
 [[(live
 test)]](http://wpt.live/css/css-font-loading/fontfaceset-clear-css-connected.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-font-loading/fontfaceset-clear-css-connected.html)

[`FontFaceSet`](#fontfaceset) objects also have internal
[`[[LoadingFonts]]`], [`[[LoadedFonts]]`], and [`[[FailedFonts]]`] slots, all of which are initialized to empty lists, and a
[`[[ReadyPromise]]`] slot, which is initialized to a fresh pending
[`Promise`](https://webidl.spec.whatwg.org/#idl-promise).

Because font families are loaded only when they are used, content
sometimes needs to understand when the loading of fonts occurs. Authors
can use the events and methods defined here to allow greater control
over actions that are dependent upon the availability of specific fonts.

A [`FontFaceSet`](#fontfaceset) is [pending on the
environment] if any of the following
are true:

- the document is still loading

- the document has pending stylesheet requests

- the document has pending layout operations which might cause the user
 agent to request a font, or which depend on recently-loaded fonts

 The idea is that once a
[`FontFaceSet`](#fontfaceset) stops being [pending on the
environment](#fontfaceset-pending-on-the-environment), as long as nothing further changes the document, an
author can depend on sizes/positions of things being \"correct\" when
measured. If the above conditions do not fully capture this guarantee,
they need to be amended to do so.

### 3.1. Events

Font load events make it easy to respond to the font-loading behavior of
the entire document, rather than having to listen to each font
specifically. The [`loading`]
event fires when the document begins loading fonts, while the
[`loadingdone`] and
[`loadingerror`] events fire
when the document is done loading fonts, containing the fonts that
successfully loaded or failed to load, respectively.

The following are the event handlers (and their corresponding event
handler event types) that must be supported by `FontFaceSet` objects as
IDL attributes:

Event handler

Event handler event type

[`onloading`](#dom-fontfaceset-onloading)

[`loading`](#eventdef-fontfaceset-loading)

[`onloadingdone`](#dom-fontfaceset-onloadingdone)

[`loadingdone`](#eventdef-fontfaceset-loadingdone)

[`onloadingerror`](#dom-fontfaceset-onloadingerror)

[`loadingerror`](#eventdef-fontfaceset-loadingerror)

To [fire a font load event] named `e` at a
[`FontFaceSet`](#fontfaceset) `target` with optional
`font faces` means to [fire a simple
event](https://www.w3.org/TR/html5/webappapis.html#event-firing) named
`e` using the
[`FontFaceSetLoadEvent`](#fontfacesetloadevent) interface that also meets these conditions:

1. The
 [`fontfaces`](#dom-fontfacesetloadevent-fontfaces) attribute is initialized to the result of filtering
 `font faces` to only contain
 [`FontFace`](#fontface)
 objects contained in `target`.

When asked to [switch the FontFaceSet to
loading] for a given
[`FontFaceSet`](#fontfaceset), the user agent must run the following steps:

1. Let `font face set` be the given
 [`FontFaceSet`](#fontfaceset).
2. Set the
 [`status`](#dom-fontfaceset-status) attribute of `font face set` to
 \"loading\".
3. If `font face set’s`
 [`[[ReadyPromise]]`](#dom-fontfaceset-readypromise-slot) slot currently holds a fulfilled promise, replace
 it with a fresh pending promise.
4. Queue a task to [fire a font load
 event](#fire-a-font-load-event) named
 [`loading`](#eventdef-fontfaceset-loading) at `font face set`.

When asked to [switch the FontFaceSet to
loaded] for a given
[`FontFaceSet`](#fontfaceset), the user agent must run the following steps:

1. Let `font face set` be the given
 [`FontFaceSet`](#fontfaceset).

2. If `font face set` is [pending on the
 environment](#fontfaceset-pending-on-the-environment), mark it as [stuck on the
 environment], and exit this
 algorithm.

3. Set `font face set’s`
 [`status`](#dom-fontfaceset-status) attribute to \"loaded\".

4. Fulfill `font face set’s`
 [`[[ReadyPromise]]`](#dom-fontfaceset-readypromise-slot) attribute's value with `font face set`.

5. Queue a task to perform the following steps synchronously:

 1. Let `loaded fonts` be the (possibly empty) contents
 of `font face set’s`
 [`[[LoadedFonts]]`](#dom-fontfaceset-loadedfonts-slot) slot.

 2. Let `failed fonts` be the (possibly empty) contents
 of `font face set’s`
 [`[[FailedFonts]]`](#dom-fontfaceset-failedfonts-slot) slot.

 3. Reset the
 [`[[LoadedFonts]]`](#dom-fontfaceset-loadedfonts-slot) and
 [`[[FailedFonts]]`](#dom-fontfaceset-failedfonts-slot) slots to empty lists.

 4. [Fire a font load
 event](#fire-a-font-load-event) named
 [`loadingdone`](#eventdef-fontfaceset-loadingdone) at `font face set` with
 `loaded fonts`.

 5. If `font face set’s` `failed fonts` is
 non-empty, [fire a font load
 event](#fire-a-font-load-event) named
 [`loadingerror`](#eventdef-fontfaceset-loadingerror) at `font face set` with
 `failed fonts`.

Whenever a [`FontFaceSet`](#fontfaceset) goes from [pending on the
environment](#fontfaceset-pending-on-the-environment) to not [pending on the
environment], the user
agent must run the following steps:

1. If the [`FontFaceSet`](#fontfaceset) is [stuck on the
 environment](#fontfaceset-stuck-on-the-environment) and its
 [`[[LoadingFonts]]`](#dom-fontfaceset-loadingfonts-slot) list is empty, [switch the FontFaceSet to
 loaded](#switch-the-fontfaceset-to-loaded).

2. If the [`FontFaceSet`](#fontfaceset) is [stuck on the
 environment](#fontfaceset-stuck-on-the-environment), unmark it as such.

If asked to [find the matching font faces] from a FontFaceSet
`source`, for a given font string `font`
optionally some sample text `text`, and optionally an
`allow system fonts` flag, run the following steps:

1. Parse `font` using the CSS value syntax of the
 [font](https://drafts.csswg.org/css-fonts-4/#propdef-font) property. If a syntax error
 occurs, return a syntax error.

 If the parsed value is a [CSS-wide
 keyword](https://drafts.csswg.org/css-values-4/#css-wide-keywords), return a syntax error.

 Absolutize all relative lengths against the initial values of the
 corresponding properties. (For example, a relative font weight like
 [bolder](https://drafts.csswg.org/css-fonts-4/#valdef-font-weight-bolder) is evaluated against the initial value
 [normal](https://drafts.csswg.org/css-fonts-4/#valdef-font-weight-normal).)

2. If `text` was not explicitly provided, let it be a string
 containing a single space character (U+0020 SPACE).

3. Let `font family list` be the list of font families
 parsed from `font`, and `font style` be the
 other font style attributes parsed from `font`.

4. Let `available font faces` be the [available font
 faces](#available-font-faces) within `source`. If the
 `allow system fonts` flag is specified, add all system
 fonts to `available font faces`.

5. Let `matched font faces` initially be an empty list.

6. For each family in `font family list`, use the font
 matching rules to select the font faces from
 `available font faces` that match the
 `font style`, and add them to
 `matched font faces`. The use of the
 [`unicodeRange`](#dom-fontface-unicoderange) attribute means that this may be more than just a
 single font face.

7. If `matched font faces` is empty, set the
 `found faces` flag to false. Otherwise, set it to true.

8. For each font face in `matched font faces`, if its
 defined
 [unicode-range](https://drafts.csswg.org/css-fonts-4/#descdef-font-face-unicode-range) does not include the
 codepoint of at least one character in `text`, remove it
 from the list.

 Therefore, if `text` is the empty
 string, every font will be removed.

9. Return `matched font faces` and the
 `found faces` flag.

Tests

- [fontface-loadingevent.html](https://wpt.fyi/results/css/css-font-loading/fontface-loadingevent.html "css/css-font-loading/fontface-loadingevent.html")
 [[(live
 test)]](http://wpt.live/css/css-font-loading/fontface-loadingevent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-font-loading/fontface-loadingevent.html)

### 3.2. The `load()` method

The
[`load()`](#dom-fontfaceset-load) method of
[`FontFaceSet`](#fontfaceset) will determine whether all fonts in the given font list
have been loaded and are available. If any fonts are downloadable fonts
and have not already been loaded, the user agent will initiate the load
of each of these fonts. It returns a Promise, which is fulfilled when
all of the fonts are loaded and ready to be used, or rejected if any
font failed to load properly.

When the [`load`](
[`font`], [`text`] ) method is called, execute these steps:

1. Let `font face set` be the
 [`FontFaceSet`](#fontfaceset) object this method was called on. Let
 `promise` be a newly-created promise object.
2. Return `promise`. Complete the rest of these steps
 asynchronously.
3. [Find the matching font
 faces](#find-the-matching-font-faces) from `font face set` using the
 [`font`](#dom-fontfaceset-load-font-text-font) and
 [`text`](#dom-fontfaceset-load-font-text-text) arguments passed to the function, and let
 `font face list` be the return value (ignoring the
 `found faces` flag). If a syntax error was returned,
 reject `promise` with a SyntaxError exception and
 terminate these steps.
4. Queue a task to run the following steps synchronously:
 1. For all of the font faces in the `font face list`,
 call their
 [`load()`](#dom-fontface-load) method.
 2. Resolve `promise` with the result of waiting for all
 of the
 [`[[FontStatusPromise]]`](#dom-fontface-fontstatuspromise-slot)s of each font face in the
 `font face list`, in order.

Tests

- [fontfaceset-load-css-wide-keywords.html](https://wpt.fyi/results/css/css-font-loading/fontfaceset-load-css-wide-keywords.html "css/css-font-loading/fontfaceset-load-css-wide-keywords.html")
 [[(live
 test)]](http://wpt.live/css/css-font-loading/fontfaceset-load-css-wide-keywords.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-font-loading/fontfaceset-load-css-wide-keywords.html)
- [fontfaceset-load-var.html](https://wpt.fyi/results/css/css-font-loading/fontfaceset-load-var.html "css/css-font-loading/fontfaceset-load-var.html")
 [[(live
 test)]](http://wpt.live/css/css-font-loading/fontfaceset-load-var.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-font-loading/fontfaceset-load-var.html)
- [fontfaceset-no-root-element.html (visual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-font-loading/fontfaceset-no-root-element.html)

### 3.3. The `check()` method

The
[`check()`](#dom-fontfaceset-check) method of
[`FontFaceSet`](#fontfaceset) will determine whether you can \"safely\" render some
provided text with a particular font list, such that it won't cause a
\"font swap\" later. If the given text/font combo will render without
attempting to use any unloaded or currently-loading fonts, this method
will return true; otherwise, it returns false.

Two special cases in this method's behavior should be noted, as they are
non-obvious:

- If the specified fonts exist, but all possible faces are ruled out due
 to their
 [unicode-range](https://drafts.csswg.org/css-fonts-4/#descdef-font-face-unicode-range) not covering the provided text,
 the method returns `true`, as the text will be rendered in the UA's
 fallback font instead, and won't trigger any font loads.

- Likewise, if none of the specified fonts exist (for example, names are
 mis-spelled), the method also returns `true`, because using this font
 list will not trigger any loads; instead, fallback will occur.

When the [`check`](
[`font`], [`text`]) method is called, execute these steps:

1. Let `font face set` be the
 [`FontFaceSet`](#fontfaceset) object this method was called on.
2. [Find the matching font
 faces](#find-the-matching-font-faces) from `font face set` using the
 [`font`](#dom-fontfaceset-check-font-text-font) and
 [`text`](#dom-fontfaceset-check-font-text-text) arguments passed to the function, and including
 system fonts, and let `font face list` be the returned
 list of font faces, and `found faces` be the returned
 `found faces` flag. If a syntax error was returned, throw
 a SyntaxError exception and terminate these steps.
3. If `font face list` is empty, or all fonts in the
 `font face list` either have a
 [`status`](#dom-fontface-status) attribute of \"loaded\" or are system fonts, return
 `true`. Otherwise, return `false`.

### 3.4. The `ready` attribute

Because the number of fonts loaded depends on the how many fonts are
used for a given piece of text, in some cases whether fonts need to be
loaded or not may not be known. The
[`ready`](#dom-fontfaceset-ready) attribute contains a
[`Promise`](https://webidl.spec.whatwg.org/#idl-promise) which is resolved when the document is done loading
fonts, which provides a way for authors to avoid having to keep track of
which fonts have or haven't been loaded before examining content which
may be affected by loading fonts.

 Authors should note that a given
`ready promise` is only fulfilled once, but further fonts may
be loaded after it fulfills. This is similar to listening for a
[`loadingdone`](#eventdef-fontfaceset-loadingdone) event to fire, but the callbacks passed to the
[`ready`](#dom-fontfaceset-ready) promise will **always** get called, even when no font
loads occur because the fonts in question are already loaded. It's a
simple, easy way to synchronize code to font loads without the need to
keep track of what fonts are needed and precisely when they load.

 Note that the user agent may need to iterate over
multiple font loads before the `ready promise` is fulfilled.
This can occur with font fallback situations, where one font in the
fontlist is loaded but doesn't contain a particular glyph and other
fonts in the fontlist need to be loaded. The `ready promise`
is only fulfilled after layout operations complete and no additional
font loads are necessary.

 Note that the Promise returned by this
[`ready`](#dom-fontfaceset-ready) attribute is only ever fulfilled, never rejected,
unlike the Promise returned by the
[`FontFace`](#fontface)
[`load()`](#dom-fontface-load) method.

Tests

- [fontface-fonts-loading.html](https://wpt.fyi/results/css/css-font-loading/fontface-fonts-loading.html "css/css-font-loading/fontface-fonts-loading.html")
 [[(live
 test)]](http://wpt.live/css/css-font-loading/fontface-fonts-loading.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-font-loading/fontface-fonts-loading.html)

### 3.5. Interaction with CSS Font Loading and Matching

When the font matching algorithm in
[\[CSS-FONTS-3\]](#biblio-css-fonts-3 "CSS Fonts Module Level 3")
is run automatically by the user-agent, the set of font faces it matches
over must be precisely the set of fonts in the [font
source](#font-source) for the
document, plus any local font faces.

When a user-agent needs to load a font face, it must do so by calling
the [`load()`](#dom-fontface-load) method of the corresponding
[`FontFace`](#fontface)
object.

(This means it must run the same algorithm, not literally call the value
currently stored in the `load` property of the object.)

Fonts are available when they are
added to a [`FontFaceSet`](#fontfaceset). Adding a new
[\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule) rule to a stylesheet also adds a new
[`FontFace`](#fontface) to
the [`FontFaceSet`](#fontfaceset) of the
[`Document`](https://dom.spec.whatwg.org/#document) object.

Adding a new
[\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule) rule:

``` highlight
document.styleSheets[0].insertRule(
 "@font-face { font-family: newfont; src: url(newfont.woff); }", 0);
document.body.style.fontFamily = "newfont, serif";
```

Constructing a new [`FontFace`](#fontface) object and adding it to `document.fonts`:

``` highlight
var f = new FontFace("newfont", "url(newfont.woff)");
document.fonts.add(f);
document.body.style.fontFamily = "newfont, serif";
```

In both cases, the loading of the font resource "newfont.woff" will be
initiated by the layout engine, just as other
[\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule) rule fonts are loaded.

Omitting the addition to `document.fonts` means the font
would never be loaded and text would be displayed in the default serif
font:

``` highlight
var f = new FontFace("newfont", "url(newtest.woff)", );

/* new {{FontFace}} not added to {{FontFaceSet}},
 so the 'font-family' property can't see it,
 and serif will be used instead */
document.body.style.fontFamily = "newfont, serif";
```

To explicitly preload a font before using it, authors can defer the
addition of a new [`FontFace`](#fontface) to a
[`FontFaceSet`](#fontfaceset) until the load has completed:

``` highlight
var f = new FontFace("newfont", "url(newfont.woff)", );
f.load().then(function (loadedFace) {
 document.fonts.add(loadedFace);
 document.body.style.fontFamily = "newfont, serif";
});
```

In this case, the font resource "newfont.woff" is first downloaded. Once
the download completes, the font is added to the document's
[`FontFaceSet`](#fontfaceset), the body font is changed, and the layout engine uses
the new font resource.

## 4. The `FontFaceSource` Mixin

```
interface mixin FontFaceSource {
 readonly attribute FontFaceSet fonts;
};

Document includes FontFaceSource;
WorkerGlobalScope includes FontFaceSource;
```

Any document, workers, or other context which can use fonts in some
manner must include the
[`FontFaceSource`](#fontfacesource) mixin. The value of the context's
[`fonts`](#dom-fontfacesource-fonts) attribute is its [font source], which provides all of the
fonts used in font-related operations, unless defined otherwise.
Operations referring to "the font source" must be interpreted as
referring to the [font source](#font-source) of the relevant context in which the operation is
taking place.

For any font-related operation that takes place within one of these
contexts, the [`FontFace`](#fontface) objects within the [font
source](#font-source) are its
[available font faces].

### 4.1. Worker FontFaceSources

Within a Worker document, the [font
source](#font-source) is
initially empty.

 [`FontFace`](#fontface) objects can be constructed and added to it as normal,
which affects CSS font-matching within the worker (such as, for example,
drawing text into a
[`OffscreenCanvas`](https://html.spec.whatwg.org/multipage/canvas.html#offscreencanvas)).

Tests

- [fontfaceset-loading-worker-crash.html](https://wpt.fyi/results/css/css-font-loading/fontfaceset-loading-worker-crash.html "css/css-font-loading/fontfaceset-loading-worker-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-font-loading/fontfaceset-loading-worker-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-font-loading/fontfaceset-loading-worker-crash.html)
- [fontfaceset-worker-fontface-crash.html](https://wpt.fyi/results/css/css-font-loading/fontfaceset-worker-fontface-crash.html "css/css-font-loading/fontfaceset-worker-fontface-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-font-loading/fontfaceset-worker-fontface-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-font-loading/fontfaceset-worker-fontface-crash.html)

### [4.2. ][ Interaction with CSS's [\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule) Rule]
The [set
entries](#fontfaceset-set-entries) for a document's [font
source](#font-source) must be
initially populated with all the
[CSS-connected](#css-connected)
[`FontFace`](#fontface)
objects from all of the CSS
[\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule) rules in the [document or shadow root CSS style
sheets](https://drafts.csswg.org/cssom-1/#documentorshadowroot-document-or-shadow-root-css-style-sheets), in document order. As
[\@font-face] rules are added or
removed from a stylesheet, or stylesheets containing
[\@font-face] rules are added or
removed, the corresponding [CSS-connected]
[`FontFace`](#fontface)
objects must be added or removed from the document's [font
source], and maintain this ordering.

Any manually-added [`FontFace`](#fontface) objects must be ordered *after* the
[CSS-connected](#css-connected) ones.

When a [`FontFaceSet`](#fontfaceset) object's
[`add()`](#dom-fontfaceset-add) method is called with a
[CSS-connected](#css-connected) [`FontFace`](#fontface) object, if the object is already in the set, the
operation must be a no-op; otherwise, the operation must do nothing, and
throw an
[`InvalidModificationError`](https://webidl.spec.whatwg.org/#invalidmodificationerror).

When a [`FontFaceSet`](#fontfaceset) object's
[`delete()`](#dom-fontfaceset-delete) method is called with a
[CSS-connected](#css-connected) [`FontFace`](#fontface) object, the operation must be a no-op, and return
`false`.

 Authors can still maintain references to a removed
[`FontFace`](#fontface), even
if it's been automatically removed from a [font
source](#font-source). As
specified in [§ 2.3 Interaction with CSS's \@font-face
Rule](#font-face-css-connection), though, the
[`FontFace`](#fontface) is no
longer [CSS-connected](#css-connected) at that point.

 It is expected that a future version of this
specification will define ways of interacting with and querying local
fonts as well.

Tests

- [fontfaceset-load-css-connected.html](https://wpt.fyi/results/css/css-font-loading/fontfaceset-load-css-connected.html "css/css-font-loading/fontfaceset-load-css-connected.html")
 [[(live
 test)]](http://wpt.live/css/css-font-loading/fontfaceset-load-css-connected.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-font-loading/fontfaceset-load-css-connected.html)
- [fontfaceset-update-after-stylesheet-change.html](https://wpt.fyi/results/css/css-font-loading/fontfaceset-update-after-stylesheet-change.html "css/css-font-loading/fontfaceset-update-after-stylesheet-change.html")
 [[(live
 test)]](http://wpt.live/css/css-font-loading/fontfaceset-update-after-stylesheet-change.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-font-loading/fontfaceset-update-after-stylesheet-change.html)

## 5. API Examples

To show content only after all font
loads complete:

``` highlight
document.fonts.ready.then(function() {
 var content = document.getElementById("content");
 content.style.visibility = "visible";
});
```

Drawing text in a canvas with a
downloadable font, explicitly initiating the font download and drawing
upon completion:

``` highlight
function drawStuff() {
 var ctx = document.getElementById("c").getContext("2d");

 ctx.fillStyle = "red";
 ctx.font = "50px MyDownloadableFont";
 ctx.fillText("Hello!", 100, 100);
}

document.fonts.load("50px MyDownloadableFont")
 .then(drawStuff, handleError);
```

A rich text editing application may
need to measure text elements after editing operations have taken place.
Since style changes may or may not require additional fonts to be
downloaded, or the fonts may already have been downloaded, the
measurement procedures need to occur after those font loads complete:

``` highlight
function measureTextElements() {
 // contents can now be measured using the metrics of
 // the downloadable font(s)
}

function doEditing() {
 // content/layout operations that may cause additional font loads
 document.fonts.ready.then(measureTextElements);
}
```

The
[`loadingdone`](#eventdef-fontfaceset-loadingdone) event only fires after all font related loads have
completed **and** text has been laid out without causing additional font
loads:

``` highlight
<style>
@font-face {
 font-family: latin-serif;
 src: url(latinserif.woff) format("woff"); /* contains no kanji/kana */
}
@font-face {
 font-family: jpn-mincho;
 src: url(mincho.woff) format("woff");
}
@font-face {
 font-family: unused;
 src: url(unused.woff);
}

body { font-family: latin-serif, jpn-mincho; }
</style>
<p>納豆はいかがでしょうか
```

In this situation, the user agent first downloads "latinserif.woff" and
then tries to use this to draw the Japanese text. But because no
Japanese glyphs are present in that font, fallback occurs and the font
"mincho.woff" is downloaded. Only after the second font is downloaded
and the Japanese text laid out does the
[`loadingdone`](#eventdef-fontfaceset-loadingdone) event fire.

The \"unused\" font isn't loaded, but no text is using it, so the UA
isn't even *trying* to load it. It doesn't interfere with the
[`loadingdone`](#eventdef-fontfaceset-loadingdone) event.

## [Changes]
Changes from the [6 April 2023 Working
Draft](https://www.w3.org/TR/2023/WD-css-font-loading-3-20230406/):

- Removed variant attribute, to align with removal of the font-variant
 descriptor in \@font-face.

Changes from the [May 2014 CSS Font Loading Last Call Working
Draft](https://www.w3.org/TR/2014/WD-css-font-loading-3-20140522/):

- Added IDL for discovery of font information.
- Clarified that FontFaceSet.clear() does not clear CSS-connected items.
- Mentioned document.fonts in the introduction.
- Font loading applies to shadow roots as well as documents.
- No longer throw an error if none of the specified fonts exist, because
 this will not trigger any font loading.
- Better alignment with WebIDL.
- Switched to constructor() method syntax.
- Clarified behavior of the matching font faces algorithm if the string
 to match is empty.
- Converted FontFaceSource to a mixin.
- Legacy term CanvasProxy changed to OffscreenCanvas.
- Harmonized FontFace with \@font-face, adding variationSettings and
 fontDisplay.
- Consistently use \[Exposed\] in the IDL.
- Prefer CSSOMString to DOMString
- Better introductory text for check()
- Clarified that layout operations which depend on recently-loaded fonts
 must be allowed to complete.
- Cover more edge cases when firing load events.
- Prefer async event queueing tasks over synchronous calls
- fonts.ready is a property, not a function.
- Differentiated between non-existing fonts, and fonts which exist but
 lack the required glyphs.
- Precisely listed order of steps for several methods
- Clarified handling of global keywords and relative values in the
 load() and check() functions.
- Parsing a src argument is the same as parsing a CSS \@font-face src
 descriptor.
- Clarified that attempting to delete a CSS connected font has no
 effect, and returns false.
- Clarified that adding duplicate fonts has no effect.
- Clarified ordering of manually added FontFace object.
- Clarified that load events only include faces still present in the
 set.
- Added
 [`variationSettings`](#dom-fontface-variationsettings) and
 [`display`](#dom-fontface-display), to sync with
 [\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule).
- Switched
 [`fontfaces`](#dom-fontfacesetloadevent-fontfaces) to be a FrozenArray, to match with proper IDL
 practice.
- Fire loading events and handle promises when a loading font is added
 to a FontFaceSet.
- Corrected the async algorithms to use \"queue a task\" language, to
 ensure that side-effect timing is well-defined.
- Updated several references to latest versions.
- Corrections to the IDL.
- Assorted typos and grammatical errors corrected.

## [ Acknowledgments]
Several members of the Google Fonts team provided helpful feedback on
font load events, as did Boris Zbarsky, Jonas Sicking and ms2ger.

## [ Privacy Considerations]
The [`FontFaceSet`](#fontfaceset) object leaks information about the user's installed
fonts, but in the exact same way as the existing
[\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule) rule; no new information is leaked, or in any
appreciably easier manner.

## [ Security Considerations]
No security considerations have been raised against this specification.
