parameter CONF_STR_SLOT_A = {
    "h2O[19:17],SLOT A,ROM,SCC,SCC+,FM-PAC,MegaFlashROM SCC+ SD,GameMaster2,FDC,Empty;",
    "H2O[19:17],SLOT A,ROM,SCC,SCC+,FM-PAC,MegaFlashROM SCC+ SD,GameMaster2,Empty;"
};
parameter CONF_STR_SLOT_B = {
    "O[31:29],SLOT B,ROM,SCC,SCC+,FM-PAC,Empty;"
};
parameter CONF_STR_MAPPER_A = {
    "H3O[23:20],Mapper type,auto,none,ASCII8,ASCII16,Konami,KonamiSCC,KOEI,linear64,R-TYPE,WIZARDRY;"
};
parameter CONF_STR_MAPPER_B = {
    "H4O[35:32],Mapper type,auto,none,ASCII8,ASCII16,Konami,KonamiSCC,KOEI,linear64,R-TYPE,WIZARDRY;"
};
parameter CONF_STR_SRAM_SIZE_A = {
    "H7H5O[28:26],SRAM size,auto,1kB,2kB,4kB,8kB,16kB,32kB,none;",
    "h7H5O[28:26],SRAM size,auto,1kB,2kB,4kB,8kB,none;"
};
parameter CONF_STR_RAM_SIZE = {
    "H7H2P2O[16:15],RAM Size,128kB,64kB,512kB,256kB;"
};

module msx_config
(
    input                     clk,
    input                     reset,
    input MSX_typ_t           msx_type,
    input              [63:0] HPS_status,
    input                     scandoubler,
    input               [5:0] mapper_detected[2],
    input               [2:0] sram_size_detected[2],
    input               [1:0] sdram_size,
    output MSX::config_cart_t cart_conf[2],
    output                    sram_A_select_hide,
    output                    ROM_A_load_hide, //3 
    output                    ROM_B_load_hide, //4
    output                    fdc_enabled,
    output MSX::user_config_t msxConfig,
    output                    reload
);

/*verilator tracing_off*/
logic  [7:0] selected_sram_size_A;

wire [2:0] slot_A_select   = HPS_status[19:17];
wire [2:0] slot_B_select   = HPS_status[31:29];
wire [2:0] sram_A_select   = HPS_status[28:26];
wire [3:0] mapper_A_select = HPS_status[23:20];
wire [3:0] mapper_B_select = HPS_status[35:32]; 

assign cart_conf[0].typ     = cart_typ_t'(slot_A_select < CART_TYP_FDC  ? slot_A_select   :
                              msx_type == MSX2                          ? CART_TYP_EMPTY  :
                              slot_A_select == CART_TYP_FDC             ? CART_TYP_FDC    :
                                                                          CART_TYP_EMPTY );

assign cart_conf[1].typ     = slot_B_select < CART_TYP_MFRSD ? cart_typ_t'(slot_B_select) : CART_TYP_EMPTY;
assign cart_conf[0].selected_mapper    = mapper_typ_t'(mapper_A_select + 4'd2);
assign cart_conf[1].selected_mapper    = mapper_typ_t'(mapper_B_select + 4'd2);
assign cart_conf[0].selected_sram_size = sram_A_select_hide ? 8'd0 : 8'd0; // TODO dopočti
assign cart_conf[1].selected_sram_size = 8'd0;

assign msxConfig.typ = msx_type;
assign msxConfig.scandoubler = scandoubler;
assign msxConfig.video_mode = video_mode_t'(msx_type == MSX1 ? (HPS_status[12] ? 2'd2 : 2'd1) : HPS_status[14:13]);
assign msxConfig.cas_audio_src = cas_audio_src_t'(HPS_status[8]);
assign msxConfig.border = HPS_status[38];

assign ROM_A_load_hide    = cart_conf[0].typ != CART_TYP_ROM;
assign ROM_B_load_hide    = cart_conf[1].typ != CART_TYP_ROM;
assign sram_A_select_hide = cart_conf[0].typ != CART_TYP_ROM | mapper_A_select == 4'd0; 
assign fdc_enabled = msx_type == MSX2 | cart_conf[0].typ == CART_TYP_FDC;


logic  [18:0] lastConfig;
wire [18:0] act_config = {cart_conf[1].typ, cart_conf[0].typ, cart_conf[0].selected_mapper, cart_conf[1].selected_mapper, sram_A_select};

always @(posedge clk) begin
    if (reset) lastConfig <= act_config;
end

assign reload = lastConfig != act_config;

endmodule
