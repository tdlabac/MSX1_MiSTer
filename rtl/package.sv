
/*
parameter MAPPER_NO_UNKNOWN = 6'd0;
parameter MAPPER_ASCII8     = 6'd1;
parameter MAPPER_ASCII16    = 6'd2;
parameter MAPPER_KONAMI     = 6'd3;
parameter MAPPER_KONAMI_SCC = 6'd4;
parameter MAPPER_KOEI       = 6'd5;
parameter MAPPER_LINEAR     = 6'd5;
parameter MAPPER_R_TYPE     = 6'd7;
parameter MAPPER_WIZARDRY   = 6'd8;

parameter CART_TYPE_ROM     = 3'd0;
parameter CART_TYPE_SCC     = 3'd1;
parameter CART_TYPE_SCC2    = 3'd2;
parameter CART_TYPE_FM_PAC  = 3'd3;
parameter CART_TYPE_GM2     = 3'd4;
parameter CART_TYPE_FDC     = 3'd5;
parameter CART_TYPE_EMPTY   = 3'd6;
*/
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
typedef enum logic [4:0] {CONFIG_NONE, CONFIG_RAM, CONFIG_BIOS, CONFIG_FDC, CONFIG_CART_A, CONFIG_CART_B} config_typ_t;
typedef enum logic [1:0] {BLOCK_TYP_RAM, BLOCK_TYP_ROM, BLOCK_TYP_FDC} block_typ_t;
typedef enum {SLOT_TYP_EMPTY, SLOT_TYP_RAM, SLOT_TYP_ROM, SLOT_TYP_MSX2_RAM, SLOT_TYP_MAPPER, SLOT_TYP_CART_A, SLOT_TYP_CART_B} slot_typ_t;
typedef enum logic [2:0] {CART_TYP_ROM, CART_TYP_SCC, CART_TYP_SCC2, CART_TYP_FM_PAC, CART_TYP_GM2, CART_TYP_FDC, CART_TYP_EMPTY } cart_typ_t;
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
        logic  [2:0]    ioctl_id;
        config_typ_t    typ;
        logic  [3:0]    block_id;
        logic  [7:0]    block_count;
        logic  [1:0]    slot;
        logic  [1:0]    sub_slot;
        logic           slot_internal_mapper;
        logic  [1:0]    start_block;
        logic [27:0]    store_address;      //Store DDR3
    } msx_config_t;

    typedef struct {
        fw_block  fmpac;
        fw_block  gm2;
        fw_block  vy010;
    } fw_blocks_t;
    
    typedef struct {
        block_typ_t     typ;                //Typ Bloku  
        logic  [7:0]    block_count;        //delka
        logic [24:0]    mem_offset;         //Umisteni SDRAM/BRAM
    } block_t;    
    
    typedef struct {           
        logic [3:0]    block_id;
        logic [1:0]    offset;
        logic          init;  
    } mem_block_t;    

    typedef struct { 
        mem_block_t    block[4];
    } subslot_t;    
    
    typedef struct {
        slot_typ_t typ;
        subslot_t subslot[4];
    } slot_t;

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
        cart_typ_t   typ;
        mapper_typ_t mapper;
    } config_cart_t;

    typedef struct {
        logic [27:0] store_address;      //Store DDR3
        logic  [7:0] block_count;
    } fw_rom_t;


endpackage