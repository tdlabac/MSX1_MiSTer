//https://www.msx.org/wiki/ROM_mappers
module cart_rom
(
    input            clk,
    input            clk_en,
    input            reset,
    input     [15:0] addr,
    input            wr,
    input            rd,
    input            iorq,
    input            mreq,
    input            m1,
    input            en,
    input            slot,
    //input	         SLTSL_n,
    input      [7:0] d_from_cpu,
    output     [7:0] d_to_cpu,
    output           cart_oe,
    output signed [15:0] sound,
    //ROM info
    //input      [5:0] mapper,
    input MSX::config_cart_t cart_conf[2],
    input MSX::rom_info_t rom_info[2],
    //input      [3:0] rom_offset,
    //input     [24:0] rom_size,
    //Memory
    output    [24:0] mem_addr,
    output           sram_oe,
    output           sram_we

    
    //input      [2:0] sram_size
    /*
    //Memory
    output    [24:0] mem_addr[2],
    output     [7:0] mem_data[2],
    output     [1:0] mem_wren,
    output     [1:0] mem_rden,
    input      [7:0] mem_q[2]  
    */  
);
wire [24:0] mem_addr_konami, mem_addr_konami_scc, mem_addr_ascii8, mem_addr_ascii16, mem_addr_gm2, mem_addr_linear, mem_addr_none, mem_addr_fmPAC;
wire        en_konami, en_konami_scc, en_ascii8, en_ascii16, en_gm2, en_linear, en_fmPAC, en_scc, en_scc2, en_fdc, en_none;
wire        mem_oe_konami, mem_oe_konami_scc, mem_oe_ascii8, mem_oe_ascii16, mem_oe_gm2, mem_oe_linear, mem_oe_none, mem_oe_fmPAC;
wire        subtype_r_type, subtype_koei, subtype_wizardy;
wire        sram_we_gm2, sram_we_fmPAc, sram_we_ascii8, sram_we_ascii16, sram_we_konami_scc;
wire        sram_oe_gm2, sram_oe_fmPAc, sram_oe_ascii8, sram_oe_ascii16, sram_oe_konami_scc;
wire        fmPac_oe, scc_oe;
wire [7:0]  d_to_cpu_fmPAC, d_to_cpu_scc;
wire signed [15:0] sound_fmpac[2], sound_scc[2], sound_A, sound_B;

/*
//Unused signals
assign mem_rden[1] = 'b0;


wire [14:0] sram_addr_ascii8, sram_addr_ascii16, sram_addr_gamemaster2, sram_addr_fmPac;
wire        sram_we_ascii8, sram_we_ascii16, sram_we_gamemaster2, sram_we_fmPAc;
wire        sram_oe_ascii8, sram_oe_ascii16, sram_oe_gamemaster2, sram_oe_fmPAc;
wire [24:0] mem_addr_konami, mem_addr_konami_scc, mem_addr_ascii8, mem_addr_ascii16, mem_addr_gamemaster2, mem_addr_linear, mem_addr_none, mem_addr_fmPAC;
wire        mem_oe_konami, mem_oe_konami_scc, mem_oe_ascii8, mem_oe_ascii16, mem_oe_gamemaster2, mem_oe_linear, mem_oe_none, mem_oe_fmPAC;
wire        mem_wren_scc;
wire        en_konami, en_konami_scc, en_ascii8, en_ascii16, en_gm2, en_linear, en_fmPAC, en_scc, en_scc2, en_fdc, en_none;
wire        subtype_r_type, subtype_koei, subtype_wizardy;
wire        scc_oe, fmPac_oe;
wire [7:0]  d_to_cpu_scc, d_to_cpu_fmPAC;
wire [14:0] scc_sound;
wire [15:0] fmPAC_sound;

assign sound       = mapper == MAPPER_KONAMI_SCC   ? scc_sound         :
                     cart_type == CART_TYPE_SCC    ? scc_sound         :
                     cart_type == CART_TYPE_SCC2   ? scc_sound         :
                     cart_type == CART_TYPE_FM_PAC ? fmPAC_sound[15:1] :
                                                     14'd0             ;

assign mem_rden[0] = ~SLTSL_n & rd;
*/
assign mem_addr    = sram_oe_fmPAc      ? mem_addr_fmPAC       :
                     sram_oe_gm2        ? mem_addr_gm2         :
                     sram_oe_konami_scc ? mem_addr_konami_scc  :
                     en_konami          ? mem_addr_konami      :
                     en_konami_scc      ? mem_addr_konami_scc  :
                     en_scc             ? mem_addr_konami_scc  :
                     en_scc2            ? mem_addr_konami_scc  :
                     en_ascii8          ? mem_addr_ascii8      :
                     en_ascii16         ? mem_addr_ascii16     :
                     en_gm2             ? mem_addr_gm2         :
                     en_linear          ? mem_addr_linear      :
                     en_fmPAC           ? mem_addr_fmPAC       :
                                          mem_addr_none        ;

assign sram_oe = sram_oe_fmPAc | sram_oe_gm2 | sram_oe_ascii8 | sram_oe_ascii16 | sram_oe_konami_scc;
assign sram_we = sram_we_fmPAc | sram_we_gm2 | sram_we_ascii8 | sram_we_ascii16 | sram_we_konami_scc;
/*
assign mem_wren[0] = en_scc         ? mem_wren_scc              :
                     en_scc2        ? mem_wren_scc              :
                                      1'b0                      ;
assign mem_data[0] = d_from_cpu;
*/
assign d_to_cpu    = //
                     scc_oe                      ? d_to_cpu_scc   :
                     fmPac_oe                    ? d_to_cpu_fmPAC :
                     //mem_oe                      ? mem_q[0]       :
                                                   8'hFF          ; 
