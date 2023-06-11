typedef enum logic [1:0] {AUTO,PAL,NTSC} video_mode_t;
typedef enum logic {CAS_AUDIO_FILE,CAS_AUDIO_ADC} cas_audio_src_t;
//typedef enum logic [1:0] {SIZE128,SIZE64,SIZE512,SIZE256} ram_size_t;


/*
parameter IMG_SRAM          = 4'd0;
parameter IMG_SRAM_A        = 4'd1;
parameter IMG_SRAM_B        = 4'd2;

parameter MEM_BIOS          = 0;
parameter MEM_EXT           = 1;
parameter MEM_RAM           = 2;
parameter MEM_DSK           = 3;
parameter MEM_FWA           = 4;
parameter MEM_SRAMA         = 5;
parameter MEM_FWB           = 6;
parameter MEM_SRAMB         = 7;

typedef enum logic {MSX2,MSX1} MSX_typ_t;
typedef enum logic [1:0] {AUTO,PAL,NTSC} video_mode_t;
typedef enum logic {CAS_AUDIO_FILE,CAS_AUDIO_ADC} cas_audio_src_t;
typedef enum logic [1:0] {SIZE128,SIZE64,SIZE512,SIZE256} ram_size_t;
typedef enum logic [4:0] {CONFIG_NONE, CONFIG_RAM, CONFIG_RAM_MAPPER, CONFIG_BIOS, CONFIG_FDC, CONFIG_CART_A, CONFIG_CART_B, CONFIG_KBD_LAYOUT, CONFIG_ROM_MIRROR, CONFIG_IO_MIRROR, CONFIG_MIRROR} config_typ_t;
typedef enum logic [1:0] {BLOCK_TYP_RAM, BLOCK_TYP_ROM, BLOCK_TYP_FDC, BLOCK_TYP_IO_MIRROR} block_typ_t;
typedef enum logic [3:0] {SLOT_TYP_EMPTY, SLOT_TYP_RAM, SLOT_TYP_ROM, SLOT_TYP_MSX2_RAM, SLOT_TYP_MAPPER, SLOT_TYP_CART_A, SLOT_TYP_CART_B, SLOT_TYP_FDC} slot_typ_t;
typedef enum logic [2:0] {CART_TYP_ROM, CART_TYP_SCC, CART_TYP_SCC2, CART_TYP_FM_PAC, CART_TYP_MFRSD, CART_TYP_GM2, CART_TYP_FDC, CART_TYP_EMPTY } cart_typ_t;
typedef enum logic [5:0] {MAPPER_NO_UNKNOWN, MAPPER_ASCII8, MAPPER_ASCII16, MAPPER_KONAMI, MAPPER_KONAMI_SCC, MAPPER_KOEI, MAPPER_LINEAR, MAPPER_R_TYPE, MAPPER_WIZARDRY } mapper_typ_t;
package MSX;  
    typedef struct {
        MSX_typ_t       typ;
        logic           scandoubler;
        logic           border;
        ram_size_t      ram_size;
        video_mode_t    video_mode;
        cas_audio_src_t cas_audio_src;
    } config_t;


    
    typedef struct {           
        logic [3:0]    block_id;
    } fw_block;
    
    typedef struct {
        config_typ_t typ;
        logic  [1:0] reference;
        logic  [7:0] block_count;
        logic  [1:0] slot;
        logic  [1:0] sub_slot;
        logic  [1:0] start_block;
        logic [27:0] store_address;      //Store DDR3
    } msx_config_t;

    typedef struct {           
        slot_typ_t   typ;
        logic [3:0]  block_id;
        logic [1:0]  offset;
        logic        init;  
    } mem_block_t;    

    typedef struct {
        slot_typ_t typ;
    } slot_t;

    typedef struct {
        slot_t       slot[0:3];
        mem_block_t  mem_block[0:3][0:3][0:3];
    } msx_slots_t;

    typedef struct {
        logic  [9:0] block_count;        //delka
        logic [24:0] mem_offset;         //Umisteni SDRAM/BRAM
    } block_t;    
    
    typedef struct {
        logic  [7:0] block_count;        //delka
        logic [24:0] mem_offset;         //Umisteni SDRAM/BRAM
    } sram_block_t;

    typedef struct {
        logic  [5:0] mapper;
        logic  [3:0] offset;
        logic [24:0] size;
    } rom_info_t;
    
    typedef struct {
        logic [24:0] rom_size;          //IOCTL size
        logic  [5:0] rom_mapper;        //IOCTL detect
        logic        loaded;
    } ioctl_rom_t;

    typedef struct {
        logic [27:0] store_address;      //Store DDR3
        logic  [9:0] block_count;
        logic  [7:0] sram_block_count;
        logic  [7:0] ram_block_count;
    } fw_rom_t;

*/
typedef enum logic [1:0] {BLOCK_TYP_NONE, BLOCK_TYP_UNUSED3, BLOCK_TYP_UNUSED2, BLOCK_TYP_UNUSED1} block_typ_t;
typedef enum logic [3:0] {CONFIG_NONE, CONFIG_FDC, CONFIG_SLOT_A, CONFIG_SLOT_B, CONFIG_SLOT_INTERNAL, CONFIG_KBD_LAYOUT, CONFIG_CONFIG} config_typ_t;
typedef enum logic [2:0] {CART_TYP_ROM, CART_TYP_SCC, CART_TYP_SCC2, CART_TYP_FM_PAC, CART_TYP_MFRSD, CART_TYP_GM2, CART_TYP_FDC, CART_TYP_EMPTY } cart_typ_t;
typedef enum logic [4:0] {MAPPER_UNUSED, MAPPER_RAM, MAPPER_AUTO, MAPPER_NONE, MAPPER_ASCII8, MAPPER_ASCII16, MAPPER_KONAMI, MAPPER_KONAMI_SCC, MAPPER_KOEI, MAPPER_LINEAR, MAPPER_RTYPE, MAPPER_WIZARDY, /*NEXT INTERNAL*/ MAPPER_FMPAC,MAPPER_OFFSET, MAPPER_MFRSD1,MAPPER_MFRSD2, MAPPER_MFRSD3, MAPPER_GM2} mapper_typ_t;
typedef enum logic [3:0] {DEVICE_NONE, DEVICE_FDC, DEVICE_OPL3, DEVICE_SCC, DEVICE_SCC2, DEVICE_MFRSD0} device_typ_t;
typedef enum logic [3:0] {ROM_NONE, ROM_ROM, ROM_RAM, ROM_FDC, ROM_FMPAC, ROM_MFRSD, ROM_GM2 } data_ID_t;
typedef enum logic {MSX1,MSX2} MSX_typ_t;


