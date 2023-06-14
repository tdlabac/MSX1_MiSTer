typedef enum logic [1:0] {AUTO,PAL,NTSC} video_mode_t;
typedef enum logic {CAS_AUDIO_FILE,CAS_AUDIO_ADC} cas_audio_src_t;
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
        video_mode_t    video_mode;
        cas_audio_src_t cas_audio_src;
    } user_config_t;    
    
    typedef struct {
        logic     [3:0] slot_expander_en;   
        MSX_typ_t       MSX_typ;
        logic     [7:0] ram_size;
        logic           use_FDC;
    } bios_config_t;    
    
    typedef struct {
        logic  [3:0] ref_ram;
        logic  [1:0] offset_ram;
        mapper_typ_t mapper;
        device_typ_t device;
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
    } config_cart_t;
        
endpackage