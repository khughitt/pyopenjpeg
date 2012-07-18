PyOpenJPEG
==========

PyOpenJPEG is a Python wrapper around the [OpenJPEG ](www.openjpeg.org) 
[JPEG 2000](http://www.jpeg.org/jpeg2000/) image library written using 
[Cython](http://www.cython.org/).

Installation
------------

**NOTE:** This library is currently in the early stages of development and is
not yet ready for use. 

First, install [OpenJPEG 2.0](http://www.openjpeg.org/index.php?menu=download)
using either the provided binaries, or by compiling from source. 

To install PyOpenJPEG, run:

    python setup.py build_ext -i
    python setup.py install

Usage
-----

Here is a quick example of decoding an image:

```python
>>> import openjpeg
>>> decoder = openjpeg.Decoder()
>>> img = decoder.decode(openjpeg.EIT_IMAGE)
```

Development
-----------
When contributing to PyOpenJPEG, it is recommended that you install the [latest
version of OpenJPEG from SVN](http://code.google.com/p/openjpeg/source/checkout).

Below are instructions for downloading and building the latest branch on Linux:

    svn checkout http://openjpeg.googlecode.com/svn/trunk/ openjpeg
    cd openjpeg
    cmake build
    make
    sudo make install
 
There is currently [an issue with OpenJPEG install](https://groups.google.com/forum/?fromgroups#!topic/openjpeg/YllZliu6Vo4)
which prevents some necessary includes being placed in the proper location. 
On Linux, you can you fix this by doing: ::

    sudo su -
    for file in /usr/local/include/openjpeg-1.99/*.h; do ln -s ${file} /usr/local/include/; done

The above command will create symbolic links in /usr/local/include to several 
needed header files.

To compile the PyOpenJPEG Cython code, run:

    python setup.py build_ext -i

TODO
----
1. Add support for saving to some common formats (BMP, PNG, etc)
2. Add encoding support