typedef logic [6:0] dev_typ_t;
parameter DEV_NONE   = 7'b000000;
parameter DEV_FDC    = 7'b000001;
parameter DEV_OPL3   = 7'b000010;
/*cart*/
parameter DEV_SCC    = 7'b000100;
parameter DEV_SCC2   = 7'b001000;
parameter DEV_MFRSD2 = 7'b010000;
parameter DEV_FLASH  = 7'b100000;


package MSX;
    
    typedef struct {
        MSX_typ_t       typ;
        logic           scandoubler;
        logic           border;
        //ram_size_t      ram_size;
        video_mode_t    video_mode;
        cas_audio_src_t cas_audio_src;
    } user_config_t;    
    

    typedef struct {
        logic     [3:0] slot_expander_en;   
        MSX_typ_t       MSX_typ;
        logic     [7:0] ram_size;
    } bios_config_t;    
    
//NEW    
    typedef struct {
        logic  [3:0] ref_ram;
        logic  [1:0] offset_ram;
        //logic  [3:0] ref_sram;
        mapper_typ_t mapper;
        device_typ_t device;
        //logic        external;
        logic        cart_num;
    } block_t;    
    
    typedef struct {
        logic [26:0] addr;
        logic [15:0] size;
        logic        ro;
    } lookup_RAM_t;

    
    typedef struct {
        logic [17:0] addr;
        logic [15:0] size;
    } lookup_SRAM_t;

    typedef struct {
        cart_typ_t   typ;
        mapper_typ_t selected_mapper;
        logic [7:0]  selected_sram_size;
        //mapper_typ_t mapper;
        //device_typ_t io_device;
        //device_typ_t mem_device;
        //data_ID_t    rom_id;
        //logic [7:0]  sram_size;
        //logic [7:0]  mode; //00-NONE, 01-MEM-REFERENCE + DEV, 02-MEM + DEV, 03-DEVICE
        //logic [7:0]  param; //offset or block ref 
    } config_cart_t;

//MSX CONFIG typ + slot/subsllot  DATA_ID, SIZE, MEM_DEV,  MEM_MAP, MODE, PARAM
//    3                           4        56    7         8        9     10
        
endpackage

