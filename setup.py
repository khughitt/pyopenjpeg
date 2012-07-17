"""
PyOpenJPEG: Python wrapper for OpenJPEG

PyOpenJPEG is a Python wrapper for the OpenJPEG JPEG 2000 library. So far
the wrapper only supports a very limited subset of the OpenJPEG functionality
with support for additional functionality planned for the future. 
"""
DOCLINES = __doc__.split("\n")

from distutils.core import setup
from distutils.extension import Extension
from Cython.Distutils import build_ext
import numpy

CLASSIFIERS = [
    'Development Status :: 3 - Alpha',
    'Intended Audience :: Science/Research',
    'Intended Audience :: Developers',
    'License :: OSI Approved :: BSD License',
    'Programming Language :: Python',
    'Programming Language :: Python :: 3',
    'Topic :: Multimedia :: Graphics',
    'Topic :: Software Development',
    'Topic :: Scientific/Engineering',
    'Operating System :: Microsoft :: Windows',
    'Operating System :: POSIX',
    'Operating System :: Unix',
    'Operating System :: MacOS'
]

setup(
    author="Keith Hughitt",
    author_email="keith.hughitt@nasa.gov",
    classifiers=CLASSIFIERS,
    cmdclass = {'build_ext': build_ext},
    description=DOCLINES[0],
    # https://bugs.archlinux.org/task/22326
    ext_modules = [Extension("openjpeg._openjpeg", 
                             ["openjpeg/src/_openjpeg.pyx"],
                             libraries=["openjpeg"],
                             include_dirs=[numpy.get_include()])],
    #install_requires=[],
    license="BSD",
    long_description="\n".join(DOCLINES[2:]),
    maintainer="keith.hughitt@nasa.gov",
    maintainer_email="keith.hughitt@nasa.gov",
    name="PyOpenJPEG",
    #packages=find_packages(),
    #package_data={'': ['*.pyx']},
    platforms=["Windows", "Linux", "Solaris", "Mac OS-X", "Unix"],
    provides=['openjpeg'],
    url="",
    #use_2to3=True,
    version="0.1"
)
