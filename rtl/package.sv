

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
typedef enum logic [1:0]{SIZE128,SIZE64,SIZE512,SIZE256} ram_size_t;

package MSX;  
    typedef struct {
        MSX_typ_t       typ;
        logic           scandoubler;
        logic           border;
        ram_size_t      ram_size;
        video_mode_t    video_mode;
        cas_audio_src_t cas_audio_src;
    } config_t;
endpackage