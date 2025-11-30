::: head
[![W3C](https://www.w3.org/StyleSheets/TR/2021/logos/W3C){crossorigin=""
height="48" width="72"}](https://www.w3.org/){.logo}

# Media Source Extensions™ {#title .title}

[W3C Editor\'s Draft](https://www.w3.org/standards/types#ED) 04 November
2025

More details about this document

This version:
:   [https://w3c.github.io/media-source/](https://w3c.github.io/media-source/){.u-url}

Latest published version:
:   <https://www.w3.org/TR/media-source-2/>

Latest editor\'s draft:
:   <https://w3c.github.io/media-source/>

History:
:   <https://www.w3.org/standards/history/media-source-2/>
:   [Commit history](https://github.com/w3c/media-source/commits/)

Latest Recommendation:
:   <https://www.w3.org/TR/2016/REC-media-source-20161117/>

Editors:
:   [Jean-Yves Avenard](mailto:jya@apple.com){.ed_mailto .u-email .email
    .p-name} ([Apple Inc.](https://www.apple.com/){.p-org .org .h-org})
:   [Mark Watson]{.p-name .fn} ([Netflix
    Inc.](https://www.netflix.com/){.p-org .org .h-org})

Former editors:
:   [Matthew Wolenetz](mailto:matt.wolenetz@gmail.com){.ed_mailto
    .u-email .email .p-name} ([W3C Invited Expert]{.p-org .org
    .h-org}) - Until 01 February 2024
:   [Jerry Smith]{.p-name .fn} ([Microsoft
    Corporation](https://www.microsoft.com/){.p-org .org .h-org}) -
    Until 01 September 2017
:   [Aaron Colwell]{.p-name .fn} ([Google
    Inc.](https://www.google.com/){.p-org .org .h-org}) - Until 01 April
    2015
:   [Adrian Bateman]{.p-name .fn} ([Microsoft
    Corporation](https://www.microsoft.com/){.p-org .org .h-org}) -
    Until 01 April 2015

Feedback:
:   [GitHub w3c/media-source](https://github.com/w3c/media-source/)
    ([pull requests](https://github.com/w3c/media-source/pulls/), [new
    issue](https://github.com/w3c/media-source/issues/new/choose), [open
    issues](https://github.com/w3c/media-source/issues/))
:   [public-media-wg@w3.org](mailto:public-media-wg@w3.org?subject=%5Bmedia-source-2%5D%20YOUR%20TOPIC%20HERE)
    with subject line [\[media-source-2\] *... message topic ...*]{.kbd}
    ([archives](https://lists.w3.org/Archives/Public/public-media-wg){rel="discussion"})

Browser support:
:   [caniuse.com](https://caniuse.com/mediasource)

[Copyright](https://www.w3.org/policies/#copyright) © 2025 [World Wide
Web Consortium](https://www.w3.org/). [W3C]{.abbr
title="World Wide Web Consortium"}^®^
[liability](https://www.w3.org/policies/#Legal_Disclaimer),
[trademark](https://www.w3.org/policies/#W3C_Trademarks) and [permissive
document
license](https://www.w3.org/copyright/software-license-2023/ "W3C Software and Document Notice and License"){rel="license"}
rules apply.

------------------------------------------------------------------------
:::

::: {#abstract .section .introductory}
## Abstract

This specification extends
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"} \[[HTML](#bib-html "HTML Standard"){.bibref
link-type="biblio"}\] to allow JavaScript to generate media streams for
playback. Allowing JavaScript to generate streams facilitates a variety
of use cases like adaptive streaming and time shifting live streams.
:::

::: {#sotd .section .introductory}
## Status of This Document

*This section describes the status of this document at the time of its
publication. A list of current [W3C]{.abbr
title="World Wide Web Consortium"} publications and the latest revision
of this technical report can be found in the [[W3C]{.abbr
title="World Wide Web Consortium"} standards and drafts
index](https://www.w3.org/TR/).*

On top of editorial updates, substantive changes since publication as a
[W3C]{.abbr title="World Wide Web Consortium"} Recommendation in
[November 2016](https://www.w3.org/TR/2016/REC-media-source-20161117/)
are:

- the addition of a
  [`changeType`](#dom-sourcebuffer-changetype){#ref-for-dom-sourcebuffer-changetype-1
  .internalDFN link-type="idl" lt="changeType()"}`()` method to switch
  among codecs or bytestreams
- the possibility to create and use
  [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-1
  .internalDFN link-type="idl" lt="MediaSource"} objects off the main
  thread in dedicated workers
- the removal of the
  [`createObjectURL`](https://www.w3.org/TR/FileAPI/#dfn-createObjectURL){link-type="method"
  lt="createObjectURL()"}`()` extension to the
  [`URL`](https://url.spec.whatwg.org/#url){link-type="interface"
  lt="URL"} object following its integration in the File API
  \[[FILEAPI](#bib-fileapi "File API"){.bibref link-type="biblio"}\]
- the addition of
  [`ManagedMediaSource`](#dom-managedmediasource){#ref-for-dom-managedmediasource-1
  .internalDFN link-type="idl" lt="ManagedMediaSource"},
  [`ManagedSourceBuffer`](#dom-managedsourcebuffer){#ref-for-dom-managedsourcebuffer-1
  .internalDFN link-type="idl" lt="ManagedSourceBuffer"}, and
  [`BufferedChangeEvent`](#dom-bufferedchangeevent){#ref-for-dom-bufferedchangeevent-1
  .internalDFN link-type="idl" lt="BufferedChangeEvent"} interfaces
  supporting power-efficient streaming and active buffered media cleanup
  by the user agent

For a full list of changes made since the previous version, see the
[commits](https://github.com/w3c/media-source/commits/main).

The working group maintains [a list of all bug reports that the editors
have not yet tried to
address](https://github.com/w3c/media-source/issues).

Implementors should be aware that this specification is not stable.
**Implementors who are not taking part in the discussions are likely to
find the specification changing out from under them in incompatible
ways.** Vendors interested in implementing this specification before it
eventually reaches the Candidate Recommendation stage should track the
[GitHub repository](https://github.com/w3c/media-source) and take part
in the discussions.

This document was published by the [Media Working
Group](https://www.w3.org/groups/wg/media) as an Editor\'s Draft.

Publication as an Editor\'s Draft does not imply endorsement by
[W3C]{.abbr title="World Wide Web Consortium"} and its Members.

This is a draft document and may be updated, replaced, or obsoleted by
other documents at any time. It is inappropriate to cite this document
as other than a work in progress.

This document was produced by a group operating under the [[W3C]{.abbr
title="World Wide Web Consortium"} Patent
Policy](https://www.w3.org/policies/patent-policy/). [W3C]{.abbr
title="World Wide Web Consortium"} maintains a [public list of any
patent
disclosures](https://www.w3.org/groups/wg/media/ipr){rel="disclosure"}
made in connection with the deliverables of the group; that page also
includes instructions for disclosing a patent. An individual who has
actual knowledge of a patent that the individual believes contains
[Essential
Claim(s)](https://www.w3.org/policies/patent-policy/#def-essential) must
disclose the information in accordance with [section 6 of the
[W3C]{.abbr title="World Wide Web Consortium"} Patent
Policy](https://www.w3.org/policies/patent-policy/#sec-Disclosure).

This document is governed by the [18 August 2025 [W3C]{.abbr
title="World Wide Web Consortium"} Process
Document](https://www.w3.org/policies/process/20250818/){#w3c_process_revision}.
:::

## Table of Contents {#table-of-contents .introductory}

1.  [Abstract](#abstract){.tocxref}
2.  [Status of This Document](#sotd){.tocxref}
3.  [1. Introduction](#introduction){.tocxref}
    1.  [1.1 Goals](#goals){.tocxref}
4.  [2. Definitions](#definitions){.tocxref}
5.  [3. [`MediaSource`]{export="" dfn-type="interface" idl="interface"
    data-title="MediaSource" dfn-for=""}
    interface](#mediasource){.tocxref}
    1.  [3.1 [`handle`]{export="" dfn-type="attribute" idl="attribute"
        data-title="handle" dfn-for="MediaSource"
        data-type="MediaSourceHandle" lt="handle"
        local-lt="MediaSource.handle"}
        attribute](#handle-attribute){.tocxref}
    2.  [3.2 [`sourceBuffers`]{export="" dfn-type="attribute"
        idl="attribute" data-title="sourceBuffers" dfn-for="MediaSource"
        data-type="SourceBufferList" lt="sourceBuffers"
        local-lt="MediaSource.sourceBuffers"}
        attribute](#sourcebuffers-attribute){.tocxref}
    3.  [3.3 [`activeSourceBuffers`]{export="" dfn-type="attribute"
        idl="attribute" data-title="activeSourceBuffers"
        dfn-for="MediaSource" data-type="SourceBufferList"
        lt="activeSourceBuffers"
        local-lt="MediaSource.activeSourceBuffers"}
        attribute](#activesourcebuffers-attribute){.tocxref}
    4.  [3.4 [`readyState`]{export="" dfn-type="attribute"
        idl="attribute" data-title="readyState" dfn-for="MediaSource"
        data-type="ReadyState" lt="readyState"
        local-lt="MediaSource.readyState"}
        attribute](#readystate-attribute){.tocxref}
    5.  [3.5 [`duration`]{export="" dfn-type="attribute" idl="attribute"
        data-title="duration" dfn-for="MediaSource"
        data-type="unrestricted double" lt="duration"
        local-lt="MediaSource.duration"}
        attribute](#duration-attribute){.tocxref}
    6.  [3.6 [`canConstructInDedicatedWorker`]{export=""
        dfn-type="attribute" idl="attribute"
        data-title="canConstructInDedicatedWorker" dfn-for="MediaSource"
        data-type="boolean" lt="canConstructInDedicatedWorker"
        local-lt="MediaSource.canConstructInDedicatedWorker"}
        attribute](#canconstructindedicatedworker-attribute){.tocxref}
    7.  [3.7 [`addSourceBuffer()`]{export="" dfn-type="method"
        idl="operation" data-title="addSourceBuffer()"
        dfn-for="MediaSource" data-type="SourceBuffer"
        lt="addSourceBuffer()|addSourceBuffer(type)"
        local-lt="MediaSource.addSourceBuffer|MediaSource.addSourceBuffer()|addSourceBuffer"}
        method](#addsourcebuffer-method){.tocxref}
    8.  [3.8 [`removeSourceBuffer()`]{export="" dfn-type="method"
        idl="operation" data-title="removeSourceBuffer()"
        dfn-for="MediaSource" data-type="undefined"
        lt="removeSourceBuffer()|removeSourceBuffer(sourceBuffer)"
        local-lt="MediaSource.removeSourceBuffer|MediaSource.removeSourceBuffer()|removeSourceBuffer"}
        method](#removesourcebuffer-method){.tocxref}
    9.  [3.9 [`endOfStream()`]{export="" dfn-type="method"
        idl="operation" data-title="endOfStream()" dfn-for="MediaSource"
        data-type="undefined" lt="endOfStream()|endOfStream(error)"
        local-lt="MediaSource.endOfStream|MediaSource.endOfStream()|endOfStream"}
        method](#endofstream-method){.tocxref}
    10. [3.10 [`setLiveSeekableRange()`]{export="" dfn-type="method"
        idl="operation" data-title="setLiveSeekableRange()"
        dfn-for="MediaSource" data-type="undefined"
        lt="setLiveSeekableRange()|setLiveSeekableRange(start, end)"
        local-lt="MediaSource.setLiveSeekableRange|MediaSource.setLiveSeekableRange()|setLiveSeekableRange"}
        method](#setliveseekablerange-method){.tocxref}
    11. [3.11 [`clearLiveSeekableRange()`]{export="" dfn-type="method"
        idl="operation" data-title="clearLiveSeekableRange()"
        dfn-for="MediaSource" data-type="undefined"
        lt="clearLiveSeekableRange()"
        local-lt="MediaSource.clearLiveSeekableRange|MediaSource.clearLiveSeekableRange()|clearLiveSeekableRange"}
        method](#clearliveseekablerange-method){.tocxref}
    12. [3.12 [`isTypeSupported()`]{export="" dfn-type="method"
        idl="operation" data-title="isTypeSupported()"
        dfn-for="MediaSource" data-type="boolean"
        lt="isTypeSupported()|isTypeSupported(type)"
        local-lt="MediaSource.isTypeSupported|MediaSource.isTypeSupported()|isTypeSupported"}
        method](#istypesupported-method){.tocxref}
    13. [3.13 Event Summary](#mediasource-events){.tocxref}
    14. [3.14 Cross-context communication
        model](#mediasource-in-worker-communication-model){.tocxref}
    15. [3.15 Algorithms](#mediasource-algorithms){.tocxref}
        1.  [3.15.1 Attaching to a media
            element](#mediasource-attach){.tocxref}
        2.  [3.15.2 Detaching from a media
            element](#mediasource-detach){.tocxref}
        3.  [3.15.3 Seeking](#mediasource-seeking){.tocxref}
        4.  [3.15.4 SourceBuffer
            Monitoring](#buffer-monitoring){.tocxref}
        5.  [3.15.5 Changes to selected/enabled track
            state](#active-source-buffer-changes){.tocxref}
        6.  [3.15.6 Duration
            change](#duration-change-algorithm){.tocxref}
        7.  [3.15.7 End of stream](#end-of-stream-algorithm){.tocxref}
        8.  [3.15.8 Mirror if
            necessary](#mirror-if-necessary-algorithm){.tocxref}
6.  [4. [`MediaSourceHandle`]{export="" dfn-type="interface"
    idl="interface" data-title="MediaSourceHandle" dfn-for=""}
    interface](#mediasourcehandle){.tocxref}
    1.  [4.1 Transfer](#transfer){.tocxref}
7.  [5. [`SourceBuffer`]{export="" dfn-type="interface" idl="interface"
    data-title="SourceBuffer" dfn-for=""}
    interface](#sourcebuffer){.tocxref}
    1.  [5.1 Attributes](#attributes){.tocxref}
    2.  [5.2 Methods](#methods){.tocxref}
    3.  [5.3 Track Buffers](#track-buffers){.tocxref}
    4.  [5.4 Event Summary](#sourcebuffer-events){.tocxref}
    5.  [5.5 Algorithms](#sourcebuffer-algorithms){.tocxref}
        1.  [5.5.1 Segment Parser
            Loop](#sourcebuffer-segment-parser-loop){.tocxref}
        2.  [5.5.2 Reset Parser
            State](#sourcebuffer-reset-parser-state){.tocxref}
        3.  [5.5.3 [Append
            Error]{export=""}](#sourcebuffer-append-error){.tocxref}
        4.  [5.5.4 Prepare
            Append](#sourcebuffer-prepare-append){.tocxref}
        5.  [5.5.5 Buffer Append](#sourcebuffer-buffer-append){.tocxref}
        6.  [5.5.6 Range Removal](#sourcebuffer-range-removal){.tocxref}
        7.  [5.5.7 Initialization Segment
            Received](#sourcebuffer-init-segment-received){.tocxref}
        8.  [5.5.8 [Coded Frame
            Processing]{export=""}](#sourcebuffer-coded-frame-processing){.tocxref}
        9.  [5.5.9 Coded Frame
            Removal](#sourcebuffer-coded-frame-removal){.tocxref}
        10. [5.5.10 Coded Frame
            Eviction](#sourcebuffer-coded-frame-eviction){.tocxref}
        11. [5.5.11 Audio Splice
            Frame](#sourcebuffer-audio-splice-frame-algorithm){.tocxref}
        12. [5.5.12 Audio Splice
            Rendering](#sourcebuffer-audio-splice-rendering-algorithm){.tocxref}
        13. [5.5.13 Text Splice
            Frame](#sourcebuffer-text-splice-frame-algorithm){.tocxref}
8.  [6. [`SourceBufferList`]{export="" dfn-type="interface"
    idl="interface" data-title="SourceBufferList" dfn-for=""}
    interface](#sourcebufferlist){.tocxref}
    1.  [6.1 Attributes](#attributes-0){.tocxref}
    2.  [6.2 Methods](#methods-0){.tocxref}
    3.  [6.3 Event Summary](#sourcebufferlist-events){.tocxref}
9.  [7. [`ManagedMediaSource`]{export="" dfn-type="interface"
    idl="interface" data-title="ManagedMediaSource" dfn-for=""}
    interface](#managedmediasource-interface){.tocxref}
    1.  [7.1 Attributes](#attributes-1){.tocxref}
    2.  [7.2 Event Summary](#event-summary){.tocxref}
    3.  [7.3 Algorithms](#algorithms){.tocxref}
        1.  [7.3.1 `ManagedSourceBuffer`
            Monitoring](#managedsourcebuffer-monitoring){.tocxref}
        2.  [7.3.2 [Memory
            Cleanup]{dfn-for="ManagedMediaSource"}](#memory-cleanup){.tocxref}
10. [8. [`BufferedChangeEvent`]{export="" dfn-type="interface"
    idl="interface" data-title="BufferedChangeEvent" dfn-for=""}
    interface](#bufferedchangeevent-interface){.tocxref}
    1.  [8.1 Attributes](#attributes-2){.tocxref}
11. [9. [`ManagedSourceBuffer`]{export="" dfn-type="interface"
    idl="interface" data-title="ManagedSourceBuffer" dfn-for=""}
    interface](#managedsourcebuffer-interface){.tocxref}
    1.  [9.1 Attributes](#attributes-3){.tocxref}
    2.  [9.2 Event Summary](#event-summary-0){.tocxref}
    3.  [9.3 Algorithms](#algorithms-0){.tocxref}
        1.  [9.3.1 Buffered Change](#buffered-change){.tocxref}
        2.  [9.3.2 [Memory
            cleanup]{dfn-for="ManagedSourceBuffer"}](#memory-cleanup-0){.tocxref}
12. [10. HTMLMediaElement
    Extensions](#htmlmediaelement-extensions){.tocxref}
    1.  [10.1 [`HTMLMediaElement`]{.formerLink xref-type="_IDL_"
        link-type="interface" lt="HTMLMediaElement" data-cite="html"
        cite-path="/media.html" cite-frag="htmlmediaelement"}\'s
        [`seekable`]{.formerLink link-type="attribute"
        xref-type="attribute|dict-member|const"
        link-for="HTMLMediaElement" xref-for="HTMLMediaElement"
        data-cite="html" cite-path="/media.html"
        cite-frag="dom-media-seekable"}](#htmlmediaelement-extensions-seekable){.tocxref}
    2.  [10.2 [`HTMLMediaElement`]{.formerLink xref-type="_IDL_"
        link-type="interface" lt="HTMLMediaElement" data-cite="html"
        cite-path="/media.html" cite-frag="htmlmediaelement"}\'s
        [`buffered`]{.formerLink link-type="attribute"
        xref-type="attribute|dict-member|const"
        link-for="HTMLMediaElement" xref-for="HTMLMediaElement"
        data-cite="html" cite-path="/media.html"
        cite-frag="dom-media-buffered"}](#htmlmediaelement-extensions-buffered){.tocxref}
    3.  [10.3 [`HTMLMediaElement`]{.formerLink xref-type="_IDL_"
        link-type="interface" lt="HTMLMediaElement" data-cite="html"
        cite-path="/media.html" cite-frag="htmlmediaelement"}\'s
        [`srcObject`]{.formerLink link-type="attribute"
        xref-type="attribute|dict-member|const"
        link-for="HTMLMediaElement" xref-for="HTMLMediaElement"
        data-cite="html" cite-path="/media.html"
        cite-frag="dom-media-srcobject"}](#htmlmediaelement-extensions-srcobject){.tocxref}
13. [11. `AudioTrack` extensions](#audio-track-extensions){.tocxref}
14. [12. `VideoTrack` extensions](#video-track-extensions){.tocxref}
15. [13. `TextTrack` extensions](#text-track-extensions){.tocxref}
16. [14. [Byte Stream
    Formats]{export=""}](#byte-stream-formats){.tocxref}
17. [15. Conformance](#conformance){.tocxref}
18. [16. Examples](#examples){.tocxref}
    1.  [16.1 Using Media Source
        Extensions](#using-media-source-extensions){.tocxref}
    2.  [16.2 Using a Managed Media
        Source](#using-a-managed-media-source){.tocxref}
19. [17. Acknowledgments](#acknowledgements){.tocxref}
20. [A. VideoPlaybackQuality](#VideoPlaybackQuality){.tocxref}
21. [B. Issue summary](#issue-summary){.tocxref}
22. [C. References](#references){.tocxref}
    1.  [C.1 Normative references](#normative-references){.tocxref}
    2.  [C.2 Informative references](#informative-references){.tocxref}

:::::: {#introduction .section .informative}
::: header-wrapper
## 1. Introduction {#x1-introduction}

[](#introduction){.self-link aria-label="Permalink for Section 1."}
:::

*This section is non-normative.*

This specification allows JavaScript to dynamically construct media
streams for \<audio\> and \<video\>. It defines a MediaSource object
that can serve as a source of media data for an HTMLMediaElement.
MediaSource objects have one or more
[`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-1
.internalDFN link-type="idl" lt="SourceBuffer"} objects. Applications
append data segments to the
[`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-2
.internalDFN link-type="idl" lt="SourceBuffer"} objects, and can adapt
the quality of appended data based on system performance and other
factors. Data from the
[`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-3
.internalDFN link-type="idl" lt="SourceBuffer"} objects is managed as
track buffers for audio, video and text data that is decoded and played.
Byte stream specifications used with these extensions are available in
the byte stream format registry
\[[MSE-REGISTRY](#bib-mse-registry "Media Source Extensions™ Byte Stream Format Registry"){.bibref
link-type="biblio"}\].

<figure id="fig-media-source-pipeline-model-diagram">
<a
href="https://w3c.github.io/media-source/pipeline_model_description.html#pipelinedesc"><img
src="pipeline_model.svg"
alt="Media Source Pipeline Model Diagram" /></a>
<figcaption><a href="#fig-media-source-pipeline-model-diagram"
class="self-link">Figure 1</a> <span class="fig-title"> Media Source
Pipeline Model Diagram </span></figcaption>
</figure>

:::: {#goals .section}
::: header-wrapper
### 1.1 Goals {#x1-1-goals}

[](#goals){.self-link aria-label="Permalink for Section 1.1"}
:::

This specification was designed with the following goals in mind:

- Allow JavaScript to construct media streams independent of how the
  media is fetched.
- Define a splicing and buffering model that facilitates use cases like
  adaptive streaming, ad-insertion, time-shifting, and video editing.
- Minimize the need for media parsing in JavaScript.
- Leverage the browser cache as much as possible.
- Provide requirements for byte stream format specifications.
- Not require support for any particular media format or codec.

This specification defines:

- Normative behavior for user agents to enable interoperability between
  user agents and web applications when processing media data.
- Normative requirements to enable other specifications to define media
  formats to be used within this specification.
::::
::::::

:::: {#definitions .section}
::: header-wrapper
## 2. Definitions {#x2-definitions}

[](#definitions){.self-link aria-label="Permalink for Section 2."}
:::

[Active Track Buffers]{#dfn-active-track-buffers .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"}

:   The [track buffers](#track-buffer){#ref-for-track-buffer-1
    .internalDFN link-type="dfn|abstract-op"} that provide [coded
    frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-1 .internalDFN
    link-type="dfn|abstract-op"} for the
    [`enabled`](https://html.spec.whatwg.org/multipage/media.html#dom-audiotrack-enabled){link-type="attribute"}
    [`audioTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-audiotracks){link-type="attribute"},
    the
    [`selected`](https://html.spec.whatwg.org/multipage/media.html#dom-videotrack-selected){link-type="attribute"}
    [`videoTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-videotracks){link-type="attribute"},
    and the
    [`"showing"`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-showing)
    or
    [`"hidden"`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-hidden)
    [`textTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-texttracks){link-type="attribute"}.
    All these tracks are associated with
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-4
    .internalDFN link-type="idl" lt="SourceBuffer"} objects in the
    [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-1
    .internalDFN link-type="idl"} list.

[Append Window]{#dfn-append-window .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"}

:   A [presentation
    timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-1
    .internalDFN link-type="dfn|abstract-op"} range used to filter out
    [coded frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-2
    .internalDFN link-type="dfn|abstract-op"} while appending. The
    append window represents a single continuous time range with a
    single start time and end time. Coded frames with [presentation
    timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-2
    .internalDFN link-type="dfn|abstract-op"} within this range are
    allowed to be appended to the
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-5
    .internalDFN link-type="idl" lt="SourceBuffer"} while coded frames
    outside this range are filtered out. The append window start and end
    times are controlled by the
    [`appendWindowStart`](#dom-sourcebuffer-appendwindowstart){#ref-for-dom-sourcebuffer-appendwindowstart-1
    .internalDFN link-type="idl"} and
    [`appendWindowEnd`](#dom-sourcebuffer-appendwindowend){#ref-for-dom-sourcebuffer-appendwindowend-1
    .internalDFN link-type="idl"} attributes respectively.

[Coded Frame]{#dfn-coded-frame .dfn .export export="" plurals="coded frames" tabindex="0" aria-haspopup="dialog" dfn-type="dfn"}

:   A unit of media data that has a [presentation
    timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-3
    .internalDFN link-type="dfn|abstract-op"}, a [decode
    timestamp](#dfn-decode-timestamp){#ref-for-dfn-decode-timestamp-1
    .internalDFN link-type="dfn|abstract-op"}, and a [coded frame
    duration](#dfn-coded-frame-duration){#ref-for-dfn-coded-frame-duration-1
    .internalDFN link-type="dfn|abstract-op"}.

[Coded Frame Duration]{#dfn-coded-frame-duration .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"}

:   The duration of a [coded
    frame](#dfn-coded-frame){#ref-for-dfn-coded-frame-3 .internalDFN
    link-type="dfn|abstract-op"}. For video and text, the duration
    indicates how long the video frame or text *SHOULD* be displayed.
    For audio, the duration represents the sum of all the samples
    contained within the coded frame. For example, if an audio frame
    contained 441 samples \@44100Hz the frame duration would be 10
    milliseconds.

[Coded Frame End Timestamp]{#dfn-coded-frame-end-timestamp .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"}

:   The sum of a [coded
    frame](#dfn-coded-frame){#ref-for-dfn-coded-frame-4 .internalDFN
    link-type="dfn|abstract-op"} [presentation
    timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-4
    .internalDFN link-type="dfn|abstract-op"} and its [coded frame
    duration](#dfn-coded-frame-duration){#ref-for-dfn-coded-frame-duration-2
    .internalDFN link-type="dfn|abstract-op"}. It represents the
    [presentation
    timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-5
    .internalDFN link-type="dfn|abstract-op"} that immediately follows
    the coded frame.

[Coded Frame Group]{#dfn-coded-frame-group .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"}

:   A group of [coded
    frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-5 .internalDFN
    link-type="dfn|abstract-op"} that are adjacent and have
    monotonically increasing [decode
    timestamps](#dfn-decode-timestamp){#ref-for-dfn-decode-timestamp-2
    .internalDFN link-type="dfn|abstract-op"} without any gaps.
    Discontinuities detected by the [coded frame
    processing](#dfn-coded-frame-processing){#ref-for-dfn-coded-frame-processing-1
    .internalDFN link-type="dfn|abstract-op"} algorithm and
    [`abort`](#dom-sourcebuffer-abort){#ref-for-dom-sourcebuffer-abort-1
    .internalDFN link-type="idl" lt="abort()"}`()` calls trigger the
    start of a new coded frame group.

[Decode Timestamp]{#dfn-decode-timestamp .dfn plurals="decode timestamps" tabindex="0" aria-haspopup="dialog" dfn-type="dfn"}

:   The decode timestamp indicates the latest time at which the frame
    needs to be decoded assuming instantaneous decoding and rendering of
    this and any dependant frames (this is equal to the [presentation
    timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-6
    .internalDFN link-type="dfn|abstract-op"} of the earliest frame, in
    [presentation
    order](#presentation-order){#ref-for-presentation-order-1
    .internalDFN link-type="dfn|abstract-op"}, that is dependant on this
    frame). If frames can be decoded out of [presentation
    order](#presentation-order){#ref-for-presentation-order-2
    .internalDFN link-type="dfn|abstract-op"}, then the decode timestamp
    *MUST* be present in or derivable from the byte stream. The user
    agent *MUST* run the [append
    error](#dfn-append-error){#ref-for-dfn-append-error-1 .internalDFN
    link-type="dfn|abstract-op"} algorithm if this is not the case. If
    frames cannot be decoded out of [presentation
    order](#presentation-order){#ref-for-presentation-order-3
    .internalDFN link-type="dfn|abstract-op"} and a decode timestamp is
    not present in the byte stream, then the decode timestamp is equal
    to the [presentation
    timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-7
    .internalDFN link-type="dfn|abstract-op"}.

[Initialization Segment]{#dfn-initialization-segment .dfn .export export="" plurals="initialization segments" tabindex="0" aria-haspopup="dialog" dfn-type="dfn"}

:   A sequence of bytes that contain all of the initialization
    information required to decode a sequence of [media
    segments](#dfn-media-segment){#ref-for-dfn-media-segment-1
    .internalDFN link-type="dfn|abstract-op"}. This includes codec
    initialization data, [Track
    ID](#dfn-track-id){#ref-for-dfn-track-id-1 .internalDFN
    link-type="dfn|abstract-op"} mappings for multiplexed segments, and
    timestamp offsets (e.g., edit lists).

    :::: {#issue-container-generatedID .note role="note"}
    ::: {#h-note .note-title .marker role="heading" aria-level="3"}
    Note
    :::

    The [byte stream format
    specifications](#byte-stream-format-specs){#ref-for-byte-stream-format-specs-1
    .internalDFN link-type="dfn|abstract-op"} in the byte stream format
    registry
    \[[MSE-REGISTRY](#bib-mse-registry "Media Source Extensions™ Byte Stream Format Registry"){.bibref
    link-type="biblio"}\] contain format specific examples.
    ::::

[Media Segment]{#dfn-media-segment .dfn .export export="" plurals="media segments" tabindex="0" aria-haspopup="dialog" dfn-type="dfn"}

:   A sequence of bytes that contain packetized & timestamped media data
    for a portion of the [media
    timeline](https://html.spec.whatwg.org/multipage/media.html#media-timeline).
    Media segments are always associated with the most recently appended
    [initialization
    segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-1
    .internalDFN link-type="dfn|abstract-op"}.

    :::: {#issue-container-generatedID-0 .note role="note"}
    ::: {#h-note-0 .note-title .marker role="heading" aria-level="3"}
    Note
    :::

    The [byte stream format
    specifications](#byte-stream-format-specs){#ref-for-byte-stream-format-specs-2
    .internalDFN link-type="dfn|abstract-op"} in the byte stream format
    registry
    \[[MSE-REGISTRY](#bib-mse-registry "Media Source Extensions™ Byte Stream Format Registry"){.bibref
    link-type="biblio"}\] contain format specific examples.
    ::::

[MediaSource object URL]{#mediasource-object-url .dfn plurals="mediasource object urls" tabindex="0" aria-haspopup="dialog" dfn-type="dfn"}

:   A [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-2
    .internalDFN link-type="idl" lt="MediaSource"} object URL is a
    unique [blob
    URL](https://www.w3.org/TR/FileAPI/#blob-url){link-type="dfn"}
    created by
    [`createObjectURL`](https://www.w3.org/TR/FileAPI/#dfn-createObjectURL){link-type="method"
    lt="createObjectURL()"}`()`. It is used to attach a
    [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-3
    .internalDFN link-type="idl" lt="MediaSource"} object to an
    HTMLMediaElement.

    These URLs are the same as a [blob
    URLs](https://www.w3.org/TR/FileAPI/#blob-url){link-type="dfn"},
    except that anything in the definition of that feature that refers
    to
    [`File`](https://www.w3.org/TR/FileAPI/#dfn-file){link-type="interface"
    lt="File"} and
    [`Blob`](https://www.w3.org/TR/FileAPI/#dfn-Blob){link-type="interface"
    lt="Blob"} objects is hereby extended to also apply to
    [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-4
    .internalDFN link-type="idl" lt="MediaSource"} objects.

    The
    [origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin){link-type="dfn"}
    of the MediaSource object URL is the [relevant settings
    object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object){link-type="dfn"}
    of [this](https://webidl.spec.whatwg.org/#this){link-type="dfn"}
    during the call to
    [`createObjectURL`](https://www.w3.org/TR/FileAPI/#dfn-createObjectURL){link-type="method"
    lt="createObjectURL()"}`()`.

    :::: {#issue-container-generatedID-1 .note role="note"}
    ::: {#h-note-1 .note-title .marker role="heading" aria-level="3"}
    Note
    :::

    For example, the
    [origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin){link-type="dfn"}
    of the MediaSource object URL affects the way that the media element
    is [consumed by
    canvas](https://html.spec.whatwg.org/multipage/canvas.html#security-with-canvas-elements).
    ::::

[Parent Media Source]{#parent-media-source .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"}

:   The parent media source of a
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-6
    .internalDFN link-type="idl" lt="SourceBuffer"} object is the
    [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-5
    .internalDFN link-type="idl" lt="MediaSource"} object that created
    it.

[Presentation Start Time]{#presentation-start-time .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"}

:   The presentation start time is the earliest time point in the
    presentation and specifies the initial [playback
    position](https://html.spec.whatwg.org/multipage/media.html#) and
    [earliest possible
    position](https://html.spec.whatwg.org/multipage/media.html#). All
    presentations created using this specification have a presentation
    start time of 0.

    :::: {#issue-container-generatedID-2 .note role="note"}
    ::: {#h-note-2 .note-title .marker role="heading" aria-level="3"}
    Note
    :::

    For the purposes of determining if
    [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
    lt="HTMLMediaElement"}\'s
    [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered){link-type="attribute"}
    contains a
    [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface"
    lt="TimeRanges"} that includes the current playback position,
    implementations *MAY* choose to allow a current playback position at
    or after [presentation start
    time](#presentation-start-time){#ref-for-presentation-start-time-1
    .internalDFN link-type="dfn|abstract-op"} and before the first
    [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface"
    lt="TimeRanges"} to play the first
    [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface"
    lt="TimeRanges"} if that
    [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface"
    lt="TimeRanges"} starts within a reasonably short time, like 1
    second, after [presentation start
    time](#presentation-start-time){#ref-for-presentation-start-time-2
    .internalDFN link-type="dfn|abstract-op"}. This allowance
    accommodates the reality that muxed streams commonly do not begin
    all tracks precisely at [presentation start
    time](#presentation-start-time){#ref-for-presentation-start-time-3
    .internalDFN link-type="dfn|abstract-op"}. Implementations *MUST*
    report the actual buffered range, regardless of this allowance.
    ::::

[Presentation Interval]{#presentation-interval .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"}

:   The presentation interval of a [coded
    frame](#dfn-coded-frame){#ref-for-dfn-coded-frame-6 .internalDFN
    link-type="dfn|abstract-op"} is the time interval from its
    [presentation
    timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-8
    .internalDFN link-type="dfn|abstract-op"} to the [presentation
    timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-9
    .internalDFN link-type="dfn|abstract-op"} plus the [coded frame\'s
    duration](#dfn-coded-frame-duration){#ref-for-dfn-coded-frame-duration-3
    .internalDFN link-type="dfn|abstract-op" lt="coded frame duration"}.
    For example, if a coded frame has a presentation timestamp of 10
    seconds and a [coded frame
    duration](#dfn-coded-frame-duration){#ref-for-dfn-coded-frame-duration-4
    .internalDFN link-type="dfn|abstract-op"} of 100 milliseconds, then
    the presentation interval would be \[10-10.1). Note that the start
    of the range is inclusive, but the end of the range is exclusive.

[Presentation Order]{#presentation-order .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"}

:   The order that [coded
    frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-7 .internalDFN
    link-type="dfn|abstract-op"} are rendered in the presentation. The
    presentation order is achieved by ordering [coded
    frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-8 .internalDFN
    link-type="dfn|abstract-op"} in monotonically increasing order by
    their [presentation
    timestamps](#presentation-timestamp){#ref-for-presentation-timestamp-10
    .internalDFN link-type="dfn|abstract-op"}.

[Presentation Timestamp]{#presentation-timestamp .dfn export="" plurals="presentation timestamps" tabindex="0" aria-haspopup="dialog" dfn-type="dfn"}

:   A reference to a specific time in the presentation. The presentation
    timestamp in a [coded
    frame](#dfn-coded-frame){#ref-for-dfn-coded-frame-9 .internalDFN
    link-type="dfn|abstract-op"} indicates when the frame *SHOULD* be
    rendered.

[Random Access Point]{#random-access-point .dfn export="" tabindex="0" aria-haspopup="dialog" dfn-type="dfn"}

:   A position in a [media
    segment](#dfn-media-segment){#ref-for-dfn-media-segment-2
    .internalDFN link-type="dfn|abstract-op"} where decoding and
    continuous playback can begin without relying on any previous data
    in the segment. For video this tends to be the location of I-frames.
    In the case of audio, most audio frames can be treated as a random
    access point. Since video tracks tend to have a more sparse
    distribution of random access points, the location of these points
    are usually considered the random access points for multiplexed
    streams.

[SourceBuffer byte stream format specification]{#dfn-sourcebuffer-byte-stream-format-specification .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"}

:   The specific [byte stream format
    specification](#byte-stream-format-specs){#ref-for-byte-stream-format-specs-3
    .internalDFN link-type="dfn|abstract-op"} that describes the format
    of the byte stream accepted by a
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-7
    .internalDFN link-type="idl" lt="SourceBuffer"} instance. The [byte
    stream format
    specification](#byte-stream-format-specs){#ref-for-byte-stream-format-specs-4
    .internalDFN link-type="dfn|abstract-op"}, for a
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-8
    .internalDFN link-type="idl" lt="SourceBuffer"} object, is initially
    selected based on the `type`{.variable data-type="DOMString"} passed
    to the
    [`addSourceBuffer`](#dom-mediasource-addsourcebuffer){#ref-for-dom-mediasource-addsourcebuffer-1
    .internalDFN link-type="idl" lt="addSourceBuffer()"}`()` call that
    created the object, and can be updated by
    [`changeType`](#dom-sourcebuffer-changetype){#ref-for-dom-sourcebuffer-changetype-2
    .internalDFN link-type="idl" lt="changeType()"}`()` calls on the
    object.

[`SourceBuffer` configuration]{#dfn-sourcebuffer-configuration .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"}

:   A specific set of tracks distributed across one or more
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-9
    .internalDFN link-type="idl" lt="SourceBuffer"} objects owned by a
    single [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-6
    .internalDFN link-type="idl" lt="MediaSource"} instance.

    Implementations *MUST* support at least 1
    [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-7
    .internalDFN link-type="idl" lt="MediaSource"} object with the
    following configurations:

    - A single SourceBuffer with 1 audio track and/or 1 video track.
    - Two SourceBuffers with one handling a single audio track and the
      other handling a single video track.

    MediaSource objects *MUST* support each of the configurations above,
    but they are only required to support one configuration at a time.
    Supporting multiple configurations at once or additional
    configurations is a quality of implementation issue.

[Track Description]{#dfn-track-description .dfn plurals="track descriptions" tabindex="0" aria-haspopup="dialog" dfn-type="dfn"}

:   A byte stream format specific structure that provides the [Track
    ID](#dfn-track-id){#ref-for-dfn-track-id-2 .internalDFN
    link-type="dfn|abstract-op"}, codec configuration, and other
    metadata for a single track. Each track description inside a single
    [initialization
    segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-2
    .internalDFN link-type="dfn|abstract-op"} has a unique [Track
    ID](#dfn-track-id){#ref-for-dfn-track-id-3 .internalDFN
    link-type="dfn|abstract-op"}. The user agent *MUST* run the [append
    error](#dfn-append-error){#ref-for-dfn-append-error-2 .internalDFN
    link-type="dfn|abstract-op"} algorithm if the [Track
    ID](#dfn-track-id){#ref-for-dfn-track-id-4 .internalDFN
    link-type="dfn|abstract-op"} is not unique within the
    [initialization
    segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-3
    .internalDFN link-type="dfn|abstract-op"}.

[Track ID]{#dfn-track-id .dfn plurals="track ids" tabindex="0" aria-haspopup="dialog" dfn-type="dfn"}

:   A Track ID is a byte stream format specific identifier that marks
    sections of the byte stream as being part of a specific track. The
    Track ID in a [track
    description](#dfn-track-description){#ref-for-dfn-track-description-1
    .internalDFN link-type="dfn|abstract-op"} identifies which sections
    of a [media
    segment](#dfn-media-segment){#ref-for-dfn-media-segment-3
    .internalDFN link-type="dfn|abstract-op"} belong to that track.
::::

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: {#mediasource .section dfn-for="MediaSource"}
::: header-wrapper
## 3. [`MediaSource`]{#dom-mediasource .dfn export="" dfn-type="interface" idl="interface" data-title="MediaSource" dfn-for="" tabindex="0" aria-haspopup="dialog"} interface {#x3-mediasource-interface}

[](#mediasource){.self-link aria-label="Permalink for Section 3."}
:::

The [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-8
.internalDFN link-type="idl" lt="MediaSource"} interface represents a
source of media data for an
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"}. It keeps track of the
[`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-1
.internalDFN link-type="idl"} for this source as well as a list of
[`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-10
.internalDFN link-type="idl"} objects that can be used to add media data
to the presentation. MediaSource objects are created by the web
application and then attached to an HTMLMediaElement. The application
uses the
[`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-11
.internalDFN link-type="idl"} objects in
[`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-1
.internalDFN link-type="idl"} to add media data to this source. The
HTMLMediaElement fetches this media data from the
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-9
.internalDFN link-type="idl"} object when it is needed during playback.

Each [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-10
.internalDFN link-type="idl" lt="MediaSource"} object has a [\[\[live
seekable range\]\]]{#dfn-live-seekable-range .dfn dfn-for="MediaSource"
idl="" noexport="" dfn-type="attribute" tabindex="0"
aria-haspopup="dialog"} internal slot that stores a [normalized
TimeRanges
object](https://html.spec.whatwg.org/multipage/media.html#normalised-timeranges-object).
It is initialized to an empty
[`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface"
lt="TimeRanges"} object when the
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-11
.internalDFN link-type="idl" lt="MediaSource"} object is created, is
maintained by
[`setLiveSeekableRange`](#dom-mediasource-setliveseekablerange){#ref-for-dom-mediasource-setliveseekablerange-1
.internalDFN link-type="idl" lt="setLiveSeekableRange()"}`()` and
[`clearLiveSeekableRange`](#dom-mediasource-clearliveseekablerange){#ref-for-dom-mediasource-clearliveseekablerange-1
.internalDFN link-type="idl" lt="clearLiveSeekableRange()"}`()`, and is
used in [10. HTMLMediaElement
Extensions](#htmlmediaelement-extensions){.sec-ref
matched-text="[[[#htmlmediaelement-extensions]]]"} to modify
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"}\'s
[`seekable`](https://html.spec.whatwg.org/multipage/media.html#dom-media-seekable){link-type="attribute"}
behavior.

Each [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-12
.internalDFN link-type="idl" lt="MediaSource"} object has a [\[\[has
ever been attached\]\]]{#dfn-has-ever-been-attached .dfn
dfn-for="MediaSource" idl="" noexport="" dfn-type="attribute"
tabindex="0" aria-haspopup="dialog"} internal slot that stores a
[`boolean`](https://webidl.spec.whatwg.org/#idl-boolean){link-type="interface"
lt="boolean"}. It is initialized to false when the
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-13
.internalDFN link-type="idl" lt="MediaSource"} object is created, and is
set true in the extended
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"}\'s [resource fetch
algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource){link-type="dfn"}
as described in the [attaching to a media
element](#dfn-attaching-to-a-media-element){#ref-for-dfn-attaching-to-a-media-element-1
.internalDFN link-type="dfn|abstract-op"} algorithm. The extended
[resource fetch
algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource){link-type="dfn"}
uses this internal slot to conditionally fail attachment of a
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-14
.internalDFN link-type="idl" lt="MediaSource"} using a
[`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-1
.internalDFN link-type="idl" lt="MediaSourceHandle"} set on a
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"}\'s
[`srcObject`](https://html.spec.whatwg.org/multipage/media.html#dom-media-srcobject){link-type="attribute"}
attribute.

``` {#webidl-26865842 .idl .def}
WebIDLenum ReadyState {
  "closed",
  "open",
  "ended",
};
```

[`closed`]{#dom-readystate-closed .dfn export="" dfn-type="enum-value" idl="enum-value" data-title="closed" dfn-for="ReadyState" tabindex="0" aria-haspopup="dialog"}
:   Indicates the source is not currently attached to a media element.

[`open`]{#dom-readystate-open .dfn export="" dfn-type="enum-value" idl="enum-value" data-title="open" dfn-for="ReadyState" tabindex="0" aria-haspopup="dialog"}
:   The source has been opened by a media element and is ready for data
    to be appended to the
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-12
    .internalDFN link-type="idl" lt="SourceBuffer"} objects in
    [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-15
    .internalDFN link-type="idl" lt="MediaSource"}\'s
    [`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-2
    .internalDFN link-type="idl"}.

[`ended`]{#dom-readystate-ended .dfn export="" dfn-type="enum-value" idl="enum-value" data-title="ended" dfn-for="ReadyState" tabindex="0" aria-haspopup="dialog"}
:   The source is still attached to a media element, but
    [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-16
    .internalDFN link-type="idl" lt="MediaSource"}\'s
    [`endOfStream`](#dom-mediasource-endofstream){#ref-for-dom-mediasource-endofstream-1
    .internalDFN link-type="idl" lt="endOfStream()"}`()` has been
    called.

:::: {#issue-container-number-276 .issue}
::: {#h-issue .issue-title .marker role="heading" aria-level="3"}
[[Issue
276]{.issue-number}](https://github.com/w3c/media-source/issues/276)[:
MSE-in-Workers: Consider adding a \"closing\" readyState to explain new
\`InvalidStateError\` exception when closing underway
[mse-in-workers](https://github.com/w3c/media-source/issues/?q=is%3Aissue+is%3Aopen+label%3A%22mse-in-workers%22){.respec-gh-label
style="background-color: rgb(170, 170, 170); color: rgb(0, 0, 0);"
aria-label="GitHub label: mse-in-workers"}]{.issue-label}
:::

Consider adding a \"`closing`\"
[`ReadyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-2
.internalDFN link-type="idl"} to indicate the source is in the process
of being concurrently detached from a media element. This would be
useful for some implementations of
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-17
.internalDFN link-type="idl" lt="MediaSource"} and
[`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-13
.internalDFN link-type="idl" lt="SourceBuffer"} in
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
lt="DedicatedWorkerGlobalScope"}.
::::

``` {#webidl-1031259774 .idl .def}
WebIDLenum EndOfStreamError {
  "network",
  "decode",
};
```

[`network`]{#dom-endofstreamerror-network .dfn export="" dfn-type="enum-value" idl="enum-value" data-title="network" dfn-for="EndOfStreamError" tabindex="0" aria-haspopup="dialog"}

:   Terminates playback and signals that a network error has occurred.

    :::: {#issue-container-generatedID-3 .note role="note"}
    ::: {#h-note-3 .note-title .marker role="heading" aria-level="3"}
    Note
    :::

    JavaScript applications *SHOULD* use this status code to terminate
    playback with a network error. For example, if a network error
    occurs while fetching media data.
    ::::

[`decode`]{#dom-endofstreamerror-decode .dfn export="" dfn-type="enum-value" idl="enum-value" data-title="decode" dfn-for="EndOfStreamError" tabindex="0" aria-haspopup="dialog"}

:   Terminates playback and signals that a decoding error has occurred.

    :::: {#issue-container-generatedID-4 .note role="note"}
    ::: {#h-note-4 .note-title .marker role="heading" aria-level="3"}
    Note
    :::

    JavaScript applications *SHOULD* use this status code to terminate
    playback with a decode error. For example, if a parsing error occurs
    while processing out-of-band media data.
    ::::

``` {#webidl-1502719514 .idl .def}
WebIDL[Exposed=(Window,DedicatedWorker)]
interface MediaSource : EventTarget {
    constructor();

    [SameObject, Exposed=DedicatedWorker]
    readonly  attribute MediaSourceHandle handle;
    readonly  attribute SourceBufferList sourceBuffers;
    readonly  attribute SourceBufferList activeSourceBuffers;
    readonly  attribute ReadyState readyState;

    attribute unrestricted double duration;
    attribute EventHandler onsourceopen;
    attribute EventHandler onsourceended;
    attribute EventHandler onsourceclose;

    static readonly attribute boolean canConstructInDedicatedWorker;

    SourceBuffer addSourceBuffer(DOMString type);
    undefined removeSourceBuffer(SourceBuffer sourceBuffer);
    undefined endOfStream(optional EndOfStreamError error);
    undefined setLiveSeekableRange(double start, double end);
    undefined clearLiveSeekableRange();
    static boolean isTypeSupported(DOMString type);
};
```

:::::: {#handle-attribute .section}
::: header-wrapper
### 3.1 [`handle`]{#dom-mediasource-handle .dfn export="" dfn-type="attribute" idl="attribute" data-title="handle" dfn-for="MediaSource" data-type="MediaSourceHandle" lt="handle" local-lt="MediaSource.handle" tabindex="0" aria-haspopup="dialog"} attribute {#x3-1-handle-attribute}

[](#handle-attribute){.self-link aria-label="Permalink for Section 3.1"}
:::

Contains a handle useful for attachment of a dedicated worker
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-19
.internalDFN link-type="idl" lt="MediaSource"} object to an
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"} via
[`srcObject`](https://html.spec.whatwg.org/multipage/media.html#dom-media-srcobject){link-type="attribute"}.
The handle remains the same object for this
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-20
.internalDFN link-type="idl" lt="MediaSource"} object across accesses of
this attribute, but it is distinct for each
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-21
.internalDFN link-type="idl" lt="MediaSource"} object.

:::: {#issue-container-generatedID-5 .note role="note"}
::: {#h-note-5 .note-title .marker role="heading" aria-level="3"}
Note
:::

This specification may eventually enable visibility of this attribute on
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-22
.internalDFN link-type="idl" lt="MediaSource"} objects on the main
Window context. If so, specification care will be necessary to prevent
potential backwards incompatible changes, such as could happen if
exceptions were thrown on accesses to this attribute.
::::

On getting, run the following steps:

1.  If the handle for this
    [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-23
    .internalDFN link-type="idl" lt="MediaSource"} object has not yet
    been created, then run the following steps:
    1.  Let `created handle`{.variable data-type="MediaSourceHandle"} be
        the result of creating a new
        [`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-3
        .internalDFN link-type="idl" lt="MediaSourceHandle"} object and
        associated resources, linked internally to this
        [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-24
        .internalDFN link-type="idl" lt="MediaSource"}.
    2.  Update the attribute to be `created handle`{.variable
        data-type="MediaSourceHandle"}.
2.  Return the
    [`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-4
    .internalDFN link-type="idl" lt="MediaSourceHandle"} object that is
    this attribute\'s value.
::::::

:::: {#sourcebuffers-attribute .section}
::: header-wrapper
### 3.2 [`sourceBuffers`]{#dom-mediasource-sourcebuffers .dfn export="" dfn-type="attribute" idl="attribute" data-title="sourceBuffers" dfn-for="MediaSource" data-type="SourceBufferList" lt="sourceBuffers" local-lt="MediaSource.sourceBuffers" tabindex="0" aria-haspopup="dialog"} attribute {#x3-2-sourcebuffers-attribute}

[](#sourcebuffers-attribute){.self-link
aria-label="Permalink for Section 3.2"}
:::

Contains the list of
[`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-16
.internalDFN link-type="idl" lt="SourceBuffer"} objects associated with
this [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-25
.internalDFN link-type="idl" lt="MediaSource"}. When
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-26
.internalDFN link-type="idl" lt="MediaSource"}\'s
[`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-4
.internalDFN link-type="idl"} equals
\"[`closed`](#dom-readystate-closed){#ref-for-dom-readystate-closed-2
.internalDFN link-type="idl"}\" this list will be empty. Once
[`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-5
.internalDFN link-type="idl"} transitions to
\"[`open`](#dom-readystate-open){#ref-for-dom-readystate-open-2
.internalDFN link-type="idl"}\" SourceBuffer objects can be added to
this list by using
[`addSourceBuffer`](#dom-mediasource-addsourcebuffer){#ref-for-dom-mediasource-addsourcebuffer-3
.internalDFN link-type="idl" lt="addSourceBuffer()"}`()`.
::::

:::::: {#activesourcebuffers-attribute .section}
::: header-wrapper
### 3.3 [`activeSourceBuffers`]{#dom-mediasource-activesourcebuffers .dfn export="" dfn-type="attribute" idl="attribute" data-title="activeSourceBuffers" dfn-for="MediaSource" data-type="SourceBufferList" lt="activeSourceBuffers" local-lt="MediaSource.activeSourceBuffers" tabindex="0" aria-haspopup="dialog"} attribute {#x3-3-activesourcebuffers-attribute}

[](#activesourcebuffers-attribute){.self-link
aria-label="Permalink for Section 3.3"}
:::

Contains the subset of
[`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-4
.internalDFN link-type="idl"} that are providing the
[`selected`](https://html.spec.whatwg.org/multipage/media.html#dom-videotrack-selected){link-type="attribute"}
video track, the
[`enabled`](https://html.spec.whatwg.org/multipage/media.html#dom-audiotrack-enabled){link-type="attribute"}
audio track(s), and the
[`"showing"`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-showing)
or
[`"hidden"`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-hidden)
text track(s).

[`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-17
.internalDFN link-type="idl" lt="SourceBuffer"} objects in this list
*MUST* appear in the same order as they appear in the
[`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-5
.internalDFN link-type="idl"} attribute; e.g., if only
sourceBuffers\[0\] and sourceBuffers\[3\] are in
[`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-3
.internalDFN link-type="idl"}, then activeSourceBuffers\[0\] *MUST*
equal sourceBuffers\[0\] and activeSourceBuffers\[1\] *MUST* equal
sourceBuffers\[3\].

:::: {#issue-container-generatedID-6 .note role="note"}
::: {#h-note-6 .note-title .marker role="heading" aria-level="3"}
Note
:::

Section [3.15.5 Changes to selected/enabled track
state](#active-source-buffer-changes){.sec-ref
matched-text="[[[#active-source-buffer-changes]]]"} describes how this
attribute gets updated.
::::
::::::

:::: {#readystate-attribute .section}
::: header-wrapper
### 3.4 [`readyState`]{#dom-mediasource-readystate .dfn export="" dfn-type="attribute" idl="attribute" data-title="readyState" dfn-for="MediaSource" data-type="ReadyState" lt="readyState" local-lt="MediaSource.readyState" tabindex="0" aria-haspopup="dialog"} attribute {#x3-4-readystate-attribute}

[](#readystate-attribute){.self-link
aria-label="Permalink for Section 3.4"}
:::

Indicates the current state of the
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-27
.internalDFN link-type="idl"} object. When the
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-28
.internalDFN link-type="idl"} is created
[`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-6
.internalDFN link-type="idl"} *MUST* be set to
\"[`closed`](#dom-readystate-closed){#ref-for-dom-readystate-closed-3
.internalDFN link-type="idl"}\".
::::

:::: {#duration-attribute .section}
::: header-wrapper
### 3.5 [`duration`]{#dom-mediasource-duration .dfn export="" dfn-type="attribute" idl="attribute" data-title="duration" dfn-for="MediaSource" data-type="unrestricted double" lt="duration" local-lt="MediaSource.duration" tabindex="0" aria-haspopup="dialog"} attribute {#x3-5-duration-attribute}

[](#duration-attribute){.self-link
aria-label="Permalink for Section 3.5"}
:::

Allows the web application to set the presentation duration. The
duration is initially set to NaN when the
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-29
.internalDFN link-type="idl"} object is created.

On getting, run the following steps:

1.  If the
    [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-7
    .internalDFN link-type="idl"} attribute is
    \"[`closed`](#dom-readystate-closed){#ref-for-dom-readystate-closed-4
    .internalDFN link-type="idl"}\" then return NaN and abort these
    steps.
2.  Return the current value of the attribute.

On setting, run the following steps:

1.  If the value being set is negative or NaN then throw a
    [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror){link-type="exception"
    lt="TypeError"} exception and abort these steps.
2.  If the
    [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-8
    .internalDFN link-type="idl"} attribute is not
    \"[`open`](#dom-readystate-open){#ref-for-dom-readystate-open-3
    .internalDFN link-type="idl"}\" then throw an
    [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror){link-type="exception"
    lt="InvalidStateError"} exception and abort these steps.
3.  If the
    [`updating`](#dom-sourcebuffer-updating){#ref-for-dom-sourcebuffer-updating-1
    .internalDFN link-type="idl"} attribute equals true on any
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-18
    .internalDFN link-type="idl" lt="SourceBuffer"} in
    [`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-6
    .internalDFN link-type="idl"}, then throw an
    [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror){link-type="exception"
    lt="InvalidStateError"} exception and abort these steps.
4.  Run the [duration
    change](#dfn-duration-change){#ref-for-dfn-duration-change-1
    .internalDFN link-type="dfn|abstract-op"} algorithm with
    `new duration`{.variable data-type="unrestricted double"} set to the
    value being assigned to this attribute.

    :::: {#issue-container-generatedID-7 .note role="note"}
    ::: {#h-note-7 .note-title .marker role="heading" aria-level="3"}
    Note
    :::

    The [duration
    change](#dfn-duration-change){#ref-for-dfn-duration-change-2
    .internalDFN link-type="dfn|abstract-op"} algorithm will adjust
    `new duration`{.variable data-type="unrestricted double"} higher if
    there is any currently buffered coded frame with a higher end time.
    ::::

    :::: {#issue-container-generatedID-8 .note role="note"}
    ::: {#h-note-8 .note-title .marker role="heading" aria-level="3"}
    Note
    :::

    [`appendBuffer`](#dom-sourcebuffer-appendbuffer){#ref-for-dom-sourcebuffer-appendbuffer-1
    .internalDFN link-type="idl" lt="appendBuffer()"}`()` and
    [`endOfStream`](#dom-mediasource-endofstream){#ref-for-dom-mediasource-endofstream-3
    .internalDFN link-type="idl" lt="endOfStream()"}`()` can update the
    duration under certain circumstances.
    ::::
::::

:::::: {#canconstructindedicatedworker-attribute .section}
::: header-wrapper
### 3.6 [`canConstructInDedicatedWorker`]{#dom-mediasource-canconstructindedicatedworker .dfn export="" dfn-type="attribute" idl="attribute" data-title="canConstructInDedicatedWorker" dfn-for="MediaSource" data-type="boolean" lt="canConstructInDedicatedWorker" local-lt="MediaSource.canConstructInDedicatedWorker" tabindex="0" aria-haspopup="dialog"} attribute {#x3-6-canconstructindedicatedworker-attribute}

[](#canconstructindedicatedworker-attribute){.self-link
aria-label="Permalink for Section 3.6"}
:::

Returns true.

:::: {#issue-container-generatedID-9 .note role="note"}
::: {#h-note-9 .note-title .marker role="heading" aria-level="3"}
Note
:::

This attribute enables main thread and dedicated worker feature
detection of support for creating and using a
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-30
.internalDFN link-type="idl" lt="MediaSource"} object in a dedicated
worker, and mitigates the need for higher latency detection polyfills
like attempting creation of a
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-31
.internalDFN link-type="idl" lt="MediaSource"} object from a dedicated
worker, especially if the feature is not supported.
::::
::::::

:::: {#addsourcebuffer-method .section}
::: header-wrapper
### 3.7 [`addSourceBuffer()`]{#dom-mediasource-addsourcebuffer .dfn export="" dfn-type="method" idl="operation" data-title="addSourceBuffer()" dfn-for="MediaSource" data-type="SourceBuffer" lt="addSourceBuffer()|addSourceBuffer(type)" local-lt="MediaSource.addSourceBuffer|MediaSource.addSourceBuffer()|addSourceBuffer" tabindex="0" aria-haspopup="dialog"} method {#x3-7-addsourcebuffer-method}

[](#addsourcebuffer-method){.self-link
aria-label="Permalink for Section 3.7"}
:::

Adds a new
[`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-19
.internalDFN link-type="idl"} to
[`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-7
.internalDFN link-type="idl"}.

1.  If `type`{.variable data-type="DOMString"} is an empty string then
    throw a
    [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror){link-type="exception"
    lt="TypeError"} exception and abort these steps.
2.  If `type`{.variable data-type="DOMString"} contains a MIME type that
    is not supported or contains a MIME type that is not supported with
    the types specified for the other
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-20
    .internalDFN link-type="idl" lt="SourceBuffer"} objects in
    [`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-8
    .internalDFN link-type="idl"}, then throw a
    [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror){link-type="exception"
    lt="NotSupportedError"} exception and abort these steps.
3.  If the user agent can\'t handle any more SourceBuffer objects or if
    creating a SourceBuffer based on `type`{.variable
    data-type="DOMString"} would result in an unsupported [SourceBuffer
    configuration](#dfn-sourcebuffer-configuration){#ref-for-dfn-sourcebuffer-configuration-1
    .internalDFN link-type="dfn|abstract-op"}, then throw a
    [`QuotaExceededError`](https://webidl.spec.whatwg.org/#quotaexceedederror){link-type="interface"
    lt="QuotaExceededError"} exception and abort these steps.

    :::: {#issue-container-generatedID-10 .note role="note"}
    ::: {#h-note-10 .note-title .marker role="heading" aria-level="3"}
    Note
    :::

    For example, a user agent *MAY* throw a
    [`QuotaExceededError`](https://webidl.spec.whatwg.org/#quotaexceedederror){link-type="interface"
    lt="QuotaExceededError"} exception if the media element has reached
    the
    [`HAVE_METADATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_metadata){link-type="const"}
    readyState. This can occur if the user agent\'s media engine does
    not support adding more tracks during playback.
    ::::
4.  If the
    [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-9
    .internalDFN link-type="idl"} attribute is not in the
    \"[`open`](#dom-readystate-open){#ref-for-dom-readystate-open-4
    .internalDFN link-type="idl"}\" state then throw an
    [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror){link-type="exception"
    lt="InvalidStateError"} exception and abort these steps.
5.  Let `buffer`{.variable} be a new instance of a
    [`ManagedSourceBuffer`](#dom-managedsourcebuffer){#ref-for-dom-managedsourcebuffer-2
    .internalDFN link-type="idl" lt="ManagedSourceBuffer"} if
    [this](https://webidl.spec.whatwg.org/#this){link-type="dfn"} is a
    [`ManagedMediaSource`](#dom-managedmediasource){#ref-for-dom-managedmediasource-2
    .internalDFN link-type="idl" lt="ManagedMediaSource"}, or a
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-21
    .internalDFN link-type="idl" lt="SourceBuffer"} otherwise, with
    their respective associated resources.
6.  Set `buffer`{.variable}\'s
    [`[[generate timestamps flag]]`](#dfn-generate-timestamps-flag){#ref-for-dfn-generate-timestamps-flag-1
    .internalDFN link-type="attribute"
    lt="[[generate timestamps flag]]"} to the value in the \"Generate
    Timestamps Flag\" column of the [Media Source Extensions™ Byte
    Stream Format
    Registry](https://w3c.github.io/mse-byte-stream-format-registry/){matched-text="[[[MSE-REGISTRY]]]"}
    entry that is associated with `type`{.variable
    data-type="DOMString"}.
7.  If `buffer`{.variable}\'s
    [`[[generate timestamps flag]]`](#dfn-generate-timestamps-flag){#ref-for-dfn-generate-timestamps-flag-2
    .internalDFN link-type="attribute"
    lt="[[generate timestamps flag]]"} is true, set
    `buffer`{.variable}\'s
    [`mode`](#dom-sourcebuffer-mode){#ref-for-dom-sourcebuffer-mode-1
    .internalDFN link-type="idl"} to
    \"[`sequence`](#dom-appendmode-sequence){#ref-for-dom-appendmode-sequence-1
    .internalDFN link-type="idl"}\". Otherwise, set
    `buffer`{.variable}\'s
    [`mode`](#dom-sourcebuffer-mode){#ref-for-dom-sourcebuffer-mode-2
    .internalDFN link-type="idl"} to
    \"[`segments`](#dom-appendmode-segments){#ref-for-dom-appendmode-segments-1
    .internalDFN link-type="idl"}\".
8.  [Append](https://infra.spec.whatwg.org/#list-append){link-type="dfn"}
    `buffer`{.variable} to
    [this](https://webidl.spec.whatwg.org/#this){link-type="dfn"}\'s
    [`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-9
    .internalDFN link-type="idl"}.
9.  [Queue a
    task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
    to [fire an
    event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
    named
    [`addsourcebuffer`](#dfn-addsourcebuffer){#ref-for-dfn-addsourcebuffer-1
    .internalDFN link-type="idl" lt="addsourcebuffer"} at
    [this](https://webidl.spec.whatwg.org/#this){link-type="dfn"}\'s
    [`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-10
    .internalDFN link-type="idl"}.
10. Return `buffer`{.variable}.
::::

:::: {#removesourcebuffer-method .section}
::: header-wrapper
### 3.8 [`removeSourceBuffer()`]{#dom-mediasource-removesourcebuffer .dfn export="" dfn-type="method" idl="operation" data-title="removeSourceBuffer()" dfn-for="MediaSource" data-type="undefined" lt="removeSourceBuffer()|removeSourceBuffer(sourceBuffer)" local-lt="MediaSource.removeSourceBuffer|MediaSource.removeSourceBuffer()|removeSourceBuffer" tabindex="0" aria-haspopup="dialog"} method {#x3-8-removesourcebuffer-method}

[](#removesourcebuffer-method){.self-link
aria-label="Permalink for Section 3.8"}
:::

Removes a
[`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-22
.internalDFN link-type="idl" lt="SourceBuffer"} from
[`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-11
.internalDFN link-type="idl"}.

1.  If `sourceBuffer`{.variable data-type="SourceBuffer"} specifies an
    object that is not in
    [`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-12
    .internalDFN link-type="idl"} then throw a
    [`NotFoundError`](https://webidl.spec.whatwg.org/#notfounderror){link-type="exception"
    lt="NotFoundError"} exception and abort these steps.
2.  If the `sourceBuffer`{.variable
    data-type="SourceBuffer"}.[`updating`](#dom-sourcebuffer-updating){#ref-for-dom-sourcebuffer-updating-2
    .internalDFN link-type="idl"} attribute equals true, then run the
    following steps:
    1.  Abort the [buffer
        append](#dfn-buffer-append){#ref-for-dfn-buffer-append-1
        .internalDFN link-type="dfn|abstract-op"} algorithm if it is
        running.
    2.  Set the `sourceBuffer`{.variable
        data-type="SourceBuffer"}.[`updating`](#dom-sourcebuffer-updating){#ref-for-dom-sourcebuffer-updating-3
        .internalDFN link-type="idl"} attribute to false.
    3.  [Queue a
        task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
        to [fire an
        event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
        named [`abort`](#dfn-abort){#ref-for-dfn-abort-1 .internalDFN
        link-type="idl" lt="abort"} at `sourceBuffer`{.variable
        data-type="SourceBuffer"}.
    4.  [Queue a
        task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
        to [fire an
        event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
        named [`updateend`](#dfn-updateend){#ref-for-dfn-updateend-1
        .internalDFN link-type="idl" lt="updateend"} at
        `sourceBuffer`{.variable data-type="SourceBuffer"}.
3.  Let `SourceBuffer audioTracks list`{.variable
    data-type="AudioTrackList"} equal the
    [`AudioTrackList`](https://html.spec.whatwg.org/multipage/media.html#audiotracklist){link-type="interface"
    lt="AudioTrackList"} object returned by `sourceBuffer`{.variable
    data-type="SourceBuffer"}.[`audioTracks`](#dom-sourcebuffer-audiotracks){#ref-for-dom-sourcebuffer-audiotracks-1
    .internalDFN link-type="idl"}.
4.  If the `SourceBuffer audioTracks list`{.variable
    data-type="AudioTrackList"} is not empty, then run the following
    steps:
    1.  For each
        [`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack){link-type="interface"
        lt="AudioTrack"} object in the
        `SourceBuffer audioTracks list`{.variable
        data-type="AudioTrackList"}, run the following steps:
        1.  Set the
            [`sourceBuffer`](#dom-audiotrack-sourcebuffer){#ref-for-dom-audiotrack-sourcebuffer-1
            .internalDFN link-type="idl"} attribute on the
            [`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack){link-type="interface"
            lt="AudioTrack"} object to null.
        2.  Remove the
            [`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack){link-type="interface"
            lt="AudioTrack"} object from the
            `SourceBuffer audioTracks list`{.variable
            data-type="AudioTrackList"}.

            :::: {#issue-container-generatedID-11 .note role="note"}
            ::: {#h-note-11 .note-title .marker role="heading" aria-level="3"}
            Note
            :::

            This should trigger
            [`AudioTrackList`](https://html.spec.whatwg.org/multipage/media.html#audiotracklist){link-type="interface"
            lt="AudioTrackList"}
            \[[HTML](#bib-html "HTML Standard"){.bibref
            link-type="biblio"}\] logic to [queue a
            task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
            to [fire an
            event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
            named
            [removetrack](https://html.spec.whatwg.org/multipage/media.html#event-media-removetrack){link-type="event"}
            using
            [`TrackEvent`](https://html.spec.whatwg.org/multipage/media.html#trackevent){link-type="interface"
            lt="TrackEvent"} with the
            [`track`](https://html.spec.whatwg.org/multipage/media.html#dom-trackevent-track){link-type="attribute"}
            attribute initialized to the
            [`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack){link-type="interface"
            lt="AudioTrack"} object, at the
            `SourceBuffer audioTracks list`{.variable
            data-type="AudioTrackList"}. If the
            [`enabled`](https://html.spec.whatwg.org/multipage/media.html#dom-audiotrack-enabled){link-type="attribute"}
            attribute on the
            [`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack){link-type="interface"
            lt="AudioTrack"} object was true at the beginning of this
            removal step, then this should also trigger
            [`AudioTrackList`](https://html.spec.whatwg.org/multipage/media.html#audiotracklist){link-type="interface"
            lt="AudioTrackList"}
            \[[HTML](#bib-html "HTML Standard"){.bibref
            link-type="biblio"}\] logic to [queue a
            task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
            to [fire an
            event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
            named
            [change](https://html.spec.whatwg.org/multipage/media.html#event-media-change){link-type="event"}
            at the `SourceBuffer audioTracks list`{.variable
            data-type="AudioTrackList"}.
            ::::
        3.  Use the [mirror if
            necessary](#dfn-mirror-if-necessary){#ref-for-dfn-mirror-if-necessary-1
            .internalDFN link-type="dfn|abstract-op"} algorithm to run
            the following steps in
            [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
            lt="Window"}, to remove the
            [`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack){link-type="interface"
            lt="AudioTrack"} object (or instead, the
            [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
            lt="Window"} mirror of it if the
            [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-32
            .internalDFN link-type="idl" lt="MediaSource"} object was
            constructed in a
            [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
            lt="DedicatedWorkerGlobalScope"}) from the media element:
            1.  Let `HTMLMediaElement audioTracks list`{.variable
                data-type="AudioTrackList"} equal the
                [`AudioTrackList`](https://html.spec.whatwg.org/multipage/media.html#audiotracklist){link-type="interface"
                lt="AudioTrackList"} object returned by the
                [`audioTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-audiotracks){link-type="attribute"}
                attribute on the HTMLMediaElement.
            2.  Remove the
                [`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack){link-type="interface"
                lt="AudioTrack"} object from the
                `HTMLMediaElement audioTracks list`{.variable}.

                :::: {#issue-container-generatedID-12 .note role="note"}
                ::: {#h-note-12 .note-title .marker role="heading" aria-level="3"}
                Note
                :::

                This should trigger
                [`AudioTrackList`](https://html.spec.whatwg.org/multipage/media.html#audiotracklist){link-type="interface"
                lt="AudioTrackList"}
                \[[HTML](#bib-html "HTML Standard"){.bibref
                link-type="biblio"}\] logic to [queue a
                task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
                to [fire an
                event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
                named
                [removetrack](https://html.spec.whatwg.org/multipage/media.html#event-media-removetrack){link-type="event"}
                using
                [`TrackEvent`](https://html.spec.whatwg.org/multipage/media.html#trackevent){link-type="interface"
                lt="TrackEvent"} with the
                [`track`](https://html.spec.whatwg.org/multipage/media.html#dom-trackevent-track){link-type="attribute"}
                attribute initialized to the
                [`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack){link-type="interface"
                lt="AudioTrack"} object, at the
                `HTMLMediaElement audioTracks list`{.variable
                data-type="AudioTrackList"}. If the
                [`enabled`](https://html.spec.whatwg.org/multipage/media.html#dom-audiotrack-enabled){link-type="attribute"}
                attribute on the
                [`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack){link-type="interface"
                lt="AudioTrack"} object was true at the beginning of
                this removal step, then this should also trigger
                [`AudioTrackList`](https://html.spec.whatwg.org/multipage/media.html#audiotracklist){link-type="interface"
                lt="AudioTrackList"}
                \[[HTML](#bib-html "HTML Standard"){.bibref
                link-type="biblio"}\] logic to [queue a
                task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
                to [fire an
                event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
                named
                [change](https://html.spec.whatwg.org/multipage/media.html#event-media-change){link-type="event"}
                at the `HTMLMediaElement audioTracks list`{.variable
                data-type="AudioTrackList"}.
                ::::
5.  Let `SourceBuffer videoTracks list`{.variable
    data-type="VideoTrackList"} equal the
    [`VideoTrackList`](https://html.spec.whatwg.org/multipage/media.html#videotracklist){link-type="interface"
    lt="VideoTrackList"} object returned by `sourceBuffer`{.variable
    data-type="SourceBuffer"}.[`videoTracks`](#dom-sourcebuffer-videotracks){#ref-for-dom-sourcebuffer-videotracks-1
    .internalDFN link-type="idl"}.
6.  If the `SourceBuffer videoTracks list`{.variable
    data-type="VideoTrackList"} is not empty, then run the following
    steps:
    1.  For each
        [`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack){link-type="interface"
        lt="VideoTrack"} object in the
        `SourceBuffer videoTracks list`{.variable
        data-type="VideoTrackList"}, run the following steps:
        1.  Set the
            [`sourceBuffer`](#dom-videotrack-sourcebuffer){#ref-for-dom-videotrack-sourcebuffer-1
            .internalDFN link-type="idl"} attribute on the
            [`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack){link-type="interface"
            lt="VideoTrack"} object to null.
        2.  Remove the
            [`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack){link-type="interface"
            lt="VideoTrack"} object from the
            `SourceBuffer videoTracks list`{.variable
            data-type="VideoTrackList"}.

            :::: {#issue-container-generatedID-13 .note role="note"}
            ::: {#h-note-13 .note-title .marker role="heading" aria-level="3"}
            Note
            :::

            This should trigger
            [`VideoTrackList`](https://html.spec.whatwg.org/multipage/media.html#videotracklist){link-type="interface"
            lt="VideoTrackList"}
            \[[HTML](#bib-html "HTML Standard"){.bibref
            link-type="biblio"}\] logic to [queue a
            task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
            to [fire an
            event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
            named
            [removetrack](https://html.spec.whatwg.org/multipage/media.html#event-media-removetrack){link-type="event"}
            using
            [`TrackEvent`](https://html.spec.whatwg.org/multipage/media.html#trackevent){link-type="interface"
            lt="TrackEvent"} with the
            [`track`](https://html.spec.whatwg.org/multipage/media.html#dom-trackevent-track){link-type="attribute"}
            attribute initialized to the
            [`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack){link-type="interface"
            lt="VideoTrack"} object, at the
            `SourceBuffer videoTracks list`{.variable
            data-type="VideoTrackList"}. If the
            [`selected`](https://html.spec.whatwg.org/multipage/media.html#dom-videotrack-selected){link-type="attribute"}
            attribute on the
            [`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack){link-type="interface"
            lt="VideoTrack"} object was true at the beginning of this
            removal step, then this should also trigger
            [`VideoTrackList`](https://html.spec.whatwg.org/multipage/media.html#videotracklist){link-type="interface"
            lt="VideoTrackList"}
            \[[HTML](#bib-html "HTML Standard"){.bibref
            link-type="biblio"}\] logic to [queue a
            task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
            to [fire an
            event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
            named
            [change](https://html.spec.whatwg.org/multipage/media.html#event-media-change){link-type="event"}
            at the `SourceBuffer videoTracks list`{.variable
            data-type="VideoTrackList"}.
            ::::
        3.  Use the [mirror if
            necessary](#dfn-mirror-if-necessary){#ref-for-dfn-mirror-if-necessary-2
            .internalDFN link-type="dfn|abstract-op"} algorithm to run
            the following steps in
            [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
            lt="Window"}, to remove the
            [`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack){link-type="interface"
            lt="VideoTrack"} object (or instead, the
            [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
            lt="Window"} mirror of it if the
            [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-33
            .internalDFN link-type="idl" lt="MediaSource"} object was
            constructed in a
            [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
            lt="DedicatedWorkerGlobalScope"}) from the media element:
            1.  Let `HTMLMediaElement videoTracks list`{.variable
                data-type="VideoTrackList"} equal the
                [`VideoTrackList`](https://html.spec.whatwg.org/multipage/media.html#videotracklist){link-type="interface"
                lt="VideoTrackList"} object returned by the
                [`videoTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-videotracks){link-type="attribute"}
                attribute on the HTMLMediaElement.
            2.  Remove the
                [`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack){link-type="interface"
                lt="VideoTrack"} object from the
                `HTMLMediaElement videoTracks list`{.variable}.

                :::: {#issue-container-generatedID-14 .note role="note"}
                ::: {#h-note-14 .note-title .marker role="heading" aria-level="3"}
                Note
                :::

                This should trigger
                [`VideoTrackList`](https://html.spec.whatwg.org/multipage/media.html#videotracklist){link-type="interface"
                lt="VideoTrackList"}
                \[[HTML](#bib-html "HTML Standard"){.bibref
                link-type="biblio"}\] logic to [queue a
                task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
                to [fire an
                event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
                named
                [removetrack](https://html.spec.whatwg.org/multipage/media.html#event-media-removetrack){link-type="event"}
                using
                [`TrackEvent`](https://html.spec.whatwg.org/multipage/media.html#trackevent){link-type="interface"
                lt="TrackEvent"} with the
                [`track`](https://html.spec.whatwg.org/multipage/media.html#dom-trackevent-track){link-type="attribute"}
                attribute initialized to the
                [`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack){link-type="interface"
                lt="VideoTrack"} object, at the
                `HTMLMediaElement videoTracks list`{.variable
                data-type="VideoTrackList"}. If the
                [`selected`](https://html.spec.whatwg.org/multipage/media.html#dom-videotrack-selected){link-type="attribute"}
                attribute on the
                [`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack){link-type="interface"
                lt="VideoTrack"} object was true at the beginning of
                this removal step, then this should also trigger
                [`VideoTrackList`](https://html.spec.whatwg.org/multipage/media.html#videotracklist){link-type="interface"
                lt="VideoTrackList"}
                \[[HTML](#bib-html "HTML Standard"){.bibref
                link-type="biblio"}\] logic to [queue a
                task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
                to [fire an
                event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
                named
                [change](https://html.spec.whatwg.org/multipage/media.html#event-media-change){link-type="event"}
                at the `HTMLMediaElement videoTracks list`{.variable
                data-type="VideoTrackList"}.
                ::::
7.  Let `SourceBuffer textTracks list`{.variable
    data-type="TextTrackList"} equal the
    [`TextTrackList`](https://html.spec.whatwg.org/multipage/media.html#texttracklist){link-type="interface"
    lt="TextTrackList"} object returned by `sourceBuffer`{.variable
    data-type="SourceBuffer"}.[`textTracks`](#dom-sourcebuffer-texttracks){#ref-for-dom-sourcebuffer-texttracks-1
    .internalDFN link-type="idl"}.
8.  If the `SourceBuffer textTracks list`{.variable
    data-type="TextTrackList"} is not empty, then run the following
    steps:
    1.  For each
        [`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack){link-type="interface"
        lt="TextTrack"} object in the
        `SourceBuffer textTracks list`{.variable
        data-type="TextTrackList"}, run the following steps:
        1.  Set the
            [`sourceBuffer`](#dom-texttrack-sourcebuffer){#ref-for-dom-texttrack-sourcebuffer-1
            .internalDFN link-type="idl"} attribute on the
            [`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack){link-type="interface"
            lt="TextTrack"} object to null.
        2.  Remove the
            [`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack){link-type="interface"
            lt="TextTrack"} object from the
            `SourceBuffer textTracks list`{.variable
            data-type="TextTrackList"}.

            :::: {#issue-container-generatedID-15 .note role="note"}
            ::: {#h-note-15 .note-title .marker role="heading" aria-level="3"}
            Note
            :::

            This should trigger
            [`TextTrackList`](https://html.spec.whatwg.org/multipage/media.html#texttracklist){link-type="interface"
            lt="TextTrackList"}
            \[[HTML](#bib-html "HTML Standard"){.bibref
            link-type="biblio"}\] logic to [queue a
            task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
            to [fire an
            event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
            named
            [removetrack](https://html.spec.whatwg.org/multipage/media.html#event-media-removetrack){link-type="event"}
            using
            [`TrackEvent`](https://html.spec.whatwg.org/multipage/media.html#trackevent){link-type="interface"
            lt="TrackEvent"} with the
            [`track`](https://html.spec.whatwg.org/multipage/media.html#dom-trackevent-track){link-type="attribute"}
            attribute initialized to the
            [`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack){link-type="interface"
            lt="TextTrack"} object, at the
            `SourceBuffer textTracks list`{.variable
            data-type="TextTrackList"}. If the
            [`mode`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-mode){link-type="attribute"}
            attribute on the
            [`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack){link-type="interface"
            lt="TextTrack"} object was
            [`"showing"`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-showing)
            or
            [`"hidden"`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-hidden)
            at the beginning of this removal step, then this should also
            trigger
            [`TextTrackList`](https://html.spec.whatwg.org/multipage/media.html#texttracklist){link-type="interface"
            lt="TextTrackList"}
            \[[HTML](#bib-html "HTML Standard"){.bibref
            link-type="biblio"}\] logic to [queue a
            task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
            to [fire an
            event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
            named
            [change](https://html.spec.whatwg.org/multipage/media.html#event-media-change){link-type="event"}
            at the `SourceBuffer textTracks list`{.variable}.
            ::::
        3.  Use the [mirror if
            necessary](#dfn-mirror-if-necessary){#ref-for-dfn-mirror-if-necessary-3
            .internalDFN link-type="dfn|abstract-op"} algorithm to run
            the following steps in
            [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
            lt="Window"}, to remove the
            [`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack){link-type="interface"
            lt="TextTrack"} object (or instead, the
            [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
            lt="Window"} mirror of it if the
            [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-34
            .internalDFN link-type="idl" lt="MediaSource"} object was
            constructed in a
            [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
            lt="DedicatedWorkerGlobalScope"}) from the media element:
            1.  Let `HTMLMediaElement textTracks list`{.variable
                data-type="TextTrackList"} equal the
                [`TextTrackList`](https://html.spec.whatwg.org/multipage/media.html#texttracklist){link-type="interface"
                lt="TextTrackList"} object returned by the
                [`textTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-texttracks){link-type="attribute"}
                attribute on the HTMLMediaElement.
            2.  Remove the
                [`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack){link-type="interface"
                lt="TextTrack"} object from the
                `HTMLMediaElement textTracks list`{.variable}.

                :::: {#issue-container-generatedID-16 .note role="note"}
                ::: {#h-note-16 .note-title .marker role="heading" aria-level="3"}
                Note
                :::

                This should trigger
                [`TextTrackList`](https://html.spec.whatwg.org/multipage/media.html#texttracklist){link-type="interface"
                lt="TextTrackList"}
                \[[HTML](#bib-html "HTML Standard"){.bibref
                link-type="biblio"}\] logic to [queue a
                task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
                to [fire an
                event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
                named
                [removetrack](https://html.spec.whatwg.org/multipage/media.html#event-media-removetrack){link-type="event"}
                using
                [`TrackEvent`](https://html.spec.whatwg.org/multipage/media.html#trackevent){link-type="interface"
                lt="TrackEvent"} with the
                [`track`](https://html.spec.whatwg.org/multipage/media.html#dom-trackevent-track){link-type="attribute"}
                attribute initialized to the
                [`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack){link-type="interface"
                lt="TextTrack"} object, at the
                `HTMLMediaElement textTracks list`{.variable
                data-type="TextTrackList"}. If the
                [`mode`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-mode){link-type="attribute"}
                attribute on the
                [`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack){link-type="interface"
                lt="TextTrack"} object was
                [`"showing"`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-showing)
                or
                [`"hidden"`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-hidden)
                at the beginning of this removal step, then this should
                also trigger
                [`TextTrackList`](https://html.spec.whatwg.org/multipage/media.html#texttracklist){link-type="interface"
                lt="TextTrackList"}
                \[[HTML](#bib-html "HTML Standard"){.bibref
                link-type="biblio"}\] logic to [queue a
                task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
                to [fire an
                event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
                named
                [change](https://html.spec.whatwg.org/multipage/media.html#event-media-change){link-type="event"}
                at the `HTMLMediaElement textTracks list`{.variable
                data-type="TextTrackList"}.
                ::::
9.  If `sourceBuffer`{.variable data-type="SourceBuffer"} is in
    [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-4
    .internalDFN link-type="idl"}, then remove `sourceBuffer`{.variable
    data-type="SourceBuffer"} from
    [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-5
    .internalDFN link-type="idl"} and [queue a
    task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
    to [fire an
    event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
    named
    [`removesourcebuffer`](#dfn-removesourcebuffer){#ref-for-dfn-removesourcebuffer-1
    .internalDFN link-type="idl" lt="removesourcebuffer"} at the
    [`SourceBufferList`](#dom-sourcebufferlist){#ref-for-dom-sourcebufferlist-3
    .internalDFN link-type="idl"} returned by
    [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-6
    .internalDFN link-type="idl"}.
10. Remove `sourceBuffer`{.variable data-type="SourceBuffer"} from
    [`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-13
    .internalDFN link-type="idl"} and [queue a
    task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
    to [fire an
    event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
    named
    [`removesourcebuffer`](#dfn-removesourcebuffer){#ref-for-dfn-removesourcebuffer-2
    .internalDFN link-type="idl" lt="removesourcebuffer"} at the
    [`SourceBufferList`](#dom-sourcebufferlist){#ref-for-dom-sourcebufferlist-4
    .internalDFN link-type="idl"} returned by
    [`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-14
    .internalDFN link-type="idl"}.
11. Destroy all resources for `sourceBuffer`{.variable
    data-type="SourceBuffer"}.
::::

:::: {#endofstream-method .section}
::: header-wrapper
### 3.9 [`endOfStream()`]{#dom-mediasource-endofstream .dfn export="" dfn-type="method" idl="operation" data-title="endOfStream()" dfn-for="MediaSource" data-type="undefined" lt="endOfStream()|endOfStream(error)" local-lt="MediaSource.endOfStream|MediaSource.endOfStream()|endOfStream" tabindex="0" aria-haspopup="dialog"} method {#x3-9-endofstream-method}

[](#endofstream-method){.self-link
aria-label="Permalink for Section 3.9"}
:::

Signals the end of the stream.

1.  If the
    [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-10
    .internalDFN link-type="idl"} attribute is not in the
    \"[`open`](#dom-readystate-open){#ref-for-dom-readystate-open-5
    .internalDFN link-type="idl"}\" state then throw an
    [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror){link-type="exception"
    lt="InvalidStateError"} exception and abort these steps.
2.  If the
    [`updating`](#dom-sourcebuffer-updating){#ref-for-dom-sourcebuffer-updating-4
    .internalDFN link-type="idl"} attribute equals true on any
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-23
    .internalDFN link-type="idl" lt="SourceBuffer"} in
    [`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-15
    .internalDFN link-type="idl"}, then throw an
    [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror){link-type="exception"
    lt="InvalidStateError"} exception and abort these steps.
3.  Run the [end of
    stream](#dfn-end-of-stream){#ref-for-dfn-end-of-stream-1
    .internalDFN link-type="dfn|abstract-op"} algorithm with the error
    parameter set to `error`{.variable data-type="EndOfStreamError"}.
::::

:::: {#setliveseekablerange-method .section}
::: header-wrapper
### 3.10 [`setLiveSeekableRange()`]{#dom-mediasource-setliveseekablerange .dfn export="" dfn-type="method" idl="operation" data-title="setLiveSeekableRange()" dfn-for="MediaSource" data-type="undefined" lt="setLiveSeekableRange()|setLiveSeekableRange(start, end)" local-lt="MediaSource.setLiveSeekableRange|MediaSource.setLiveSeekableRange()|setLiveSeekableRange" tabindex="0" aria-haspopup="dialog"} method {#x3-10-setliveseekablerange-method}

[](#setliveseekablerange-method){.self-link
aria-label="Permalink for Section 3.10"}
:::

Updates
[`[[live seekable range]]`](#dfn-live-seekable-range){#ref-for-dfn-live-seekable-range-1
.internalDFN link-type="attribute" lt="[[live seekable range]]"} that is
used in section [10. HTMLMediaElement
Extensions](#htmlmediaelement-extensions){.sec-ref
matched-text="[[[#htmlmediaelement-extensions]]]"} to modify
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"}\'s
[`seekable`](https://html.spec.whatwg.org/multipage/media.html#dom-media-seekable){link-type="attribute"}
behavior.

When this method is invoked, the user agent must run the following
steps:

1.  If the
    [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-11
    .internalDFN link-type="idl"} attribute is not
    \"[`open`](#dom-readystate-open){#ref-for-dom-readystate-open-6
    .internalDFN link-type="idl"}\" then throw an
    [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror){link-type="exception"
    lt="InvalidStateError"} exception and abort these steps.
2.  If `start`{.variable data-type="double"} is negative or greater than
    `end`{.variable data-type="double"}, then throw a
    [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror){link-type="exception"
    lt="TypeError"} exception and abort these steps.
3.  Set
    [`[[live seekable range]]`](#dfn-live-seekable-range){#ref-for-dfn-live-seekable-range-2
    .internalDFN link-type="attribute" lt="[[live seekable range]]"} to
    be a new [normalized TimeRanges
    object](https://html.spec.whatwg.org/multipage/media.html#normalised-timeranges-object)
    containing a single range whose start position is `start`{.variable
    data-type="double"} and end position is `end`{.variable
    data-type="double"}.
::::

:::: {#clearliveseekablerange-method .section}
::: header-wrapper
### 3.11 [`clearLiveSeekableRange()`]{#dom-mediasource-clearliveseekablerange .dfn export="" dfn-type="method" idl="operation" data-title="clearLiveSeekableRange()" dfn-for="MediaSource" data-type="undefined" lt="clearLiveSeekableRange()" local-lt="MediaSource.clearLiveSeekableRange|MediaSource.clearLiveSeekableRange()|clearLiveSeekableRange" tabindex="0" aria-haspopup="dialog"} method {#x3-11-clearliveseekablerange-method}

[](#clearliveseekablerange-method){.self-link
aria-label="Permalink for Section 3.11"}
:::

Updates
[`[[live seekable range]]`](#dfn-live-seekable-range){#ref-for-dfn-live-seekable-range-3
.internalDFN link-type="attribute" lt="[[live seekable range]]"} that is
used in section [10. HTMLMediaElement
Extensions](#htmlmediaelement-extensions){.sec-ref
matched-text="[[[#htmlmediaelement-extensions]]]"} to modify
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"}\'s
[`seekable`](https://html.spec.whatwg.org/multipage/media.html#dom-media-seekable){link-type="attribute"}
behavior.

When this method is invoked, the user agent must run the following
steps:

1.  If the
    [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-12
    .internalDFN link-type="idl"} attribute is not
    \"[`open`](#dom-readystate-open){#ref-for-dom-readystate-open-7
    .internalDFN link-type="idl"}\" then throw an
    [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror){link-type="exception"
    lt="InvalidStateError"} exception and abort these steps.
2.  If
    [`[[live seekable range]]`](#dfn-live-seekable-range){#ref-for-dfn-live-seekable-range-4
    .internalDFN link-type="attribute" lt="[[live seekable range]]"}
    contains a range, then set
    [`[[live seekable range]]`](#dfn-live-seekable-range){#ref-for-dfn-live-seekable-range-5
    .internalDFN link-type="attribute" lt="[[live seekable range]]"} to
    be a new empty
    [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface"
    lt="TimeRanges"} object.
::::

:::::::: {#istypesupported-method .section}
::: header-wrapper
### 3.12 [`isTypeSupported()`]{#dom-mediasource-istypesupported .dfn export="" dfn-type="method" idl="operation" data-title="isTypeSupported()" dfn-for="MediaSource" data-type="boolean" lt="isTypeSupported()|isTypeSupported(type)" local-lt="MediaSource.isTypeSupported|MediaSource.isTypeSupported()|isTypeSupported" tabindex="0" aria-haspopup="dialog"} method {#x3-12-istypesupported-method}

[](#istypesupported-method){.self-link
aria-label="Permalink for Section 3.12"}
:::

Check to see whether the
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-35
.internalDFN link-type="idl"} is capable of creating
[`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-24
.internalDFN link-type="idl"} objects for the specified MIME type.

:::: {#issue-container-generatedID-17 .note role="note"}
::: {#h-note-17 .note-title .marker role="heading" aria-level="3"}
Note
:::

If true is returned from this method, it only indicates that the
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-36
.internalDFN link-type="idl" lt="MediaSource"} implementation is capable
of creating
[`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-25
.internalDFN link-type="idl" lt="SourceBuffer"} objects for the
specified MIME type. An
[`addSourceBuffer`](#dom-mediasource-addsourcebuffer){#ref-for-dom-mediasource-addsourcebuffer-4
.internalDFN link-type="idl" lt="addSourceBuffer()"}`()` call *SHOULD*
still fail if sufficient resources are not available to support the
addition of a new
[`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-26
.internalDFN link-type="idl" lt="SourceBuffer"}.
::::

:::: {#issue-container-generatedID-18 .note role="note"}
::: {#h-note-18 .note-title .marker role="heading" aria-level="3"}
Note
:::

This method returning true implies that
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"}\'s
[`canPlayType`](https://html.spec.whatwg.org/multipage/media.html#dom-navigator-canplaytype){link-type="method"
lt="canPlayType()"}`()` will return \"maybe\" or \"probably\" since it
does not make sense for a
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-37
.internalDFN link-type="idl" lt="MediaSource"} to support a type the
HTMLMediaElement knows it cannot play.
::::

When this method is invoked, the user agent must run the following
steps:

1.  If `type`{.variable data-type="DOMString"} is an empty string, then
    return false.
2.  If `type`{.variable data-type="DOMString"} does not contain a valid
    MIME type string, then return false.
3.  If `type`{.variable data-type="DOMString"} contains a media type or
    media subtype that the MediaSource does not support, then return
    false.
4.  If `type`{.variable data-type="DOMString"} contains a codec that the
    MediaSource does not support, then return false.
5.  If the MediaSource does not support the specified combination of
    media type, media subtype, and codecs then return false.
6.  Return true.
::::::::

:::: {#mediasource-events .section}
::: header-wrapper
### 3.13 Event Summary {#x3-13-event-summary}

[](#mediasource-events){.self-link
aria-label="Permalink for Section 3.13"}
:::

  Event name                                                                                                   Interface                                                                         Dispatched when\...
  ------------------------------------------------------------------------------------------------------------ --------------------------------------------------------------------------------- -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  [sourceopen]{#dfn-sourceopen .dfn .event dfn-type="event" tabindex="0" aria-haspopup="dialog" export=""}     [`Event`](https://dom.spec.whatwg.org/#event){link-type="interface" lt="Event"}   [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-38 .internalDFN link-type="idl" lt="MediaSource"}\'s [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-13 .internalDFN link-type="idl"} transitions from \"[`closed`](#dom-readystate-closed){#ref-for-dom-readystate-closed-5 .internalDFN link-type="idl"}\" to \"[`open`](#dom-readystate-open){#ref-for-dom-readystate-open-8 .internalDFN link-type="idl"}\" or from \"[`ended`](#dom-readystate-ended){#ref-for-dom-readystate-ended-2 .internalDFN link-type="idl"}\" to \"[`open`](#dom-readystate-open){#ref-for-dom-readystate-open-9 .internalDFN link-type="idl"}\".
  [sourceended]{#dfn-sourceended .dfn .event dfn-type="event" tabindex="0" aria-haspopup="dialog" export=""}   [`Event`](https://dom.spec.whatwg.org/#event){link-type="interface" lt="Event"}   [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-39 .internalDFN link-type="idl" lt="MediaSource"}\'s [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-14 .internalDFN link-type="idl"} transitions from \"[`open`](#dom-readystate-open){#ref-for-dom-readystate-open-10 .internalDFN link-type="idl"}\" to \"[`ended`](#dom-readystate-ended){#ref-for-dom-readystate-ended-3 .internalDFN link-type="idl"}\".
  [sourceclose]{#dfn-sourceclose .dfn .event dfn-type="event" tabindex="0" aria-haspopup="dialog" export=""}   [`Event`](https://dom.spec.whatwg.org/#event){link-type="interface" lt="Event"}   [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-40 .internalDFN link-type="idl" lt="MediaSource"}\'s [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-15 .internalDFN link-type="idl"} transitions from \"[`open`](#dom-readystate-open){#ref-for-dom-readystate-open-11 .internalDFN link-type="idl"}\" to \"[`closed`](#dom-readystate-closed){#ref-for-dom-readystate-closed-6 .internalDFN link-type="idl"}\" or \"[`ended`](#dom-readystate-ended){#ref-for-dom-readystate-ended-4 .internalDFN link-type="idl"}\" to \"[`closed`](#dom-readystate-closed){#ref-for-dom-readystate-closed-7 .internalDFN link-type="idl"}\".
::::

:::::: {#mediasource-in-worker-communication-model .section}
::: header-wrapper
### 3.14 [Cross-context communication model]{#dfn-cross-context-communication-model .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"} {#x3-14-cross-context-communication-model}

[](#mediasource-in-worker-communication-model){.self-link
aria-label="Permalink for Section 3.14"}
:::

When a
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
lt="Window"}
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"} is attached to a
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
lt="DedicatedWorkerGlobalScope"}
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-41
.internalDFN link-type="idl" lt="MediaSource"}, each context has
algorithms that depend on information from the other.

:::: {#issue-container-generatedID-19 .note role="note"}
::: {#h-note-19 .note-title .marker role="heading" aria-level="4"}
Note
:::

[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"} is exposed only to
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
lt="Window"} contexts, but
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-42
.internalDFN link-type="idl" lt="MediaSource"} and related objects
defined in this specification are exposed in
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
lt="Window"} and
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
lt="DedicatedWorkerGlobalScope"} contexts. This lets applications
construct a
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-43
.internalDFN link-type="idl" lt="MediaSource"} object in either of those
types of context and attach it to an
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"} object in a
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
lt="Window"} context using a [MediaSource object
URL](#mediasource-object-url){#ref-for-mediasource-object-url-1
.internalDFN link-type="dfn|abstract-op"} or a
[`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-5
.internalDFN link-type="idl" lt="MediaSourceHandle"} as described in the
[attaching to a media
element](#dfn-attaching-to-a-media-element){#ref-for-dfn-attaching-to-a-media-element-2
.internalDFN link-type="dfn|abstract-op"} algorithm. A
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-44
.internalDFN link-type="idl" lt="MediaSource"} object is not
[`Transferable`](https://html.spec.whatwg.org/multipage/structured-data.html#transferable){link-type="extended-attribute"
lt="Transferable"}; it is only visible in the context where it was
created.
::::

The rest of this section describes a model for bounding information
latency for attachments of a
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
lt="Window"} media element to a
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
lt="DedicatedWorkerGlobalScope"}
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-45
.internalDFN link-type="idl" lt="MediaSource"}. While the model
describes communication using message passing, implementations *MAY*
choose to communicate in potentially faster ways, such as using shared
memory and locks. Attachments to a
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
lt="Window"}
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-46
.internalDFN link-type="idl" lt="MediaSource"} synchronously have the
information already without communicating it across contexts.

A [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-47
.internalDFN link-type="idl" lt="MediaSource"} that is constructed in a
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
lt="DedicatedWorkerGlobalScope"} has a [\[\[port to
main\]\]]{#dfn-port-to-main .dfn dfn-for="MediaSource" idl=""
noexport="" dfn-type="attribute" tabindex="0" aria-haspopup="dialog"}
internal slot that stores a
[`MessagePort`](https://html.spec.whatwg.org/multipage/web-messaging.html#messageport){link-type="interface"
lt="MessagePort"} setup during attachment and nulled during detachment.
A
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
lt="Window"}
[`[[port to main]]`](#dfn-port-to-main){#ref-for-dfn-port-to-main-1
.internalDFN link-type="attribute" lt="[[port to main]]"} is always
null.

An
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"} extended by this specification and attached to a
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
lt="DedicatedWorkerGlobalScope"}
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-48
.internalDFN link-type="idl" lt="MediaSource"} similarly has a [\[\[port
to worker\]\]]{#dfn-port-to-worker .dfn dfn-for="HTMLMediaElement"
idl="" noexport="" dfn-type="attribute" tabindex="0"
aria-haspopup="dialog"} internal slot that stores a
[`MessagePort`](https://html.spec.whatwg.org/multipage/web-messaging.html#messageport){link-type="interface"
lt="MessagePort"} and a [\[\[channel with
worker\]\]]{#dfn-channel-with-worker .dfn dfn-for="HTMLMediaElement"
idl="" noexport="" dfn-type="attribute" tabindex="0"
aria-haspopup="dialog"} internal slot that stores a
[`MessageChannel`](https://html.spec.whatwg.org/multipage/web-messaging.html#messagechannel){link-type="interface"
lt="MessageChannel"}, both setup during attachment and nulled during
detachment. Both
[`[[port to worker]]`](#dfn-port-to-worker){#ref-for-dfn-port-to-worker-1
.internalDFN link-type="attribute" lt="[[port to worker]]"} and
[`[[channel with worker]]`](#dfn-channel-with-worker){#ref-for-dfn-channel-with-worker-1
.internalDFN link-type="attribute" lt="[[channel with worker]]"} are
null unless attached to a
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
lt="DedicatedWorkerGlobalScope"}
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-49
.internalDFN link-type="idl" lt="MediaSource"}.

Algorithms in this specification that need to communicate information
from a
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
lt="Window"}
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"} to an attached
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
lt="DedicatedWorkerGlobalScope"}
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-50
.internalDFN link-type="idl" lt="MediaSource"}, or vice versa, will use
these internal ports implicitly to post a message to their counterpart,
where the implicit handler of the message runs steps as described in the
algorithms.
::::::

:::::::::::::::::::::::::::::::: {#mediasource-algorithms .section}
::: header-wrapper
### 3.15 Algorithms {#x3-15-algorithms}

[](#mediasource-algorithms){.self-link
aria-label="Permalink for Section 3.15"}
:::

:::::::::: {#mediasource-attach .section}
::: header-wrapper
#### 3.15.1 [Attaching to a media element]{#dfn-attaching-to-a-media-element .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"} {#x3-15-1-attaching-to-a-media-element}

[](#mediasource-attach){.self-link
aria-label="Permalink for Section 3.15.1"}
:::

There are distinct mechanisms for attaching a
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-51
.internalDFN link-type="idl" lt="MediaSource"} to a media element
depending on where the
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-52
.internalDFN link-type="idl" lt="MediaSource"} object was constructed,
in a
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
lt="Window"} versus in a
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
lt="DedicatedWorkerGlobalScope"}:

- Attaching a
  [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-53
  .internalDFN link-type="idl" lt="MediaSource"} that was constructed in
  a
  [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
  lt="Window"} can be done by assigning a [MediaSource object
  URL](#mediasource-object-url){#ref-for-mediasource-object-url-2
  .internalDFN link-type="dfn|abstract-op"} for that
  [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-54
  .internalDFN link-type="idl" lt="MediaSource"} to the media element
  [`src`](https://html.spec.whatwg.org/multipage/media.html#dom-media-src){link-type="attribute"}
  attribute or the src attribute of a \<source\> inside a media element.
  A [MediaSource object
  URL](#mediasource-object-url){#ref-for-mediasource-object-url-3
  .internalDFN link-type="dfn|abstract-op"} is created by passing a
  MediaSource object to
  [`createObjectURL`](https://www.w3.org/TR/FileAPI/#dfn-createObjectURL){link-type="method"
  lt="createObjectURL()"}`()`.

  Though implementations *MAY* allow [MediaSource object
  URL](#mediasource-object-url){#ref-for-mediasource-object-url-4
  .internalDFN link-type="dfn|abstract-op"} creation in a
  [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
  lt="DedicatedWorkerGlobalScope"} for a
  [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-55
  .internalDFN link-type="idl" lt="MediaSource"} constructed in that
  worker, attempting to use that [MediaSource object
  URL](#mediasource-object-url){#ref-for-mediasource-object-url-5
  .internalDFN link-type="dfn|abstract-op"} to attach to a media element
  using either the
  [`src`](https://html.spec.whatwg.org/multipage/media.html#dom-media-src){link-type="attribute"}
  attribute or the src attribute of a \<source\> inside a media element
  *MUST* fail in the media element\'s [resource fetch
  algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource){link-type="dfn"},
  as extended below.

  :::: {#issue-container-generatedID-20 .note role="note"}
  ::: {#h-note-20 .note-title .marker role="heading" aria-level="5"}
  Note
  :::

  Extending the object URL attachment mechanism to worker MediaSource
  object URLs would further propagate this idiom that is less preferred
  versus using srcObject, and would unnecessarily increase user agent
  interoperability risk and implementation complexity.
  ::::

- Attaching a
  [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-56
  .internalDFN link-type="idl" lt="MediaSource"} that was constructed in
  a
  [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
  lt="DedicatedWorkerGlobalScope"} can only be done by obtaining a
  handle from it using
  [`handle`](#dom-mediasource-handle){#ref-for-dom-mediasource-handle-2
  .internalDFN link-type="idl"}, transferring that
  [`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-6
  .internalDFN link-type="idl" lt="MediaSourceHandle"} to the
  [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
  lt="Window"} context and assigning it to the media element
  [`srcObject`](https://html.spec.whatwg.org/multipage/media.html#dom-media-srcobject){link-type="attribute"}
  attribute. For the purposes of aligning this specification with
  [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
  lt="HTMLMediaElement"} resource loading and fetching algorithms, the
  underlying
  [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
  lt="DedicatedWorkerGlobalScope"}
  [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-57
  .internalDFN link-type="idl" lt="MediaSource"} is the MediaSource
  object mentioned there, and the
  [`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-7
  .internalDFN link-type="idl" lt="MediaSourceHandle"} object is the
  media provider object.

If the [resource fetch
algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource){link-type="dfn"}
was invoked with a media provider object that is a
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-58
.internalDFN link-type="idl" lt="MediaSource"} object, a
[`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-8
.internalDFN link-type="idl" lt="MediaSourceHandle"} object or a URL
record whose object is a
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-59
.internalDFN link-type="idl" lt="MediaSource"} object, then let mode be
local, skip the first step in the [resource fetch
algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource){link-type="dfn"}
(which may otherwise set mode to remote) and continue the execution of
the [resource fetch
algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource){link-type="dfn"}.

:::: {#issue-container-generatedID-21 .note role="note"}
::: {#h-note-21 .note-title .marker role="heading" aria-level="5"}
Note
:::

The first step of the [resource fetch
algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource){link-type="dfn"}
is expected to eventually align with selecting local mode for URL
records whose objects are media provider objects. The intent is that if
the
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"}\'s
[`src`](https://html.spec.whatwg.org/multipage/media.html#dom-media-src){link-type="attribute"}
attribute or selected child
[`source`](https://html.spec.whatwg.org/multipage/embedded-content.html#the-source-element){link-type="element"}\'s
[`src`](https://html.spec.whatwg.org/multipage/embedded-content.html#attr-source-src){link-type="element-attr"}
attribute is a `blob:` URL matching a [MediaSource object
URL](#mediasource-object-url){#ref-for-mediasource-object-url-6
.internalDFN link-type="dfn|abstract-op"} when the respective `src`
attribute was last changed, then that
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-60
.internalDFN link-type="idl" lt="MediaSource"} object is used as the
media provider object and current media resource in the local mode logic
in the [resource fetch
algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource){link-type="dfn"}.
This also means that the remote mode logic that includes observance of
any preload attribute is skipped when a MediaSource object is attached.
Even with that eventual change to
\[[HTML](#bib-html "HTML Standard"){.bibref link-type="biblio"}\], the
execution of the following steps at the beginning of the local mode
logic is still required when the current media resource is a
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-61
.internalDFN link-type="idl" lt="MediaSource"} object.
::::

At the beginning of the \"Otherwise (mode is local)\" section of the
[resource fetch
algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource){link-type="dfn"},
execute the additional steps, below.

:::: {#issue-container-generatedID-22 .note role="note"}
::: {#h-note-22 .note-title .marker role="heading" aria-level="5"}
Note
:::

Relative to the action which triggered the media element\'s resource
selection algorithm, these steps are asynchronous. The [resource fetch
algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource){link-type="dfn"}
is run after the task that invoked the resource selection algorithm is
allowed to continue and a stable state is reached. Implementations may
delay the steps in the \"*Otherwise*\" clause, below, until the
MediaSource object is ready for use.
::::

1.  If the [resource fetch
    algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource){link-type="dfn"}
    was invoked with a media provider object that is a
    [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-62
    .internalDFN link-type="idl" lt="MediaSource"} object, a
    [`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-9
    .internalDFN link-type="idl" lt="MediaSourceHandle"} object or a URL
    record whose object is a
    [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-63
    .internalDFN link-type="idl" lt="MediaSource"} object, then:

    If the media provider object is a URL record whose object is a [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-64 .internalDFN link-type="idl" lt="MediaSource"} that was constructed in a [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface" lt="DedicatedWorkerGlobalScope"}, such as would occur if attempting to use a [MediaSource object URL](#mediasource-object-url){#ref-for-mediasource-object-url-7 .internalDFN link-type="dfn|abstract-op"} from a [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface" lt="DedicatedWorkerGlobalScope"} [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-65 .internalDFN link-type="idl" lt="MediaSource"}
    :   Run the \"*If the media data cannot be fetched at all, due to
        network errors, causing the user agent to give up trying to
        fetch the resource*\" steps of the [resource fetch
        algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource){link-type="dfn"}\'s
        [media data processing steps
        list](https://html.spec.whatwg.org/multipage/media.html#media-data-processing-steps-list).
        ::::: {#issue-container-generatedID-23 .note role="note"}
        ::: {#h-note-23 .note-title .marker role="heading" aria-level="5"}
        Note
        :::

        ::: {}
        This prevents using [MediaSource object
        URLs](#mediasource-object-url){#ref-for-mediasource-object-url-8
        .internalDFN link-type="dfn|abstract-op"} for DedicatedWorker
        MediaSource attachments. Transferring
        [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-66
        .internalDFN link-type="idl" lt="MediaSource"}\'s
        [`handle`](#dom-mediasource-handle){#ref-for-dom-mediasource-handle-3
        .internalDFN link-type="idl"} from the DedicatedWorker to the
        Window context and assigning it to the media element\'s
        [`srcObject`](https://html.spec.whatwg.org/multipage/media.html#dom-media-srcobject){link-type="attribute"}
        attribute is the only way to attach such a MediaSource.
        :::
        :::::

    If the media provider object is a [`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-10 .internalDFN link-type="idl" lt="MediaSourceHandle"} whose [`[[Detached]]`](#dfn-detached){#ref-for-dfn-detached-1 .internalDFN link-type="attribute" lt="[[Detached]]"} internal slot is true
    :   Run the \"*If the media data cannot be fetched at all, due to
        network errors, causing the user agent to give up trying to
        fetch the resource*\" steps of the [resource fetch
        algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource){link-type="dfn"}\'s
        [media data processing steps
        list](https://html.spec.whatwg.org/multipage/media.html#media-data-processing-steps-list).

    If the media provider object is a [`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-11 .internalDFN link-type="idl" lt="MediaSourceHandle"} whose underlying [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-67 .internalDFN link-type="idl" lt="MediaSource"}\'s [`[[has ever been attached]]`](#dfn-has-ever-been-attached){#ref-for-dfn-has-ever-been-attached-1 .internalDFN link-type="attribute" lt="[[has ever been attached]]"} internal slot is true
    :   Run the \"*If the media data cannot be fetched at all, due to
        network errors, causing the user agent to give up trying to
        fetch the resource*\" steps of the [resource fetch
        algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource){link-type="dfn"}\'s
        [media data processing steps
        list](https://html.spec.whatwg.org/multipage/media.html#media-data-processing-steps-list).
        ::::: {#issue-container-generatedID-24 .note role="note"}
        ::: {#h-note-24 .note-title .marker role="heading" aria-level="5"}
        Note
        :::

        ::: {}
        This prevents loading an underlying
        [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-68
        .internalDFN link-type="idl" lt="MediaSource"} more than once
        using a
        [`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-12
        .internalDFN link-type="idl" lt="MediaSourceHandle"}, even if
        the
        [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-69
        .internalDFN link-type="idl" lt="MediaSource"} was constructed
        on
        [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
        lt="Window"} and had been loaded previously using a [MediaSource
        object
        URL](#mediasource-object-url){#ref-for-mediasource-object-url-9
        .internalDFN link-type="dfn|abstract-op"}. This doesn\'t
        preclude subsequent use of a [MediaSource object
        URL](#mediasource-object-url){#ref-for-mediasource-object-url-10
        .internalDFN link-type="dfn|abstract-op"} for a
        [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
        lt="Window"}
        [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-70
        .internalDFN link-type="idl" lt="MediaSource"} from succeeding
        though.
        :::
        :::::

    If [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-16 .internalDFN link-type="idl"} is NOT set to \"[`closed`](#dom-readystate-closed){#ref-for-dom-readystate-closed-8 .internalDFN link-type="idl"}\"
    :   Run the \"*If the media data cannot be fetched at all, due to
        network errors, causing the user agent to give up trying to
        fetch the resource*\" steps of the [resource fetch
        algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource){link-type="dfn"}\'s
        [media data processing steps
        list](https://html.spec.whatwg.org/multipage/media.html#media-data-processing-steps-list).

    Otherwise

    :   1.  Set the
            [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-71
            .internalDFN link-type="idl" lt="MediaSource"}\'s
            [`[[has ever been attached]]`](#dfn-has-ever-been-attached){#ref-for-dfn-has-ever-been-attached-2
            .internalDFN link-type="attribute"
            lt="[[has ever been attached]]"} internal slot to true.

        2.  Set the media element\'s
            [delaying-the-load-event-flag](https://html.spec.whatwg.org/multipage/media.html#delaying-the-load-event-flag)
            to false.

        3.  

            If the [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-72 .internalDFN link-type="idl" lt="MediaSource"} was constructed in a [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface" lt="DedicatedWorkerGlobalScope"}, then setup worker attachment communication and open the [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-73 .internalDFN link-type="idl" lt="MediaSource"}:

            :   1.  Set
                    [`[[channel with worker]]`](#dfn-channel-with-worker){#ref-for-dfn-channel-with-worker-2
                    .internalDFN link-type="attribute"
                    lt="[[channel with worker]]"} to be a new
                    [`MessageChannel`](https://html.spec.whatwg.org/multipage/web-messaging.html#messagechannel){link-type="interface"
                    lt="MessageChannel"}.
                2.  Set
                    [`[[port to worker]]`](#dfn-port-to-worker){#ref-for-dfn-port-to-worker-2
                    .internalDFN link-type="attribute"
                    lt="[[port to worker]]"} to the
                    [`port1`](https://html.spec.whatwg.org/multipage/web-messaging.html#dom-messagechannel-port1){link-type="attribute"}
                    value of
                    [`[[channel with worker]]`](#dfn-channel-with-worker){#ref-for-dfn-channel-with-worker-3
                    .internalDFN link-type="attribute"
                    lt="[[channel with worker]]"}.
                3.  Execute
                    [StructuredSerializeWithTransfer](https://html.spec.whatwg.org/multipage/structured-data.html#structuredserializewithtransfer){link-type="dfn"}
                    with the
                    [`port2`](https://html.spec.whatwg.org/multipage/web-messaging.html#dom-messagechannel-port2){link-type="attribute"}
                    of
                    [`[[channel with worker]]`](#dfn-channel-with-worker){#ref-for-dfn-channel-with-worker-4
                    .internalDFN link-type="attribute"
                    lt="[[channel with worker]]"} as both the value and
                    the sole member of the `transferList`{.variable},
                    and let the result be `serialized port2`{.variable
                    data-type="MessagePort"}.
                4.  [Queue a
                    task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
                    on the
                    [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-74
                    .internalDFN link-type="idl" lt="MediaSource"}\'s
                    [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
                    lt="DedicatedWorkerGlobalScope"} that will
                    1.  Execute
                        [StructuredDeserializeWithTransfer](https://html.spec.whatwg.org/multipage/structured-data.html#structureddeserializewithtransfer){link-type="dfn"}
                        with `serialized port2`{.variable} and
                        [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
                        lt="DedicatedWorkerGlobalScope"}\'s
                        [realm](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object's-realm){link-type="dfn"},
                        and set
                        [`[[port to main]]`](#dfn-port-to-main){#ref-for-dfn-port-to-main-2
                        .internalDFN link-type="attribute"
                        lt="[[port to main]]"} to be the resulting
                        deserialized clone of the transferred
                        [`port2`](https://html.spec.whatwg.org/multipage/web-messaging.html#dom-messagechannel-port2){link-type="attribute"}
                        value of
                        [`[[channel with worker]]`](#dfn-channel-with-worker){#ref-for-dfn-channel-with-worker-5
                        .internalDFN link-type="attribute"
                        lt="[[channel with worker]]"}.
                    2.  Set the
                        [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-17
                        .internalDFN link-type="idl"} attribute to
                        \"[`open`](#dom-readystate-open){#ref-for-dom-readystate-open-12
                        .internalDFN link-type="idl"}\".
                    3.  [Queue a
                        task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
                        to [fire an
                        event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
                        named
                        [`sourceopen`](#dfn-sourceopen){#ref-for-dfn-sourceopen-1
                        .internalDFN link-type="idl" lt="sourceopen"} at
                        the
                        [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-75
                        .internalDFN link-type="idl" lt="MediaSource"}.

            Otherwise, the [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-76 .internalDFN link-type="idl" lt="MediaSource"} was constructed in a [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface" lt="Window"}:

            :   1.  Set
                    [`[[channel with worker]]`](#dfn-channel-with-worker){#ref-for-dfn-channel-with-worker-6
                    .internalDFN link-type="attribute"
                    lt="[[channel with worker]]"} null.
                2.  Set
                    [`[[port to worker]]`](#dfn-port-to-worker){#ref-for-dfn-port-to-worker-3
                    .internalDFN link-type="attribute"
                    lt="[[port to worker]]"} null.
                3.  Set
                    [`[[port to main]]`](#dfn-port-to-main){#ref-for-dfn-port-to-main-3
                    .internalDFN link-type="attribute"
                    lt="[[port to main]]"} null.
                4.  Set the
                    [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-18
                    .internalDFN link-type="idl"} attribute to
                    \"[`open`](#dom-readystate-open){#ref-for-dom-readystate-open-13
                    .internalDFN link-type="idl"}\".
                5.  [Queue a
                    task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
                    to [fire an
                    event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
                    named
                    [`sourceopen`](#dfn-sourceopen){#ref-for-dfn-sourceopen-2
                    .internalDFN link-type="idl" lt="sourceopen"} at the
                    [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-77
                    .internalDFN link-type="idl" lt="MediaSource"}.

        4.  Continue the [resource fetch
            algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource){link-type="dfn"}
            by running the remaining \"*Otherwise (mode is local)*\"
            steps, with these requirements:
            1.  Text in the [resource fetch
                algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource){link-type="dfn"}
                or the [media data processing steps
                list](https://html.spec.whatwg.org/multipage/media.html#media-data-processing-steps-list)
                that refers to \"the download\", \"bytes received\", or
                \"whenever new data for the current media resource
                becomes available\" refers to data passed in via
                [`appendBuffer`](#dom-sourcebuffer-appendbuffer){#ref-for-dom-sourcebuffer-appendbuffer-2
                .internalDFN link-type="idl" lt="appendBuffer()"}`()`.
            2.  References to HTTP in the [resource fetch
                algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource){link-type="dfn"}
                and the [media data processing steps
                list](https://html.spec.whatwg.org/multipage/media.html#media-data-processing-steps-list)
                shall not apply because the HTMLMediaElement does not
                fetch media data via HTTP when a
                [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-78
                .internalDFN link-type="idl" lt="MediaSource"} is
                attached.

:::: {#issue-container-generatedID-25 .note role="note"}
::: {#h-note-25 .note-title .marker role="heading" aria-level="5"}
Note
:::

An attached MediaSource does not use the remote mode steps in the
[resource fetch
algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource){link-type="dfn"},
so the media element will not fire \"suspend\" events. Though future
versions of this specification will likely remove \"progress\" and
\"stalled\" events from a media element with an attached MediaSource,
user agents conforming to this version of the specification may still
fire these two events as these
\[[HTML](#bib-html "HTML Standard"){.bibref link-type="biblio"}\]
references changed after implementations of this specification
stabilized.
::::
::::::::::

:::::: {#mediasource-detach .section}
::: header-wrapper
#### 3.15.2 [Detaching from a media element]{#dfn-detaching-from-a-media-element .dfn .respec-offending-element tabindex="0" aria-haspopup="dialog" dfn-type="dfn" title="Found definition for \"Detaching from a media element\", but nothing links to it. This is usually a spec bug!"} {#x3-15-2-detaching-from-a-media-element}

[](#mediasource-detach){.self-link
aria-label="Permalink for Section 3.15.2"}
:::

The following steps are run in any case where the media element is going
to transition to
[`NETWORK_EMPTY`](https://html.spec.whatwg.org/multipage/media.html#dom-media-network_empty){link-type="const"}
and [queue a
task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
to [fire an
event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
named
[emptied](https://html.spec.whatwg.org/multipage/media.html#event-media-emptied){link-type="event"}
at the media element. These steps *SHOULD* be run right before the
transition.

1.  

    If the [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-79 .internalDFN link-type="idl" lt="MediaSource"} was constructed in a [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface" lt="DedicatedWorkerGlobalScope"}:

    :   1.  Notify the
            [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-80
            .internalDFN link-type="idl" lt="MediaSource"} using an
            internal `detach` message posted to
            [`[[port to worker]]`](#dfn-port-to-worker){#ref-for-dfn-port-to-worker-4
            .internalDFN link-type="attribute" lt="[[port to worker]]"}.
        2.  Set
            [`[[port to worker]]`](#dfn-port-to-worker){#ref-for-dfn-port-to-worker-5
            .internalDFN link-type="attribute" lt="[[port to worker]]"}
            null.
        3.  Set
            [`[[channel with worker]]`](#dfn-channel-with-worker){#ref-for-dfn-channel-with-worker-7
            .internalDFN link-type="attribute"
            lt="[[channel with worker]]"} null.
        4.  The implicit message handler for this `detach` notification
            runs the remainder of these steps in the
            [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
            lt="DedicatedWorkerGlobalScope"}
            [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-81
            .internalDFN link-type="idl" lt="MediaSource"}.

    Otherwise, the [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-82 .internalDFN link-type="idl" lt="MediaSource"} was constructed in a [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface" lt="Window"}:
    :   Continue the remainder of these steps on the
        [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
        lt="Window"}
        [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-83
        .internalDFN link-type="idl" lt="MediaSource"}.

2.  Set
    [`[[port to main]]`](#dfn-port-to-main){#ref-for-dfn-port-to-main-4
    .internalDFN link-type="attribute" lt="[[port to main]]"} null.

3.  Set the
    [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-19
    .internalDFN link-type="idl"} attribute to
    \"[`closed`](#dom-readystate-closed){#ref-for-dom-readystate-closed-9
    .internalDFN link-type="idl"}\".

4.  If [this](https://webidl.spec.whatwg.org/#this){link-type="dfn"} is
    a
    [`ManagedMediaSource`](#dom-managedmediasource){#ref-for-dom-managedmediasource-3
    .internalDFN link-type="idl" lt="ManagedMediaSource"}, then set
    [`streaming`](#dom-managedmediasource-streaming){#ref-for-dom-managedmediasource-streaming-1
    .internalDFN link-type="idl"} attribute to `false`.

5.  Update
    [`duration`](#dom-mediasource-duration){#ref-for-dom-mediasource-duration-2
    .internalDFN link-type="idl"} to NaN.

6.  Remove all the
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-27
    .internalDFN link-type="idl" lt="SourceBuffer"} objects from
    [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-7
    .internalDFN link-type="idl"}.

7.  [Queue a
    task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
    to [fire an
    event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
    named
    [`removesourcebuffer`](#dfn-removesourcebuffer){#ref-for-dfn-removesourcebuffer-3
    .internalDFN link-type="idl" lt="removesourcebuffer"} at
    [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-8
    .internalDFN link-type="idl"}.

8.  Remove all the
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-28
    .internalDFN link-type="idl" lt="SourceBuffer"} objects from
    [`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-16
    .internalDFN link-type="idl"}.

9.  [Queue a
    task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
    to [fire an
    event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
    named
    [`removesourcebuffer`](#dfn-removesourcebuffer){#ref-for-dfn-removesourcebuffer-4
    .internalDFN link-type="idl" lt="removesourcebuffer"} at
    [`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-17
    .internalDFN link-type="idl"}.

10. [Queue a
    task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
    to [fire an
    event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
    named [`sourceclose`](#dfn-sourceclose){#ref-for-dfn-sourceclose-1
    .internalDFN link-type="idl" lt="sourceclose"} at the
    [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-84
    .internalDFN link-type="idl" lt="MediaSource"}.

:::: {#issue-container-generatedID-26 .note role="note"}
::: {#h-note-26 .note-title .marker role="heading" aria-level="5"}
Note
:::

Going forward, this algorithm is intended to be externally called and
run in any case where the attached
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-85
.internalDFN link-type="idl" lt="MediaSource"}, if any, must be detached
from the media element. It *MAY* be called on HTMLMediaElement
\[[HTML](#bib-html "HTML Standard"){.bibref link-type="biblio"}\]
operations like load() and [resource fetch
algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource){link-type="dfn"}
failures in addition to, or in place of, when the media element
transitions to
[`NETWORK_EMPTY`](https://html.spec.whatwg.org/multipage/media.html#dom-media-network_empty){link-type="const"}.
Resource fetch algorithm failures are those which abort either the
resource fetch algorithm or the resource selection algorithm, with the
exception that the \"Final step\"
\[[HTML](#bib-html "HTML Standard"){.bibref link-type="biblio"}\] is not
considered a failure that triggers detachment.
::::
::::::

:::: {#mediasource-seeking .section}
::: header-wrapper
#### 3.15.3 [Seeking]{#dfn-seeking .dfn .respec-offending-element tabindex="0" aria-haspopup="dialog" dfn-type="dfn" title="Found definition for \"Seeking\", but nothing links to it. This is usually a spec bug!"} {#x3-15-3-seeking}

[](#mediasource-seeking){.self-link
aria-label="Permalink for Section 3.15.3"}
:::

Run the following steps as part of the \"*Wait until the user agent has
established whether or not the media data for the new playback position
is available, and, if it is, until it has decoded enough data to play
back that position\"* step of the [seek
algorithm](https://html.spec.whatwg.org/multipage/media.html#dom-media-seek):

1.  :::: {#issue-container-generatedID-27 .note role="note"}
    ::: {#h-note-27 .note-title .marker role="heading" aria-level="5"}
    Note
    :::

    The media element looks for [media
    segments](#dfn-media-segment){#ref-for-dfn-media-segment-4
    .internalDFN link-type="dfn|abstract-op"} containing the
    `new playback position`{.variable data-type="double"} in each
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-29
    .internalDFN link-type="idl" lt="SourceBuffer"} object in
    [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-9
    .internalDFN link-type="idl"}. Any position within a
    [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface"
    lt="TimeRanges"} in the current value of the
    [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
    lt="HTMLMediaElement"}\'s
    [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered){link-type="attribute"}
    attribute has all necessary media segments buffered for that
    position.
    ::::

    If `new playback position`{.variable} is not in any [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface" lt="TimeRanges"} of [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface" lt="HTMLMediaElement"}\'s [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered){link-type="attribute"}

    :   1.  If the
            [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
            lt="HTMLMediaElement"}\'s
            [`readyState`](#dom-readystate){#ref-for-dom-readystate-2
            .internalDFN link-type="idl"} attribute is greater than
            [`HAVE_METADATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_metadata){link-type="const"},
            then set the
            [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
            lt="HTMLMediaElement"}\'s
            [`readyState`](#dom-readystate){#ref-for-dom-readystate-3
            .internalDFN link-type="idl"} attribute to
            [`HAVE_METADATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_metadata){link-type="const"}.

            :::: {#issue-container-generatedID-28 .note role="note"}
            ::: {#h-note-28 .note-title .marker role="heading" aria-level="5"}
            Note
            :::

            Per
            [`HTMLMediaElement ready states`](https://html.spec.whatwg.org/multipage/media.html#ready-states)
            \[[HTML](#bib-html "HTML Standard"){.bibref
            link-type="biblio"}\] logic,
            [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
            lt="HTMLMediaElement"}\'s
            [`readyState`](#dom-readystate){#ref-for-dom-readystate-4
            .internalDFN link-type="idl"} changes may trigger events on
            the HTMLMediaElement.
            ::::
        2.  The media element waits until an
            [`appendBuffer`](#dom-sourcebuffer-appendbuffer){#ref-for-dom-sourcebuffer-appendbuffer-3
            .internalDFN link-type="idl" lt="appendBuffer()"}`()` call
            causes the [coded frame
            processing](#dfn-coded-frame-processing){#ref-for-dfn-coded-frame-processing-2
            .internalDFN link-type="dfn|abstract-op"} algorithm to set
            the
            [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
            lt="HTMLMediaElement"}\'s
            [`readyState`](#dom-readystate){#ref-for-dom-readystate-5
            .internalDFN link-type="idl"} attribute to a value greater
            than
            [`HAVE_METADATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_metadata){link-type="const"}.

            :::: {#issue-container-generatedID-29 .note role="note"}
            ::: {#h-note-29 .note-title .marker role="heading" aria-level="5"}
            Note
            :::

            The web application can use
            [`buffered`](#dom-sourcebuffer-buffered){#ref-for-dom-sourcebuffer-buffered-1
            .internalDFN link-type="idl"} and
            [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
            lt="HTMLMediaElement"}\'s
            [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered){link-type="attribute"}
            to determine what the media element needs to resume
            playback.
            ::::

    Otherwise
    :   Continue
        :::: {#issue-container-generatedID-30 .note role="note"}
        ::: {#h-note-30 .note-title .marker role="heading" aria-level="5"}
        Note
        :::

        If the
        [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-20
        .internalDFN link-type="idl"} attribute is
        \"[`ended`](#dom-readystate-ended){#ref-for-dom-readystate-ended-5
        .internalDFN link-type="idl"}\" and the
        `new playback position`{.variable} is within a
        [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface"
        lt="TimeRanges"} currently in
        [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
        lt="HTMLMediaElement"}\'s
        [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered){link-type="attribute"},
        then the seek operation must continue to completion here even if
        one or more currently selected or enabled track buffers\'
        largest range end timestamp is less than
        `new playback position`{.variable}. This condition should only
        occur due to logic in
        [`buffered`](#dom-sourcebuffer-buffered){#ref-for-dom-sourcebuffer-buffered-2
        .internalDFN link-type="idl"} when
        [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-21
        .internalDFN link-type="idl"} is
        \"[`ended`](#dom-readystate-ended){#ref-for-dom-readystate-ended-6
        .internalDFN link-type="idl"}\".
        ::::

2.  The media element resets all decoders and initializes each one with
    data from the appropriate [initialization
    segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-4
    .internalDFN link-type="dfn|abstract-op"}.

3.  The media element feeds [coded
    frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-10 .internalDFN
    link-type="dfn|abstract-op"} from the [active track
    buffers](#dfn-active-track-buffers){#ref-for-dfn-active-track-buffers-1
    .internalDFN link-type="dfn|abstract-op"} into the decoders starting
    with the closest [random access
    point](#random-access-point){#ref-for-random-access-point-1
    .internalDFN link-type="dfn|abstract-op"} before the
    `new playback position`{.variable}.

4.  Resume the [seek
    algorithm](https://html.spec.whatwg.org/multipage/media.html#dom-media-seek)
    at the \"*Await a stable state*\" step.
::::

:::::::: {#buffer-monitoring .section}
::: header-wrapper
#### 3.15.4 [SourceBuffer Monitoring]{#dfn-sourcebuffer-monitoring .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"} {#x3-15-4-sourcebuffer-monitoring}

[](#buffer-monitoring){.self-link
aria-label="Permalink for Section 3.15.4"}
:::

The following steps are periodically run during playback to make sure
that all of the
[`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-30
.internalDFN link-type="idl" lt="SourceBuffer"} objects in
[`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-10
.internalDFN link-type="idl"} have [enough data to ensure uninterrupted
playback](#enough-data){#ref-for-enough-data-1 .internalDFN
link-type="dfn|abstract-op"}. Changes to
[`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-11
.internalDFN link-type="idl"} also cause these steps to run because they
affect the conditions that trigger state transitions.

Having [enough data to ensure uninterrupted playback]{#enough-data .dfn
tabindex="0" aria-haspopup="dialog" dfn-type="dfn"} is an implementation
specific condition where the user agent determines that it currently has
enough data to play the presentation without stalling for a meaningful
period of time. This condition is constantly evaluated to determine when
to transition the media element into and out of the
[`HAVE_ENOUGH_DATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_enough_data){link-type="const"}
ready state. These transitions indicate when the user agent believes it
has enough data buffered or it needs more data respectively.

:::: {#issue-container-generatedID-31 .note role="note"}
::: {#h-note-31 .note-title .marker role="heading" aria-level="5"}
Note
:::

An implementation *MAY* choose to use bytes buffered, time buffered, the
append rate, or any other metric it sees fit to determine when it has
enough data. The metrics used *MAY* change during playback so web
applications *SHOULD* only rely on the value of
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"}\'s
[`readyState`](#dom-readystate){#ref-for-dom-readystate-6 .internalDFN
link-type="idl"} to determine whether more data is needed or not.
::::

:::: {#issue-container-generatedID-32 .note role="note"}
::: {#h-note-32 .note-title .marker role="heading" aria-level="5"}
Note
:::

When the media element needs more data, the user agent *SHOULD*
transition it from
[`HAVE_ENOUGH_DATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_enough_data){link-type="const"}
to
[`HAVE_FUTURE_DATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_future_data){link-type="const"}
early enough for a web application to be able to respond without causing
an interruption in playback. For example, transitioning when the current
playback position is 500ms before the end of the buffered data gives the
application roughly 500ms to append more data before playback stalls.
::::

If the [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface" lt="HTMLMediaElement"}\'s [`readyState`](#dom-readystate){#ref-for-dom-readystate-7 .internalDFN link-type="idl"} attribute equals [`HAVE_NOTHING`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_nothing){link-type="const"}:

:   1.  Abort these steps.

If [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface" lt="HTMLMediaElement"}\'s [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered){link-type="attribute"} does not contain a [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface" lt="TimeRanges"} for the current playback position:

:   1.  Set the
        [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
        lt="HTMLMediaElement"}\'s
        [`readyState`](#dom-readystate){#ref-for-dom-readystate-8
        .internalDFN link-type="idl"} attribute to
        [`HAVE_METADATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_metadata){link-type="const"}.

        :::: {#issue-container-generatedID-33 .note role="note"}
        ::: {#h-note-33 .note-title .marker role="heading" aria-level="5"}
        Note
        :::

        Per
        [`HTMLMediaElement ready states`](https://html.spec.whatwg.org/multipage/media.html#ready-states)
        \[[HTML](#bib-html "HTML Standard"){.bibref
        link-type="biblio"}\] logic,
        [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
        lt="HTMLMediaElement"}\'s
        [`readyState`](#dom-readystate){#ref-for-dom-readystate-9
        .internalDFN link-type="idl"} changes may trigger events on the
        HTMLMediaElement.
        ::::
    2.  Abort these steps.

If [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface" lt="HTMLMediaElement"}\'s [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered){link-type="attribute"} contains a [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface" lt="TimeRanges"} that includes the current playback position and [enough data to ensure uninterrupted playback](#enough-data){#ref-for-enough-data-2 .internalDFN link-type="dfn|abstract-op"}:

:   1.  Set the
        [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
        lt="HTMLMediaElement"}\'s
        [`readyState`](#dom-readystate){#ref-for-dom-readystate-10
        .internalDFN link-type="idl"} attribute to
        [`HAVE_ENOUGH_DATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_enough_data){link-type="const"}.

        :::: {#issue-container-generatedID-34 .note role="note"}
        ::: {#h-note-34 .note-title .marker role="heading" aria-level="5"}
        Note
        :::

        Per
        [`HTMLMediaElement ready states`](https://html.spec.whatwg.org/multipage/media.html#ready-states)
        \[[HTML](#bib-html "HTML Standard"){.bibref
        link-type="biblio"}\] logic,
        [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
        lt="HTMLMediaElement"}\'s
        [`readyState`](#dom-readystate){#ref-for-dom-readystate-11
        .internalDFN link-type="idl"} changes may trigger events on the
        HTMLMediaElement.
        ::::
    2.  Playback may resume at this point if it was previously suspended
        by a transition to
        [`HAVE_CURRENT_DATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_current_data){link-type="const"}.
    3.  Abort these steps.

If [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface" lt="HTMLMediaElement"}\'s [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered){link-type="attribute"} contains a [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface" lt="TimeRanges"} that includes the current playback position and some time beyond the current playback position, then run the following steps:

:   1.  Set the
        [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
        lt="HTMLMediaElement"}\'s
        [`readyState`](#dom-readystate){#ref-for-dom-readystate-12
        .internalDFN link-type="idl"} attribute to
        [`HAVE_FUTURE_DATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_future_data){link-type="const"}.

        :::: {#issue-container-generatedID-35 .note role="note"}
        ::: {#h-note-35 .note-title .marker role="heading" aria-level="5"}
        Note
        :::

        Per
        [`HTMLMediaElement ready states`](https://html.spec.whatwg.org/multipage/media.html#ready-states)
        \[[HTML](#bib-html "HTML Standard"){.bibref
        link-type="biblio"}\] logic,
        [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
        lt="HTMLMediaElement"}\'s
        [`readyState`](#dom-readystate){#ref-for-dom-readystate-13
        .internalDFN link-type="idl"} changes may trigger events on the
        HTMLMediaElement.
        ::::
    2.  Playback may resume at this point if it was previously suspended
        by a transition to
        [`HAVE_CURRENT_DATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_current_data){link-type="const"}.
    3.  Abort these steps.

If [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface" lt="HTMLMediaElement"}\'s [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered){link-type="attribute"} contains a [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface" lt="TimeRanges"} that ends at the current playback position and does not have a range covering the time immediately after the current position:

:   1.  Set the
        [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
        lt="HTMLMediaElement"}\'s
        [`readyState`](#dom-readystate){#ref-for-dom-readystate-14
        .internalDFN link-type="idl"} attribute to
        [`HAVE_CURRENT_DATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_current_data){link-type="const"}.

        :::: {#issue-container-generatedID-36 .note role="note"}
        ::: {#h-note-36 .note-title .marker role="heading" aria-level="5"}
        Note
        :::

        Per
        [`HTMLMediaElement ready states`](https://html.spec.whatwg.org/multipage/media.html#ready-states)
        \[[HTML](#bib-html "HTML Standard"){.bibref
        link-type="biblio"}\] logic,
        [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
        lt="HTMLMediaElement"}\'s
        [`readyState`](#dom-readystate){#ref-for-dom-readystate-15
        .internalDFN link-type="idl"} changes may trigger events on the
        HTMLMediaElement.
        ::::
    2.  Playback is suspended at this point since the media element
        doesn\'t have enough data to advance the [media
        timeline](https://html.spec.whatwg.org/multipage/media.html#media-timeline).
    3.  Abort these steps.
::::::::

:::: {#active-source-buffer-changes .section}
::: header-wrapper
#### 3.15.5 [Changes to selected/enabled track state]{#dfn-changes-to-selected-enabled-track-state .dfn .respec-offending-element tabindex="0" aria-haspopup="dialog" dfn-type="dfn" title="Found definition for \"Changes to selected/enabled track state\", but nothing links to it. This is usually a spec bug!"} {#x3-15-5-changes-to-selected-enabled-track-state}

[](#active-source-buffer-changes){.self-link
aria-label="Permalink for Section 3.15.5"}
:::

During playback
[`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-12
.internalDFN link-type="idl"} needs to be updated if the
[`selected`](https://html.spec.whatwg.org/multipage/media.html#dom-videotrack-selected){link-type="attribute"}
video track, the
[`enabled`](https://html.spec.whatwg.org/multipage/media.html#dom-audiotrack-enabled){link-type="attribute"}
audio track(s), or a text track
[`mode`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-mode){link-type="attribute"}
changes. When one or more of these changes occur the following steps
need to be followed. Also, when
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-86
.internalDFN link-type="idl" lt="MediaSource"} was constructed in a
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
lt="DedicatedWorkerGlobalScope"}, then each change that occurs to a
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
lt="Window"} mirror of a track created previously by the implicit
handler for the internal `create track mirror` message *MUST* also be
made to the corresponding
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
lt="DedicatedWorkerGlobalScope"} track using an internal
`update track state` message posted to
[`[[port to worker]]`](#dfn-port-to-worker){#ref-for-dfn-port-to-worker-6
.internalDFN link-type="attribute" lt="[[port to worker]]"} whose
implicit handler makes the change and runs the following steps.
Likewise, each change that occurs to a
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
lt="DedicatedWorkerGlobalScope"} track *MUST* also be made to the
corresponding
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
lt="Window"} mirror of the track using an internal `update track state`
message posted to
[`[[port to main]]`](#dfn-port-to-main){#ref-for-dfn-port-to-main-5
.internalDFN link-type="attribute" lt="[[port to main]]"} whose implicit
handler makes the change to the mirror.

If the selected video track changes, then run the following steps:

:   1.  If the
        [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-31
        .internalDFN link-type="idl" lt="SourceBuffer"} associated with
        the previously selected video track is not associated with any
        other enabled tracks, run the following steps:
        1.  Remove the
            [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-32
            .internalDFN link-type="idl" lt="SourceBuffer"} from
            [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-13
            .internalDFN link-type="idl"}.
        2.  [Queue a
            task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
            to [fire an
            event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
            named
            [`removesourcebuffer`](#dfn-removesourcebuffer){#ref-for-dfn-removesourcebuffer-5
            .internalDFN link-type="idl" lt="removesourcebuffer"} at
            [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-14
            .internalDFN link-type="idl"}
    2.  If the
        [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-33
        .internalDFN link-type="idl" lt="SourceBuffer"} associated with
        the newly selected video track is not already in
        [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-15
        .internalDFN link-type="idl"}, run the following steps:
        1.  Add the
            [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-34
            .internalDFN link-type="idl" lt="SourceBuffer"} to
            [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-16
            .internalDFN link-type="idl"}.
        2.  [Queue a
            task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
            to [fire an
            event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
            named
            [`addsourcebuffer`](#dfn-addsourcebuffer){#ref-for-dfn-addsourcebuffer-2
            .internalDFN link-type="idl" lt="addsourcebuffer"} at
            [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-17
            .internalDFN link-type="idl"}

If an audio track becomes disabled and the [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-35 .internalDFN link-type="idl" lt="SourceBuffer"} associated with this track is not associated with any other enabled or selected track, then run the following steps:

:   1.  Remove the
        [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-36
        .internalDFN link-type="idl" lt="SourceBuffer"} associated with
        the audio track from
        [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-18
        .internalDFN link-type="idl"}
    2.  [Queue a
        task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
        to [fire an
        event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
        named
        [`removesourcebuffer`](#dfn-removesourcebuffer){#ref-for-dfn-removesourcebuffer-6
        .internalDFN link-type="idl" lt="removesourcebuffer"} at
        [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-19
        .internalDFN link-type="idl"}

If an audio track becomes enabled and the [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-37 .internalDFN link-type="idl" lt="SourceBuffer"} associated with this track is not already in [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-20 .internalDFN link-type="idl"}, then run the following steps:

:   1.  Add the
        [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-38
        .internalDFN link-type="idl" lt="SourceBuffer"} associated with
        the audio track to
        [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-21
        .internalDFN link-type="idl"}
    2.  [Queue a
        task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
        to [fire an
        event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
        named
        [`addsourcebuffer`](#dfn-addsourcebuffer){#ref-for-dfn-addsourcebuffer-3
        .internalDFN link-type="idl" lt="addsourcebuffer"} at
        [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-22
        .internalDFN link-type="idl"}

If a text track [`mode`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-mode){link-type="attribute"} becomes [`"disabled"`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-disabled) and the [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-39 .internalDFN link-type="idl" lt="SourceBuffer"} associated with this track is not associated with any other enabled or selected track, then run the following steps:

:   1.  Remove the
        [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-40
        .internalDFN link-type="idl" lt="SourceBuffer"} associated with
        the text track from
        [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-23
        .internalDFN link-type="idl"}
    2.  [Queue a
        task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
        to [fire an
        event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
        named
        [`removesourcebuffer`](#dfn-removesourcebuffer){#ref-for-dfn-removesourcebuffer-7
        .internalDFN link-type="idl" lt="removesourcebuffer"} at
        [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-24
        .internalDFN link-type="idl"}

If a text track [`mode`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-mode){link-type="attribute"} becomes [`"showing"`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-showing) or [`"hidden"`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-hidden) and the [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-41 .internalDFN link-type="idl" lt="SourceBuffer"} associated with this track is not already in [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-25 .internalDFN link-type="idl"}, then run the following steps:

:   1.  Add the
        [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-42
        .internalDFN link-type="idl" lt="SourceBuffer"} associated with
        the text track to
        [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-26
        .internalDFN link-type="idl"}
    2.  [Queue a
        task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
        to [fire an
        event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
        named
        [`addsourcebuffer`](#dfn-addsourcebuffer){#ref-for-dfn-addsourcebuffer-4
        .internalDFN link-type="idl" lt="addsourcebuffer"} at
        [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-27
        .internalDFN link-type="idl"}
::::

:::: {#duration-change-algorithm .section}
::: header-wrapper
#### 3.15.6 [Duration change]{#dfn-duration-change .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"} {#x3-15-6-duration-change}

[](#duration-change-algorithm){.self-link
aria-label="Permalink for Section 3.15.6"}
:::

Follow these steps when
[`duration`](#dom-mediasource-duration){#ref-for-dom-mediasource-duration-3
.internalDFN link-type="idl"} needs to change to a
`new duration`{.variable data-type="unrestricted double"}.

1.  If the current value of
    [`duration`](#dom-mediasource-duration){#ref-for-dom-mediasource-duration-4
    .internalDFN link-type="idl"} is equal to `new duration`{.variable},
    then return.
2.  If `new duration`{.variable} is less than the highest [presentation
    timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-11
    .internalDFN link-type="dfn|abstract-op"} of any buffered [coded
    frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-11 .internalDFN
    link-type="dfn|abstract-op"} for all
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-43
    .internalDFN link-type="idl" lt="SourceBuffer"} objects in
    [`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-18
    .internalDFN link-type="idl"}, then throw an
    [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror){link-type="exception"
    lt="InvalidStateError"} exception and abort these steps.

    :::: {#issue-container-generatedID-37 .note role="note"}
    ::: {#h-note-37 .note-title .marker role="heading" aria-level="5"}
    Note
    :::

    Duration reductions that would truncate currently buffered media are
    disallowed. When truncation is necessary, use
    [`remove`](#dom-sourcebuffer-remove){#ref-for-dom-sourcebuffer-remove-1
    .internalDFN link-type="idl" lt="remove()"}`()` to reduce the
    buffered range before updating
    [`duration`](#dom-mediasource-duration){#ref-for-dom-mediasource-duration-5
    .internalDFN link-type="idl"}.
    ::::
3.  Let `highest end time`{.variable data-type="unrestricted double"} be
    the largest [track buffer
    ranges](#track-buffer-ranges){#ref-for-track-buffer-ranges-1
    .internalDFN link-type="dfn|abstract-op"} end time across all the
    [track buffers](#track-buffer){#ref-for-track-buffer-2 .internalDFN
    link-type="dfn|abstract-op"} across all
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-44
    .internalDFN link-type="idl" lt="SourceBuffer"} objects in
    [`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-19
    .internalDFN link-type="idl"}.
4.  If `new duration`{.variable} is less than
    `highest end time`{.variable data-type="unrestricted double"}, then

    :::: {#issue-container-generatedID-38 .note role="note"}
    ::: {#h-note-38 .note-title .marker role="heading" aria-level="5"}
    Note
    :::

    This condition can occur because the [coded frame
    removal](#dfn-coded-frame-removal){#ref-for-dfn-coded-frame-removal-1
    .internalDFN link-type="dfn|abstract-op"} algorithm preserves coded
    frames that start before the start of the removal range.
    ::::

    1.  Update `new duration`{.variable} to equal
        `highest end time`{.variable data-type="unrestricted double"}.
5.  Update
    [`duration`](#dom-mediasource-duration){#ref-for-dom-mediasource-duration-6
    .internalDFN link-type="idl"} to `new duration`{.variable}.
6.  Use the [mirror if
    necessary](#dfn-mirror-if-necessary){#ref-for-dfn-mirror-if-necessary-4
    .internalDFN link-type="dfn|abstract-op"} algorithm to run the
    following steps in
    [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
    lt="Window"} to update the media element\'s duration:
    1.  Update the media element\'s
        [`duration`](https://html.spec.whatwg.org/multipage/media.html#dom-media-duration){link-type="attribute"}
        to `new duration`{.variable}.
    2.  Run the [HTMLMediaElement duration change
        algorithm](https://html.spec.whatwg.org/multipage/media.html#durationChange).
::::

:::: {#end-of-stream-algorithm .section}
::: header-wrapper
#### 3.15.7 [End of stream]{#dfn-end-of-stream .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"} {#x3-15-7-end-of-stream}

[](#end-of-stream-algorithm){.self-link
aria-label="Permalink for Section 3.15.7"}
:::

This algorithm gets called when the application signals the end of
stream via an
[`endOfStream`](#dom-mediasource-endofstream){#ref-for-dom-mediasource-endofstream-4
.internalDFN link-type="idl" lt="endOfStream()"}`()` call or an
algorithm needs to signal a decode error. This algorithm takes an
`error`{.variable data-type="EndOfStreamError"} parameter that indicates
whether an error will be signalled.

1.  Change the
    [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-22
    .internalDFN link-type="idl"} attribute value to
    \"[`ended`](#dom-readystate-ended){#ref-for-dom-readystate-ended-7
    .internalDFN link-type="idl"}\".

2.  [Queue a
    task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
    to [fire an
    event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
    named [`sourceended`](#dfn-sourceended){#ref-for-dfn-sourceended-1
    .internalDFN link-type="idl" lt="sourceended"} at the
    [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-87
    .internalDFN link-type="idl" lt="MediaSource"}.

3.  

    If `error`{.variable data-type="EndOfStreamError"} is not set

    :   1.  Run the [duration
            change](#dfn-duration-change){#ref-for-dfn-duration-change-3
            .internalDFN link-type="dfn|abstract-op"} algorithm with
            `new duration`{.variable data-type="unrestricted
                                double"} set to the largest [track
            buffer
            ranges](#track-buffer-ranges){#ref-for-track-buffer-ranges-2
            .internalDFN link-type="dfn|abstract-op"} end time across
            all the [track
            buffers](#track-buffer){#ref-for-track-buffer-3 .internalDFN
            link-type="dfn|abstract-op"} across all
            [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-45
            .internalDFN link-type="idl" lt="SourceBuffer"} objects in
            [`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-20
            .internalDFN link-type="idl"}.

            :::: {#issue-container-generatedID-39 .note role="note"}
            ::: {#h-note-39 .note-title .marker role="heading" aria-level="5"}
            Note
            :::

            This allows the duration to properly reflect the end of the
            appended media segments. For example, if the duration was
            explicitly set to 10 seconds and only media segments for 0
            to 5 seconds were appended before endOfStream() was called,
            then the duration will get updated to 5 seconds.
            ::::
        2.  Notify the media element that it now has all of the media
            data.

    If `error`{.variable data-type="EndOfStreamError"} is set to \"[`network`](#dom-endofstreamerror-network){#ref-for-dom-endofstreamerror-network-2 .internalDFN link-type="idl"}\"
    :   Use the [mirror if
        necessary](#dfn-mirror-if-necessary){#ref-for-dfn-mirror-if-necessary-5
        .internalDFN link-type="dfn|abstract-op"} algorithm to run the
        following steps in
        [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
        lt="Window"}:

        If the [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface" lt="HTMLMediaElement"}\'s [`readyState`](#dom-readystate){#ref-for-dom-readystate-16 .internalDFN link-type="idl"} attribute equals [`HAVE_NOTHING`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_nothing){link-type="const"}
        :   Run the \"*If the media data cannot be fetched at all, due
            to network errors, causing the user agent to give up trying
            to fetch the resource*\" steps of the [resource fetch
            algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource){link-type="dfn"}\'s
            [media data processing steps
            list](https://html.spec.whatwg.org/multipage/media.html#media-data-processing-steps-list).

        If the [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface" lt="HTMLMediaElement"}\'s [`readyState`](#dom-readystate){#ref-for-dom-readystate-17 .internalDFN link-type="idl"} attribute is greater than [`HAVE_NOTHING`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_nothing){link-type="const"}
        :   Run the \"*If the connection is interrupted after some media
            data has been received, causing the user agent to give up
            trying to fetch the resource*\" steps of the [resource fetch
            algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource){link-type="dfn"}\'s
            [media data processing steps
            list](https://html.spec.whatwg.org/multipage/media.html#media-data-processing-steps-list).

    If `error`{.variable data-type="EndOfStreamError"} is set to \"[`decode`](#dom-endofstreamerror-decode){#ref-for-dom-endofstreamerror-decode-2 .internalDFN link-type="idl"}\"
    :   Use the [mirror if
        necessary](#dfn-mirror-if-necessary){#ref-for-dfn-mirror-if-necessary-6
        .internalDFN link-type="dfn|abstract-op"} algorithm to run the
        following steps in
        [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
        lt="Window"}:

        If the [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface" lt="HTMLMediaElement"}\'s [`readyState`](#dom-readystate){#ref-for-dom-readystate-18 .internalDFN link-type="idl"} attribute equals [`HAVE_NOTHING`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_nothing){link-type="const"}
        :   Run the \"*If the media data can be fetched but is found by
            inspection to be in an unsupported format, or can otherwise
            not be rendered at all*\" steps of the [resource fetch
            algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource){link-type="dfn"}\'s
            [media data processing steps
            list](https://html.spec.whatwg.org/multipage/media.html#media-data-processing-steps-list).

        If the [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface" lt="HTMLMediaElement"}\'s [`readyState`](#dom-readystate){#ref-for-dom-readystate-19 .internalDFN link-type="idl"} attribute is greater than [`HAVE_NOTHING`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_nothing){link-type="const"}
        :   Run the [media data is
            corrupted](https://html.spec.whatwg.org/multipage/media.html#fatal-decode-error)
            steps of the [resource fetch
            algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource){link-type="dfn"}\'s
            [media data processing steps
            list](https://html.spec.whatwg.org/multipage/media.html#media-data-processing-steps-list).
::::

:::: {#mirror-if-necessary-algorithm .section}
::: header-wrapper
#### 3.15.8 [Mirror if necessary]{#dfn-mirror-if-necessary .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"} {#x3-15-8-mirror-if-necessary}

[](#mirror-if-necessary-algorithm){.self-link
aria-label="Permalink for Section 3.15.8"}
:::

This algorithm is used to run steps on
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
lt="Window"} from a
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-88
.internalDFN link-type="idl" lt="MediaSource"} attached from either the
same
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
lt="Window"} or from a
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
lt="DedicatedWorkerGlobalScope"}, usually to update the state of the
attached
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"}. This algorithm takes a `steps`{.variable}
parameter that lists the steps to run on
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
lt="Window"}.

If the [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-89 .internalDFN link-type="idl" lt="MediaSource"} was constructed in a [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface" lt="DedicatedWorkerGlobalScope"}:
:   Post an internal `mirror on window` message to
    [`[[port to main]]`](#dfn-port-to-main){#ref-for-dfn-port-to-main-6
    .internalDFN link-type="attribute" lt="[[port to main]]"} whose
    implicit handler in
    [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
    lt="Window"} will run `steps`{.variable}. Return control to the
    caller without awaiting that handler\'s receipt of the message.
    ::::: {#issue-container-generatedID-40 .note role="note"}
    ::: {#h-note-40 .note-title .marker role="heading" aria-level="5"}
    Note
    :::

    ::: {}
    The purpose of the mirror message mechanism is to ensure that:
    1.  `steps`{.variable} run asynchronously as their own task on
        [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
        lt="Window"} rather than these `steps`{.variable} somehow
        happening in the middle of some other
        [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
        lt="Window"} task\'s execution, and
    2.  `steps`{.variable} are run without blocking the synchronous
        execution and return of this algorithm on
        [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
        lt="DedicatedWorkerGlobalScope"}.
    :::
    :::::

Otherwise:
:   Run `steps`{.variable}.
::::
::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::: {#mediasourcehandle .section}
::: header-wrapper
## 4. [`MediaSourceHandle`]{#dom-mediasourcehandle .dfn export="" dfn-type="interface" idl="interface" data-title="MediaSourceHandle" dfn-for="" tabindex="0" aria-haspopup="dialog"} interface {#x4-mediasourcehandle-interface}

[](#mediasourcehandle){.self-link aria-label="Permalink for Section 4."}
:::

The
[`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-13
.internalDFN link-type="idl" lt="MediaSourceHandle"} interface
represents a proxy for a
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-90
.internalDFN link-type="idl" lt="MediaSource"} object that is useful for
attaching a
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
lt="DedicatedWorkerGlobalScope"}
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-91
.internalDFN link-type="idl" lt="MediaSource"} to a
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
lt="Window"}
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"} using
[`srcObject`](https://html.spec.whatwg.org/multipage/media.html#dom-media-srcobject){link-type="attribute"}
as described in the [attaching to a media
element](#dfn-attaching-to-a-media-element){#ref-for-dfn-attaching-to-a-media-element-3
.internalDFN link-type="dfn|abstract-op"} algorithm.

:::: {#issue-container-generatedID-41 .note role="note"}
::: {#h-note-41 .note-title .marker role="heading" aria-level="3"}
Note
:::

This distinct object is necessary to attach a cross-context
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-92
.internalDFN link-type="idl" lt="MediaSource"} to a media element
because [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-93
.internalDFN link-type="idl" lt="MediaSource"} objects themselves are
not transferable since they are event targets.
::::

Each
[`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-14
.internalDFN link-type="idl" lt="MediaSourceHandle"} object has a
[\[\[has ever been assigned as
srcobject\]\]]{#dfn-has-ever-been-assigned-as-srcobject .dfn
dfn-for="MediaSourceHandle" idl="" noexport="" dfn-type="attribute"
tabindex="0" aria-haspopup="dialog"} internal slot that stores a
[`boolean`](https://webidl.spec.whatwg.org/#idl-boolean){link-type="interface"
lt="boolean"}. It is initialized to false when the
[`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-15
.internalDFN link-type="idl" lt="MediaSourceHandle"} object is created,
is set true in the extended
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"}\'s
[`srcObject`](https://html.spec.whatwg.org/multipage/media.html#dom-media-srcobject){link-type="attribute"}
setter as described in section [10. HTMLMediaElement
Extensions](#htmlmediaelement-extensions){.sec-ref
matched-text="[[[#htmlmediaelement-extensions]]]"}, and if true,
prevents successful transfer of the
[`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-16
.internalDFN link-type="idl" lt="MediaSourceHandle"} as described in
section [4.1 Transfer](#transfer){.sec-ref
matched-text="[[[#transfer]]]"}.

[`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-17
.internalDFN link-type="idl" lt="MediaSourceHandle"} objects are
[`Transferable`](https://html.spec.whatwg.org/multipage/structured-data.html#transferable){link-type="extended-attribute"
lt="Transferable"}, each having a [\[\[Detached\]\]]{#dfn-detached .dfn
dfn-for="MediaSourceHandle" idl="" noexport="" dfn-type="attribute"
tabindex="0" aria-haspopup="dialog"} internal slot that is used to
ensure that once the handle object instance has been transferred, that
instance cannot be transferred again.

``` {#webidl-1737388085 .idl .def}
WebIDL[Transferable, Exposed=(Window,DedicatedWorker)]
interface MediaSourceHandle {};
```

:::::::::: {#transfer .section}
::: header-wrapper
### 4.1 Transfer {#x4-1-transfer}

[](#transfer){.self-link aria-label="Permalink for Section 4.1"}
:::

The
[`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-19
.internalDFN link-type="idl" lt="MediaSourceHandle"} [transfer
steps](https://html.spec.whatwg.org/multipage/structured-data.html#transfer-steps){link-type="dfn"}
and [transfer-receiving
steps](https://html.spec.whatwg.org/multipage/structured-data.html#transfer-receiving-steps){link-type="dfn"}
require the implementation to maintain an implicit internal slot
referencing the underlying
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-94
.internalDFN link-type="idl" lt="MediaSource"} to enable [attaching to a
media
element](#dfn-attaching-to-a-media-element){#ref-for-dfn-attaching-to-a-media-element-4
.internalDFN link-type="dfn|abstract-op"} using
[`srcObject`](https://html.spec.whatwg.org/multipage/media.html#dom-media-srcobject){link-type="attribute"}
and consequent setup of an attachment\'s [cross-context communication
model](#dfn-cross-context-communication-model){#ref-for-dfn-cross-context-communication-model-1
.internalDFN link-type="dfn|abstract-op"}.

:::: {#issue-container-generatedID-42 .note role="note"}
::: {#h-note-42 .note-title .marker role="heading" aria-level="4"}
Note
:::

Implementors should be aware that assumption of \"move\" semantics
implied by
[`Transferable`](https://html.spec.whatwg.org/multipage/structured-data.html#transferable){link-type="extended-attribute"
lt="Transferable"} is not always reality. For example, extensions or
internal implementations of postMessage using broadcast may cause
unintended multiple recipients of a transferred
[`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-20
.internalDFN link-type="idl" lt="MediaSourceHandle"}. For this reason,
implementations are guided to not resolve which potential clone of a
transferred
[`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-21
.internalDFN link-type="idl" lt="MediaSourceHandle"} is still valid for
attachment until and unless any handle for the underlying
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-95
.internalDFN link-type="idl" lt="MediaSource"} object is used in the
asynchronous portion of the media element\'s resource selection
algorithm. This is similar to the existing behavior for attachment via
[MediaSource object
URLs](#mediasource-object-url){#ref-for-mediasource-object-url-11
.internalDFN link-type="dfn|abstract-op"}, which can be cloned easily,
where such a URL is valid for at most one attachment start (across all
of its potentially many clones).
::::

Implementations *MUST* support at most one attachment (load) via
[`srcObject`](https://html.spec.whatwg.org/multipage/media.html#dom-media-srcobject){link-type="attribute"}
ever for the
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-96
.internalDFN link-type="idl" lt="MediaSource"} object underlying a
[`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-22
.internalDFN link-type="idl" lt="MediaSourceHandle"}, regardless of
potential cloning of the
[`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-23
.internalDFN link-type="idl" lt="MediaSourceHandle"} due to varying
implementations of
[`Transferable`](https://html.spec.whatwg.org/multipage/structured-data.html#transferable){link-type="extended-attribute"
lt="Transferable"}.

:::: {#issue-container-generatedID-43 .note role="note"}
::: {#h-note-43 .note-title .marker role="heading" aria-level="4"}
Note
:::

See [attaching to a media
element](#dfn-attaching-to-a-media-element){#ref-for-dfn-attaching-to-a-media-element-5
.internalDFN link-type="dfn|abstract-op"} for how this is enforced
during the asynchronous portion of the media element\'s resource
selection algorithm.
::::

[`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-24
.internalDFN link-type="idl" lt="MediaSourceHandle"} is only exposed on
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
lt="Window"} and
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
lt="DedicatedWorkerGlobalScope"} contexts, and cannot successfully
transfer between different [agent
clusters](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#sec-agent-clusters){link-type="dfn"}
\[[ECMASCRIPT](#bib-ecmascript "ECMAScript Language Specification"){.bibref
link-type="biblio"}\]. Transfer of a
[`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-25
.internalDFN link-type="idl" lt="MediaSourceHandle"} object can only
succeed within the same [agent
cluster](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#sec-agent-clusters){link-type="dfn"}.

:::: {#issue-container-generatedID-44 .note role="note"}
::: {#h-note-44 .note-title .marker role="heading" aria-level="4"}
Note
:::

For example, transfer of a
[`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-26
.internalDFN link-type="idl" lt="MediaSourceHandle"} object from either
a
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
lt="Window"} or
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
lt="DedicatedWorkerGlobalScope"} to either a SharedWorker or a
ServiceWorker will not succeed. Developers should be aware of this
difference versus [MediaSource object
URLs](#mediasource-object-url){#ref-for-mediasource-object-url-12
.internalDFN link-type="dfn|abstract-op"} which are
[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString){link-type="interface"
lt="DOMString"}s that can be communicated many ways. Even so, [attaching
to a media
element](#dfn-attaching-to-a-media-element){#ref-for-dfn-attaching-to-a-media-element-6
.internalDFN link-type="dfn|abstract-op"} using a [MediaSource object
URL](#mediasource-object-url){#ref-for-mediasource-object-url-13
.internalDFN link-type="dfn|abstract-op"} can only succeed for a
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-97
.internalDFN link-type="idl" lt="MediaSource"} that was constructed in a
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
lt="Window"} context. See also the integration of the
[agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#agent){link-type="dfn"}
and [agent
cluster](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#sec-agent-clusters){link-type="dfn"}
formalisms for Web Application APIs
\[[HTML](#bib-html "HTML Standard"){.bibref link-type="biblio"}\] where
related concepts such as [dedicated worker
agents](https://html.spec.whatwg.org/multipage/webappapis.html#dedicated-worker-agent){link-type="dfn"}
are defined.
::::

[Transfer
steps](https://html.spec.whatwg.org/multipage/structured-data.html#transfer-steps){link-type="dfn"}
for a
[`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-27
.internalDFN link-type="idl" lt="MediaSourceHandle"} object *MUST*
include the following step:

1.  If the
    [`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-28
    .internalDFN link-type="idl" lt="MediaSourceHandle"}\'s
    [`[[has ever been assigned as srcobject]]`](#dfn-has-ever-been-assigned-as-srcobject){#ref-for-dfn-has-ever-been-assigned-as-srcobject-1
    .internalDFN link-type="attribute"
    lt="[[has ever been assigned as srcobject]]"} internal slot is true,
    then the [transfer
    steps](https://html.spec.whatwg.org/multipage/structured-data.html#transfer-steps){link-type="dfn"}
    must fail by throwing a
    [`DataCloneError`](https://webidl.spec.whatwg.org/#datacloneerror){link-type="exception"
    lt="DataCloneError"} exception.
::::::::::
::::::::::::::

:::::::::::::::::::::::::::::::::::::::::::::::::::: {#sourcebuffer .section}
::: header-wrapper
## 5. [`SourceBuffer`]{#dom-sourcebuffer .dfn export="" dfn-type="interface" idl="interface" data-title="SourceBuffer" dfn-for="" tabindex="0" aria-haspopup="dialog"} interface {#x5-sourcebuffer-interface}

[](#sourcebuffer){.self-link aria-label="Permalink for Section 5."}
:::

``` {#webidl-955395090 .idl .def}
WebIDLenum AppendMode {
  "segments",
  "sequence",
};
```

[`segments`]{#dom-appendmode-segments .dfn export="" dfn-type="enum-value" idl="enum-value" data-title="segments" dfn-for="AppendMode" tabindex="0" aria-haspopup="dialog"}
:   The timestamps in the media segment determine where the [coded
    frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-12 .internalDFN
    link-type="dfn|abstract-op"} are placed in the presentation. Media
    segments can be appended in any order.

[`sequence`]{#dom-appendmode-sequence .dfn export="" dfn-type="enum-value" idl="enum-value" data-title="sequence" dfn-for="AppendMode" tabindex="0" aria-haspopup="dialog"}
:   Media segments will be treated as adjacent in time independent of
    the timestamps in the media segment. Coded frames in a new media
    segment will be placed immediately after the coded frames in the
    previous media segment. The
    [`timestampOffset`](#dom-sourcebuffer-timestampoffset){#ref-for-dom-sourcebuffer-timestampoffset-1
    .internalDFN link-type="idl"} attribute will be updated if a new
    offset is needed to make the new media segments adjacent to the
    previous media segment. Setting the
    [`timestampOffset`](#dom-sourcebuffer-timestampoffset){#ref-for-dom-sourcebuffer-timestampoffset-2
    .internalDFN link-type="idl"} attribute in
    \"[`sequence`](#dom-appendmode-sequence){#ref-for-dom-appendmode-sequence-3
    .internalDFN link-type="idl"}\" mode allows a media segment to be
    placed at a specific position in the timeline without any knowledge
    of the timestamps in the media segment.

``` {#webidl-544711679 .idl .def}
WebIDL[Exposed=(Window,DedicatedWorker)]
interface SourceBuffer : EventTarget {
  attribute AppendMode mode;
  readonly  attribute boolean updating;
  readonly  attribute TimeRanges buffered;
  attribute double timestampOffset;
  readonly  attribute AudioTrackList audioTracks;
  readonly  attribute VideoTrackList videoTracks;
  readonly  attribute TextTrackList textTracks;
  attribute double appendWindowStart;
  attribute unrestricted double appendWindowEnd;

  attribute EventHandler onupdatestart;
  attribute EventHandler onupdate;
  attribute EventHandler onupdateend;
  attribute EventHandler onerror;
  attribute EventHandler onabort;

  undefined appendBuffer(BufferSource data);
  undefined abort();
  undefined changeType(DOMString type);
  undefined remove(double start, unrestricted double end);
};
```

::::: {#issue-container-number-280 .issue}
::: {#h-issue-0 .issue-title .marker role="heading" aria-level="3"}
[[Issue
280]{.issue-number}](https://github.com/w3c/media-source/issues/280)[:
MSE-in-Workers: {Audio,Video,Text}Track{,List} IDL in HTML need
additional DedicatedWorker in Exposed
[mse-in-workers](https://github.com/w3c/media-source/issues/?q=is%3Aissue+is%3Aopen+label%3A%22mse-in-workers%22){.respec-gh-label
style="background-color: rgb(170, 170, 170); color: rgb(0, 0, 0);"
aria-label="GitHub label: mse-in-workers"}]{.issue-label}
:::

::: {}
\[[HTML](#bib-html "HTML Standard"){.bibref link-type="biblio"}\]
[`AudioTrackList`](https://html.spec.whatwg.org/multipage/media.html#audiotracklist){link-type="interface"
lt="AudioTrackList"},
[`VideoTrackList`](https://html.spec.whatwg.org/multipage/media.html#videotracklist){link-type="interface"
lt="VideoTrackList"} and
[`TextTrackList`](https://html.spec.whatwg.org/multipage/media.html#texttracklist){link-type="interface"
lt="TextTrackList"} need Window+DedicatedWorker exposure.
:::
:::::

:::: {#attributes .section}
::: header-wrapper
### 5.1 Attributes {#x5-1-attributes}

[](#attributes){.self-link aria-label="Permalink for Section 5.1"}
:::

[`mode`]{#dom-sourcebuffer-mode .dfn export="" dfn-type="attribute" idl="attribute" data-title="mode" dfn-for="SourceBuffer" data-type="AppendMode" lt="mode" local-lt="SourceBuffer.mode" tabindex="0" aria-haspopup="dialog"} of type [`AppendMode`](#dom-appendmode){#ref-for-dom-appendmode-2 .internalDFN link-type="idl"}

:   Controls how a sequence of [media
    segments](#dfn-media-segment){#ref-for-dfn-media-segment-5
    .internalDFN link-type="dfn|abstract-op"} are handled. This
    attribute is initially set by
    [`addSourceBuffer`](#dom-mediasource-addsourcebuffer){#ref-for-dom-mediasource-addsourcebuffer-5
    .internalDFN link-type="idl" lt="addSourceBuffer()"}`()` after the
    object is created, and can be updated by
    [`changeType`](#dom-sourcebuffer-changetype){#ref-for-dom-sourcebuffer-changetype-4
    .internalDFN link-type="idl" lt="changeType()"}`()` or setting this
    attribute.

    On getting, Return the initial value or the last value that was
    successfully set.

    On setting, run the following steps:

    1.  If this object has been removed from the
        [`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-21
        .internalDFN link-type="idl"} attribute of the [parent media
        source](#parent-media-source){#ref-for-parent-media-source-1
        .internalDFN link-type="dfn|abstract-op"}, then throw an
        [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror){link-type="exception"
        lt="InvalidStateError"} exception and abort these steps.

    2.  If the
        [`updating`](#dom-sourcebuffer-updating){#ref-for-dom-sourcebuffer-updating-6
        .internalDFN link-type="idl"} attribute equals true, then throw
        an
        [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror){link-type="exception"
        lt="InvalidStateError"} exception and abort these steps.

    3.  Let `new mode`{.variable data-type="AppendMode"} equal the new
        value being assigned to this attribute.

    4.  If
        [`[[generate timestamps flag]]`](#dfn-generate-timestamps-flag){#ref-for-dfn-generate-timestamps-flag-3
        .internalDFN link-type="attribute"
        lt="[[generate timestamps flag]]"} equals true and
        `new mode`{.variable data-type="AppendMode"} equals
        \"[`segments`](#dom-appendmode-segments){#ref-for-dom-appendmode-segments-3
        .internalDFN link-type="idl"}\", then throw a
        [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror){link-type="exception"
        lt="TypeError"} exception and abort these steps.

    5.  If the
        [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-23
        .internalDFN link-type="idl"} attribute of the [parent media
        source](#parent-media-source){#ref-for-parent-media-source-2
        .internalDFN link-type="dfn|abstract-op"} is in the
        \"[`ended`](#dom-readystate-ended){#ref-for-dom-readystate-ended-8
        .internalDFN link-type="idl"}\" state then run the following
        steps:

        1.  Set the
            [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-24
            .internalDFN link-type="idl"} attribute of the [parent media
            source](#parent-media-source){#ref-for-parent-media-source-3
            .internalDFN link-type="dfn|abstract-op"} to
            \"[`open`](#dom-readystate-open){#ref-for-dom-readystate-open-14
            .internalDFN link-type="idl"}\"
        2.  [Queue a
            task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
            to [fire an
            event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
            named
            [`sourceopen`](#dfn-sourceopen){#ref-for-dfn-sourceopen-3
            .internalDFN link-type="idl" lt="sourceopen"} at the [parent
            media
            source](#parent-media-source){#ref-for-parent-media-source-4
            .internalDFN link-type="dfn|abstract-op"}.

    6.  If the
        [`[[append state]]`](#dfn-append-state){#ref-for-dfn-append-state-1
        .internalDFN link-type="attribute" lt="[[append state]]"} equals
        [PARSING_MEDIA_SEGMENT](#sourcebuffer-parsing-media-segment){#ref-for-sourcebuffer-parsing-media-segment-1
        .internalDFN link-type="dfn|abstract-op"}, then throw an
        [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror){link-type="exception"
        lt="InvalidStateError"} and abort these steps.

    7.  If the `new mode`{.variable data-type="AppendMode"} equals
        \"[`sequence`](#dom-appendmode-sequence){#ref-for-dom-appendmode-sequence-4
        .internalDFN link-type="idl"}\", then set the
        [`[[group start timestamp]]`](#dfn-group-start-timestamp){#ref-for-dfn-group-start-timestamp-1
        .internalDFN link-type="attribute"
        lt="[[group start timestamp]]"} to the
        [`[[group end timestamp]]`](#dfn-group-end-timestamp){#ref-for-dfn-group-end-timestamp-1
        .internalDFN link-type="attribute"
        lt="[[group end timestamp]]"}.

    8.  Update the attribute to `new mode`{.variable
        data-type="AppendMode"}.

[`updating`]{#dom-sourcebuffer-updating .dfn export="" dfn-type="attribute" idl="attribute" data-title="updating" dfn-for="SourceBuffer" data-type="boolean" lt="updating" local-lt="SourceBuffer.updating" tabindex="0" aria-haspopup="dialog"} of type [`boolean`](https://webidl.spec.whatwg.org/#idl-boolean){link-type="interface" lt="boolean"}, readonly

:   Indicates whether the asynchronous continuation of an
    [`appendBuffer`](#dom-sourcebuffer-appendbuffer){#ref-for-dom-sourcebuffer-appendbuffer-5
    .internalDFN link-type="idl" lt="appendBuffer()"}`()` or
    [`remove`](#dom-sourcebuffer-remove){#ref-for-dom-sourcebuffer-remove-3
    .internalDFN link-type="idl" lt="remove()"}`()` operation is still
    being processed. This attribute is initially set to false when the
    object is created.

[`buffered`]{#dom-sourcebuffer-buffered .dfn export="" dfn-type="attribute" idl="attribute" data-title="buffered" dfn-for="SourceBuffer" data-type="TimeRanges" lt="buffered" local-lt="SourceBuffer.buffered" tabindex="0" aria-haspopup="dialog"} of type [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface" lt="TimeRanges"}, readonly

:   Indicates what
    [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface"
    lt="TimeRanges"} are buffered in the
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-47
    .internalDFN link-type="idl" lt="SourceBuffer"}. This attribute is
    initially set to an empty
    [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface"
    lt="TimeRanges"} object when the object is created.

    When the attribute is read the following steps *MUST* occur:

    1.  If this object has been removed from the
        [`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-22
        .internalDFN link-type="idl"} attribute of the [parent media
        source](#parent-media-source){#ref-for-parent-media-source-5
        .internalDFN link-type="dfn|abstract-op"} then throw an
        [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror){link-type="exception"
        lt="InvalidStateError"} exception and abort these steps.
    2.  Let `highest end time`{.variable data-type="double"} be the
        largest [track buffer
        ranges](#track-buffer-ranges){#ref-for-track-buffer-ranges-3
        .internalDFN link-type="dfn|abstract-op"} end time across all
        the [track buffers](#track-buffer){#ref-for-track-buffer-4
        .internalDFN link-type="dfn|abstract-op"} managed by this
        [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-48
        .internalDFN link-type="idl" lt="SourceBuffer"} object.
    3.  Let `intersection ranges`{.variable
        data-type="normalized TimeRanges"} equal a
        [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface"
        lt="TimeRanges"} object containing a single range from 0 to
        `highest end time`{.variable data-type="double"}.
    4.  For each audio and video [track
        buffer](#track-buffer){#ref-for-track-buffer-5 .internalDFN
        link-type="dfn|abstract-op"} managed by this
        [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-49
        .internalDFN link-type="idl" lt="SourceBuffer"}, run the
        following steps:

        :::: {#issue-container-generatedID-45 .note role="note"}
        ::: {#h-note-45 .note-title .marker role="heading" aria-level="4"}
        Note
        :::

        Text [track buffers](#track-buffer){#ref-for-track-buffer-6
        .internalDFN link-type="dfn|abstract-op"} are included in the
        calculation of `highest end time`{.variable data-type="double"},
        above, but excluded from the buffered range calculation here.
        They are not necessarily continuous, nor should any
        discontinuity within them trigger playback stall when the other
        media tracks are continuous over the same time range.
        ::::

        1.  Let `track ranges`{.variable
            data-type="normalized TimeRanges"} equal the [track buffer
            ranges](#track-buffer-ranges){#ref-for-track-buffer-ranges-4
            .internalDFN link-type="dfn|abstract-op"} for the current
            [track buffer](#track-buffer){#ref-for-track-buffer-7
            .internalDFN link-type="dfn|abstract-op"}.
        2.  If
            [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-25
            .internalDFN link-type="idl"} is
            \"[`ended`](#dom-readystate-ended){#ref-for-dom-readystate-ended-9
            .internalDFN link-type="idl"}\", then set the end time on
            the last range in `track ranges`{.variable
            data-type="normalized TimeRanges"} to
            `highest end time`{.variable data-type="double"}.
        3.  Let `new intersection ranges`{.variable
            data-type="normalized TimeRanges"} equal the intersection
            between the `intersection ranges`{.variable
            data-type="normalized TimeRanges"} and the
            `track ranges`{.variable data-type="normalized TimeRanges"}.
        4.  Replace the ranges in `intersection ranges`{.variable
            data-type="normalized TimeRanges"} with the
            `new intersection ranges`{.variable}.
    5.  If `intersection ranges`{.variable
        data-type="normalized TimeRanges"} does not contain the exact
        same range information as the current value of this attribute,
        then update the current value of this attribute to
        `intersection ranges`{.variable
        data-type="normalized TimeRanges"}.
    6.  Return the current value of this attribute.

[`timestampOffset`]{#dom-sourcebuffer-timestampoffset .dfn export="" dfn-type="attribute" idl="attribute" data-title="timestampOffset" dfn-for="SourceBuffer" data-type="double" lt="timestampOffset" local-lt="SourceBuffer.timestampOffset" tabindex="0" aria-haspopup="dialog"} of type [`double`](https://webidl.spec.whatwg.org/#idl-double){link-type="interface" lt="double"}

:   Controls the offset applied to timestamps inside subsequent [media
    segments](#dfn-media-segment){#ref-for-dfn-media-segment-6
    .internalDFN link-type="dfn|abstract-op"} that are appended to this
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-50
    .internalDFN link-type="idl" lt="SourceBuffer"}. The
    [`timestampOffset`](#dom-sourcebuffer-timestampoffset){#ref-for-dom-sourcebuffer-timestampoffset-4
    .internalDFN link-type="idl"} is initially set to 0 which indicates
    that no offset is being applied.

    On getting, Return the initial value or the last value that was
    successfully set.

    On setting, run the following steps:

    1.  Let `new timestamp offset`{.variable data-type="double"} equal
        the new value being assigned to this attribute.

    2.  If this object has been removed from the
        [`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-23
        .internalDFN link-type="idl"} attribute of the [parent media
        source](#parent-media-source){#ref-for-parent-media-source-6
        .internalDFN link-type="dfn|abstract-op"}, then throw an
        [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror){link-type="exception"
        lt="InvalidStateError"} exception and abort these steps.

    3.  If the
        [`updating`](#dom-sourcebuffer-updating){#ref-for-dom-sourcebuffer-updating-7
        .internalDFN link-type="idl"} attribute equals true, then throw
        an
        [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror){link-type="exception"
        lt="InvalidStateError"} exception and abort these steps.

    4.  If the
        [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-26
        .internalDFN link-type="idl"} attribute of the [parent media
        source](#parent-media-source){#ref-for-parent-media-source-7
        .internalDFN link-type="dfn|abstract-op"} is in the
        \"[`ended`](#dom-readystate-ended){#ref-for-dom-readystate-ended-10
        .internalDFN link-type="idl"}\" state then run the following
        steps:

        1.  Set the
            [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-27
            .internalDFN link-type="idl"} attribute of the [parent media
            source](#parent-media-source){#ref-for-parent-media-source-8
            .internalDFN link-type="dfn|abstract-op"} to
            \"[`open`](#dom-readystate-open){#ref-for-dom-readystate-open-15
            .internalDFN link-type="idl"}\"
        2.  [Queue a
            task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
            to [fire an
            event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
            named
            [`sourceopen`](#dfn-sourceopen){#ref-for-dfn-sourceopen-4
            .internalDFN link-type="idl" lt="sourceopen"} at the [parent
            media
            source](#parent-media-source){#ref-for-parent-media-source-9
            .internalDFN link-type="dfn|abstract-op"}.

    5.  If the
        [`[[append state]]`](#dfn-append-state){#ref-for-dfn-append-state-2
        .internalDFN link-type="attribute" lt="[[append state]]"} equals
        [PARSING_MEDIA_SEGMENT](#sourcebuffer-parsing-media-segment){#ref-for-sourcebuffer-parsing-media-segment-2
        .internalDFN link-type="dfn|abstract-op"}, then throw an
        [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror){link-type="exception"
        lt="InvalidStateError"} and abort these steps.

    6.  If the
        [`mode`](#dom-sourcebuffer-mode){#ref-for-dom-sourcebuffer-mode-4
        .internalDFN link-type="idl"} attribute equals
        \"[`sequence`](#dom-appendmode-sequence){#ref-for-dom-appendmode-sequence-5
        .internalDFN link-type="idl"}\", then set the
        [`[[group start timestamp]]`](#dfn-group-start-timestamp){#ref-for-dfn-group-start-timestamp-2
        .internalDFN link-type="attribute"
        lt="[[group start timestamp]]"} to
        `new timestamp offset`{.variable data-type="double"}.

    7.  Update the attribute to `new timestamp offset`{.variable
        data-type="double"}.

[`audioTracks`]{#dom-sourcebuffer-audiotracks .dfn plurals="audiotrack" export="" dfn-type="attribute" idl="attribute" data-title="audioTracks" dfn-for="SourceBuffer" data-type="AudioTrackList" lt="audioTracks" local-lt="SourceBuffer.audioTracks" tabindex="0" aria-haspopup="dialog"} of type [`AudioTrackList`](https://html.spec.whatwg.org/multipage/media.html#audiotracklist){link-type="interface" lt="AudioTrackList"}, readonly
:   The list of
    [`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack){link-type="interface"
    lt="AudioTrack"} objects created by this object.

[`videoTracks`]{#dom-sourcebuffer-videotracks .dfn plurals="videotrack" export="" dfn-type="attribute" idl="attribute" data-title="videoTracks" dfn-for="SourceBuffer" data-type="VideoTrackList" lt="videoTracks" local-lt="SourceBuffer.videoTracks" tabindex="0" aria-haspopup="dialog"} of type [`VideoTrackList`](https://html.spec.whatwg.org/multipage/media.html#videotracklist){link-type="interface" lt="VideoTrackList"}, readonly
:   The list of
    [`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack){link-type="interface"
    lt="VideoTrack"} objects created by this object.

[`textTracks`]{#dom-sourcebuffer-texttracks .dfn plurals="texttrack" export="" dfn-type="attribute" idl="attribute" data-title="textTracks" dfn-for="SourceBuffer" data-type="TextTrackList" lt="textTracks" local-lt="SourceBuffer.textTracks" tabindex="0" aria-haspopup="dialog"} of type [`TextTrackList`](https://html.spec.whatwg.org/multipage/media.html#texttracklist){link-type="interface" lt="TextTrackList"}, readonly
:   The list of
    [`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack){link-type="interface"
    lt="TextTrack"} objects created by this object.

[`appendWindowStart`]{#dom-sourcebuffer-appendwindowstart .dfn export="" dfn-type="attribute" idl="attribute" data-title="appendWindowStart" dfn-for="SourceBuffer" data-type="double" lt="appendWindowStart" local-lt="SourceBuffer.appendWindowStart" tabindex="0" aria-haspopup="dialog"} of type [`double`](https://webidl.spec.whatwg.org/#idl-double){link-type="interface" lt="double"}

:   The [presentation
    timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-12
    .internalDFN link-type="dfn|abstract-op"} for the start of the
    [append window](#dfn-append-window){#ref-for-dfn-append-window-1
    .internalDFN link-type="dfn|abstract-op"}. This attribute is
    initially set to the [presentation start
    time](#presentation-start-time){#ref-for-presentation-start-time-4
    .internalDFN link-type="dfn|abstract-op"}.

    On getting, Return the initial value or the last value that was
    successfully set.

    On setting, run the following steps:

    1.  If this object has been removed from the
        [`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-24
        .internalDFN link-type="idl"} attribute of the [parent media
        source](#parent-media-source){#ref-for-parent-media-source-10
        .internalDFN link-type="dfn|abstract-op"}, then throw an
        [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror){link-type="exception"
        lt="InvalidStateError"} exception and abort these steps.
    2.  If the
        [`updating`](#dom-sourcebuffer-updating){#ref-for-dom-sourcebuffer-updating-8
        .internalDFN link-type="idl"} attribute equals true, then throw
        an
        [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror){link-type="exception"
        lt="InvalidStateError"} exception and abort these steps.
    3.  If the new value is less than 0 or greater than or equal to
        [`appendWindowEnd`](#dom-sourcebuffer-appendwindowend){#ref-for-dom-sourcebuffer-appendwindowend-3
        .internalDFN link-type="idl"} then throw a
        [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror){link-type="exception"
        lt="TypeError"} exception and abort these steps.
    4.  Update the attribute to the new value.

[`appendWindowEnd`]{#dom-sourcebuffer-appendwindowend .dfn export="" dfn-type="attribute" idl="attribute" data-title="appendWindowEnd" dfn-for="SourceBuffer" data-type="unrestricted double" lt="appendWindowEnd" local-lt="SourceBuffer.appendWindowEnd" tabindex="0" aria-haspopup="dialog"} of type [`unrestricted double`](https://webidl.spec.whatwg.org/#idl-unrestricted-double){link-type="interface" lt="unrestricted double"}

:   The [presentation
    timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-13
    .internalDFN link-type="dfn|abstract-op"} for the end of the [append
    window](#dfn-append-window){#ref-for-dfn-append-window-2
    .internalDFN link-type="dfn|abstract-op"}. This attribute is
    initially set to positive Infinity.

    On getting, Return the initial value or the last value that was
    successfully set.

    On setting, run the following steps:

    1.  If this object has been removed from the
        [`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-25
        .internalDFN link-type="idl"} attribute of the [parent media
        source](#parent-media-source){#ref-for-parent-media-source-11
        .internalDFN link-type="dfn|abstract-op"}, then throw an
        [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror){link-type="exception"
        lt="InvalidStateError"} exception and abort these steps.
    2.  If the
        [`updating`](#dom-sourcebuffer-updating){#ref-for-dom-sourcebuffer-updating-9
        .internalDFN link-type="idl"} attribute equals true, then throw
        an
        [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror){link-type="exception"
        lt="InvalidStateError"} exception and abort these steps.
    3.  If the new value equals NaN, then throw a
        [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror){link-type="exception"
        lt="TypeError"} and abort these steps.
    4.  If the new value is less than or equal to
        [`appendWindowStart`](#dom-sourcebuffer-appendwindowstart){#ref-for-dom-sourcebuffer-appendwindowstart-3
        .internalDFN link-type="idl"} then throw a
        [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror){link-type="exception"
        lt="TypeError"} exception and abort these steps.
    5.  Update the attribute to the new value.

[`onupdatestart`]{#dom-sourcebuffer-onupdatestart .dfn export="" dfn-type="attribute" idl="attribute" data-title="onupdatestart" dfn-for="SourceBuffer" data-type="EventHandler" lt="onupdatestart" local-lt="SourceBuffer.onupdatestart" tabindex="0" aria-haspopup="dialog"} of type [`EventHandler`](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler){link-type="typedef" lt="EventHandler"}

:   The event handler for the
    [`updatestart`](#dfn-updatestart){#ref-for-dfn-updatestart-1
    .internalDFN link-type="idl" lt="updatestart"} event.

[`onupdate`]{#dom-sourcebuffer-onupdate .dfn export="" dfn-type="attribute" idl="attribute" data-title="onupdate" dfn-for="SourceBuffer" data-type="EventHandler" lt="onupdate" local-lt="SourceBuffer.onupdate" tabindex="0" aria-haspopup="dialog"} of type [`EventHandler`](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler){link-type="typedef" lt="EventHandler"}

:   The event handler for the
    [`update`](#dfn-update){#ref-for-dfn-update-1 .internalDFN
    link-type="idl" lt="update"} event.

[`onupdateend`]{#dom-sourcebuffer-onupdateend .dfn export="" dfn-type="attribute" idl="attribute" data-title="onupdateend" dfn-for="SourceBuffer" data-type="EventHandler" lt="onupdateend" local-lt="SourceBuffer.onupdateend" tabindex="0" aria-haspopup="dialog"} of type [`EventHandler`](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler){link-type="typedef" lt="EventHandler"}

:   The event handler for the
    [`updateend`](#dfn-updateend){#ref-for-dfn-updateend-2 .internalDFN
    link-type="idl" lt="updateend"} event.

[`onerror`]{#dom-sourcebuffer-onerror .dfn export="" dfn-type="attribute" idl="attribute" data-title="onerror" dfn-for="SourceBuffer" data-type="EventHandler" lt="onerror" local-lt="SourceBuffer.onerror" tabindex="0" aria-haspopup="dialog"} of type [`EventHandler`](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler){link-type="typedef" lt="EventHandler"}

:   The event handler for the [`error`](#dfn-error){#ref-for-dfn-error-1
    .internalDFN link-type="idl" lt="error"} event.

[`onabort`]{#dom-sourcebuffer-onabort .dfn export="" dfn-type="attribute" idl="attribute" data-title="onabort" dfn-for="SourceBuffer" data-type="EventHandler" lt="onabort" local-lt="SourceBuffer.onabort" tabindex="0" aria-haspopup="dialog"} of type [`EventHandler`](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler){link-type="typedef" lt="EventHandler"}

:   The event handler for the [`abort`](#dfn-abort){#ref-for-dfn-abort-2
    .internalDFN link-type="idl" lt="abort"} event.
::::

:::: {#methods .section}
::: header-wrapper
### 5.2 Methods {#x5-2-methods}

[](#methods){.self-link aria-label="Permalink for Section 5.2"}
:::

[`appendBuffer`]{#dom-sourcebuffer-appendbuffer .dfn export="" dfn-type="method" idl="operation" data-title="appendBuffer" dfn-for="SourceBuffer" data-type="undefined" lt="appendBuffer()|appendBuffer(data)" local-lt="SourceBuffer.appendBuffer|SourceBuffer.appendBuffer()|appendBuffer" tabindex="0" aria-haspopup="dialog"}

:   Appends the segment data in an
    [`BufferSource`](https://www.w3.org/TR/WebIDL-1/#common-BufferSource){.idlType}\[[WEBIDL](#bib-webidl "Web IDL Standard"){.bibref
    link-type="biblio"}\] to the
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-51
    .internalDFN link-type="idl" lt="SourceBuffer"}.

    When this method is invoked, the user agent must run the following
    steps:

    1.  Run the [prepare
        append](#dfn-prepare-append){#ref-for-dfn-prepare-append-1
        .internalDFN link-type="dfn|abstract-op"} algorithm.
    2.  Add `data`{.variable data-type="BufferSource"} to the end of the
        [`[[input buffer]]`](#dfn-input-buffer){#ref-for-dfn-input-buffer-1
        .internalDFN link-type="attribute" lt="[[input buffer]]"}.
    3.  Set the
        [`updating`](#dom-sourcebuffer-updating){#ref-for-dom-sourcebuffer-updating-10
        .internalDFN link-type="idl"} attribute to true.
    4.  [Queue a
        task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
        to [fire an
        event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
        named
        [`updatestart`](#dfn-updatestart){#ref-for-dfn-updatestart-2
        .internalDFN link-type="idl" lt="updatestart"} at this
        [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-52
        .internalDFN link-type="idl" lt="SourceBuffer"} object.
    5.  Asynchronously run the [buffer
        append](#dfn-buffer-append){#ref-for-dfn-buffer-append-2
        .internalDFN link-type="dfn|abstract-op"} algorithm.

[`abort`]{#dom-sourcebuffer-abort .dfn export="" dfn-type="method" idl="operation" data-title="abort" dfn-for="SourceBuffer" data-type="undefined" lt="abort()" local-lt="SourceBuffer.abort|SourceBuffer.abort()|abort" tabindex="0" aria-haspopup="dialog"}

:   Aborts the current segment and resets the segment parser.

    When this method is invoked, the user agent must run the following
    steps:

    1.  If this object has been removed from the
        [`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-26
        .internalDFN link-type="idl"} attribute of the [parent media
        source](#parent-media-source){#ref-for-parent-media-source-12
        .internalDFN link-type="dfn|abstract-op"} then throw an
        [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror){link-type="exception"
        lt="InvalidStateError"} exception and abort these steps.
    2.  If the
        [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-28
        .internalDFN link-type="idl"} attribute of the [parent media
        source](#parent-media-source){#ref-for-parent-media-source-13
        .internalDFN link-type="dfn|abstract-op"} is not in the
        \"[`open`](#dom-readystate-open){#ref-for-dom-readystate-open-16
        .internalDFN link-type="idl"}\" state then throw an
        [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror){link-type="exception"
        lt="InvalidStateError"} exception and abort these steps.
    3.  If the [range
        removal](#dfn-range-removal){#ref-for-dfn-range-removal-1
        .internalDFN link-type="dfn|abstract-op"} algorithm is running,
        then throw an
        [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror){link-type="exception"
        lt="InvalidStateError"} exception and abort these steps.
    4.  If the
        [`updating`](#dom-sourcebuffer-updating){#ref-for-dom-sourcebuffer-updating-11
        .internalDFN link-type="idl"} attribute equals true, then run
        the following steps:
        1.  Abort the [buffer
            append](#dfn-buffer-append){#ref-for-dfn-buffer-append-3
            .internalDFN link-type="dfn|abstract-op"} algorithm if it is
            running.
        2.  Set the
            [`updating`](#dom-sourcebuffer-updating){#ref-for-dom-sourcebuffer-updating-12
            .internalDFN link-type="idl"} attribute to false.
        3.  [Queue a
            task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
            to [fire an
            event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
            named [`abort`](#dfn-abort){#ref-for-dfn-abort-3
            .internalDFN link-type="idl" lt="abort"} at this
            [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-53
            .internalDFN link-type="idl" lt="SourceBuffer"} object.
        4.  [Queue a
            task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
            to [fire an
            event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
            named [`updateend`](#dfn-updateend){#ref-for-dfn-updateend-3
            .internalDFN link-type="idl" lt="updateend"} at this
            [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-54
            .internalDFN link-type="idl" lt="SourceBuffer"} object.
    5.  Run the [reset parser
        state](#dfn-reset-parser-state){#ref-for-dfn-reset-parser-state-1
        .internalDFN link-type="dfn|abstract-op"} algorithm.
    6.  Set
        [`appendWindowStart`](#dom-sourcebuffer-appendwindowstart){#ref-for-dom-sourcebuffer-appendwindowstart-4
        .internalDFN link-type="idl"} to the [presentation start
        time](#presentation-start-time){#ref-for-presentation-start-time-5
        .internalDFN link-type="dfn|abstract-op"}.
    7.  Set
        [`appendWindowEnd`](#dom-sourcebuffer-appendwindowend){#ref-for-dom-sourcebuffer-appendwindowend-4
        .internalDFN link-type="idl"} to positive Infinity.

[`changeType`]{#dom-sourcebuffer-changetype .dfn export="" dfn-type="method" idl="operation" data-title="changeType" dfn-for="SourceBuffer" data-type="undefined" lt="changeType()|changeType(type)" local-lt="SourceBuffer.changeType|SourceBuffer.changeType()|changeType" tabindex="0" aria-haspopup="dialog"}

:   Changes the MIME type associated with this object. Subsequent
    [`appendBuffer`](#dom-sourcebuffer-appendbuffer){#ref-for-dom-sourcebuffer-appendbuffer-6
    .internalDFN link-type="idl" lt="appendBuffer()"}`()` calls will
    expect the newly appended bytes to conform to the new type.

    When this method is invoked, the user agent must run the following
    steps:

    1.  If `type`{.variable data-type="DOMString"} is an empty string
        then throw a
        [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror){link-type="exception"
        lt="TypeError"} exception and abort these steps.

    2.  If this object has been removed from the
        [`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-27
        .internalDFN link-type="idl"} attribute of the [parent media
        source](#parent-media-source){#ref-for-parent-media-source-14
        .internalDFN link-type="dfn|abstract-op"}, then throw an
        [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror){link-type="exception"
        lt="InvalidStateError"} exception and abort these steps.

    3.  If the
        [`updating`](#dom-sourcebuffer-updating){#ref-for-dom-sourcebuffer-updating-13
        .internalDFN link-type="idl"} attribute equals true, then throw
        an
        [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror){link-type="exception"
        lt="InvalidStateError"} exception and abort these steps.

    4.  If `type`{.variable data-type="DOMString"} contains a MIME type
        that is not supported or contains a MIME type that is not
        supported with the types specified (currently or previously) of
        [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-55
        .internalDFN link-type="idl" lt="SourceBuffer"} objects in the
        [`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-28
        .internalDFN link-type="idl"} attribute of the [parent media
        source](#parent-media-source){#ref-for-parent-media-source-15
        .internalDFN link-type="dfn|abstract-op"}, then throw a
        [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror){link-type="exception"
        lt="NotSupportedError"} exception and abort these steps.

    5.  If the
        [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-29
        .internalDFN link-type="idl"} attribute of the [parent media
        source](#parent-media-source){#ref-for-parent-media-source-16
        .internalDFN link-type="dfn|abstract-op"} is in the
        \"[`ended`](#dom-readystate-ended){#ref-for-dom-readystate-ended-11
        .internalDFN link-type="idl"}\" state then run the following
        steps:

        1.  Set the
            [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-30
            .internalDFN link-type="idl"} attribute of the [parent media
            source](#parent-media-source){#ref-for-parent-media-source-17
            .internalDFN link-type="dfn|abstract-op"} to
            \"[`open`](#dom-readystate-open){#ref-for-dom-readystate-open-17
            .internalDFN link-type="idl"}\".
        2.  [Queue a
            task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
            to [fire an
            event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
            named
            [`sourceopen`](#dfn-sourceopen){#ref-for-dfn-sourceopen-5
            .internalDFN link-type="idl" lt="sourceopen"} at the [parent
            media
            source](#parent-media-source){#ref-for-parent-media-source-18
            .internalDFN link-type="dfn|abstract-op"}.

    6.  Run the [reset parser
        state](#dfn-reset-parser-state){#ref-for-dfn-reset-parser-state-2
        .internalDFN link-type="dfn|abstract-op"} algorithm.

    7.  Update the
        [`[[generate timestamps flag]]`](#dfn-generate-timestamps-flag){#ref-for-dfn-generate-timestamps-flag-4
        .internalDFN link-type="attribute"
        lt="[[generate timestamps flag]]"} on this
        [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-56
        .internalDFN link-type="idl" lt="SourceBuffer"} object to the
        value in the \"Generate Timestamps Flag\" column of the byte
        stream format registry
        \[[MSE-REGISTRY](#bib-mse-registry "Media Source Extensions™ Byte Stream Format Registry"){.bibref
        link-type="biblio"}\] entry that is associated with
        `type`{.variable data-type="DOMString"}.

    8.  

        If the [`[[generate timestamps flag]]`](#dfn-generate-timestamps-flag){#ref-for-dfn-generate-timestamps-flag-5 .internalDFN link-type="attribute" lt="[[generate timestamps flag]]"} equals true:
        :   Set the
            [`mode`](#dom-sourcebuffer-mode){#ref-for-dom-sourcebuffer-mode-5
            .internalDFN link-type="idl"} attribute on this
            [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-57
            .internalDFN link-type="idl" lt="SourceBuffer"} object to
            \"[`sequence`](#dom-appendmode-sequence){#ref-for-dom-appendmode-sequence-6
            .internalDFN link-type="idl"}\", including running the
            associated steps for that attribute being set.

        Otherwise:
        :   Keep the previous value of the
            [`mode`](#dom-sourcebuffer-mode){#ref-for-dom-sourcebuffer-mode-6
            .internalDFN link-type="idl"} attribute on this
            [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-58
            .internalDFN link-type="idl" lt="SourceBuffer"} object,
            without running any associated steps for that attribute
            being set.

    9.  Set the
        [`[[pending initialization segment for changeType flag]]`](#dfn-pending-initialization-segment-for-changetype-flag){#ref-for-dfn-pending-initialization-segment-for-changetype-flag-1
        .internalDFN link-type="attribute"
        lt="[[pending initialization segment for changeType flag]]"} on
        this
        [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-59
        .internalDFN link-type="idl" lt="SourceBuffer"} object to true.

[`remove`]{#dom-sourcebuffer-remove .dfn export="" dfn-type="method" idl="operation" data-title="remove" dfn-for="SourceBuffer" data-type="undefined" lt="remove()|remove(start, end)" local-lt="SourceBuffer.remove|SourceBuffer.remove()|remove" tabindex="0" aria-haspopup="dialog"}

:   Removes media for a specific time range. The `start`{.variable} of
    the removal range, in seconds measured from [presentation start
    time](#presentation-start-time){#ref-for-presentation-start-time-6
    .internalDFN link-type="dfn|abstract-op"} The `end`{.variable} of
    the removal range, in seconds measured from [presentation start
    time](#presentation-start-time){#ref-for-presentation-start-time-7
    .internalDFN link-type="dfn|abstract-op"}.

    When this method is invoked, the user agent must run the following
    steps:

    1.  If this object has been removed from the
        [`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-29
        .internalDFN link-type="idl"} attribute of the [parent media
        source](#parent-media-source){#ref-for-parent-media-source-19
        .internalDFN link-type="dfn|abstract-op"} then throw an
        [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror){link-type="exception"
        lt="InvalidStateError"} exception and abort these steps.

    2.  If the
        [`updating`](#dom-sourcebuffer-updating){#ref-for-dom-sourcebuffer-updating-14
        .internalDFN link-type="idl"} attribute equals true, then throw
        an
        [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror){link-type="exception"
        lt="InvalidStateError"} exception and abort these steps.

    3.  If
        [`duration`](#dom-mediasource-duration){#ref-for-dom-mediasource-duration-7
        .internalDFN link-type="idl"} equals NaN, then throw a
        [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror){link-type="exception"
        lt="TypeError"} exception and abort these steps.

    4.  If `start`{.variable data-type="double"} is negative or greater
        than
        [`duration`](#dom-mediasource-duration){#ref-for-dom-mediasource-duration-8
        .internalDFN link-type="idl"}, then throw a
        [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror){link-type="exception"
        lt="TypeError"} exception and abort these steps.

    5.  If `end`{.variable data-type="unrestricted double"} is less than
        or equal to `start`{.variable data-type="double"} or
        `end`{.variable data-type="unrestricted double"} equals NaN,
        then throw a
        [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror){link-type="exception"
        lt="TypeError"} exception and abort these steps.

    6.  If the
        [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-31
        .internalDFN link-type="idl"} attribute of the [parent media
        source](#parent-media-source){#ref-for-parent-media-source-20
        .internalDFN link-type="dfn|abstract-op"} is in the
        \"[`ended`](#dom-readystate-ended){#ref-for-dom-readystate-ended-12
        .internalDFN link-type="idl"}\" state then run the following
        steps:

        1.  Set the
            [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-32
            .internalDFN link-type="idl"} attribute of the [parent media
            source](#parent-media-source){#ref-for-parent-media-source-21
            .internalDFN link-type="dfn|abstract-op"} to
            \"[`open`](#dom-readystate-open){#ref-for-dom-readystate-open-18
            .internalDFN link-type="idl"}\"
        2.  [Queue a
            task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
            to [fire an
            event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
            named
            [`sourceopen`](#dfn-sourceopen){#ref-for-dfn-sourceopen-6
            .internalDFN link-type="idl" lt="sourceopen"} at the [parent
            media
            source](#parent-media-source){#ref-for-parent-media-source-22
            .internalDFN link-type="dfn|abstract-op"}.

    7.  Run the [range
        removal](#dfn-range-removal){#ref-for-dfn-range-removal-2
        .internalDFN link-type="dfn|abstract-op"} algorithm with
        `start`{.variable data-type="double"} and `end`{.variable
        data-type="unrestricted double"} as the start and end of the
        removal range.
::::

:::::::: {#track-buffers .section}
::: header-wrapper
### 5.3 Track Buffers {#x5-3-track-buffers}

[](#track-buffers){.self-link aria-label="Permalink for Section 5.3"}
:::

A [track buffer]{#track-buffer .dfn plurals="track buffers" tabindex="0"
aria-haspopup="dialog" dfn-type="dfn"} stores the [track
descriptions](#dfn-track-description){#ref-for-dfn-track-description-2
.internalDFN link-type="dfn|abstract-op"} and [coded
frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-13 .internalDFN
link-type="dfn|abstract-op"} for an individual track. The track buffer
is updated as [initialization
segments](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-5
.internalDFN link-type="dfn|abstract-op"} and [media
segments](#dfn-media-segment){#ref-for-dfn-media-segment-7 .internalDFN
link-type="dfn|abstract-op"} are appended to the
[`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-60
.internalDFN link-type="idl" lt="SourceBuffer"}.

Each [track buffer](#track-buffer){#ref-for-track-buffer-8 .internalDFN
link-type="dfn|abstract-op"} has a [last decode
timestamp]{#last-decode-timestamp .dfn tabindex="0"
aria-haspopup="dialog" dfn-type="dfn"} variable that stores the decode
timestamp of the last [coded
frame](#dfn-coded-frame){#ref-for-dfn-coded-frame-14 .internalDFN
link-type="dfn|abstract-op"} appended in the current [coded frame
group](#dfn-coded-frame-group){#ref-for-dfn-coded-frame-group-1
.internalDFN link-type="dfn|abstract-op"}. The variable is initially
unset to indicate that no [coded
frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-15 .internalDFN
link-type="dfn|abstract-op"} have been appended yet.

Each [track buffer](#track-buffer){#ref-for-track-buffer-9 .internalDFN
link-type="dfn|abstract-op"} has a [last frame
duration]{#last-frame-duration .dfn tabindex="0" aria-haspopup="dialog"
dfn-type="dfn"} variable that stores the [coded frame
duration](#dfn-coded-frame-duration){#ref-for-dfn-coded-frame-duration-5
.internalDFN link-type="dfn|abstract-op"} of the last [coded
frame](#dfn-coded-frame){#ref-for-dfn-coded-frame-16 .internalDFN
link-type="dfn|abstract-op"} appended in the current [coded frame
group](#dfn-coded-frame-group){#ref-for-dfn-coded-frame-group-2
.internalDFN link-type="dfn|abstract-op"}. The variable is initially
unset to indicate that no [coded
frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-17 .internalDFN
link-type="dfn|abstract-op"} have been appended yet.

Each [track buffer](#track-buffer){#ref-for-track-buffer-10 .internalDFN
link-type="dfn|abstract-op"} has a [highest end
timestamp]{#highest-end-timestamp .dfn tabindex="0"
aria-haspopup="dialog" dfn-type="dfn"} variable that stores the highest
[coded frame end
timestamp](#dfn-coded-frame-end-timestamp){#ref-for-dfn-coded-frame-end-timestamp-1
.internalDFN link-type="dfn|abstract-op"} across all [coded
frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-18 .internalDFN
link-type="dfn|abstract-op"} in the current [coded frame
group](#dfn-coded-frame-group){#ref-for-dfn-coded-frame-group-3
.internalDFN link-type="dfn|abstract-op"} that were appended to this
track buffer. The variable is initially unset to indicate that no [coded
frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-19 .internalDFN
link-type="dfn|abstract-op"} have been appended yet.

Each [track buffer](#track-buffer){#ref-for-track-buffer-11 .internalDFN
link-type="dfn|abstract-op"} has a [need random access point
flag]{#need-RAP-flag .dfn tabindex="0" aria-haspopup="dialog"
dfn-type="dfn"} variable that keeps track of whether the track buffer is
waiting for a [random access
point](#random-access-point){#ref-for-random-access-point-2 .internalDFN
link-type="dfn|abstract-op"} [coded
frame](#dfn-coded-frame){#ref-for-dfn-coded-frame-20 .internalDFN
link-type="dfn|abstract-op"}. The variable is initially set to true to
indicate that [random access
point](#random-access-point){#ref-for-random-access-point-3 .internalDFN
link-type="dfn|abstract-op"} [coded
frame](#dfn-coded-frame){#ref-for-dfn-coded-frame-21 .internalDFN
link-type="dfn|abstract-op"} is needed before anything can be added to
the [track buffer](#track-buffer){#ref-for-track-buffer-12 .internalDFN
link-type="dfn|abstract-op"}.

Each [track buffer](#track-buffer){#ref-for-track-buffer-13 .internalDFN
link-type="dfn|abstract-op"} has a [track buffer
ranges]{#track-buffer-ranges .dfn tabindex="0" aria-haspopup="dialog"
dfn-type="dfn"} variable that represents the presentation time ranges
occupied by the [coded
frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-22 .internalDFN
link-type="dfn|abstract-op"} currently stored in the track buffer.

:::: {#issue-container-generatedID-46 .note role="note"}
::: {#h-note-46 .note-title .marker role="heading" aria-level="4"}
Note
:::

For track buffer ranges, these presentation time ranges are based on
[presentation
timestamps](#presentation-timestamp){#ref-for-presentation-timestamp-14
.internalDFN link-type="dfn|abstract-op"}, frame durations, and
potentially coded frame group start times for coded frame groups across
track buffers in a muxed
[`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-61
.internalDFN link-type="idl" lt="SourceBuffer"}.
::::

For specification purposes, this information is treated as if it were
stored in a [normalized TimeRanges
object](https://html.spec.whatwg.org/multipage/media.html#normalised-timeranges-object).
Intersected [track buffer
ranges](#track-buffer-ranges){#ref-for-track-buffer-ranges-5
.internalDFN link-type="dfn|abstract-op"} are used to report
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"}\'s
[`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered){link-type="attribute"},
and *MUST* therefore support uninterrupted playback within each range of
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"}\'s
[`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered){link-type="attribute"}.

:::: {#issue-container-generatedID-47 .note role="note"}
::: {#h-note-47 .note-title .marker role="heading" aria-level="4"}
Note
:::

These coded frame group start times differ slightly from those mentioned
in the [coded frame
processing](#dfn-coded-frame-processing){#ref-for-dfn-coded-frame-processing-3
.internalDFN link-type="dfn|abstract-op"} algorithm in that they are the
earliest [presentation
timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-15
.internalDFN link-type="dfn|abstract-op"} across all track buffers
following a discontinuity. Discontinuities can occur within the [coded
frame
processing](#dfn-coded-frame-processing){#ref-for-dfn-coded-frame-processing-4
.internalDFN link-type="dfn|abstract-op"} algorithm or result from the
[coded frame
removal](#dfn-coded-frame-removal){#ref-for-dfn-coded-frame-removal-2
.internalDFN link-type="dfn|abstract-op"} algorithm, regardless of
[`mode`](#dom-sourcebuffer-mode){#ref-for-dom-sourcebuffer-mode-7
.internalDFN link-type="idl"}. The threshold for determining
disjointness of [track buffer
ranges](#track-buffer-ranges){#ref-for-track-buffer-ranges-6
.internalDFN link-type="dfn|abstract-op"} is implementation-specific.
For example, to reduce unexpected playback stalls, implementations *MAY*
approximate the [coded frame
processing](#dfn-coded-frame-processing){#ref-for-dfn-coded-frame-processing-5
.internalDFN link-type="dfn|abstract-op"} algorithm\'s discontinuity
detection logic by coalescing adjacent ranges separated by a gap smaller
than 2 times the maximum frame duration buffered so far in this [track
buffer](#track-buffer){#ref-for-track-buffer-14 .internalDFN
link-type="dfn|abstract-op"}. Implementations *MAY* also use coded frame
group start times as range start times across [track
buffers](#track-buffer){#ref-for-track-buffer-15 .internalDFN
link-type="dfn|abstract-op"} in a muxed
[`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-62
.internalDFN link-type="idl" lt="SourceBuffer"} to further reduce
unexpected playback stalls.
::::
::::::::

:::: {#sourcebuffer-events .section}
::: header-wrapper
### 5.4 Event Summary {#x5-4-event-summary}

[](#sourcebuffer-events){.self-link
aria-label="Permalink for Section 5.4"}
:::

  Event name                                                                                                   Interface                                                                         Dispatched when\...
  ------------------------------------------------------------------------------------------------------------ --------------------------------------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  [updatestart]{#dfn-updatestart .dfn .event dfn-type="event" tabindex="0" aria-haspopup="dialog" export=""}   [`Event`](https://dom.spec.whatwg.org/#event){link-type="interface" lt="Event"}   [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-63 .internalDFN link-type="idl" lt="SourceBuffer"}\'s [`updating`](#dom-sourcebuffer-updating){#ref-for-dom-sourcebuffer-updating-15 .internalDFN link-type="idl"} transitions from false to true.
  [update]{#dfn-update .dfn .event dfn-type="event" tabindex="0" aria-haspopup="dialog" export=""}             [`Event`](https://dom.spec.whatwg.org/#event){link-type="interface" lt="Event"}   A [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-64 .internalDFN link-type="idl" lt="SourceBuffer"}\'s append or remove successfully completed. [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-65 .internalDFN link-type="idl" lt="SourceBuffer"}\'s [`updating`](#dom-sourcebuffer-updating){#ref-for-dom-sourcebuffer-updating-16 .internalDFN link-type="idl"} transitions from true to false.
  [updateend]{#dfn-updateend .dfn .event dfn-type="event" tabindex="0" aria-haspopup="dialog" export=""}       [`Event`](https://dom.spec.whatwg.org/#event){link-type="interface" lt="Event"}   The append or remove of a [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-66 .internalDFN link-type="idl" lt="SourceBuffer"} ended.
  [error]{#dfn-error .dfn .event dfn-type="event" tabindex="0" aria-haspopup="dialog" export=""}               [`Event`](https://dom.spec.whatwg.org/#event){link-type="interface" lt="Event"}   An error occurred during the append to a [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-67 .internalDFN link-type="idl" lt="SourceBuffer"}. [`updating`](#dom-sourcebuffer-updating){#ref-for-dom-sourcebuffer-updating-17 .internalDFN link-type="idl"} transitions from true to false.
  [abort]{#dfn-abort .dfn .event dfn-type="event" tabindex="0" aria-haspopup="dialog" export=""}               [`Event`](https://dom.spec.whatwg.org/#event){link-type="interface" lt="Event"}   The [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-68 .internalDFN link-type="idl" lt="SourceBuffer"}\'s append was aborted by an [`abort`](#dom-sourcebuffer-abort){#ref-for-dom-sourcebuffer-abort-3 .internalDFN link-type="idl" lt="abort()"}`()` call. [`updating`](#dom-sourcebuffer-updating){#ref-for-dom-sourcebuffer-updating-18 .internalDFN link-type="idl"} transitions from true to false.
::::

::::::::::::::::::::::::::::::::::: {#sourcebuffer-algorithms .section}
::: header-wrapper
### 5.5 Algorithms {#x5-5-algorithms}

[](#sourcebuffer-algorithms){.self-link
aria-label="Permalink for Section 5.5"}
:::

:::::: {#sourcebuffer-segment-parser-loop .section}
::: header-wrapper
#### 5.5.1 [Segment Parser Loop]{#dfn-segment-parser-loop .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"} {#x5-5-1-segment-parser-loop}

[](#sourcebuffer-segment-parser-loop){.self-link
aria-label="Permalink for Section 5.5.1"}
:::

Each [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-69
.internalDFN link-type="idl" lt="SourceBuffer"} object has an
[\[\[append state\]\]]{#dfn-append-state .dfn dfn-for="SourceBuffer"
idl="" noexport="" dfn-type="attribute" tabindex="0"
aria-haspopup="dialog"} internal slot that keeps track of the high-level
segment parsing state. It is initially set to
[WAITING_FOR_SEGMENT](#sourcebuffer-waiting-for-segment){#ref-for-sourcebuffer-waiting-for-segment-1
.internalDFN link-type="dfn|abstract-op"} and can transition to the
following states as data is appended.

  Append state name                                                                                                      Description
  ---------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  [WAITING_FOR_SEGMENT]{#sourcebuffer-waiting-for-segment .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"}       Waiting for the start of an [initialization segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-6 .internalDFN link-type="dfn|abstract-op"} or [media segment](#dfn-media-segment){#ref-for-dfn-media-segment-8 .internalDFN link-type="dfn|abstract-op"} to be appended.
  [PARSING_INIT_SEGMENT]{#sourcebuffer-parsing-init-segment .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"}     Currently parsing an [initialization segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-7 .internalDFN link-type="dfn|abstract-op"}.
  [PARSING_MEDIA_SEGMENT]{#sourcebuffer-parsing-media-segment .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"}   Currently parsing a [media segment](#dfn-media-segment){#ref-for-dfn-media-segment-9 .internalDFN link-type="dfn|abstract-op"}.

Each [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-70
.internalDFN link-type="idl" lt="SourceBuffer"} object has an [\[\[input
buffer\]\]]{#dfn-input-buffer .dfn dfn-for="SourceBuffer" idl=""
noexport="" dfn-type="attribute" tabindex="0" aria-haspopup="dialog"}
internal slot that is a byte buffer that holds unparsed bytes across
[`appendBuffer`](#dom-sourcebuffer-appendbuffer){#ref-for-dom-sourcebuffer-appendbuffer-7
.internalDFN link-type="idl" lt="appendBuffer()"}`()` calls. The buffer
is empty when the
[`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-71
.internalDFN link-type="idl" lt="SourceBuffer"} object is created.

Each [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-72
.internalDFN link-type="idl" lt="SourceBuffer"} object has a [\[\[buffer
full flag\]\]]{#dfn-buffer-full-flag .dfn dfn-for="SourceBuffer" idl=""
noexport="" dfn-type="attribute" tabindex="0" aria-haspopup="dialog"}
internal slot that keeps track of whether
[`appendBuffer`](#dom-sourcebuffer-appendbuffer){#ref-for-dom-sourcebuffer-appendbuffer-8
.internalDFN link-type="idl" lt="appendBuffer()"}`()` is allowed to
accept more bytes. It is set to false when the
[`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-73
.internalDFN link-type="idl" lt="SourceBuffer"} object is created and
gets updated as data is appended and removed.

Each [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-74
.internalDFN link-type="idl" lt="SourceBuffer"} object has a [\[\[group
start timestamp\]\]]{#dfn-group-start-timestamp .dfn
dfn-for="SourceBuffer" idl="" noexport="" dfn-type="attribute"
tabindex="0" aria-haspopup="dialog"} internal slot that keeps track of
the starting timestamp for a new [coded frame
group](#dfn-coded-frame-group){#ref-for-dfn-coded-frame-group-4
.internalDFN link-type="dfn|abstract-op"} in the
\"[`sequence`](#dom-appendmode-sequence){#ref-for-dom-appendmode-sequence-7
.internalDFN link-type="idl"}\" mode. It is unset when the SourceBuffer
object is created and gets updated when the
[`mode`](#dom-sourcebuffer-mode){#ref-for-dom-sourcebuffer-mode-8
.internalDFN link-type="idl"} attribute equals
\"[`sequence`](#dom-appendmode-sequence){#ref-for-dom-appendmode-sequence-8
.internalDFN link-type="idl"}\" and the
[`timestampOffset`](#dom-sourcebuffer-timestampoffset){#ref-for-dom-sourcebuffer-timestampoffset-5
.internalDFN link-type="idl"} attribute is set, or the [coded frame
processing](#dfn-coded-frame-processing){#ref-for-dfn-coded-frame-processing-6
.internalDFN link-type="dfn|abstract-op"} algorithm runs.

Each [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-75
.internalDFN link-type="idl" lt="SourceBuffer"} object has a [\[\[group
end timestamp\]\]]{#dfn-group-end-timestamp .dfn dfn-for="SourceBuffer"
idl="" noexport="" dfn-type="attribute" tabindex="0"
aria-haspopup="dialog"} internal slot that stores the highest [coded
frame end
timestamp](#dfn-coded-frame-end-timestamp){#ref-for-dfn-coded-frame-end-timestamp-2
.internalDFN link-type="dfn|abstract-op"} across all [coded
frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-23 .internalDFN
link-type="dfn|abstract-op"} in the current [coded frame
group](#dfn-coded-frame-group){#ref-for-dfn-coded-frame-group-5
.internalDFN link-type="dfn|abstract-op"}. It is set to 0 when the
SourceBuffer object is created and gets updated by the [coded frame
processing](#dfn-coded-frame-processing){#ref-for-dfn-coded-frame-processing-7
.internalDFN link-type="dfn|abstract-op"} algorithm.

:::: {#issue-container-generatedID-48 .note role="note"}
::: {#h-note-48 .note-title .marker role="heading" aria-level="5"}
Note
:::

The
[`[[group end timestamp]]`](#dfn-group-end-timestamp){#ref-for-dfn-group-end-timestamp-2
.internalDFN link-type="attribute" lt="[[group end timestamp]]"} stores
the highest [coded frame end
timestamp](#dfn-coded-frame-end-timestamp){#ref-for-dfn-coded-frame-end-timestamp-3
.internalDFN link-type="dfn|abstract-op"} across all [track
buffers](#track-buffer){#ref-for-track-buffer-16 .internalDFN
link-type="dfn|abstract-op"} in a
[`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-76
.internalDFN link-type="idl" lt="SourceBuffer"}. Therefore, care should
be taken in setting the
[`mode`](#dom-sourcebuffer-mode){#ref-for-dom-sourcebuffer-mode-9
.internalDFN link-type="idl"} attribute when appending multiplexed
segments in which the timestamps are not aligned across tracks.
::::

Each [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-77
.internalDFN link-type="idl" lt="SourceBuffer"} object has a
[\[\[generate timestamps flag\]\]]{#dfn-generate-timestamps-flag .dfn
dfn-for="SourceBuffer" export="" idl="" dfn-type="attribute"
tabindex="0" aria-haspopup="dialog"} internal slot that is a boolean
that keeps track of whether timestamps need to be generated for the
[coded frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-24
.internalDFN link-type="dfn|abstract-op"} passed to the [coded frame
processing](#dfn-coded-frame-processing){#ref-for-dfn-coded-frame-processing-8
.internalDFN link-type="dfn|abstract-op"} algorithm. This flag is set by
[`addSourceBuffer`](#dom-mediasource-addsourcebuffer){#ref-for-dom-mediasource-addsourcebuffer-6
.internalDFN link-type="idl" lt="addSourceBuffer()"}`()` when the
[`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-78
.internalDFN link-type="idl" lt="SourceBuffer"} object is created and is
updated by
[`changeType`](#dom-sourcebuffer-changetype){#ref-for-dom-sourcebuffer-changetype-5
.internalDFN link-type="idl" lt="changeType()"}`()`.

When the segment parser loop algorithm is invoked, run the following
steps:

1.  *Loop Top:* If the
    [`[[input buffer]]`](#dfn-input-buffer){#ref-for-dfn-input-buffer-2
    .internalDFN link-type="attribute" lt="[[input buffer]]"} is empty,
    then jump to the *need more data* step below.

2.  If the
    [`[[input buffer]]`](#dfn-input-buffer){#ref-for-dfn-input-buffer-3
    .internalDFN link-type="attribute" lt="[[input buffer]]"} contains
    bytes that violate the [SourceBuffer byte stream format
    specification](#dfn-sourcebuffer-byte-stream-format-specification){#ref-for-dfn-sourcebuffer-byte-stream-format-specification-1
    .internalDFN link-type="dfn|abstract-op"}, then run the [append
    error](#dfn-append-error){#ref-for-dfn-append-error-3 .internalDFN
    link-type="dfn|abstract-op"} algorithm and abort this algorithm.

3.  Remove any bytes that the [byte stream format
    specifications](#byte-stream-format-specs){#ref-for-byte-stream-format-specs-5
    .internalDFN link-type="dfn|abstract-op"} say *MUST* be ignored from
    the start of the
    [`[[input buffer]]`](#dfn-input-buffer){#ref-for-dfn-input-buffer-4
    .internalDFN link-type="attribute" lt="[[input buffer]]"}.

4.  If the
    [`[[append state]]`](#dfn-append-state){#ref-for-dfn-append-state-3
    .internalDFN link-type="attribute" lt="[[append state]]"} equals
    [WAITING_FOR_SEGMENT](#sourcebuffer-waiting-for-segment){#ref-for-sourcebuffer-waiting-for-segment-2
    .internalDFN link-type="dfn|abstract-op"}, then run the following
    steps:

    1.  If the beginning of the
        [`[[input buffer]]`](#dfn-input-buffer){#ref-for-dfn-input-buffer-5
        .internalDFN link-type="attribute" lt="[[input buffer]]"}
        indicates the start of an [initialization
        segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-8
        .internalDFN link-type="dfn|abstract-op"}, set the
        [`[[append state]]`](#dfn-append-state){#ref-for-dfn-append-state-4
        .internalDFN link-type="attribute" lt="[[append state]]"} to
        [PARSING_INIT_SEGMENT](#sourcebuffer-parsing-init-segment){#ref-for-sourcebuffer-parsing-init-segment-1
        .internalDFN link-type="dfn|abstract-op"}.
    2.  If the beginning of the
        [`[[input buffer]]`](#dfn-input-buffer){#ref-for-dfn-input-buffer-6
        .internalDFN link-type="attribute" lt="[[input buffer]]"}
        indicates the start of a [media
        segment](#dfn-media-segment){#ref-for-dfn-media-segment-10
        .internalDFN link-type="dfn|abstract-op"}, set
        [`[[append state]]`](#dfn-append-state){#ref-for-dfn-append-state-5
        .internalDFN link-type="attribute" lt="[[append state]]"} to
        [PARSING_MEDIA_SEGMENT](#sourcebuffer-parsing-media-segment){#ref-for-sourcebuffer-parsing-media-segment-3
        .internalDFN link-type="dfn|abstract-op"}.
    3.  Jump to the *loop top* step above.

5.  If the
    [`[[append state]]`](#dfn-append-state){#ref-for-dfn-append-state-6
    .internalDFN link-type="attribute" lt="[[append state]]"} equals
    [PARSING_INIT_SEGMENT](#sourcebuffer-parsing-init-segment){#ref-for-sourcebuffer-parsing-init-segment-2
    .internalDFN link-type="dfn|abstract-op"}, then run the following
    steps:

    1.  If the
        [`[[input buffer]]`](#dfn-input-buffer){#ref-for-dfn-input-buffer-7
        .internalDFN link-type="attribute" lt="[[input buffer]]"} does
        not contain a complete [initialization
        segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-9
        .internalDFN link-type="dfn|abstract-op"} yet, then jump to the
        *need more data* step below.
    2.  Run the [initialization segment
        received](#dfn-initialization-segment-received){#ref-for-dfn-initialization-segment-received-1
        .internalDFN link-type="dfn|abstract-op"} algorithm.
    3.  Remove the [initialization
        segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-10
        .internalDFN link-type="dfn|abstract-op"} bytes from the
        beginning of the
        [`[[input buffer]]`](#dfn-input-buffer){#ref-for-dfn-input-buffer-8
        .internalDFN link-type="attribute" lt="[[input buffer]]"}.
    4.  Set
        [`[[append state]]`](#dfn-append-state){#ref-for-dfn-append-state-7
        .internalDFN link-type="attribute" lt="[[append state]]"} to
        [WAITING_FOR_SEGMENT](#sourcebuffer-waiting-for-segment){#ref-for-sourcebuffer-waiting-for-segment-3
        .internalDFN link-type="dfn|abstract-op"}.
    5.  Jump to the *loop top* step above.

6.  If the
    [`[[append state]]`](#dfn-append-state){#ref-for-dfn-append-state-8
    .internalDFN link-type="attribute" lt="[[append state]]"} equals
    [PARSING_MEDIA_SEGMENT](#sourcebuffer-parsing-media-segment){#ref-for-sourcebuffer-parsing-media-segment-4
    .internalDFN link-type="dfn|abstract-op"}, then run the following
    steps:

    1.  If the
        [`[[first initialization segment received flag]]`](#dfn-first-initialization-segment-received-flag){#ref-for-dfn-first-initialization-segment-received-flag-1
        .internalDFN link-type="attribute"
        lt="[[first initialization segment received flag]]"} is false or
        the
        [`[[pending initialization segment for changeType flag]]`](#dfn-pending-initialization-segment-for-changetype-flag){#ref-for-dfn-pending-initialization-segment-for-changetype-flag-2
        .internalDFN link-type="attribute"
        lt="[[pending initialization segment for changeType flag]]"} is
        true, then run the [append
        error](#dfn-append-error){#ref-for-dfn-append-error-4
        .internalDFN link-type="dfn|abstract-op"} algorithm and abort
        this algorithm.
    2.  If the
        [`[[input buffer]]`](#dfn-input-buffer){#ref-for-dfn-input-buffer-9
        .internalDFN link-type="attribute" lt="[[input buffer]]"}
        contains one or more complete [coded
        frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-25
        .internalDFN link-type="dfn|abstract-op"}, then run the [coded
        frame
        processing](#dfn-coded-frame-processing){#ref-for-dfn-coded-frame-processing-9
        .internalDFN link-type="dfn|abstract-op"} algorithm.

        :::: {#issue-container-generatedID-49 .note role="note"}
        ::: {#h-note-49 .note-title .marker role="heading" aria-level="5"}
        Note
        :::

        The frequency at which the coded frame processing algorithm is
        run is implementation-specific. The coded frame processing
        algorithm *MAY* be called when the input buffer contains the
        complete media segment or it *MAY* be called multiple times as
        complete coded frames are added to the input buffer.
        ::::
    3.  If this
        [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-79
        .internalDFN link-type="idl" lt="SourceBuffer"} is full and
        cannot accept more media data, then set the
        [`[[buffer full flag]]`](#dfn-buffer-full-flag){#ref-for-dfn-buffer-full-flag-1
        .internalDFN link-type="attribute" lt="[[buffer full flag]]"} to
        true.
    4.  If the
        [`[[input buffer]]`](#dfn-input-buffer){#ref-for-dfn-input-buffer-10
        .internalDFN link-type="attribute" lt="[[input buffer]]"} does
        not contain a complete [media
        segment](#dfn-media-segment){#ref-for-dfn-media-segment-11
        .internalDFN link-type="dfn|abstract-op"}, then jump to the
        *need more data* step below.
    5.  Remove the [media
        segment](#dfn-media-segment){#ref-for-dfn-media-segment-12
        .internalDFN link-type="dfn|abstract-op"} bytes from the
        beginning of the
        [`[[input buffer]]`](#dfn-input-buffer){#ref-for-dfn-input-buffer-11
        .internalDFN link-type="attribute" lt="[[input buffer]]"}.
    6.  Set
        [`[[append state]]`](#dfn-append-state){#ref-for-dfn-append-state-9
        .internalDFN link-type="attribute" lt="[[append state]]"} to
        [WAITING_FOR_SEGMENT](#sourcebuffer-waiting-for-segment){#ref-for-sourcebuffer-waiting-for-segment-4
        .internalDFN link-type="dfn|abstract-op"}.
    7.  Jump to the *loop top* step above.

7.  *Need more data:* Return control to the calling algorithm.
::::::

:::: {#sourcebuffer-reset-parser-state .section}
::: header-wrapper
#### 5.5.2 [Reset Parser State]{#dfn-reset-parser-state .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"} {#x5-5-2-reset-parser-state}

[](#sourcebuffer-reset-parser-state){.self-link
aria-label="Permalink for Section 5.5.2"}
:::

When the parser state needs to be reset, run the following steps:

1.  If the
    [`[[append state]]`](#dfn-append-state){#ref-for-dfn-append-state-10
    .internalDFN link-type="attribute" lt="[[append state]]"} equals
    [PARSING_MEDIA_SEGMENT](#sourcebuffer-parsing-media-segment){#ref-for-sourcebuffer-parsing-media-segment-5
    .internalDFN link-type="dfn|abstract-op"} and the
    [`[[input buffer]]`](#dfn-input-buffer){#ref-for-dfn-input-buffer-12
    .internalDFN link-type="attribute" lt="[[input buffer]]"} contains
    some complete [coded
    frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-26 .internalDFN
    link-type="dfn|abstract-op"}, then run the [coded frame
    processing](#dfn-coded-frame-processing){#ref-for-dfn-coded-frame-processing-10
    .internalDFN link-type="dfn|abstract-op"} algorithm until all of
    these complete [coded
    frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-27 .internalDFN
    link-type="dfn|abstract-op"} have been processed.
2.  Unset the [last decode
    timestamp](#last-decode-timestamp){#ref-for-last-decode-timestamp-1
    .internalDFN link-type="dfn|abstract-op"} on all [track
    buffers](#track-buffer){#ref-for-track-buffer-17 .internalDFN
    link-type="dfn|abstract-op"}.
3.  Unset the [last frame
    duration](#last-frame-duration){#ref-for-last-frame-duration-1
    .internalDFN link-type="dfn|abstract-op"} on all [track
    buffers](#track-buffer){#ref-for-track-buffer-18 .internalDFN
    link-type="dfn|abstract-op"}.
4.  Unset the [highest end
    timestamp](#highest-end-timestamp){#ref-for-highest-end-timestamp-1
    .internalDFN link-type="dfn|abstract-op"} on all [track
    buffers](#track-buffer){#ref-for-track-buffer-19 .internalDFN
    link-type="dfn|abstract-op"}.
5.  Set the [need random access point
    flag](#need-RAP-flag){#ref-for-need-RAP-flag-1 .internalDFN
    link-type="dfn|abstract-op"} on all [track
    buffers](#track-buffer){#ref-for-track-buffer-20 .internalDFN
    link-type="dfn|abstract-op"} to true.
6.  If the
    [`mode`](#dom-sourcebuffer-mode){#ref-for-dom-sourcebuffer-mode-10
    .internalDFN link-type="idl"} attribute equals
    \"[`sequence`](#dom-appendmode-sequence){#ref-for-dom-appendmode-sequence-9
    .internalDFN link-type="idl"}\", then set the
    [`[[group start timestamp]]`](#dfn-group-start-timestamp){#ref-for-dfn-group-start-timestamp-3
    .internalDFN link-type="attribute" lt="[[group start timestamp]]"}
    to the
    [`[[group end timestamp]]`](#dfn-group-end-timestamp){#ref-for-dfn-group-end-timestamp-3
    .internalDFN link-type="attribute" lt="[[group end timestamp]]"}
7.  Remove all bytes from the
    [`[[input buffer]]`](#dfn-input-buffer){#ref-for-dfn-input-buffer-13
    .internalDFN link-type="attribute" lt="[[input buffer]]"}.
8.  Set
    [`[[append state]]`](#dfn-append-state){#ref-for-dfn-append-state-11
    .internalDFN link-type="attribute" lt="[[append state]]"} to
    [WAITING_FOR_SEGMENT](#sourcebuffer-waiting-for-segment){#ref-for-sourcebuffer-waiting-for-segment-5
    .internalDFN link-type="dfn|abstract-op"}.
::::

:::: {#sourcebuffer-append-error .section}
::: header-wrapper
#### 5.5.3 [Append Error]{#dfn-append-error .dfn export="" tabindex="0" aria-haspopup="dialog" dfn-type="dfn"} {#x5-5-3-append-error}

[](#sourcebuffer-append-error){.self-link
aria-label="Permalink for Section 5.5.3"}
:::

This algorithm is called when an error occurs during an append.

1.  Run the [reset parser
    state](#dfn-reset-parser-state){#ref-for-dfn-reset-parser-state-3
    .internalDFN link-type="dfn|abstract-op"} algorithm.
2.  Set the
    [`updating`](#dom-sourcebuffer-updating){#ref-for-dom-sourcebuffer-updating-19
    .internalDFN link-type="idl"} attribute to false.
3.  [Queue a
    task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
    to [fire an
    event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
    named [`error`](#dfn-error){#ref-for-dfn-error-2 .internalDFN
    link-type="idl" lt="error"} at this
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-80
    .internalDFN link-type="idl" lt="SourceBuffer"} object.
4.  [Queue a
    task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
    to [fire an
    event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
    named [`updateend`](#dfn-updateend){#ref-for-dfn-updateend-4
    .internalDFN link-type="idl" lt="updateend"} at this
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-81
    .internalDFN link-type="idl" lt="SourceBuffer"} object.
5.  Run the [end of
    stream](#dfn-end-of-stream){#ref-for-dfn-end-of-stream-2
    .internalDFN link-type="dfn|abstract-op"} algorithm with the
    `error`{.variable data-type="EndOfStreamError"} parameter set to
    \"[`decode`](#dom-endofstreamerror-decode){#ref-for-dom-endofstreamerror-decode-3
    .internalDFN link-type="idl"}\".
::::

:::: {#sourcebuffer-prepare-append .section}
::: header-wrapper
#### 5.5.4 [Prepare Append]{#dfn-prepare-append .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"} {#x5-5-4-prepare-append}

[](#sourcebuffer-prepare-append){.self-link
aria-label="Permalink for Section 5.5.4"}
:::

When an append operation begins, the following steps are run to validate
and prepare the
[`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-82
.internalDFN link-type="idl" lt="SourceBuffer"}.

1.  If the
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-83
    .internalDFN link-type="idl" lt="SourceBuffer"} has been removed
    from the
    [`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-30
    .internalDFN link-type="idl"} attribute of the [parent media
    source](#parent-media-source){#ref-for-parent-media-source-23
    .internalDFN link-type="dfn|abstract-op"} then throw an
    [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror){link-type="exception"
    lt="InvalidStateError"} exception and abort these steps.

2.  If the
    [`updating`](#dom-sourcebuffer-updating){#ref-for-dom-sourcebuffer-updating-20
    .internalDFN link-type="idl"} attribute equals true, then throw an
    [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror){link-type="exception"
    lt="InvalidStateError"} exception and abort these steps.

3.  Let `recent element error`{.variable data-type="boolean"} be
    determined as follows:

    If the [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-98 .internalDFN link-type="idl" lt="MediaSource"} was constructed in a [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface" lt="Window"}
    :   Let `recent element error`{.variable data-type="boolean"} be
        true if the
        [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
        lt="HTMLMediaElement"}\'s
        [`error`](#dfn-error){#ref-for-dfn-error-3 .internalDFN
        link-type="idl"} attribute is not null. If that attribute is
        null, then let `recent element error`{.variable
        data-type="boolean"} be false.

    Otherwise
    :   Let `recent element error`{.variable data-type="boolean"} be the
        value resulting from the steps for the
        [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
        lt="Window"} case, but run on the
        [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
        lt="Window"}
        [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
        lt="HTMLMediaElement"} on any change to its
        [`error`](#dfn-error){#ref-for-dfn-error-4 .internalDFN
        link-type="idl"} attribute and communicated by using
        [`[[port to worker]]`](#dfn-port-to-worker){#ref-for-dfn-port-to-worker-7
        .internalDFN link-type="attribute" lt="[[port to worker]]"}
        implicit messages. If such a message has not yet been received,
        then let `recent element error`{.variable data-type="boolean"}
        be false.

4.  If `recent element error`{.variable data-type="boolean"} is true,
    then throw an
    [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror){link-type="exception"
    lt="InvalidStateError"} exception and abort these steps.

5.  If the
    [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-33
    .internalDFN link-type="idl"} attribute of the [parent media
    source](#parent-media-source){#ref-for-parent-media-source-24
    .internalDFN link-type="dfn|abstract-op"} is in the
    \"[`ended`](#dom-readystate-ended){#ref-for-dom-readystate-ended-13
    .internalDFN link-type="idl"}\" state then run the following steps:

    1.  Set the
        [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-34
        .internalDFN link-type="idl"} attribute of the [parent media
        source](#parent-media-source){#ref-for-parent-media-source-25
        .internalDFN link-type="dfn|abstract-op"} to
        \"[`open`](#dom-readystate-open){#ref-for-dom-readystate-open-19
        .internalDFN link-type="idl"}\"
    2.  [Queue a
        task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
        to [fire an
        event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
        named [`sourceopen`](#dfn-sourceopen){#ref-for-dfn-sourceopen-7
        .internalDFN link-type="idl" lt="sourceopen"} at the [parent
        media
        source](#parent-media-source){#ref-for-parent-media-source-26
        .internalDFN link-type="dfn|abstract-op"}.

6.  Run the [coded frame
    eviction](#dfn-coded-frame-eviction){#ref-for-dfn-coded-frame-eviction-1
    .internalDFN link-type="dfn|abstract-op"} algorithm.

7.  If the
    [`[[buffer full flag]]`](#dfn-buffer-full-flag){#ref-for-dfn-buffer-full-flag-2
    .internalDFN link-type="attribute" lt="[[buffer full flag]]"} equals
    true, then throw a
    [`QuotaExceededError`](https://webidl.spec.whatwg.org/#quotaexceedederror){link-type="interface"
    lt="QuotaExceededError"} exception and abort these steps.

    :::: {#issue-container-generatedID-50 .note role="note"}
    ::: {#h-note-50 .note-title .marker role="heading" aria-level="5"}
    Note
    :::

    This is the signal that the implementation was unable to evict
    enough data to accommodate the append or the append is too big. The
    web application *SHOULD* use
    [`remove`](#dom-sourcebuffer-remove){#ref-for-dom-sourcebuffer-remove-4
    .internalDFN link-type="idl" lt="remove()"}`()` to explicitly free
    up space and/or reduce the size of the append.
    ::::
::::

:::: {#sourcebuffer-buffer-append .section}
::: header-wrapper
#### 5.5.5 [Buffer Append]{#dfn-buffer-append .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"} {#x5-5-5-buffer-append}

[](#sourcebuffer-buffer-append){.self-link
aria-label="Permalink for Section 5.5.5"}
:::

When
[`appendBuffer`](#dom-sourcebuffer-appendbuffer){#ref-for-dom-sourcebuffer-appendbuffer-9
.internalDFN link-type="idl" lt="appendBuffer()"}`()` is called, the
following steps are run to process the appended data.

1.  Run the [segment parser
    loop](#dfn-segment-parser-loop){#ref-for-dfn-segment-parser-loop-1
    .internalDFN link-type="dfn|abstract-op"} algorithm.
2.  If the [segment parser
    loop](#dfn-segment-parser-loop){#ref-for-dfn-segment-parser-loop-2
    .internalDFN link-type="dfn|abstract-op"} algorithm in the previous
    step was aborted, then abort this algorithm.
3.  Set the
    [`updating`](#dom-sourcebuffer-updating){#ref-for-dom-sourcebuffer-updating-21
    .internalDFN link-type="idl"} attribute to false.
4.  [Queue a
    task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
    to [fire an
    event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
    named [`update`](#dfn-update){#ref-for-dfn-update-2 .internalDFN
    link-type="idl" lt="update"} at this
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-84
    .internalDFN link-type="idl" lt="SourceBuffer"} object.
5.  [Queue a
    task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
    to [fire an
    event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
    named [`updateend`](#dfn-updateend){#ref-for-dfn-updateend-5
    .internalDFN link-type="idl" lt="updateend"} at this
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-85
    .internalDFN link-type="idl" lt="SourceBuffer"} object.
::::

:::: {#sourcebuffer-range-removal .section}
::: header-wrapper
#### 5.5.6 [Range Removal]{#dfn-range-removal .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"} {#x5-5-6-range-removal}

[](#sourcebuffer-range-removal){.self-link
aria-label="Permalink for Section 5.5.6"}
:::

Follow these steps when a caller needs to initiate a JavaScript visible
range removal operation that blocks other SourceBuffer updates:

1.  Let `start`{.variable data-type="double"} equal the starting
    [presentation
    timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-16
    .internalDFN link-type="dfn|abstract-op"} for the removal range, in
    seconds measured from [presentation start
    time](#presentation-start-time){#ref-for-presentation-start-time-8
    .internalDFN link-type="dfn|abstract-op"}.
2.  Let `end`{.variable data-type="unrestricted double"} equal the end
    [presentation
    timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-17
    .internalDFN link-type="dfn|abstract-op"} for the removal range, in
    seconds measured from [presentation start
    time](#presentation-start-time){#ref-for-presentation-start-time-9
    .internalDFN link-type="dfn|abstract-op"}.
3.  Set the
    [`updating`](#dom-sourcebuffer-updating){#ref-for-dom-sourcebuffer-updating-22
    .internalDFN link-type="idl"} attribute to true.
4.  [Queue a
    task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
    to [fire an
    event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
    named [`updatestart`](#dfn-updatestart){#ref-for-dfn-updatestart-3
    .internalDFN link-type="idl" lt="updatestart"} at this
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-86
    .internalDFN link-type="idl" lt="SourceBuffer"} object.
5.  Return control to the caller and run the rest of the steps
    asynchronously.
6.  Run the [coded frame
    removal](#dfn-coded-frame-removal){#ref-for-dfn-coded-frame-removal-3
    .internalDFN link-type="dfn|abstract-op"} algorithm with
    `start`{.variable data-type="double"} and `end`{.variable
    data-type="unrestricted double"} as the start and end of the removal
    range.
7.  Set the
    [`updating`](#dom-sourcebuffer-updating){#ref-for-dom-sourcebuffer-updating-23
    .internalDFN link-type="idl"} attribute to false.
8.  [Queue a
    task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
    to [fire an
    event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
    named [`update`](#dfn-update){#ref-for-dfn-update-3 .internalDFN
    link-type="idl" lt="update"} at this
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-87
    .internalDFN link-type="idl" lt="SourceBuffer"} object.
9.  [Queue a
    task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
    to [fire an
    event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
    named [`updateend`](#dfn-updateend){#ref-for-dfn-updateend-6
    .internalDFN link-type="idl" lt="updateend"} at this
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-88
    .internalDFN link-type="idl" lt="SourceBuffer"} object.
::::

:::: {#sourcebuffer-init-segment-received .section}
::: header-wrapper
#### 5.5.7 [Initialization Segment Received]{#dfn-initialization-segment-received .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"} {#x5-5-7-initialization-segment-received}

[](#sourcebuffer-init-segment-received){.self-link
aria-label="Permalink for Section 5.5.7"}
:::

The following steps are run when the [segment parser
loop](#dfn-segment-parser-loop){#ref-for-dfn-segment-parser-loop-3
.internalDFN link-type="dfn|abstract-op"} successfully parses a complete
[initialization
segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-11
.internalDFN link-type="dfn|abstract-op"}:

Each SourceBuffer object has a [\[\[first initialization segment
received flag\]\]]{#dfn-first-initialization-segment-received-flag .dfn
dfn-for="SourceBuffer" idl="" noexport="" dfn-type="attribute"
tabindex="0" aria-haspopup="dialog"} internal slot that tracks whether
the first [initialization
segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-12
.internalDFN link-type="dfn|abstract-op"} has been appended and received
by this algorithm. This flag is set to false when the SourceBuffer is
created and updated by the algorithm below.

Each SourceBuffer object has a [\[\[pending initialization segment for
changeType
flag\]\]]{#dfn-pending-initialization-segment-for-changetype-flag .dfn
dfn-for="SourceBuffer" idl="" noexport="" dfn-type="attribute"
tabindex="0" aria-haspopup="dialog"} internal slot that tracks whether
an [initialization
segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-13
.internalDFN link-type="dfn|abstract-op"} is needed since the most
recent
[`changeType`](#dom-sourcebuffer-changetype){#ref-for-dom-sourcebuffer-changetype-6
.internalDFN link-type="idl" lt="changeType()"}`()`. This flag is set to
false when the SourceBuffer is created, set to true by
[`changeType`](#dom-sourcebuffer-changetype){#ref-for-dom-sourcebuffer-changetype-7
.internalDFN link-type="idl" lt="changeType()"}`()` and reset to false
by the algorithm below.

1.  Update the
    [`duration`](#dom-mediasource-duration){#ref-for-dom-mediasource-duration-9
    .internalDFN link-type="idl"} attribute if it currently equals NaN:

    If the initialization segment contains a duration:
    :   Run the [duration
        change](#dfn-duration-change){#ref-for-dfn-duration-change-4
        .internalDFN link-type="dfn|abstract-op"} algorithm with
        `new duration`{.variable data-type="unrestricted double"} set to
        the duration in the initialization segment.

    Otherwise:
    :   Run the [duration
        change](#dfn-duration-change){#ref-for-dfn-duration-change-5
        .internalDFN link-type="dfn|abstract-op"} algorithm with
        `new duration`{.variable data-type="unrestricted double"} set to
        positive Infinity.

2.  If the [initialization
    segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-14
    .internalDFN link-type="dfn|abstract-op"} has no audio, video, or
    text tracks, then run the [append
    error](#dfn-append-error){#ref-for-dfn-append-error-5 .internalDFN
    link-type="dfn|abstract-op"} algorithm and abort these steps.

3.  If the
    [`[[first initialization segment received flag]]`](#dfn-first-initialization-segment-received-flag){#ref-for-dfn-first-initialization-segment-received-flag-2
    .internalDFN link-type="attribute"
    lt="[[first initialization segment received flag]]"} is true, then
    run the following steps:
    1.  Verify the following properties. If any of the checks fail then
        run the [append
        error](#dfn-append-error){#ref-for-dfn-append-error-6
        .internalDFN link-type="dfn|abstract-op"} algorithm and abort
        these steps.
        - The number of audio, video, and text tracks match what was in
          the first [initialization
          segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-15
          .internalDFN link-type="dfn|abstract-op"}.
        - If more than one track for a single type are present (e.g., 2
          audio tracks), then the [Track
          IDs](#dfn-track-id){#ref-for-dfn-track-id-5 .internalDFN
          link-type="dfn|abstract-op"} match the ones in the first
          [initialization
          segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-16
          .internalDFN link-type="dfn|abstract-op"}.
        - The codecs for each track are supported by the user agent.

          :::: {#issue-container-generatedID-51 .note role="note"}
          ::: {#h-note-51 .note-title .marker role="heading" aria-level="5"}
          Note
          :::

          User agents *MAY* consider codecs, that would otherwise be
          supported, as \"not supported\" here if the codecs were not
          specified in `type`{.variable data-type="DOMString"} parameter
          passed to (a) the most recently successful
          [`changeType`](#dom-sourcebuffer-changetype){#ref-for-dom-sourcebuffer-changetype-8
          .internalDFN link-type="idl" lt="changeType()"}`()` on this
          [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-89
          .internalDFN link-type="idl" lt="SourceBuffer"} object, or (b)
          if no successful
          [`changeType`](#dom-sourcebuffer-changetype){#ref-for-dom-sourcebuffer-changetype-9
          .internalDFN link-type="idl" lt="changeType()"}`()` has yet
          occurred on this object, the
          [`addSourceBuffer`](#dom-mediasource-addsourcebuffer){#ref-for-dom-mediasource-addsourcebuffer-7
          .internalDFN link-type="idl" lt="addSourceBuffer()"}`()` that
          created this
          [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-90
          .internalDFN link-type="idl" lt="SourceBuffer"} object. For
          example, if the most recently successful
          [`changeType`](#dom-sourcebuffer-changetype){#ref-for-dom-sourcebuffer-changetype-10
          .internalDFN link-type="idl" lt="changeType()"}`()` was called
          with `'video/webm'` or `'video/webm; codecs="vp8"'`, and a
          video track containing vp9 appears in the initialization
          segment, then the user agent *MAY* use this step to trigger a
          decode error even if the other two properties\' checks, above,
          pass. Implementations are encouraged to trigger error in such
          cases only when the codec is indeed not supported or the other
          two properties\' checks fail. Web authors are encouraged to
          use
          [`changeType`](#dom-sourcebuffer-changetype){#ref-for-dom-sourcebuffer-changetype-11
          .internalDFN link-type="idl" lt="changeType()"}`()`,
          [`addSourceBuffer`](#dom-mediasource-addsourcebuffer){#ref-for-dom-mediasource-addsourcebuffer-8
          .internalDFN link-type="idl" lt="addSourceBuffer()"}`()` and
          [`isTypeSupported`](#dom-mediasource-istypesupported){#ref-for-dom-mediasource-istypesupported-2
          .internalDFN link-type="idl" lt="isTypeSupported()"}`()` with
          precise codec parameters to more proactively detect user agent
          support.
          [`changeType`](#dom-sourcebuffer-changetype){#ref-for-dom-sourcebuffer-changetype-12
          .internalDFN link-type="idl" lt="changeType()"}`()` is
          required if the
          [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-91
          .internalDFN link-type="idl" lt="SourceBuffer"} object\'s
          bytestream format is changing.
          ::::
    2.  Add the appropriate [track
        descriptions](#dfn-track-description){#ref-for-dfn-track-description-3
        .internalDFN link-type="dfn|abstract-op"} from this
        [initialization
        segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-17
        .internalDFN link-type="dfn|abstract-op"} to each of the [track
        buffers](#track-buffer){#ref-for-track-buffer-21 .internalDFN
        link-type="dfn|abstract-op"}.
    3.  Set the [need random access point
        flag](#need-RAP-flag){#ref-for-need-RAP-flag-2 .internalDFN
        link-type="dfn|abstract-op"} on all track buffers to true.

4.  Let `active track flag`{.variable data-type="boolean"} equal false.

5.  If the
    [`[[first initialization segment received flag]]`](#dfn-first-initialization-segment-received-flag){#ref-for-dfn-first-initialization-segment-received-flag-3
    .internalDFN link-type="attribute"
    lt="[[first initialization segment received flag]]"} is false, then
    run the following steps:

    1.  If the [initialization
        segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-18
        .internalDFN link-type="dfn|abstract-op"} contains tracks with
        codecs the user agent does not support, then run the [append
        error](#dfn-append-error){#ref-for-dfn-append-error-7
        .internalDFN link-type="dfn|abstract-op"} algorithm and abort
        these steps.

        :::: {#issue-container-generatedID-52 .note role="note"}
        ::: {#h-note-52 .note-title .marker role="heading" aria-level="5"}
        Note
        :::

        User agents *MAY* consider codecs, that would otherwise be
        supported, as \"not supported\" here if the codecs were not
        specified in `type`{.variable data-type="DOMString"} parameter
        passed to (a) the most recently successful
        [`changeType`](#dom-sourcebuffer-changetype){#ref-for-dom-sourcebuffer-changetype-13
        .internalDFN link-type="idl" lt="changeType()"}`()` on this
        [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-92
        .internalDFN link-type="idl" lt="SourceBuffer"} object, or (b)
        if no successful
        [`changeType`](#dom-sourcebuffer-changetype){#ref-for-dom-sourcebuffer-changetype-14
        .internalDFN link-type="idl" lt="changeType()"}`()` has yet
        occurred on this object, the
        [`addSourceBuffer`](#dom-mediasource-addsourcebuffer){#ref-for-dom-mediasource-addsourcebuffer-9
        .internalDFN link-type="idl" lt="addSourceBuffer()"}`()` that
        created this
        [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-93
        .internalDFN link-type="idl" lt="SourceBuffer"} object. For
        example,
        `MediaSource.isTypeSupported('video/webm;codecs="vp8,vorbis"')`
        may return true, but if
        [`addSourceBuffer`](#dom-mediasource-addsourcebuffer){#ref-for-dom-mediasource-addsourcebuffer-10
        .internalDFN link-type="idl" lt="addSourceBuffer()"}`()` was
        called with `'video/webm;codecs="vp8"'` and a Vorbis track
        appears in the [initialization
        segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-19
        .internalDFN link-type="dfn|abstract-op"}, then the user agent
        *MAY* use this step to trigger a decode error. Implementations
        are encouraged to trigger error in such cases only when the
        codec is indeed not supported. Web authors are encouraged to use
        [`changeType`](#dom-sourcebuffer-changetype){#ref-for-dom-sourcebuffer-changetype-15
        .internalDFN link-type="idl" lt="changeType()"}`()`,
        [`addSourceBuffer`](#dom-mediasource-addsourcebuffer){#ref-for-dom-mediasource-addsourcebuffer-11
        .internalDFN link-type="idl" lt="addSourceBuffer()"}`()` and
        [`isTypeSupported`](#dom-mediasource-istypesupported){#ref-for-dom-mediasource-istypesupported-3
        .internalDFN link-type="idl" lt="isTypeSupported()"}`()` with
        precise codec parameters to more proactively detect user agent
        support.
        [`changeType`](#dom-sourcebuffer-changetype){#ref-for-dom-sourcebuffer-changetype-16
        .internalDFN link-type="idl" lt="changeType()"}`()` is required
        if the
        [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-94
        .internalDFN link-type="idl" lt="SourceBuffer"} object\'s
        bytestream format is changing.
        ::::

    2.  For each audio track in the [initialization
        segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-20
        .internalDFN link-type="dfn|abstract-op"}, run following steps:

        1.  Let `audio byte stream track ID`{.variable} be the [Track
            ID](#dfn-track-id){#ref-for-dfn-track-id-6 .internalDFN
            link-type="dfn|abstract-op"} for the current track being
            processed.
        2.  Let `audio language`{.variable data-type="DOMString"} be a
            BCP 47 language tag for the language specified in the
            [initialization
            segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-21
            .internalDFN link-type="dfn|abstract-op"} for this track or
            an empty string if no language info is present.
        3.  If `audio language`{.variable data-type="DOMString"} equals
            the \'und\' BCP 47 value, then assign an empty string to
            `audio language`{.variable data-type="DOMString"}.
        4.  Let `audio label`{.variable data-type="DOMString"} be a
            label specified in the [initialization
            segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-22
            .internalDFN link-type="dfn|abstract-op"} for this track or
            an empty string if no label info is present.
        5.  Let `audio kinds`{.variable data-type="DOMString sequence"}
            be a sequence of kind strings specified in the
            [initialization
            segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-23
            .internalDFN link-type="dfn|abstract-op"} for this track or
            a sequence with a single empty string element in it if no
            kind information is provided.
        6.  For each value in `audio kinds`{.variable
            data-type="DOMString sequence"}, run the following steps:
            1.  Let `current audio kind`{.variable
                data-type="DOMString"} equal the value from
                `audio kinds`{.variable data-type="DOMString sequence"}
                for this iteration of the loop.

            2.  Let `new audio track`{.variable data-type="AudioTrack"}
                be a new
                [`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack){link-type="interface"
                lt="AudioTrack"} object.

            3.  Generate a unique ID and assign it to the
                [`id`](https://html.spec.whatwg.org/multipage/media.html#dom-audiotrack-id){link-type="attribute"}
                property on `new audio track`{.variable
                data-type="AudioTrack"}.

            4.  Assign `audio language`{.variable data-type="DOMString"}
                to the
                [`language`](https://html.spec.whatwg.org/multipage/media.html#dom-audiotrack-language){link-type="attribute"}
                property on `new audio track`{.variable}.

            5.  Assign `audio label`{.variable data-type="DOMString"} to
                the
                [`label`](https://html.spec.whatwg.org/multipage/media.html#dom-audiotrack-label){link-type="attribute"}
                property on `new audio track`{.variable}.

            6.  Assign `current audio kind`{.variable
                data-type="DOMString"} to the
                [`kind`](https://html.spec.whatwg.org/multipage/media.html#dom-audiotrack-kind){link-type="attribute"}
                property on `new audio track`{.variable}.

            7.  If this
                [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-95
                .internalDFN link-type="idl" lt="SourceBuffer"}
                object\'s
                [`audioTracks`](#dom-sourcebuffer-audiotracks){#ref-for-dom-sourcebuffer-audiotracks-3
                .internalDFN link-type="idl"}\'s
                [`length`](https://html.spec.whatwg.org/multipage/media.html#dom-audiotracklist-length){link-type="attribute"}
                equals 0, then run the following steps:

                1.  Set the
                    [`enabled`](https://html.spec.whatwg.org/multipage/media.html#dom-audiotrack-enabled){link-type="attribute"}
                    property on `new audio track`{.variable
                    data-type="AudioTrack"} to true.
                2.  Set `active track flag`{.variable
                    data-type="boolean"} to true.

            8.  Add `new audio track`{.variable data-type="AudioTrack"}
                to the
                [`audioTracks`](#dom-sourcebuffer-audiotracks){#ref-for-dom-sourcebuffer-audiotracks-4
                .internalDFN link-type="idl"} attribute on this
                [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-96
                .internalDFN link-type="idl" lt="SourceBuffer"} object.

                :::: {#issue-container-generatedID-53 .note role="note"}
                ::: {#h-note-53 .note-title .marker role="heading" aria-level="5"}
                Note
                :::

                This should trigger
                [`AudioTrackList`](https://html.spec.whatwg.org/multipage/media.html#audiotracklist){link-type="interface"
                lt="AudioTrackList"}
                \[[HTML](#bib-html "HTML Standard"){.bibref
                link-type="biblio"}\] logic to [queue a
                task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
                to [fire an
                event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
                named
                [addtrack](https://html.spec.whatwg.org/multipage/media.html#event-media-addtrack){link-type="event"}
                using
                [`TrackEvent`](https://html.spec.whatwg.org/multipage/media.html#trackevent){link-type="interface"
                lt="TrackEvent"} with the
                [`track`](https://html.spec.whatwg.org/multipage/media.html#dom-trackevent-track){link-type="attribute"}
                attribute initialized to `new audio track`{.variable
                data-type="AudioTrack"}, at the
                [`AudioTrackList`](https://html.spec.whatwg.org/multipage/media.html#audiotracklist){link-type="interface"
                lt="AudioTrackList"} object referenced by the
                [`audioTracks`](#dom-sourcebuffer-audiotracks){#ref-for-dom-sourcebuffer-audiotracks-5
                .internalDFN link-type="idl"} attribute on this
                [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-97
                .internalDFN link-type="idl" lt="SourceBuffer"} object.
                ::::

            9.  

                If the [parent media source](#parent-media-source){#ref-for-parent-media-source-27 .internalDFN link-type="dfn|abstract-op"} was constructed in a [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface" lt="DedicatedWorkerGlobalScope"}:
                :   Post an internal `create track mirror` message to
                    [`[[port to main]]`](#dfn-port-to-main){#ref-for-dfn-port-to-main-7
                    .internalDFN link-type="attribute"
                    lt="[[port to main]]"} whose implicit handler in
                    [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
                    lt="Window"} runs the following steps:
                    1.  Let `mirrored audio track`{.variable
                        data-type="AudioTrack"} be a new
                        [`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack){link-type="interface"
                        lt="AudioTrack"} object.
                    2.  Assign the same property values to
                        `mirrored audio track`{.variable
                        data-type="AudioTrack"} as were determined for
                        `new audio track`{.variable
                        data-type="AudioTrack"}.
                    3.  Add `mirrored audio track`{.variable
                        data-type="AudioTrack"} to the
                        [`audioTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-audiotracks){link-type="attribute"}
                        attribute on the HTMLMediaElement.

                Otherwise:
                :   Add `new audio track`{.variable
                    data-type="AudioTrack"} to the
                    [`audioTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-audiotracks){link-type="attribute"}
                    attribute on the HTMLMediaElement.

                :::: {#issue-container-generatedID-54 .note role="note"}
                ::: {#h-note-54 .note-title .marker role="heading" aria-level="5"}
                Note
                :::

                This should trigger
                [`AudioTrackList`](https://html.spec.whatwg.org/multipage/media.html#audiotracklist){link-type="interface"
                lt="AudioTrackList"}
                \[[HTML](#bib-html "HTML Standard"){.bibref
                link-type="biblio"}\] logic to [queue a
                task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
                to [fire an
                event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
                named
                [addtrack](https://html.spec.whatwg.org/multipage/media.html#event-media-addtrack){link-type="event"}
                using
                [`TrackEvent`](https://html.spec.whatwg.org/multipage/media.html#trackevent){link-type="interface"
                lt="TrackEvent"} with the
                [`track`](https://html.spec.whatwg.org/multipage/media.html#dom-trackevent-track){link-type="attribute"}
                attribute initialized to
                `mirrored audio track`{.variable data-type="AudioTrack"}
                or `new audio track`{.variable data-type="AudioTrack"},
                at the
                [`AudioTrackList`](https://html.spec.whatwg.org/multipage/media.html#audiotracklist){link-type="interface"
                lt="AudioTrackList"} object referenced by the
                [`audioTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-audiotracks){link-type="attribute"}
                attribute on the HTMLMediaElement.
                ::::
        7.  Create a new [track
            buffer](#track-buffer){#ref-for-track-buffer-22 .internalDFN
            link-type="dfn|abstract-op"} to store [coded
            frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-28
            .internalDFN link-type="dfn|abstract-op"} for this track.
        8.  Add the [track
            description](#dfn-track-description){#ref-for-dfn-track-description-4
            .internalDFN link-type="dfn|abstract-op"} for this track to
            the [track buffer](#track-buffer){#ref-for-track-buffer-23
            .internalDFN link-type="dfn|abstract-op"}.

    3.  For each video track in the [initialization
        segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-24
        .internalDFN link-type="dfn|abstract-op"}, run following steps:

        1.  Let `video byte stream track ID`{.variable} be the [Track
            ID](#dfn-track-id){#ref-for-dfn-track-id-7 .internalDFN
            link-type="dfn|abstract-op"} for the current track being
            processed.
        2.  Let `video language`{.variable data-type="DOMString"} be a
            BCP 47 language tag for the language specified in the
            [initialization
            segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-25
            .internalDFN link-type="dfn|abstract-op"} for this track or
            an empty string if no language info is present.
        3.  If `video language`{.variable data-type="DOMString"} equals
            the \'und\' BCP 47 value, then assign an empty string to
            `video language`{.variable data-type="DOMString"}.
        4.  Let `video label`{.variable data-type="DOMString"} be a
            label specified in the [initialization
            segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-26
            .internalDFN link-type="dfn|abstract-op"} for this track or
            an empty string if no label info is present.
        5.  Let `video kinds`{.variable data-type="DOMString sequence"}
            be a sequence of kind strings specified in the
            [initialization
            segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-27
            .internalDFN link-type="dfn|abstract-op"} for this track or
            a sequence with a single empty string element in it if no
            kind information is provided.
        6.  For each value in `video kinds`{.variable
            data-type="DOMString sequence"}, run the following steps:
            1.  Let `current video kind`{.variable
                data-type="DOMString"} equal the value from
                `video kinds`{.variable data-type="DOMString sequence"}
                for this iteration of the loop.

            2.  Let `new video track`{.variable data-type="VideoTrack"}
                be a new
                [`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack){link-type="interface"
                lt="VideoTrack"} object.

            3.  Generate a unique ID and assign it to the
                [`id`](https://html.spec.whatwg.org/multipage/media.html#dom-videotrack-id){link-type="attribute"}
                property on `new video track`{.variable
                data-type="VideoTrack"}.

            4.  Assign `video language`{.variable data-type="DOMString"}
                to the
                [`language`](https://html.spec.whatwg.org/multipage/media.html#dom-videotrack-language){link-type="attribute"}
                property on `new video track`{.variable}.

            5.  Assign `video label`{.variable data-type="DOMString"} to
                the
                [`label`](https://html.spec.whatwg.org/multipage/media.html#dom-videotrack-label){link-type="attribute"}
                property on `new video track`{.variable}.

            6.  Assign `current video kind`{.variable
                data-type="DOMString"} to the
                [`kind`](https://html.spec.whatwg.org/multipage/media.html#dom-videotrack-kind){link-type="attribute"}
                property on `new video track`{.variable}.

            7.  If this
                [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-98
                .internalDFN link-type="idl" lt="SourceBuffer"}
                object\'s
                [`videoTracks`](#dom-sourcebuffer-videotracks){#ref-for-dom-sourcebuffer-videotracks-3
                .internalDFN link-type="idl"}\'s
                [`length`](https://html.spec.whatwg.org/multipage/media.html#dom-videotracklist-length){link-type="attribute"}
                equals 0, then run the following steps:

                1.  Set the
                    [`selected`](https://html.spec.whatwg.org/multipage/media.html#dom-videotrack-selected){link-type="attribute"}
                    property on `new video track`{.variable
                    data-type="VideoTrack"} to true.
                2.  Set `active track flag`{.variable
                    data-type="boolean"} to true.

            8.  Add `new video track`{.variable data-type="VideoTrack"}
                to the
                [`videoTracks`](#dom-sourcebuffer-videotracks){#ref-for-dom-sourcebuffer-videotracks-4
                .internalDFN link-type="idl"} attribute on this
                [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-99
                .internalDFN link-type="idl" lt="SourceBuffer"} object.

                :::: {#issue-container-generatedID-55 .note role="note"}
                ::: {#h-note-55 .note-title .marker role="heading" aria-level="5"}
                Note
                :::

                This should trigger
                [`VideoTrackList`](https://html.spec.whatwg.org/multipage/media.html#videotracklist){link-type="interface"
                lt="VideoTrackList"}
                \[[HTML](#bib-html "HTML Standard"){.bibref
                link-type="biblio"}\] logic to [queue a
                task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
                to [fire an
                event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
                named
                [addtrack](https://html.spec.whatwg.org/multipage/media.html#event-media-addtrack){link-type="event"}
                using
                [`TrackEvent`](https://html.spec.whatwg.org/multipage/media.html#trackevent){link-type="interface"
                lt="TrackEvent"} with the
                [`track`](https://html.spec.whatwg.org/multipage/media.html#dom-trackevent-track){link-type="attribute"}
                attribute initialized to `new video track`{.variable
                data-type="VideoTrack"}, at the
                [`VideoTrackList`](https://html.spec.whatwg.org/multipage/media.html#videotracklist){link-type="interface"
                lt="VideoTrackList"} object referenced by the
                [`videoTracks`](#dom-sourcebuffer-videotracks){#ref-for-dom-sourcebuffer-videotracks-5
                .internalDFN link-type="idl"} attribute on this
                [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-100
                .internalDFN link-type="idl" lt="SourceBuffer"} object.
                ::::

            9.  

                If the [parent media source](#parent-media-source){#ref-for-parent-media-source-28 .internalDFN link-type="dfn|abstract-op"} was constructed in a [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface" lt="DedicatedWorkerGlobalScope"}:
                :   Post an internal `create track mirror` message to
                    [`[[port to main]]`](#dfn-port-to-main){#ref-for-dfn-port-to-main-8
                    .internalDFN link-type="attribute"
                    lt="[[port to main]]"} whose implicit handler in
                    [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
                    lt="Window"} runs the following steps:
                    1.  Let `mirrored video track`{.variable
                        data-type="VideoTrack"} be a new
                        [`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack){link-type="interface"
                        lt="VideoTrack"} object.
                    2.  Assign the same property values to
                        `mirrored video track`{.variable
                        data-type="VideoTrack"} as were determined for
                        `new video track`{.variable
                        data-type="VideoTrack"}.
                    3.  Add `mirrored video track`{.variable
                        data-type="VideoTrack"} to the
                        [`videoTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-videotracks){link-type="attribute"}
                        attribute on the HTMLMediaElement.

                Otherwise:
                :   Add `new video track`{.variable
                    data-type="VideoTrack"} to the
                    [`videoTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-videotracks){link-type="attribute"}
                    attribute on the HTMLMediaElement.

                :::: {#issue-container-generatedID-56 .note role="note"}
                ::: {#h-note-56 .note-title .marker role="heading" aria-level="5"}
                Note
                :::

                This should trigger
                [`VideoTrackList`](https://html.spec.whatwg.org/multipage/media.html#videotracklist){link-type="interface"
                lt="VideoTrackList"}
                \[[HTML](#bib-html "HTML Standard"){.bibref
                link-type="biblio"}\] logic to [queue a
                task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
                to [fire an
                event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
                named
                [addtrack](https://html.spec.whatwg.org/multipage/media.html#event-media-addtrack){link-type="event"}
                using
                [`TrackEvent`](https://html.spec.whatwg.org/multipage/media.html#trackevent){link-type="interface"
                lt="TrackEvent"} with the
                [`track`](https://html.spec.whatwg.org/multipage/media.html#dom-trackevent-track){link-type="attribute"}
                attribute initialized to
                `mirrored video track`{.variable data-type="VideoTrack"}
                or `new video track`{.variable data-type="VideoTrack"},
                at the
                [`VideoTrackList`](https://html.spec.whatwg.org/multipage/media.html#videotracklist){link-type="interface"
                lt="VideoTrackList"} object referenced by the
                [`videoTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-videotracks){link-type="attribute"}
                attribute on the HTMLMediaElement.
                ::::
        7.  Create a new [track
            buffer](#track-buffer){#ref-for-track-buffer-24 .internalDFN
            link-type="dfn|abstract-op"} to store [coded
            frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-29
            .internalDFN link-type="dfn|abstract-op"} for this track.
        8.  Add the [track
            description](#dfn-track-description){#ref-for-dfn-track-description-5
            .internalDFN link-type="dfn|abstract-op"} for this track to
            the [track buffer](#track-buffer){#ref-for-track-buffer-25
            .internalDFN link-type="dfn|abstract-op"}.

    4.  For each text track in the [initialization
        segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-28
        .internalDFN link-type="dfn|abstract-op"}, run following steps:

        1.  Let `text byte stream track ID`{.variable} be the [Track
            ID](#dfn-track-id){#ref-for-dfn-track-id-8 .internalDFN
            link-type="dfn|abstract-op"} for the current track being
            processed.
        2.  Let `text language`{.variable data-type="DOMString"} be a
            BCP 47 language tag for the language specified in the
            [initialization
            segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-29
            .internalDFN link-type="dfn|abstract-op"} for this track or
            an empty string if no language info is present.
        3.  If `text language`{.variable data-type="DOMString"} equals
            the \'und\' BCP 47 value, then assign an empty string to
            `text language`{.variable data-type="DOMString"}.
        4.  Let `text label`{.variable data-type="DOMString"} be a label
            specified in the [initialization
            segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-30
            .internalDFN link-type="dfn|abstract-op"} for this track or
            an empty string if no label info is present.
        5.  Let `text kinds`{.variable data-type="DOMString sequence"}
            be a sequence of kind strings specified in the
            [initialization
            segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-31
            .internalDFN link-type="dfn|abstract-op"} for this track or
            a sequence with a single empty string element in it if no
            kind information is provided.
        6.  For each value in `text kinds`{.variable
            data-type="DOMString sequence"}, run the following steps:
            1.  Let `current text kind`{.variable data-type="DOMString"}
                equal the value from `text kinds`{.variable
                data-type="DOMString sequence"} for this iteration of
                the loop.

            2.  Let `new text track`{.variable data-type="TextTrack"} be
                a new
                [`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack){link-type="interface"
                lt="TextTrack"} object.

            3.  Generate a unique ID and assign it to the
                [`id`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-id){link-type="attribute"}
                property on `new text track`{.variable
                data-type="TextTrack"}.

            4.  Assign `text language`{.variable data-type="DOMString"}
                to the
                [`language`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-language){link-type="attribute"}
                property on `new text track`{.variable}.

            5.  Assign `text label`{.variable data-type="DOMString"} to
                the
                [`label`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-label){link-type="attribute"}
                property on `new text track`{.variable}.

            6.  Assign `current text kind`{.variable
                data-type="DOMString"} to the
                [`kind`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-kind){link-type="attribute"}
                property on `new text track`{.variable}.

            7.  Populate the remaining properties on
                `new text track`{.variable data-type="TextTrack"} with
                the appropriate information from the [initialization
                segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-32
                .internalDFN link-type="dfn|abstract-op"}.

            8.  If the
                [`mode`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-mode){link-type="attribute"}
                property on `new text track`{.variable
                data-type="TextTrack"} equals
                [`"showing"`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-showing)
                or
                [`"hidden"`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-hidden),
                then set `active track flag`{.variable
                data-type="boolean"} to true.

            9.  Add `new text track`{.variable data-type="TextTrack"} to
                the
                [`textTracks`](#dom-sourcebuffer-texttracks){#ref-for-dom-sourcebuffer-texttracks-3
                .internalDFN link-type="idl"} attribute on this
                [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-101
                .internalDFN link-type="idl" lt="SourceBuffer"} object.

                :::: {#issue-container-generatedID-57 .note role="note"}
                ::: {#h-note-57 .note-title .marker role="heading" aria-level="5"}
                Note
                :::

                This should trigger
                [`TextTrackList`](https://html.spec.whatwg.org/multipage/media.html#texttracklist){link-type="interface"
                lt="TextTrackList"}
                \[[HTML](#bib-html "HTML Standard"){.bibref
                link-type="biblio"}\] logic to [queue a
                task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
                to [fire an
                event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
                named
                [addtrack](https://html.spec.whatwg.org/multipage/media.html#event-media-addtrack){link-type="event"}
                using
                [`TrackEvent`](https://html.spec.whatwg.org/multipage/media.html#trackevent){link-type="interface"
                lt="TrackEvent"} with the
                [`track`](https://html.spec.whatwg.org/multipage/media.html#dom-trackevent-track){link-type="attribute"}
                attribute initialized to `new text track`{.variable
                data-type="TextTrack"}, at the
                [`TextTrackList`](https://html.spec.whatwg.org/multipage/media.html#texttracklist){link-type="interface"
                lt="TextTrackList"} object referenced by the
                [`textTracks`](#dom-sourcebuffer-texttracks){#ref-for-dom-sourcebuffer-texttracks-4
                .internalDFN link-type="idl"} attribute on this
                [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-102
                .internalDFN link-type="idl" lt="SourceBuffer"} object.
                ::::

            10. 

                If the [parent media source](#parent-media-source){#ref-for-parent-media-source-29 .internalDFN link-type="dfn|abstract-op"} was constructed in a [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface" lt="DedicatedWorkerGlobalScope"}:
                :   Post an internal `create track mirror` message to
                    [`[[port to main]]`](#dfn-port-to-main){#ref-for-dfn-port-to-main-9
                    .internalDFN link-type="attribute"
                    lt="[[port to main]]"} whose implicit handler in
                    [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
                    lt="Window"} runs the following steps:
                    1.  Let `mirrored text track`{.variable
                        data-type="TextTrack"} be a new
                        [`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack){link-type="interface"
                        lt="TextTrack"} object.
                    2.  Assign the same property values to
                        `mirrored text track`{.variable
                        data-type="TextTrack"} as were determined for
                        `new text track`{.variable
                        data-type="TextTrack"}.
                    3.  Add `mirrored text track`{.variable
                        data-type="TextTrack"} to the
                        [`textTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-texttracks){link-type="attribute"}
                        attribute on the HTMLMediaElement.

                Otherwise:
                :   Add `new text track`{.variable
                    data-type="TextTrack"} to the
                    [`textTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-texttracks){link-type="attribute"}
                    attribute on the HTMLMediaElement.

                :::: {#issue-container-generatedID-58 .note role="note"}
                ::: {#h-note-58 .note-title .marker role="heading" aria-level="5"}
                Note
                :::

                This should trigger
                [`TextTrackList`](https://html.spec.whatwg.org/multipage/media.html#texttracklist){link-type="interface"
                lt="TextTrackList"}
                \[[HTML](#bib-html "HTML Standard"){.bibref
                link-type="biblio"}\] logic to [queue a
                task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
                to [fire an
                event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
                named
                [addtrack](https://html.spec.whatwg.org/multipage/media.html#event-media-addtrack){link-type="event"}
                using
                [`TrackEvent`](https://html.spec.whatwg.org/multipage/media.html#trackevent){link-type="interface"
                lt="TrackEvent"} with the
                [`track`](https://html.spec.whatwg.org/multipage/media.html#dom-trackevent-track){link-type="attribute"}
                attribute initialized to `mirrored text track`{.variable
                data-type="TextTrack"} or `new text track`{.variable
                data-type="TextTrack"}, at the
                [`TextTrackList`](https://html.spec.whatwg.org/multipage/media.html#texttracklist){link-type="interface"
                lt="TextTrackList"} object referenced by the
                [`textTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-texttracks){link-type="attribute"}
                attribute on the HTMLMediaElement.
                ::::
        7.  Create a new [track
            buffer](#track-buffer){#ref-for-track-buffer-26 .internalDFN
            link-type="dfn|abstract-op"} to store [coded
            frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-30
            .internalDFN link-type="dfn|abstract-op"} for this track.
        8.  Add the [track
            description](#dfn-track-description){#ref-for-dfn-track-description-6
            .internalDFN link-type="dfn|abstract-op"} for this track to
            the [track buffer](#track-buffer){#ref-for-track-buffer-27
            .internalDFN link-type="dfn|abstract-op"}.

    5.  If `active track flag`{.variable data-type="boolean"} equals
        true, then run the following steps:
        1.  Add this
            [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-103
            .internalDFN link-type="idl" lt="SourceBuffer"} to
            [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-28
            .internalDFN link-type="idl"}.
        2.  [Queue a
            task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
            to [fire an
            event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
            named
            [`addsourcebuffer`](#dfn-addsourcebuffer){#ref-for-dfn-addsourcebuffer-5
            .internalDFN link-type="idl" lt="addsourcebuffer"} at
            [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-29
            .internalDFN link-type="idl"}

    6.  Set
        [`[[first initialization segment received flag]]`](#dfn-first-initialization-segment-received-flag){#ref-for-dfn-first-initialization-segment-received-flag-4
        .internalDFN link-type="attribute"
        lt="[[first initialization segment received flag]]"} to true.

6.  Set
    [`[[pending initialization segment for changeType flag]]`](#dfn-pending-initialization-segment-for-changetype-flag){#ref-for-dfn-pending-initialization-segment-for-changetype-flag-3
    .internalDFN link-type="attribute"
    lt="[[pending initialization segment for changeType flag]]"} to
    false.

7.  If the `active track flag`{.variable data-type="boolean"} equals
    true, then run the following steps:

8.  Use the [parent media
    source](#parent-media-source){#ref-for-parent-media-source-30
    .internalDFN link-type="dfn|abstract-op"}\'s [mirror if
    necessary](#dfn-mirror-if-necessary){#ref-for-dfn-mirror-if-necessary-7
    .internalDFN link-type="dfn|abstract-op"} algorithm to run the
    following step in
    [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
    lt="Window"}:
    1.  If the
        [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
        lt="HTMLMediaElement"}\'s
        [`readyState`](#dom-readystate){#ref-for-dom-readystate-20
        .internalDFN link-type="idl"} attribute is greater than
        [`HAVE_CURRENT_DATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_current_data){link-type="const"},
        then set the
        [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
        lt="HTMLMediaElement"}\'s
        [`readyState`](#dom-readystate){#ref-for-dom-readystate-21
        .internalDFN link-type="idl"} attribute to
        [`HAVE_METADATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_metadata){link-type="const"}.

        :::: {#issue-container-generatedID-59 .note role="note"}
        ::: {#h-note-59 .note-title .marker role="heading" aria-level="5"}
        Note
        :::

        Per
        [`HTMLMediaElement ready states`](https://html.spec.whatwg.org/multipage/media.html#ready-states)
        \[[HTML](#bib-html "HTML Standard"){.bibref
        link-type="biblio"}\] logic,
        [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
        lt="HTMLMediaElement"}\'s
        [`readyState`](#dom-readystate){#ref-for-dom-readystate-22
        .internalDFN link-type="idl"} changes may trigger events on the
        HTMLMediaElement.
        ::::

9.  If each object in
    [`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-31
    .internalDFN link-type="idl"} of the [parent media
    source](#parent-media-source){#ref-for-parent-media-source-31
    .internalDFN link-type="dfn|abstract-op"} has
    [`[[first initialization segment received flag]]`](#dfn-first-initialization-segment-received-flag){#ref-for-dfn-first-initialization-segment-received-flag-5
    .internalDFN link-type="attribute"
    lt="[[first initialization segment received flag]]"} equal to true,
    then use the [parent media
    source](#parent-media-source){#ref-for-parent-media-source-32
    .internalDFN link-type="dfn|abstract-op"}\'s [mirror if
    necessary](#dfn-mirror-if-necessary){#ref-for-dfn-mirror-if-necessary-8
    .internalDFN link-type="dfn|abstract-op"} algorithm to run the
    following step in
    [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
    lt="Window"}:
    1.  If the
        [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
        lt="HTMLMediaElement"}\'s
        [`readyState`](#dom-readystate){#ref-for-dom-readystate-23
        .internalDFN link-type="idl"} attribute is
        [`HAVE_NOTHING`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_nothing){link-type="const"},
        then set the
        [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
        lt="HTMLMediaElement"}\'s
        [`readyState`](#dom-readystate){#ref-for-dom-readystate-24
        .internalDFN link-type="idl"} attribute to
        [`HAVE_METADATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_metadata){link-type="const"}.

        :::: {#issue-container-generatedID-60 .note role="note"}
        ::: {#h-note-60 .note-title .marker role="heading" aria-level="5"}
        Note
        :::

        Per
        [`HTMLMediaElement ready states`](https://html.spec.whatwg.org/multipage/media.html#ready-states)
        \[[HTML](#bib-html "HTML Standard"){.bibref
        link-type="biblio"}\] logic,
        [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
        lt="HTMLMediaElement"}\'s
        [`readyState`](#dom-readystate){#ref-for-dom-readystate-25
        .internalDFN link-type="idl"} changes may trigger events on the
        HTMLMediaElement. If transition from
        [`HAVE_NOTHING`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_nothing){link-type="const"}
        to
        [`HAVE_METADATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_metadata){link-type="const"}
        occurs, it should trigger HTMLMediaElement logic to [queue a
        task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
        to [fire an
        event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
        named
        [loadedmetadata](https://html.spec.whatwg.org/multipage/media.html#event-media-loadedmetadata){link-type="event"}
        at the media element.
        ::::
::::

:::: {#sourcebuffer-coded-frame-processing .section}
::: header-wrapper
#### 5.5.8 [Coded Frame Processing]{#dfn-coded-frame-processing .dfn export="" tabindex="0" aria-haspopup="dialog" dfn-type="dfn"} {#x5-5-8-coded-frame-processing}

[](#sourcebuffer-coded-frame-processing){.self-link
aria-label="Permalink for Section 5.5.8"}
:::

When complete [coded
frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-31 .internalDFN
link-type="dfn|abstract-op"} have been parsed by the [segment parser
loop](#dfn-segment-parser-loop){#ref-for-dfn-segment-parser-loop-4
.internalDFN link-type="dfn|abstract-op"} then the following steps are
run:

1.  For each [coded frame](#dfn-coded-frame){#ref-for-dfn-coded-frame-32
    .internalDFN link-type="dfn|abstract-op"} in the [media
    segment](#dfn-media-segment){#ref-for-dfn-media-segment-13
    .internalDFN link-type="dfn|abstract-op"} run the following steps:

    1.  *Loop Top:*

        If [`[[generate timestamps flag]]`](#dfn-generate-timestamps-flag){#ref-for-dfn-generate-timestamps-flag-6 .internalDFN link-type="attribute" lt="[[generate timestamps flag]]"} equals true:

        :   1.  Let `presentation timestamp`{.variable
                data-type="double"} equal 0.
            2.  Let `decode timestamp`{.variable data-type="double"}
                equal 0.

        Otherwise:

        :   1.  Let `presentation timestamp`{.variable
                data-type="double"} be a double precision floating point
                representation of the coded frame\'s [presentation
                timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-18
                .internalDFN link-type="dfn|abstract-op"} in seconds.

                :::: {#issue-container-generatedID-61 .note role="note"}
                ::: {#h-note-61 .note-title .marker role="heading" aria-level="5"}
                Note
                :::

                Special processing may be needed to determine the
                presentation and decode timestamps for timed text frames
                since this information may not be explicitly present in
                the underlying format or may be dependent on the order
                of the frames. Some metadata text tracks, like MPEG2-TS
                PSI data, may only have implied timestamps. Format
                specific rules for these situations *SHOULD* be in the
                [byte stream format
                specifications](#byte-stream-format-specs){#ref-for-byte-stream-format-specs-6
                .internalDFN link-type="dfn|abstract-op"} or in separate
                extension specifications.
                ::::
            2.  Let `decode timestamp`{.variable data-type="double"} be
                a double precision floating point representation of the
                coded frame\'s decode timestamp in seconds.

                :::: {#issue-container-generatedID-62 .note role="note"}
                ::: {#h-note-62 .note-title .marker role="heading" aria-level="5"}
                Note
                :::

                Implementations don\'t have to internally store
                timestamps in a double precision floating point
                representation. This representation is used here because
                it is the representation for timestamps in the HTML
                spec. The intention here is to make the behavior clear
                without adding unnecessary complexity to the algorithm
                to deal with the fact that adding a timestampOffset may
                cause a timestamp rollover in the underlying timestamp
                representation used by the byte stream format.
                Implementations can use any internal timestamp
                representation they wish, but the addition of
                timestampOffset *SHOULD* behave in a similar manner to
                what would happen if a double precision floating point
                representation was used.
                ::::

    2.  Let `frame duration`{.variable data-type="double"} be a double
        precision floating point representation of the [coded frame\'s
        duration](#dfn-coded-frame-duration){#ref-for-dfn-coded-frame-duration-6
        .internalDFN link-type="dfn|abstract-op"
        lt="coded frame duration"} in seconds.

    3.  If
        [`mode`](#dom-sourcebuffer-mode){#ref-for-dom-sourcebuffer-mode-11
        .internalDFN link-type="idl"} equals
        \"[`sequence`](#dom-appendmode-sequence){#ref-for-dom-appendmode-sequence-10
        .internalDFN link-type="idl"}\" and
        [`[[group start timestamp]]`](#dfn-group-start-timestamp){#ref-for-dfn-group-start-timestamp-4
        .internalDFN link-type="attribute"
        lt="[[group start timestamp]]"} is set, then run the following
        steps:
        1.  Set
            [`timestampOffset`](#dom-sourcebuffer-timestampoffset){#ref-for-dom-sourcebuffer-timestampoffset-6
            .internalDFN link-type="idl"} equal to
            [`[[group start timestamp]]`](#dfn-group-start-timestamp){#ref-for-dfn-group-start-timestamp-5
            .internalDFN link-type="attribute"
            lt="[[group start timestamp]]"} minus
            `presentation timestamp`{.variable data-type="double"}.
        2.  Set
            [`[[group end timestamp]]`](#dfn-group-end-timestamp){#ref-for-dfn-group-end-timestamp-4
            .internalDFN link-type="attribute"
            lt="[[group end timestamp]]"} equal to
            [`[[group start timestamp]]`](#dfn-group-start-timestamp){#ref-for-dfn-group-start-timestamp-6
            .internalDFN link-type="attribute"
            lt="[[group start timestamp]]"}.
        3.  Set the [need random access point
            flag](#need-RAP-flag){#ref-for-need-RAP-flag-3 .internalDFN
            link-type="dfn|abstract-op"} on all [track
            buffers](#track-buffer){#ref-for-track-buffer-28
            .internalDFN link-type="dfn|abstract-op"} to true.
        4.  Unset
            [`[[group start timestamp]]`](#dfn-group-start-timestamp){#ref-for-dfn-group-start-timestamp-7
            .internalDFN link-type="attribute"
            lt="[[group start timestamp]]"}.

    4.  If
        [`timestampOffset`](#dom-sourcebuffer-timestampoffset){#ref-for-dom-sourcebuffer-timestampoffset-7
        .internalDFN link-type="idl"} is not 0, then run the following
        steps:

        1.  Add
            [`timestampOffset`](#dom-sourcebuffer-timestampoffset){#ref-for-dom-sourcebuffer-timestampoffset-8
            .internalDFN link-type="idl"} to the
            `presentation timestamp`{.variable data-type="double"}.
        2.  Add
            [`timestampOffset`](#dom-sourcebuffer-timestampoffset){#ref-for-dom-sourcebuffer-timestampoffset-9
            .internalDFN link-type="idl"} to the
            `decode timestamp`{.variable data-type="double"}.

    5.  Let `track buffer`{.variable} equal the [track
        buffer](#track-buffer){#ref-for-track-buffer-29 .internalDFN
        link-type="dfn|abstract-op"} that the coded frame will be added
        to.

    6.  

        If [last decode timestamp](#last-decode-timestamp){#ref-for-last-decode-timestamp-2 .internalDFN link-type="dfn|abstract-op"} for `track buffer`{.variable} is set and `decode timestamp`{.variable data-type="double"} is less than [last decode timestamp](#last-decode-timestamp){#ref-for-last-decode-timestamp-3 .internalDFN link-type="dfn|abstract-op"}:
        :   OR

        If [last decode timestamp](#last-decode-timestamp){#ref-for-last-decode-timestamp-4 .internalDFN link-type="dfn|abstract-op"} for `track buffer`{.variable} is set and the difference between `decode timestamp`{.variable data-type="double"} and [last decode timestamp](#last-decode-timestamp){#ref-for-last-decode-timestamp-5 .internalDFN link-type="dfn|abstract-op"} is greater than 2 times [last frame duration](#last-frame-duration){#ref-for-last-frame-duration-2 .internalDFN link-type="dfn|abstract-op"}:

        :   1.  

                If [`mode`](#dom-sourcebuffer-mode){#ref-for-dom-sourcebuffer-mode-12 .internalDFN link-type="idl"} equals \"[`segments`](#dom-appendmode-segments){#ref-for-dom-appendmode-segments-4 .internalDFN link-type="idl"}\":
                :   Set
                    [`[[group end timestamp]]`](#dfn-group-end-timestamp){#ref-for-dfn-group-end-timestamp-5
                    .internalDFN link-type="attribute"
                    lt="[[group end timestamp]]"} to
                    `presentation timestamp`{.variable}.

                If [`mode`](#dom-sourcebuffer-mode){#ref-for-dom-sourcebuffer-mode-13 .internalDFN link-type="idl"} equals \"[`sequence`](#dom-appendmode-sequence){#ref-for-dom-appendmode-sequence-11 .internalDFN link-type="idl"}\":
                :   Set
                    [`[[group start timestamp]]`](#dfn-group-start-timestamp){#ref-for-dfn-group-start-timestamp-8
                    .internalDFN link-type="attribute"
                    lt="[[group start timestamp]]"} equal to the
                    [`[[group end timestamp]]`](#dfn-group-end-timestamp){#ref-for-dfn-group-end-timestamp-6
                    .internalDFN link-type="attribute"
                    lt="[[group end timestamp]]"}.

            2.  Unset the [last decode
                timestamp](#last-decode-timestamp){#ref-for-last-decode-timestamp-6
                .internalDFN link-type="dfn|abstract-op"} on all [track
                buffers](#track-buffer){#ref-for-track-buffer-30
                .internalDFN link-type="dfn|abstract-op"}.

            3.  Unset the [last frame
                duration](#last-frame-duration){#ref-for-last-frame-duration-3
                .internalDFN link-type="dfn|abstract-op"} on all [track
                buffers](#track-buffer){#ref-for-track-buffer-31
                .internalDFN link-type="dfn|abstract-op"}.

            4.  Unset the [highest end
                timestamp](#highest-end-timestamp){#ref-for-highest-end-timestamp-2
                .internalDFN link-type="dfn|abstract-op"} on all [track
                buffers](#track-buffer){#ref-for-track-buffer-32
                .internalDFN link-type="dfn|abstract-op"}.

            5.  Set the [need random access point
                flag](#need-RAP-flag){#ref-for-need-RAP-flag-4
                .internalDFN link-type="dfn|abstract-op"} on all [track
                buffers](#track-buffer){#ref-for-track-buffer-33
                .internalDFN link-type="dfn|abstract-op"} to true.

            6.  Jump to the *Loop Top* step above to restart processing
                of the current [coded
                frame](#dfn-coded-frame){#ref-for-dfn-coded-frame-33
                .internalDFN link-type="dfn|abstract-op"}.

        Otherwise:
        :   Continue.

    7.  Let `frame end timestamp`{.variable data-type="double"} equal
        the sum of `presentation timestamp`{.variable
        data-type="double"} and `frame duration`{.variable
        data-type="double"}.

    8.  If `presentation timestamp`{.variable data-type="double"} is
        less than
        [`appendWindowStart`](#dom-sourcebuffer-appendwindowstart){#ref-for-dom-sourcebuffer-appendwindowstart-5
        .internalDFN link-type="idl"}, then set the [need random access
        point flag](#need-RAP-flag){#ref-for-need-RAP-flag-5
        .internalDFN link-type="dfn|abstract-op"} to true, drop the
        coded frame, and jump to the top of the loop to start processing
        the next coded frame.

        :::: {#issue-container-generatedID-63 .note role="note"}
        ::: {#h-note-63 .note-title .marker role="heading" aria-level="5"}
        Note
        :::

        Some implementations *MAY* choose to collect some of these coded
        frames with `presentation timestamp`{.variable
        data-type="double"} less than
        [`appendWindowStart`](#dom-sourcebuffer-appendwindowstart){#ref-for-dom-sourcebuffer-appendwindowstart-6
        .internalDFN link-type="idl"} and use them to generate a splice
        at the first coded frame that has a [presentation
        timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-19
        .internalDFN link-type="dfn|abstract-op"} greater than or equal
        to
        [`appendWindowStart`](#dom-sourcebuffer-appendwindowstart){#ref-for-dom-sourcebuffer-appendwindowstart-7
        .internalDFN link-type="idl"} even if that frame is not a
        [random access
        point](#random-access-point){#ref-for-random-access-point-4
        .internalDFN link-type="dfn|abstract-op"}. Supporting this
        requires multiple decoders or faster than real-time decoding so
        for now this behavior will not be a normative requirement.
        ::::

    9.  If `frame end timestamp`{.variable data-type="double"} is
        greater than
        [`appendWindowEnd`](#dom-sourcebuffer-appendwindowend){#ref-for-dom-sourcebuffer-appendwindowend-5
        .internalDFN link-type="idl"}, then set the [need random access
        point flag](#need-RAP-flag){#ref-for-need-RAP-flag-6
        .internalDFN link-type="dfn|abstract-op"} to true, drop the
        coded frame, and jump to the top of the loop to start processing
        the next coded frame.

        :::: {#issue-container-generatedID-64 .note role="note"}
        ::: {#h-note-64 .note-title .marker role="heading" aria-level="5"}
        Note
        :::

        Some implementations *MAY* choose to collect coded frames with
        `presentation timestamp`{.variable} less than
        [`appendWindowEnd`](#dom-sourcebuffer-appendwindowend){#ref-for-dom-sourcebuffer-appendwindowend-6
        .internalDFN link-type="idl"} and
        `frame end timestamp`{.variable data-type="double"} greater than
        [`appendWindowEnd`](#dom-sourcebuffer-appendwindowend){#ref-for-dom-sourcebuffer-appendwindowend-7
        .internalDFN link-type="idl"} and use them to generate a splice
        across the portion of the collected coded frames within the
        append window at time of collection, and the beginning portion
        of later processed frames which only partially overlap the end
        of the collected coded frames. Supporting this requires multiple
        decoders or faster than real-time decoding so for now this
        behavior will not be a normative requirement. In conjunction
        with collecting coded frames that span
        [`appendWindowStart`](#dom-sourcebuffer-appendwindowstart){#ref-for-dom-sourcebuffer-appendwindowstart-8
        .internalDFN link-type="idl"}, implementations *MAY* thus
        support gapless audio splicing.
        ::::

    10. If the [need random access point
        flag](#need-RAP-flag){#ref-for-need-RAP-flag-7 .internalDFN
        link-type="dfn|abstract-op"} on `track buffer`{.variable} equals
        true, then run the following steps:
        1.  If the coded frame is not a [random access
            point](#random-access-point){#ref-for-random-access-point-5
            .internalDFN link-type="dfn|abstract-op"}, then drop the
            coded frame and jump to the top of the loop to start
            processing the next coded frame.
        2.  Set the [need random access point
            flag](#need-RAP-flag){#ref-for-need-RAP-flag-8 .internalDFN
            link-type="dfn|abstract-op"} on `track buffer`{.variable} to
            false.

    11. Let `spliced audio frame`{.variable} be an unset variable for
        holding audio splice information

    12. Let `spliced timed text frame`{.variable} be an unset variable
        for holding timed text splice information

    13. If [last decode
        timestamp](#last-decode-timestamp){#ref-for-last-decode-timestamp-7
        .internalDFN link-type="dfn|abstract-op"} for
        `track buffer`{.variable} is unset and
        `presentation timestamp`{.variable} falls within the
        [presentation
        interval](#presentation-interval){#ref-for-presentation-interval-1
        .internalDFN link-type="dfn|abstract-op"} of a [coded
        frame](#dfn-coded-frame){#ref-for-dfn-coded-frame-34
        .internalDFN link-type="dfn|abstract-op"} in
        `track buffer`{.variable}, then run the following steps:
        1.  Let `overlapped frame`{.variable} be the [coded
            frame](#dfn-coded-frame){#ref-for-dfn-coded-frame-35
            .internalDFN link-type="dfn|abstract-op"} in
            `track buffer`{.variable} that matches the condition above.

        2.  

            If `track buffer`{.variable} contains audio [coded frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-36 .internalDFN link-type="dfn|abstract-op"}:
            :   Run the [audio splice
                frame](#dfn-audio-splice-frame){#ref-for-dfn-audio-splice-frame-1
                .internalDFN link-type="dfn|abstract-op"} algorithm and
                if a splice frame is returned, assign it to
                `spliced audio frame`{.variable}.

            If `track buffer`{.variable} contains video [coded frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-37 .internalDFN link-type="dfn|abstract-op"}:

            :   1.  Let `remove window timestamp`{.variable
                    data-type="double"} equal the
                    `overlapped frame`{.variable} [presentation
                    timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-20
                    .internalDFN link-type="dfn|abstract-op"} plus 1
                    microsecond.
                2.  If the `presentation timestamp`{.variable
                    data-type="double"} is less than the
                    `remove window timestamp`{.variable}, then remove
                    `overlapped frame`{.variable} from
                    `track buffer`{.variable}.

                    :::: {#issue-container-generatedID-65 .note role="note"}
                    ::: {#h-note-65 .note-title .marker role="heading" aria-level="5"}
                    Note
                    :::

                    This is to compensate for minor errors in frame
                    timestamp computations that can appear when
                    converting back and forth between double precision
                    floating point numbers and rationals. This tolerance
                    allows a frame to replace an existing one as long as
                    it is within 1 microsecond of the existing frame\'s
                    start time. Frames that come slightly before an
                    existing frame are handled by the removal step
                    below.
                    ::::

            If `track buffer`{.variable} contains timed text [coded frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-38 .internalDFN link-type="dfn|abstract-op"}:
            :   Run the [text splice
                frame](#dfn-text-splice-frame){#ref-for-dfn-text-splice-frame-1
                .internalDFN link-type="dfn|abstract-op"} algorithm and
                if a splice frame is returned, assign it to
                `spliced timed text frame`{.variable}.

    14. Remove existing coded frames in `track buffer`{.variable}:

        If [highest end timestamp](#highest-end-timestamp){#ref-for-highest-end-timestamp-3 .internalDFN link-type="dfn|abstract-op"} for `track buffer`{.variable} is not set:
        :   Remove all [coded
            frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-39
            .internalDFN link-type="dfn|abstract-op"} from
            `track buffer`{.variable} that have a [presentation
            timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-21
            .internalDFN link-type="dfn|abstract-op"} greater than or
            equal to `presentation timestamp`{.variable
            data-type="double"} and less than
            `frame end timestamp`{.variable data-type="double"}.

        If [highest end timestamp](#highest-end-timestamp){#ref-for-highest-end-timestamp-4 .internalDFN link-type="dfn|abstract-op"} for `track buffer`{.variable} is set and less than or equal to `presentation timestamp`{.variable data-type="double"}:
        :   Remove all [coded
            frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-40
            .internalDFN link-type="dfn|abstract-op"} from
            `track buffer`{.variable} that have a [presentation
            timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-22
            .internalDFN link-type="dfn|abstract-op"} greater than or
            equal to [highest end
            timestamp](#highest-end-timestamp){#ref-for-highest-end-timestamp-5
            .internalDFN link-type="dfn|abstract-op"} and less than
            `frame end timestamp`{.variable data-type="double"}.

    15. Remove all possible decoding dependencies on the [coded
        frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-41
        .internalDFN link-type="dfn|abstract-op"} removed in the
        previous two steps by removing all [coded
        frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-42
        .internalDFN link-type="dfn|abstract-op"} from
        `track buffer`{.variable} between those frames removed in the
        previous two steps and the next [random access
        point](#random-access-point){#ref-for-random-access-point-6
        .internalDFN link-type="dfn|abstract-op"} after those removed
        frames.

        :::: {#issue-container-generatedID-66 .note role="note"}
        ::: {#h-note-66 .note-title .marker role="heading" aria-level="5"}
        Note
        :::

        Removing all [coded
        frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-43
        .internalDFN link-type="dfn|abstract-op"} until the next [random
        access
        point](#random-access-point){#ref-for-random-access-point-7
        .internalDFN link-type="dfn|abstract-op"} is a conservative
        estimate of the decoding dependencies since it assumes all
        frames between the removed frames and the next random access
        point depended on the frames that were removed.
        ::::

    16. 

        If `spliced audio frame`{.variable} is set:
        :   Add `spliced audio frame`{.variable} to the
            `track buffer`{.variable}.

        If `spliced timed text frame`{.variable} is set:
        :   Add `spliced timed text frame`{.variable} to the
            `track buffer`{.variable}.

        Otherwise:
        :   Add the [coded
            frame](#dfn-coded-frame){#ref-for-dfn-coded-frame-44
            .internalDFN link-type="dfn|abstract-op"} with the
            `presentation timestamp`{.variable data-type="double"},
            `decode timestamp`{.variable}, and
            `frame duration`{.variable data-type="double"} to the
            `track buffer`{.variable}.

    17. Set [last decode
        timestamp](#last-decode-timestamp){#ref-for-last-decode-timestamp-8
        .internalDFN link-type="dfn|abstract-op"} for
        `track buffer`{.variable} to `decode timestamp`{.variable
        data-type="double"}.

    18. Set [last frame
        duration](#last-frame-duration){#ref-for-last-frame-duration-4
        .internalDFN link-type="dfn|abstract-op"} for
        `track buffer`{.variable} to `frame duration`{.variable
        data-type="double"}.

    19. If [highest end
        timestamp](#highest-end-timestamp){#ref-for-highest-end-timestamp-6
        .internalDFN link-type="dfn|abstract-op"} for
        `track buffer`{.variable} is unset or
        `frame end timestamp`{.variable} is greater than [highest end
        timestamp](#highest-end-timestamp){#ref-for-highest-end-timestamp-7
        .internalDFN link-type="dfn|abstract-op"}, then set [highest end
        timestamp](#highest-end-timestamp){#ref-for-highest-end-timestamp-8
        .internalDFN link-type="dfn|abstract-op"} for
        `track buffer`{.variable} to `frame end timestamp`{.variable
        data-type="double"}.

        :::: {#issue-container-generatedID-67 .note role="note"}
        ::: {#h-note-67 .note-title .marker role="heading" aria-level="5"}
        Note
        :::

        The greater than check is needed because bidirectional
        prediction between coded frames can cause
        `presentation timestamp`{.variable data-type="double"} to not be
        monotonically increasing even though the decode timestamps are
        monotonically increasing.
        ::::

    20. If `frame end timestamp`{.variable data-type="double"} is
        greater than
        [`[[group end timestamp]]`](#dfn-group-end-timestamp){#ref-for-dfn-group-end-timestamp-7
        .internalDFN link-type="attribute"
        lt="[[group end timestamp]]"}, then set
        [`[[group end timestamp]]`](#dfn-group-end-timestamp){#ref-for-dfn-group-end-timestamp-8
        .internalDFN link-type="attribute" lt="[[group end timestamp]]"}
        equal to `frame end timestamp`{.variable}.

    21. If
        [`[[generate timestamps flag]]`](#dfn-generate-timestamps-flag){#ref-for-dfn-generate-timestamps-flag-7
        .internalDFN link-type="attribute"
        lt="[[generate timestamps flag]]"} equals true, then set
        [`timestampOffset`](#dom-sourcebuffer-timestampoffset){#ref-for-dom-sourcebuffer-timestampoffset-10
        .internalDFN link-type="idl"} equal to
        `frame end timestamp`{.variable data-type="double"}.

2.  If the
    [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
    lt="HTMLMediaElement"}\'s
    [`readyState`](#dom-readystate){#ref-for-dom-readystate-26
    .internalDFN link-type="idl"} attribute is
    [`HAVE_METADATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_metadata){link-type="const"}
    and the new [coded
    frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-45 .internalDFN
    link-type="dfn|abstract-op"} cause
    [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
    lt="HTMLMediaElement"}\'s
    [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered){link-type="attribute"}
    to have a
    [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface"
    lt="TimeRanges"} for the current playback position, then set the
    [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
    lt="HTMLMediaElement"}\'s
    [`readyState`](#dom-readystate){#ref-for-dom-readystate-27
    .internalDFN link-type="idl"} attribute to
    [`HAVE_CURRENT_DATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_current_data){link-type="const"}.

    :::: {#issue-container-generatedID-68 .note role="note"}
    ::: {#h-note-68 .note-title .marker role="heading" aria-level="5"}
    Note
    :::

    Per
    [`HTMLMediaElement ready states`](https://html.spec.whatwg.org/multipage/media.html#ready-states)
    \[[HTML](#bib-html "HTML Standard"){.bibref link-type="biblio"}\]
    logic,
    [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
    lt="HTMLMediaElement"}\'s
    [`readyState`](#dom-readystate){#ref-for-dom-readystate-28
    .internalDFN link-type="idl"} changes may trigger events on the
    HTMLMediaElement.
    ::::

3.  If the
    [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
    lt="HTMLMediaElement"}\'s
    [`readyState`](#dom-readystate){#ref-for-dom-readystate-29
    .internalDFN link-type="idl"} attribute is
    [`HAVE_CURRENT_DATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_current_data){link-type="const"}
    and the new [coded
    frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-46 .internalDFN
    link-type="dfn|abstract-op"} cause
    [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
    lt="HTMLMediaElement"}\'s
    [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered){link-type="attribute"}
    to have a
    [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface"
    lt="TimeRanges"} that includes the current playback position and
    some time beyond the current playback position, then set the
    [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
    lt="HTMLMediaElement"}\'s
    [`readyState`](#dom-readystate){#ref-for-dom-readystate-30
    .internalDFN link-type="idl"} attribute to
    [`HAVE_FUTURE_DATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_future_data){link-type="const"}.

    :::: {#issue-container-generatedID-69 .note role="note"}
    ::: {#h-note-69 .note-title .marker role="heading" aria-level="5"}
    Note
    :::

    Per
    [`HTMLMediaElement ready states`](https://html.spec.whatwg.org/multipage/media.html#ready-states)
    \[[HTML](#bib-html "HTML Standard"){.bibref link-type="biblio"}\]
    logic,
    [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
    lt="HTMLMediaElement"}\'s
    [`readyState`](#dom-readystate){#ref-for-dom-readystate-31
    .internalDFN link-type="idl"} changes may trigger events on the
    HTMLMediaElement.
    ::::

4.  If the
    [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
    lt="HTMLMediaElement"}\'s
    [`readyState`](#dom-readystate){#ref-for-dom-readystate-32
    .internalDFN link-type="idl"} attribute is
    [`HAVE_FUTURE_DATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_future_data){link-type="const"}
    and the new [coded
    frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-47 .internalDFN
    link-type="dfn|abstract-op"} cause
    [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
    lt="HTMLMediaElement"}\'s
    [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered){link-type="attribute"}
    to have a
    [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface"
    lt="TimeRanges"} that includes the current playback position and
    [enough data to ensure uninterrupted
    playback](#enough-data){#ref-for-enough-data-3 .internalDFN
    link-type="dfn|abstract-op"}, then set the
    [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
    lt="HTMLMediaElement"}\'s
    [`readyState`](#dom-readystate){#ref-for-dom-readystate-33
    .internalDFN link-type="idl"} attribute to
    [`HAVE_ENOUGH_DATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_enough_data){link-type="const"}.

    :::: {#issue-container-generatedID-70 .note role="note"}
    ::: {#h-note-70 .note-title .marker role="heading" aria-level="5"}
    Note
    :::

    Per
    [`HTMLMediaElement ready states`](https://html.spec.whatwg.org/multipage/media.html#ready-states)
    \[[HTML](#bib-html "HTML Standard"){.bibref link-type="biblio"}\]
    logic,
    [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
    lt="HTMLMediaElement"}\'s
    [`readyState`](#dom-readystate){#ref-for-dom-readystate-34
    .internalDFN link-type="idl"} changes may trigger events on the
    HTMLMediaElement.
    ::::

5.  If the [media
    segment](#dfn-media-segment){#ref-for-dfn-media-segment-14
    .internalDFN link-type="dfn|abstract-op"} contains data beyond the
    current
    [`duration`](#dom-mediasource-duration){#ref-for-dom-mediasource-duration-10
    .internalDFN link-type="idl"}, then run the [duration
    change](#dfn-duration-change){#ref-for-dfn-duration-change-6
    .internalDFN link-type="dfn|abstract-op"} algorithm with
    `new duration`{.variable data-type="unrestricted double"} set to the
    maximum of the current duration and the
    [`[[group end timestamp]]`](#dfn-group-end-timestamp){#ref-for-dfn-group-end-timestamp-9
    .internalDFN link-type="attribute" lt="[[group end timestamp]]"}.
::::

:::: {#sourcebuffer-coded-frame-removal .section}
::: header-wrapper
#### 5.5.9 [Coded Frame Removal]{#dfn-coded-frame-removal .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"} {#x5-5-9-coded-frame-removal}

[](#sourcebuffer-coded-frame-removal){.self-link
aria-label="Permalink for Section 5.5.9"}
:::

Follow these steps when [coded
frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-48 .internalDFN
link-type="dfn|abstract-op"} for a specific time range need to be
removed from the SourceBuffer:

1.  Let `start`{.variable data-type="double"} be the starting
    [presentation
    timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-23
    .internalDFN link-type="dfn|abstract-op"} for the removal range.

2.  Let `end`{.variable data-type="unrestricted double"} be the end
    [presentation
    timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-24
    .internalDFN link-type="dfn|abstract-op"} for the removal range.

3.  For each [track buffer](#track-buffer){#ref-for-track-buffer-34
    .internalDFN link-type="dfn|abstract-op"} in this
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-104
    .internalDFN link-type="idl" lt="SourceBuffer"}, run the following
    steps:

    1.  Let `remove end timestamp`{.variable
        data-type="unrestricted double"} be the current value of
        [`duration`](#dom-mediasource-duration){#ref-for-dom-mediasource-duration-11
        .internalDFN link-type="idl"}

    2.  If this [track buffer](#track-buffer){#ref-for-track-buffer-35
        .internalDFN link-type="dfn|abstract-op"} has a [random access
        point](#random-access-point){#ref-for-random-access-point-8
        .internalDFN link-type="dfn|abstract-op"} timestamp that is
        greater than or equal to `end`{.variable
        data-type="unrestricted double"}, then update
        `remove end timestamp`{.variable
        data-type="unrestricted double"} to that random access point
        timestamp.

        :::: {#issue-container-generatedID-71 .note role="note"}
        ::: {#h-note-71 .note-title .marker role="heading" aria-level="5"}
        Note
        :::

        Random access point timestamps can be different across tracks
        because the dependencies between [coded
        frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-49
        .internalDFN link-type="dfn|abstract-op"} within a track are
        usually different than the dependencies in another track.
        ::::

    3.  Remove all media data, from this [track
        buffer](#track-buffer){#ref-for-track-buffer-36 .internalDFN
        link-type="dfn|abstract-op"}, that contain starting timestamps
        greater than or equal to `start`{.variable data-type="double"}
        and less than the `remove end timestamp`{.variable}.
        1.  For each removed frame, if the frame has a [decode
            timestamp](#dfn-decode-timestamp){#ref-for-dfn-decode-timestamp-3
            .internalDFN link-type="dfn|abstract-op"} equal to the [last
            decode
            timestamp](#last-decode-timestamp){#ref-for-last-decode-timestamp-9
            .internalDFN link-type="dfn|abstract-op"} for the frame\'s
            track, run the following steps:

            If [`mode`](#dom-sourcebuffer-mode){#ref-for-dom-sourcebuffer-mode-14 .internalDFN link-type="idl"} equals \"[`segments`](#dom-appendmode-segments){#ref-for-dom-appendmode-segments-5 .internalDFN link-type="idl"}\":
            :   Set
                [`[[group end timestamp]]`](#dfn-group-end-timestamp){#ref-for-dfn-group-end-timestamp-10
                .internalDFN link-type="attribute"
                lt="[[group end timestamp]]"} to [presentation
                timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-25
                .internalDFN link-type="dfn|abstract-op"}.

            If [`mode`](#dom-sourcebuffer-mode){#ref-for-dom-sourcebuffer-mode-15 .internalDFN link-type="idl"} equals \"[`sequence`](#dom-appendmode-sequence){#ref-for-dom-appendmode-sequence-12 .internalDFN link-type="idl"}\":
            :   Set
                [`[[group start timestamp]]`](#dfn-group-start-timestamp){#ref-for-dfn-group-start-timestamp-9
                .internalDFN link-type="attribute"
                lt="[[group start timestamp]]"} equal to the
                [`[[group end timestamp]]`](#dfn-group-end-timestamp){#ref-for-dfn-group-end-timestamp-11
                .internalDFN link-type="attribute"
                lt="[[group end timestamp]]"}.

        2.  Unset the [last decode
            timestamp](#last-decode-timestamp){#ref-for-last-decode-timestamp-10
            .internalDFN link-type="dfn|abstract-op"} on all [track
            buffers](#track-buffer){#ref-for-track-buffer-37
            .internalDFN link-type="dfn|abstract-op"}.

        3.  Unset the [last frame
            duration](#last-frame-duration){#ref-for-last-frame-duration-5
            .internalDFN link-type="dfn|abstract-op"} on all [track
            buffers](#track-buffer){#ref-for-track-buffer-38
            .internalDFN link-type="dfn|abstract-op"}.

        4.  Unset the [highest end
            timestamp](#highest-end-timestamp){#ref-for-highest-end-timestamp-9
            .internalDFN link-type="dfn|abstract-op"} on all [track
            buffers](#track-buffer){#ref-for-track-buffer-39
            .internalDFN link-type="dfn|abstract-op"}.

        5.  Set the [need random access point
            flag](#need-RAP-flag){#ref-for-need-RAP-flag-9 .internalDFN
            link-type="dfn|abstract-op"} on all [track
            buffers](#track-buffer){#ref-for-track-buffer-40
            .internalDFN link-type="dfn|abstract-op"} to true.

    4.  Remove all possible decoding dependencies on the [coded
        frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-50
        .internalDFN link-type="dfn|abstract-op"} removed in the
        previous step by removing all [coded
        frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-51
        .internalDFN link-type="dfn|abstract-op"} from this [track
        buffer](#track-buffer){#ref-for-track-buffer-41 .internalDFN
        link-type="dfn|abstract-op"} between those frames removed in the
        previous step and the next [random access
        point](#random-access-point){#ref-for-random-access-point-9
        .internalDFN link-type="dfn|abstract-op"} after those removed
        frames.

        :::: {#issue-container-generatedID-72 .note role="note"}
        ::: {#h-note-72 .note-title .marker role="heading" aria-level="5"}
        Note
        :::

        Removing all [coded
        frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-52
        .internalDFN link-type="dfn|abstract-op"} until the next [random
        access
        point](#random-access-point){#ref-for-random-access-point-10
        .internalDFN link-type="dfn|abstract-op"} is a conservative
        estimate of the decoding dependencies since it assumes all
        frames between the removed frames and the next random access
        point depended on the frames that were removed.
        ::::

    5.  If this object is in
        [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-30
        .internalDFN link-type="idl"}, the [current playback
        position](https://html.spec.whatwg.org/multipage/media.html#current-playback-position)
        is greater than or equal to `start`{.variable
        data-type="double"} and less than the
        `remove end timestamp`{.variable
        data-type="unrestricted double"}, and
        [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
        lt="HTMLMediaElement"}\'s
        [`readyState`](#dom-readystate){#ref-for-dom-readystate-35
        .internalDFN link-type="idl"} is greater than
        [`HAVE_METADATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_metadata){link-type="const"},
        then set the
        [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
        lt="HTMLMediaElement"}\'s
        [`readyState`](#dom-readystate){#ref-for-dom-readystate-36
        .internalDFN link-type="idl"} attribute to
        [`HAVE_METADATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_metadata){link-type="const"}
        and stall playback.

        :::: {#issue-container-generatedID-73 .note role="note"}
        ::: {#h-note-73 .note-title .marker role="heading" aria-level="5"}
        Note
        :::

        Per
        [`HTMLMediaElement ready states`](https://html.spec.whatwg.org/multipage/media.html#ready-states)
        \[[HTML](#bib-html "HTML Standard"){.bibref
        link-type="biblio"}\] logic,
        [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
        lt="HTMLMediaElement"}\'s
        [`readyState`](#dom-readystate){#ref-for-dom-readystate-37
        .internalDFN link-type="idl"} changes may trigger events on the
        HTMLMediaElement.
        ::::

        :::: {#issue-container-generatedID-74 .note role="note"}
        ::: {#h-note-74 .note-title .marker role="heading" aria-level="5"}
        Note
        :::

        This transition occurs because media data for the current
        position has been removed. Playback cannot progress until media
        for the [current playback
        position](https://html.spec.whatwg.org/multipage/media.html#current-playback-position)
        is appended or the [3.15.5 Changes to selected/enabled track
        state](#active-source-buffer-changes){.sec-ref
        matched-text="[[[#active-source-buffer-changes]]]"}.
        ::::

4.  If the
    [`[[buffer full flag]]`](#dfn-buffer-full-flag){#ref-for-dfn-buffer-full-flag-3
    .internalDFN link-type="attribute" lt="[[buffer full flag]]"} equals
    true and this object is ready to accept more bytes, then set the
    [`[[buffer full flag]]`](#dfn-buffer-full-flag){#ref-for-dfn-buffer-full-flag-4
    .internalDFN link-type="attribute" lt="[[buffer full flag]]"} to
    false.
::::

:::: {#sourcebuffer-coded-frame-eviction .section}
::: header-wrapper
#### 5.5.10 [Coded Frame Eviction]{#dfn-coded-frame-eviction .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"} {#x5-5-10-coded-frame-eviction}

[](#sourcebuffer-coded-frame-eviction){.self-link
aria-label="Permalink for Section 5.5.10"}
:::

This algorithm is run to free up space in this
[`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-105
.internalDFN link-type="idl" lt="SourceBuffer"} when new data is
appended.

1.  Let `new data`{.variable data-type="BufferSource"} equal the data
    that is about to be appended to this SourceBuffer.

    ::::: {#issue-container-number-289 .issue}
    ::: {#h-issue-1 .issue-title .marker role="heading" aria-level="5"}
    [[Issue
    289]{.issue-number}](https://github.com/w3c/media-source/issues/289)[:
    Editorial? Coded Frame eviction algorithm needs to note that
    \"buffer full flag\" may be updated immediately based on \|new
    data\|]{.issue-label}
    :::

    ::: {}
    Need to recognize step here that implementations *MAY* decide to set
    [`[[buffer full flag]]`](#dfn-buffer-full-flag){#ref-for-dfn-buffer-full-flag-5
    .internalDFN link-type="attribute" lt="[[buffer full flag]]"} true
    here if it predicts that processing `new data`{.variable
    data-type="BufferSource"} in addition to any existing bytes in
    [`[[input buffer]]`](#dfn-input-buffer){#ref-for-dfn-input-buffer-14
    .internalDFN link-type="attribute" lt="[[input buffer]]"} would
    exceed the capacity of the
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-106
    .internalDFN link-type="idl" lt="SourceBuffer"}. Such a step enables
    more proactive push-back from implementations before accepting
    `new data`{.variable data-type="BufferSource"} which would overflow
    resources, for example. In practice, at least one implementation
    already does this.
    :::
    :::::
2.  If the
    [`[[buffer full flag]]`](#dfn-buffer-full-flag){#ref-for-dfn-buffer-full-flag-6
    .internalDFN link-type="attribute" lt="[[buffer full flag]]"} equals
    false, then abort these steps.
3.  Let `removal ranges`{.variable data-type="normalized TimeRanges"}
    equal a list of presentation time ranges that can be evicted from
    the presentation to make room for the `new data`{.variable
    data-type="BufferSource"}.

    :::: {#issue-container-generatedID-75 .note role="note"}
    ::: {#h-note-75 .note-title .marker role="heading" aria-level="5"}
    Note
    :::

    Implementations *MAY* use different methods for selecting
    `removal ranges`{.variable data-type="normalized TimeRanges"} so web
    applications *SHOULD NOT* depend on a specific behavior. The web
    application can use the
    [`buffered`](#dom-sourcebuffer-buffered){#ref-for-dom-sourcebuffer-buffered-4
    .internalDFN link-type="idl"} attribute to observe whether portions
    of the buffered data have been evicted.
    ::::
4.  For each range in `removal ranges`{.variable
    data-type="normalized TimeRanges"}, run the [coded frame
    removal](#dfn-coded-frame-removal){#ref-for-dfn-coded-frame-removal-4
    .internalDFN link-type="dfn|abstract-op"} algorithm with
    `start`{.variable data-type="double"} and `end`{.variable
    data-type="unrestricted double"} equal to the removal range start
    and end timestamp respectively.
::::

:::: {#sourcebuffer-audio-splice-frame-algorithm .section}
::: header-wrapper
#### 5.5.11 [Audio Splice Frame]{#dfn-audio-splice-frame .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"} {#x5-5-11-audio-splice-frame}

[](#sourcebuffer-audio-splice-frame-algorithm){.self-link
aria-label="Permalink for Section 5.5.11"}
:::

Follow these steps when the [coded frame
processing](#dfn-coded-frame-processing){#ref-for-dfn-coded-frame-processing-11
.internalDFN link-type="dfn|abstract-op"} algorithm needs to generate a
splice frame for two overlapping audio [coded
frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-53 .internalDFN
link-type="dfn|abstract-op"}:

1.  Let `track buffer`{.variable} be the [track
    buffer](#track-buffer){#ref-for-track-buffer-42 .internalDFN
    link-type="dfn|abstract-op"} that will contain the splice.
2.  Let `new coded frame`{.variable} be the new [coded
    frame](#dfn-coded-frame){#ref-for-dfn-coded-frame-54 .internalDFN
    link-type="dfn|abstract-op"}, that is being added to
    `track buffer`{.variable}, which triggered the need for a splice.
3.  Let `presentation timestamp`{.variable data-type="double"} be the
    [presentation
    timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-26
    .internalDFN link-type="dfn|abstract-op"} for
    `new coded frame`{.variable}.
4.  Let `decode timestamp`{.variable data-type="double"} be the decode
    timestamp for `new coded frame`{.variable}.
5.  Let `frame duration`{.variable data-type="double"} be the [coded
    frame
    duration](#dfn-coded-frame-duration){#ref-for-dfn-coded-frame-duration-7
    .internalDFN link-type="dfn|abstract-op"} of
    `new coded frame`{.variable}.
6.  Let `overlapped frame`{.variable} be the [coded
    frame](#dfn-coded-frame){#ref-for-dfn-coded-frame-55 .internalDFN
    link-type="dfn|abstract-op"} in `track buffer`{.variable} with a
    [presentation
    interval](#presentation-interval){#ref-for-presentation-interval-2
    .internalDFN link-type="dfn|abstract-op"} that contains
    `presentation timestamp`{.variable data-type="double"}.
7.  Update `presentation timestamp`{.variable data-type="double"} and
    `decode timestamp`{.variable data-type="double"} to the nearest
    audio sample timestamp based on sample rate of the audio in
    `overlapped frame`{.variable}. If a timestamp is equidistant from
    both audio sample timestamps, then use the higher timestamp (e.g.,
    `floor(x * sample_rate + 0.5) / sample_rate`).

    ::::: {#issue-container-generatedID-76 .note role="note"}
    ::: {#h-note-76 .note-title .marker role="heading" aria-level="5"}
    Note
    :::

    ::: {}
    For example, given the following values:

    - The [presentation
      timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-27
      .internalDFN link-type="dfn|abstract-op"} of
      `overlapped frame`{.variable} equals 10.
    - The sample rate of `overlapped frame`{.variable} equals 8000 Hz
    - `presentation timestamp`{.variable data-type="double"} equals
      10.01255
    - `decode timestamp`{.variable data-type="double"} equals 10.01255

    `presentation timestamp`{.variable data-type="double"} and
    `decode timestamp`{.variable data-type="double"} are updated to
    10.0125 since 10.01255 is closer to 10 + 100/8000 (10.0125) than
    10 + 101/8000 (10.012625)
    :::
    :::::
8.  If the user agent does not support crossfading then run the
    following steps:
    1.  Remove `overlapped frame`{.variable} from
        `track buffer`{.variable}.
    2.  Add a silence frame to `track buffer`{.variable} with the
        following properties:
        - The [presentation
          timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-28
          .internalDFN link-type="dfn|abstract-op"} set to the
          `overlapped frame`{.variable} [presentation
          timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-29
          .internalDFN link-type="dfn|abstract-op"}.
        - The [decode
          timestamp](#dfn-decode-timestamp){#ref-for-dfn-decode-timestamp-4
          .internalDFN link-type="dfn|abstract-op"} set to the
          `overlapped frame`{.variable} [decode
          timestamp](#dfn-decode-timestamp){#ref-for-dfn-decode-timestamp-5
          .internalDFN link-type="dfn|abstract-op"}.
        - The [coded frame
          duration](#dfn-coded-frame-duration){#ref-for-dfn-coded-frame-duration-8
          .internalDFN link-type="dfn|abstract-op"} set to difference
          between `presentation timestamp`{.variable} and the
          `overlapped frame`{.variable} [presentation
          timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-30
          .internalDFN link-type="dfn|abstract-op"}.

        :::: {#issue-container-generatedID-77 .note role="note"}
        ::: {#h-note-77 .note-title .marker role="heading" aria-level="5"}
        Note
        :::

        Some implementations *MAY* apply fades to/from silence to coded
        frames on either side of the inserted silence to make the
        transition less jarring.
        ::::
    3.  Return to caller without providing a splice frame.

        :::: {#issue-container-generatedID-78 .note role="note"}
        ::: {#h-note-78 .note-title .marker role="heading" aria-level="5"}
        Note
        :::

        This is intended to allow `new coded frame`{.variable} to be
        added to the `track buffer`{.variable} as if
        `overlapped frame`{.variable} had not been in the
        `track buffer`{.variable} to begin with.
        ::::
9.  Let `frame end timestamp`{.variable data-type="double"} equal the
    sum of `presentation timestamp`{.variable data-type="double"} and
    `frame duration`{.variable data-type="double"}.
10. Let `splice end timestamp`{.variable data-type="double"} equal the
    sum of `presentation timestamp`{.variable data-type="double"} and
    the splice duration of 5 milliseconds.
11. Let `fade out coded frames`{.variable} equal
    `overlapped frame`{.variable} as well as any additional frames in
    `track buffer`{.variable} that have a [presentation
    timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-31
    .internalDFN link-type="dfn|abstract-op"} greater than
    `presentation timestamp`{.variable data-type="double"} and less than
    `splice end timestamp`{.variable data-type="double"}.
12. Remove all the frames included in `fade out coded frames`{.variable}
    from `track buffer`{.variable}.
13. Return a splice frame with the following properties:
    - The [presentation
      timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-32
      .internalDFN link-type="dfn|abstract-op"} set to the
      `overlapped frame`{.variable} [presentation
      timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-33
      .internalDFN link-type="dfn|abstract-op"}.
    - The [decode
      timestamp](#dfn-decode-timestamp){#ref-for-dfn-decode-timestamp-6
      .internalDFN link-type="dfn|abstract-op"} set to the
      `overlapped frame`{.variable} [decode
      timestamp](#dfn-decode-timestamp){#ref-for-dfn-decode-timestamp-7
      .internalDFN link-type="dfn|abstract-op"}.
    - The [coded frame
      duration](#dfn-coded-frame-duration){#ref-for-dfn-coded-frame-duration-9
      .internalDFN link-type="dfn|abstract-op"} set to difference
      between `frame end timestamp`{.variable data-type="double"} and
      the `overlapped frame`{.variable} [presentation
      timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-34
      .internalDFN link-type="dfn|abstract-op"}.
    - The fade out coded frames equals
      `fade out coded frames`{.variable}.
    - The fade in coded frame equals `new coded frame`{.variable}.

      :::: {#issue-container-generatedID-79 .note role="note"}
      ::: {#h-note-79 .note-title .marker role="heading" aria-level="5"}
      Note
      :::

      If the `new coded frame`{.variable} is less than 5 milliseconds in
      duration, then coded frames that are appended after the
      `new coded frame`{.variable} will be needed to properly render the
      splice.
      ::::
    - The splice timestamp equals `presentation timestamp`{.variable
      data-type="double"}.

    :::: {#issue-container-generatedID-80 .note role="note"}
    ::: {#h-note-80 .note-title .marker role="heading" aria-level="5"}
    Note
    :::

    See the [audio splice
    rendering](#dfn-audio-splice-rendering){#ref-for-dfn-audio-splice-rendering-1
    .internalDFN link-type="dfn|abstract-op"} algorithm for details on
    how this splice frame is rendered.
    ::::
::::

::::::: {#sourcebuffer-audio-splice-rendering-algorithm .section}
::: header-wrapper
#### 5.5.12 [Audio Splice Rendering]{#dfn-audio-splice-rendering .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"} {#x5-5-12-audio-splice-rendering}

[](#sourcebuffer-audio-splice-rendering-algorithm){.self-link
aria-label="Permalink for Section 5.5.12"}
:::

The following steps are run when a spliced frame, generated by the
[audio splice
frame](#dfn-audio-splice-frame){#ref-for-dfn-audio-splice-frame-2
.internalDFN link-type="dfn|abstract-op"} algorithm, needs to be
rendered by the media element:

1.  Let `fade out coded frames`{.variable} be the [coded
    frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-56 .internalDFN
    link-type="dfn|abstract-op"} that are faded out during the splice.
2.  Let `fade in coded frames`{.variable} be the [coded
    frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-57 .internalDFN
    link-type="dfn|abstract-op"} that are faded in during the splice.
3.  Let `presentation timestamp`{.variable data-type="double"} be the
    [presentation
    timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-35
    .internalDFN link-type="dfn|abstract-op"} of the first coded frame
    in `fade out coded frames`{.variable}.
4.  Let `end timestamp`{.variable data-type="double"} be the sum of the
    [presentation
    timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-36
    .internalDFN link-type="dfn|abstract-op"} and the [coded frame
    duration](#dfn-coded-frame-duration){#ref-for-dfn-coded-frame-duration-10
    .internalDFN link-type="dfn|abstract-op"} of the last frame in
    `fade in coded frames`{.variable}.
5.  Let `splice timestamp`{.variable data-type="double"} be the
    [presentation
    timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-37
    .internalDFN link-type="dfn|abstract-op"} where the splice starts.
    This corresponds with the [presentation
    timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-38
    .internalDFN link-type="dfn|abstract-op"} of the first frame in
    `fade in coded frames`{.variable}.
6.  Let `splice end timestamp`{.variable data-type="double"} equal
    `splice timestamp`{.variable data-type="double"} plus five
    milliseconds.
7.  Let `fade out samples`{.variable} be the samples generated by
    decoding `fade out coded frames`{.variable}.
8.  Trim `fade out samples`{.variable} so that it only contains samples
    between `presentation timestamp`{.variable} and
    `splice end timestamp`{.variable data-type="double"}.
9.  Let `fade in samples`{.variable} be the samples generated by
    decoding `fade in coded frames`{.variable}.
10. If `fade out samples`{.variable} and `fade in samples`{.variable} do
    not have a common sample rate and channel layout, then convert
    `fade out samples`{.variable} and `fade in samples`{.variable} to a
    common sample rate and channel layout.
11. Let `output samples`{.variable} be a buffer to hold the output
    samples.
12. Apply a linear gain fade out with a starting gain of 1 and an ending
    gain of 0 to the samples between `splice timestamp`{.variable
    data-type="double"} and `splice end timestamp`{.variable
    data-type="double"} in `fade out samples`{.variable}.
13. Apply a linear gain fade in with a starting gain of 0 and an ending
    gain of 1 to the samples between `splice timestamp`{.variable
    data-type="double"} and `splice end timestamp`{.variable
    data-type="double"} in `fade in samples`{.variable}.
14. Copy samples between `presentation timestamp`{.variable
    data-type="double"} to `splice timestamp`{.variable
    data-type="double"} from `fade out samples`{.variable} into
    `output samples`{.variable}.
15. For each sample between `splice timestamp`{.variable
    data-type="double"} and `splice end timestamp`{.variable
    data-type="double"}, compute the sum of a sample from
    `fade out samples`{.variable} and the corresponding sample in
    `fade in samples`{.variable} and store the result in
    `output samples`{.variable}.
16. Copy samples between `splice end timestamp`{.variable
    data-type="double"} to `end timestamp`{.variable data-type="double"}
    from `fade in samples`{.variable} into `output samples`{.variable}.
17. Render `output samples`{.variable}.

::::: {#issue-container-generatedID-81 .note role="note"}
::: {#h-note-81 .note-title .marker role="heading" aria-level="5"}
Note
:::

::: {}
Here is a graphical representation of this algorithm.

![Audio splice diagram](audio_splice.png)
:::
:::::
:::::::

:::: {#sourcebuffer-text-splice-frame-algorithm .section}
::: header-wrapper
#### 5.5.13 [Text Splice Frame]{#dfn-text-splice-frame .dfn tabindex="0" aria-haspopup="dialog" dfn-type="dfn"} {#x5-5-13-text-splice-frame}

[](#sourcebuffer-text-splice-frame-algorithm){.self-link
aria-label="Permalink for Section 5.5.13"}
:::

Follow these steps when the [coded frame
processing](#dfn-coded-frame-processing){#ref-for-dfn-coded-frame-processing-12
.internalDFN link-type="dfn|abstract-op"} algorithm needs to generate a
splice frame for two overlapping timed text [coded
frames](#dfn-coded-frame){#ref-for-dfn-coded-frame-58 .internalDFN
link-type="dfn|abstract-op"}:

1.  Let `track buffer`{.variable} be the [track
    buffer](#track-buffer){#ref-for-track-buffer-43 .internalDFN
    link-type="dfn|abstract-op"} that will contain the splice.
2.  Let `new coded frame`{.variable} be the new [coded
    frame](#dfn-coded-frame){#ref-for-dfn-coded-frame-59 .internalDFN
    link-type="dfn|abstract-op"}, that is being added to
    `track buffer`{.variable}, which triggered the need for a splice.
3.  Let `presentation timestamp`{.variable data-type="double"} be the
    [presentation
    timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-39
    .internalDFN link-type="dfn|abstract-op"} for
    `new coded frame`{.variable}
4.  Let `decode timestamp`{.variable data-type="double"} be the decode
    timestamp for `new coded frame`{.variable}.
5.  Let `frame duration`{.variable data-type="double"} be the [coded
    frame
    duration](#dfn-coded-frame-duration){#ref-for-dfn-coded-frame-duration-11
    .internalDFN link-type="dfn|abstract-op"} of
    `new coded frame`{.variable}.
6.  Let `frame end timestamp`{.variable data-type="double"} equal the
    sum of `presentation timestamp`{.variable data-type="double"} and
    `frame duration`{.variable data-type="double"}.
7.  Let `first overlapped frame`{.variable} be the [coded
    frame](#dfn-coded-frame){#ref-for-dfn-coded-frame-60 .internalDFN
    link-type="dfn|abstract-op"} in `track buffer`{.variable} with a
    [presentation
    interval](#presentation-interval){#ref-for-presentation-interval-3
    .internalDFN link-type="dfn|abstract-op"} that contains
    `presentation timestamp`{.variable data-type="double"}.
8.  Let `overlapped presentation timestamp`{.variable
    data-type="double"} be the [presentation
    timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-40
    .internalDFN link-type="dfn|abstract-op"} of the
    `first overlapped frame`{.variable}.
9.  Let `overlapped frames`{.variable} equal
    `first overlapped frame`{.variable} as well as any additional frames
    in `track buffer`{.variable} that have a [presentation
    timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-41
    .internalDFN link-type="dfn|abstract-op"} greater than
    `presentation timestamp`{.variable data-type="double"} and less than
    `frame end timestamp`{.variable data-type="double"}.
10. Remove all the frames included in `overlapped frames`{.variable}
    from `track buffer`{.variable}.
11. Update the [coded frame
    duration](#dfn-coded-frame-duration){#ref-for-dfn-coded-frame-duration-12
    .internalDFN link-type="dfn|abstract-op"} of the
    `first overlapped frame`{.variable} to
    `presentation timestamp`{.variable data-type="double"} minus
    `overlapped presentation timestamp`{.variable data-type="double"}.
12. Add `first overlapped frame`{.variable} to the
    `track buffer`{.variable}.
13. Return to caller without providing a splice frame.

    :::: {#issue-container-generatedID-82 .note role="note"}
    ::: {#h-note-82 .note-title .marker role="heading" aria-level="5"}
    Note
    :::

    This is intended to allow `new coded frame`{.variable} to be added
    to the `track buffer`{.variable} as if it hadn\'t overlapped any
    frames in `track buffer`{.variable} to begin with.
    ::::
::::
:::::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::: {#sourcebufferlist .section}
::: header-wrapper
## 6. [`SourceBufferList`]{#dom-sourcebufferlist .dfn export="" dfn-type="interface" idl="interface" data-title="SourceBufferList" dfn-for="" tabindex="0" aria-haspopup="dialog"} interface {#x6-sourcebufferlist-interface}

[](#sourcebufferlist){.self-link aria-label="Permalink for Section 6."}
:::

[`SourceBufferList`](#dom-sourcebufferlist){#ref-for-dom-sourcebufferlist-5
.internalDFN link-type="idl" lt="SourceBufferList"} is a simple
container object for
[`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-107
.internalDFN link-type="idl"} objects. It provides read-only array
access and fires events when the list is modified.

``` {#webidl-2108728413 .idl .def}
WebIDL[Exposed=(Window,DedicatedWorker)]
interface SourceBufferList : EventTarget {
  readonly attribute unsigned long length;

  attribute EventHandler onaddsourcebuffer;
  attribute EventHandler onremovesourcebuffer;

  getter SourceBuffer (unsigned long index);
};
```

:::: {#attributes-0 .section}
::: header-wrapper
### 6.1 Attributes {#x6-1-attributes}

[](#attributes-0){.self-link aria-label="Permalink for Section 6.1"}
:::

[`length`]{#dom-sourcebufferlist-length .dfn export="" dfn-type="attribute" idl="attribute" data-title="length" dfn-for="SourceBufferList" data-type="unsigned long" lt="length" local-lt="SourceBufferList.length" tabindex="0" aria-haspopup="dialog"} of type [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long){link-type="interface" lt="unsigned long"}, readonly

:   Indicates the number of
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-109
    .internalDFN link-type="idl" lt="SourceBuffer"} objects in the list.

[`onaddsourcebuffer`]{#dom-sourcebufferlist-onaddsourcebuffer .dfn export="" dfn-type="attribute" idl="attribute" data-title="onaddsourcebuffer" dfn-for="SourceBufferList" data-type="EventHandler" lt="onaddsourcebuffer" local-lt="SourceBufferList.onaddsourcebuffer" tabindex="0" aria-haspopup="dialog"} of type [`EventHandler`](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler){link-type="typedef" lt="EventHandler"}

:   The event handler for the
    [`addsourcebuffer`](#dfn-addsourcebuffer){#ref-for-dfn-addsourcebuffer-6
    .internalDFN link-type="idl" lt="addsourcebuffer"} event.

[`onremovesourcebuffer`]{#dom-sourcebufferlist-onremovesourcebuffer .dfn export="" dfn-type="attribute" idl="attribute" data-title="onremovesourcebuffer" dfn-for="SourceBufferList" data-type="EventHandler" lt="onremovesourcebuffer" local-lt="SourceBufferList.onremovesourcebuffer" tabindex="0" aria-haspopup="dialog"} of type [`EventHandler`](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler){link-type="typedef" lt="EventHandler"}

:   The event handler for the
    [`removesourcebuffer`](#dfn-removesourcebuffer){#ref-for-dfn-removesourcebuffer-8
    .internalDFN link-type="idl" lt="removesourcebuffer"} event.
::::

:::: {#methods-0 .section}
::: header-wrapper
### 6.2 Methods {#x6-2-methods}

[](#methods-0){.self-link aria-label="Permalink for Section 6.2"}
:::

[getter]{#dfn-sourcebufferlist-getter .dfn .respec-offending-element lt-nodefault="" lt="sourcebufferlist-getter" tabindex="0" aria-haspopup="dialog" dfn-type="dfn" title="Found definition for \"getter\", but nothing links to it. This is usually a spec bug!"}

:   Allows the SourceBuffer objects in the list to be accessed with an
    array operator (i.e., \[\]).

    When this method is invoked, the user agent must run the following
    steps:

    1.  If `index`{.variable data-type="unsigned long"} is greater than
        or equal to the
        [`length`](#dom-sourcebufferlist-length){#ref-for-dom-sourcebufferlist-length-2
        .internalDFN link-type="idl"} attribute then return undefined
        and abort these steps.
    2.  Return the `index`{.variable data-type="unsigned long"}\'th
        [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-110
        .internalDFN link-type="idl" lt="SourceBuffer"} object in the
        list.
::::

:::: {#sourcebufferlist-events .section}
::: header-wrapper
### 6.3 Event Summary {#x6-3-event-summary}

[](#sourcebufferlist-events){.self-link
aria-label="Permalink for Section 6.3"}
:::

  Event name                                                                                                                 Interface                                                                         Dispatched when\...
  -------------------------------------------------------------------------------------------------------------------------- --------------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------
  [addsourcebuffer]{#dfn-addsourcebuffer .dfn .event dfn-type="event" tabindex="0" aria-haspopup="dialog" export=""}         [`Event`](https://dom.spec.whatwg.org/#event){link-type="interface" lt="Event"}   When a [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-111 .internalDFN link-type="idl" lt="SourceBuffer"} is added to the list.
  [removesourcebuffer]{#dfn-removesourcebuffer .dfn .event dfn-type="event" tabindex="0" aria-haspopup="dialog" export=""}   [`Event`](https://dom.spec.whatwg.org/#event){link-type="interface" lt="Event"}   When a [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-112 .internalDFN link-type="idl" lt="SourceBuffer"} is removed from the list.
::::
::::::::::

:::::::::::::::: {#managedmediasource-interface .section data-cite="WEBIDL mimesniff" dfn-for="ManagedMediaSource"}
::: header-wrapper
## 7. [`ManagedMediaSource`]{#dom-managedmediasource .dfn export="" dfn-type="interface" idl="interface" data-title="ManagedMediaSource" dfn-for="" tabindex="0" aria-haspopup="dialog"} interface {#x7-managedmediasource-interface}

[](#managedmediasource-interface){.self-link
aria-label="Permalink for Section 7."}
:::

A
[`ManagedMediaSource`](#dom-managedmediasource){#ref-for-dom-managedmediasource-4
.internalDFN link-type="idl" lt="ManagedMediaSource"} is a
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-99
.internalDFN link-type="idl" lt="MediaSource"} that actively manages its
memory content. Unlike a
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-100
.internalDFN link-type="idl" lt="MediaSource"}, the [user
agent](https://infra.spec.whatwg.org/#user-agent){link-type="dfn"} can
evict content through the [memory
cleanup](#dfn-memory-cleanup){#ref-for-dfn-memory-cleanup-1 .internalDFN
link-type="dfn|abstract-op"} algorithm from its
[`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-32
.internalDFN link-type="idl"} (populated with
[`ManagedSourceBuffer`](#dom-managedsourcebuffer){#ref-for-dom-managedsourcebuffer-3
.internalDFN link-type="idl" lt="ManagedSourceBuffer"}) for any reason.

:::: {#issue-container-generatedID-83 .note role="note"}
::: {#h-note-83 .note-title .marker role="heading" aria-level="3"}
Note[: Eviction reasons]{.issue-label}
:::

Reasons that the user agent might evict content are implementation
specific and can include, but are not limited to, memory and/or hardware
limitations, change in environmental conditions, and so on. Developers
shouldn\'t make assumptions as to why, how, or when a user agent might
evict content. Instead, developers need to write scripts with the
assumption that content is constantly and randomly being evicted to
avoid stalled video playback (i.e., code defensibly and listen for the
[`bufferedchange`](#dfn-bufferedchange){#ref-for-dfn-bufferedchange-1
.internalDFN link-type="idl" lt="bufferedchange"} event!).
::::

``` {#webidl-1619111096 .idl .def}
WebIDL[Exposed=(Window,DedicatedWorker)]
interface ManagedMediaSource : MediaSource {
  constructor();
  readonly attribute boolean streaming;
  attribute EventHandler onstartstreaming;
  attribute EventHandler onendstreaming;
};
```

:::: {#attributes-1 .section}
::: header-wrapper
### 7.1 Attributes {#x7-1-attributes}

[](#attributes-1){.self-link aria-label="Permalink for Section 7.1"}
:::

[`streaming`]{#dom-managedmediasource-streaming .dfn export="" dfn-type="attribute" idl="attribute" data-title="streaming" dfn-for="ManagedMediaSource" data-type="boolean" lt="streaming" local-lt="ManagedMediaSource.streaming" tabindex="0" aria-haspopup="dialog"}

:   On getting:

    1.  Return the current value of the attribute.
::::

:::: {#event-summary .section}
::: header-wrapper
### 7.2 Event Summary {#x7-2-event-summary}

[](#event-summary){.self-link aria-label="Permalink for Section 7.2"}
:::

  Event name                                                                                                         Interface                                                                         Dispatched when\...
  ------------------------------------------------------------------------------------------------------------------ --------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  [startstreaming]{#dfn-startstreaming .dfn .event dfn-type="event" tabindex="0" aria-haspopup="dialog" export=""}   [`Event`](https://dom.spec.whatwg.org/#event){link-type="interface" lt="Event"}   A [`ManagedMediaSource`](#dom-managedmediasource){#ref-for-dom-managedmediasource-6 .internalDFN link-type="idl" lt="ManagedMediaSource"}\'s [`streaming`](#dom-managedmediasource-streaming){#ref-for-dom-managedmediasource-streaming-3 .internalDFN link-type="idl"} attribute changed from `false` to `true`.
  [endstreaming]{#dfn-endstreaming .dfn .event dfn-type="event" tabindex="0" aria-haspopup="dialog" export=""}       [`Event`](https://dom.spec.whatwg.org/#event){link-type="interface" lt="Event"}   A [`ManagedMediaSource`](#dom-managedmediasource){#ref-for-dom-managedmediasource-7 .internalDFN link-type="idl" lt="ManagedMediaSource"}\'s [`streaming`](#dom-managedmediasource-streaming){#ref-for-dom-managedmediasource-streaming-4 .internalDFN link-type="idl"} attribute changed from `true` to `false`.
::::

:::::::: {#algorithms .section}
::: header-wrapper
### 7.3 Algorithms {#x7-3-algorithms}

[](#algorithms){.self-link aria-label="Permalink for Section 7.3"}
:::

:::: {#managedsourcebuffer-monitoring .section}
::: header-wrapper
#### 7.3.1 `ManagedSourceBuffer` Monitoring {#x7-3-1-managedsourcebuffer-monitoring}

[](#managedsourcebuffer-monitoring){.self-link
aria-label="Permalink for Section 7.3.1"}
:::

The following steps are run periodically, whenever the [SourceBuffer
Monitoring](#dfn-sourcebuffer-monitoring){#ref-for-dfn-sourcebuffer-monitoring-1
.internalDFN link-type="dfn|abstract-op"} algorithm is scheduled to run.

Having [enough managed data to ensure uninterrupted
playback]{#dfn-enough-managed-data-to-ensure-uninterrupted-playback .dfn
tabindex="0" aria-haspopup="dialog" dfn-type="dfn"} is an implementation
defined condition where the user agent determines that it currently has
enough data to play the presentation without stalling for a meaningful
period of time. This condition is constantly evaluated to determine when
to transition the value of
[`streaming`](#dom-managedmediasource-streaming){#ref-for-dom-managedmediasource-streaming-5
.internalDFN link-type="idl"}. These transitions indicate when the user
agent believes it has enough data buffered or it needs more data
respectively.

Being [able to retrieve and buffer data in an efficient
way]{#dfn-able-to-retrieve-and-buffer-data-in-an-efficient-way .dfn
tabindex="0" aria-haspopup="dialog" dfn-type="dfn"} is an implementation
defined condition where the user agent determines that it can fetch new
data in an energy efficient manner while able to achieve the desired
memory usage.

1.  Run the
    [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-102
    .internalDFN link-type="idl" lt="MediaSource"} [SourceBuffer
    Monitoring](#dfn-sourcebuffer-monitoring){#ref-for-dfn-sourcebuffer-monitoring-2
    .internalDFN link-type="dfn|abstract-op"} algorithm.
2.  Let `can play uninterrupted and efficiently`{.variable} be a flag
    that is true if the
    [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered){link-type="attribute"}
    attribute contains a
    [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface"
    lt="TimeRanges"} that includes the current playback position and
    [enough managed data to ensure uninterrupted
    playback](#dfn-enough-managed-data-to-ensure-uninterrupted-playback){#ref-for-dfn-enough-managed-data-to-ensure-uninterrupted-playback-1
    .internalDFN link-type="dfn|abstract-op"} and is [able to retrieve
    and buffer data in an efficient
    way](#dfn-able-to-retrieve-and-buffer-data-in-an-efficient-way){#ref-for-dfn-able-to-retrieve-and-buffer-data-in-an-efficient-way-1
    .internalDFN link-type="dfn|abstract-op"}

    If `can play uninterrupted and efficiently`{.variable} is not equal to [`streaming`](#dom-managedmediasource-streaming){#ref-for-dom-managedmediasource-streaming-6 .internalDFN link-type="idl"}, [queue an element task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-an-element-task){link-type="dfn"} on the [media element](https://html.spec.whatwg.org/multipage/media.html#media-element){link-type="dfn"} that runs the following steps:

    :   1.  Set
            [this](https://webidl.spec.whatwg.org/#this){link-type="dfn"}
            [`streaming`](#dom-managedmediasource-streaming){#ref-for-dom-managedmediasource-streaming-7
            .internalDFN link-type="idl"} attribute to
            `can play uninterrupted and efficiently`{.variable}.
        2.  If `can play uninterrupted and efficiently`{.variable} is
            false [fire an
            event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
            called
            [`startstreaming`](#dfn-startstreaming){#ref-for-dfn-startstreaming-1
            .internalDFN link-type="idl" lt="startstreaming"} at the
            [`ManagedMediaSource`](#dom-managedmediasource){#ref-for-dom-managedmediasource-8
            .internalDFN link-type="idl" lt="ManagedMediaSource"}.
        3.  Otherwise, [fire an
            event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
            called
            [`endstreaming`](#dfn-endstreaming){#ref-for-dfn-endstreaming-1
            .internalDFN link-type="idl" lt="endstreaming"} at the
            [`ManagedMediaSource`](#dom-managedmediasource){#ref-for-dom-managedmediasource-9
            .internalDFN link-type="idl" lt="ManagedMediaSource"}.
::::

:::: {#memory-cleanup .section}
::: header-wrapper
#### 7.3.2 [Memory Cleanup]{#dfn-memory-cleanup .dfn dfn-for="ManagedMediaSource" tabindex="0" aria-haspopup="dialog" dfn-type="dfn"} {#x7-3-2-memory-cleanup}

[](#memory-cleanup){.self-link aria-label="Permalink for Section 7.3.2"}
:::

1.  

    For each `buffer`{.variable data-type="ManagedSourceBuffer"} in [this](https://webidl.spec.whatwg.org/#this){link-type="dfn"}\'s [`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-33 .internalDFN link-type="idl"}:

    :   1.  Run the `buffer`{.variable
            data-type="ManagedSourceBuffer"}\'s [memory
            cleanup](#dfn-memory-cleanup-0){#ref-for-dfn-memory-cleanup-0-1
            .internalDFN link-type="dfn|abstract-op"} algorithm.
::::
::::::::
::::::::::::::::

:::::: {#bufferedchangeevent-interface .section dfn-for="BufferedChangeEvent"}
::: header-wrapper
## 8. [`BufferedChangeEvent`]{#dom-bufferedchangeevent .dfn export="" dfn-type="interface" idl="interface" data-title="BufferedChangeEvent" dfn-for="" tabindex="0" aria-haspopup="dialog"} interface {#x8-bufferedchangeevent-interface}

[](#bufferedchangeevent-interface){.self-link
aria-label="Permalink for Section 8."}
:::

``` {#webidl-2057880103 .idl .def}
WebIDL[Exposed=(Window,DedicatedWorker)]
interface BufferedChangeEvent : Event {
  constructor(DOMString type, optional BufferedChangeEventInit eventInitDict = {});

  [SameObject] readonly attribute TimeRanges addedRanges;
  [SameObject] readonly attribute TimeRanges removedRanges;
};

dictionary BufferedChangeEventInit : EventInit {
  TimeRanges addedRanges;
  TimeRanges removedRanges;
};
```

:::: {#attributes-2 .section}
::: header-wrapper
### 8.1 Attributes {#x8-1-attributes}

[](#attributes-2){.self-link aria-label="Permalink for Section 8.1"}
:::

[`addedRanges`]{#dom-bufferedchangeevent-addedranges .dfn export="" dfn-type="attribute" idl="attribute" data-title="addedRanges" dfn-for="BufferedChangeEvent" data-type="TimeRanges" lt="addedRanges" local-lt="BufferedChangeEvent.addedRanges" tabindex="0" aria-haspopup="dialog"}
:   The time ranges added between the last
    [`updatestart`](#dfn-updatestart){#ref-for-dfn-updatestart-4
    .internalDFN link-type="idl" lt="updatestart"} and
    [`updateend`](#dfn-updateend){#ref-for-dfn-updateend-7 .internalDFN
    link-type="idl" lt="updateend"} events (which would have occurred
    during the last run of the [coded frame
    processing](#dfn-coded-frame-processing){#ref-for-dfn-coded-frame-processing-13
    .internalDFN link-type="dfn|abstract-op"} algorithm).

[`removedRanges`]{#dom-bufferedchangeevent-removedranges .dfn export="" dfn-type="attribute" idl="attribute" data-title="removedRanges" dfn-for="BufferedChangeEvent" data-type="TimeRanges" lt="removedRanges" local-lt="BufferedChangeEvent.removedRanges" tabindex="0" aria-haspopup="dialog"}
:   The time ranges removed between the last `updatestart` and
    `updateend` events (which would have occurred during the last run of
    the [coded frame
    removal](#dfn-coded-frame-removal){#ref-for-dfn-coded-frame-removal-5
    .internalDFN link-type="dfn|abstract-op"} or [coded frame
    eviction](#dfn-coded-frame-eviction){#ref-for-dfn-coded-frame-eviction-2
    .internalDFN link-type="dfn|abstract-op"} algorithm or if the user
    agent evicted content in response to a [memory
    cleanup](#dfn-memory-cleanup-0){#ref-for-dfn-memory-cleanup-0-2
    .internalDFN link-type="dfn|abstract-op"}).
::::
::::::

:::::::::::::: {#managedsourcebuffer-interface .section}
::: header-wrapper
## 9. [`ManagedSourceBuffer`]{#dom-managedsourcebuffer .dfn export="" dfn-type="interface" idl="interface" data-title="ManagedSourceBuffer" dfn-for="" tabindex="0" aria-haspopup="dialog"} interface {#x9-managedsourcebuffer-interface}

[](#managedsourcebuffer-interface){.self-link
aria-label="Permalink for Section 9."}
:::

``` {#webidl-1682162223 .idl .def}
WebIDL[Exposed=(Window,DedicatedWorker)]
interface ManagedSourceBuffer : SourceBuffer {
  attribute EventHandler onbufferedchange;
};
```

:::: {#attributes-3 .section}
::: header-wrapper
### 9.1 Attributes {#x9-1-attributes}

[](#attributes-3){.self-link aria-label="Permalink for Section 9.1"}
:::

[`onbufferedchange`]{#dom-managedsourcebuffer-onbufferedchange .dfn export="" dfn-type="attribute" idl="attribute" data-title="onbufferedchange" dfn-for="ManagedSourceBuffer" data-type="EventHandler" lt="onbufferedchange" local-lt="ManagedSourceBuffer.onbufferedchange" tabindex="0" aria-haspopup="dialog"}

:   An [event handler IDL
    attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes){link-type="dfn"}
    whose [event handler event
    type](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-event-type){link-type="dfn"}
    is
    [`bufferedchange`](#dfn-bufferedchange){#ref-for-dfn-bufferedchange-2
    .internalDFN link-type="idl" lt="bufferedchange"}.
::::

:::: {#event-summary-0 .section}
::: header-wrapper
### 9.2 Event Summary {#x9-2-event-summary}

[](#event-summary-0){.self-link aria-label="Permalink for Section 9.2"}
:::

  Event name                                                                                                         Interface                                                                                                                                     Dispatched when\...
  ------------------------------------------------------------------------------------------------------------------ --------------------------------------------------------------------------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  [bufferedchange]{#dfn-bufferedchange .dfn .event dfn-type="event" tabindex="0" aria-haspopup="dialog" export=""}   [`BufferedChangeEvent`](#dom-bufferedchangeevent){#ref-for-dom-bufferedchangeevent-3 .internalDFN link-type="idl" lt="BufferedChangeEvent"}   The [`ManagedSourceBuffer`](#dom-managedsourcebuffer){#ref-for-dom-managedsourcebuffer-5 .internalDFN link-type="idl" lt="ManagedSourceBuffer"}\'s buffered range changed following a call to [`appendBuffer`](#dom-sourcebuffer-appendbuffer){#ref-for-dom-sourcebuffer-appendbuffer-10 .internalDFN link-type="idl" lt="appendBuffer()"}`()`, [`remove`](#dom-sourcebuffer-remove){#ref-for-dom-sourcebuffer-remove-5 .internalDFN link-type="idl" lt="remove()"}`()`, [`endOfStream`](#dom-mediasource-endofstream){#ref-for-dom-mediasource-endofstream-5 .internalDFN link-type="idl" lt="endOfStream()"}`()`, or as a consequence of the user agent running the [memory cleanup](#dfn-memory-cleanup-0){#ref-for-dfn-memory-cleanup-0-3 .internalDFN link-type="dfn|abstract-op"} algorithm.
::::

:::::::: {#algorithms-0 .section}
::: header-wrapper
### 9.3 Algorithms {#x9-3-algorithms}

[](#algorithms-0){.self-link aria-label="Permalink for Section 9.3"}
:::

:::: {#buffered-change .section}
::: header-wrapper
#### 9.3.1 Buffered Change {#x9-3-1-buffered-change}

[](#buffered-change){.self-link
aria-label="Permalink for Section 9.3.1"}
:::

The following steps are run at the completion of all operations to the
[`ManagedSourceBuffer`](#dom-managedsourcebuffer){#ref-for-dom-managedsourcebuffer-6
.internalDFN link-type="idl" lt="ManagedSourceBuffer"}
`buffer`{.variable data-type="ManagedSourceBuffer"} that would cause a
`buffer`{.variable data-type="ManagedSourceBuffer"}\'s
[`buffered`](#dom-sourcebuffer-buffered){#ref-for-dom-sourcebuffer-buffered-5
.internalDFN link-type="idl"} to change. That is once
[`appendBuffer`](#dom-sourcebuffer-appendbuffer){#ref-for-dom-sourcebuffer-appendbuffer-11
.internalDFN link-type="idl" lt="appendBuffer()"}`()`,
[`remove`](#dom-sourcebuffer-remove){#ref-for-dom-sourcebuffer-remove-6
.internalDFN link-type="idl" lt="remove()"}`()` or [memory
cleanup](#dfn-memory-cleanup-0){#ref-for-dfn-memory-cleanup-0-4
.internalDFN link-type="dfn|abstract-op"} algorithm have completed.

1.  Let `previous buffered ranges`{.variable
    data-type="normalized TimeRanges"} equal the
    [`buffered`](#dom-sourcebuffer-buffered){#ref-for-dom-sourcebuffer-buffered-6
    .internalDFN link-type="idl"} attribute before the changes occurred.
2.  Let `new buffered ranges`{.variable
    data-type="normalized TimeRanges"} equal the new
    [`buffered`](#dom-sourcebuffer-buffered){#ref-for-dom-sourcebuffer-buffered-7
    .internalDFN link-type="idl"}
    [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface"
    lt="TimeRanges"}.
3.  Let `added`{.variable data-type="normalized TimeRanges"} equal the
    `previous buffered ranges`{.variable data-type="normalized
            TimeRanges"} subtracted from `new buffered ranges`{.variable
    data-type="normalized TimeRanges"}.
4.  Let `removed`{.variable data-type="normalized TimeRanges"} equal the
    `new buffered ranges`{.variable data-type="normalized
            TimeRanges"} subtracted from
    `previous buffered ranges`{.variable
    data-type="normalized TimeRanges"}.
5.  Let `eventInitDict`{.variable} be a new
    [`BufferedChangeEventInit`](#dom-bufferedchangeeventinit){#ref-for-dom-bufferedchangeeventinit-2
    .internalDFN link-type="idl" lt="BufferedChangeEventInit"}
    dictionary initialized with `added`{.variable
    data-type="normalized TimeRanges"} as its
    [`addedRanges`](#dom-bufferedchangeeventinit-addedranges){#ref-for-dom-bufferedchangeeventinit-addedranges-1
    .internalDFN link-type="idl"} and `removed`{.variable
    data-type="normalized TimeRanges"} as its
    [`removedRanges`](#dom-bufferedchangeeventinit-removedranges){#ref-for-dom-bufferedchangeeventinit-removedranges-1
    .internalDFN link-type="idl"}
6.  [Queue a
    task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){link-type="dfn"}
    to [fire an
    event](https://dom.spec.whatwg.org/#concept-event-fire){link-type="dfn"}
    named
    [`bufferedchange`](#dfn-bufferedchange){#ref-for-dfn-bufferedchange-3
    .internalDFN link-type="idl" lt="bufferedchange"} at
    `buffer`{.variable data-type="ManagedSourceBuffer"} using the
    [`BufferedChangeEvent`](#dom-bufferedchangeevent){#ref-for-dom-bufferedchangeevent-4
    .internalDFN link-type="idl" lt="BufferedChangeEvent"} interface,
    initialized with `eventInitDict`{.variable}.
::::

:::: {#memory-cleanup-0 .section}
::: header-wrapper
#### 9.3.2 [Memory cleanup]{#dfn-memory-cleanup-0 .dfn dfn-for="ManagedSourceBuffer" tabindex="0" aria-haspopup="dialog" dfn-type="dfn"} {#x9-3-2-memory-cleanup}

[](#memory-cleanup-0){.self-link
aria-label="Permalink for Section 9.3.2"}
:::

1.  

    If [this](https://webidl.spec.whatwg.org/#this){link-type="dfn"} is not in [this](https://webidl.spec.whatwg.org/#this){link-type="dfn"}\'s [`ManagedMediaSource`](#dom-managedmediasource){#ref-for-dom-managedmediasource-10 .internalDFN link-type="idl" lt="ManagedMediaSource"} parent [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-31 .internalDFN link-type="idl"}:

    :   1.  Run the [coded frame
            removal](#dfn-coded-frame-removal){#ref-for-dfn-coded-frame-removal-6
            .internalDFN link-type="dfn|abstract-op"} algorithm with
            start set to 0, end set to positive infinity, and abort
            these steps.

2.  Let `removal ranges`{.variable data-type="normalized TimeRanges"}
    equal a list of presentation time ranges that can be evicted from
    the presentation to ensure uninterrupted playback from
    [`currentTime`](https://html.spec.whatwg.org/multipage/media.html#dom-media-currenttime){link-type="attribute"}
    until such presentation could be retrieved again.

    :::: {#issue-container-generatedID-84 .note role="note"}
    ::: {#h-note-84 .note-title .marker role="heading" aria-level="3"}
    Note
    :::

    Implementations can use different strategies for selecting
    `removal ranges`{.variable data-type="normalized TimeRanges"} so web
    applications shouldn\'t depend on a specific behavior. The web
    application would listen to the
    [`bufferedchange`](#dfn-bufferedchange){#ref-for-dfn-bufferedchange-4
    .internalDFN link-type="idl" lt="bufferedchange"} event to observe
    whether portions of the buffered data have been evicted.
    ::::

3.  For each range in `removal ranges`{.variable
    data-type="normalized TimeRanges"}, run the [coded frame
    removal](#dfn-coded-frame-removal){#ref-for-dfn-coded-frame-removal-7
    .internalDFN link-type="dfn|abstract-op"} algorithm with
    `start`{.variable data-type="double"} and `end`{.variable
    data-type="unrestricted double"} equal to the removal range start
    and end timestamp respectively.
::::
::::::::
::::::::::::::

:::::::::::::: {#htmlmediaelement-extensions .section}
::: header-wrapper
## 10. HTMLMediaElement Extensions {#x10-htmlmediaelement-extensions}

[](#htmlmediaelement-extensions){.self-link
aria-label="Permalink for Section 10."}
:::

This section specifies what existing
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"}\'s
[`seekable`](https://html.spec.whatwg.org/multipage/media.html#dom-media-seekable){link-type="attribute"}
and
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"}\'s
[`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered){link-type="attribute"}
attributes on the
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"} *MUST* return when a
[`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-103
.internalDFN link-type="idl" lt="MediaSource"} is attached to the
element, and what the existing
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"}\'s
[`srcObject`](https://html.spec.whatwg.org/multipage/media.html#dom-media-srcobject){link-type="attribute"}
attribute *MUST* also do when it is set to be a
[`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-29
.internalDFN link-type="idl" lt="MediaSourceHandle"} object.

:::: {#htmlmediaelement-extensions-seekable .section}
::: header-wrapper
### 10.1 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface" lt="HTMLMediaElement"}\'s [`seekable`](https://html.spec.whatwg.org/multipage/media.html#dom-media-seekable){link-type="attribute"} {#x10-1-htmlmediaelement-s-seekable}

[](#htmlmediaelement-extensions-seekable){.self-link
aria-label="Permalink for Section 10.1"}
:::

The
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"}\'s
[`seekable`](https://html.spec.whatwg.org/multipage/media.html#dom-media-seekable){link-type="attribute"}
attribute returns a new static [normalized TimeRanges
object](https://html.spec.whatwg.org/multipage/media.html#normalised-timeranges-object)
created based on the following steps:

1.  If the
    [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-104
    .internalDFN link-type="idl" lt="MediaSource"} was constructed in a
    [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
    lt="DedicatedWorkerGlobalScope"} that is terminated or is closing
    then return an empty
    [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface"
    lt="TimeRanges"} object and abort these steps.

    :::: {#issue-container-generatedID-85 .note role="note"}
    ::: {#h-note-85 .note-title .marker role="heading" aria-level="4"}
    Note
    :::

    This case is intended to handle implementations that may no longer
    maintain any previous information about buffered or seekable media
    in a MediaSource that was constructed in a
    DedicatedWorkerGlobalScope that has been terminated by
    [`terminate`](https://html.spec.whatwg.org/multipage/workers.html#dom-worker-terminate){link-type="method"
    lt="terminate()"}`()` or user agent execution of [terminate a
    worker](https://html.spec.whatwg.org/multipage/workers.html#terminate-a-worker){link-type="dfn"}
    for the MediaSource\'s DedicatedWorkerGlobalScope, for instance as
    the eventual result of
    [`close`](https://html.spec.whatwg.org/multipage/workers.html#dom-dedicatedworkerglobalscope-close){link-type="method"
    lt="close()"}`()` execution.
    ::::

    ::::: {#issue-container-number-277 .issue}
    ::: {#h-issue-2 .issue-title .marker role="heading" aria-level="4"}
    [[Issue
    277]{.issue-number}](https://github.com/w3c/media-source/issues/277)[:
    MSE-in-Workers: Consider (eventually) transitioning attached element
    to error upon termination of MediaSource\'s worker/what should media
    element do?
    [mse-in-workers](https://github.com/w3c/media-source/issues/?q=is%3Aissue+is%3Aopen+label%3A%22mse-in-workers%22){.respec-gh-label
    style="background-color: rgb(170, 170, 170); color: rgb(0, 0, 0);"
    aria-label="GitHub label: mse-in-workers"}]{.issue-label}
    :::

    ::: {}
    Should there be some (eventual) media element error transition in
    the case of an attached worker MediaSource having its context
    destroyed? The experimental Chromium implementation of worker MSE
    just keeps the element readyState, networkState and error the same
    as prior to that context destruction, though the seekable and
    buffered attributes each report an empty TimeRange.
    :::
    :::::

2.  Let `recent duration`{.variable data-type="unrestricted double"} and
    `recent live seekable range`{.variable data-type="normalized
              TimeRanges"} respectively be the recent values of
    [`duration`](#dom-mediasource-duration){#ref-for-dom-mediasource-duration-12
    .internalDFN link-type="idl"} and
    [`[[live seekable range]]`](#dfn-live-seekable-range){#ref-for-dfn-live-seekable-range-6
    .internalDFN link-type="attribute" lt="[[live seekable range]]"},
    determined as follows:

    If the [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-105 .internalDFN link-type="idl" lt="MediaSource"} was constructed in a [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface" lt="Window"}
    :   Set `recent duration`{.variable data-type="unrestricted double"}
        to be
        [`duration`](#dom-mediasource-duration){#ref-for-dom-mediasource-duration-13
        .internalDFN link-type="idl"} and set
        `recent live seekable range`{.variable} to be
        [`[[live seekable range]]`](#dfn-live-seekable-range){#ref-for-dfn-live-seekable-range-7
        .internalDFN link-type="attribute"
        lt="[[live seekable range]]"}.

    Otherwise:
    :   Set `recent duration`{.variable data-type="unrestricted double"}
        and `recent live seekable range`{.variable data-type="normalized
                  TimeRanges"} respectively to be what the
        [`duration`](#dom-mediasource-duration){#ref-for-dom-mediasource-duration-14
        .internalDFN link-type="idl"} and
        [`[[live seekable range]]`](#dfn-live-seekable-range){#ref-for-dfn-live-seekable-range-8
        .internalDFN link-type="attribute" lt="[[live seekable range]]"}
        were recently, updated by handling implicit messages posted by
        the
        [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-106
        .internalDFN link-type="idl" lt="MediaSource"} to its
        [`[[port to main]]`](#dfn-port-to-main){#ref-for-dfn-port-to-main-10
        .internalDFN link-type="attribute" lt="[[port to main]]"} on
        every change to
        [`duration`](#dom-mediasource-duration){#ref-for-dom-mediasource-duration-15
        .internalDFN link-type="idl"} or
        [`[[live seekable range]]`](#dfn-live-seekable-range){#ref-for-dfn-live-seekable-range-9
        .internalDFN link-type="attribute"
        lt="[[live seekable range]]"}.

3.  

    If `recent duration`{.variable data-type="unrestricted double"} equals NaN:
    :   Return an empty
        [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface"
        lt="TimeRanges"} object.

    If `recent duration`{.variable data-type="unrestricted double"} equals positive Infinity:

    :   1.  If `recent live seekable range`{.variable
            data-type="normalized
                      TimeRanges"} is not empty:
            1.  Let `union ranges`{.variable
                data-type="normalized TimeRanges"} be the union of
                `recent live seekable range`{.variable} and the
                [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
                lt="HTMLMediaElement"}\'s
                [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered){link-type="attribute"}
                attribute.
            2.  Return a single range with a start time equal to the
                earliest start time in `union ranges`{.variable
                data-type="normalized TimeRanges"} and an end time equal
                to the highest end time in `union ranges`{.variable} and
                abort these steps.
        2.  If the
            [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
            lt="HTMLMediaElement"}\'s
            [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered){link-type="attribute"}
            attribute returns an empty
            [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface"
            lt="TimeRanges"} object, then return an empty
            [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface"
            lt="TimeRanges"} object and abort these steps.
        3.  Return a single range with a start time of 0 and an end time
            equal to the highest end time reported by the
            [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
            lt="HTMLMediaElement"}\'s
            [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered){link-type="attribute"}
            attribute.

    Otherwise:
    :   Return a single range with a start time of 0 and an end time
        equal to `recent duration`{.variable}.
::::

:::: {#htmlmediaelement-extensions-buffered .section}
::: header-wrapper
### 10.2 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface" lt="HTMLMediaElement"}\'s [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered){link-type="attribute"} {#x10-2-htmlmediaelement-s-buffered}

[](#htmlmediaelement-extensions-buffered){.self-link
aria-label="Permalink for Section 10.2"}
:::

The
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"}\'s
[`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered){link-type="attribute"}
attribute returns a static [normalized TimeRanges
object](https://html.spec.whatwg.org/multipage/media.html#normalised-timeranges-object)
based on the following steps.

1.  If the
    [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-107
    .internalDFN link-type="idl" lt="MediaSource"} was constructed in a
    [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
    lt="DedicatedWorkerGlobalScope"} that is terminated or is closing
    then return an empty
    [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface"
    lt="TimeRanges"} object and abort these steps.

    :::: {#issue-container-generatedID-86 .note role="note"}
    ::: {#h-note-86 .note-title .marker role="heading" aria-level="4"}
    Note
    :::

    This case is intended to handle implementations that may no longer
    maintain any previous information about buffered or seekable media
    in a MediaSource that was constructed in a
    DedicatedWorkerGlobalScope that has been terminated by
    [`terminate`](https://html.spec.whatwg.org/multipage/workers.html#dom-worker-terminate){link-type="method"
    lt="terminate()"}`()` or user agent execution of [terminate a
    worker](https://html.spec.whatwg.org/multipage/workers.html#terminate-a-worker){link-type="dfn"}
    for the MediaSource\'s DedicatedWorkerGlobalScope, for instance as
    the eventual result of
    [`close`](https://html.spec.whatwg.org/multipage/workers.html#dom-dedicatedworkerglobalscope-close){link-type="method"
    lt="close()"}`()` execution.
    ::::

    ::::: {#issue-container-number-277-0 .issue}
    ::: {#h-issue-3 .issue-title .marker role="heading" aria-level="4"}
    [[Issue
    277]{.issue-number}](https://github.com/w3c/media-source/issues/277)[:
    MSE-in-Workers: Consider (eventually) transitioning attached element
    to error upon termination of MediaSource\'s worker/what should media
    element do?
    [mse-in-workers](https://github.com/w3c/media-source/issues/?q=is%3Aissue+is%3Aopen+label%3A%22mse-in-workers%22){.respec-gh-label
    style="background-color: rgb(170, 170, 170); color: rgb(0, 0, 0);"
    aria-label="GitHub label: mse-in-workers"}]{.issue-label}
    :::

    ::: {}
    Should there be some (eventual) media element error transition in
    the case of an attached worker MediaSource having its context
    destroyed? The experimental Chromium implementation of worker MSE
    just keeps the element readyState, networkState and error the same
    as prior to that context destruction, though the seekable and
    buffered attributes each report an empty TimeRange.
    :::
    :::::
2.  Let `recent intersection ranges`{.variable
    data-type="normalized TimeRanges"} be determined as follows:

    If the [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-108 .internalDFN link-type="idl" lt="MediaSource"} was constructed in a [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface" lt="Window"}

    :   1.  Let `recent intersection ranges`{.variable
            data-type="normalized TimeRanges"} equal an empty
            [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface"
            lt="TimeRanges"} object.
        2.  If
            [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-32
            .internalDFN link-type="idl"}.length does not equal 0 then
            run the following steps:
            1.  Let `active ranges`{.variable
                data-type="sequence of normalized TimeRanges"} be the
                ranges returned by
                [`buffered`](#dom-sourcebuffer-buffered){#ref-for-dom-sourcebuffer-buffered-8
                .internalDFN link-type="idl"} for each
                [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-114
                .internalDFN link-type="idl" lt="SourceBuffer"} object
                in
                [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-33
                .internalDFN link-type="idl"}.
            2.  Let `highest end time`{.variable
                data-type="unrestricted double"} be the largest range
                end time in the `active ranges`{.variable
                data-type="sequence of normalized TimeRanges"}.
            3.  Let `recent intersection ranges`{.variable
                data-type="normalized TimeRanges"} equal a
                [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface"
                lt="TimeRanges"} object containing a single range from 0
                to `highest end time`{.variable
                data-type="unrestricted double"}.
            4.  For each
                [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-115
                .internalDFN link-type="idl" lt="SourceBuffer"} object
                in
                [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-34
                .internalDFN link-type="idl"} run the following steps:
                1.  Let `source ranges`{.variable
                    data-type="normalized TimeRanges"} equal the ranges
                    returned by the
                    [`buffered`](#dom-sourcebuffer-buffered){#ref-for-dom-sourcebuffer-buffered-9
                    .internalDFN link-type="idl"} attribute on the
                    current
                    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-116
                    .internalDFN link-type="idl" lt="SourceBuffer"}.
                2.  If
                    [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-35
                    .internalDFN link-type="idl"} is
                    \"[`ended`](#dom-readystate-ended){#ref-for-dom-readystate-ended-14
                    .internalDFN link-type="idl"}\", then set the end
                    time on the last range in `source ranges`{.variable
                    data-type="normalized TimeRanges"} to
                    `highest end time`{.variable
                    data-type="unrestricted double"}.
                3.  Let `new intersection ranges`{.variable
                    data-type="normalized TimeRanges"} equal the
                    intersection between the
                    `recent intersection ranges`{.variable
                    data-type="normalized TimeRanges"} and the
                    `source ranges`{.variable}.
                4.  Replace the ranges in
                    `recent intersection ranges`{.variable
                    data-type="normalized TimeRanges"} with the
                    `new intersection ranges`{.variable}.

    Otherwise:
    :   Let `recent intersection ranges`{.variable
        data-type="normalized TimeRanges"} be the
        [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges){link-type="interface"
        lt="TimeRanges"} resulting from the steps for the
        [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
        lt="Window"} case, but run with the
        [`MediaSource`](#dom-mediasource){#ref-for-dom-mediasource-109
        .internalDFN link-type="idl" lt="MediaSource"} and its
        [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-117
        .internalDFN link-type="idl" lt="SourceBuffer"} objects in their
        [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
        lt="DedicatedWorkerGlobalScope"} and communicated by using
        [`[[port to main]]`](#dfn-port-to-main){#ref-for-dfn-port-to-main-11
        .internalDFN link-type="attribute" lt="[[port to main]]"}
        implicit messages on every update to the
        [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-35
        .internalDFN link-type="idl"},
        [`readyState`](#dom-mediasource-readystate){#ref-for-dom-mediasource-readystate-36
        .internalDFN link-type="idl"}, or any of the buffering state
        that would change any of the values of each of those
        [`buffered`](#dom-sourcebuffer-buffered){#ref-for-dom-sourcebuffer-buffered-10
        .internalDFN link-type="idl"} attributes of the
        [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers){#ref-for-dom-mediasource-activesourcebuffers-36
        .internalDFN link-type="idl"}.
        :::: {#issue-container-generatedID-87 .note role="note"}
        ::: {#h-note-87 .note-title .marker role="heading" aria-level="4"}
        Note
        :::

        The overhead of recalculating and communicating
        `recent intersection ranges`{.variable
        data-type="normalized TimeRanges"} so frequently is one reason
        for allowing implementation flexibility to query this
        information on-demand using other mechanisms such as shared
        memory and locks as mentioned in [cross-context communication
        model](#dfn-cross-context-communication-model){#ref-for-dfn-cross-context-communication-model-2
        .internalDFN link-type="dfn|abstract-op"}.
        ::::
3.  If the current value of this attribute has not been set by this
    algorithm or `recent intersection ranges`{.variable} does not
    contain the exact same range information as the current value of
    this attribute, then update the current value of this attribute to
    `recent intersection ranges`{.variable}.
4.  Return the current value of this attribute.
::::

:::::::: {#htmlmediaelement-extensions-srcobject .section}
::: header-wrapper
### 10.3 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface" lt="HTMLMediaElement"}\'s [`srcObject`](https://html.spec.whatwg.org/multipage/media.html#dom-media-srcobject){link-type="attribute"} {#x10-3-htmlmediaelement-s-srcobject}

[](#htmlmediaelement-extensions-srcobject){.self-link
aria-label="Permalink for Section 10.3"}
:::

If a
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"}\'s
[`srcObject`](https://html.spec.whatwg.org/multipage/media.html#dom-media-srcobject){link-type="attribute"}
attribute is assigned a
[`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-30
.internalDFN link-type="idl" lt="MediaSourceHandle"}, then set
[`[[has ever been assigned as srcobject]]`](#dfn-has-ever-been-assigned-as-srcobject){#ref-for-dfn-has-ever-been-assigned-as-srcobject-2
.internalDFN link-type="attribute"
lt="[[has ever been assigned as srcobject]]"} for that
[`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-31
.internalDFN link-type="idl" lt="MediaSourceHandle"} to true as part of
the synchronous steps of the extended
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"}\'s
[`srcObject`](https://html.spec.whatwg.org/multipage/media.html#dom-media-srcobject){link-type="attribute"}
setter that occur before invoking the element\'s load algorithm.

:::: {#issue-container-generatedID-88 .note role="note"}
::: {#h-note-88 .note-title .marker role="heading" aria-level="4"}
Note
:::

This prevents transferring that
[`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-32
.internalDFN link-type="idl" lt="MediaSourceHandle"} object ever again,
enabling clear synchronous exception if that is attempted.
::::

:::: {#issue-container-generatedID-89 .issue}
::: {#h-issue-4 .issue-title .marker role="heading" aria-level="4"}
Issue
:::

[`MediaSourceHandle`](#dom-mediasourcehandle){#ref-for-dom-mediasourcehandle-33
.internalDFN link-type="idl" lt="MediaSourceHandle"} needs to be added
to
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement){link-type="interface"
lt="HTMLMediaElement"}\'s MediaProvider IDL typedef and related text
involving media provider objects.
::::
::::::::
::::::::::::::

:::::::::: {#audio-track-extensions .section}
::: header-wrapper
## 11. `AudioTrack` extensions {#x11-audiotrack-extensions}

[](#audio-track-extensions){.self-link
aria-label="Permalink for Section 11."}
:::

This section specifies extensions to the
\[[HTML](#bib-html "HTML Standard"){.bibref link-type="biblio"}\]
[`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack){link-type="interface"
lt="AudioTrack"} definition.

:::::::: {}
``` {#webidl-935490083 .idl .def}
WebIDL[Exposed=(Window,DedicatedWorker)]
partial interface AudioTrack {
  readonly attribute SourceBuffer? sourceBuffer;
};
```

::::: {#issue-container-number-280-0 .issue}
::: {#h-issue-5 .issue-title .marker role="heading" aria-level="3"}
[[Issue
280]{.issue-number}](https://github.com/w3c/media-source/issues/280)[:
MSE-in-Workers: {Audio,Video,Text}Track{,List} IDL in HTML need
additional DedicatedWorker in Exposed
[mse-in-workers](https://github.com/w3c/media-source/issues/?q=is%3Aissue+is%3Aopen+label%3A%22mse-in-workers%22){.respec-gh-label
style="background-color: rgb(170, 170, 170); color: rgb(0, 0, 0);"
aria-label="GitHub label: mse-in-workers"}]{.issue-label}
:::

::: {}
\[[HTML](#bib-html "HTML Standard"){.bibref link-type="biblio"}\]
[`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack){link-type="interface"
lt="AudioTrack"} needs Window+DedicatedWorker exposure.
:::
:::::

:::: section
::: header-wrapper
### Attributes {#attributes-4}

[](#attributes-4){.self-link aria-label="Permalink for this Section"}
:::

[`sourceBuffer`]{#dom-audiotrack-sourcebuffer .dfn export="" dfn-type="attribute" idl="attribute" data-title="sourceBuffer" dfn-for="AudioTrack" data-type="SourceBuffer" lt="sourceBuffer" local-lt="AudioTrack.sourceBuffer" tabindex="0" aria-haspopup="dialog"} of type [[`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-119 .internalDFN link-type="idl" lt="SourceBuffer"}]{.idlAttrType}, readonly , nullable

:   On getting, run the following step:

    If this track was created by a [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-120 .internalDFN link-type="idl" lt="SourceBuffer"} that was created on the same [realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-global-object-realm){link-type="dfn"} as this track, and if that [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-121 .internalDFN link-type="idl" lt="SourceBuffer"} has not been removed from the [`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-34 .internalDFN link-type="idl"} attribute of its [parent media source](#parent-media-source){#ref-for-parent-media-source-33 .internalDFN link-type="dfn|abstract-op"}:
    :   Return the
        [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-122
        .internalDFN link-type="idl" lt="SourceBuffer"} that created
        this track.

    Otherwise:
    :   Return null.

    ::::: {#issue-container-generatedID-90 .note role="note"}
    ::: {#h-note-89 .note-title .marker role="heading" aria-level="4"}
    Note
    :::

    ::: {}
    For example, if a
    [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
    lt="DedicatedWorkerGlobalScope"}
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-123
    .internalDFN link-type="idl" lt="SourceBuffer"} notified its
    internal `create track mirror` handler in
    [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
    lt="Window"} to create this track, then the
    [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
    lt="Window"} copy of the track would return null for this attribute.
    :::
    :::::
::::
::::::::
::::::::::

:::::::::: {#video-track-extensions .section}
::: header-wrapper
## 12. `VideoTrack` extensions {#x12-videotrack-extensions}

[](#video-track-extensions){.self-link
aria-label="Permalink for Section 12."}
:::

This section specifies extensions to the
\[[HTML](#bib-html "HTML Standard"){.bibref link-type="biblio"}\]
[`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack){link-type="interface"
lt="VideoTrack"} definition.

:::::::: {}
``` {#webidl-251527976 .idl .def}
WebIDL[Exposed=(Window,DedicatedWorker)]
partial interface VideoTrack {
  readonly attribute SourceBuffer? sourceBuffer;
};
```

::::: {#issue-container-number-280-1 .issue}
::: {#h-issue-6 .issue-title .marker role="heading" aria-level="3"}
[[Issue
280]{.issue-number}](https://github.com/w3c/media-source/issues/280)[:
MSE-in-Workers: {Audio,Video,Text}Track{,List} IDL in HTML need
additional DedicatedWorker in Exposed
[mse-in-workers](https://github.com/w3c/media-source/issues/?q=is%3Aissue+is%3Aopen+label%3A%22mse-in-workers%22){.respec-gh-label
style="background-color: rgb(170, 170, 170); color: rgb(0, 0, 0);"
aria-label="GitHub label: mse-in-workers"}]{.issue-label}
:::

::: {}
\[[HTML](#bib-html "HTML Standard"){.bibref link-type="biblio"}\]
[`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack){link-type="interface"
lt="VideoTrack"} needs Window+DedicatedWorker exposure.
:::
:::::

:::: section
::: header-wrapper
### Attributes {#attributes-5}

[](#attributes-5){.self-link aria-label="Permalink for this Section"}
:::

[`sourceBuffer`]{#dom-videotrack-sourcebuffer .dfn export="" dfn-type="attribute" idl="attribute" data-title="sourceBuffer" dfn-for="VideoTrack" data-type="SourceBuffer" lt="sourceBuffer" local-lt="VideoTrack.sourceBuffer" tabindex="0" aria-haspopup="dialog"} of type [[`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-125 .internalDFN link-type="idl" lt="SourceBuffer"}]{.idlAttrType}, readonly , nullable

:   On getting, run the following step:

    If this track was created by a [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-126 .internalDFN link-type="idl" lt="SourceBuffer"} that was created on the same [realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-global-object-realm){link-type="dfn"} as this track, and if that [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-127 .internalDFN link-type="idl" lt="SourceBuffer"} has not been removed from the [`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-35 .internalDFN link-type="idl"} attribute of its [parent media source](#parent-media-source){#ref-for-parent-media-source-34 .internalDFN link-type="dfn|abstract-op"}:
    :   Return the
        [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-128
        .internalDFN link-type="idl" lt="SourceBuffer"} that created
        this track.

    Otherwise:
    :   Return null.

    ::::: {#issue-container-generatedID-91 .note role="note"}
    ::: {#h-note-90 .note-title .marker role="heading" aria-level="4"}
    Note
    :::

    ::: {}
    For example, if a
    [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
    lt="DedicatedWorkerGlobalScope"}
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-129
    .internalDFN link-type="idl" lt="SourceBuffer"} notified its
    internal `create track mirror` handler in
    [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
    lt="Window"} to create this track, then the
    [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
    lt="Window"} copy of the track would return null for this attribute.
    :::
    :::::
::::
::::::::
::::::::::

:::::::::: {#text-track-extensions .section}
::: header-wrapper
## 13. `TextTrack` extensions {#x13-texttrack-extensions}

[](#text-track-extensions){.self-link
aria-label="Permalink for Section 13."}
:::

This section specifies extensions to the
\[[HTML](#bib-html "HTML Standard"){.bibref link-type="biblio"}\]
[`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack){link-type="interface"
lt="TextTrack"} definition.

:::::::: {}
``` {#webidl-959897060 .idl .def}
WebIDL[Exposed=(Window,DedicatedWorker)]
partial interface TextTrack {
  readonly attribute SourceBuffer? sourceBuffer;
};
```

::::: {#issue-container-number-280-2 .issue}
::: {#h-issue-7 .issue-title .marker role="heading" aria-level="3"}
[[Issue
280]{.issue-number}](https://github.com/w3c/media-source/issues/280)[:
MSE-in-Workers: {Audio,Video,Text}Track{,List} IDL in HTML need
additional DedicatedWorker in Exposed
[mse-in-workers](https://github.com/w3c/media-source/issues/?q=is%3Aissue+is%3Aopen+label%3A%22mse-in-workers%22){.respec-gh-label
style="background-color: rgb(170, 170, 170); color: rgb(0, 0, 0);"
aria-label="GitHub label: mse-in-workers"}]{.issue-label}
:::

::: {}
\[[HTML](#bib-html "HTML Standard"){.bibref link-type="biblio"}\]
[`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack){link-type="interface"
lt="TextTrack"} needs Window+DedicatedWorker exposure.
:::
:::::

:::: section
::: header-wrapper
### Attributes {#attributes-6}

[](#attributes-6){.self-link aria-label="Permalink for this Section"}
:::

[`sourceBuffer`]{#dom-texttrack-sourcebuffer .dfn export="" dfn-type="attribute" idl="attribute" data-title="sourceBuffer" dfn-for="TextTrack" data-type="SourceBuffer" lt="sourceBuffer" local-lt="TextTrack.sourceBuffer" tabindex="0" aria-haspopup="dialog"} of type [[`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-131 .internalDFN link-type="idl" lt="SourceBuffer"}]{.idlAttrType}, readonly , nullable

:   On getting, run the following step:

    If this track was created by a [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-132 .internalDFN link-type="idl" lt="SourceBuffer"} that was created on the same [realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-global-object-realm){link-type="dfn"} as this track, and if that [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-133 .internalDFN link-type="idl" lt="SourceBuffer"} has not been removed from the [`sourceBuffers`](#dom-mediasource-sourcebuffers){#ref-for-dom-mediasource-sourcebuffers-36 .internalDFN link-type="idl"} attribute of its [parent media source](#parent-media-source){#ref-for-parent-media-source-35 .internalDFN link-type="dfn|abstract-op"}:
    :   Return the
        [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-134
        .internalDFN link-type="idl" lt="SourceBuffer"} that created
        this track.

    Otherwise:
    :   Return null.

    ::::: {#issue-container-generatedID-92 .note role="note"}
    ::: {#h-note-91 .note-title .marker role="heading" aria-level="4"}
    Note
    :::

    ::: {}
    For example, if a
    [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope){link-type="interface"
    lt="DedicatedWorkerGlobalScope"}
    [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-135
    .internalDFN link-type="idl" lt="SourceBuffer"} notified its
    internal `create track mirror` handler in
    [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
    lt="Window"} to create this track, then the
    [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){link-type="interface"
    lt="Window"} copy of the track would return null for this attribute.
    :::
    :::::
::::
::::::::
::::::::::

:::::::: {#byte-stream-formats .section}
::: header-wrapper
## 14. [Byte Stream Formats]{#dfn-byte-stream-formats .dfn export="" tabindex="0" aria-haspopup="dialog" dfn-type="dfn"} {#x14-byte-stream-formats}

[](#byte-stream-formats){.self-link
aria-label="Permalink for Section 14."}
:::

The bytes provided through
[`appendBuffer`](#dom-sourcebuffer-appendbuffer){#ref-for-dom-sourcebuffer-appendbuffer-12
.internalDFN link-type="idl" lt="appendBuffer()"}`()` for a
[`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-136
.internalDFN link-type="idl" lt="SourceBuffer"} form a logical byte
stream. The format and semantics of these byte streams are defined in
[byte stream format specifications]{#byte-stream-format-specs .dfn
plurals="byte stream format specification" tabindex="0"
aria-haspopup="dialog" dfn-type="dfn"}. The byte stream format registry
\[[MSE-REGISTRY](#bib-mse-registry "Media Source Extensions™ Byte Stream Format Registry"){.bibref
link-type="biblio"}\] provides mappings between a MIME type that may be
passed to
[`addSourceBuffer`](#dom-mediasource-addsourcebuffer){#ref-for-dom-mediasource-addsourcebuffer-12
.internalDFN link-type="idl" lt="addSourceBuffer()"}`()`,
[`isTypeSupported`](#dom-mediasource-istypesupported){#ref-for-dom-mediasource-istypesupported-4
.internalDFN link-type="idl" lt="isTypeSupported()"}`()` or
[`changeType`](#dom-sourcebuffer-changetype){#ref-for-dom-sourcebuffer-changetype-17
.internalDFN link-type="idl" lt="changeType()"}`()` and the byte stream
format expected by a
[`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-137
.internalDFN link-type="idl" lt="SourceBuffer"} using that MIME type for
parsing newly appended data. Implementations are encouraged to register
mappings for byte stream formats they support to facilitate
interoperability. The byte stream format registry
\[[MSE-REGISTRY](#bib-mse-registry "Media Source Extensions™ Byte Stream Format Registry"){.bibref
link-type="biblio"}\] is the authoritative source for these mappings. If
an implementation claims to support a MIME type listed in the registry,
its [`SourceBuffer`](#dom-sourcebuffer){#ref-for-dom-sourcebuffer-138
.internalDFN link-type="idl" lt="SourceBuffer"} implementation *MUST*
conform to the [byte stream format
specification](#byte-stream-format-specs){#ref-for-byte-stream-format-specs-7
.internalDFN link-type="dfn|abstract-op"} listed in the registry entry.

:::: {#issue-container-generatedID-93 .note role="note"}
::: {#h-note-92 .note-title .marker role="heading" aria-level="3"}
Note
:::

The byte stream format specifications in the registry are not intended
to define new storage formats. They simply outline the subset of
existing storage format structures that implementations of this
specification will accept.
::::

:::: {#issue-container-generatedID-94 .note role="note"}
::: {#h-note-93 .note-title .marker role="heading" aria-level="3"}
Note
:::

Byte stream format parsing and validation is implemented in the [segment
parser
loop](#dfn-segment-parser-loop){#ref-for-dfn-segment-parser-loop-5
.internalDFN link-type="dfn|abstract-op"} algorithm.
::::

This section provides general requirements for all byte stream format
specifications:

- A byte stream format specification *MUST* define [initialization
  segments](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-33
  .internalDFN link-type="dfn|abstract-op"} and [media
  segments](#dfn-media-segment){#ref-for-dfn-media-segment-15
  .internalDFN link-type="dfn|abstract-op"}.

- A byte stream format *SHOULD* provide references for sourcing
  [`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack){link-type="interface"
  lt="AudioTrack"},
  [`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack){link-type="interface"
  lt="VideoTrack"}, and
  [`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack){link-type="interface"
  lt="TextTrack"} attribute values from data in [initialization
  segments](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-34
  .internalDFN link-type="dfn|abstract-op"}.

  :::: {#issue-container-generatedID-95 .note role="note"}
  ::: {#h-note-94 .note-title .marker role="heading" aria-level="3"}
  Note
  :::

  If the byte stream format covers a format similar to one covered in
  the in-band tracks spec
  \[[INBANDTRACKS](#bib-inbandtracks "Sourcing In-band Media Resource Tracks from Media Containers into HTML"){.bibref
  link-type="biblio"}\], then it *SHOULD* try to use the same attribute
  mappings so that Media Source Extensions playback and non-Media Source
  Extensions playback provide the same track information.
  ::::

- It *MUST* be possible to identify segment boundaries and segment type
  (initialization or media) by examining the byte stream alone.

- The user agent *MUST* run the [append
  error](#dfn-append-error){#ref-for-dfn-append-error-8 .internalDFN
  link-type="dfn|abstract-op"} algorithm when any of the following
  conditions are met:
  1.  The number and type of tracks are not consistent.

      :::: {#issue-container-generatedID-96 .note role="note"}
      ::: {#h-note-95 .note-title .marker role="heading" aria-level="3"}
      Note
      :::

      For example, if the first [initialization
      segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-35
      .internalDFN link-type="dfn|abstract-op"} has 2 audio tracks and 1
      video track, then all [initialization
      segments](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-36
      .internalDFN link-type="dfn|abstract-op"} that follow it in the
      byte stream *MUST* describe 2 audio tracks and 1 video track.
      ::::

  2.  [Track IDs](#dfn-track-id){#ref-for-dfn-track-id-9 .internalDFN
      link-type="dfn|abstract-op"} are not the same across
      [initialization
      segments](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-37
      .internalDFN link-type="dfn|abstract-op"}, for segments describing
      multiple tracks of a single type (e.g., 2 audio tracks).

  3.  Unsupported codec changes occur across [initialization
      segments](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-38
      .internalDFN link-type="dfn|abstract-op"}.

      :::: {#issue-container-generatedID-97 .note role="note"}
      ::: {#h-note-96 .note-title .marker role="heading" aria-level="3"}
      Note
      :::

      See the [initialization segment
      received](#dfn-initialization-segment-received){#ref-for-dfn-initialization-segment-received-2
      .internalDFN link-type="dfn|abstract-op"} algorithm,
      [`addSourceBuffer`](#dom-mediasource-addsourcebuffer){#ref-for-dom-mediasource-addsourcebuffer-13
      .internalDFN link-type="idl" lt="addSourceBuffer()"}`()` and
      [`changeType`](#dom-sourcebuffer-changetype){#ref-for-dom-sourcebuffer-changetype-18
      .internalDFN link-type="idl" lt="changeType()"}`()` for details
      and examples of codec changes.
      ::::

- The user agent *MUST* support the following:
  1.  [Track IDs](#dfn-track-id){#ref-for-dfn-track-id-10 .internalDFN
      link-type="dfn|abstract-op"} changing across [initialization
      segments](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-39
      .internalDFN link-type="dfn|abstract-op"} if the segments describe
      only one track of each type.

  2.  Video frame size changes. The user agent *MUST* support seamless
      playback.

      :::: {#issue-container-generatedID-98 .note role="note"}
      ::: {#h-note-97 .note-title .marker role="heading" aria-level="3"}
      Note
      :::

      This will cause the \<video\> display region to change size if the
      web application does not use CSS or HTML attributes (width/height)
      to constrain the element size.
      ::::

  3.  Audio channel count changes. The user agent *MAY* support this
      seamlessly and could trigger downmixing.

      :::: {#issue-container-generatedID-99 .note role="note"}
      ::: {#h-note-98 .note-title .marker role="heading" aria-level="3"}
      Note
      :::

      This is a quality of implementation issue because changing the
      channel count may require reinitializing the audio device,
      resamplers, and channel mixers which tends to be audible.
      ::::

- The following rules apply to all [media
  segments](#dfn-media-segment){#ref-for-dfn-media-segment-16
  .internalDFN link-type="dfn|abstract-op"} within a byte stream. A user
  agent *MUST*:
  1.  Map all timestamps to the same [media
      timeline](https://html.spec.whatwg.org/multipage/media.html#media-timeline).
  2.  Support seamless playback of [media
      segments](#dfn-media-segment){#ref-for-dfn-media-segment-17
      .internalDFN link-type="dfn|abstract-op"} having a timestamp gap
      smaller than the audio frame size. User agents *MUST NOT* reflect
      these gaps in the
      [`buffered`](#dom-sourcebuffer-buffered){#ref-for-dom-sourcebuffer-buffered-11
      .internalDFN link-type="idl"} attribute.

      :::: {#issue-container-generatedID-100 .note role="note"}
      ::: {#h-note-99 .note-title .marker role="heading" aria-level="3"}
      Note
      :::

      This is intended to simplify switching between audio streams where
      the frame boundaries don\'t always line up across encodings (e.g.,
      Vorbis).
      ::::

- The user agent *MUST* run the [append
  error](#dfn-append-error){#ref-for-dfn-append-error-9 .internalDFN
  link-type="dfn|abstract-op"} algorithm when any combination of an
  [initialization
  segment](#dfn-initialization-segment){#ref-for-dfn-initialization-segment-40
  .internalDFN link-type="dfn|abstract-op"} and any contiguous sequence
  of [media segments](#dfn-media-segment){#ref-for-dfn-media-segment-18
  .internalDFN link-type="dfn|abstract-op"} satisfies the following
  conditions:

  1.  The number and type (audio, video, text, etc.) of all tracks in
      the [media
      segments](#dfn-media-segment){#ref-for-dfn-media-segment-19
      .internalDFN link-type="dfn|abstract-op"} are not identified.
  2.  The decoding capabilities needed to decode each track (i.e., codec
      and codec parameters) are not provided.
  3.  Encryption parameters necessary to decrypt the content (except the
      encryption key itself) are not provided for all encrypted tracks.
  4.  All information necessary to decode and render the earliest
      [random access
      point](#random-access-point){#ref-for-random-access-point-11
      .internalDFN link-type="dfn|abstract-op"} in the sequence of
      [media segments](#dfn-media-segment){#ref-for-dfn-media-segment-20
      .internalDFN link-type="dfn|abstract-op"} and all subsequence
      samples in the sequence (in presentation time) are not provided.
      This includes in particular,
      - Information that determines the [intrinsic width and
        height](https://html.spec.whatwg.org/multipage/media.html#concept-video-intrinsic-width)
        of the video (specifically, this requires either the picture or
        pixel aspect ratio, together with the encoded resolution).
      - Information necessary to convert the video decoder output to a
        format suitable for display
  5.  Information necessary to compute the global [presentation
      timestamp](#presentation-timestamp){#ref-for-presentation-timestamp-42
      .internalDFN link-type="dfn|abstract-op"} of every sample in the
      sequence of [media
      segments](#dfn-media-segment){#ref-for-dfn-media-segment-21
      .internalDFN link-type="dfn|abstract-op"} is not provided.

  For example, if I1 is associated with M1, M2, M3 then the above *MUST*
  hold for all the combinations I1+M1, I1+M2, I1+M1+M2, I1+M2+M3, etc.

Byte stream specifications *MUST* at a minimum define constraints which
ensure that the above requirements hold. Additional constraints *MAY* be
defined, for example to simplify implementation.
::::::::

:::: {#conformance .section}
::: header-wrapper
## 15. Conformance {#x15-conformance}

[](#conformance){.self-link aria-label="Permalink for Section 15."}
:::

As well as sections marked as non-normative, all authoring guidelines,
diagrams, examples, and notes in this specification are non-normative.
Everything else in this specification is normative.

The key words *MAY*, *MUST*, *MUST NOT*, *SHOULD*, and *SHOULD NOT* in
this document are to be interpreted as described in [BCP
14](https://www.rfc-editor.org/info/bcp14)
\[[RFC2119](#bib-rfc2119 "Key words for use in RFCs to Indicate Requirement Levels"){.bibref
link-type="biblio"}\]
\[[RFC8174](#bib-rfc8174 "Ambiguity of Uppercase vs Lowercase in RFC 2119 Key Words"){.bibref
link-type="biblio"}\] when, and only when, they appear in all capitals,
as shown here.
::::

:::::::::::: {#examples .section}
::: header-wrapper
## 16. Examples {#x16-examples}

[](#examples){.self-link aria-label="Permalink for Section 16."}
:::

:::::: {#using-media-source-extensions .section}
::: header-wrapper
### 16.1 Using Media Source Extensions {#x16-1-using-media-source-extensions}

[](#using-media-source-extensions){.self-link
aria-label="Permalink for Section 16.1"}
:::

:::: {#example-1 .example}
::: marker
[Example 1](#example-1){.self-link}
:::

``` {aria-busy="false"}
<video id="v" autoplay></video>
<script>
const video = document.getElementById("v");
const mediaSource = new MediaSource();
mediaSource.addEventListener("sourceopen", onSourceOpen);
video.src = window.URL.createObjectURL(mediaSource);

async function onSourceOpen(e) {
  const mediaSource = e.target;

  if (mediaSource.sourceBuffers.length > 0) return;

  const sourceBuffer = mediaSource.addSourceBuffer(
    'video/webm; codecs="vorbis,vp8"',
  );

  video.addEventListener("seeking", (e) => onSeeking(mediaSource, e.target));
  video.addEventListener("progress", () =>
    appendNextMediaSegment(mediaSource),
  );

  try {
    const initSegment = await getInitializationSegment();

    if (initSegment == null) {
      // Error fetching the initialization segment. Signal end of stream with an error.
      mediaSource.endOfStream("network");
      return;
    }

    // Append the initialization segment.
    sourceBuffer.addEventListener("updateend", function firstAppendHandler() {
      sourceBuffer.removeEventListener("updateend", firstAppendHandler);

      // Append some initial media data.
      appendNextMediaSegment(mediaSource);
    });

    sourceBuffer.appendBuffer(initSegment);
  } catch (error) {
    // Handle errors that might occur during initialization segment fetching.
    console.error("Error fetching initialization segment:", error);
    mediaSource.endOfStream("network");
  }
}

async function appendNextMediaSegment(mediaSource) {
  if (
    mediaSource.readyState === "closed" ||
    mediaSource.sourceBuffers[0].updating
  )
    return;

  // If we have run out of stream data, then signal end of stream.
  if (!haveMoreMediaSegments()) {
    mediaSource.endOfStream();
    return;
  }

  try {
    const mediaSegment = await getNextMediaSegment();

    // NOTE: If mediaSource.readyState == "ended", this appendBuffer() call will
    // cause mediaSource.readyState to transition to "open". The web application
    // should be prepared to handle multiple "sourceopen" events.
    mediaSource.sourceBuffers[0].appendBuffer(mediaSegment);
  }
  catch (error) {
    // Handle errors that might occur during media segment fetching.
    console.error("Error fetching media segment:", error);
    mediaSource.endOfStream("network");
  }
}

function onSeeking(mediaSource, video) {
  if (mediaSource.readyState === "open") {
    // Abort current segment append.
    mediaSource.sourceBuffers[0].abort();
  }

  // Notify the media segment loading code to start fetching data at the
  // new playback position.
  seekToMediaSegmentAt(video.currentTime);

  // Append a media segment from the new playback position.
  appendNextMediaSegment(mediaSource);
}

function onProgress(mediaSource, e) {
  appendNextMediaSegment(mediaSource);
}

// Example of async function for getting initialization segment
async function getInitializationSegment() {
  // Implement fetching of the initialization segment
  // This is just a placeholder function
}

// Example function for checking if there are more media segments
function haveMoreMediaSegments() {
  // Implement logic to determine if there are more media segments
  // This is just a placeholder function
}

// Example function for getting the next media segment
async function getNextMediaSegment() {
  // Implement fetching of the next media segment
  // This is just a placeholder function
}

// Example function for seeking to a specific media segment
function seekToMediaSegmentAt(currentTime) {
  // Implement seeking logic
  // This is just a placeholder function
}
</script>
```
::::
::::::

:::::: {#using-a-managed-media-source .section}
::: header-wrapper
### 16.2 Using a Managed Media Source {#x16-2-using-a-managed-media-source}

[](#using-a-managed-media-source){.self-link
aria-label="Permalink for Section 16.2"}
:::

:::: {#example-2 .example}
::: marker
[Example 2](#example-2){.self-link}
:::

``` {aria-busy="false"}
<script>
async function setUpVideoStream() {
  // Specific video format and codec
  const mediaType = 'video/mp4; codecs="mp4a.40.2,avc1.4d4015"';

  // Check if the type of video format / codec is supported.
  if (!window.ManagedMediaSource?.isTypeSupported(mediaType)) {
    return; // Not supported, do something else.
  }

  // Set up video and its managed source.
  const video = document.createElement("video");
  const source = new ManagedMediaSource();

  video.controls = true;

  await new Promise((resolve) => {
    video.src = URL.createObjectURL(source);
    source.addEventListener("sourceopen", resolve, { once: true });
    document.body.appendChild(video);
  });

  const sourceBuffer = source.addSourceBuffer(mediaType);

  // Set up the event handlers
  sourceBuffer.onbufferedchange = (e) => {
    console.log("onbufferedchange event fired.");
    console.log(`Added Ranges: ${timeRangesToString(e.addedRanges)}`);
    console.log(`Removed Ranges: ${timeRangesToString(e.removedRanges)}`);
  };

  source.onstartstreaming = async () => {
    const response = await fetch("./videos/bipbop.mp4");
    const buffer = await response.arrayBuffer();
    await new Promise((resolve) => {
      sourceBuffer.addEventListener("updateend", resolve, { once: true });
      sourceBuffer.appendBuffer(buffer);
    });
  };

  source.onendstreaming = async () => {
    // Stop fetching new segments here
  };
}

// Helper function...
function timeRangesToString(timeRanges) {
  const ranges = [];
  for (let i = 0; i < timeRanges.length; i++) {
    ranges.push([timeRanges.start(i), timeRanges.end(i)]);
  }
  return "[" + ranges.map(([start, end]) => `[${start}, ${end})` ) + "]";
}
</script>
<body onload="setUpVideoStream()"></body>
```
::::
::::::
::::::::::::

:::: {#acknowledgements .section}
::: header-wrapper
## 17. Acknowledgments {#x17-acknowledgments}

[](#acknowledgements){.self-link aria-label="Permalink for Section 17."}
:::

The editors would like to thank Alex Giladi, Bob Lund, Chris Needham,
Chris Poole, Chris Wilson, Cyril Concolato, Dale Curtis, David Dorwin,
David Singer, Duncan Rowden, François Daoust, Frank Galligan, Glenn
Adams, Jer Noble, Joe Steele, John Simmons, Kagami Sascha Rosylight,
Kevin Streeter, Marcos Cáceres, Mark Vickers, Matt Ward, Matthew Gregan,
Michael(tm) Smith, Michael Thornburgh, Mounir Lamouri, Paul Adenot,
Philip Jägenstedt, Philippe Le Hegaret, Pierre Lemieux, Ralph Giles,
Steven Robertson, and Tatsuya Igarashi for their contributions to this
specification.
::::

:::: {#VideoPlaybackQuality .section .appendix .informative}
::: header-wrapper
## A. VideoPlaybackQuality {#a-videoplaybackquality}

[](#VideoPlaybackQuality){.self-link
aria-label="Permalink for Appendix A."}
:::

*This section is non-normative.*

The video playback quality metrics described in previous revisions of
this specification (e.g., sections 5 and 10 of the [Candidate
Recommendation](https://www.w3.org/TR/2016/CR-media-source-20160705/))
are now being developed as part of
\[[MEDIA-PLAYBACK-QUALITY](#bib-media-playback-quality "Media Playback Quality"){.bibref
link-type="biblio"}\]. Some implementations may have implemented the
earlier draft `VideoPlaybackQuality` object and the
[`HTMLVideoElement`](https://html.spec.whatwg.org/multipage/media.html#htmlvideoelement){link-type="interface"
lt="HTMLVideoElement"} extension method
[`getVideoPlaybackQuality`](https://w3c.github.io/media-playback-quality/#dom-htmlvideoelement-getvideoplaybackquality){link-type="method"
lt="getVideoPlaybackQuality()"}`()` described in those previous
revisions.
::::

:::: {#issue-summary .section .appendix}
::: header-wrapper
## B. Issue summary {#b-issue-summary}

[](#issue-summary){.self-link aria-label="Permalink for Appendix B."}
:::

- [Issue 276](#issue-container-number-276)[: MSE-in-Workers: Consider
  adding a \"closing\" readyState to explain new \`InvalidStateError\`
  exception when closing underway]{style="text-transform: none"}
- [Issue 280](#issue-container-number-280)[: MSE-in-Workers:
  {Audio,Video,Text}Track{,List} IDL in HTML need additional
  DedicatedWorker in Exposed]{style="text-transform: none"}
- [Issue 289](#issue-container-number-289)[: Editorial? Coded Frame
  eviction algorithm needs to note that \"buffer full flag\" may be
  updated immediately based on \|new
  data\|]{style="text-transform: none"}
- [Issue 277](#issue-container-number-277)[: MSE-in-Workers: Consider
  (eventually) transitioning attached element to error upon termination
  of MediaSource\'s worker/what should media element
  do?]{style="text-transform: none"}
- [Issue 277](#issue-container-number-277-0)[: MSE-in-Workers: Consider
  (eventually) transitioning attached element to error upon termination
  of MediaSource\'s worker/what should media element
  do?]{style="text-transform: none"}
- [Issue](#issue-container-generatedID-89)
- [Issue 280](#issue-container-number-280-0)[: MSE-in-Workers:
  {Audio,Video,Text}Track{,List} IDL in HTML need additional
  DedicatedWorker in Exposed]{style="text-transform: none"}
- [Issue 280](#issue-container-number-280-1)[: MSE-in-Workers:
  {Audio,Video,Text}Track{,List} IDL in HTML need additional
  DedicatedWorker in Exposed]{style="text-transform: none"}
- [Issue 280](#issue-container-number-280-2)[: MSE-in-Workers:
  {Audio,Video,Text}Track{,List} IDL in HTML need additional
  DedicatedWorker in Exposed]{style="text-transform: none"}
::::

:::::::: {#references .section .appendix}
::: header-wrapper
## C. References {#c-references}

[](#references){.self-link aria-label="Permalink for Appendix C."}
:::

:::: {#normative-references .section}
::: header-wrapper
### C.1 Normative references {#c-1-normative-references}

[](#normative-references){.self-link
aria-label="Permalink for Appendix C.1"}
:::

\[dom\]
:   [DOM Standard](https://dom.spec.whatwg.org/). Anne van Kesteren.
    WHATWG. Living Standard. URL: <https://dom.spec.whatwg.org/>

\[ECMASCRIPT\]
:   [ECMAScript Language
    Specification](https://tc39.es/ecma262/multipage/). Ecma
    International. URL: <https://tc39.es/ecma262/multipage/>

\[FILEAPI\]
:   [File API](https://www.w3.org/TR/FileAPI/). Marijn Kruisselbrink.
    W3C. 4 December 2024. W3C Working Draft. URL:
    <https://www.w3.org/TR/FileAPI/>

\[HTML\]
:   [HTML Standard](https://html.spec.whatwg.org/multipage/). Anne van
    Kesteren; Domenic Denicola; Dominic Farolino; Ian Hickson; Philip
    Jägenstedt; Simon Pieters. WHATWG. Living Standard. URL:
    <https://html.spec.whatwg.org/multipage/>

\[infra\]
:   [Infra Standard](https://infra.spec.whatwg.org/). Anne van Kesteren;
    Domenic Denicola. WHATWG. Living Standard. URL:
    <https://infra.spec.whatwg.org/>

\[MSE-REGISTRY\]
:   [Media Source Extensions™ Byte Stream Format
    Registry](https://w3c.github.io/mse-byte-stream-format-registry/).
    Matthew Wolenetz; Jerry Smith; Aaron Colwell. W3C. URL:
    <https://w3c.github.io/mse-byte-stream-format-registry/>

\[RFC2119\]
:   [Key words for use in RFCs to Indicate Requirement
    Levels](https://www.rfc-editor.org/rfc/rfc2119). S. Bradner. IETF.
    March 1997. Best Current Practice. URL:
    <https://www.rfc-editor.org/rfc/rfc2119>

\[RFC8174\]
:   [Ambiguity of Uppercase vs Lowercase in RFC 2119 Key
    Words](https://www.rfc-editor.org/rfc/rfc8174). B. Leiba. IETF.
    May 2017. Best Current Practice. URL:
    <https://www.rfc-editor.org/rfc/rfc8174>

\[WEBIDL\]
:   [Web IDL Standard](https://webidl.spec.whatwg.org/). Edgar Chen;
    Timothy Gu. WHATWG. Living Standard. URL:
    <https://webidl.spec.whatwg.org/>
::::

:::: {#informative-references .section}
::: header-wrapper
### C.2 Informative references {#c-2-informative-references}

[](#informative-references){.self-link
aria-label="Permalink for Appendix C.2"}
:::

\[INBANDTRACKS\]
:   [Sourcing In-band Media Resource Tracks from Media Containers into
    HTML](https://dev.w3.org/html5/html-sourcing-inband-tracks/). Silvia
    Pfeiffer; Bob Lund. W3C. 26 April 2015. Unofficial Draft. URL:
    <https://dev.w3.org/html5/html-sourcing-inband-tracks/>

\[MEDIA-PLAYBACK-QUALITY\]
:   [Media Playback
    Quality](https://w3c.github.io/media-playback-quality/). Mounir
    Lamouri; Chris Cunningham. W3C. W3C Editor\'s Draft. URL:
    <https://w3c.github.io/media-playback-quality/>

\[url\]
:   [URL Standard](https://url.spec.whatwg.org/). Anne van Kesteren.
    WHATWG. Living Standard. URL: <https://url.spec.whatwg.org/>
::::
::::::::

[[↑]{.abbr title="Back to Top"}](#title)

:::: {#dfn-panel-for-dfn-active-track-buffers .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Active Track Buffers"}
[]{.caret}

::: {}
[Permalink](#dfn-active-track-buffers){.self-link
aria-label="Permalink for definition: Active Track Buffers. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 3.15.3
  Seeking](#ref-for-dfn-active-track-buffers-1 "§ 3.15.3 Seeking")
::::

:::: {#dfn-panel-for-dfn-append-window .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Append Window"}
[]{.caret}

::: {}
[Permalink](#dfn-append-window){.self-link
aria-label="Permalink for definition: Append Window. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.1 Attributes](#ref-for-dfn-append-window-1 "§ 5.1 Attributes")
  [(2)](#ref-for-dfn-append-window-2 "Reference 2")
::::

:::: {#dfn-panel-for-dfn-coded-frame .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Coded Frame"}
[]{.caret}

::: {}
[Permalink](#dfn-coded-frame){.self-link
aria-label="Permalink for definition: Coded Frame. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
:::

**Referenced in:**

- [§ 2. Definitions](#ref-for-dfn-coded-frame-1 "§ 2. Definitions")
  [(2)](#ref-for-dfn-coded-frame-2 "Reference 2")
  [(3)](#ref-for-dfn-coded-frame-3 "Reference 3")
  [(4)](#ref-for-dfn-coded-frame-4 "Reference 4")
  [(5)](#ref-for-dfn-coded-frame-5 "Reference 5")
  [(6)](#ref-for-dfn-coded-frame-6 "Reference 6")
  [(7)](#ref-for-dfn-coded-frame-7 "Reference 7")
  [(8)](#ref-for-dfn-coded-frame-8 "Reference 8")
  [(9)](#ref-for-dfn-coded-frame-9 "Reference 9")
- [§ 3.15.3 Seeking](#ref-for-dfn-coded-frame-10 "§ 3.15.3 Seeking")
- [§ 3.15.6 Duration
  change](#ref-for-dfn-coded-frame-11 "§ 3.15.6 Duration change")
- [§ 5. SourceBuffer
  interface](#ref-for-dfn-coded-frame-12 "§ 5. SourceBuffer interface")
- [§ 5.3 Track
  Buffers](#ref-for-dfn-coded-frame-13 "§ 5.3 Track Buffers")
  [(2)](#ref-for-dfn-coded-frame-14 "Reference 2")
  [(3)](#ref-for-dfn-coded-frame-15 "Reference 3")
  [(4)](#ref-for-dfn-coded-frame-16 "Reference 4")
  [(5)](#ref-for-dfn-coded-frame-17 "Reference 5")
  [(6)](#ref-for-dfn-coded-frame-18 "Reference 6")
  [(7)](#ref-for-dfn-coded-frame-19 "Reference 7")
  [(8)](#ref-for-dfn-coded-frame-20 "Reference 8")
  [(9)](#ref-for-dfn-coded-frame-21 "Reference 9")
  [(10)](#ref-for-dfn-coded-frame-22 "Reference 10")
- [§ 5.5.1 Segment Parser
  Loop](#ref-for-dfn-coded-frame-23 "§ 5.5.1 Segment Parser Loop")
  [(2)](#ref-for-dfn-coded-frame-24 "Reference 2")
  [(3)](#ref-for-dfn-coded-frame-25 "Reference 3")
- [§ 5.5.2 Reset Parser
  State](#ref-for-dfn-coded-frame-26 "§ 5.5.2 Reset Parser State")
  [(2)](#ref-for-dfn-coded-frame-27 "Reference 2")
- [§ 5.5.7 Initialization Segment
  Received](#ref-for-dfn-coded-frame-28 "§ 5.5.7 Initialization Segment Received")
  [(2)](#ref-for-dfn-coded-frame-29 "Reference 2")
  [(3)](#ref-for-dfn-coded-frame-30 "Reference 3")
- [§ 5.5.8 Coded Frame
  Processing](#ref-for-dfn-coded-frame-31 "§ 5.5.8 Coded Frame Processing")
  [(2)](#ref-for-dfn-coded-frame-32 "Reference 2")
  [(3)](#ref-for-dfn-coded-frame-33 "Reference 3")
  [(4)](#ref-for-dfn-coded-frame-34 "Reference 4")
  [(5)](#ref-for-dfn-coded-frame-35 "Reference 5")
  [(6)](#ref-for-dfn-coded-frame-36 "Reference 6")
  [(7)](#ref-for-dfn-coded-frame-37 "Reference 7")
  [(8)](#ref-for-dfn-coded-frame-38 "Reference 8")
  [(9)](#ref-for-dfn-coded-frame-39 "Reference 9")
  [(10)](#ref-for-dfn-coded-frame-40 "Reference 10")
  [(11)](#ref-for-dfn-coded-frame-41 "Reference 11")
  [(12)](#ref-for-dfn-coded-frame-42 "Reference 12")
  [(13)](#ref-for-dfn-coded-frame-43 "Reference 13")
  [(14)](#ref-for-dfn-coded-frame-44 "Reference 14")
  [(15)](#ref-for-dfn-coded-frame-45 "Reference 15")
  [(16)](#ref-for-dfn-coded-frame-46 "Reference 16")
  [(17)](#ref-for-dfn-coded-frame-47 "Reference 17")
- [§ 5.5.9 Coded Frame
  Removal](#ref-for-dfn-coded-frame-48 "§ 5.5.9 Coded Frame Removal")
  [(2)](#ref-for-dfn-coded-frame-49 "Reference 2")
  [(3)](#ref-for-dfn-coded-frame-50 "Reference 3")
  [(4)](#ref-for-dfn-coded-frame-51 "Reference 4")
  [(5)](#ref-for-dfn-coded-frame-52 "Reference 5")
- [§ 5.5.11 Audio Splice
  Frame](#ref-for-dfn-coded-frame-53 "§ 5.5.11 Audio Splice Frame")
  [(2)](#ref-for-dfn-coded-frame-54 "Reference 2")
  [(3)](#ref-for-dfn-coded-frame-55 "Reference 3")
- [§ 5.5.12 Audio Splice
  Rendering](#ref-for-dfn-coded-frame-56 "§ 5.5.12 Audio Splice Rendering")
  [(2)](#ref-for-dfn-coded-frame-57 "Reference 2")
- [§ 5.5.13 Text Splice
  Frame](#ref-for-dfn-coded-frame-58 "§ 5.5.13 Text Splice Frame")
  [(2)](#ref-for-dfn-coded-frame-59 "Reference 2")
  [(3)](#ref-for-dfn-coded-frame-60 "Reference 3")
::::

:::: {#dfn-panel-for-dfn-coded-frame-duration .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Coded Frame Duration"}
[]{.caret}

::: {}
[Permalink](#dfn-coded-frame-duration){.self-link
aria-label="Permalink for definition: Coded Frame Duration. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 2.
  Definitions](#ref-for-dfn-coded-frame-duration-1 "§ 2. Definitions")
  [(2)](#ref-for-dfn-coded-frame-duration-2 "Reference 2")
  [(3)](#ref-for-dfn-coded-frame-duration-3 "Reference 3")
  [(4)](#ref-for-dfn-coded-frame-duration-4 "Reference 4")
- [§ 5.3 Track
  Buffers](#ref-for-dfn-coded-frame-duration-5 "§ 5.3 Track Buffers")
- [§ 5.5.8 Coded Frame
  Processing](#ref-for-dfn-coded-frame-duration-6 "§ 5.5.8 Coded Frame Processing")
- [§ 5.5.11 Audio Splice
  Frame](#ref-for-dfn-coded-frame-duration-7 "§ 5.5.11 Audio Splice Frame")
  [(2)](#ref-for-dfn-coded-frame-duration-8 "Reference 2")
  [(3)](#ref-for-dfn-coded-frame-duration-9 "Reference 3")
- [§ 5.5.12 Audio Splice
  Rendering](#ref-for-dfn-coded-frame-duration-10 "§ 5.5.12 Audio Splice Rendering")
- [§ 5.5.13 Text Splice
  Frame](#ref-for-dfn-coded-frame-duration-11 "§ 5.5.13 Text Splice Frame")
  [(2)](#ref-for-dfn-coded-frame-duration-12 "Reference 2")
::::

:::: {#dfn-panel-for-dfn-coded-frame-end-timestamp .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Coded Frame End Timestamp"}
[]{.caret}

::: {}
[Permalink](#dfn-coded-frame-end-timestamp){.self-link
aria-label="Permalink for definition: Coded Frame End Timestamp. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.3 Track
  Buffers](#ref-for-dfn-coded-frame-end-timestamp-1 "§ 5.3 Track Buffers")
- [§ 5.5.1 Segment Parser
  Loop](#ref-for-dfn-coded-frame-end-timestamp-2 "§ 5.5.1 Segment Parser Loop")
  [(2)](#ref-for-dfn-coded-frame-end-timestamp-3 "Reference 2")
::::

:::: {#dfn-panel-for-dfn-coded-frame-group .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Coded Frame Group"}
[]{.caret}

::: {}
[Permalink](#dfn-coded-frame-group){.self-link
aria-label="Permalink for definition: Coded Frame Group. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.3 Track
  Buffers](#ref-for-dfn-coded-frame-group-1 "§ 5.3 Track Buffers")
  [(2)](#ref-for-dfn-coded-frame-group-2 "Reference 2")
  [(3)](#ref-for-dfn-coded-frame-group-3 "Reference 3")
- [§ 5.5.1 Segment Parser
  Loop](#ref-for-dfn-coded-frame-group-4 "§ 5.5.1 Segment Parser Loop")
  [(2)](#ref-for-dfn-coded-frame-group-5 "Reference 2")
::::

:::: {#dfn-panel-for-dfn-decode-timestamp .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Decode Timestamp"}
[]{.caret}

::: {}
[Permalink](#dfn-decode-timestamp){.self-link
aria-label="Permalink for definition: Decode Timestamp. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 2. Definitions](#ref-for-dfn-decode-timestamp-1 "§ 2. Definitions")
  [(2)](#ref-for-dfn-decode-timestamp-2 "Reference 2")
- [§ 5.5.9 Coded Frame
  Removal](#ref-for-dfn-decode-timestamp-3 "§ 5.5.9 Coded Frame Removal")
- [§ 5.5.11 Audio Splice
  Frame](#ref-for-dfn-decode-timestamp-4 "§ 5.5.11 Audio Splice Frame")
  [(2)](#ref-for-dfn-decode-timestamp-5 "Reference 2")
  [(3)](#ref-for-dfn-decode-timestamp-6 "Reference 3")
  [(4)](#ref-for-dfn-decode-timestamp-7 "Reference 4")
::::

:::: {#dfn-panel-for-dfn-initialization-segment .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Initialization Segment"}
[]{.caret}

::: {}
[Permalink](#dfn-initialization-segment){.self-link
aria-label="Permalink for definition: Initialization Segment. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
:::

**Referenced in:**

- [§ 2.
  Definitions](#ref-for-dfn-initialization-segment-1 "§ 2. Definitions")
  [(2)](#ref-for-dfn-initialization-segment-2 "Reference 2")
  [(3)](#ref-for-dfn-initialization-segment-3 "Reference 3")
- [§ 3.15.3
  Seeking](#ref-for-dfn-initialization-segment-4 "§ 3.15.3 Seeking")
- [§ 5.3 Track
  Buffers](#ref-for-dfn-initialization-segment-5 "§ 5.3 Track Buffers")
- [§ 5.5.1 Segment Parser
  Loop](#ref-for-dfn-initialization-segment-6 "§ 5.5.1 Segment Parser Loop")
  [(2)](#ref-for-dfn-initialization-segment-7 "Reference 2")
  [(3)](#ref-for-dfn-initialization-segment-8 "Reference 3")
  [(4)](#ref-for-dfn-initialization-segment-9 "Reference 4")
  [(5)](#ref-for-dfn-initialization-segment-10 "Reference 5")
- [§ 5.5.7 Initialization Segment
  Received](#ref-for-dfn-initialization-segment-11 "§ 5.5.7 Initialization Segment Received")
  [(2)](#ref-for-dfn-initialization-segment-12 "Reference 2")
  [(3)](#ref-for-dfn-initialization-segment-13 "Reference 3")
  [(4)](#ref-for-dfn-initialization-segment-14 "Reference 4")
  [(5)](#ref-for-dfn-initialization-segment-15 "Reference 5")
  [(6)](#ref-for-dfn-initialization-segment-16 "Reference 6")
  [(7)](#ref-for-dfn-initialization-segment-17 "Reference 7")
  [(8)](#ref-for-dfn-initialization-segment-18 "Reference 8")
  [(9)](#ref-for-dfn-initialization-segment-19 "Reference 9")
  [(10)](#ref-for-dfn-initialization-segment-20 "Reference 10")
  [(11)](#ref-for-dfn-initialization-segment-21 "Reference 11")
  [(12)](#ref-for-dfn-initialization-segment-22 "Reference 12")
  [(13)](#ref-for-dfn-initialization-segment-23 "Reference 13")
  [(14)](#ref-for-dfn-initialization-segment-24 "Reference 14")
  [(15)](#ref-for-dfn-initialization-segment-25 "Reference 15")
  [(16)](#ref-for-dfn-initialization-segment-26 "Reference 16")
  [(17)](#ref-for-dfn-initialization-segment-27 "Reference 17")
  [(18)](#ref-for-dfn-initialization-segment-28 "Reference 18")
  [(19)](#ref-for-dfn-initialization-segment-29 "Reference 19")
  [(20)](#ref-for-dfn-initialization-segment-30 "Reference 20")
  [(21)](#ref-for-dfn-initialization-segment-31 "Reference 21")
  [(22)](#ref-for-dfn-initialization-segment-32 "Reference 22")
- [§ 14. Byte Stream
  Formats](#ref-for-dfn-initialization-segment-33 "§ 14. Byte Stream Formats")
  [(2)](#ref-for-dfn-initialization-segment-34 "Reference 2")
  [(3)](#ref-for-dfn-initialization-segment-35 "Reference 3")
  [(4)](#ref-for-dfn-initialization-segment-36 "Reference 4")
  [(5)](#ref-for-dfn-initialization-segment-37 "Reference 5")
  [(6)](#ref-for-dfn-initialization-segment-38 "Reference 6")
  [(7)](#ref-for-dfn-initialization-segment-39 "Reference 7")
  [(8)](#ref-for-dfn-initialization-segment-40 "Reference 8")
::::

:::: {#dfn-panel-for-dfn-media-segment .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Media Segment"}
[]{.caret}

::: {}
[Permalink](#dfn-media-segment){.self-link
aria-label="Permalink for definition: Media Segment. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
:::

**Referenced in:**

- [§ 2. Definitions](#ref-for-dfn-media-segment-1 "§ 2. Definitions")
  [(2)](#ref-for-dfn-media-segment-2 "Reference 2")
  [(3)](#ref-for-dfn-media-segment-3 "Reference 3")
- [§ 3.15.3 Seeking](#ref-for-dfn-media-segment-4 "§ 3.15.3 Seeking")
- [§ 5.1 Attributes](#ref-for-dfn-media-segment-5 "§ 5.1 Attributes")
  [(2)](#ref-for-dfn-media-segment-6 "Reference 2")
- [§ 5.3 Track
  Buffers](#ref-for-dfn-media-segment-7 "§ 5.3 Track Buffers")
- [§ 5.5.1 Segment Parser
  Loop](#ref-for-dfn-media-segment-8 "§ 5.5.1 Segment Parser Loop")
  [(2)](#ref-for-dfn-media-segment-9 "Reference 2")
  [(3)](#ref-for-dfn-media-segment-10 "Reference 3")
  [(4)](#ref-for-dfn-media-segment-11 "Reference 4")
  [(5)](#ref-for-dfn-media-segment-12 "Reference 5")
- [§ 5.5.8 Coded Frame
  Processing](#ref-for-dfn-media-segment-13 "§ 5.5.8 Coded Frame Processing")
  [(2)](#ref-for-dfn-media-segment-14 "Reference 2")
- [§ 14. Byte Stream
  Formats](#ref-for-dfn-media-segment-15 "§ 14. Byte Stream Formats")
  [(2)](#ref-for-dfn-media-segment-16 "Reference 2")
  [(3)](#ref-for-dfn-media-segment-17 "Reference 3")
  [(4)](#ref-for-dfn-media-segment-18 "Reference 4")
  [(5)](#ref-for-dfn-media-segment-19 "Reference 5")
  [(6)](#ref-for-dfn-media-segment-20 "Reference 6")
  [(7)](#ref-for-dfn-media-segment-21 "Reference 7")
::::

:::: {#dfn-panel-for-mediasource-object-url .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: MediaSource object URL"}
[]{.caret}

::: {}
[Permalink](#mediasource-object-url){.self-link
aria-label="Permalink for definition: MediaSource object URL. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 3.14 Cross-context communication
  model](#ref-for-mediasource-object-url-1 "§ 3.14 Cross-context communication model")
- [§ 3.15.1 Attaching to a media
  element](#ref-for-mediasource-object-url-2 "§ 3.15.1 Attaching to a media element")
  [(2)](#ref-for-mediasource-object-url-3 "Reference 2")
  [(3)](#ref-for-mediasource-object-url-4 "Reference 3")
  [(4)](#ref-for-mediasource-object-url-5 "Reference 4")
  [(5)](#ref-for-mediasource-object-url-6 "Reference 5")
  [(6)](#ref-for-mediasource-object-url-7 "Reference 6")
  [(7)](#ref-for-mediasource-object-url-8 "Reference 7")
  [(8)](#ref-for-mediasource-object-url-9 "Reference 8")
  [(9)](#ref-for-mediasource-object-url-10 "Reference 9")
- [§ 4.1 Transfer](#ref-for-mediasource-object-url-11 "§ 4.1 Transfer")
  [(2)](#ref-for-mediasource-object-url-12 "Reference 2")
  [(3)](#ref-for-mediasource-object-url-13 "Reference 3")
::::

:::: {#dfn-panel-for-parent-media-source .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Parent Media Source"}
[]{.caret}

::: {}
[Permalink](#parent-media-source){.self-link
aria-label="Permalink for definition: Parent Media Source. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.1 Attributes](#ref-for-parent-media-source-1 "§ 5.1 Attributes")
  [(2)](#ref-for-parent-media-source-2 "Reference 2")
  [(3)](#ref-for-parent-media-source-3 "Reference 3")
  [(4)](#ref-for-parent-media-source-4 "Reference 4")
  [(5)](#ref-for-parent-media-source-5 "Reference 5")
  [(6)](#ref-for-parent-media-source-6 "Reference 6")
  [(7)](#ref-for-parent-media-source-7 "Reference 7")
  [(8)](#ref-for-parent-media-source-8 "Reference 8")
  [(9)](#ref-for-parent-media-source-9 "Reference 9")
  [(10)](#ref-for-parent-media-source-10 "Reference 10")
  [(11)](#ref-for-parent-media-source-11 "Reference 11")
- [§ 5.2 Methods](#ref-for-parent-media-source-12 "§ 5.2 Methods")
  [(2)](#ref-for-parent-media-source-13 "Reference 2")
  [(3)](#ref-for-parent-media-source-14 "Reference 3")
  [(4)](#ref-for-parent-media-source-15 "Reference 4")
  [(5)](#ref-for-parent-media-source-16 "Reference 5")
  [(6)](#ref-for-parent-media-source-17 "Reference 6")
  [(7)](#ref-for-parent-media-source-18 "Reference 7")
  [(8)](#ref-for-parent-media-source-19 "Reference 8")
  [(9)](#ref-for-parent-media-source-20 "Reference 9")
  [(10)](#ref-for-parent-media-source-21 "Reference 10")
  [(11)](#ref-for-parent-media-source-22 "Reference 11")
- [§ 5.5.4 Prepare
  Append](#ref-for-parent-media-source-23 "§ 5.5.4 Prepare Append")
  [(2)](#ref-for-parent-media-source-24 "Reference 2")
  [(3)](#ref-for-parent-media-source-25 "Reference 3")
  [(4)](#ref-for-parent-media-source-26 "Reference 4")
- [§ 5.5.7 Initialization Segment
  Received](#ref-for-parent-media-source-27 "§ 5.5.7 Initialization Segment Received")
  [(2)](#ref-for-parent-media-source-28 "Reference 2")
  [(3)](#ref-for-parent-media-source-29 "Reference 3")
  [(4)](#ref-for-parent-media-source-30 "Reference 4")
  [(5)](#ref-for-parent-media-source-31 "Reference 5")
  [(6)](#ref-for-parent-media-source-32 "Reference 6")
- [§ Attributes](#ref-for-parent-media-source-33 "§ Attributes")
  [(2)](#ref-for-parent-media-source-34 "Reference 2")
  [(3)](#ref-for-parent-media-source-35 "Reference 3")
::::

:::: {#dfn-panel-for-presentation-start-time .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Presentation Start Time"}
[]{.caret}

::: {}
[Permalink](#presentation-start-time){.self-link
aria-label="Permalink for definition: Presentation Start Time. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 2.
  Definitions](#ref-for-presentation-start-time-1 "§ 2. Definitions")
  [(2)](#ref-for-presentation-start-time-2 "Reference 2")
  [(3)](#ref-for-presentation-start-time-3 "Reference 3")
- [§ 5.1
  Attributes](#ref-for-presentation-start-time-4 "§ 5.1 Attributes")
- [§ 5.2 Methods](#ref-for-presentation-start-time-5 "§ 5.2 Methods")
  [(2)](#ref-for-presentation-start-time-6 "Reference 2")
  [(3)](#ref-for-presentation-start-time-7 "Reference 3")
- [§ 5.5.6 Range
  Removal](#ref-for-presentation-start-time-8 "§ 5.5.6 Range Removal")
  [(2)](#ref-for-presentation-start-time-9 "Reference 2")
::::

:::: {#dfn-panel-for-presentation-interval .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Presentation Interval"}
[]{.caret}

::: {}
[Permalink](#presentation-interval){.self-link
aria-label="Permalink for definition: Presentation Interval. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.5.8 Coded Frame
  Processing](#ref-for-presentation-interval-1 "§ 5.5.8 Coded Frame Processing")
- [§ 5.5.11 Audio Splice
  Frame](#ref-for-presentation-interval-2 "§ 5.5.11 Audio Splice Frame")
- [§ 5.5.13 Text Splice
  Frame](#ref-for-presentation-interval-3 "§ 5.5.13 Text Splice Frame")
::::

:::: {#dfn-panel-for-presentation-order .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Presentation Order"}
[]{.caret}

::: {}
[Permalink](#presentation-order){.self-link
aria-label="Permalink for definition: Presentation Order. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 2. Definitions](#ref-for-presentation-order-1 "§ 2. Definitions")
  [(2)](#ref-for-presentation-order-2 "Reference 2")
  [(3)](#ref-for-presentation-order-3 "Reference 3")
::::

:::: {#dfn-panel-for-presentation-timestamp .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Presentation Timestamp"}
[]{.caret}

::: {}
[Permalink](#presentation-timestamp){.self-link
aria-label="Permalink for definition: Presentation Timestamp. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
:::

**Referenced in:**

- [§ 2.
  Definitions](#ref-for-presentation-timestamp-1 "§ 2. Definitions")
  [(2)](#ref-for-presentation-timestamp-2 "Reference 2")
  [(3)](#ref-for-presentation-timestamp-3 "Reference 3")
  [(4)](#ref-for-presentation-timestamp-4 "Reference 4")
  [(5)](#ref-for-presentation-timestamp-5 "Reference 5")
  [(6)](#ref-for-presentation-timestamp-6 "Reference 6")
  [(7)](#ref-for-presentation-timestamp-7 "Reference 7")
  [(8)](#ref-for-presentation-timestamp-8 "Reference 8")
  [(9)](#ref-for-presentation-timestamp-9 "Reference 9")
  [(10)](#ref-for-presentation-timestamp-10 "Reference 10")
- [§ 3.15.6 Duration
  change](#ref-for-presentation-timestamp-11 "§ 3.15.6 Duration change")
- [§ 5.1
  Attributes](#ref-for-presentation-timestamp-12 "§ 5.1 Attributes")
  [(2)](#ref-for-presentation-timestamp-13 "Reference 2")
- [§ 5.3 Track
  Buffers](#ref-for-presentation-timestamp-14 "§ 5.3 Track Buffers")
  [(2)](#ref-for-presentation-timestamp-15 "Reference 2")
- [§ 5.5.6 Range
  Removal](#ref-for-presentation-timestamp-16 "§ 5.5.6 Range Removal")
  [(2)](#ref-for-presentation-timestamp-17 "Reference 2")
- [§ 5.5.8 Coded Frame
  Processing](#ref-for-presentation-timestamp-18 "§ 5.5.8 Coded Frame Processing")
  [(2)](#ref-for-presentation-timestamp-19 "Reference 2")
  [(3)](#ref-for-presentation-timestamp-20 "Reference 3")
  [(4)](#ref-for-presentation-timestamp-21 "Reference 4")
  [(5)](#ref-for-presentation-timestamp-22 "Reference 5")
- [§ 5.5.9 Coded Frame
  Removal](#ref-for-presentation-timestamp-23 "§ 5.5.9 Coded Frame Removal")
  [(2)](#ref-for-presentation-timestamp-24 "Reference 2")
  [(3)](#ref-for-presentation-timestamp-25 "Reference 3")
- [§ 5.5.11 Audio Splice
  Frame](#ref-for-presentation-timestamp-26 "§ 5.5.11 Audio Splice Frame")
  [(2)](#ref-for-presentation-timestamp-27 "Reference 2")
  [(3)](#ref-for-presentation-timestamp-28 "Reference 3")
  [(4)](#ref-for-presentation-timestamp-29 "Reference 4")
  [(5)](#ref-for-presentation-timestamp-30 "Reference 5")
  [(6)](#ref-for-presentation-timestamp-31 "Reference 6")
  [(7)](#ref-for-presentation-timestamp-32 "Reference 7")
  [(8)](#ref-for-presentation-timestamp-33 "Reference 8")
  [(9)](#ref-for-presentation-timestamp-34 "Reference 9")
- [§ 5.5.12 Audio Splice
  Rendering](#ref-for-presentation-timestamp-35 "§ 5.5.12 Audio Splice Rendering")
  [(2)](#ref-for-presentation-timestamp-36 "Reference 2")
  [(3)](#ref-for-presentation-timestamp-37 "Reference 3")
  [(4)](#ref-for-presentation-timestamp-38 "Reference 4")
- [§ 5.5.13 Text Splice
  Frame](#ref-for-presentation-timestamp-39 "§ 5.5.13 Text Splice Frame")
  [(2)](#ref-for-presentation-timestamp-40 "Reference 2")
  [(3)](#ref-for-presentation-timestamp-41 "Reference 3")
- [§ 14. Byte Stream
  Formats](#ref-for-presentation-timestamp-42 "§ 14. Byte Stream Formats")
::::

:::: {#dfn-panel-for-random-access-point .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Random Access Point"}
[]{.caret}

::: {}
[Permalink](#random-access-point){.self-link
aria-label="Permalink for definition: Random Access Point. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
:::

**Referenced in:**

- [§ 3.15.3 Seeking](#ref-for-random-access-point-1 "§ 3.15.3 Seeking")
- [§ 5.3 Track
  Buffers](#ref-for-random-access-point-2 "§ 5.3 Track Buffers")
  [(2)](#ref-for-random-access-point-3 "Reference 2")
- [§ 5.5.8 Coded Frame
  Processing](#ref-for-random-access-point-4 "§ 5.5.8 Coded Frame Processing")
  [(2)](#ref-for-random-access-point-5 "Reference 2")
  [(3)](#ref-for-random-access-point-6 "Reference 3")
  [(4)](#ref-for-random-access-point-7 "Reference 4")
- [§ 5.5.9 Coded Frame
  Removal](#ref-for-random-access-point-8 "§ 5.5.9 Coded Frame Removal")
  [(2)](#ref-for-random-access-point-9 "Reference 2")
  [(3)](#ref-for-random-access-point-10 "Reference 3")
- [§ 14. Byte Stream
  Formats](#ref-for-random-access-point-11 "§ 14. Byte Stream Formats")
::::

:::: {#dfn-panel-for-dfn-sourcebuffer-byte-stream-format-specification .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: SourceBuffer byte stream format specification"}
[]{.caret}

::: {}
[Permalink](#dfn-sourcebuffer-byte-stream-format-specification){.self-link
aria-label="Permalink for definition: SourceBuffer byte stream format specification. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.5.1 Segment Parser
  Loop](#ref-for-dfn-sourcebuffer-byte-stream-format-specification-1 "§ 5.5.1 Segment Parser Loop")
::::

:::: {#dfn-panel-for-dfn-sourcebuffer-configuration .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: SourceBuffer configuration"}
[]{.caret}

::: {}
[Permalink](#dfn-sourcebuffer-configuration){.self-link
aria-label="Permalink for definition: SourceBuffer configuration. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 3.7 addSourceBuffer()
  method](#ref-for-dfn-sourcebuffer-configuration-1 "§ 3.7 addSourceBuffer() method")
::::

:::: {#dfn-panel-for-dfn-track-description .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Track Description"}
[]{.caret}

::: {}
[Permalink](#dfn-track-description){.self-link
aria-label="Permalink for definition: Track Description. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 2.
  Definitions](#ref-for-dfn-track-description-1 "§ 2. Definitions")
- [§ 5.3 Track
  Buffers](#ref-for-dfn-track-description-2 "§ 5.3 Track Buffers")
- [§ 5.5.7 Initialization Segment
  Received](#ref-for-dfn-track-description-3 "§ 5.5.7 Initialization Segment Received")
  [(2)](#ref-for-dfn-track-description-4 "Reference 2")
  [(3)](#ref-for-dfn-track-description-5 "Reference 3")
  [(4)](#ref-for-dfn-track-description-6 "Reference 4")
::::

:::: {#dfn-panel-for-dfn-track-id .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Track ID"}
[]{.caret}

::: {}
[Permalink](#dfn-track-id){.self-link
aria-label="Permalink for definition: Track ID. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 2. Definitions](#ref-for-dfn-track-id-1 "§ 2. Definitions")
  [(2)](#ref-for-dfn-track-id-2 "Reference 2")
  [(3)](#ref-for-dfn-track-id-3 "Reference 3")
  [(4)](#ref-for-dfn-track-id-4 "Reference 4")
- [§ 5.5.7 Initialization Segment
  Received](#ref-for-dfn-track-id-5 "§ 5.5.7 Initialization Segment Received")
  [(2)](#ref-for-dfn-track-id-6 "Reference 2")
  [(3)](#ref-for-dfn-track-id-7 "Reference 3")
  [(4)](#ref-for-dfn-track-id-8 "Reference 4")
- [§ 14. Byte Stream
  Formats](#ref-for-dfn-track-id-9 "§ 14. Byte Stream Formats")
  [(2)](#ref-for-dfn-track-id-10 "Reference 2")
::::

:::: {#dfn-panel-for-dom-mediasource .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: MediaSource"}
[]{.caret}

::: {}
[Permalink](#dom-mediasource){.self-link
aria-label="Permalink for definition: MediaSource. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-1502719514 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ Status of This
  Document](#ref-for-dom-mediasource-1 "§ Status of This Document")
- [§ 2. Definitions](#ref-for-dom-mediasource-2 "§ 2. Definitions")
  [(2)](#ref-for-dom-mediasource-3 "Reference 2")
  [(3)](#ref-for-dom-mediasource-4 "Reference 3")
  [(4)](#ref-for-dom-mediasource-5 "Reference 4")
  [(5)](#ref-for-dom-mediasource-6 "Reference 5")
  [(6)](#ref-for-dom-mediasource-7 "Reference 6")
- [§ 3. MediaSource
  interface](#ref-for-dom-mediasource-8 "§ 3. MediaSource interface")
  [(2)](#ref-for-dom-mediasource-9 "Reference 2")
  [(3)](#ref-for-dom-mediasource-10 "Reference 3")
  [(4)](#ref-for-dom-mediasource-11 "Reference 4")
  [(5)](#ref-for-dom-mediasource-12 "Reference 5")
  [(6)](#ref-for-dom-mediasource-13 "Reference 6")
  [(7)](#ref-for-dom-mediasource-14 "Reference 7")
  [(8)](#ref-for-dom-mediasource-15 "Reference 8")
  [(9)](#ref-for-dom-mediasource-16 "Reference 9")
  [(10)](#ref-for-dom-mediasource-17 "Reference 10")
  [(11)](#ref-for-dom-mediasource-18 "Reference 11")
- [§ 3.1 handle
  attribute](#ref-for-dom-mediasource-19 "§ 3.1 handle attribute")
  [(2)](#ref-for-dom-mediasource-20 "Reference 2")
  [(3)](#ref-for-dom-mediasource-21 "Reference 3")
  [(4)](#ref-for-dom-mediasource-22 "Reference 4")
  [(5)](#ref-for-dom-mediasource-23 "Reference 5")
  [(6)](#ref-for-dom-mediasource-24 "Reference 6")
- [§ 3.2 sourceBuffers
  attribute](#ref-for-dom-mediasource-25 "§ 3.2 sourceBuffers attribute")
  [(2)](#ref-for-dom-mediasource-26 "Reference 2")
- [§ 3.4 readyState
  attribute](#ref-for-dom-mediasource-27 "§ 3.4 readyState attribute")
  [(2)](#ref-for-dom-mediasource-28 "Reference 2")
- [§ 3.5 duration
  attribute](#ref-for-dom-mediasource-29 "§ 3.5 duration attribute")
- [§ 3.6 canConstructInDedicatedWorker
  attribute](#ref-for-dom-mediasource-30 "§ 3.6 canConstructInDedicatedWorker attribute")
  [(2)](#ref-for-dom-mediasource-31 "Reference 2")
- [§ 3.8 removeSourceBuffer()
  method](#ref-for-dom-mediasource-32 "§ 3.8 removeSourceBuffer() method")
  [(2)](#ref-for-dom-mediasource-33 "Reference 2")
  [(3)](#ref-for-dom-mediasource-34 "Reference 3")
- [§ 3.12 isTypeSupported()
  method](#ref-for-dom-mediasource-35 "§ 3.12 isTypeSupported() method")
  [(2)](#ref-for-dom-mediasource-36 "Reference 2")
  [(3)](#ref-for-dom-mediasource-37 "Reference 3")
- [§ 3.13 Event
  Summary](#ref-for-dom-mediasource-38 "§ 3.13 Event Summary")
  [(2)](#ref-for-dom-mediasource-39 "Reference 2")
  [(3)](#ref-for-dom-mediasource-40 "Reference 3")
- [§ 3.14 Cross-context communication
  model](#ref-for-dom-mediasource-41 "§ 3.14 Cross-context communication model")
  [(2)](#ref-for-dom-mediasource-42 "Reference 2")
  [(3)](#ref-for-dom-mediasource-43 "Reference 3")
  [(4)](#ref-for-dom-mediasource-44 "Reference 4")
  [(5)](#ref-for-dom-mediasource-45 "Reference 5")
  [(6)](#ref-for-dom-mediasource-46 "Reference 6")
  [(7)](#ref-for-dom-mediasource-47 "Reference 7")
  [(8)](#ref-for-dom-mediasource-48 "Reference 8")
  [(9)](#ref-for-dom-mediasource-49 "Reference 9")
  [(10)](#ref-for-dom-mediasource-50 "Reference 10")
- [§ 3.15.1 Attaching to a media
  element](#ref-for-dom-mediasource-51 "§ 3.15.1 Attaching to a media element")
  [(2)](#ref-for-dom-mediasource-52 "Reference 2")
  [(3)](#ref-for-dom-mediasource-53 "Reference 3")
  [(4)](#ref-for-dom-mediasource-54 "Reference 4")
  [(5)](#ref-for-dom-mediasource-55 "Reference 5")
  [(6)](#ref-for-dom-mediasource-56 "Reference 6")
  [(7)](#ref-for-dom-mediasource-57 "Reference 7")
  [(8)](#ref-for-dom-mediasource-58 "Reference 8")
  [(9)](#ref-for-dom-mediasource-59 "Reference 9")
  [(10)](#ref-for-dom-mediasource-60 "Reference 10")
  [(11)](#ref-for-dom-mediasource-61 "Reference 11")
  [(12)](#ref-for-dom-mediasource-62 "Reference 12")
  [(13)](#ref-for-dom-mediasource-63 "Reference 13")
  [(14)](#ref-for-dom-mediasource-64 "Reference 14")
  [(15)](#ref-for-dom-mediasource-65 "Reference 15")
  [(16)](#ref-for-dom-mediasource-66 "Reference 16")
  [(17)](#ref-for-dom-mediasource-67 "Reference 17")
  [(18)](#ref-for-dom-mediasource-68 "Reference 18")
  [(19)](#ref-for-dom-mediasource-69 "Reference 19")
  [(20)](#ref-for-dom-mediasource-70 "Reference 20")
  [(21)](#ref-for-dom-mediasource-71 "Reference 21")
  [(22)](#ref-for-dom-mediasource-72 "Reference 22")
  [(23)](#ref-for-dom-mediasource-73 "Reference 23")
  [(24)](#ref-for-dom-mediasource-74 "Reference 24")
  [(25)](#ref-for-dom-mediasource-75 "Reference 25")
  [(26)](#ref-for-dom-mediasource-76 "Reference 26")
  [(27)](#ref-for-dom-mediasource-77 "Reference 27")
  [(28)](#ref-for-dom-mediasource-78 "Reference 28")
- [§ 3.15.2 Detaching from a media
  element](#ref-for-dom-mediasource-79 "§ 3.15.2 Detaching from a media element")
  [(2)](#ref-for-dom-mediasource-80 "Reference 2")
  [(3)](#ref-for-dom-mediasource-81 "Reference 3")
  [(4)](#ref-for-dom-mediasource-82 "Reference 4")
  [(5)](#ref-for-dom-mediasource-83 "Reference 5")
  [(6)](#ref-for-dom-mediasource-84 "Reference 6")
  [(7)](#ref-for-dom-mediasource-85 "Reference 7")
- [§ 3.15.5 Changes to selected/enabled track
  state](#ref-for-dom-mediasource-86 "§ 3.15.5 Changes to selected/enabled track state")
- [§ 3.15.7 End of
  stream](#ref-for-dom-mediasource-87 "§ 3.15.7 End of stream")
- [§ 3.15.8 Mirror if
  necessary](#ref-for-dom-mediasource-88 "§ 3.15.8 Mirror if necessary")
  [(2)](#ref-for-dom-mediasource-89 "Reference 2")
- [§ 4. MediaSourceHandle
  interface](#ref-for-dom-mediasource-90 "§ 4. MediaSourceHandle interface")
  [(2)](#ref-for-dom-mediasource-91 "Reference 2")
  [(3)](#ref-for-dom-mediasource-92 "Reference 3")
  [(4)](#ref-for-dom-mediasource-93 "Reference 4")
- [§ 4.1 Transfer](#ref-for-dom-mediasource-94 "§ 4.1 Transfer")
  [(2)](#ref-for-dom-mediasource-95 "Reference 2")
  [(3)](#ref-for-dom-mediasource-96 "Reference 3")
  [(4)](#ref-for-dom-mediasource-97 "Reference 4")
- [§ 5.5.4 Prepare
  Append](#ref-for-dom-mediasource-98 "§ 5.5.4 Prepare Append")
- [§ 7. ManagedMediaSource
  interface](#ref-for-dom-mediasource-99 "§ 7. ManagedMediaSource interface")
  [(2)](#ref-for-dom-mediasource-100 "Reference 2")
  [(3)](#ref-for-dom-mediasource-101 "Reference 3")
- [§ 7.3.1 ManagedSourceBuffer
  Monitoring](#ref-for-dom-mediasource-102 "§ 7.3.1 ManagedSourceBuffer Monitoring")
- [§ 10. HTMLMediaElement
  Extensions](#ref-for-dom-mediasource-103 "§ 10. HTMLMediaElement Extensions")
- [§ 10.1 HTMLMediaElement\'s
  seekable](#ref-for-dom-mediasource-104 "§ 10.1 HTMLMediaElement's seekable")
  [(2)](#ref-for-dom-mediasource-105 "Reference 2")
  [(3)](#ref-for-dom-mediasource-106 "Reference 3")
- [§ 10.2 HTMLMediaElement\'s
  buffered](#ref-for-dom-mediasource-107 "§ 10.2 HTMLMediaElement's buffered")
  [(2)](#ref-for-dom-mediasource-108 "Reference 2")
  [(3)](#ref-for-dom-mediasource-109 "Reference 3")
::::

:::: {#dfn-panel-for-dfn-live-seekable-range .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: [[live seekable range]]"}
[]{.caret}

::: {}
[Permalink](#dfn-live-seekable-range){.self-link
aria-label="Permalink for definition: [[live seekable range]]. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 3.10 setLiveSeekableRange()
  method](#ref-for-dfn-live-seekable-range-1 "§ 3.10 setLiveSeekableRange() method")
  [(2)](#ref-for-dfn-live-seekable-range-2 "Reference 2")
- [§ 3.11 clearLiveSeekableRange()
  method](#ref-for-dfn-live-seekable-range-3 "§ 3.11 clearLiveSeekableRange() method")
  [(2)](#ref-for-dfn-live-seekable-range-4 "Reference 2")
  [(3)](#ref-for-dfn-live-seekable-range-5 "Reference 3")
- [§ 10.1 HTMLMediaElement\'s
  seekable](#ref-for-dfn-live-seekable-range-6 "§ 10.1 HTMLMediaElement's seekable")
  [(2)](#ref-for-dfn-live-seekable-range-7 "Reference 2")
  [(3)](#ref-for-dfn-live-seekable-range-8 "Reference 3")
  [(4)](#ref-for-dfn-live-seekable-range-9 "Reference 4")
::::

:::: {#dfn-panel-for-dfn-has-ever-been-attached .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: [[has ever been attached]]"}
[]{.caret}

::: {}
[Permalink](#dfn-has-ever-been-attached){.self-link
aria-label="Permalink for definition: [[has ever been attached]]. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 3.15.1 Attaching to a media
  element](#ref-for-dfn-has-ever-been-attached-1 "§ 3.15.1 Attaching to a media element")
  [(2)](#ref-for-dfn-has-ever-been-attached-2 "Reference 2")
::::

:::: {#dfn-panel-for-dom-readystate .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: ReadyState"}
[]{.caret}

::: {}
[Permalink](#dom-readystate){.self-link
aria-label="Permalink for definition: ReadyState. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
:::

**Referenced in:**

- [§ 3. MediaSource
  interface](#ref-for-dom-readystate-1 "§ 3. MediaSource interface")
- [§ 3.15.3 Seeking](#ref-for-dom-readystate-2 "§ 3.15.3 Seeking")
  [(2)](#ref-for-dom-readystate-3 "Reference 2")
  [(3)](#ref-for-dom-readystate-4 "Reference 3")
  [(4)](#ref-for-dom-readystate-5 "Reference 4")
- [§ 3.15.4 SourceBuffer
  Monitoring](#ref-for-dom-readystate-6 "§ 3.15.4 SourceBuffer Monitoring")
  [(2)](#ref-for-dom-readystate-7 "Reference 2")
  [(3)](#ref-for-dom-readystate-8 "Reference 3")
  [(4)](#ref-for-dom-readystate-9 "Reference 4")
  [(5)](#ref-for-dom-readystate-10 "Reference 5")
  [(6)](#ref-for-dom-readystate-11 "Reference 6")
  [(7)](#ref-for-dom-readystate-12 "Reference 7")
  [(8)](#ref-for-dom-readystate-13 "Reference 8")
  [(9)](#ref-for-dom-readystate-14 "Reference 9")
  [(10)](#ref-for-dom-readystate-15 "Reference 10")
- [§ 3.15.7 End of
  stream](#ref-for-dom-readystate-16 "§ 3.15.7 End of stream")
  [(2)](#ref-for-dom-readystate-17 "Reference 2")
  [(3)](#ref-for-dom-readystate-18 "Reference 3")
  [(4)](#ref-for-dom-readystate-19 "Reference 4")
- [§ 5.5.7 Initialization Segment
  Received](#ref-for-dom-readystate-20 "§ 5.5.7 Initialization Segment Received")
  [(2)](#ref-for-dom-readystate-21 "Reference 2")
  [(3)](#ref-for-dom-readystate-22 "Reference 3")
  [(4)](#ref-for-dom-readystate-23 "Reference 4")
  [(5)](#ref-for-dom-readystate-24 "Reference 5")
  [(6)](#ref-for-dom-readystate-25 "Reference 6")
- [§ 5.5.8 Coded Frame
  Processing](#ref-for-dom-readystate-26 "§ 5.5.8 Coded Frame Processing")
  [(2)](#ref-for-dom-readystate-27 "Reference 2")
  [(3)](#ref-for-dom-readystate-28 "Reference 3")
  [(4)](#ref-for-dom-readystate-29 "Reference 4")
  [(5)](#ref-for-dom-readystate-30 "Reference 5")
  [(6)](#ref-for-dom-readystate-31 "Reference 6")
  [(7)](#ref-for-dom-readystate-32 "Reference 7")
  [(8)](#ref-for-dom-readystate-33 "Reference 8")
  [(9)](#ref-for-dom-readystate-34 "Reference 9")
- [§ 5.5.9 Coded Frame
  Removal](#ref-for-dom-readystate-35 "§ 5.5.9 Coded Frame Removal")
  [(2)](#ref-for-dom-readystate-36 "Reference 2")
  [(3)](#ref-for-dom-readystate-37 "Reference 3")
::::

:::: {#dfn-panel-for-dom-readystate-closed .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: closed"}
[]{.caret}

::: {}
[Permalink](#dom-readystate-closed){.self-link
aria-label="Permalink for definition: closed. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-26865842 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3. MediaSource
  interface](#ref-for-dom-readystate-closed-1 "§ 3. MediaSource interface")
- [§ 3.2 sourceBuffers
  attribute](#ref-for-dom-readystate-closed-2 "§ 3.2 sourceBuffers attribute")
- [§ 3.4 readyState
  attribute](#ref-for-dom-readystate-closed-3 "§ 3.4 readyState attribute")
- [§ 3.5 duration
  attribute](#ref-for-dom-readystate-closed-4 "§ 3.5 duration attribute")
- [§ 3.13 Event
  Summary](#ref-for-dom-readystate-closed-5 "§ 3.13 Event Summary")
  [(2)](#ref-for-dom-readystate-closed-6 "Reference 2")
  [(3)](#ref-for-dom-readystate-closed-7 "Reference 3")
- [§ 3.15.1 Attaching to a media
  element](#ref-for-dom-readystate-closed-8 "§ 3.15.1 Attaching to a media element")
- [§ 3.15.2 Detaching from a media
  element](#ref-for-dom-readystate-closed-9 "§ 3.15.2 Detaching from a media element")
::::

:::: {#dfn-panel-for-dom-readystate-open .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: open"}
[]{.caret}

::: {}
[Permalink](#dom-readystate-open){.self-link
aria-label="Permalink for definition: open. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-26865842 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3. MediaSource
  interface](#ref-for-dom-readystate-open-1 "§ 3. MediaSource interface")
- [§ 3.2 sourceBuffers
  attribute](#ref-for-dom-readystate-open-2 "§ 3.2 sourceBuffers attribute")
- [§ 3.5 duration
  attribute](#ref-for-dom-readystate-open-3 "§ 3.5 duration attribute")
- [§ 3.7 addSourceBuffer()
  method](#ref-for-dom-readystate-open-4 "§ 3.7 addSourceBuffer() method")
- [§ 3.9 endOfStream()
  method](#ref-for-dom-readystate-open-5 "§ 3.9 endOfStream() method")
- [§ 3.10 setLiveSeekableRange()
  method](#ref-for-dom-readystate-open-6 "§ 3.10 setLiveSeekableRange() method")
- [§ 3.11 clearLiveSeekableRange()
  method](#ref-for-dom-readystate-open-7 "§ 3.11 clearLiveSeekableRange() method")
- [§ 3.13 Event
  Summary](#ref-for-dom-readystate-open-8 "§ 3.13 Event Summary")
  [(2)](#ref-for-dom-readystate-open-9 "Reference 2")
  [(3)](#ref-for-dom-readystate-open-10 "Reference 3")
  [(4)](#ref-for-dom-readystate-open-11 "Reference 4")
- [§ 3.15.1 Attaching to a media
  element](#ref-for-dom-readystate-open-12 "§ 3.15.1 Attaching to a media element")
  [(2)](#ref-for-dom-readystate-open-13 "Reference 2")
- [§ 5.1 Attributes](#ref-for-dom-readystate-open-14 "§ 5.1 Attributes")
  [(2)](#ref-for-dom-readystate-open-15 "Reference 2")
- [§ 5.2 Methods](#ref-for-dom-readystate-open-16 "§ 5.2 Methods")
  [(2)](#ref-for-dom-readystate-open-17 "Reference 2")
  [(3)](#ref-for-dom-readystate-open-18 "Reference 3")
- [§ 5.5.4 Prepare
  Append](#ref-for-dom-readystate-open-19 "§ 5.5.4 Prepare Append")
::::

:::: {#dfn-panel-for-dom-readystate-ended .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: ended"}
[]{.caret}

::: {}
[Permalink](#dom-readystate-ended){.self-link
aria-label="Permalink for definition: ended. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-26865842 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3. MediaSource
  interface](#ref-for-dom-readystate-ended-1 "§ 3. MediaSource interface")
- [§ 3.13 Event
  Summary](#ref-for-dom-readystate-ended-2 "§ 3.13 Event Summary")
  [(2)](#ref-for-dom-readystate-ended-3 "Reference 2")
  [(3)](#ref-for-dom-readystate-ended-4 "Reference 3")
- [§ 3.15.3 Seeking](#ref-for-dom-readystate-ended-5 "§ 3.15.3 Seeking")
  [(2)](#ref-for-dom-readystate-ended-6 "Reference 2")
- [§ 3.15.7 End of
  stream](#ref-for-dom-readystate-ended-7 "§ 3.15.7 End of stream")
- [§ 5.1 Attributes](#ref-for-dom-readystate-ended-8 "§ 5.1 Attributes")
  [(2)](#ref-for-dom-readystate-ended-9 "Reference 2")
  [(3)](#ref-for-dom-readystate-ended-10 "Reference 3")
- [§ 5.2 Methods](#ref-for-dom-readystate-ended-11 "§ 5.2 Methods")
  [(2)](#ref-for-dom-readystate-ended-12 "Reference 2")
- [§ 5.5.4 Prepare
  Append](#ref-for-dom-readystate-ended-13 "§ 5.5.4 Prepare Append")
- [§ 10.2 HTMLMediaElement\'s
  buffered](#ref-for-dom-readystate-ended-14 "§ 10.2 HTMLMediaElement's buffered")
::::

:::: {#dfn-panel-for-dom-endofstreamerror .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: EndOfStreamError"}
[]{.caret}

::: {}
[Permalink](#dom-endofstreamerror){.self-link
aria-label="Permalink for definition: EndOfStreamError. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
:::

**Referenced in:**

- [§ 3. MediaSource
  interface](#ref-for-dom-endofstreamerror-1 "§ 3. MediaSource interface")
::::

:::: {#dfn-panel-for-dom-endofstreamerror-network .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: network"}
[]{.caret}

::: {}
[Permalink](#dom-endofstreamerror-network){.self-link
aria-label="Permalink for definition: network. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-1031259774 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3. MediaSource
  interface](#ref-for-dom-endofstreamerror-network-1 "§ 3. MediaSource interface")
- [§ 3.15.7 End of
  stream](#ref-for-dom-endofstreamerror-network-2 "§ 3.15.7 End of stream")
::::

:::: {#dfn-panel-for-dom-endofstreamerror-decode .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: decode"}
[]{.caret}

::: {}
[Permalink](#dom-endofstreamerror-decode){.self-link
aria-label="Permalink for definition: decode. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-1031259774 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3. MediaSource
  interface](#ref-for-dom-endofstreamerror-decode-1 "§ 3. MediaSource interface")
- [§ 3.15.7 End of
  stream](#ref-for-dom-endofstreamerror-decode-2 "§ 3.15.7 End of stream")
- [§ 5.5.3 Append
  Error](#ref-for-dom-endofstreamerror-decode-3 "§ 5.5.3 Append Error")
::::

:::: {#dfn-panel-for-dom-mediasource-constructor .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: constructor"}
[]{.caret}

::: {}
[Permalink](#dom-mediasource-constructor){.self-link
aria-label="Permalink for definition: constructor. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
:::

**Referenced in:**

- Not referenced in this document.
::::

:::: {#dfn-panel-for-dom-mediasource-onsourceopen .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: onsourceopen"}
[]{.caret}

::: {}
[Permalink](#dom-mediasource-onsourceopen){.self-link
aria-label="Permalink for definition: onsourceopen. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
:::

**Referenced in:**

- Not referenced in this document.
::::

:::: {#dfn-panel-for-dom-mediasource-onsourceended .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: onsourceended"}
[]{.caret}

::: {}
[Permalink](#dom-mediasource-onsourceended){.self-link
aria-label="Permalink for definition: onsourceended. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
:::

**Referenced in:**

- Not referenced in this document.
::::

:::: {#dfn-panel-for-dom-mediasource-onsourceclose .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: onsourceclose"}
[]{.caret}

::: {}
[Permalink](#dom-mediasource-onsourceclose){.self-link
aria-label="Permalink for definition: onsourceclose. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
:::

**Referenced in:**

- Not referenced in this document.
::::

:::: {#dfn-panel-for-dom-mediasource-handle .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: handle"}
[]{.caret}

::: {}
[Permalink](#dom-mediasource-handle){.self-link
aria-label="Permalink for definition: handle. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-1502719514 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3. MediaSource
  interface](#ref-for-dom-mediasource-handle-1 "§ 3. MediaSource interface")
- [§ 3.15.1 Attaching to a media
  element](#ref-for-dom-mediasource-handle-2 "§ 3.15.1 Attaching to a media element")
  [(2)](#ref-for-dom-mediasource-handle-3 "Reference 2")
::::

:::: {#dfn-panel-for-dom-mediasource-sourcebuffers .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: sourceBuffers"}
[]{.caret}

::: {}
[Permalink](#dom-mediasource-sourcebuffers){.self-link
aria-label="Permalink for definition: sourceBuffers. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-1502719514 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3. MediaSource
  interface](#ref-for-dom-mediasource-sourcebuffers-1 "§ 3. MediaSource interface")
  [(2)](#ref-for-dom-mediasource-sourcebuffers-2 "Reference 2")
  [(3)](#ref-for-dom-mediasource-sourcebuffers-3 "Reference 3")
- [§ 3.3 activeSourceBuffers
  attribute](#ref-for-dom-mediasource-sourcebuffers-4 "§ 3.3 activeSourceBuffers attribute")
  [(2)](#ref-for-dom-mediasource-sourcebuffers-5 "Reference 2")
- [§ 3.5 duration
  attribute](#ref-for-dom-mediasource-sourcebuffers-6 "§ 3.5 duration attribute")
- [§ 3.7 addSourceBuffer()
  method](#ref-for-dom-mediasource-sourcebuffers-7 "§ 3.7 addSourceBuffer() method")
  [(2)](#ref-for-dom-mediasource-sourcebuffers-8 "Reference 2")
  [(3)](#ref-for-dom-mediasource-sourcebuffers-9 "Reference 3")
  [(4)](#ref-for-dom-mediasource-sourcebuffers-10 "Reference 4")
- [§ 3.8 removeSourceBuffer()
  method](#ref-for-dom-mediasource-sourcebuffers-11 "§ 3.8 removeSourceBuffer() method")
  [(2)](#ref-for-dom-mediasource-sourcebuffers-12 "Reference 2")
  [(3)](#ref-for-dom-mediasource-sourcebuffers-13 "Reference 3")
  [(4)](#ref-for-dom-mediasource-sourcebuffers-14 "Reference 4")
- [§ 3.9 endOfStream()
  method](#ref-for-dom-mediasource-sourcebuffers-15 "§ 3.9 endOfStream() method")
- [§ 3.15.2 Detaching from a media
  element](#ref-for-dom-mediasource-sourcebuffers-16 "§ 3.15.2 Detaching from a media element")
  [(2)](#ref-for-dom-mediasource-sourcebuffers-17 "Reference 2")
- [§ 3.15.6 Duration
  change](#ref-for-dom-mediasource-sourcebuffers-18 "§ 3.15.6 Duration change")
  [(2)](#ref-for-dom-mediasource-sourcebuffers-19 "Reference 2")
- [§ 3.15.7 End of
  stream](#ref-for-dom-mediasource-sourcebuffers-20 "§ 3.15.7 End of stream")
- [§ 5.1
  Attributes](#ref-for-dom-mediasource-sourcebuffers-21 "§ 5.1 Attributes")
  [(2)](#ref-for-dom-mediasource-sourcebuffers-22 "Reference 2")
  [(3)](#ref-for-dom-mediasource-sourcebuffers-23 "Reference 3")
  [(4)](#ref-for-dom-mediasource-sourcebuffers-24 "Reference 4")
  [(5)](#ref-for-dom-mediasource-sourcebuffers-25 "Reference 5")
- [§ 5.2
  Methods](#ref-for-dom-mediasource-sourcebuffers-26 "§ 5.2 Methods")
  [(2)](#ref-for-dom-mediasource-sourcebuffers-27 "Reference 2")
  [(3)](#ref-for-dom-mediasource-sourcebuffers-28 "Reference 3")
  [(4)](#ref-for-dom-mediasource-sourcebuffers-29 "Reference 4")
- [§ 5.5.4 Prepare
  Append](#ref-for-dom-mediasource-sourcebuffers-30 "§ 5.5.4 Prepare Append")
- [§ 5.5.7 Initialization Segment
  Received](#ref-for-dom-mediasource-sourcebuffers-31 "§ 5.5.7 Initialization Segment Received")
- [§ 7. ManagedMediaSource
  interface](#ref-for-dom-mediasource-sourcebuffers-32 "§ 7. ManagedMediaSource interface")
- [§ 7.3.2 Memory
  Cleanup](#ref-for-dom-mediasource-sourcebuffers-33 "§ 7.3.2 Memory Cleanup")
- [§
  Attributes](#ref-for-dom-mediasource-sourcebuffers-34 "§ Attributes")
  [(2)](#ref-for-dom-mediasource-sourcebuffers-35 "Reference 2")
  [(3)](#ref-for-dom-mediasource-sourcebuffers-36 "Reference 3")
::::

:::: {#dfn-panel-for-dom-mediasource-activesourcebuffers .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: activeSourceBuffers"}
[]{.caret}

::: {}
[Permalink](#dom-mediasource-activesourcebuffers){.self-link
aria-label="Permalink for definition: activeSourceBuffers. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-1502719514 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 2.
  Definitions](#ref-for-dom-mediasource-activesourcebuffers-1 "§ 2. Definitions")
- [§ 3. MediaSource
  interface](#ref-for-dom-mediasource-activesourcebuffers-2 "§ 3. MediaSource interface")
- [§ 3.3 activeSourceBuffers
  attribute](#ref-for-dom-mediasource-activesourcebuffers-3 "§ 3.3 activeSourceBuffers attribute")
- [§ 3.8 removeSourceBuffer()
  method](#ref-for-dom-mediasource-activesourcebuffers-4 "§ 3.8 removeSourceBuffer() method")
  [(2)](#ref-for-dom-mediasource-activesourcebuffers-5 "Reference 2")
  [(3)](#ref-for-dom-mediasource-activesourcebuffers-6 "Reference 3")
- [§ 3.15.2 Detaching from a media
  element](#ref-for-dom-mediasource-activesourcebuffers-7 "§ 3.15.2 Detaching from a media element")
  [(2)](#ref-for-dom-mediasource-activesourcebuffers-8 "Reference 2")
- [§ 3.15.3
  Seeking](#ref-for-dom-mediasource-activesourcebuffers-9 "§ 3.15.3 Seeking")
- [§ 3.15.4 SourceBuffer
  Monitoring](#ref-for-dom-mediasource-activesourcebuffers-10 "§ 3.15.4 SourceBuffer Monitoring")
  [(2)](#ref-for-dom-mediasource-activesourcebuffers-11 "Reference 2")
- [§ 3.15.5 Changes to selected/enabled track
  state](#ref-for-dom-mediasource-activesourcebuffers-12 "§ 3.15.5 Changes to selected/enabled track state")
  [(2)](#ref-for-dom-mediasource-activesourcebuffers-13 "Reference 2")
  [(3)](#ref-for-dom-mediasource-activesourcebuffers-14 "Reference 3")
  [(4)](#ref-for-dom-mediasource-activesourcebuffers-15 "Reference 4")
  [(5)](#ref-for-dom-mediasource-activesourcebuffers-16 "Reference 5")
  [(6)](#ref-for-dom-mediasource-activesourcebuffers-17 "Reference 6")
  [(7)](#ref-for-dom-mediasource-activesourcebuffers-18 "Reference 7")
  [(8)](#ref-for-dom-mediasource-activesourcebuffers-19 "Reference 8")
  [(9)](#ref-for-dom-mediasource-activesourcebuffers-20 "Reference 9")
  [(10)](#ref-for-dom-mediasource-activesourcebuffers-21 "Reference 10")
  [(11)](#ref-for-dom-mediasource-activesourcebuffers-22 "Reference 11")
  [(12)](#ref-for-dom-mediasource-activesourcebuffers-23 "Reference 12")
  [(13)](#ref-for-dom-mediasource-activesourcebuffers-24 "Reference 13")
  [(14)](#ref-for-dom-mediasource-activesourcebuffers-25 "Reference 14")
  [(15)](#ref-for-dom-mediasource-activesourcebuffers-26 "Reference 15")
  [(16)](#ref-for-dom-mediasource-activesourcebuffers-27 "Reference 16")
- [§ 5.5.7 Initialization Segment
  Received](#ref-for-dom-mediasource-activesourcebuffers-28 "§ 5.5.7 Initialization Segment Received")
  [(2)](#ref-for-dom-mediasource-activesourcebuffers-29 "Reference 2")
- [§ 5.5.9 Coded Frame
  Removal](#ref-for-dom-mediasource-activesourcebuffers-30 "§ 5.5.9 Coded Frame Removal")
- [§ 9.3.2 Memory
  cleanup](#ref-for-dom-mediasource-activesourcebuffers-31 "§ 9.3.2 Memory cleanup")
- [§ 10.2 HTMLMediaElement\'s
  buffered](#ref-for-dom-mediasource-activesourcebuffers-32 "§ 10.2 HTMLMediaElement's buffered")
  [(2)](#ref-for-dom-mediasource-activesourcebuffers-33 "Reference 2")
  [(3)](#ref-for-dom-mediasource-activesourcebuffers-34 "Reference 3")
  [(4)](#ref-for-dom-mediasource-activesourcebuffers-35 "Reference 4")
  [(5)](#ref-for-dom-mediasource-activesourcebuffers-36 "Reference 5")
::::

:::: {#dfn-panel-for-dom-mediasource-readystate .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: readyState"}
[]{.caret}

::: {}
[Permalink](#dom-mediasource-readystate){.self-link
aria-label="Permalink for definition: readyState. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-1502719514 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3. MediaSource
  interface](#ref-for-dom-mediasource-readystate-1 "§ 3. MediaSource interface")
  [(2)](#ref-for-dom-mediasource-readystate-2 "Reference 2")
  [(3)](#ref-for-dom-mediasource-readystate-3 "Reference 3")
- [§ 3.2 sourceBuffers
  attribute](#ref-for-dom-mediasource-readystate-4 "§ 3.2 sourceBuffers attribute")
  [(2)](#ref-for-dom-mediasource-readystate-5 "Reference 2")
- [§ 3.4 readyState
  attribute](#ref-for-dom-mediasource-readystate-6 "§ 3.4 readyState attribute")
- [§ 3.5 duration
  attribute](#ref-for-dom-mediasource-readystate-7 "§ 3.5 duration attribute")
  [(2)](#ref-for-dom-mediasource-readystate-8 "Reference 2")
- [§ 3.7 addSourceBuffer()
  method](#ref-for-dom-mediasource-readystate-9 "§ 3.7 addSourceBuffer() method")
- [§ 3.9 endOfStream()
  method](#ref-for-dom-mediasource-readystate-10 "§ 3.9 endOfStream() method")
- [§ 3.10 setLiveSeekableRange()
  method](#ref-for-dom-mediasource-readystate-11 "§ 3.10 setLiveSeekableRange() method")
- [§ 3.11 clearLiveSeekableRange()
  method](#ref-for-dom-mediasource-readystate-12 "§ 3.11 clearLiveSeekableRange() method")
- [§ 3.13 Event
  Summary](#ref-for-dom-mediasource-readystate-13 "§ 3.13 Event Summary")
  [(2)](#ref-for-dom-mediasource-readystate-14 "Reference 2")
  [(3)](#ref-for-dom-mediasource-readystate-15 "Reference 3")
- [§ 3.15.1 Attaching to a media
  element](#ref-for-dom-mediasource-readystate-16 "§ 3.15.1 Attaching to a media element")
  [(2)](#ref-for-dom-mediasource-readystate-17 "Reference 2")
  [(3)](#ref-for-dom-mediasource-readystate-18 "Reference 3")
- [§ 3.15.2 Detaching from a media
  element](#ref-for-dom-mediasource-readystate-19 "§ 3.15.2 Detaching from a media element")
- [§ 3.15.3
  Seeking](#ref-for-dom-mediasource-readystate-20 "§ 3.15.3 Seeking")
  [(2)](#ref-for-dom-mediasource-readystate-21 "Reference 2")
- [§ 3.15.7 End of
  stream](#ref-for-dom-mediasource-readystate-22 "§ 3.15.7 End of stream")
- [§ 5.1
  Attributes](#ref-for-dom-mediasource-readystate-23 "§ 5.1 Attributes")
  [(2)](#ref-for-dom-mediasource-readystate-24 "Reference 2")
  [(3)](#ref-for-dom-mediasource-readystate-25 "Reference 3")
  [(4)](#ref-for-dom-mediasource-readystate-26 "Reference 4")
  [(5)](#ref-for-dom-mediasource-readystate-27 "Reference 5")
- [§ 5.2
  Methods](#ref-for-dom-mediasource-readystate-28 "§ 5.2 Methods")
  [(2)](#ref-for-dom-mediasource-readystate-29 "Reference 2")
  [(3)](#ref-for-dom-mediasource-readystate-30 "Reference 3")
  [(4)](#ref-for-dom-mediasource-readystate-31 "Reference 4")
  [(5)](#ref-for-dom-mediasource-readystate-32 "Reference 5")
- [§ 5.5.4 Prepare
  Append](#ref-for-dom-mediasource-readystate-33 "§ 5.5.4 Prepare Append")
  [(2)](#ref-for-dom-mediasource-readystate-34 "Reference 2")
- [§ 10.2 HTMLMediaElement\'s
  buffered](#ref-for-dom-mediasource-readystate-35 "§ 10.2 HTMLMediaElement's buffered")
  [(2)](#ref-for-dom-mediasource-readystate-36 "Reference 2")
::::

:::: {#dfn-panel-for-dom-mediasource-duration .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: duration"}
[]{.caret}

::: {}
[Permalink](#dom-mediasource-duration){.self-link
aria-label="Permalink for definition: duration. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-1502719514 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3. MediaSource
  interface](#ref-for-dom-mediasource-duration-1 "§ 3. MediaSource interface")
- [§ 3.15.2 Detaching from a media
  element](#ref-for-dom-mediasource-duration-2 "§ 3.15.2 Detaching from a media element")
- [§ 3.15.6 Duration
  change](#ref-for-dom-mediasource-duration-3 "§ 3.15.6 Duration change")
  [(2)](#ref-for-dom-mediasource-duration-4 "Reference 2")
  [(3)](#ref-for-dom-mediasource-duration-5 "Reference 3")
  [(4)](#ref-for-dom-mediasource-duration-6 "Reference 4")
- [§ 5.2 Methods](#ref-for-dom-mediasource-duration-7 "§ 5.2 Methods")
  [(2)](#ref-for-dom-mediasource-duration-8 "Reference 2")
- [§ 5.5.7 Initialization Segment
  Received](#ref-for-dom-mediasource-duration-9 "§ 5.5.7 Initialization Segment Received")
- [§ 5.5.8 Coded Frame
  Processing](#ref-for-dom-mediasource-duration-10 "§ 5.5.8 Coded Frame Processing")
- [§ 5.5.9 Coded Frame
  Removal](#ref-for-dom-mediasource-duration-11 "§ 5.5.9 Coded Frame Removal")
- [§ 10.1 HTMLMediaElement\'s
  seekable](#ref-for-dom-mediasource-duration-12 "§ 10.1 HTMLMediaElement's seekable")
  [(2)](#ref-for-dom-mediasource-duration-13 "Reference 2")
  [(3)](#ref-for-dom-mediasource-duration-14 "Reference 3")
  [(4)](#ref-for-dom-mediasource-duration-15 "Reference 4")
::::

:::: {#dfn-panel-for-dom-mediasource-canconstructindedicatedworker .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: canConstructInDedicatedWorker"}
[]{.caret}

::: {}
[Permalink](#dom-mediasource-canconstructindedicatedworker){.self-link
aria-label="Permalink for definition: canConstructInDedicatedWorker. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-1502719514 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3. MediaSource
  interface](#ref-for-dom-mediasource-canconstructindedicatedworker-1 "§ 3. MediaSource interface")
::::

:::: {#dfn-panel-for-dom-mediasource-addsourcebuffer .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: addSourceBuffer()"}
[]{.caret}

::: {}
[Permalink](#dom-mediasource-addsourcebuffer){.self-link
aria-label="Permalink for definition: addSourceBuffer(). Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-1502719514 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 2.
  Definitions](#ref-for-dom-mediasource-addsourcebuffer-1 "§ 2. Definitions")
- [§ 3. MediaSource
  interface](#ref-for-dom-mediasource-addsourcebuffer-2 "§ 3. MediaSource interface")
- [§ 3.2 sourceBuffers
  attribute](#ref-for-dom-mediasource-addsourcebuffer-3 "§ 3.2 sourceBuffers attribute")
- [§ 3.12 isTypeSupported()
  method](#ref-for-dom-mediasource-addsourcebuffer-4 "§ 3.12 isTypeSupported() method")
- [§ 5.1
  Attributes](#ref-for-dom-mediasource-addsourcebuffer-5 "§ 5.1 Attributes")
- [§ 5.5.1 Segment Parser
  Loop](#ref-for-dom-mediasource-addsourcebuffer-6 "§ 5.5.1 Segment Parser Loop")
- [§ 5.5.7 Initialization Segment
  Received](#ref-for-dom-mediasource-addsourcebuffer-7 "§ 5.5.7 Initialization Segment Received")
  [(2)](#ref-for-dom-mediasource-addsourcebuffer-8 "Reference 2")
  [(3)](#ref-for-dom-mediasource-addsourcebuffer-9 "Reference 3")
  [(4)](#ref-for-dom-mediasource-addsourcebuffer-10 "Reference 4")
  [(5)](#ref-for-dom-mediasource-addsourcebuffer-11 "Reference 5")
- [§ 14. Byte Stream
  Formats](#ref-for-dom-mediasource-addsourcebuffer-12 "§ 14. Byte Stream Formats")
  [(2)](#ref-for-dom-mediasource-addsourcebuffer-13 "Reference 2")
::::

:::: {#dfn-panel-for-dom-mediasource-removesourcebuffer .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: removeSourceBuffer()"}
[]{.caret}

::: {}
[Permalink](#dom-mediasource-removesourcebuffer){.self-link
aria-label="Permalink for definition: removeSourceBuffer(). Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-1502719514 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3. MediaSource
  interface](#ref-for-dom-mediasource-removesourcebuffer-1 "§ 3. MediaSource interface")
::::

:::: {#dfn-panel-for-dom-mediasource-endofstream .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: endOfStream()"}
[]{.caret}

::: {}
[Permalink](#dom-mediasource-endofstream){.self-link
aria-label="Permalink for definition: endOfStream(). Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-1502719514 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3. MediaSource
  interface](#ref-for-dom-mediasource-endofstream-1 "§ 3. MediaSource interface")
  [(2)](#ref-for-dom-mediasource-endofstream-2 "Reference 2")
- [§ 3.5 duration
  attribute](#ref-for-dom-mediasource-endofstream-3 "§ 3.5 duration attribute")
- [§ 3.15.7 End of
  stream](#ref-for-dom-mediasource-endofstream-4 "§ 3.15.7 End of stream")
- [§ 9.2 Event
  Summary](#ref-for-dom-mediasource-endofstream-5 "§ 9.2 Event Summary")
::::

:::: {#dfn-panel-for-dom-mediasource-setliveseekablerange .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: setLiveSeekableRange()"}
[]{.caret}

::: {}
[Permalink](#dom-mediasource-setliveseekablerange){.self-link
aria-label="Permalink for definition: setLiveSeekableRange(). Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-1502719514 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3. MediaSource
  interface](#ref-for-dom-mediasource-setliveseekablerange-1 "§ 3. MediaSource interface")
  [(2)](#ref-for-dom-mediasource-setliveseekablerange-2 "Reference 2")
::::

:::: {#dfn-panel-for-dom-mediasource-clearliveseekablerange .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: clearLiveSeekableRange()"}
[]{.caret}

::: {}
[Permalink](#dom-mediasource-clearliveseekablerange){.self-link
aria-label="Permalink for definition: clearLiveSeekableRange(). Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-1502719514 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3. MediaSource
  interface](#ref-for-dom-mediasource-clearliveseekablerange-1 "§ 3. MediaSource interface")
  [(2)](#ref-for-dom-mediasource-clearliveseekablerange-2 "Reference 2")
::::

:::: {#dfn-panel-for-dom-mediasource-istypesupported .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: isTypeSupported()"}
[]{.caret}

::: {}
[Permalink](#dom-mediasource-istypesupported){.self-link
aria-label="Permalink for definition: isTypeSupported(). Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-1502719514 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3. MediaSource
  interface](#ref-for-dom-mediasource-istypesupported-1 "§ 3. MediaSource interface")
- [§ 5.5.7 Initialization Segment
  Received](#ref-for-dom-mediasource-istypesupported-2 "§ 5.5.7 Initialization Segment Received")
  [(2)](#ref-for-dom-mediasource-istypesupported-3 "Reference 2")
- [§ 14. Byte Stream
  Formats](#ref-for-dom-mediasource-istypesupported-4 "§ 14. Byte Stream Formats")
::::

:::: {#dfn-panel-for-dfn-sourceopen .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: sourceopen"}
[]{.caret}

::: {}
[Permalink](#dfn-sourceopen){.self-link
aria-label="Permalink for definition: sourceopen. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 3.15.1 Attaching to a media
  element](#ref-for-dfn-sourceopen-1 "§ 3.15.1 Attaching to a media element")
  [(2)](#ref-for-dfn-sourceopen-2 "Reference 2")
- [§ 5.1 Attributes](#ref-for-dfn-sourceopen-3 "§ 5.1 Attributes")
  [(2)](#ref-for-dfn-sourceopen-4 "Reference 2")
- [§ 5.2 Methods](#ref-for-dfn-sourceopen-5 "§ 5.2 Methods")
  [(2)](#ref-for-dfn-sourceopen-6 "Reference 2")
- [§ 5.5.4 Prepare
  Append](#ref-for-dfn-sourceopen-7 "§ 5.5.4 Prepare Append")
::::

:::: {#dfn-panel-for-dfn-sourceended .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: sourceended"}
[]{.caret}

::: {}
[Permalink](#dfn-sourceended){.self-link
aria-label="Permalink for definition: sourceended. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 3.15.7 End of
  stream](#ref-for-dfn-sourceended-1 "§ 3.15.7 End of stream")
::::

:::: {#dfn-panel-for-dfn-sourceclose .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: sourceclose"}
[]{.caret}

::: {}
[Permalink](#dfn-sourceclose){.self-link
aria-label="Permalink for definition: sourceclose. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 3.15.2 Detaching from a media
  element](#ref-for-dfn-sourceclose-1 "§ 3.15.2 Detaching from a media element")
::::

:::: {#dfn-panel-for-dfn-cross-context-communication-model .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Cross-context communication model"}
[]{.caret}

::: {}
[Permalink](#dfn-cross-context-communication-model){.self-link
aria-label="Permalink for definition: Cross-context communication model. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 4.1
  Transfer](#ref-for-dfn-cross-context-communication-model-1 "§ 4.1 Transfer")
- [§ 10.2 HTMLMediaElement\'s
  buffered](#ref-for-dfn-cross-context-communication-model-2 "§ 10.2 HTMLMediaElement's buffered")
::::

:::: {#dfn-panel-for-dfn-port-to-main .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: [[port to main]]"}
[]{.caret}

::: {}
[Permalink](#dfn-port-to-main){.self-link
aria-label="Permalink for definition: [[port to main]]. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 3.14 Cross-context communication
  model](#ref-for-dfn-port-to-main-1 "§ 3.14 Cross-context communication model")
- [§ 3.15.1 Attaching to a media
  element](#ref-for-dfn-port-to-main-2 "§ 3.15.1 Attaching to a media element")
  [(2)](#ref-for-dfn-port-to-main-3 "Reference 2")
- [§ 3.15.2 Detaching from a media
  element](#ref-for-dfn-port-to-main-4 "§ 3.15.2 Detaching from a media element")
- [§ 3.15.5 Changes to selected/enabled track
  state](#ref-for-dfn-port-to-main-5 "§ 3.15.5 Changes to selected/enabled track state")
- [§ 3.15.8 Mirror if
  necessary](#ref-for-dfn-port-to-main-6 "§ 3.15.8 Mirror if necessary")
- [§ 5.5.7 Initialization Segment
  Received](#ref-for-dfn-port-to-main-7 "§ 5.5.7 Initialization Segment Received")
  [(2)](#ref-for-dfn-port-to-main-8 "Reference 2")
  [(3)](#ref-for-dfn-port-to-main-9 "Reference 3")
- [§ 10.1 HTMLMediaElement\'s
  seekable](#ref-for-dfn-port-to-main-10 "§ 10.1 HTMLMediaElement's seekable")
- [§ 10.2 HTMLMediaElement\'s
  buffered](#ref-for-dfn-port-to-main-11 "§ 10.2 HTMLMediaElement's buffered")
::::

:::: {#dfn-panel-for-dfn-port-to-worker .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: [[port to worker]]"}
[]{.caret}

::: {}
[Permalink](#dfn-port-to-worker){.self-link
aria-label="Permalink for definition: [[port to worker]]. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 3.14 Cross-context communication
  model](#ref-for-dfn-port-to-worker-1 "§ 3.14 Cross-context communication model")
- [§ 3.15.1 Attaching to a media
  element](#ref-for-dfn-port-to-worker-2 "§ 3.15.1 Attaching to a media element")
  [(2)](#ref-for-dfn-port-to-worker-3 "Reference 2")
- [§ 3.15.2 Detaching from a media
  element](#ref-for-dfn-port-to-worker-4 "§ 3.15.2 Detaching from a media element")
  [(2)](#ref-for-dfn-port-to-worker-5 "Reference 2")
- [§ 3.15.5 Changes to selected/enabled track
  state](#ref-for-dfn-port-to-worker-6 "§ 3.15.5 Changes to selected/enabled track state")
- [§ 5.5.4 Prepare
  Append](#ref-for-dfn-port-to-worker-7 "§ 5.5.4 Prepare Append")
::::

:::: {#dfn-panel-for-dfn-channel-with-worker .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: [[channel with worker]]"}
[]{.caret}

::: {}
[Permalink](#dfn-channel-with-worker){.self-link
aria-label="Permalink for definition: [[channel with worker]]. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 3.14 Cross-context communication
  model](#ref-for-dfn-channel-with-worker-1 "§ 3.14 Cross-context communication model")
- [§ 3.15.1 Attaching to a media
  element](#ref-for-dfn-channel-with-worker-2 "§ 3.15.1 Attaching to a media element")
  [(2)](#ref-for-dfn-channel-with-worker-3 "Reference 2")
  [(3)](#ref-for-dfn-channel-with-worker-4 "Reference 3")
  [(4)](#ref-for-dfn-channel-with-worker-5 "Reference 4")
  [(5)](#ref-for-dfn-channel-with-worker-6 "Reference 5")
- [§ 3.15.2 Detaching from a media
  element](#ref-for-dfn-channel-with-worker-7 "§ 3.15.2 Detaching from a media element")
::::

:::: {#dfn-panel-for-dfn-attaching-to-a-media-element .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Attaching to a media element"}
[]{.caret}

::: {}
[Permalink](#dfn-attaching-to-a-media-element){.self-link
aria-label="Permalink for definition: Attaching to a media element. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 3. MediaSource
  interface](#ref-for-dfn-attaching-to-a-media-element-1 "§ 3. MediaSource interface")
- [§ 3.14 Cross-context communication
  model](#ref-for-dfn-attaching-to-a-media-element-2 "§ 3.14 Cross-context communication model")
- [§ 4. MediaSourceHandle
  interface](#ref-for-dfn-attaching-to-a-media-element-3 "§ 4. MediaSourceHandle interface")
- [§ 4.1
  Transfer](#ref-for-dfn-attaching-to-a-media-element-4 "§ 4.1 Transfer")
  [(2)](#ref-for-dfn-attaching-to-a-media-element-5 "Reference 2")
  [(3)](#ref-for-dfn-attaching-to-a-media-element-6 "Reference 3")
::::

:::: {#dfn-panel-for-dfn-detaching-from-a-media-element .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Detaching from a media element"}
[]{.caret}

::: {}
[Permalink](#dfn-detaching-from-a-media-element){.self-link
aria-label="Permalink for definition: Detaching from a media element. Activate to close this dialog."}
:::

**Referenced in:**

- Not referenced in this document.
::::

:::: {#dfn-panel-for-dfn-seeking .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Seeking"}
[]{.caret}

::: {}
[Permalink](#dfn-seeking){.self-link
aria-label="Permalink for definition: Seeking. Activate to close this dialog."}
:::

**Referenced in:**

- Not referenced in this document.
::::

:::: {#dfn-panel-for-dfn-sourcebuffer-monitoring .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: SourceBuffer Monitoring"}
[]{.caret}

::: {}
[Permalink](#dfn-sourcebuffer-monitoring){.self-link
aria-label="Permalink for definition: SourceBuffer Monitoring. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 7.3.1 ManagedSourceBuffer
  Monitoring](#ref-for-dfn-sourcebuffer-monitoring-1 "§ 7.3.1 ManagedSourceBuffer Monitoring")
  [(2)](#ref-for-dfn-sourcebuffer-monitoring-2 "Reference 2")
::::

:::: {#dfn-panel-for-enough-data .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: enough data to ensure uninterrupted playback"}
[]{.caret}

::: {}
[Permalink](#enough-data){.self-link
aria-label="Permalink for definition: enough data to ensure uninterrupted playback. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 3.15.4 SourceBuffer
  Monitoring](#ref-for-enough-data-1 "§ 3.15.4 SourceBuffer Monitoring")
  [(2)](#ref-for-enough-data-2 "Reference 2")
- [§ 5.5.8 Coded Frame
  Processing](#ref-for-enough-data-3 "§ 5.5.8 Coded Frame Processing")
::::

:::: {#dfn-panel-for-dfn-changes-to-selected-enabled-track-state .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Changes to selected/enabled track state"}
[]{.caret}

::: {}
[Permalink](#dfn-changes-to-selected-enabled-track-state){.self-link
aria-label="Permalink for definition: Changes to selected/enabled track state. Activate to close this dialog."}
:::

**Referenced in:**

- Not referenced in this document.
::::

:::: {#dfn-panel-for-dfn-duration-change .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Duration change"}
[]{.caret}

::: {}
[Permalink](#dfn-duration-change){.self-link
aria-label="Permalink for definition: Duration change. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 3.5 duration
  attribute](#ref-for-dfn-duration-change-1 "§ 3.5 duration attribute")
  [(2)](#ref-for-dfn-duration-change-2 "Reference 2")
- [§ 3.15.7 End of
  stream](#ref-for-dfn-duration-change-3 "§ 3.15.7 End of stream")
- [§ 5.5.7 Initialization Segment
  Received](#ref-for-dfn-duration-change-4 "§ 5.5.7 Initialization Segment Received")
  [(2)](#ref-for-dfn-duration-change-5 "Reference 2")
- [§ 5.5.8 Coded Frame
  Processing](#ref-for-dfn-duration-change-6 "§ 5.5.8 Coded Frame Processing")
::::

:::: {#dfn-panel-for-dfn-end-of-stream .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: End of stream"}
[]{.caret}

::: {}
[Permalink](#dfn-end-of-stream){.self-link
aria-label="Permalink for definition: End of stream. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 3.9 endOfStream()
  method](#ref-for-dfn-end-of-stream-1 "§ 3.9 endOfStream() method")
- [§ 5.5.3 Append
  Error](#ref-for-dfn-end-of-stream-2 "§ 5.5.3 Append Error")
::::

:::: {#dfn-panel-for-dfn-mirror-if-necessary .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Mirror if necessary"}
[]{.caret}

::: {}
[Permalink](#dfn-mirror-if-necessary){.self-link
aria-label="Permalink for definition: Mirror if necessary. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 3.8 removeSourceBuffer()
  method](#ref-for-dfn-mirror-if-necessary-1 "§ 3.8 removeSourceBuffer() method")
  [(2)](#ref-for-dfn-mirror-if-necessary-2 "Reference 2")
  [(3)](#ref-for-dfn-mirror-if-necessary-3 "Reference 3")
- [§ 3.15.6 Duration
  change](#ref-for-dfn-mirror-if-necessary-4 "§ 3.15.6 Duration change")
- [§ 3.15.7 End of
  stream](#ref-for-dfn-mirror-if-necessary-5 "§ 3.15.7 End of stream")
  [(2)](#ref-for-dfn-mirror-if-necessary-6 "Reference 2")
- [§ 5.5.7 Initialization Segment
  Received](#ref-for-dfn-mirror-if-necessary-7 "§ 5.5.7 Initialization Segment Received")
  [(2)](#ref-for-dfn-mirror-if-necessary-8 "Reference 2")
::::

:::: {#dfn-panel-for-dom-mediasourcehandle .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: MediaSourceHandle"}
[]{.caret}

::: {}
[Permalink](#dom-mediasourcehandle){.self-link
aria-label="Permalink for definition: MediaSourceHandle. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-1737388085 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3. MediaSource
  interface](#ref-for-dom-mediasourcehandle-1 "§ 3. MediaSource interface")
  [(2)](#ref-for-dom-mediasourcehandle-2 "Reference 2")
- [§ 3.1 handle
  attribute](#ref-for-dom-mediasourcehandle-3 "§ 3.1 handle attribute")
  [(2)](#ref-for-dom-mediasourcehandle-4 "Reference 2")
- [§ 3.14 Cross-context communication
  model](#ref-for-dom-mediasourcehandle-5 "§ 3.14 Cross-context communication model")
- [§ 3.15.1 Attaching to a media
  element](#ref-for-dom-mediasourcehandle-6 "§ 3.15.1 Attaching to a media element")
  [(2)](#ref-for-dom-mediasourcehandle-7 "Reference 2")
  [(3)](#ref-for-dom-mediasourcehandle-8 "Reference 3")
  [(4)](#ref-for-dom-mediasourcehandle-9 "Reference 4")
  [(5)](#ref-for-dom-mediasourcehandle-10 "Reference 5")
  [(6)](#ref-for-dom-mediasourcehandle-11 "Reference 6")
  [(7)](#ref-for-dom-mediasourcehandle-12 "Reference 7")
- [§ 4. MediaSourceHandle
  interface](#ref-for-dom-mediasourcehandle-13 "§ 4. MediaSourceHandle interface")
  [(2)](#ref-for-dom-mediasourcehandle-14 "Reference 2")
  [(3)](#ref-for-dom-mediasourcehandle-15 "Reference 3")
  [(4)](#ref-for-dom-mediasourcehandle-16 "Reference 4")
  [(5)](#ref-for-dom-mediasourcehandle-17 "Reference 5")
  [(6)](#ref-for-dom-mediasourcehandle-18 "Reference 6")
- [§ 4.1 Transfer](#ref-for-dom-mediasourcehandle-19 "§ 4.1 Transfer")
  [(2)](#ref-for-dom-mediasourcehandle-20 "Reference 2")
  [(3)](#ref-for-dom-mediasourcehandle-21 "Reference 3")
  [(4)](#ref-for-dom-mediasourcehandle-22 "Reference 4")
  [(5)](#ref-for-dom-mediasourcehandle-23 "Reference 5")
  [(6)](#ref-for-dom-mediasourcehandle-24 "Reference 6")
  [(7)](#ref-for-dom-mediasourcehandle-25 "Reference 7")
  [(8)](#ref-for-dom-mediasourcehandle-26 "Reference 8")
  [(9)](#ref-for-dom-mediasourcehandle-27 "Reference 9")
  [(10)](#ref-for-dom-mediasourcehandle-28 "Reference 10")
- [§ 10. HTMLMediaElement
  Extensions](#ref-for-dom-mediasourcehandle-29 "§ 10. HTMLMediaElement Extensions")
- [§ 10.3 HTMLMediaElement\'s
  srcObject](#ref-for-dom-mediasourcehandle-30 "§ 10.3 HTMLMediaElement's srcObject")
  [(2)](#ref-for-dom-mediasourcehandle-31 "Reference 2")
  [(3)](#ref-for-dom-mediasourcehandle-32 "Reference 3")
  [(4)](#ref-for-dom-mediasourcehandle-33 "Reference 4")
::::

:::: {#dfn-panel-for-dfn-has-ever-been-assigned-as-srcobject .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: [[has ever been assigned as srcobject]]"}
[]{.caret}

::: {}
[Permalink](#dfn-has-ever-been-assigned-as-srcobject){.self-link
aria-label="Permalink for definition: [[has ever been assigned as srcobject]]. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 4.1
  Transfer](#ref-for-dfn-has-ever-been-assigned-as-srcobject-1 "§ 4.1 Transfer")
- [§ 10.3 HTMLMediaElement\'s
  srcObject](#ref-for-dfn-has-ever-been-assigned-as-srcobject-2 "§ 10.3 HTMLMediaElement's srcObject")
::::

:::: {#dfn-panel-for-dfn-detached .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: [[Detached]]"}
[]{.caret}

::: {}
[Permalink](#dfn-detached){.self-link
aria-label="Permalink for definition: [[Detached]]. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 3.15.1 Attaching to a media
  element](#ref-for-dfn-detached-1 "§ 3.15.1 Attaching to a media element")
::::

:::: {#dfn-panel-for-dom-sourcebuffer .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: SourceBuffer"}
[]{.caret}

::: {}
[Permalink](#dom-sourcebuffer){.self-link
aria-label="Permalink for definition: SourceBuffer. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-544711679 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 1. Introduction](#ref-for-dom-sourcebuffer-1 "§ 1. Introduction")
  [(2)](#ref-for-dom-sourcebuffer-2 "Reference 2")
  [(3)](#ref-for-dom-sourcebuffer-3 "Reference 3")
- [§ 2. Definitions](#ref-for-dom-sourcebuffer-4 "§ 2. Definitions")
  [(2)](#ref-for-dom-sourcebuffer-5 "Reference 2")
  [(3)](#ref-for-dom-sourcebuffer-6 "Reference 3")
  [(4)](#ref-for-dom-sourcebuffer-7 "Reference 4")
  [(5)](#ref-for-dom-sourcebuffer-8 "Reference 5")
  [(6)](#ref-for-dom-sourcebuffer-9 "Reference 6")
- [§ 3. MediaSource
  interface](#ref-for-dom-sourcebuffer-10 "§ 3. MediaSource interface")
  [(2)](#ref-for-dom-sourcebuffer-11 "Reference 2")
  [(3)](#ref-for-dom-sourcebuffer-12 "Reference 3")
  [(4)](#ref-for-dom-sourcebuffer-13 "Reference 4")
  [(5)](#ref-for-dom-sourcebuffer-14 "Reference 5")
  [(6)](#ref-for-dom-sourcebuffer-15 "Reference 6")
- [§ 3.2 sourceBuffers
  attribute](#ref-for-dom-sourcebuffer-16 "§ 3.2 sourceBuffers attribute")
- [§ 3.3 activeSourceBuffers
  attribute](#ref-for-dom-sourcebuffer-17 "§ 3.3 activeSourceBuffers attribute")
- [§ 3.5 duration
  attribute](#ref-for-dom-sourcebuffer-18 "§ 3.5 duration attribute")
- [§ 3.7 addSourceBuffer()
  method](#ref-for-dom-sourcebuffer-19 "§ 3.7 addSourceBuffer() method")
  [(2)](#ref-for-dom-sourcebuffer-20 "Reference 2")
  [(3)](#ref-for-dom-sourcebuffer-21 "Reference 3")
- [§ 3.8 removeSourceBuffer()
  method](#ref-for-dom-sourcebuffer-22 "§ 3.8 removeSourceBuffer() method")
- [§ 3.9 endOfStream()
  method](#ref-for-dom-sourcebuffer-23 "§ 3.9 endOfStream() method")
- [§ 3.12 isTypeSupported()
  method](#ref-for-dom-sourcebuffer-24 "§ 3.12 isTypeSupported() method")
  [(2)](#ref-for-dom-sourcebuffer-25 "Reference 2")
  [(3)](#ref-for-dom-sourcebuffer-26 "Reference 3")
- [§ 3.15.2 Detaching from a media
  element](#ref-for-dom-sourcebuffer-27 "§ 3.15.2 Detaching from a media element")
  [(2)](#ref-for-dom-sourcebuffer-28 "Reference 2")
- [§ 3.15.3 Seeking](#ref-for-dom-sourcebuffer-29 "§ 3.15.3 Seeking")
- [§ 3.15.4 SourceBuffer
  Monitoring](#ref-for-dom-sourcebuffer-30 "§ 3.15.4 SourceBuffer Monitoring")
- [§ 3.15.5 Changes to selected/enabled track
  state](#ref-for-dom-sourcebuffer-31 "§ 3.15.5 Changes to selected/enabled track state")
  [(2)](#ref-for-dom-sourcebuffer-32 "Reference 2")
  [(3)](#ref-for-dom-sourcebuffer-33 "Reference 3")
  [(4)](#ref-for-dom-sourcebuffer-34 "Reference 4")
  [(5)](#ref-for-dom-sourcebuffer-35 "Reference 5")
  [(6)](#ref-for-dom-sourcebuffer-36 "Reference 6")
  [(7)](#ref-for-dom-sourcebuffer-37 "Reference 7")
  [(8)](#ref-for-dom-sourcebuffer-38 "Reference 8")
  [(9)](#ref-for-dom-sourcebuffer-39 "Reference 9")
  [(10)](#ref-for-dom-sourcebuffer-40 "Reference 10")
  [(11)](#ref-for-dom-sourcebuffer-41 "Reference 11")
  [(12)](#ref-for-dom-sourcebuffer-42 "Reference 12")
- [§ 3.15.6 Duration
  change](#ref-for-dom-sourcebuffer-43 "§ 3.15.6 Duration change")
  [(2)](#ref-for-dom-sourcebuffer-44 "Reference 2")
- [§ 3.15.7 End of
  stream](#ref-for-dom-sourcebuffer-45 "§ 3.15.7 End of stream")
- [§ 5. SourceBuffer
  interface](#ref-for-dom-sourcebuffer-46 "§ 5. SourceBuffer interface")
- [§ 5.1 Attributes](#ref-for-dom-sourcebuffer-47 "§ 5.1 Attributes")
  [(2)](#ref-for-dom-sourcebuffer-48 "Reference 2")
  [(3)](#ref-for-dom-sourcebuffer-49 "Reference 3")
  [(4)](#ref-for-dom-sourcebuffer-50 "Reference 4")
- [§ 5.2 Methods](#ref-for-dom-sourcebuffer-51 "§ 5.2 Methods")
  [(2)](#ref-for-dom-sourcebuffer-52 "Reference 2")
  [(3)](#ref-for-dom-sourcebuffer-53 "Reference 3")
  [(4)](#ref-for-dom-sourcebuffer-54 "Reference 4")
  [(5)](#ref-for-dom-sourcebuffer-55 "Reference 5")
  [(6)](#ref-for-dom-sourcebuffer-56 "Reference 6")
  [(7)](#ref-for-dom-sourcebuffer-57 "Reference 7")
  [(8)](#ref-for-dom-sourcebuffer-58 "Reference 8")
  [(9)](#ref-for-dom-sourcebuffer-59 "Reference 9")
- [§ 5.3 Track
  Buffers](#ref-for-dom-sourcebuffer-60 "§ 5.3 Track Buffers")
  [(2)](#ref-for-dom-sourcebuffer-61 "Reference 2")
  [(3)](#ref-for-dom-sourcebuffer-62 "Reference 3")
- [§ 5.4 Event
  Summary](#ref-for-dom-sourcebuffer-63 "§ 5.4 Event Summary")
  [(2)](#ref-for-dom-sourcebuffer-64 "Reference 2")
  [(3)](#ref-for-dom-sourcebuffer-65 "Reference 3")
  [(4)](#ref-for-dom-sourcebuffer-66 "Reference 4")
  [(5)](#ref-for-dom-sourcebuffer-67 "Reference 5")
  [(6)](#ref-for-dom-sourcebuffer-68 "Reference 6")
- [§ 5.5.1 Segment Parser
  Loop](#ref-for-dom-sourcebuffer-69 "§ 5.5.1 Segment Parser Loop")
  [(2)](#ref-for-dom-sourcebuffer-70 "Reference 2")
  [(3)](#ref-for-dom-sourcebuffer-71 "Reference 3")
  [(4)](#ref-for-dom-sourcebuffer-72 "Reference 4")
  [(5)](#ref-for-dom-sourcebuffer-73 "Reference 5")
  [(6)](#ref-for-dom-sourcebuffer-74 "Reference 6")
  [(7)](#ref-for-dom-sourcebuffer-75 "Reference 7")
  [(8)](#ref-for-dom-sourcebuffer-76 "Reference 8")
  [(9)](#ref-for-dom-sourcebuffer-77 "Reference 9")
  [(10)](#ref-for-dom-sourcebuffer-78 "Reference 10")
  [(11)](#ref-for-dom-sourcebuffer-79 "Reference 11")
- [§ 5.5.3 Append
  Error](#ref-for-dom-sourcebuffer-80 "§ 5.5.3 Append Error")
  [(2)](#ref-for-dom-sourcebuffer-81 "Reference 2")
- [§ 5.5.4 Prepare
  Append](#ref-for-dom-sourcebuffer-82 "§ 5.5.4 Prepare Append")
  [(2)](#ref-for-dom-sourcebuffer-83 "Reference 2")
- [§ 5.5.5 Buffer
  Append](#ref-for-dom-sourcebuffer-84 "§ 5.5.5 Buffer Append")
  [(2)](#ref-for-dom-sourcebuffer-85 "Reference 2")
- [§ 5.5.6 Range
  Removal](#ref-for-dom-sourcebuffer-86 "§ 5.5.6 Range Removal")
  [(2)](#ref-for-dom-sourcebuffer-87 "Reference 2")
  [(3)](#ref-for-dom-sourcebuffer-88 "Reference 3")
- [§ 5.5.7 Initialization Segment
  Received](#ref-for-dom-sourcebuffer-89 "§ 5.5.7 Initialization Segment Received")
  [(2)](#ref-for-dom-sourcebuffer-90 "Reference 2")
  [(3)](#ref-for-dom-sourcebuffer-91 "Reference 3")
  [(4)](#ref-for-dom-sourcebuffer-92 "Reference 4")
  [(5)](#ref-for-dom-sourcebuffer-93 "Reference 5")
  [(6)](#ref-for-dom-sourcebuffer-94 "Reference 6")
  [(7)](#ref-for-dom-sourcebuffer-95 "Reference 7")
  [(8)](#ref-for-dom-sourcebuffer-96 "Reference 8")
  [(9)](#ref-for-dom-sourcebuffer-97 "Reference 9")
  [(10)](#ref-for-dom-sourcebuffer-98 "Reference 10")
  [(11)](#ref-for-dom-sourcebuffer-99 "Reference 11")
  [(12)](#ref-for-dom-sourcebuffer-100 "Reference 12")
  [(13)](#ref-for-dom-sourcebuffer-101 "Reference 13")
  [(14)](#ref-for-dom-sourcebuffer-102 "Reference 14")
  [(15)](#ref-for-dom-sourcebuffer-103 "Reference 15")
- [§ 5.5.9 Coded Frame
  Removal](#ref-for-dom-sourcebuffer-104 "§ 5.5.9 Coded Frame Removal")
- [§ 5.5.10 Coded Frame
  Eviction](#ref-for-dom-sourcebuffer-105 "§ 5.5.10 Coded Frame Eviction")
  [(2)](#ref-for-dom-sourcebuffer-106 "Reference 2")
- [§ 6. SourceBufferList
  interface](#ref-for-dom-sourcebuffer-107 "§ 6. SourceBufferList interface")
  [(2)](#ref-for-dom-sourcebuffer-108 "Reference 2")
- [§ 6.1 Attributes](#ref-for-dom-sourcebuffer-109 "§ 6.1 Attributes")
- [§ 6.2 Methods](#ref-for-dom-sourcebuffer-110 "§ 6.2 Methods")
- [§ 6.3 Event
  Summary](#ref-for-dom-sourcebuffer-111 "§ 6.3 Event Summary")
  [(2)](#ref-for-dom-sourcebuffer-112 "Reference 2")
- [§ 9. ManagedSourceBuffer
  interface](#ref-for-dom-sourcebuffer-113 "§ 9. ManagedSourceBuffer interface")
- [§ 10.2 HTMLMediaElement\'s
  buffered](#ref-for-dom-sourcebuffer-114 "§ 10.2 HTMLMediaElement's buffered")
  [(2)](#ref-for-dom-sourcebuffer-115 "Reference 2")
  [(3)](#ref-for-dom-sourcebuffer-116 "Reference 3")
  [(4)](#ref-for-dom-sourcebuffer-117 "Reference 4")
- [§ 11. AudioTrack
  extensions](#ref-for-dom-sourcebuffer-118 "§ 11. AudioTrack extensions")
- [§ Attributes](#ref-for-dom-sourcebuffer-119 "§ Attributes")
  [(2)](#ref-for-dom-sourcebuffer-120 "Reference 2")
  [(3)](#ref-for-dom-sourcebuffer-121 "Reference 3")
  [(4)](#ref-for-dom-sourcebuffer-122 "Reference 4")
  [(5)](#ref-for-dom-sourcebuffer-123 "Reference 5")
  [(6)](#ref-for-dom-sourcebuffer-125 "Reference 6")
  [(7)](#ref-for-dom-sourcebuffer-126 "Reference 7")
  [(8)](#ref-for-dom-sourcebuffer-127 "Reference 8")
  [(9)](#ref-for-dom-sourcebuffer-128 "Reference 9")
  [(10)](#ref-for-dom-sourcebuffer-129 "Reference 10")
  [(11)](#ref-for-dom-sourcebuffer-131 "Reference 11")
  [(12)](#ref-for-dom-sourcebuffer-132 "Reference 12")
  [(13)](#ref-for-dom-sourcebuffer-133 "Reference 13")
  [(14)](#ref-for-dom-sourcebuffer-134 "Reference 14")
  [(15)](#ref-for-dom-sourcebuffer-135 "Reference 15")
- [§ 12. VideoTrack
  extensions](#ref-for-dom-sourcebuffer-124 "§ 12. VideoTrack extensions")
- [§ 13. TextTrack
  extensions](#ref-for-dom-sourcebuffer-130 "§ 13. TextTrack extensions")
- [§ 14. Byte Stream
  Formats](#ref-for-dom-sourcebuffer-136 "§ 14. Byte Stream Formats")
  [(2)](#ref-for-dom-sourcebuffer-137 "Reference 2")
  [(3)](#ref-for-dom-sourcebuffer-138 "Reference 3")
::::

:::: {#dfn-panel-for-dom-appendmode .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: AppendMode"}
[]{.caret}

::: {}
[Permalink](#dom-appendmode){.self-link
aria-label="Permalink for definition: AppendMode. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
:::

**Referenced in:**

- [§ 5. SourceBuffer
  interface](#ref-for-dom-appendmode-1 "§ 5. SourceBuffer interface")
- [§ 5.1 Attributes](#ref-for-dom-appendmode-2 "§ 5.1 Attributes")
::::

:::: {#dfn-panel-for-dom-appendmode-segments .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: segments"}
[]{.caret}

::: {}
[Permalink](#dom-appendmode-segments){.self-link
aria-label="Permalink for definition: segments. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-955395090 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3.7 addSourceBuffer()
  method](#ref-for-dom-appendmode-segments-1 "§ 3.7 addSourceBuffer() method")
- [§ 5. SourceBuffer
  interface](#ref-for-dom-appendmode-segments-2 "§ 5. SourceBuffer interface")
- [§ 5.1
  Attributes](#ref-for-dom-appendmode-segments-3 "§ 5.1 Attributes")
- [§ 5.5.8 Coded Frame
  Processing](#ref-for-dom-appendmode-segments-4 "§ 5.5.8 Coded Frame Processing")
- [§ 5.5.9 Coded Frame
  Removal](#ref-for-dom-appendmode-segments-5 "§ 5.5.9 Coded Frame Removal")
::::

:::: {#dfn-panel-for-dom-appendmode-sequence .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: sequence"}
[]{.caret}

::: {}
[Permalink](#dom-appendmode-sequence){.self-link
aria-label="Permalink for definition: sequence. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-955395090 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3.7 addSourceBuffer()
  method](#ref-for-dom-appendmode-sequence-1 "§ 3.7 addSourceBuffer() method")
- [§ 5. SourceBuffer
  interface](#ref-for-dom-appendmode-sequence-2 "§ 5. SourceBuffer interface")
  [(2)](#ref-for-dom-appendmode-sequence-3 "Reference 2")
- [§ 5.1
  Attributes](#ref-for-dom-appendmode-sequence-4 "§ 5.1 Attributes")
  [(2)](#ref-for-dom-appendmode-sequence-5 "Reference 2")
- [§ 5.2 Methods](#ref-for-dom-appendmode-sequence-6 "§ 5.2 Methods")
- [§ 5.5.1 Segment Parser
  Loop](#ref-for-dom-appendmode-sequence-7 "§ 5.5.1 Segment Parser Loop")
  [(2)](#ref-for-dom-appendmode-sequence-8 "Reference 2")
- [§ 5.5.2 Reset Parser
  State](#ref-for-dom-appendmode-sequence-9 "§ 5.5.2 Reset Parser State")
- [§ 5.5.8 Coded Frame
  Processing](#ref-for-dom-appendmode-sequence-10 "§ 5.5.8 Coded Frame Processing")
  [(2)](#ref-for-dom-appendmode-sequence-11 "Reference 2")
- [§ 5.5.9 Coded Frame
  Removal](#ref-for-dom-appendmode-sequence-12 "§ 5.5.9 Coded Frame Removal")
::::

:::: {#dfn-panel-for-dom-sourcebuffer-mode .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: mode"}
[]{.caret}

::: {}
[Permalink](#dom-sourcebuffer-mode){.self-link
aria-label="Permalink for definition: mode. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-544711679 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3.7 addSourceBuffer()
  method](#ref-for-dom-sourcebuffer-mode-1 "§ 3.7 addSourceBuffer() method")
  [(2)](#ref-for-dom-sourcebuffer-mode-2 "Reference 2")
- [§ 5. SourceBuffer
  interface](#ref-for-dom-sourcebuffer-mode-3 "§ 5. SourceBuffer interface")
- [§ 5.1
  Attributes](#ref-for-dom-sourcebuffer-mode-4 "§ 5.1 Attributes")
- [§ 5.2 Methods](#ref-for-dom-sourcebuffer-mode-5 "§ 5.2 Methods")
  [(2)](#ref-for-dom-sourcebuffer-mode-6 "Reference 2")
- [§ 5.3 Track
  Buffers](#ref-for-dom-sourcebuffer-mode-7 "§ 5.3 Track Buffers")
- [§ 5.5.1 Segment Parser
  Loop](#ref-for-dom-sourcebuffer-mode-8 "§ 5.5.1 Segment Parser Loop")
  [(2)](#ref-for-dom-sourcebuffer-mode-9 "Reference 2")
- [§ 5.5.2 Reset Parser
  State](#ref-for-dom-sourcebuffer-mode-10 "§ 5.5.2 Reset Parser State")
- [§ 5.5.8 Coded Frame
  Processing](#ref-for-dom-sourcebuffer-mode-11 "§ 5.5.8 Coded Frame Processing")
  [(2)](#ref-for-dom-sourcebuffer-mode-12 "Reference 2")
  [(3)](#ref-for-dom-sourcebuffer-mode-13 "Reference 3")
- [§ 5.5.9 Coded Frame
  Removal](#ref-for-dom-sourcebuffer-mode-14 "§ 5.5.9 Coded Frame Removal")
  [(2)](#ref-for-dom-sourcebuffer-mode-15 "Reference 2")
::::

:::: {#dfn-panel-for-dom-sourcebuffer-updating .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: updating"}
[]{.caret}

::: {}
[Permalink](#dom-sourcebuffer-updating){.self-link
aria-label="Permalink for definition: updating. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-544711679 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3.5 duration
  attribute](#ref-for-dom-sourcebuffer-updating-1 "§ 3.5 duration attribute")
- [§ 3.8 removeSourceBuffer()
  method](#ref-for-dom-sourcebuffer-updating-2 "§ 3.8 removeSourceBuffer() method")
  [(2)](#ref-for-dom-sourcebuffer-updating-3 "Reference 2")
- [§ 3.9 endOfStream()
  method](#ref-for-dom-sourcebuffer-updating-4 "§ 3.9 endOfStream() method")
- [§ 5. SourceBuffer
  interface](#ref-for-dom-sourcebuffer-updating-5 "§ 5. SourceBuffer interface")
- [§ 5.1
  Attributes](#ref-for-dom-sourcebuffer-updating-6 "§ 5.1 Attributes")
  [(2)](#ref-for-dom-sourcebuffer-updating-7 "Reference 2")
  [(3)](#ref-for-dom-sourcebuffer-updating-8 "Reference 3")
  [(4)](#ref-for-dom-sourcebuffer-updating-9 "Reference 4")
- [§ 5.2 Methods](#ref-for-dom-sourcebuffer-updating-10 "§ 5.2 Methods")
  [(2)](#ref-for-dom-sourcebuffer-updating-11 "Reference 2")
  [(3)](#ref-for-dom-sourcebuffer-updating-12 "Reference 3")
  [(4)](#ref-for-dom-sourcebuffer-updating-13 "Reference 4")
  [(5)](#ref-for-dom-sourcebuffer-updating-14 "Reference 5")
- [§ 5.4 Event
  Summary](#ref-for-dom-sourcebuffer-updating-15 "§ 5.4 Event Summary")
  [(2)](#ref-for-dom-sourcebuffer-updating-16 "Reference 2")
  [(3)](#ref-for-dom-sourcebuffer-updating-17 "Reference 3")
  [(4)](#ref-for-dom-sourcebuffer-updating-18 "Reference 4")
- [§ 5.5.3 Append
  Error](#ref-for-dom-sourcebuffer-updating-19 "§ 5.5.3 Append Error")
- [§ 5.5.4 Prepare
  Append](#ref-for-dom-sourcebuffer-updating-20 "§ 5.5.4 Prepare Append")
- [§ 5.5.5 Buffer
  Append](#ref-for-dom-sourcebuffer-updating-21 "§ 5.5.5 Buffer Append")
- [§ 5.5.6 Range
  Removal](#ref-for-dom-sourcebuffer-updating-22 "§ 5.5.6 Range Removal")
  [(2)](#ref-for-dom-sourcebuffer-updating-23 "Reference 2")
::::

:::: {#dfn-panel-for-dom-sourcebuffer-buffered .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: buffered"}
[]{.caret}

::: {}
[Permalink](#dom-sourcebuffer-buffered){.self-link
aria-label="Permalink for definition: buffered. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-544711679 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3.15.3
  Seeking](#ref-for-dom-sourcebuffer-buffered-1 "§ 3.15.3 Seeking")
  [(2)](#ref-for-dom-sourcebuffer-buffered-2 "Reference 2")
- [§ 5. SourceBuffer
  interface](#ref-for-dom-sourcebuffer-buffered-3 "§ 5. SourceBuffer interface")
- [§ 5.5.10 Coded Frame
  Eviction](#ref-for-dom-sourcebuffer-buffered-4 "§ 5.5.10 Coded Frame Eviction")
- [§ 9.3.1 Buffered
  Change](#ref-for-dom-sourcebuffer-buffered-5 "§ 9.3.1 Buffered Change")
  [(2)](#ref-for-dom-sourcebuffer-buffered-6 "Reference 2")
  [(3)](#ref-for-dom-sourcebuffer-buffered-7 "Reference 3")
- [§ 10.2 HTMLMediaElement\'s
  buffered](#ref-for-dom-sourcebuffer-buffered-8 "§ 10.2 HTMLMediaElement's buffered")
  [(2)](#ref-for-dom-sourcebuffer-buffered-9 "Reference 2")
  [(3)](#ref-for-dom-sourcebuffer-buffered-10 "Reference 3")
- [§ 14. Byte Stream
  Formats](#ref-for-dom-sourcebuffer-buffered-11 "§ 14. Byte Stream Formats")
::::

:::: {#dfn-panel-for-dom-sourcebuffer-timestampoffset .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: timestampOffset"}
[]{.caret}

::: {}
[Permalink](#dom-sourcebuffer-timestampoffset){.self-link
aria-label="Permalink for definition: timestampOffset. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-544711679 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 5. SourceBuffer
  interface](#ref-for-dom-sourcebuffer-timestampoffset-1 "§ 5. SourceBuffer interface")
  [(2)](#ref-for-dom-sourcebuffer-timestampoffset-2 "Reference 2")
  [(3)](#ref-for-dom-sourcebuffer-timestampoffset-3 "Reference 3")
- [§ 5.1
  Attributes](#ref-for-dom-sourcebuffer-timestampoffset-4 "§ 5.1 Attributes")
- [§ 5.5.1 Segment Parser
  Loop](#ref-for-dom-sourcebuffer-timestampoffset-5 "§ 5.5.1 Segment Parser Loop")
- [§ 5.5.8 Coded Frame
  Processing](#ref-for-dom-sourcebuffer-timestampoffset-6 "§ 5.5.8 Coded Frame Processing")
  [(2)](#ref-for-dom-sourcebuffer-timestampoffset-7 "Reference 2")
  [(3)](#ref-for-dom-sourcebuffer-timestampoffset-8 "Reference 3")
  [(4)](#ref-for-dom-sourcebuffer-timestampoffset-9 "Reference 4")
  [(5)](#ref-for-dom-sourcebuffer-timestampoffset-10 "Reference 5")
::::

:::: {#dfn-panel-for-dom-sourcebuffer-audiotracks .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: audioTracks"}
[]{.caret}

::: {}
[Permalink](#dom-sourcebuffer-audiotracks){.self-link
aria-label="Permalink for definition: audioTracks. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-544711679 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3.8 removeSourceBuffer()
  method](#ref-for-dom-sourcebuffer-audiotracks-1 "§ 3.8 removeSourceBuffer() method")
- [§ 5. SourceBuffer
  interface](#ref-for-dom-sourcebuffer-audiotracks-2 "§ 5. SourceBuffer interface")
- [§ 5.5.7 Initialization Segment
  Received](#ref-for-dom-sourcebuffer-audiotracks-3 "§ 5.5.7 Initialization Segment Received")
  [(2)](#ref-for-dom-sourcebuffer-audiotracks-4 "Reference 2")
  [(3)](#ref-for-dom-sourcebuffer-audiotracks-5 "Reference 3")
::::

:::: {#dfn-panel-for-dom-sourcebuffer-videotracks .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: videoTracks"}
[]{.caret}

::: {}
[Permalink](#dom-sourcebuffer-videotracks){.self-link
aria-label="Permalink for definition: videoTracks. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-544711679 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3.8 removeSourceBuffer()
  method](#ref-for-dom-sourcebuffer-videotracks-1 "§ 3.8 removeSourceBuffer() method")
- [§ 5. SourceBuffer
  interface](#ref-for-dom-sourcebuffer-videotracks-2 "§ 5. SourceBuffer interface")
- [§ 5.5.7 Initialization Segment
  Received](#ref-for-dom-sourcebuffer-videotracks-3 "§ 5.5.7 Initialization Segment Received")
  [(2)](#ref-for-dom-sourcebuffer-videotracks-4 "Reference 2")
  [(3)](#ref-for-dom-sourcebuffer-videotracks-5 "Reference 3")
::::

:::: {#dfn-panel-for-dom-sourcebuffer-texttracks .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: textTracks"}
[]{.caret}

::: {}
[Permalink](#dom-sourcebuffer-texttracks){.self-link
aria-label="Permalink for definition: textTracks. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-544711679 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3.8 removeSourceBuffer()
  method](#ref-for-dom-sourcebuffer-texttracks-1 "§ 3.8 removeSourceBuffer() method")
- [§ 5. SourceBuffer
  interface](#ref-for-dom-sourcebuffer-texttracks-2 "§ 5. SourceBuffer interface")
- [§ 5.5.7 Initialization Segment
  Received](#ref-for-dom-sourcebuffer-texttracks-3 "§ 5.5.7 Initialization Segment Received")
  [(2)](#ref-for-dom-sourcebuffer-texttracks-4 "Reference 2")
::::

:::: {#dfn-panel-for-dom-sourcebuffer-appendwindowstart .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: appendWindowStart"}
[]{.caret}

::: {}
[Permalink](#dom-sourcebuffer-appendwindowstart){.self-link
aria-label="Permalink for definition: appendWindowStart. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-544711679 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 2.
  Definitions](#ref-for-dom-sourcebuffer-appendwindowstart-1 "§ 2. Definitions")
- [§ 5. SourceBuffer
  interface](#ref-for-dom-sourcebuffer-appendwindowstart-2 "§ 5. SourceBuffer interface")
- [§ 5.1
  Attributes](#ref-for-dom-sourcebuffer-appendwindowstart-3 "§ 5.1 Attributes")
- [§ 5.2
  Methods](#ref-for-dom-sourcebuffer-appendwindowstart-4 "§ 5.2 Methods")
- [§ 5.5.8 Coded Frame
  Processing](#ref-for-dom-sourcebuffer-appendwindowstart-5 "§ 5.5.8 Coded Frame Processing")
  [(2)](#ref-for-dom-sourcebuffer-appendwindowstart-6 "Reference 2")
  [(3)](#ref-for-dom-sourcebuffer-appendwindowstart-7 "Reference 3")
  [(4)](#ref-for-dom-sourcebuffer-appendwindowstart-8 "Reference 4")
::::

:::: {#dfn-panel-for-dom-sourcebuffer-appendwindowend .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: appendWindowEnd"}
[]{.caret}

::: {}
[Permalink](#dom-sourcebuffer-appendwindowend){.self-link
aria-label="Permalink for definition: appendWindowEnd. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-544711679 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 2.
  Definitions](#ref-for-dom-sourcebuffer-appendwindowend-1 "§ 2. Definitions")
- [§ 5. SourceBuffer
  interface](#ref-for-dom-sourcebuffer-appendwindowend-2 "§ 5. SourceBuffer interface")
- [§ 5.1
  Attributes](#ref-for-dom-sourcebuffer-appendwindowend-3 "§ 5.1 Attributes")
- [§ 5.2
  Methods](#ref-for-dom-sourcebuffer-appendwindowend-4 "§ 5.2 Methods")
- [§ 5.5.8 Coded Frame
  Processing](#ref-for-dom-sourcebuffer-appendwindowend-5 "§ 5.5.8 Coded Frame Processing")
  [(2)](#ref-for-dom-sourcebuffer-appendwindowend-6 "Reference 2")
  [(3)](#ref-for-dom-sourcebuffer-appendwindowend-7 "Reference 3")
::::

:::: {#dfn-panel-for-dom-sourcebuffer-onupdatestart .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: onupdatestart"}
[]{.caret}

::: {}
[Permalink](#dom-sourcebuffer-onupdatestart){.self-link
aria-label="Permalink for definition: onupdatestart. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-544711679 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 5. SourceBuffer
  interface](#ref-for-dom-sourcebuffer-onupdatestart-1 "§ 5. SourceBuffer interface")
::::

:::: {#dfn-panel-for-dom-sourcebuffer-onupdate .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: onupdate"}
[]{.caret}

::: {}
[Permalink](#dom-sourcebuffer-onupdate){.self-link
aria-label="Permalink for definition: onupdate. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-544711679 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 5. SourceBuffer
  interface](#ref-for-dom-sourcebuffer-onupdate-1 "§ 5. SourceBuffer interface")
::::

:::: {#dfn-panel-for-dom-sourcebuffer-onupdateend .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: onupdateend"}
[]{.caret}

::: {}
[Permalink](#dom-sourcebuffer-onupdateend){.self-link
aria-label="Permalink for definition: onupdateend. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-544711679 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 5. SourceBuffer
  interface](#ref-for-dom-sourcebuffer-onupdateend-1 "§ 5. SourceBuffer interface")
::::

:::: {#dfn-panel-for-dom-sourcebuffer-onerror .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: onerror"}
[]{.caret}

::: {}
[Permalink](#dom-sourcebuffer-onerror){.self-link
aria-label="Permalink for definition: onerror. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-544711679 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 5. SourceBuffer
  interface](#ref-for-dom-sourcebuffer-onerror-1 "§ 5. SourceBuffer interface")
::::

:::: {#dfn-panel-for-dom-sourcebuffer-onabort .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: onabort"}
[]{.caret}

::: {}
[Permalink](#dom-sourcebuffer-onabort){.self-link
aria-label="Permalink for definition: onabort. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-544711679 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 5. SourceBuffer
  interface](#ref-for-dom-sourcebuffer-onabort-1 "§ 5. SourceBuffer interface")
::::

:::: {#dfn-panel-for-dom-sourcebuffer-appendbuffer .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: appendBuffer"}
[]{.caret}

::: {}
[Permalink](#dom-sourcebuffer-appendbuffer){.self-link
aria-label="Permalink for definition: appendBuffer. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-544711679 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3.5 duration
  attribute](#ref-for-dom-sourcebuffer-appendbuffer-1 "§ 3.5 duration attribute")
- [§ 3.15.1 Attaching to a media
  element](#ref-for-dom-sourcebuffer-appendbuffer-2 "§ 3.15.1 Attaching to a media element")
- [§ 3.15.3
  Seeking](#ref-for-dom-sourcebuffer-appendbuffer-3 "§ 3.15.3 Seeking")
- [§ 5. SourceBuffer
  interface](#ref-for-dom-sourcebuffer-appendbuffer-4 "§ 5. SourceBuffer interface")
- [§ 5.1
  Attributes](#ref-for-dom-sourcebuffer-appendbuffer-5 "§ 5.1 Attributes")
- [§ 5.2
  Methods](#ref-for-dom-sourcebuffer-appendbuffer-6 "§ 5.2 Methods")
- [§ 5.5.1 Segment Parser
  Loop](#ref-for-dom-sourcebuffer-appendbuffer-7 "§ 5.5.1 Segment Parser Loop")
  [(2)](#ref-for-dom-sourcebuffer-appendbuffer-8 "Reference 2")
- [§ 5.5.5 Buffer
  Append](#ref-for-dom-sourcebuffer-appendbuffer-9 "§ 5.5.5 Buffer Append")
- [§ 9.2 Event
  Summary](#ref-for-dom-sourcebuffer-appendbuffer-10 "§ 9.2 Event Summary")
- [§ 9.3.1 Buffered
  Change](#ref-for-dom-sourcebuffer-appendbuffer-11 "§ 9.3.1 Buffered Change")
- [§ 14. Byte Stream
  Formats](#ref-for-dom-sourcebuffer-appendbuffer-12 "§ 14. Byte Stream Formats")
::::

:::: {#dfn-panel-for-dom-sourcebuffer-abort .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: abort"}
[]{.caret}

::: {}
[Permalink](#dom-sourcebuffer-abort){.self-link
aria-label="Permalink for definition: abort. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-544711679 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 2.
  Definitions](#ref-for-dom-sourcebuffer-abort-1 "§ 2. Definitions")
- [§ 5. SourceBuffer
  interface](#ref-for-dom-sourcebuffer-abort-2 "§ 5. SourceBuffer interface")
- [§ 5.4 Event
  Summary](#ref-for-dom-sourcebuffer-abort-3 "§ 5.4 Event Summary")
::::

:::: {#dfn-panel-for-dom-sourcebuffer-changetype .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: changeType"}
[]{.caret}

::: {}
[Permalink](#dom-sourcebuffer-changetype){.self-link
aria-label="Permalink for definition: changeType. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-544711679 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ Status of This
  Document](#ref-for-dom-sourcebuffer-changetype-1 "§ Status of This Document")
- [§ 2.
  Definitions](#ref-for-dom-sourcebuffer-changetype-2 "§ 2. Definitions")
- [§ 5. SourceBuffer
  interface](#ref-for-dom-sourcebuffer-changetype-3 "§ 5. SourceBuffer interface")
- [§ 5.1
  Attributes](#ref-for-dom-sourcebuffer-changetype-4 "§ 5.1 Attributes")
- [§ 5.5.1 Segment Parser
  Loop](#ref-for-dom-sourcebuffer-changetype-5 "§ 5.5.1 Segment Parser Loop")
- [§ 5.5.7 Initialization Segment
  Received](#ref-for-dom-sourcebuffer-changetype-6 "§ 5.5.7 Initialization Segment Received")
  [(2)](#ref-for-dom-sourcebuffer-changetype-7 "Reference 2")
  [(3)](#ref-for-dom-sourcebuffer-changetype-8 "Reference 3")
  [(4)](#ref-for-dom-sourcebuffer-changetype-9 "Reference 4")
  [(5)](#ref-for-dom-sourcebuffer-changetype-10 "Reference 5")
  [(6)](#ref-for-dom-sourcebuffer-changetype-11 "Reference 6")
  [(7)](#ref-for-dom-sourcebuffer-changetype-12 "Reference 7")
  [(8)](#ref-for-dom-sourcebuffer-changetype-13 "Reference 8")
  [(9)](#ref-for-dom-sourcebuffer-changetype-14 "Reference 9")
  [(10)](#ref-for-dom-sourcebuffer-changetype-15 "Reference 10")
  [(11)](#ref-for-dom-sourcebuffer-changetype-16 "Reference 11")
- [§ 14. Byte Stream
  Formats](#ref-for-dom-sourcebuffer-changetype-17 "§ 14. Byte Stream Formats")
  [(2)](#ref-for-dom-sourcebuffer-changetype-18 "Reference 2")
::::

:::: {#dfn-panel-for-dom-sourcebuffer-remove .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: remove"}
[]{.caret}

::: {}
[Permalink](#dom-sourcebuffer-remove){.self-link
aria-label="Permalink for definition: remove. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-544711679 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3.15.6 Duration
  change](#ref-for-dom-sourcebuffer-remove-1 "§ 3.15.6 Duration change")
- [§ 5. SourceBuffer
  interface](#ref-for-dom-sourcebuffer-remove-2 "§ 5. SourceBuffer interface")
- [§ 5.1
  Attributes](#ref-for-dom-sourcebuffer-remove-3 "§ 5.1 Attributes")
- [§ 5.5.4 Prepare
  Append](#ref-for-dom-sourcebuffer-remove-4 "§ 5.5.4 Prepare Append")
- [§ 9.2 Event
  Summary](#ref-for-dom-sourcebuffer-remove-5 "§ 9.2 Event Summary")
- [§ 9.3.1 Buffered
  Change](#ref-for-dom-sourcebuffer-remove-6 "§ 9.3.1 Buffered Change")
::::

:::: {#dfn-panel-for-track-buffer .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: track buffer"}
[]{.caret}

::: {}
[Permalink](#track-buffer){.self-link
aria-label="Permalink for definition: track buffer. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 2. Definitions](#ref-for-track-buffer-1 "§ 2. Definitions")
- [§ 3.15.6 Duration
  change](#ref-for-track-buffer-2 "§ 3.15.6 Duration change")
- [§ 3.15.7 End of
  stream](#ref-for-track-buffer-3 "§ 3.15.7 End of stream")
- [§ 5.1 Attributes](#ref-for-track-buffer-4 "§ 5.1 Attributes")
  [(2)](#ref-for-track-buffer-5 "Reference 2")
  [(3)](#ref-for-track-buffer-6 "Reference 3")
  [(4)](#ref-for-track-buffer-7 "Reference 4")
- [§ 5.3 Track Buffers](#ref-for-track-buffer-8 "§ 5.3 Track Buffers")
  [(2)](#ref-for-track-buffer-9 "Reference 2")
  [(3)](#ref-for-track-buffer-10 "Reference 3")
  [(4)](#ref-for-track-buffer-11 "Reference 4")
  [(5)](#ref-for-track-buffer-12 "Reference 5")
  [(6)](#ref-for-track-buffer-13 "Reference 6")
  [(7)](#ref-for-track-buffer-14 "Reference 7")
  [(8)](#ref-for-track-buffer-15 "Reference 8")
- [§ 5.5.1 Segment Parser
  Loop](#ref-for-track-buffer-16 "§ 5.5.1 Segment Parser Loop")
- [§ 5.5.2 Reset Parser
  State](#ref-for-track-buffer-17 "§ 5.5.2 Reset Parser State")
  [(2)](#ref-for-track-buffer-18 "Reference 2")
  [(3)](#ref-for-track-buffer-19 "Reference 3")
  [(4)](#ref-for-track-buffer-20 "Reference 4")
- [§ 5.5.7 Initialization Segment
  Received](#ref-for-track-buffer-21 "§ 5.5.7 Initialization Segment Received")
  [(2)](#ref-for-track-buffer-22 "Reference 2")
  [(3)](#ref-for-track-buffer-23 "Reference 3")
  [(4)](#ref-for-track-buffer-24 "Reference 4")
  [(5)](#ref-for-track-buffer-25 "Reference 5")
  [(6)](#ref-for-track-buffer-26 "Reference 6")
  [(7)](#ref-for-track-buffer-27 "Reference 7")
- [§ 5.5.8 Coded Frame
  Processing](#ref-for-track-buffer-28 "§ 5.5.8 Coded Frame Processing")
  [(2)](#ref-for-track-buffer-29 "Reference 2")
  [(3)](#ref-for-track-buffer-30 "Reference 3")
  [(4)](#ref-for-track-buffer-31 "Reference 4")
  [(5)](#ref-for-track-buffer-32 "Reference 5")
  [(6)](#ref-for-track-buffer-33 "Reference 6")
- [§ 5.5.9 Coded Frame
  Removal](#ref-for-track-buffer-34 "§ 5.5.9 Coded Frame Removal")
  [(2)](#ref-for-track-buffer-35 "Reference 2")
  [(3)](#ref-for-track-buffer-36 "Reference 3")
  [(4)](#ref-for-track-buffer-37 "Reference 4")
  [(5)](#ref-for-track-buffer-38 "Reference 5")
  [(6)](#ref-for-track-buffer-39 "Reference 6")
  [(7)](#ref-for-track-buffer-40 "Reference 7")
  [(8)](#ref-for-track-buffer-41 "Reference 8")
- [§ 5.5.11 Audio Splice
  Frame](#ref-for-track-buffer-42 "§ 5.5.11 Audio Splice Frame")
- [§ 5.5.13 Text Splice
  Frame](#ref-for-track-buffer-43 "§ 5.5.13 Text Splice Frame")
::::

:::: {#dfn-panel-for-last-decode-timestamp .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: last decode timestamp"}
[]{.caret}

::: {}
[Permalink](#last-decode-timestamp){.self-link
aria-label="Permalink for definition: last decode timestamp. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.5.2 Reset Parser
  State](#ref-for-last-decode-timestamp-1 "§ 5.5.2 Reset Parser State")
- [§ 5.5.8 Coded Frame
  Processing](#ref-for-last-decode-timestamp-2 "§ 5.5.8 Coded Frame Processing")
  [(2)](#ref-for-last-decode-timestamp-3 "Reference 2")
  [(3)](#ref-for-last-decode-timestamp-4 "Reference 3")
  [(4)](#ref-for-last-decode-timestamp-5 "Reference 4")
  [(5)](#ref-for-last-decode-timestamp-6 "Reference 5")
  [(6)](#ref-for-last-decode-timestamp-7 "Reference 6")
  [(7)](#ref-for-last-decode-timestamp-8 "Reference 7")
- [§ 5.5.9 Coded Frame
  Removal](#ref-for-last-decode-timestamp-9 "§ 5.5.9 Coded Frame Removal")
  [(2)](#ref-for-last-decode-timestamp-10 "Reference 2")
::::

:::: {#dfn-panel-for-last-frame-duration .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: last frame duration"}
[]{.caret}

::: {}
[Permalink](#last-frame-duration){.self-link
aria-label="Permalink for definition: last frame duration. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.5.2 Reset Parser
  State](#ref-for-last-frame-duration-1 "§ 5.5.2 Reset Parser State")
- [§ 5.5.8 Coded Frame
  Processing](#ref-for-last-frame-duration-2 "§ 5.5.8 Coded Frame Processing")
  [(2)](#ref-for-last-frame-duration-3 "Reference 2")
  [(3)](#ref-for-last-frame-duration-4 "Reference 3")
- [§ 5.5.9 Coded Frame
  Removal](#ref-for-last-frame-duration-5 "§ 5.5.9 Coded Frame Removal")
::::

:::: {#dfn-panel-for-highest-end-timestamp .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: highest end timestamp"}
[]{.caret}

::: {}
[Permalink](#highest-end-timestamp){.self-link
aria-label="Permalink for definition: highest end timestamp. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.5.2 Reset Parser
  State](#ref-for-highest-end-timestamp-1 "§ 5.5.2 Reset Parser State")
- [§ 5.5.8 Coded Frame
  Processing](#ref-for-highest-end-timestamp-2 "§ 5.5.8 Coded Frame Processing")
  [(2)](#ref-for-highest-end-timestamp-3 "Reference 2")
  [(3)](#ref-for-highest-end-timestamp-4 "Reference 3")
  [(4)](#ref-for-highest-end-timestamp-5 "Reference 4")
  [(5)](#ref-for-highest-end-timestamp-6 "Reference 5")
  [(6)](#ref-for-highest-end-timestamp-7 "Reference 6")
  [(7)](#ref-for-highest-end-timestamp-8 "Reference 7")
- [§ 5.5.9 Coded Frame
  Removal](#ref-for-highest-end-timestamp-9 "§ 5.5.9 Coded Frame Removal")
::::

:::: {#dfn-panel-for-need-RAP-flag .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: need random access point flag"}
[]{.caret}

::: {}
[Permalink](#need-RAP-flag){.self-link
aria-label="Permalink for definition: need random access point flag. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.5.2 Reset Parser
  State](#ref-for-need-RAP-flag-1 "§ 5.5.2 Reset Parser State")
- [§ 5.5.7 Initialization Segment
  Received](#ref-for-need-RAP-flag-2 "§ 5.5.7 Initialization Segment Received")
- [§ 5.5.8 Coded Frame
  Processing](#ref-for-need-RAP-flag-3 "§ 5.5.8 Coded Frame Processing")
  [(2)](#ref-for-need-RAP-flag-4 "Reference 2")
  [(3)](#ref-for-need-RAP-flag-5 "Reference 3")
  [(4)](#ref-for-need-RAP-flag-6 "Reference 4")
  [(5)](#ref-for-need-RAP-flag-7 "Reference 5")
  [(6)](#ref-for-need-RAP-flag-8 "Reference 6")
- [§ 5.5.9 Coded Frame
  Removal](#ref-for-need-RAP-flag-9 "§ 5.5.9 Coded Frame Removal")
::::

:::: {#dfn-panel-for-track-buffer-ranges .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: track buffer ranges"}
[]{.caret}

::: {}
[Permalink](#track-buffer-ranges){.self-link
aria-label="Permalink for definition: track buffer ranges. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 3.15.6 Duration
  change](#ref-for-track-buffer-ranges-1 "§ 3.15.6 Duration change")
- [§ 3.15.7 End of
  stream](#ref-for-track-buffer-ranges-2 "§ 3.15.7 End of stream")
- [§ 5.1 Attributes](#ref-for-track-buffer-ranges-3 "§ 5.1 Attributes")
  [(2)](#ref-for-track-buffer-ranges-4 "Reference 2")
- [§ 5.3 Track
  Buffers](#ref-for-track-buffer-ranges-5 "§ 5.3 Track Buffers")
  [(2)](#ref-for-track-buffer-ranges-6 "Reference 2")
::::

:::: {#dfn-panel-for-dfn-updatestart .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: updatestart"}
[]{.caret}

::: {}
[Permalink](#dfn-updatestart){.self-link
aria-label="Permalink for definition: updatestart. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.1 Attributes](#ref-for-dfn-updatestart-1 "§ 5.1 Attributes")
- [§ 5.2 Methods](#ref-for-dfn-updatestart-2 "§ 5.2 Methods")
- [§ 5.5.6 Range
  Removal](#ref-for-dfn-updatestart-3 "§ 5.5.6 Range Removal")
- [§ 8.1 Attributes](#ref-for-dfn-updatestart-4 "§ 8.1 Attributes")
::::

:::: {#dfn-panel-for-dfn-update .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: update"}
[]{.caret}

::: {}
[Permalink](#dfn-update){.self-link
aria-label="Permalink for definition: update. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.1 Attributes](#ref-for-dfn-update-1 "§ 5.1 Attributes")
- [§ 5.5.5 Buffer Append](#ref-for-dfn-update-2 "§ 5.5.5 Buffer Append")
- [§ 5.5.6 Range Removal](#ref-for-dfn-update-3 "§ 5.5.6 Range Removal")
::::

:::: {#dfn-panel-for-dfn-updateend .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: updateend"}
[]{.caret}

::: {}
[Permalink](#dfn-updateend){.self-link
aria-label="Permalink for definition: updateend. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 3.8 removeSourceBuffer()
  method](#ref-for-dfn-updateend-1 "§ 3.8 removeSourceBuffer() method")
- [§ 5.1 Attributes](#ref-for-dfn-updateend-2 "§ 5.1 Attributes")
- [§ 5.2 Methods](#ref-for-dfn-updateend-3 "§ 5.2 Methods")
- [§ 5.5.3 Append
  Error](#ref-for-dfn-updateend-4 "§ 5.5.3 Append Error")
- [§ 5.5.5 Buffer
  Append](#ref-for-dfn-updateend-5 "§ 5.5.5 Buffer Append")
- [§ 5.5.6 Range
  Removal](#ref-for-dfn-updateend-6 "§ 5.5.6 Range Removal")
- [§ 8.1 Attributes](#ref-for-dfn-updateend-7 "§ 8.1 Attributes")
::::

:::: {#dfn-panel-for-dfn-error .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: error"}
[]{.caret}

::: {}
[Permalink](#dfn-error){.self-link
aria-label="Permalink for definition: error. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.1 Attributes](#ref-for-dfn-error-1 "§ 5.1 Attributes")
- [§ 5.5.3 Append Error](#ref-for-dfn-error-2 "§ 5.5.3 Append Error")
- [§ 5.5.4 Prepare
  Append](#ref-for-dfn-error-3 "§ 5.5.4 Prepare Append")
  [(2)](#ref-for-dfn-error-4 "Reference 2")
::::

:::: {#dfn-panel-for-dfn-abort .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: abort"}
[]{.caret}

::: {}
[Permalink](#dfn-abort){.self-link
aria-label="Permalink for definition: abort. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 3.8 removeSourceBuffer()
  method](#ref-for-dfn-abort-1 "§ 3.8 removeSourceBuffer() method")
- [§ 5.1 Attributes](#ref-for-dfn-abort-2 "§ 5.1 Attributes")
- [§ 5.2 Methods](#ref-for-dfn-abort-3 "§ 5.2 Methods")
::::

:::: {#dfn-panel-for-dfn-segment-parser-loop .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Segment Parser Loop"}
[]{.caret}

::: {}
[Permalink](#dfn-segment-parser-loop){.self-link
aria-label="Permalink for definition: Segment Parser Loop. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.5.5 Buffer
  Append](#ref-for-dfn-segment-parser-loop-1 "§ 5.5.5 Buffer Append")
  [(2)](#ref-for-dfn-segment-parser-loop-2 "Reference 2")
- [§ 5.5.7 Initialization Segment
  Received](#ref-for-dfn-segment-parser-loop-3 "§ 5.5.7 Initialization Segment Received")
- [§ 5.5.8 Coded Frame
  Processing](#ref-for-dfn-segment-parser-loop-4 "§ 5.5.8 Coded Frame Processing")
- [§ 14. Byte Stream
  Formats](#ref-for-dfn-segment-parser-loop-5 "§ 14. Byte Stream Formats")
::::

:::: {#dfn-panel-for-dfn-append-state .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: [[append state]]"}
[]{.caret}

::: {}
[Permalink](#dfn-append-state){.self-link
aria-label="Permalink for definition: [[append state]]. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.1 Attributes](#ref-for-dfn-append-state-1 "§ 5.1 Attributes")
  [(2)](#ref-for-dfn-append-state-2 "Reference 2")
- [§ 5.5.1 Segment Parser
  Loop](#ref-for-dfn-append-state-3 "§ 5.5.1 Segment Parser Loop")
  [(2)](#ref-for-dfn-append-state-4 "Reference 2")
  [(3)](#ref-for-dfn-append-state-5 "Reference 3")
  [(4)](#ref-for-dfn-append-state-6 "Reference 4")
  [(5)](#ref-for-dfn-append-state-7 "Reference 5")
  [(6)](#ref-for-dfn-append-state-8 "Reference 6")
  [(7)](#ref-for-dfn-append-state-9 "Reference 7")
- [§ 5.5.2 Reset Parser
  State](#ref-for-dfn-append-state-10 "§ 5.5.2 Reset Parser State")
  [(2)](#ref-for-dfn-append-state-11 "Reference 2")
::::

:::: {#dfn-panel-for-sourcebuffer-waiting-for-segment .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: WAITING_FOR_SEGMENT"}
[]{.caret}

::: {}
[Permalink](#sourcebuffer-waiting-for-segment){.self-link
aria-label="Permalink for definition: WAITING_FOR_SEGMENT. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.5.1 Segment Parser
  Loop](#ref-for-sourcebuffer-waiting-for-segment-1 "§ 5.5.1 Segment Parser Loop")
  [(2)](#ref-for-sourcebuffer-waiting-for-segment-2 "Reference 2")
  [(3)](#ref-for-sourcebuffer-waiting-for-segment-3 "Reference 3")
  [(4)](#ref-for-sourcebuffer-waiting-for-segment-4 "Reference 4")
- [§ 5.5.2 Reset Parser
  State](#ref-for-sourcebuffer-waiting-for-segment-5 "§ 5.5.2 Reset Parser State")
::::

:::: {#dfn-panel-for-sourcebuffer-parsing-init-segment .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: PARSING_INIT_SEGMENT"}
[]{.caret}

::: {}
[Permalink](#sourcebuffer-parsing-init-segment){.self-link
aria-label="Permalink for definition: PARSING_INIT_SEGMENT. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.5.1 Segment Parser
  Loop](#ref-for-sourcebuffer-parsing-init-segment-1 "§ 5.5.1 Segment Parser Loop")
  [(2)](#ref-for-sourcebuffer-parsing-init-segment-2 "Reference 2")
::::

:::: {#dfn-panel-for-sourcebuffer-parsing-media-segment .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: PARSING_MEDIA_SEGMENT"}
[]{.caret}

::: {}
[Permalink](#sourcebuffer-parsing-media-segment){.self-link
aria-label="Permalink for definition: PARSING_MEDIA_SEGMENT. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.1
  Attributes](#ref-for-sourcebuffer-parsing-media-segment-1 "§ 5.1 Attributes")
  [(2)](#ref-for-sourcebuffer-parsing-media-segment-2 "Reference 2")
- [§ 5.5.1 Segment Parser
  Loop](#ref-for-sourcebuffer-parsing-media-segment-3 "§ 5.5.1 Segment Parser Loop")
  [(2)](#ref-for-sourcebuffer-parsing-media-segment-4 "Reference 2")
- [§ 5.5.2 Reset Parser
  State](#ref-for-sourcebuffer-parsing-media-segment-5 "§ 5.5.2 Reset Parser State")
::::

:::: {#dfn-panel-for-dfn-input-buffer .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: [[input buffer]]"}
[]{.caret}

::: {}
[Permalink](#dfn-input-buffer){.self-link
aria-label="Permalink for definition: [[input buffer]]. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.2 Methods](#ref-for-dfn-input-buffer-1 "§ 5.2 Methods")
- [§ 5.5.1 Segment Parser
  Loop](#ref-for-dfn-input-buffer-2 "§ 5.5.1 Segment Parser Loop")
  [(2)](#ref-for-dfn-input-buffer-3 "Reference 2")
  [(3)](#ref-for-dfn-input-buffer-4 "Reference 3")
  [(4)](#ref-for-dfn-input-buffer-5 "Reference 4")
  [(5)](#ref-for-dfn-input-buffer-6 "Reference 5")
  [(6)](#ref-for-dfn-input-buffer-7 "Reference 6")
  [(7)](#ref-for-dfn-input-buffer-8 "Reference 7")
  [(8)](#ref-for-dfn-input-buffer-9 "Reference 8")
  [(9)](#ref-for-dfn-input-buffer-10 "Reference 9")
  [(10)](#ref-for-dfn-input-buffer-11 "Reference 10")
- [§ 5.5.2 Reset Parser
  State](#ref-for-dfn-input-buffer-12 "§ 5.5.2 Reset Parser State")
  [(2)](#ref-for-dfn-input-buffer-13 "Reference 2")
- [§ 5.5.10 Coded Frame
  Eviction](#ref-for-dfn-input-buffer-14 "§ 5.5.10 Coded Frame Eviction")
::::

:::: {#dfn-panel-for-dfn-buffer-full-flag .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: [[buffer full flag]]"}
[]{.caret}

::: {}
[Permalink](#dfn-buffer-full-flag){.self-link
aria-label="Permalink for definition: [[buffer full flag]]. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.5.1 Segment Parser
  Loop](#ref-for-dfn-buffer-full-flag-1 "§ 5.5.1 Segment Parser Loop")
- [§ 5.5.4 Prepare
  Append](#ref-for-dfn-buffer-full-flag-2 "§ 5.5.4 Prepare Append")
- [§ 5.5.9 Coded Frame
  Removal](#ref-for-dfn-buffer-full-flag-3 "§ 5.5.9 Coded Frame Removal")
  [(2)](#ref-for-dfn-buffer-full-flag-4 "Reference 2")
- [§ 5.5.10 Coded Frame
  Eviction](#ref-for-dfn-buffer-full-flag-5 "§ 5.5.10 Coded Frame Eviction")
  [(2)](#ref-for-dfn-buffer-full-flag-6 "Reference 2")
::::

:::: {#dfn-panel-for-dfn-group-start-timestamp .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: [[group start timestamp]]"}
[]{.caret}

::: {}
[Permalink](#dfn-group-start-timestamp){.self-link
aria-label="Permalink for definition: [[group start timestamp]]. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.1
  Attributes](#ref-for-dfn-group-start-timestamp-1 "§ 5.1 Attributes")
  [(2)](#ref-for-dfn-group-start-timestamp-2 "Reference 2")
- [§ 5.5.2 Reset Parser
  State](#ref-for-dfn-group-start-timestamp-3 "§ 5.5.2 Reset Parser State")
- [§ 5.5.8 Coded Frame
  Processing](#ref-for-dfn-group-start-timestamp-4 "§ 5.5.8 Coded Frame Processing")
  [(2)](#ref-for-dfn-group-start-timestamp-5 "Reference 2")
  [(3)](#ref-for-dfn-group-start-timestamp-6 "Reference 3")
  [(4)](#ref-for-dfn-group-start-timestamp-7 "Reference 4")
  [(5)](#ref-for-dfn-group-start-timestamp-8 "Reference 5")
- [§ 5.5.9 Coded Frame
  Removal](#ref-for-dfn-group-start-timestamp-9 "§ 5.5.9 Coded Frame Removal")
::::

:::: {#dfn-panel-for-dfn-group-end-timestamp .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: [[group end timestamp]]"}
[]{.caret}

::: {}
[Permalink](#dfn-group-end-timestamp){.self-link
aria-label="Permalink for definition: [[group end timestamp]]. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.1
  Attributes](#ref-for-dfn-group-end-timestamp-1 "§ 5.1 Attributes")
- [§ 5.5.1 Segment Parser
  Loop](#ref-for-dfn-group-end-timestamp-2 "§ 5.5.1 Segment Parser Loop")
- [§ 5.5.2 Reset Parser
  State](#ref-for-dfn-group-end-timestamp-3 "§ 5.5.2 Reset Parser State")
- [§ 5.5.8 Coded Frame
  Processing](#ref-for-dfn-group-end-timestamp-4 "§ 5.5.8 Coded Frame Processing")
  [(2)](#ref-for-dfn-group-end-timestamp-5 "Reference 2")
  [(3)](#ref-for-dfn-group-end-timestamp-6 "Reference 3")
  [(4)](#ref-for-dfn-group-end-timestamp-7 "Reference 4")
  [(5)](#ref-for-dfn-group-end-timestamp-8 "Reference 5")
  [(6)](#ref-for-dfn-group-end-timestamp-9 "Reference 6")
- [§ 5.5.9 Coded Frame
  Removal](#ref-for-dfn-group-end-timestamp-10 "§ 5.5.9 Coded Frame Removal")
  [(2)](#ref-for-dfn-group-end-timestamp-11 "Reference 2")
::::

:::: {#dfn-panel-for-dfn-generate-timestamps-flag .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: [[generate timestamps flag]]"}
[]{.caret}

::: {}
[Permalink](#dfn-generate-timestamps-flag){.self-link
aria-label="Permalink for definition: [[generate timestamps flag]]. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
:::

**Referenced in:**

- [§ 3.7 addSourceBuffer()
  method](#ref-for-dfn-generate-timestamps-flag-1 "§ 3.7 addSourceBuffer() method")
  [(2)](#ref-for-dfn-generate-timestamps-flag-2 "Reference 2")
- [§ 5.1
  Attributes](#ref-for-dfn-generate-timestamps-flag-3 "§ 5.1 Attributes")
- [§ 5.2
  Methods](#ref-for-dfn-generate-timestamps-flag-4 "§ 5.2 Methods")
  [(2)](#ref-for-dfn-generate-timestamps-flag-5 "Reference 2")
- [§ 5.5.8 Coded Frame
  Processing](#ref-for-dfn-generate-timestamps-flag-6 "§ 5.5.8 Coded Frame Processing")
  [(2)](#ref-for-dfn-generate-timestamps-flag-7 "Reference 2")
::::

:::: {#dfn-panel-for-dfn-reset-parser-state .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Reset Parser State"}
[]{.caret}

::: {}
[Permalink](#dfn-reset-parser-state){.self-link
aria-label="Permalink for definition: Reset Parser State. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.2 Methods](#ref-for-dfn-reset-parser-state-1 "§ 5.2 Methods")
  [(2)](#ref-for-dfn-reset-parser-state-2 "Reference 2")
- [§ 5.5.3 Append
  Error](#ref-for-dfn-reset-parser-state-3 "§ 5.5.3 Append Error")
::::

:::: {#dfn-panel-for-dfn-append-error .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Append Error"}
[]{.caret}

::: {}
[Permalink](#dfn-append-error){.self-link
aria-label="Permalink for definition: Append Error. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
:::

**Referenced in:**

- [§ 2. Definitions](#ref-for-dfn-append-error-1 "§ 2. Definitions")
  [(2)](#ref-for-dfn-append-error-2 "Reference 2")
- [§ 5.5.1 Segment Parser
  Loop](#ref-for-dfn-append-error-3 "§ 5.5.1 Segment Parser Loop")
  [(2)](#ref-for-dfn-append-error-4 "Reference 2")
- [§ 5.5.7 Initialization Segment
  Received](#ref-for-dfn-append-error-5 "§ 5.5.7 Initialization Segment Received")
  [(2)](#ref-for-dfn-append-error-6 "Reference 2")
  [(3)](#ref-for-dfn-append-error-7 "Reference 3")
- [§ 14. Byte Stream
  Formats](#ref-for-dfn-append-error-8 "§ 14. Byte Stream Formats")
  [(2)](#ref-for-dfn-append-error-9 "Reference 2")
::::

:::: {#dfn-panel-for-dfn-prepare-append .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Prepare Append"}
[]{.caret}

::: {}
[Permalink](#dfn-prepare-append){.self-link
aria-label="Permalink for definition: Prepare Append. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.2 Methods](#ref-for-dfn-prepare-append-1 "§ 5.2 Methods")
::::

:::: {#dfn-panel-for-dfn-buffer-append .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Buffer Append"}
[]{.caret}

::: {}
[Permalink](#dfn-buffer-append){.self-link
aria-label="Permalink for definition: Buffer Append. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 3.8 removeSourceBuffer()
  method](#ref-for-dfn-buffer-append-1 "§ 3.8 removeSourceBuffer() method")
- [§ 5.2 Methods](#ref-for-dfn-buffer-append-2 "§ 5.2 Methods")
  [(2)](#ref-for-dfn-buffer-append-3 "Reference 2")
::::

:::: {#dfn-panel-for-dfn-range-removal .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Range Removal"}
[]{.caret}

::: {}
[Permalink](#dfn-range-removal){.self-link
aria-label="Permalink for definition: Range Removal. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.2 Methods](#ref-for-dfn-range-removal-1 "§ 5.2 Methods")
  [(2)](#ref-for-dfn-range-removal-2 "Reference 2")
::::

:::: {#dfn-panel-for-dfn-initialization-segment-received .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Initialization Segment Received"}
[]{.caret}

::: {}
[Permalink](#dfn-initialization-segment-received){.self-link
aria-label="Permalink for definition: Initialization Segment Received. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.5.1 Segment Parser
  Loop](#ref-for-dfn-initialization-segment-received-1 "§ 5.5.1 Segment Parser Loop")
- [§ 14. Byte Stream
  Formats](#ref-for-dfn-initialization-segment-received-2 "§ 14. Byte Stream Formats")
::::

:::: {#dfn-panel-for-dfn-first-initialization-segment-received-flag .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: [[first initialization segment received flag]]"}
[]{.caret}

::: {}
[Permalink](#dfn-first-initialization-segment-received-flag){.self-link
aria-label="Permalink for definition: [[first initialization segment received flag]]. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.5.1 Segment Parser
  Loop](#ref-for-dfn-first-initialization-segment-received-flag-1 "§ 5.5.1 Segment Parser Loop")
- [§ 5.5.7 Initialization Segment
  Received](#ref-for-dfn-first-initialization-segment-received-flag-2 "§ 5.5.7 Initialization Segment Received")
  [(2)](#ref-for-dfn-first-initialization-segment-received-flag-3 "Reference 2")
  [(3)](#ref-for-dfn-first-initialization-segment-received-flag-4 "Reference 3")
  [(4)](#ref-for-dfn-first-initialization-segment-received-flag-5 "Reference 4")
::::

:::: {#dfn-panel-for-dfn-pending-initialization-segment-for-changetype-flag .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: [[pending initialization segment for changeType flag]]"}
[]{.caret}

::: {}
[Permalink](#dfn-pending-initialization-segment-for-changetype-flag){.self-link
aria-label="Permalink for definition: [[pending initialization segment for changeType flag]]. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.2
  Methods](#ref-for-dfn-pending-initialization-segment-for-changetype-flag-1 "§ 5.2 Methods")
- [§ 5.5.1 Segment Parser
  Loop](#ref-for-dfn-pending-initialization-segment-for-changetype-flag-2 "§ 5.5.1 Segment Parser Loop")
- [§ 5.5.7 Initialization Segment
  Received](#ref-for-dfn-pending-initialization-segment-for-changetype-flag-3 "§ 5.5.7 Initialization Segment Received")
::::

:::: {#dfn-panel-for-dfn-coded-frame-processing .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Coded Frame Processing"}
[]{.caret}

::: {}
[Permalink](#dfn-coded-frame-processing){.self-link
aria-label="Permalink for definition: Coded Frame Processing. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
:::

**Referenced in:**

- [§ 2.
  Definitions](#ref-for-dfn-coded-frame-processing-1 "§ 2. Definitions")
- [§ 3.15.3
  Seeking](#ref-for-dfn-coded-frame-processing-2 "§ 3.15.3 Seeking")
- [§ 5.3 Track
  Buffers](#ref-for-dfn-coded-frame-processing-3 "§ 5.3 Track Buffers")
  [(2)](#ref-for-dfn-coded-frame-processing-4 "Reference 2")
  [(3)](#ref-for-dfn-coded-frame-processing-5 "Reference 3")
- [§ 5.5.1 Segment Parser
  Loop](#ref-for-dfn-coded-frame-processing-6 "§ 5.5.1 Segment Parser Loop")
  [(2)](#ref-for-dfn-coded-frame-processing-7 "Reference 2")
  [(3)](#ref-for-dfn-coded-frame-processing-8 "Reference 3")
  [(4)](#ref-for-dfn-coded-frame-processing-9 "Reference 4")
- [§ 5.5.2 Reset Parser
  State](#ref-for-dfn-coded-frame-processing-10 "§ 5.5.2 Reset Parser State")
- [§ 5.5.11 Audio Splice
  Frame](#ref-for-dfn-coded-frame-processing-11 "§ 5.5.11 Audio Splice Frame")
- [§ 5.5.13 Text Splice
  Frame](#ref-for-dfn-coded-frame-processing-12 "§ 5.5.13 Text Splice Frame")
- [§ 8.1
  Attributes](#ref-for-dfn-coded-frame-processing-13 "§ 8.1 Attributes")
::::

:::: {#dfn-panel-for-dfn-coded-frame-removal .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Coded Frame Removal"}
[]{.caret}

::: {}
[Permalink](#dfn-coded-frame-removal){.self-link
aria-label="Permalink for definition: Coded Frame Removal. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 3.15.6 Duration
  change](#ref-for-dfn-coded-frame-removal-1 "§ 3.15.6 Duration change")
- [§ 5.3 Track
  Buffers](#ref-for-dfn-coded-frame-removal-2 "§ 5.3 Track Buffers")
- [§ 5.5.6 Range
  Removal](#ref-for-dfn-coded-frame-removal-3 "§ 5.5.6 Range Removal")
- [§ 5.5.10 Coded Frame
  Eviction](#ref-for-dfn-coded-frame-removal-4 "§ 5.5.10 Coded Frame Eviction")
- [§ 8.1
  Attributes](#ref-for-dfn-coded-frame-removal-5 "§ 8.1 Attributes")
- [§ 9.3.2 Memory
  cleanup](#ref-for-dfn-coded-frame-removal-6 "§ 9.3.2 Memory cleanup")
  [(2)](#ref-for-dfn-coded-frame-removal-7 "Reference 2")
::::

:::: {#dfn-panel-for-dfn-coded-frame-eviction .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Coded Frame Eviction"}
[]{.caret}

::: {}
[Permalink](#dfn-coded-frame-eviction){.self-link
aria-label="Permalink for definition: Coded Frame Eviction. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.5.4 Prepare
  Append](#ref-for-dfn-coded-frame-eviction-1 "§ 5.5.4 Prepare Append")
- [§ 8.1
  Attributes](#ref-for-dfn-coded-frame-eviction-2 "§ 8.1 Attributes")
::::

:::: {#dfn-panel-for-dfn-audio-splice-frame .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Audio Splice Frame"}
[]{.caret}

::: {}
[Permalink](#dfn-audio-splice-frame){.self-link
aria-label="Permalink for definition: Audio Splice Frame. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.5.8 Coded Frame
  Processing](#ref-for-dfn-audio-splice-frame-1 "§ 5.5.8 Coded Frame Processing")
- [§ 5.5.12 Audio Splice
  Rendering](#ref-for-dfn-audio-splice-frame-2 "§ 5.5.12 Audio Splice Rendering")
::::

:::: {#dfn-panel-for-dfn-audio-splice-rendering .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Audio Splice Rendering"}
[]{.caret}

::: {}
[Permalink](#dfn-audio-splice-rendering){.self-link
aria-label="Permalink for definition: Audio Splice Rendering. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.5.11 Audio Splice
  Frame](#ref-for-dfn-audio-splice-rendering-1 "§ 5.5.11 Audio Splice Frame")
::::

:::: {#dfn-panel-for-dfn-text-splice-frame .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Text Splice Frame"}
[]{.caret}

::: {}
[Permalink](#dfn-text-splice-frame){.self-link
aria-label="Permalink for definition: Text Splice Frame. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 5.5.8 Coded Frame
  Processing](#ref-for-dfn-text-splice-frame-1 "§ 5.5.8 Coded Frame Processing")
::::

:::: {#dfn-panel-for-dom-sourcebufferlist .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: SourceBufferList"}
[]{.caret}

::: {}
[Permalink](#dom-sourcebufferlist){.self-link
aria-label="Permalink for definition: SourceBufferList. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-2108728413 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3. MediaSource
  interface](#ref-for-dom-sourcebufferlist-1 "§ 3. MediaSource interface")
  [(2)](#ref-for-dom-sourcebufferlist-2 "Reference 2")
- [§ 3.8 removeSourceBuffer()
  method](#ref-for-dom-sourcebufferlist-3 "§ 3.8 removeSourceBuffer() method")
  [(2)](#ref-for-dom-sourcebufferlist-4 "Reference 2")
- [§ 6. SourceBufferList
  interface](#ref-for-dom-sourcebufferlist-5 "§ 6. SourceBufferList interface")
  [(2)](#ref-for-dom-sourcebufferlist-6 "Reference 2")
::::

:::: {#dfn-panel-for-dom-sourcebufferlist-getter .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: getter"}
[]{.caret}

::: {}
[Permalink](#dom-sourcebufferlist-getter){.self-link
aria-label="Permalink for definition: getter. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
:::

**Referenced in:**

- Not referenced in this document.
::::

:::: {#dfn-panel-for-dom-sourcebufferlist-length .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: length"}
[]{.caret}

::: {}
[Permalink](#dom-sourcebufferlist-length){.self-link
aria-label="Permalink for definition: length. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-2108728413 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 6. SourceBufferList
  interface](#ref-for-dom-sourcebufferlist-length-1 "§ 6. SourceBufferList interface")
- [§ 6.2
  Methods](#ref-for-dom-sourcebufferlist-length-2 "§ 6.2 Methods")
::::

:::: {#dfn-panel-for-dom-sourcebufferlist-onaddsourcebuffer .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: onaddsourcebuffer"}
[]{.caret}

::: {}
[Permalink](#dom-sourcebufferlist-onaddsourcebuffer){.self-link
aria-label="Permalink for definition: onaddsourcebuffer. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-2108728413 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 6. SourceBufferList
  interface](#ref-for-dom-sourcebufferlist-onaddsourcebuffer-1 "§ 6. SourceBufferList interface")
::::

:::: {#dfn-panel-for-dom-sourcebufferlist-onremovesourcebuffer .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: onremovesourcebuffer"}
[]{.caret}

::: {}
[Permalink](#dom-sourcebufferlist-onremovesourcebuffer){.self-link
aria-label="Permalink for definition: onremovesourcebuffer. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-2108728413 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 6. SourceBufferList
  interface](#ref-for-dom-sourcebufferlist-onremovesourcebuffer-1 "§ 6. SourceBufferList interface")
::::

:::: {#dfn-panel-for-dfn-sourcebufferlist-getter .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: getter"}
[]{.caret}

::: {}
[Permalink](#dfn-sourcebufferlist-getter){.self-link
aria-label="Permalink for definition: getter. Activate to close this dialog."}
:::

**Referenced in:**

- Not referenced in this document.
::::

:::: {#dfn-panel-for-dfn-addsourcebuffer .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: addsourcebuffer"}
[]{.caret}

::: {}
[Permalink](#dfn-addsourcebuffer){.self-link
aria-label="Permalink for definition: addsourcebuffer. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 3.7 addSourceBuffer()
  method](#ref-for-dfn-addsourcebuffer-1 "§ 3.7 addSourceBuffer() method")
- [§ 3.15.5 Changes to selected/enabled track
  state](#ref-for-dfn-addsourcebuffer-2 "§ 3.15.5 Changes to selected/enabled track state")
  [(2)](#ref-for-dfn-addsourcebuffer-3 "Reference 2")
  [(3)](#ref-for-dfn-addsourcebuffer-4 "Reference 3")
- [§ 5.5.7 Initialization Segment
  Received](#ref-for-dfn-addsourcebuffer-5 "§ 5.5.7 Initialization Segment Received")
- [§ 6.1 Attributes](#ref-for-dfn-addsourcebuffer-6 "§ 6.1 Attributes")
::::

:::: {#dfn-panel-for-dfn-removesourcebuffer .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: removesourcebuffer"}
[]{.caret}

::: {}
[Permalink](#dfn-removesourcebuffer){.self-link
aria-label="Permalink for definition: removesourcebuffer. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 3.8 removeSourceBuffer()
  method](#ref-for-dfn-removesourcebuffer-1 "§ 3.8 removeSourceBuffer() method")
  [(2)](#ref-for-dfn-removesourcebuffer-2 "Reference 2")
- [§ 3.15.2 Detaching from a media
  element](#ref-for-dfn-removesourcebuffer-3 "§ 3.15.2 Detaching from a media element")
  [(2)](#ref-for-dfn-removesourcebuffer-4 "Reference 2")
- [§ 3.15.5 Changes to selected/enabled track
  state](#ref-for-dfn-removesourcebuffer-5 "§ 3.15.5 Changes to selected/enabled track state")
  [(2)](#ref-for-dfn-removesourcebuffer-6 "Reference 2")
  [(3)](#ref-for-dfn-removesourcebuffer-7 "Reference 3")
- [§ 6.1
  Attributes](#ref-for-dfn-removesourcebuffer-8 "§ 6.1 Attributes")
::::

:::: {#dfn-panel-for-dom-managedmediasource .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: ManagedMediaSource"}
[]{.caret}

::: {}
[Permalink](#dom-managedmediasource){.self-link
aria-label="Permalink for definition: ManagedMediaSource. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-1619111096 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ Status of This
  Document](#ref-for-dom-managedmediasource-1 "§ Status of This Document")
- [§ 3.7 addSourceBuffer()
  method](#ref-for-dom-managedmediasource-2 "§ 3.7 addSourceBuffer() method")
- [§ 3.15.2 Detaching from a media
  element](#ref-for-dom-managedmediasource-3 "§ 3.15.2 Detaching from a media element")
- [§ 7. ManagedMediaSource
  interface](#ref-for-dom-managedmediasource-4 "§ 7. ManagedMediaSource interface")
  [(2)](#ref-for-dom-managedmediasource-5 "Reference 2")
- [§ 7.2 Event
  Summary](#ref-for-dom-managedmediasource-6 "§ 7.2 Event Summary")
  [(2)](#ref-for-dom-managedmediasource-7 "Reference 2")
- [§ 7.3.1 ManagedSourceBuffer
  Monitoring](#ref-for-dom-managedmediasource-8 "§ 7.3.1 ManagedSourceBuffer Monitoring")
  [(2)](#ref-for-dom-managedmediasource-9 "Reference 2")
- [§ 9.3.2 Memory
  cleanup](#ref-for-dom-managedmediasource-10 "§ 9.3.2 Memory cleanup")
::::

:::: {#dfn-panel-for-dom-managedmediasource-constructor .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: constructor"}
[]{.caret}

::: {}
[Permalink](#dom-managedmediasource-constructor){.self-link
aria-label="Permalink for definition: constructor. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
:::

**Referenced in:**

- Not referenced in this document.
::::

:::: {#dfn-panel-for-dom-managedmediasource-onstartstreaming .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: onstartstreaming"}
[]{.caret}

::: {}
[Permalink](#dom-managedmediasource-onstartstreaming){.self-link
aria-label="Permalink for definition: onstartstreaming. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
:::

**Referenced in:**

- Not referenced in this document.
::::

:::: {#dfn-panel-for-dom-managedmediasource-onendstreaming .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: onendstreaming"}
[]{.caret}

::: {}
[Permalink](#dom-managedmediasource-onendstreaming){.self-link
aria-label="Permalink for definition: onendstreaming. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
:::

**Referenced in:**

- Not referenced in this document.
::::

:::: {#dfn-panel-for-dom-managedmediasource-streaming .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: streaming"}
[]{.caret}

::: {}
[Permalink](#dom-managedmediasource-streaming){.self-link
aria-label="Permalink for definition: streaming. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-1619111096 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3.15.2 Detaching from a media
  element](#ref-for-dom-managedmediasource-streaming-1 "§ 3.15.2 Detaching from a media element")
- [§ 7. ManagedMediaSource
  interface](#ref-for-dom-managedmediasource-streaming-2 "§ 7. ManagedMediaSource interface")
- [§ 7.2 Event
  Summary](#ref-for-dom-managedmediasource-streaming-3 "§ 7.2 Event Summary")
  [(2)](#ref-for-dom-managedmediasource-streaming-4 "Reference 2")
- [§ 7.3.1 ManagedSourceBuffer
  Monitoring](#ref-for-dom-managedmediasource-streaming-5 "§ 7.3.1 ManagedSourceBuffer Monitoring")
  [(2)](#ref-for-dom-managedmediasource-streaming-6 "Reference 2")
  [(3)](#ref-for-dom-managedmediasource-streaming-7 "Reference 3")
::::

:::: {#dfn-panel-for-dfn-startstreaming .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: startstreaming"}
[]{.caret}

::: {}
[Permalink](#dfn-startstreaming){.self-link
aria-label="Permalink for definition: startstreaming. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 7.3.1 ManagedSourceBuffer
  Monitoring](#ref-for-dfn-startstreaming-1 "§ 7.3.1 ManagedSourceBuffer Monitoring")
::::

:::: {#dfn-panel-for-dfn-endstreaming .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: endstreaming"}
[]{.caret}

::: {}
[Permalink](#dfn-endstreaming){.self-link
aria-label="Permalink for definition: endstreaming. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 7.3.1 ManagedSourceBuffer
  Monitoring](#ref-for-dfn-endstreaming-1 "§ 7.3.1 ManagedSourceBuffer Monitoring")
::::

:::: {#dfn-panel-for-dfn-enough-managed-data-to-ensure-uninterrupted-playback .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: enough managed data to ensure uninterrupted playback"}
[]{.caret}

::: {}
[Permalink](#dfn-enough-managed-data-to-ensure-uninterrupted-playback){.self-link
aria-label="Permalink for definition: enough managed data to ensure uninterrupted playback. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 7.3.1 ManagedSourceBuffer
  Monitoring](#ref-for-dfn-enough-managed-data-to-ensure-uninterrupted-playback-1 "§ 7.3.1 ManagedSourceBuffer Monitoring")
::::

:::: {#dfn-panel-for-dfn-able-to-retrieve-and-buffer-data-in-an-efficient-way .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: able to retrieve and buffer data in an efficient way"}
[]{.caret}

::: {}
[Permalink](#dfn-able-to-retrieve-and-buffer-data-in-an-efficient-way){.self-link
aria-label="Permalink for definition: able to retrieve and buffer data in an efficient way. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 7.3.1 ManagedSourceBuffer
  Monitoring](#ref-for-dfn-able-to-retrieve-and-buffer-data-in-an-efficient-way-1 "§ 7.3.1 ManagedSourceBuffer Monitoring")
::::

:::: {#dfn-panel-for-dfn-memory-cleanup .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Memory Cleanup"}
[]{.caret}

::: {}
[Permalink](#dfn-memory-cleanup){.self-link
aria-label="Permalink for definition: Memory Cleanup. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 7. ManagedMediaSource
  interface](#ref-for-dfn-memory-cleanup-1 "§ 7. ManagedMediaSource interface")
::::

:::: {#dfn-panel-for-dom-bufferedchangeevent .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: BufferedChangeEvent"}
[]{.caret}

::: {}
[Permalink](#dom-bufferedchangeevent){.self-link
aria-label="Permalink for definition: BufferedChangeEvent. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-2057880103 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ Status of This
  Document](#ref-for-dom-bufferedchangeevent-1 "§ Status of This Document")
- [§ 8. BufferedChangeEvent
  interface](#ref-for-dom-bufferedchangeevent-2 "§ 8. BufferedChangeEvent interface")
- [§ 9.2 Event
  Summary](#ref-for-dom-bufferedchangeevent-3 "§ 9.2 Event Summary")
- [§ 9.3.1 Buffered
  Change](#ref-for-dom-bufferedchangeevent-4 "§ 9.3.1 Buffered Change")
::::

:::: {#dfn-panel-for-dom-bufferedchangeevent-constructor .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: constructor"}
[]{.caret}

::: {}
[Permalink](#dom-bufferedchangeevent-constructor){.self-link
aria-label="Permalink for definition: constructor. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
:::

**Referenced in:**

- Not referenced in this document.
::::

:::: {#dfn-panel-for-dom-bufferedchangeeventinit .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: BufferedChangeEventInit"}
[]{.caret}

::: {}
[Permalink](#dom-bufferedchangeeventinit){.self-link
aria-label="Permalink for definition: BufferedChangeEventInit. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
:::

**Referenced in:**

- [§ 8. BufferedChangeEvent
  interface](#ref-for-dom-bufferedchangeeventinit-1 "§ 8. BufferedChangeEvent interface")
- [§ 9.3.1 Buffered
  Change](#ref-for-dom-bufferedchangeeventinit-2 "§ 9.3.1 Buffered Change")
::::

:::: {#dfn-panel-for-dom-bufferedchangeeventinit-addedranges .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: addedRanges"}
[]{.caret}

::: {}
[Permalink](#dom-bufferedchangeeventinit-addedranges){.self-link
aria-label="Permalink for definition: addedRanges. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
:::

**Referenced in:**

- [§ 9.3.1 Buffered
  Change](#ref-for-dom-bufferedchangeeventinit-addedranges-1 "§ 9.3.1 Buffered Change")
::::

:::: {#dfn-panel-for-dom-bufferedchangeeventinit-removedranges .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: removedRanges"}
[]{.caret}

::: {}
[Permalink](#dom-bufferedchangeeventinit-removedranges){.self-link
aria-label="Permalink for definition: removedRanges. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
:::

**Referenced in:**

- [§ 9.3.1 Buffered
  Change](#ref-for-dom-bufferedchangeeventinit-removedranges-1 "§ 9.3.1 Buffered Change")
::::

:::: {#dfn-panel-for-dom-bufferedchangeevent-addedranges .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: addedRanges"}
[]{.caret}

::: {}
[Permalink](#dom-bufferedchangeevent-addedranges){.self-link
aria-label="Permalink for definition: addedRanges. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-2057880103 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 8. BufferedChangeEvent
  interface](#ref-for-dom-bufferedchangeevent-addedranges-1 "§ 8. BufferedChangeEvent interface")
::::

:::: {#dfn-panel-for-dom-bufferedchangeevent-removedranges .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: removedRanges"}
[]{.caret}

::: {}
[Permalink](#dom-bufferedchangeevent-removedranges){.self-link
aria-label="Permalink for definition: removedRanges. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-2057880103 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 8. BufferedChangeEvent
  interface](#ref-for-dom-bufferedchangeevent-removedranges-1 "§ 8. BufferedChangeEvent interface")
::::

:::: {#dfn-panel-for-dom-managedsourcebuffer .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: ManagedSourceBuffer"}
[]{.caret}

::: {}
[Permalink](#dom-managedsourcebuffer){.self-link
aria-label="Permalink for definition: ManagedSourceBuffer. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-1682162223 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ Status of This
  Document](#ref-for-dom-managedsourcebuffer-1 "§ Status of This Document")
- [§ 3.7 addSourceBuffer()
  method](#ref-for-dom-managedsourcebuffer-2 "§ 3.7 addSourceBuffer() method")
- [§ 7. ManagedMediaSource
  interface](#ref-for-dom-managedsourcebuffer-3 "§ 7. ManagedMediaSource interface")
- [§ 9. ManagedSourceBuffer
  interface](#ref-for-dom-managedsourcebuffer-4 "§ 9. ManagedSourceBuffer interface")
- [§ 9.2 Event
  Summary](#ref-for-dom-managedsourcebuffer-5 "§ 9.2 Event Summary")
- [§ 9.3.1 Buffered
  Change](#ref-for-dom-managedsourcebuffer-6 "§ 9.3.1 Buffered Change")
::::

:::: {#dfn-panel-for-dom-managedsourcebuffer-onbufferedchange .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: onbufferedchange"}
[]{.caret}

::: {}
[Permalink](#dom-managedsourcebuffer-onbufferedchange){.self-link
aria-label="Permalink for definition: onbufferedchange. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-1682162223 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 9. ManagedSourceBuffer
  interface](#ref-for-dom-managedsourcebuffer-onbufferedchange-1 "§ 9. ManagedSourceBuffer interface")
::::

:::: {#dfn-panel-for-dfn-bufferedchange .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: bufferedchange"}
[]{.caret}

::: {}
[Permalink](#dfn-bufferedchange){.self-link
aria-label="Permalink for definition: bufferedchange. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 7. ManagedMediaSource
  interface](#ref-for-dfn-bufferedchange-1 "§ 7. ManagedMediaSource interface")
- [§ 9.1 Attributes](#ref-for-dfn-bufferedchange-2 "§ 9.1 Attributes")
- [§ 9.3.1 Buffered
  Change](#ref-for-dfn-bufferedchange-3 "§ 9.3.1 Buffered Change")
- [§ 9.3.2 Memory
  cleanup](#ref-for-dfn-bufferedchange-4 "§ 9.3.2 Memory cleanup")
::::

:::: {#dfn-panel-for-dfn-memory-cleanup-0 .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Memory cleanup"}
[]{.caret}

::: {}
[Permalink](#dfn-memory-cleanup-0){.self-link
aria-label="Permalink for definition: Memory cleanup. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 7.3.2 Memory
  Cleanup](#ref-for-dfn-memory-cleanup-0-1 "§ 7.3.2 Memory Cleanup")
- [§ 8.1 Attributes](#ref-for-dfn-memory-cleanup-0-2 "§ 8.1 Attributes")
- [§ 9.2 Event
  Summary](#ref-for-dfn-memory-cleanup-0-3 "§ 9.2 Event Summary")
- [§ 9.3.1 Buffered
  Change](#ref-for-dfn-memory-cleanup-0-4 "§ 9.3.1 Buffered Change")
::::

:::: {#dfn-panel-for-dom-audiotrack-sourcebuffer .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: sourceBuffer"}
[]{.caret}

::: {}
[Permalink](#dom-audiotrack-sourcebuffer){.self-link
aria-label="Permalink for definition: sourceBuffer. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-935490083 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3.8 removeSourceBuffer()
  method](#ref-for-dom-audiotrack-sourcebuffer-1 "§ 3.8 removeSourceBuffer() method")
- [§ 11. AudioTrack
  extensions](#ref-for-dom-audiotrack-sourcebuffer-2 "§ 11. AudioTrack extensions")
::::

:::: {#dfn-panel-for-dom-videotrack-sourcebuffer .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: sourceBuffer"}
[]{.caret}

::: {}
[Permalink](#dom-videotrack-sourcebuffer){.self-link
aria-label="Permalink for definition: sourceBuffer. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-251527976 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3.8 removeSourceBuffer()
  method](#ref-for-dom-videotrack-sourcebuffer-1 "§ 3.8 removeSourceBuffer() method")
- [§ 12. VideoTrack
  extensions](#ref-for-dom-videotrack-sourcebuffer-2 "§ 12. VideoTrack extensions")
::::

:::: {#dfn-panel-for-dom-texttrack-sourcebuffer .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: sourceBuffer"}
[]{.caret}

::: {}
[Permalink](#dom-texttrack-sourcebuffer){.self-link
aria-label="Permalink for definition: sourceBuffer. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
[IDL](#webidl-959897060 "Jump to IDL declaration"){.marker .idl-block}
:::

**Referenced in:**

- [§ 3.8 removeSourceBuffer()
  method](#ref-for-dom-texttrack-sourcebuffer-1 "§ 3.8 removeSourceBuffer() method")
- [§ 13. TextTrack
  extensions](#ref-for-dom-texttrack-sourcebuffer-2 "§ 13. TextTrack extensions")
::::

:::: {#dfn-panel-for-dfn-byte-stream-formats .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: Byte Stream Formats"}
[]{.caret}

::: {}
[Permalink](#dfn-byte-stream-formats){.self-link
aria-label="Permalink for definition: Byte Stream Formats. Activate to close this dialog."}
[exported]{.marker .dfn-exported
title="Definition can be referenced by other specifications"}
:::

**Referenced in:**

- Not referenced in this document.
::::

:::: {#dfn-panel-for-byte-stream-format-specs .dfn-panel hidden="" role="dialog" aria-modal="true" aria-label="Links in this document to definition: byte stream format specifications"}
[]{.caret}

::: {}
[Permalink](#byte-stream-format-specs){.self-link
aria-label="Permalink for definition: byte stream format specifications. Activate to close this dialog."}
:::

**Referenced in:**

- [§ 2.
  Definitions](#ref-for-byte-stream-format-specs-1 "§ 2. Definitions")
  [(2)](#ref-for-byte-stream-format-specs-2 "Reference 2")
  [(3)](#ref-for-byte-stream-format-specs-3 "Reference 3")
  [(4)](#ref-for-byte-stream-format-specs-4 "Reference 4")
- [§ 5.5.1 Segment Parser
  Loop](#ref-for-byte-stream-format-specs-5 "§ 5.5.1 Segment Parser Loop")
- [§ 5.5.8 Coded Frame
  Processing](#ref-for-byte-stream-format-specs-6 "§ 5.5.8 Coded Frame Processing")
- [§ 14. Byte Stream
  Formats](#ref-for-byte-stream-format-specs-7 "§ 14. Byte Stream Formats")
::::
