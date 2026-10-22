/* libjpeg-turbo integration, not a JPEG implementation. The suspension and
 * scanline design follows Blink's JPEGImageReader/OutputRows, independently
 * implemented here. No fabricated EOI or pixels after suspended input. */
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <setjmp.h>
#include <jpeglib.h>
#include <jerror.h>
#include "image_codecs.h"

struct crane_jpeg {
    struct jpeg_decompress_struct decoder;
    struct jpeg_error_mgr error;
    struct jpeg_source_mgr source;
    struct jpeg_progress_mgr progress;
    jmp_buf jump;
    int created, warning, failure;
    uint32_t rows;
    void *row;
};

static void fatal(j_common_ptr common) {
    struct crane_jpeg *self = common->client_data;
    self->failure = common->err->msg_code == JERR_OUT_OF_MEMORY ? CRANE_OOM : CRANE_CORRUPT;
    longjmp(self->jump, 1);
}
static void message(j_common_ptr common, int level) {
    if (level < 0) ((struct crane_jpeg *)common->client_data)->warning = 1;
}
static void quiet(j_common_ptr common) { (void)common; }
static void source_noop(j_decompress_ptr decoder) { (void)decoder; }
static boolean suspended(j_decompress_ptr decoder) { (void)decoder; return FALSE; }
static void skip(j_decompress_ptr decoder, long count) {
    if (count <= 0) return;
    size_t amount = (size_t)count;
    if (amount > decoder->src->bytes_in_buffer) amount = decoder->src->bytes_in_buffer;
    decoder->src->next_input_byte += amount;
    decoder->src->bytes_in_buffer -= amount;
}
static void progress(j_common_ptr common) {
    /* Blink also bounds progressive scan count; malformed inputs must not
     * turn a synchronous image decode into unbounded work. */
    if (((j_decompress_ptr)common)->input_scan_number >= 100) {
        common->err->msg_code = JERR_BAD_PROGRESSION;
        fatal(common);
    }
}

void crane_jpeg_close(struct crane_jpeg *self) {
    if (!self) return;
    if (self->created) jpeg_destroy_decompress(&self->decoder);
    free(self->row);
    free(self);
}

struct crane_jpeg *crane_jpeg_open(const unsigned char *data, size_t length,
                              uint32_t *width, uint32_t *height, int *result) {
    struct crane_jpeg *self = calloc(1, sizeof(*self));
    *result = CRANE_OOM;
    if (!self) return NULL;
    self->decoder.err = jpeg_std_error(&self->error);
    self->decoder.client_data = self;
    self->error.error_exit = fatal;
    self->error.emit_message = message;
    self->error.output_message = quiet;
    if (setjmp(self->jump)) {
        *result = self->failure;
        crane_jpeg_close(self);
        return NULL;
    }
    /* jpeg_destroy_decompress tolerates a partially created memory manager. */
    self->created = 1;
    jpeg_create_decompress(&self->decoder);
    self->source.init_source = source_noop;
    self->source.fill_input_buffer = suspended;
    self->source.skip_input_data = skip;
    self->source.resync_to_restart = jpeg_resync_to_restart;
    self->source.term_source = source_noop;
    self->source.next_input_byte = data;
    self->source.bytes_in_buffer = length;
    self->decoder.src = &self->source;
    self->progress.progress_monitor = progress;
    self->decoder.progress = &self->progress;
    /* CSS Images 3 2.1.2: layout metadata is read before the image data. */
    jpeg_save_markers(&self->decoder, JPEG_APP0 + 1, 0xffff);
    if (jpeg_read_header(&self->decoder, TRUE) != JPEG_HEADER_OK) {
        *result = CRANE_CORRUPT;
        crane_jpeg_close(self);
        return NULL;
    }
    *width = self->decoder.image_width;
    *height = self->decoder.image_height;
    *result = CRANE_COMPLETE;
    return self;
}

static unsigned char sample(struct crane_jpeg *self, size_t index) {
    int bits = self->decoder.data_precision;
    if (bits == 8) return ((unsigned char *)self->row)[index];
    if (bits < 8) return (unsigned char)((((unsigned char *)self->row)[index] * 255u + ((1u << bits) - 1u) / 2u) / ((1u << bits) - 1u));
    unsigned value = bits <= 12 ? (unsigned)((J12SAMPLE *)self->row)[index]
                               : (unsigned)((J16SAMPLE *)self->row)[index];
    return (unsigned char)((value * 255u + ((1u << bits) - 1u) / 2u) / ((1u << bits) - 1u));
}

