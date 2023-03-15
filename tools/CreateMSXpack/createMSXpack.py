import os
import hashlib
import xml.etree.ElementTree as ET
import base64


ROM_DIR = 'ROM'
XML_DIR = 'Computer'
BLOCK_TYPES = ["NONE", "RAM", "RAM MAPPER 1", "RAM MAPPER 2", "ROM", "FDC", "SLOT A", "SLOT B", "KBD LAYOUT", "ROM MIROR", "IO_MIRROR", "MIRROR"]
RAM_TYPES = ["RAM", "RAM MAPPER 1", "RAM MAPPER 2"]
MSX_TYPES = ["MSX1", "MSX2"]


def file_hash(filename):
    """Return the SHA1 hash of the file at `filename`."""
    with open(filename, 'rb') as f:
        return hashlib.sha1(f.read()).hexdigest()


def get_block_type_id(typ):
    """Return the tuple of (type, id) for the given block type."""
    id = 0
    if typ in RAM_TYPES:
        id = RAM_TYPES.index(typ)
        typ = 1
    else:
        typ = BLOCK_TYPES.index(typ) - 2
    return (typ, id)


def get_msx_type_id(typ):
    """Return the index of the given MSX type."""
    return MSX_TYPES.index(typ)


def create_block(msx_type, primary, secondary, block_id, typ, count, sha1, ref):
    """Create and return a bytearray representing a block."""
    (typ, id) = get_block_type_id(typ)
    ref = 0 if ref is None else int(ref)
    id = id if typ == 1 else ref
    count = 0 if count is None else int(count)

    head = bytearray()
    head.extend('MSX'.encode('ascii'))
    head.append(get_msx_type_id(msx_type))
    head.append(int(primary))
    head.append(int(secondary))
    head.append(int(block_id))
    head.append(typ)
    head.append(id)
    head.append(count)
    head.extend(bytearray(b'\x00\x00\x00\x00\x00\x00'))
    return head


# Traverse the ROM directory and save the hashes of the files in a dictionary
rom_hashes = {}
for dirpath, dirnames, filenames in os.walk(ROM_DIR):
    for filename in filenames:
        filepath = os.path.join(dirpath, filename)
        rom_hashes[file_hash(filepath)] = filepath


# Traverse the XML directory and create blocks for each XML file
for dirpath, dirnames, filenames in os.walk(XML_DIR):
    for filename in filenames:
        try:
            if filename.endswith('.xml'):
                heads = []
                filepath = os.path.join(dirpath, filename)
                filename_without_extension, extension = os.path.splitext(filename)
                dir_save = "MSX" + dirpath[len(XML_DIR):]
                output_filename = os.path.join(dir_save, filename_without_extension) + ".MSX"
                if not os.path.exists(dir_save):
                    os.makedirs(dir_save)

                tree = ET.parse(filepath)
                root = tree.getroot()

                msx_type_value = None
                msx_type = root.find('type')
                if msx_type is not None:
                    msx_type_value = msx_type.text

                outfile = open(output_filename, "wb")

                for primary in root.findall("./primary"):
                    primary_slot = primary.attrib["slot"]
                    for secondary in primary.findall("./secondary"):
                        secondary_slot = secondary.attrib["slot"]
                        for block in secondary.findall("./block"):
                            block_id = block.attrib["id"]
                            block_type = block.find('type').text if block.find('type') is not None else None
                            block_count = block.find('count').text if block.find('count') is not None else None
                            block_filename = block.find('filename').text if block.find('filename') is not None else None
                            block_SHA1 = block.find('SHA1').text if block.find('SHA1') is not None else None
                            block_ref = block.find('ref').text if block.find('ref') is not None else None
                            head = create_block(msx_type_value, primary_slot, secondary_slot, block_id, block_type, block_count, block_SHA1, block_ref ) 
                            if block_ref is None :
                                outfile.write(head)
                                if block_SHA1 is not None :
                                    if block_SHA1 in rom_hashes.keys() :
                                        infile = open(rom_hashes[block_SHA1], "rb")
                                        outfile.write(infile.read())
                                    else :
                                        outfile.close()
                                        os.remove(output_filename)
                                        raise Exception(f"Skip: {filename} Not found ROM {block_filename} SHA1:{block_SHA1}")
                            else :
                                heads.append(head)

                for head in heads :             
                    outfile.write(head)
                
                kbd_layout = root.find('kbd_layout')
                if kbd_layout is not None:
                    head = create_block(msx_type_value, 0, 0, 0, "KBD LAYOUT", 0, None, 0 ) 
                    outfile.write(head)
                    outfile.write(base64.b64decode(kbd_layout.text))
                
                outfile.close()
        except Exception as e:
            print(e)
