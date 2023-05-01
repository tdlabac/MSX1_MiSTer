import os
import hashlib
import xml.etree.ElementTree as ET
import base64


ROM_DIR = 'ROM'
XML_DIR_COMP = 'Computer'
XML_DIR_FW = 'Extension'
BLOCK_TYPES = ["NONE", "RAM", "RAM MAPPER", "ROM", "FDC", "SLOT A", "SLOT B", "KBD LAYOUT", "ROM MIROR", "IO_MIRROR", "MIRROR"]
EXTENSIONS  = ["ROM", "SCC", "SCC2", "FM_PAC", "MEGA_FLASH_ROM_SCC_SD", "GM2", "FDC", "EMPTY" ]
MSX_TYPES = ["MSX1", "MSX2"]


#BLOCK_TYPES = ["NONE", "RAM", "RAM MAPPER", "ROM", "FDC", "SLOT A", "SLOT B", "KBD LAYOUT", "ROM MIROR", "IO_MIRROR", "MIRROR"]

BLOCK_TYPES = {"NONE"       : 0x00,
               "RAM"        : 0x81, 
               "RAM MAPPER" : 0x82,
               "ROM"        : 0xC1,
               "FDC"        : 0xC3,
               "SLOT A"     : 0x04,
               "SLOT B"     : 0x05,
               "KBD LAYOUT" : 0x06,
               "ROM MIROR"  : 0x00,
               "IO_MIRROR"  : 0x00,
               "MIRROR"     : 0x00
               }

def file_hash(filename):
    """Return the SHA1 hash of the file at `filename`."""
    with open(filename, 'rb') as f:
        return hashlib.sha1(f.read()).hexdigest()


#def get_block_type_id(typ):
#    """Return the tuple of (type, id) for the given block type."""
#    return BLOCK_TYPES.index(typ)


def get_msx_type_id(typ):
    """Return the index of the given MSX type."""
    return MSX_TYPES.index(typ)


def create_MSX_block(msx_type, primary, secondary, block_start, typ, size, sha1, ref):
    """Create and return a bytearray representing a block."""
    
    
    ref = 0 if ref is None else int(ref)
    size = 0 if size is None else int(size)
    block_start = int(block_start) & 3
    slotSubslot = ((int(primary) & 3) << 4) | ((int(secondary) & 3) << 2)
    
    head = bytearray()
    head.extend('MSX'.encode('ascii'))
    
    head.append(BLOCK_TYPES[typ])
    head.append((size >> 8) & 255)
    head.append(size & 255)
    if typ in ["KBD LAYOUT"] :
        None
 
    if typ in ["RAM", "ROM", "FDC"] :
        head.append(0x80 | slotSubslot | block_start)
        head.append(0)
        if (size > 1) :
            head.append(0x80 | slotSubslot | ((block_start+1) & 3))
            head.append(1)
        if (size > 2) :
            head.append(0x80 | slotSubslot | ((block_start+2) & 3))
            head.append(2)
        if (size > 3) :
            head.append(0x80 | slotSubslot | ((block_start+3) & 3))
            head.append(3)

    if typ in ["RAM MAPPER", "SLOT A", "SLOT B"] :
        head.append(0x80 | slotSubslot)
        head.append(0)
        head.append(0x80 | slotSubslot+1)
        head.append(0)
        head.append(0x80 | slotSubslot+2)
        head.append(0)
        head.append(0x80 | slotSubslot+3)
        head.append(0)

    for i in range(len(head),16) :
        head.append(0)
    #print(BLOCK_TYPES[typ])
    #print(len(head))
    
    #head.append(get_msx_type_id(msx_type))
    #head.append(int(primary))
    #head.append(int(secondary))
    #head.append(int(block_id))
    #head.append(typ)
    #head.append(ref)
    #head.append(count)
    #head.extend(bytearray(b'\x00\x00\x00\x00\x00\x00'))
    return head

def create_FW_block(type, size):
    """Create and return a bytearray representing a block."""
    head = bytearray()
    head.extend('MSX'.encode('ascii'))
    head.append(0)
    head.append(type)
    head.append(size >> 8)
    head.append(size & 255)
    head.extend(bytearray(b'\x00\x00\x00\x00\x00\x00\x00\x00\x00'))
    return head

