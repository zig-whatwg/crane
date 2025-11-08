## Introduction

*This section is non-normative.*

The APIs specified in this specification are used to compress and decompress streams of data. They support "deflate", "deflate-raw" and "gzip" as compression algorithms. They are widely used by web developers.


## Infrastructure

This specification depends on Infra. [INFRA]

A chunk is a piece of data. In the case of CompressionStream and DecompressionStream, the output chunk type is Uint8Array. They accept any `BufferSource` type as input.

A stream represents an ordered sequence of chunks. The terms `ReadableStream` and `WritableStream` are defined in Streams. [STREAMS]

A compression context is the internal state maintained by a compression or decompression algorithm. The contents of a compression context depend on the format, algorithm and implementation in use. From the point of view of this specification, it is an opaque object. A compression context is initially in a start state such that it anticipates the first byte of input.


## Supported formats

[`deflate`](#dom-compressionformat-deflate)

:   "ZLIB Compressed Data Format" [RFC1950]

    Note: This format is referred to as "deflate" for consistency with HTTP Content-Encodings. See [RFC7230] section 4.2.2.

    - Implementations must be "compliant" as described in [RFC1950] section 2.3.

    - Field values described as invalid in [RFC1950] must not be created by CompressionStream, and are errors for DecompressionStream.

    - The only valid value of the `CM` (Compression method) part of the `CMF` field is 8.

    - The `FDICT` flag is not supported by these APIs, and will error the stream if set.

    - The `FLEVEL` flag is ignored by DecompressionStream.

    - It is an error for DecompressionStream if the `ADLER32` checksum is not correct.

    - It is an error if there is additional input data after the `ADLER32` checksum.

[`deflate-raw`](#dom-compressionformat-deflate-raw)

:   "The DEFLATE algorithm" [RFC1951]

    - Implementations must be "compliant" as described in [RFC1951] section 1.4.

    - Non-[RFC1951]-conforming blocks must not be created by CompressionStream, and are errors for DecompressionStream.

    - It is an error if there is additional input data after the final block indicated by the `BFINAL` flag.

[`gzip`](#dom-compressionformat-gzip)

:   "GZIP file format" [RFC1952]

    - Implementations must be "compliant" as described in [RFC1952] section 2.3.1.2.

    - Field values described as invalid in [RFC1952] must not be created by CompressionStream, and are errors for DecompressionStream.

    - The only valid value of the `CM` (Compression Method) field is 8.

    - The `FTEXT` flag must be ignored by DecompressionStream.

    - If the `FHCRC` field is present, it is an error for it to be incorrect.

    - The contents of any `FEXTRA`, `FNAME` and `FCOMMENT` fields must be ignored by DecompressionStream, except to verify that they are terminated correctly.

    - The contents of the `MTIME`, `XFL` and `OS` fields must be ignored by DecompressionStream.

    - It is an error if `CRC32` or `ISIZE` do not match the decompressed data.

    - A `gzip` stream may only contain one "member".

    - It is an error if there is additional input data after the end of the "member".


## Interface `CompressionStream`

```idl
enum CompressionFormat {
  "deflate",
  "deflate-raw",
  "gzip",
};

[Exposed=*]
interface CompressionStream {
  constructor(CompressionFormat format);
};
CompressionStream includes GenericTransformStream;
```

A `CompressionStream` has an associated format and [compression context](#compression-context) context.

The `new CompressionStream(format)` steps are:

1.  If `format` is unsupported in `CompressionStream`, then throw a `TypeError`.

2.  Set this's format to `format`.

3.  Let `transformAlgorithm` be an algorithm which takes a `chunk` argument and runs the [compress and enqueue a chunk](#compress-and-enqueue-a-chunk) algorithm with this and `chunk`.

4.  Let `flushAlgorithm` be an algorithm which takes no argument and runs the [compress flush and enqueue](#compress-flush-and-enqueue) algorithm with this.

5.  Set this's transform to a new `TransformStream`.

6.  Set up this's transform with *transformAlgorithm* set to `transformAlgorithm` and *flushAlgorithm* set to `flushAlgorithm`.

The compress and enqueue a chunk algorithm, given a `CompressionStream` object `cs` and a `chunk`, runs these steps:

1.  If `chunk` is not a `BufferSource` type, then throw a `TypeError`.

2.  Let `buffer` be the result of compressing `chunk` with `cs`'s format and context.

3.  If `buffer` is empty, return.

4.  Let `arrays` be the result of splitting `buffer` into one or more non-empty pieces and converting them into `Uint8Array`s.

5.  For each `Uint8Array` `array` of `arrays`, enqueue `array` in `cs`'s transform.

The compress flush and enqueue algorithm, which handles the end of data from the input `ReadableStream` object, given a `CompressionStream` object `cs`, runs these steps:

1.  Let `buffer` be the result of compressing an empty input with `cs`'s format and context, with the finish flag.

2.  If `buffer` is empty, return.

3.  Let `arrays` be the result of splitting `buffer` into one or more non-empty pieces and converting them into `Uint8Array`s.

4.  For each `Uint8Array` `array` of `arrays`, enqueue `array` in `cs`'s transform.


## Interface `DecompressionStream`

```idl
[Exposed=*]
interface DecompressionStream {
  constructor(CompressionFormat format);
};
DecompressionStream includes GenericTransformStream;
```

A `DecompressionStream` has an associated format and compression context context.

The `new DecompressionStream(format)` steps are:

1. If `format` is unsupported in `DecompressionStream`, then throw a `TypeError`.

2. Set this's format to `format`.

3. Let `transformAlgorithm` be an algorithm which takes a `chunk` argument and runs the decompress and enqueue a chunk algorithm with this and `chunk`.

4. Let `flushAlgorithm` be an algorithm which takes no argument and runs the decompress flush and enqueue algorithm with this.

5. Set this's transform to a new `TransformStream`.

6. Set up this's transform with *transformAlgorithm* set to `transformAlgorithm` and *flushAlgorithm* set to `flushAlgorithm`.

The decompress and enqueue a chunk algorithm, given a `DecompressionStream` object `ds` and a `chunk`, runs these steps:

1. If `chunk` is not a `BufferSource` type, then throw a `TypeError`.

2. Let `buffer` be the result of decompressing `chunk` with `ds`'s format and context. If this results in an error, then throw a `TypeError`.

3. If `buffer` is empty, return.

4. Let `arrays` be the result of splitting `buffer` into one or more non-empty pieces and converting them into `Uint8Array`s.

5. For each `Uint8Array` `array` of `arrays`, enqueue `array` in `ds`'s transform.

6. If the end of the compressed input has been reached, and `ds`'s context has not fully consumed `chunk`, then throw a `TypeError`.

The decompress flush and enqueue algorithm, which handles the end of data from the input `ReadableStream` object, given a `DecompressionStream` object `ds`, runs these steps:

1. Let `buffer` be the result of decompressing an empty input with `ds`'s format and context, with the finish flag.

2. If `buffer` is not empty:

    1. Let `arrays` be the result of splitting `buffer` into one or more non-empty pieces and converting them into `Uint8Array`s.

    2. For each `Uint8Array` `array` of `arrays`, enqueue `array` in `ds`'s transform.

3. If the end of the compressed input has not been reached, then throw a `TypeError`.


## Privacy and security considerations

The API doesn't add any new privileges to the web platform.

However, web developers have to pay attention to the situation when attackers can get the length of the data. If so, they may be able to guess the contents of the data.


## Examples


### Gzip-compress a stream

```
const compressedReadableStream
    = inputReadableStream.pipeThrough(new CompressionStream('gzip'));
```


### Deflate-compress an ArrayBuffer to a Uint8Array

```
async function compressArrayBuffer(input) {
  const cs = new CompressionStream('deflate');

  const writer = cs.writable.getWriter();
  writer.write(input);
  writer.close();

  const output = [];
  let totalSize = 0;
  for (const chunk of cs.readable) {
    output.push(value);
    totalSize += value.byteLength;
  }

  const concatenated = new Uint8Array(totalSize);
  let offset = 0;
  for (const array of output) {
    concatenated.set(array, offset);
    offset += array.byteLength;
  }

  return concatenated;
}
```


### Gzip-decompress a Blob to Blob

```
function decompressBlob(blob) {
  const ds = new DecompressionStream('gzip');
  const decompressionStream = blob.stream().pipeThrough(ds);
  return new Response(decompressionStream).blob();
}
```