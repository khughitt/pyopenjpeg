"""PyOpenJPEG

Python wrapper to the OpenJPEG library (v1.5).

keith.hughitt@gmail.com
"""
cimport copenjpeg as opj
from libc.stdio cimport fopen, fclose, printf, fprintf, FILE
from libc.stdlib cimport calloc, malloc, free
from libc.stdint cimport int8_t, uint8_t, int16_t, uint16_t, int32_t, uint32_t, int64_t, uint64_t
import numpy as np
cimport numpy as np

cdef class Decoder:
    """JPEG 2000 image decoder"""
    cdef opj.opj_image_t *_image
    
    def __cinit__(self):
        """Creates a new OpenJPEG Decoder"""
        pass

    def decode(self, filename, layer=0, reduce=0, x0=None, x1=None, y0=None,
               y1=None):
        """Decodes a single JPEG 2000 image.
        
        Parameters
        ----------
        filename : str
            Name of the file to decode
        layer : int
            Layer to be decoded
        reduce : int
            Number of highest resolution levels to be discarded. The image 
            resolution is effectively divided by 2 to the power of the number 
            of discarded levels. The reduce factor is limited by the smallest 
            total number of decomposition levels among tiles.
        x0 : int
            Region of interest left pixel number
        x1 : int
            Region of interest right pixel number
        y0 : int
            Region of interest top pixel number
        y1 : int
            Region of interest bottom pixel number
            
        Returns
        -------
        out : numpy.ndarray
            An ndarray representing the decoded image data
            
        Examples
        --------
        >>> import openjpeg
        >>> decoder = openjpeg.Decoder()
        >>> img = decoder.decode('file.jp2', reduce=1)
            
        """
        cdef:
            FILE *fsrc = NULL
            int width, height
            unsigned char *data = NULL
            opj.opj_dparameters_t parameters
            
        # Default decoding parameters
        opj.opj_set_default_decoder_parameters(&parameters)
        
        parameters.cp_layer = layer
        parameters.cp_reduce = reduce
        
        if x0 is not None:
            parameters.DA_x0 = x0
        if x1 is not None:
            parameters.DA_x1 = x1
        if y0 is not None:
            parameters.DA_y0 = y0
        if y1 is not None:
            parameters.DA_y1 = y1
        
#        params = {
#            "cp_layer": layer,
#            "cp_reduce": reduce
#        }        
#        parameters.update(params)
#        
#        for k,v in default_params.items():
#            setattr(parameters, k, v)

        # Decode image
        self._image = self._decode(filename, &parameters)
        
        # Get image dimensions
        w = self._image.comps[0].w        
        h = self._image.comps[0].h
        num_pixels = w * h
        
        # Convert to an ndarray
        cdef np.ndarray[np.uint8_t, ndim=1] im = np.empty(num_pixels, np.uint8)        
        
        for i in range(num_pixels):
            im[i] = self._image.comps[0].data[i]

        # free image data structure
        opj.opj_image_destroy(self._image);
        
        return im.reshape((w, h))
    
    cdef opj.opj_image_t* _decode(self, filename, opj.opj_dparameters_t* parameters) except *:
        """Converts raw data into an OpenJPEG image structure"""
        cdef opj.opj_stream_t *l_stream = NULL  # Stream
        cdef opj.opj_codec_t* l_codec = NULL    # Handle to a decompressor
        cdef opj.opj_codestream_info_t cstr_info  # codestream information structure
        cdef opj.opj_image_t *image = NULL

        # Open the image
        fsrc = fopen(<char *>filename, "rb")
        
        if not fsrc:
            raise("Failed to open %s for reading" % filename);
        
        # Create file stream
        l_stream = opj.opj_stream_create_default_file_stream(fsrc, 1)
        if not l_stream:
            fclose(fsrc)
            raise("Failed to open %s for reading" % filename);
        
        # decode the JPEG 2000 codestream
        l_codec = opj.opj_create_decompress_v2(opj.CODEC_JP2)
        
        # Setup event handlers
        opj.opj_set_info_handler(l_codec, info_callback, <void*>0)
        opj.opj_set_warning_handler(l_codec, warning_callback, <void*>0)
        opj.opj_set_error_handler(l_codec, error_callback, <void*>0)
        
        # setup the decoder using specified parameters
        if not opj.opj_setup_decoder_v2(l_codec, parameters):
            opj.opj_stream_destroy(l_stream)
            fclose(fsrc)
            opj.opj_destroy_codec(l_codec)
            raise Exception("Failed to setup the decoder")
                
        # read codestream header
        if not opj.opj_read_header(l_stream, l_codec, &image):
            opj.opj_stream_destroy(l_stream)
            fclose(fsrc)
            opj.opj_destroy_codec(l_codec)
            opj.opj_image_destroy(image)
            raise Exception("Failed to read the header")

        # decode tile
        # EXCEPTIONS ENCOUNTERED HERE!!!
        if not opj.opj_get_decoded_tile(l_codec, l_stream, image, parameters.tile_index):
            opj.opj_destroy_codec(l_codec)
            opj.opj_stream_destroy(l_stream)
            opj.opj_image_destroy(image)
            fclose(fsrc)
            raise Exception("Failed to decode tile")
        
        # close the byte stream
        opj.opj_stream_destroy(l_stream)
        fclose(fsrc)
        
        return image
        
#    cdef unsigned char* _get_data(self, opj.opj_image_t *image):
#        """Retrieves raw image data from the JP2"""
#        cdef int w, h
#        cdef int i, r
#        cdef unsigned char *data = NULL
#        
#        w = image.comps[0].w        
#        h = image.comps[0].h
#        
#        # read image data
#        data = <unsigned char*> calloc (w * h, sizeof(unsigned char))
#    
#        for i in range(w * h):
#            r = image.comps[0].data[w * h - ((i) / (w) + 1) * w + (i) % (w)]
#            r += (1 << (image.comps[0].prec - 1) if image.comps[0].sgnd else 0)
#
#            r = max(0, min(255, r))
#
#            data[i] = r
#            
#        return data
    
#
# Internal event handlers
#
cdef void error_callback(char *msg, void *client_data):
    raise Exception("[ERROR] %s" % msg)

cdef void warning_callback(char *msg, void *client_data):
    raise Exception("[WARNING] %s" % msg)

cdef void info_callback(char *msg, void *client_data):
    <void>client_data
    print("[INFO] %s" % msg)

#
# JPEG 2000 file signatures
#
DEF JP2_RFC3745_MAGIC = "\x00\x00\x00\x0c\x6a\x50\x20\x20\x0d\x0a\x87\x0a"
DEF JP2_MAGIC = "\x0d\x0a\x87\x0a"
DEF J2K_CODESTREAM_MAGIC = "\xff\x4f\xff\x51"
