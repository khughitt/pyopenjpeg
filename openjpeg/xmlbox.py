"""JPEG 2000 XML box read and write functionality.

This module provides support for reading in a JPEG 2000 XML Box and returning
it as either a string, or a Python dictionary.

References
----------
| http://www.digitalpreservation.gov/formats/fdd/fdd000143.shtml

"""
from __future__ import absolute_import
from xml.dom.minidom import parseString
import re

def get_xmlbox(filepath, as_string=False):
    """Reads in an XML Box and returns it as a Python dictionary.
    
    Parameters
    ----------
    as_string : bool
        (Optional) If set to True, the orignal XML string will be returned,
        otherwise a Python dictionary representation of the XML box is
        returned. Default = False. 
    """    
    # Parse XML box
    xmlstring = _read_xmlbox(filepath)
    
    # Return a string if requested
    if as_string:
        return xmlstring

    # Otherwise convert to a Python dictionary
    pydict = xml_to_dict(xmlstring)
    
    #Fix numeric types
    def fix_types(node):
        for k, v in node.items():
            if isinstance(v, dict):
                fix_types(v)
            elif isinstance(v, basestring):
                if v.isdigit():
                    node[k] = int(v)
                elif is_float(v):
                    node[k] = float(v)
        
    fix_types(pydict)
            
    return pydict

def _read_xmlbox(filepath):
    """
    Extracts the XML box from a JPEG 2000 image.
    """
    fp = open(filepath, 'rb')
    
    # Find root node
    root_node = None
    
    for line in fp:
        match = re.match("<(\w+)>", line)

        if match is not None:
            root_node = match.group(1)
            xmlstr = line.strip()
            break
            
    if root_node is None:
        raise UnableToParseXMLBox
            
    # Continue parsing until end of XML box
    for line in fp:
        xmlstr += line.strip()
        if line.find("</%s>" % root_node) != -1:
            break

#    start = xmlstr.find("<%s>" % root)
#    end = xmlstr.find("</%s>" % root) + len("</%s>" % root)
#    
#    xmlstr = xmlstr[start : end]
    
    fp.close()

    return xmlstr

def is_float(s):
    """Check to see if a string value is a valid float"""
    try:
        float(s)
        return True
    except ValueError:
        return False
    
class UnableToParseXMLBox(IOError):
    """Unable to find or parse an image XML box"""
    pass

#
# Converting XML to a Dictionary
# Author: Christoph Dietze
# URL   : http://code.activestate.com/recipes/116539/
#
class NotTextNodeError(Exception):
    pass

def xml_to_dict(xmlstring):
    """Converts an XML string to a Python dictionary"""
    return node_to_dict(parseString(xmlstring))

def node_to_dict(node):
    """
    node_to_dict() scans through the children of node and makes a dictionary 
    from the content.
    
    Three cases are differentiated:
    1. If the node contains no other nodes, it is a text-node and 
       {nodeName: text} is merged into the dictionary.
    2. If the node has the attribute "method" set to "true", then it's children 
       will be appended to a list and this list is merged to the dictionary in 
       the form: {nodeName:list}.
    3. Else, node_to_dict() will call itself recursively on the nodes children 
       (merging {nodeName: node_to_dict()} to the dictionary).
    """
    dic = {} 
    for n in node.childNodes:
        if n.nodeType != n.ELEMENT_NODE:
            continue
        if n.getAttribute("multiple") == "true":
            # node with multiple children: put them in a list
            l = []
            for c in n.childNodes:
                if c.nodeType != n.ELEMENT_NODE:
                    continue
                l.append(node_to_dict(c))
                dic.update({n.nodeName: l})
            continue
            
        try:
            text = get_node_text(n)
        except NotTextNodeError:
            # 'normal' node
            dic.update({n.nodeName: node_to_dict(n)})
            continue
    
        # text node
        dic.update({n.nodeName: text})
        continue
    return dic

def get_node_text(node):
    """
    scans through all children of node and gathers the text. if node has 
    non-text child-nodes, then NotTextNodeError is raised.
    """
    t = ""
    for n in node.childNodes:
        if n.nodeType == n.TEXT_NODE:
            t += n.nodeValue
        else:
            raise NotTextNodeError
    return t
