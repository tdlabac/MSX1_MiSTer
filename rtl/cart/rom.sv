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
    input	         SLTSL_n,
    input      [7:0] d_from_cpu,
    output     [7:0] d_to_cpu,
    output    [14:0] sound,
    //ROM info
    input      [5:0] mapper,
    input      [2:0] cart_type,
    input      [3:0] rom_offset,
    input     [24:0] rom_size,
    input      [2:0] sram_size,
    //Memory
    output    [24:0] mem_addr[2],
    output     [7:0] mem_data[2],
    output     [1:0] mem_wren,
    output     [1:0] mem_rden,
    input      [7:0] mem_q[2]    
);

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
assign mem_addr[0] = en_konami      ? mem_addr_konami           :
                     en_konami_scc  ? mem_addr_konami_scc       :
                     en_scc         ? mem_addr_konami_scc       :
                     en_scc2        ? mem_addr_konami_scc       :
                     en_ascii8      ? mem_addr_ascii8           :
                     en_ascii16     ? mem_addr_ascii16          :
                     en_gm2         ? mem_addr_gamemaster2      :
                     en_linear      ? mem_addr_linear           :
                     en_fmPAC       ? mem_addr_fmPAC            :
                                      mem_addr_none             ;

assign mem_wren[0] = en_scc         ? mem_wren_scc              :
                     en_scc2        ? mem_wren_scc              :
                                      1'b0                      ;
assign mem_data[0] = d_from_cpu;

assign d_to_cpu    = sram_oe                     ? mem_q[1]       :
                     scc_oe                      ? d_to_cpu_scc   :
                     fmPac_oe                    ? d_to_cpu_fmPAC :
                     mem_oe                      ? mem_q[0]       :
                                                   8'hFF          ;
//SRAM
assign mem_wren[1] = sram_we;
assign mem_data[1] = d_from_cpu;
assign mem_addr[1] = en_fmPAC       ? sram_addr_fmPac           :
                     en_ascii8      ? sram_addr_ascii8          :
                     en_ascii16     ? sram_addr_ascii16         :
                     en_gm2         ? sram_addr_gamemaster2     :
                                      13'h0                     ;

wire  [5:0] sram_mask = 6'b111111 << sram_size;
wire        sram_en   = ~|(mem_addr[1][14:9] & sram_mask);
wire        sram_we   = sram_en & (sram_we_gamemaster2 | sram_we_ascii8 | sram_we_ascii16 | sram_we_fmPAc);
wire        sram_oe   = sram_en & (sram_oe_gamemaster2 | sram_oe_ascii8 | sram_oe_ascii16 | sram_oe_fmPAc);
wire        mem_oe    = mem_oe_konami | mem_oe_konami_scc | mem_oe_ascii8 | mem_oe_ascii16 | mem_oe_gamemaster2 | mem_oe_linear | mem_oe_none | mem_oe_fmPAC;

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
    .en(~SLTSL_n),
    .*
);
cart_konami konami
(
    .clk(clk),
    .reset(reset),
    .rom_size(rom_size),
    .addr(addr),
    .d_from_cpu(d_from_cpu),
    .wr(wr),
    .cs(en_konami),
    .mem_addr(mem_addr_konami),
    .mem_oe(mem_oe_konami)
);
cart_konami_scc konami_scc
(
    .clk(clk),
    .clk_en(clk_en),
    .reset(reset),
    .rom_size(rom_size),
    .addr(addr),
    .d_from_cpu(d_from_cpu),
    .d_to_cpu(d_to_cpu_scc),
    .cart_oe(scc_oe),
    .wr(wr),
    .rd(rd),
    .cs(en_konami_scc | en_scc | en_scc2),
    .scc(en_scc),
    .scc2(en_scc2),
    .mem_addr(mem_addr_konami_scc),
    .mem_wren(mem_wren_scc),
    .mem_oe(mem_oe_konami_scc),
    .scc_sound(scc_sound)
);
cart_ascii8 ascii8
(
    .clk(clk),
    .reset(reset),
    .rom_size(rom_size),
    .addr(addr),
    .d_from_cpu(d_from_cpu),
    .wr(wr),
    .cs(en_ascii8),
    .koei(subtype_koei),
    .wizardry(subtype_wizardy),
    .sram_addr(sram_addr_ascii8),
    .sram_we(sram_we_ascii8),
    .sram_oe(sram_oe_ascii8), 
    .mem_addr(mem_addr_ascii8),
    .mem_oe(mem_oe_ascii8)
);
cart_ascii16 ascii16
(
    .clk(clk),
    .reset(reset),
    .rom_size(rom_size),
    .addr(addr),
    .d_from_cpu(d_from_cpu),
    .wr(wr),
    .cs(en_ascii16),
    .r_type(subtype_r_type),
    .sram_addr(sram_addr_ascii16),
    .sram_we(sram_we_ascii16),
    .sram_oe(sram_oe_ascii16),
    .mem_addr(mem_addr_ascii16),
    .mem_oe(mem_oe_ascii16)  
);
cart_gamemaster2 gamemaster2
(
    .clk(clk),
    .reset(reset),
    .addr(addr),
    .d_from_cpu(d_from_cpu),
    .wr(wr),
    .cs(en_gm2),
    .sram_addr(sram_addr_gamemaster2),
    .sram_we(sram_we_gamemaster2),
    .sram_oe(sram_oe_gamemaster2),
    .mem_addr(mem_addr_gamemaster2),
    .mem_oe(mem_oe_gamemaster2)  
);
cart_linear linear
(
    .cs(en_linear),
    .rom_size(rom_size),
    .addr(addr),
    .mem_addr(mem_addr_linear),
    .mem_oe(mem_oe_linear)
);
cart_none none
(
    .cs(en_none),
    .addr(addr),
    .rom_offset(rom_offset),
    .mem_addr(mem_addr_none),
    .mem_oe(mem_oe_none)
);
cart_fm_pac fmPAC
(
    .clk(clk),
    .clk_en(clk_en),
    .reset(reset),
    .addr(addr),
    .d_from_cpu(d_from_cpu),
    .d_to_cpu(d_to_cpu_fmPAC),
    .cs(en_fmPAC),
    .wr(wr),
    .rd(rd),
    .iorq(iorq),
    .m1(m1),    
    .sound(fmPAC_sound),
    .mem_addr(mem_addr_fmPAC),
    .mem_oe(mem_oe_fmPAC),
    .cart_oe(fmPac_oe),
    .sram_oe(sram_oe_fmPAc),
    .sram_we(sram_we_fmPAc),    
    .sram_addr(sram_addr_fmPac)    
);

endmodule