def createFWpack(root, fileHandle) :
    try :
        for fw in root.findall("./fw"):
            fw_name = fw.attrib["name"]
            fw_filename = fw.find('filename').text if fw.find('filename') is not None else None
            fw_SHA1 = fw.find('SHA1').text if fw.find('SHA1') is not None else None
            fw_size = int(fw.find('size').text) if fw.find('size') is not None else None
            if fw_name in EXTENSIONS :
                typ = EXTENSIONS.index(fw_name)
                if fw_SHA1 is not None :
                    if fw_SHA1 in rom_hashes.keys() :                    
                        inFileName = rom_hashes[fw_SHA1]
                        fileSize = os.path.getsize(inFileName)
                        size = fw_size if fw_size is not None else fileSize
                        head = create_FW_block(typ, size  >> 14)
                        fileHandle.write(head)
                        infile = open(inFileName, "rb")
                        fileHandle.write(infile.read())
                        print(size)
                        print(fileSize)
                        if size > fileSize :
                            fileHandle.write(bytes([0xFF] * (size - fileSize)))
                    else :
                        fileHandle.close()
                        raise Exception(f"Skip: {filename} Not found ROM {fw_filename} SHA1:{fw_SHA1}")
        fileHandle.close()
        return False
    except Exception as e:
        print(e)
        return True

def createMSXpack(root, fileHandle) :
    try :
        heads = []
        msx_type_value = None
        msx_type = root.find('type')
        if msx_type is not None:
            msx_type_value = msx_type.text
        for primary in root.findall("./primary"):
            primary_slot = primary.attrib["slot"]
            for secondary in primary.findall("./secondary"):
                secondary_slot = secondary.attrib["slot"]
                for block in secondary.findall("./block"):
                    block_start = block.attrib["start"]
                    block_type = block.find('type').text if block.find('type') is not None else None
                    block_count = block.find('block_count').text if block.find('block_count') is not None else None
                    block_filename = block.find('filename').text if block.find('filename') is not None else None
                    block_SHA1 = block.find('SHA1').text if block.find('SHA1') is not None else None
                    block_ref = block.find('ref').text if block.find('ref') is not None else None
                    head = create_MSX_block(msx_type_value, primary_slot, secondary_slot, block_start, block_type, block_count, block_SHA1, block_ref ) 
                    if block_ref is None :
                        fileHandle.write(head)
                        if block_SHA1 is not None :
                            if block_SHA1 in rom_hashes.keys() :
                                infile = open(rom_hashes[block_SHA1], "rb")
                                fileHandle.write(infile.read())
                            else :
                                fileHandle.close()
                                raise Exception(f"Skip: {filename} Not found ROM {block_filename} SHA1:{block_SHA1}")
                    else :
                        heads.append(head)

        for head in heads :             
            fileHandle.write(head)
        
        kbd_layout = root.find('kbd_layout')
        if kbd_layout is not None:
            head = create_MSX_block(msx_type_value, 0, 0, 0, "KBD LAYOUT", 0, None, 0 ) 
            fileHandle.write(head)
            fileHandle.write(base64.b64decode(kbd_layout.text))
        
        fileHandle.close()
        return False
    except Exception as e:
        print(e)
        return True

# Traverse the XML directory and create blocks for each XML file
def parseDir(dir) :
    for dirpath, dirnames, filenames in os.walk(dir):
        for filename in filenames:
            if filename.endswith('.xml'):
                filepath = os.path.join(dirpath, filename)
                filename_without_extension, extension = os.path.splitext(filename)
                dir_save = "MSX" + dirpath[len(dir):]
                output_filename = os.path.join(dir_save, filename_without_extension) + ".MSX"
                if not os.path.exists(dir_save):
                    os.makedirs(dir_save)

                tree = ET.parse(filepath)
                root = tree.getroot()
                outfile = open(output_filename, "wb")               
                error = True
                if root.tag == "msxConfig" :
                    error = createMSXpack(root, outfile)
                if root.tag == "fwConfig" :
                    error = createFWpack(root, outfile)
                if error :
                    outfile.close()
                    os.remove(output_filename)


# Traverse the ROM directory and save the hashes of the files in a dictionary
rom_hashes = {}
for dirpath, dirnames, filenames in os.walk(ROM_DIR):
    for filename in filenames:
        filepath = os.path.join(dirpath, filename)
        rom_hashes[file_hash(filepath)] = filepath


parseDir(XML_DIR_COMP)
parseDir(XML_DIR_FW)

            

                
