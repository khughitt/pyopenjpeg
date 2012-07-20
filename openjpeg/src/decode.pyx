"""PyOpenJPEG

Python wrapper to the OpenJPEG library (2.0).

keith.hughitt@gmail.com
"""
cimport copenjpeg as opj
from libc.stdio cimport fopen, fclose, printf, fprintf, FILE
from libc.stdlib cimport calloc, malloc, free
from libc.stdint cimport int8_t, uint8_t, int16_t, uint16_t, int32_t, uint32_t, int64_t, uint64_t
import numpy as np
cimport numpy as np
import xmlbox

#
# JPEG 2000 file signatures
#
JP2_RFC3745_MAGIC = "\x00\x00\x00\x0c\x6a\x50\x20\x20\x0d\x0a\x87\x0a"
JP2_MAGIC = "\x0d\x0a\x87\x0a"
J2K_CODESTREAM_MAGIC = "\xff\x4f\xff\x51"

#
# Format definitions
#
DEF J2K_CFMT = 0
DEF JP2_CFMT = 1
DEF JPT_CFMT = 2

cdef class Decoder:
    """JPEG 2000 image decoder"""
    cdef opj.opj_image_t *_image
    
    def __cinit__(self):
        """Creates a new OpenJPEG Decoder"""
        pass
    
    def decode(self, filename, layer=0, reduce=0, max_quality_layers=None, 
               x0=None, x1=None, y0=None, y1=None, tile_num=None):
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
        max_quality_layers : int
            Maximum number of quality layer to decode.
        x0 : int
            Region of interest left pixel number
        x1 : int
            Region of interest right pixel number
        y0 : int
            Region of interest top pixel number
        y1 : int
            Region of interest bottom pixel number
        tile_num : int
            Tile number of decode. Tiles are counted from left-up to bottom-up.
            
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
        
#        params = {
#            "cp_layer": layer,
#            "cp_reduce": reduce
#        }        
#        parameters.update(params)
#        
#        for k,v in default_params.items():
#            setattr(parameters, k, v)
        
        parameters.cp_layer = layer
        parameters.cp_reduce = reduce
        
        # Check for optional parameters that have been set
        if max_quality_layers is not None:
            parameters.cp_layer = max_quality_layers
        if x0 is not None:
            parameters.DA_x0 = x0
        if x1 is not None:
            parameters.DA_x1 = x1
        if y0 is not None:
            parameters.DA_y0 = y0
        if y1 is not None:
            parameters.DA_y1 = y1
        if tile_num is not None:
            parameters.nb_tile_to_decode = 1
            parameters.tile_index = tile_num
            
        # Determine input file format
        parameters.decod_format = self._detect_format(filename)
        
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
    
    def get_xmlbox(self, filepath, as_string=False):
        """Reads in an XML Box and returns it as a Python dictionary.
        
        Parameters
        ----------
        as_string : bool
            (Optional) If set to True, the orignal XML string will be returned,
            otherwise a Python dictionary representation of the XML box is
            returned. Default = False.
            
        Return
        ------
        out : dict, string
            Returns a dictionary or string representation of the XML box
            
        Examples
        --------
        >>> import openjpeg
        >>> decoder = openjpeg.Decoder()
        >>> xmlbox = decoder.get_xmlbox(openjpeg.EIT_IMAGE)
        >>> xmlbox['meta']['fits']['DATE_OBS']
        u'2012-05-02T13:13:49.147Z'
        """
        return xmlbox.get_xmlbox(filepath, as_string)
    
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
        
        # Decode the JPEG 2000 codestream
        codecs = {
            JP2_CFMT: opj.CODEC_JP2,    # JPEG 2000 compressed image data
            J2K_CFMT: opj.CODEC_J2K     # JPEG-2000 codestream
        }
        l_codec = opj.opj_create_decompress_v2(codecs[parameters.decod_format])
        
        # Setup event handlers
        opj.opj_set_info_handler(l_codec, info_callback, <void*>0)
        opj.opj_set_warning_handler(l_codec, warning_callback, <void*>0)
        opj.opj_set_error_handler(l_codec, error_callback, <void*>0)
        
        # Setup the decoder using specified parameters
        if not opj.opj_setup_decoder_v2(l_codec, parameters):
            opj.opj_stream_destroy(l_stream)
            fclose(fsrc)
            opj.opj_destroy_codec(l_codec)
            raise Exception("Failed to setup the decoder")
                
        # Read codestream header
        if not opj.opj_read_header(l_stream, l_codec, &image):
            opj.opj_stream_destroy(l_stream)
            fclose(fsrc)
            opj.opj_destroy_codec(l_codec)
            opj.opj_image_destroy(image)
            raise Exception("Failed to read the header")
        
        # Decode image
        if not parameters.nb_tile_to_decode:
            # check to see if a sub-region was specified
            if not opj.opj_set_decode_area(l_codec, image, 
                                           parameters.DA_x0, parameters.DA_y0,
                                           parameters.DA_x1, parameters.DA_y1):
                opj.opj_stream_destroy(l_stream)
                opj.opj_destroy_codec(l_codec)
                opj.opj_image_destroy(image)
                fclose(fsrc)
                raise Exception("Failed to set the decoded area")

            # Otherwise grab the whole thing
            if not (opj.opj_decode_v2(l_codec, l_stream, image) and 
                    opj.opj_end_decompress(l_codec, l_stream)):
                opj.opj_destroy_codec(l_codec)
                opj.opj_stream_destroy(l_stream)
                opj.opj_image_destroy(image)
                fclose(fsrc)
                raise Exception("Failed to decode image")
        else:
            # Decode tile
            if not opj.opj_get_decoded_tile(l_codec, l_stream, image, parameters.tile_index):
                opj.opj_destroy_codec(l_codec)
                opj.opj_stream_destroy(l_stream)
                opj.opj_image_destroy(image)
                fclose(fsrc)
                raise Exception("Failed to decode tile")
        
        # Close the byte stream
        opj.opj_stream_destroy(l_stream)
        fclose(fsrc)
        
        return image
    
    def _detect_format(self, filepath):
        """Uses the first twelve bytes at the beginning of the file to attempt
        to determine what type of JPEG 2000 data is being loaded."""
        
        # Get signature
        fp = open(filepath)
        signature = fp.read(12)
        fp.close()
        
        # Compare with known types
        if signature == JP2_RFC3745_MAGIC or signature[:4] == JP2_MAGIC:
            return JP2_CFMT
        elif signature[:4] == J2K_CODESTREAM_MAGIC: 
            return J2K_CFMT

        # Raise an error if format is not recognized
        raise TypeError("Unsupported input format")

#
# Internal event handlers
#
cdef void error_callback(char *msg, void *client_data):
    raise Exception("[ERROR] %s" % msg.strip())

cdef void warning_callback(char *msg, void *client_data):
    raise Exception("[WARNING] %s" % msg.strip())

cdef void info_callback(char *msg, void *client_data):
    <void>client_data
    print("[INFO] %s" % msg.strip())
