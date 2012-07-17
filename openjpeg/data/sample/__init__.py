"""OpenJPEG sample data files"""
from __future__ import absolute_import
import openjpeg
import os

__author__ = "Keith Hughitt"
__email__ = "keith.hughitt@nasa.gov"

rootdir = os.path.join(os.path.dirname(openjpeg.__file__), "data/sample") 

#
# 2012_05_02__13_13_49_147__SOHO_EIT_EIT_195.jp2
#
EIT_IMAGE = os.path.join(rootdir, "2012_05_02__13_13_49_147__SOHO_EIT_EIT_195.jp2")