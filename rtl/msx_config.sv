parameter CONF_STR_SLOT_A = {
    "h2O[19:17],SLOT A,ROM,SCC,SCC+,FM-PAC,MegaFlashROM SCC+ SD,GameMaster2,FDC,Empty;",
    "H2O[19:17],SLOT A,ROM,SCC,SCC+,FM-PAC,MegaFlashROM SCC+ SD,GameMaster2,Empty;"
};
parameter CONF_STR_SLOT_B = {
    "O[31:29],SLOT B,ROM,SCC,SCC+,FM-PAC,Empty;"
};
parameter CONF_STR_MAPPER_A = {
    "H3O[23:20],Mapper type,auto,ASCII8,ASCII16,Konami,KonamiSCC,KOEI,linear64,R-TYPE,WIZARDRY,none;"
};
parameter CONF_STR_MAPPER_B = {
    "H4O[34:32],Mapper type,auto,ASCII8,ASCII16,Konami,KonamiSCC,KOEI,linear64,R-TYPE,WIZARDRY,none;"
};
parameter CONF_STR_SRAM_SIZE_A = {
    "H7H5O[28:26],SRAM size,auto,1kB,2kB,4kB,8kB,16kB,32kB,none;",
    "h7H5O[28:26],SRAM size,auto,1kB,2kB,4kB,8kB,none;"
};
parameter CONF_STR_RAM_SIZE = {
    "H7H2P2O[16:15],RAM Size,128kB,64kB,512kB,256kB;",
};

module msx_config
(
    input                clk,
    input                reset,
    input                msx_type,
    input         [63:0] HPS_status,
    input                scandoubler,
    input          [5:0] mapper_detected[2],
    input          [2:0] sram_size_detected[2],
    input          [1:0] sdram_size,

    output MSX::config_cart_t cart_conf[2],
    
    //output         [2:0] cart_type[2],
    output         [2:0] sram_size[2],
    //output         [2:0] sram_B_size,
    //output         [5:0] mapper_A,
    //output         [5:0] mapper_B,
    output               sram_A_select_hide,
    output               sram_loadsave_hide,
    output               ROM_A_load_hide,
    output               ROM_B_load_hide, //4
    output               fdc_enabled,
    output MSX::config_t MSXconf,
    output               reset_request,
    output               cart_changed
    //output         [1:0] rom_eject
);


wire [2:0] slot_A_select   = HPS_status[19:17];
wire [2:0] slot_B_select   = HPS_status[31:29];
wire [2:0] sram_A_select   = HPS_status[28:26];
wire [3:0] mapper_A_select = HPS_status[23:20];
wire [3:0] mapper_B_select = HPS_status[34:32]; 

assign cart_conf[0].typ = cart_typ_t'(slot_A_select < CART_TYP_FDC  ? slot_A_select   :
                                      MSXconf.typ == MSX2           ? CART_TYP_EMPTY  :
                                      slot_A_select == CART_TYP_FDC ? CART_TYP_FDC    :
                                                                      CART_TYP_EMPTY );

assign cart_conf[1].typ    = cart_typ_t'(slot_B_select < CART_TYP_MFRSD ? slot_B_select : CART_TYP_EMPTY );
assign cart_conf[0].mapper = mapper_typ_t'(mapper_A_select == 4'd9 ? MAPPER_UNUSED : {2'b00, mapper_A_select});
assign cart_conf[1].mapper = mapper_typ_t'(mapper_B_select == 4'd9 ? MAPPER_UNUSED : {2'b00,mapper_B_select});

assign sram_A_select_hide = cart_conf[0].typ != CART_TYP_ROM | mapper_A_select == 4'd0; 
assign sram_size[0] = cart_conf[0].typ == CART_TYP_FM_PAC ? 3'd4                  :
                      cart_conf[0].typ == CART_TYP_GM2    ? 3'd4                  :
                      sram_A_select == 3'd7               ? 3'd0                  :                     
                      sram_A_select_hide                  ? sram_size_detected[0] :
                      sram_A_select == 3'd0               ? sram_size_detected[0] :
                      sdram_size > 2'd0                   ? sram_A_select         :
                      sram_A_select <= 3'd6               ? sram_A_select         :
                                                            3'd4                  ; //8kB

assign sram_size[1] = cart_conf[1].typ == CART_TYP_FM_PAC ? 3'd4                  :
                                                            3'd0                  ;

assign fdc_enabled = MSXconf.typ == MSX2 | cart_conf[0].typ == CART_TYP_FDC;

//assign MSXconf.typ = MSX_typ_t'(HPS_status[11]);
assign MSXconf.typ = MSX_typ_t'(msx_type);
assign MSXconf.scandoubler = scandoubler;
assign MSXconf.video_mode = video_mode_t'(MSXconf.typ == MSX1 ? (HPS_status[12] ? 2'd2 : 2'd1) : HPS_status[14:13]);
assign MSXconf.cas_audio_src = cas_audio_src_t'(HPS_status[8]);
assign MSXconf.ram_size = sdram_size == 2'd0 ? SIZE64 : ram_size_t'(HPS_status[16:15]);
assign MSXconf.border = HPS_status[38];

assign sram_loadsave_hide = sram_size[0] == 0 & sram_size[1] == 0;
assign ROM_A_load_hide    = cart_conf[0].typ != CART_TYP_ROM;
assign ROM_B_load_hide    = cart_conf[1].typ != CART_TYP_ROM;


reg  [20:0] lastConfig;
reg  [5:0]  last_cart_type;

wire [20:0] act_config = {cart_conf[1].typ, cart_conf[0].typ, mapper_A_select, mapper_B_select, sram_A_select, MSXconf.ram_size};
wire [5:0]  act_cart_type = {cart_conf[1].typ, cart_conf[0].typ};

always @(posedge clk) begin
    if (reset) lastConfig <= act_config;
    last_cart_type <= act_cart_type;
end

assign reset_request = lastConfig != act_config;
assign cart_changed = last_cart_type[5:0] != act_cart_type[5:0];
//assign rom_eject = {cart_conf[1].typ == CART_TYP_ROM ? HPS_status[10] : 1'b0, cart_conf[0].typ == CART_TYP_ROM ? HPS_status[10] : 1'b0};
endmodule