static int output_rows(struct crane_jpeg *self, unsigned char *pixels) {
    struct jpeg_decompress_struct *d = &self->decoder;
    while (d->output_scanline < d->output_height) {
        uint32_t y = d->output_scanline;
        JDIMENSION count;
        if (d->data_precision <= 8) {
            JSAMPROW row = self->row;
            count = jpeg_read_scanlines(d, &row, 1);
        } else if (d->data_precision <= 12) {
            J12SAMPROW row = self->row;
            count = jpeg12_read_scanlines(d, &row, 1);
        } else {
            J16SAMPROW row = self->row;
            count = jpeg16_read_scanlines(d, &row, 1);
        }
        if (count != 1) return CRANE_TRUNCATED;
        unsigned char *dst = pixels + (size_t)y * d->output_width * 4;
        for (size_t x = 0; x < d->output_width; ++x) {
            size_t offset = x * d->output_components;
            if (d->out_color_space == JCS_CMYK) {
                unsigned k = sample(self, offset + 3);
                for (size_t channel = 0; channel < 3; ++channel) {
                    unsigned c = sample(self, offset + channel);
                    dst[x * 4 + channel] = (unsigned char)(d->saw_Adobe_marker ?
                        (c * k + 127) / 255 : ((255 - c) * (255 - k) + 127) / 255);
                }
            } else {
                for (size_t channel = 0; channel < 3; ++channel)
                    dst[x * 4 + channel] = sample(self, offset + channel);
            }
            dst[x * 4 + 3] = 255;
        }
        self->rows = y + 1;
    }
    return CRANE_COMPLETE;
}

int crane_jpeg_decode(struct crane_jpeg *self, unsigned char *pixels, int *empty) {
    struct jpeg_decompress_struct *d = &self->decoder;
    *empty = 1;
    if (setjmp(self->jump)) {
        *empty = self->rows == 0;
        return self->failure;
    }
    d->out_color_space = d->jpeg_color_space == JCS_CMYK || d->jpeg_color_space == JCS_YCCK ? JCS_CMYK : JCS_RGB;
    d->dct_method = JDCT_ISLOW;
    d->buffered_image = jpeg_has_multiple_scans(d);
    self->row = malloc((size_t)d->image_width * 4 * sizeof(J16SAMPLE));
    if (!self->row) return CRANE_OOM;
    if (!jpeg_start_decompress(d)) return CRANE_TRUNCATED;
    int result = CRANE_COMPLETE;
    if (d->buffered_image) {
        int status;
        int complete_scan = 0;
        do {
            status = jpeg_consume_input(d);
            if (status == JPEG_SCAN_COMPLETED || status == JPEG_REACHED_EOI)
                complete_scan = d->input_scan_number;
        } while (status != JPEG_SUSPENDED && status != JPEG_REACHED_EOI);
        if (!complete_scan) return CRANE_TRUNCATED;
        if (d->coef_bits) {
            for (int component = 0; component < d->num_components; ++component)
                if (d->coef_bits[component][0] < 0) return CRANE_TRUNCATED;
        } else if (!jpeg_input_complete(d)) return CRANE_TRUNCATED;
        if (!jpeg_start_output(d, complete_scan)) return CRANE_TRUNCATED;
        result = output_rows(self, pixels);
        if (!jpeg_finish_output(d) || status == JPEG_SUSPENDED) result = CRANE_TRUNCATED;
    } else {
        result = output_rows(self, pixels);
    }
    *empty = self->rows == 0;
    if (result == CRANE_COMPLETE && !jpeg_finish_decompress(d)) result = CRANE_TRUNCATED;
    return self->warning ? CRANE_CORRUPT : result;
}

static uint32_t tiff_uint(const unsigned char *p, unsigned size, int little) {
    uint32_t value = 0;
    for (unsigned i = 0; i < size; ++i)
        value = (value << 8) | p[little ? size - 1 - i : i];
    return value;
}

unsigned char crane_jpeg_orientation(struct crane_jpeg *self) {
    for (jpeg_saved_marker_ptr marker = self->decoder.marker_list; marker; marker = marker->next) {
        if (marker->marker != JPEG_APP0 + 1 || marker->data_length < 14 || memcmp(marker->data, "Exif\0\0", 6)) continue;
        const unsigned char *tiff = marker->data + 6;
        size_t length = marker->data_length - 6;
        int little = tiff[0] == 'I' && tiff[1] == 'I';
        if (!little && !(tiff[0] == 'M' && tiff[1] == 'M')) continue;
        if (tiff_uint(tiff + 2, 2, little) != 42) continue;
        size_t offset = tiff_uint(tiff + 4, 4, little);
        if (offset > length - 2) continue;
        unsigned count = tiff_uint(tiff + offset, 2, little);
        offset += 2;
        if (count > (length - offset) / 12) continue;
        for (unsigned i = 0; i < count; ++i, offset += 12) {
            const unsigned char *entry = tiff + offset;
            if (tiff_uint(entry, 2, little) != 0x112 || tiff_uint(entry + 2, 2, little) != 3 || tiff_uint(entry + 4, 4, little) != 1) continue;
            unsigned value = tiff_uint(entry + 8, 2, little);
            if (value >= 1 && value <= 8) return (unsigned char)value;
        }
    }
    return 1;
}