assign cart_oe     = fmPac_oe | scc_oe;

assign sound_A = cart_conf[0].typ == CART_TYP_FM_PAC       ? sound_fmpac[0] :
                 cart_conf[0].typ == CART_TYP_SCC          ? sound_scc[0]   :
                 cart_conf[0].typ == CART_TYP_SCC2         ? sound_scc[0]   :
                 cart_conf[0].typ == CART_TYP_ROM          
                 & rom_info[0].mapper == MAPPER_KONAMI_SCC ? sound_scc[0]   :
                                                             16'd0          ;
                                                                          

assign sound_B = cart_conf[1].typ == CART_TYP_FM_PAC       ? sound_fmpac[1] :
                 cart_conf[1].typ == CART_TYP_SCC          ? sound_scc[1]   :
                 cart_conf[1].typ == CART_TYP_SCC2         ? sound_scc[1]   :
                 cart_conf[1].typ == CART_TYP_ROM          
                 & rom_info[1].mapper == MAPPER_KONAMI_SCC ? sound_scc[1]   :
                                                             16'd0          ;

assign sound = sound_A + sound_B;                                                                        


//SRAM
/*
assign mem_wren[1] = sram_we;
assign mem_data[1] = d_from_cpu;
assign mem_addr[1] = en_fmPAC       ? sram_addr_fmPac           :
                     en_ascii8      ? sram_addr_ascii8          :
                     en_ascii16     ? sram_addr_ascii16         :
                     en_gm2         ? sram_addr_gamemaster2     :
                                      13'h0                     ;
*/
/*
wire  [5:0] sram_mask = 6'b111111 << sram_size;
wire        sram_en   = ~|(mem_addr[1][14:9] & sram_mask);
wire        sram_we   = sram_en & (sram_we_gamemaster2 | sram_we_ascii8 | sram_we_ascii16 | sram_we_fmPAc);
wire        sram_oe   = sram_en & (sram_oe_gamemaster2 | sram_oe_ascii8 | sram_oe_ascii16 | sram_oe_fmPAc);
wire        mem_oe    = mem_oe_konami | mem_oe_konami_scc | mem_oe_ascii8 | mem_oe_ascii16 | mem_oe_gamemaster2 | mem_oe_linear | mem_oe_none | mem_oe_fmPAC;
*/
/*
0  0 0000 -
1  1 0000 - 0400 0000 0100 - 0000 0011 & 0111 1100 - 
2  2 0000 - 0800 0000 1000 - 0000 0111 & 0111 1000 - 
3  4 0000 - 1000 0001 0000 - 0000 1111 & 0111 0000 - 
4  8 0000 - 2000 0010 0000 - 0001 1111 & 0110 0000 - 
5 16 0000 - 4000 0100 0000 - 0011 1111 & 0100 0000 - 
6 32 0000 - 8000 1000 0000 - 0111 1111 & 0000 0000 - 
*/

cart_mapper_decoder decoder
(
    .en(en),
    .cart_typ(cart_conf[slot].typ),
    .mapper(rom_info[slot].mapper),
    .*
);

cart_konami konami
(
    .wr(wr & mreq),
    .cs(en_konami),
    .rom_size(rom_info[slot].size),
    .mem_addr(mem_addr_konami),
    .*
);

cart_konami_scc konami_scc
(
    .wr(wr & mreq),
    .rd(rd & mreq),
    .cs(en_konami_scc | en_scc | en_scc2),
    .scc(en_scc),
    .scc2(en_scc2),
    .rom_size(rom_info[slot].size),
    .mem_addr(mem_addr_konami_scc),
    .mem_oe(sram_oe_konami_scc),
    .mem_wren(sram_we_konami_scc),
    .cart_oe(scc_oe),
    .sound(sound_scc),
    //.scc_mode(),
    .d_to_cpu(d_to_cpu_scc),
    .*
); 

cart_ascii8 ascii8
(
    .wr(wr & mreq),
    .cs(en_ascii8),
    .koei(subtype_koei),
    .wizardry(subtype_wizardy),
    .rom_size(rom_info[slot].size),
    .mem_addr(mem_addr_ascii8),
    .sram_oe(sram_oe_ascii8),
    .sram_we(sram_we_ascii8),
    .*
);

cart_ascii16 ascii16
(
    .wr(wr & mreq),
    .cs(en_ascii16),
    .r_type(subtype_r_type),
    .rom_size(rom_info[slot].size),
    .mem_addr(mem_addr_ascii16),
    .sram_oe(sram_oe_ascii16),
    .sram_we(sram_we_ascii16),
    .*
);

cart_gamemaster2 gamemaster2
(
    .wr(wr & mreq),
    .cs(en_gm2),
    .sram_we(sram_we_gm2),
    .sram_oe(sram_oe_gm2),
    .mem_addr(mem_addr_gm2),
    .*
); 

cart_linear linear
(
    .rom_size(rom_info[slot].size),
    .mem_addr(mem_addr_linear),
    .*
);

cart_none none
(
    .rom_offset(rom_info[slot].offset),
    .mem_addr(mem_addr_none),
    .*
);

cart_fm_pac fmPAC
(
    .d_to_cpu(d_to_cpu_fmPAC),
    .cs(en_fmPAC),
    .mem_addr(mem_addr_fmPAC),
    .cart_oe(fmPac_oe),
    .sram_oe(sram_oe_fmPAc),
    .sram_we(sram_we_fmPAc),
    .sound(sound_fmpac),
    .*
);

endmodule