/*
40 01 00 02 00 02 0A 04 00 00 00 00 0/0 {'start': 0, 'type': 'ROM', 'count': 2, 'filename': 'nms8250_basic-bios2.rom', 'SHA1': '6103b39f1e38d1aa2d84b1c3219c44f1abb5436e'}
24 01 00 00 00 00 00 00 00 00 00 00 1/0 {'start': 0, 'type': 'SLOT A', 'count': 0, 'filename': None, 'SHA1': None}
38 01 00 00 00 00 00 00 00 00 00 00 2/0 {'start': 0, 'type': 'SLOT B', 'count': 0, 'filename': None, 'SHA1': None}
4C 01 00 01 00 02 02 00 00 00 00 00 3/0 {'start': 0, 'type': 'ROM', 'count': 1, 'filename': 'nms8250_msx2sub.rom', 'SHA1': '5c1f9c7fb655e43d38e5dd1fcc6b942b2ff68b02'}
4C 00 00 01 00 02 04 00 00 00 00 00 3/0 {'start': 1, 'type': 'ROM_MIRROR', 'count': 1, 'filename': None, 'SHA1': None, 'ref': {'start': 0, 'type': 'ROM', 'count': 1, 'filename': 'nms8250_msx2sub.rom', 'SHA1': '5c1f9c7fb655e43d38e5dd1fcc6b942b2ff68b02'}}
4C 00 00 01 00 02 10 00 00 00 00 00 3/0 {'start': 2, 'type': 'ROM_MIRROR', 'count': 1, 'filename': None, 'SHA1': None, 'ref': {'start': 0, 'type': 'ROM', 'count': 1, 'filename': 'nms8250_msx2sub.rom', 'SHA1': '5c1f9c7fb655e43d38e5dd1fcc6b942b2ff68b02'}}
4C 00 00 01 00 02 40 00 00 00 00 00 3/0 {'start': 3, 'type': 'ROM_MIRROR', 'count': 1, 'filename': None, 'SHA1': None, 'ref': {'start': 0, 'type': 'ROM', 'count': 1, 'filename': 'nms8250_msx2sub.rom', 'SHA1': '5c1f9c7fb655e43d38e5dd1fcc6b942b2ff68b02'}}
4E 02 00 08 00 03 AA E4 00 00 00 00 3/2 {'start': 0, 'type': 'RAM MAPPER', 'count': 8, 'filename': None, 'SHA1': None}
4F 03 00 01 01 02 08 00 00 00 00 00 3/3 {'start': 1, 'type': 'FDC', 'count': 1, 'filename': 'nms8250_1.08_disk.rom', 'SHA1': 'dab3e6f36843392665b71b04178aadd8762c6589'}
4F 00 00 01 01 00 03 00 00 00 00 00 3/3 {'start': 0, 'type': 'IO_MIRROR', 'count': 1, 'filename': None, 'SHA1': None, 'ref': {'start': 1, 'type': 'FDC', 'count': 1, 'filename': 'nms8250_1.08_disk.rom', 'SHA1': 'dab3e6f36843392665b71b04178aadd8762c6589'}}
4F 00 00 02 01 00 F0 00 00 00 00 00 3/3 {'start': 2, 'type': 'IO_MIRROR', 'count': 2, 'filename': None, 'SHA1': None, 'ref': {'start': 1, 'type': 'FDC', 'count': 1, 'filename': 'nms8250_1.08_disk.rom', 'SHA1': 'dab3e6f36843392665b71b04178aadd8762c6589'}}
50 00 00 00 00 00 00 00 00 00 00 00 -/- {'type': 'KBD LAYOUT', 'count': 0}
60 18 00 00 00 00 00 00 00 00 00 00

MSX\Philips\Philips_VG_8020-00.MSX
40 01 00 02 00 02 0A 04 00 00 00 00 0/0 {'start': 0, 'type': 'ROM', 'count': 2, 'filename': 'vg8020_basic-bios1.rom', 'SHA1': '829c00c3114f25b3dae5157c0a238b52a3ac37db'}
24 01 00 00 00 00 00 00 00 00 00 00 1/0 {'start': 0, 'type': 'SLOT A', 'count': 0, 'filename': None, 'SHA1': None}
38 01 00 00 00 00 00 00 00 00 00 00 2/0 {'start': 0, 'type': 'SLOT B', 'count': 0, 'filename': None, 'SHA1': None}
4C 02 00 04 00 02 AA E4 00 00 00 00 3/0 {'start': 0, 'type': 'RAM', 'count': 4, 'filename': None, 'SHA1': None}
50 00 00 00 00 00 00 00 00 00 00 00 -/- {'type': 'KBD LAYOUT', 'count': 0}
60 00 00 00 00 00 00 00 00 00 00 00

*/