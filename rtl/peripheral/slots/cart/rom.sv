//https://www.msx.org/wiki/ROM_mappers
module cart_rom
(
    input                    clk,
    input                    clk_en,
    input                    reset,
    input             [15:0] addr,
    input                    wr,
    input                    rd,
    input                    iorq,
    input                    mreq,
    input                    m1,
    input                    en,
    input                    slot,
    input              [7:0] d_from_cpu,
    output             [7:0] d_to_cpu,
    output                   cart_oe,
    output signed     [15:0] sound,
    input MSX::config_cart_t cart_conf[2],
    input MSX::rom_info_t    rom_info[2],
    output            [24:0] mem_addr,
    output                   sram_oe,
    output                   sram_we,
        // SD/MMC SPI
    output reg               spi_ss,
    output                   spi_clk,
    input                    spi_di,
    output                   spi_do
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
                     MFRSD & mfrsd_addr_valid ? mfrsd_addr     :
                                          mem_addr_none        ;

assign sram_oe = sram_oe_fmPAc | sram_oe_gm2 | sram_oe_ascii8 | sram_oe_ascii16 | sram_oe_konami_scc;
assign sram_we = sram_we_fmPAc | sram_we_gm2 | sram_we_ascii8 | sram_we_ascii16 | sram_we_konami_scc;
assign d_to_cpu    = scc_oe                      ? d_to_cpu_scc   :
                     fmPac_oe                    ? d_to_cpu_fmPAC :
                     mfrsd_oe                    ? ~mapper_slot   :
                     sdcard_oe                   ? d_from_sd      :
                                                   8'hFF          ; 
assign cart_oe     = fmPac_oe | scc_oe | mfrsd_oe | (MFRSD & subSlot == 2'd2 & ~mfrsd_addr_valid) ; 

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


//Mega Flash ROM SCC+ SD
wire MFRSD = cart_conf[slot].typ == CART_TYP_MFRSD & en;
wire mapper_en = (addr == 16'hFFFF & MFRSD);
logic [7:0] mapper_slot;

always @(posedge reset, posedge clk) begin
   if (reset) begin
      mapper_slot <= 8'h00;
   end else begin
      if (mapper_en & wr & mreq)
         mapper_slot <= d_from_cpu;
   end
end

logic [7:0] configReg, mapperReg, bankRegsSubSlot1[4], sccBanks[4], bankRegsSubSlot3[4];
logic [9:0] offsetReg;


wire subSlot1_en = (MFRSD & subSlot == 2'd1);
wire subSlot3_en = (MFRSD & subSlot == 2'd3);
wire [2:0] page8kB = addr[15:13] - 2'd2;
always @(posedge reset, posedge clk) begin
   if (reset) begin
      configReg <=  8'd03;
      mapperReg <=  8'd00;
      offsetReg <= 10'd00;
      bankRegsSubSlot1[0] <= 8'd0;
      bankRegsSubSlot1[1] <= 8'd1;
      bankRegsSubSlot1[2] <= 8'd2;
      bankRegsSubSlot1[3] <= 8'd3;
      sccBanks[0] <= 8'd0;
      sccBanks[1] <= 8'd1;
      sccBanks[2] <= 8'd2;
      sccBanks[3] <= 8'd3;
   end else begin
      if (subSlot1_en & wr & mreq) begin
         if (addr[15:2] == 14'h1FFF) begin
            if (addr[1:0] == 2'b00 & ~configReg[7]) configReg      <= d_from_cpu;      //FC
            if (addr[1:0] == 2'b01 & ~mapperReg[1]) offsetReg[7:0] <= d_from_cpu;      //FD
            if (addr[1:0] == 2'b10 & ~mapperReg[1]) offsetReg[9:8] <= d_from_cpu[1:0]; //FE
            if (addr[1:0] == 2'b11 & ~mapperReg[2]) mapperReg      <= d_from_cpu;      //FF
         end
         if (~mapperReg[1] & page8kB < 3'd4) 
            case(mapperReg[7:5]) 
               3'd0: //Konami-SCC
                  if (addr[12:11] == 2'b10) begin
                     sccBanks[page8kB[1:0]] <= d_from_cpu;
                     bankRegsSubSlot1[page8kB[1:0]] <= d_from_cpu & (mapperReg[0] ? 8'h3F : 8'hFF);
                  end
               3'd1: //Konami
                  if (addr >= 16'h6000 | mapperReg[3])
                     if (addr >= 16'h6000 | (addr >= 16'h5000 & addr<16'h5800))  
                        bankRegsSubSlot1[page8kB[1:0]] <= d_from_cpu & (mapperReg[0] ? 8'h1F : 8'hFF);
               3'd2,
               3'd3: //64kB
                  bankRegsSubSlot1[page8kB[1:0]] <= d_from_cpu;
               3'd4,
               3'd5: //ASCII-8
                  if (addr[15:13] == 3'b011)
                     bankRegsSubSlot1[addr[12:11]] <= d_from_cpu;
               3'd6,
               3'd7: //ASCII-16
                  case (addr[15:11])
                     5'b01100: begin // 6000-67ffh
                        bankRegsSubSlot1[0] <= (d_from_cpu << 1);
                        bankRegsSubSlot1[1] <= (d_from_cpu << 1)+1'b1; 
                     end
                     5'b01110: begin // 7000-77ffh
                        bankRegsSubSlot1[2] <= (d_from_cpu << 1);
                        bankRegsSubSlot1[3] <= (d_from_cpu << 1)+1'b1;
                     end
                  endcase
            endcase
      end
   end
end

always @(posedge reset, posedge clk) begin
   if (reset) begin
      bankRegsSubSlot3[0] = 8'd0;
      bankRegsSubSlot3[1] = 8'd1;
      bankRegsSubSlot3[2] = 8'd0;
      bankRegsSubSlot3[3] = 8'd0;
   end else begin
      if (subSlot3_en & wr & mreq)
         if (addr[15:13] == 3'b011)
            bankRegsSubSlot3[addr[12:11]] <= d_from_cpu;
   end
end

wire [1:0] subSlot = configReg[2]         ? 2'b01            :
                     addr[15:14] == 2'b00 ? mapper_slot[1:0] :
                     addr[15:14] == 2'b01 ? mapper_slot[3:2] :
                     addr[15:14] == 2'b10 ? mapper_slot[5:4] :
                                            mapper_slot[7:6] ;

wire is64Kmapper = mapperReg[7:6] == 2'b01;

wire  [3:0] page = is64Kmapper ? addr[15:14] : addr[15:13] - 4'd2;
wire [15:0] bank = configReg[4] & page == 4'd0 & bankRegsSubSlot1[page[1:0]] == 2'd0 ? 16'h3FA                                   :
                   configReg[4] & page == 4'd1 & bankRegsSubSlot1[page[1:0]] == 2'd1 ? 16'h3FB                                   :
                                                                                        bankRegsSubSlot1[page[1:0]] + offsetReg ; 

wire [22:0] mfrsd_64Kaddr = 23'('h10000 + (bank << (is64Kmapper ? 'd14:'d13)) + (is64Kmapper ? addr[13:0] : addr[12:0]));
//wire [22:0] mfrsd_64Kaddr = 23'(is64Kmapper ? {(bankRegsSubSlot1[page[1:0]] + offsetReg), addr[13:0]} : {(bankRegsSubSlot1[page[1:0]] + offsetReg), addr[12:0]});
wire [22:0] mfrsd_SDaddr  = 23'('h700000 + (bankRegsSubSlot3[page8kB[1:0]][6:0] << 13) + addr[12:0]);
wire SDrom = addr[15:14] == 2'b01 | addr[15:14] == 2'b10;

wire [24:0] mfrsd_addr;
wire        mfrsd_addr_valid;
assign {mfrsd_addr, mfrsd_addr_valid} = subSlot == 2'b00 ? {addr[13:0],1'b1}                  :
                                        subSlot == 2'b01 ? page >= 4 ? 26'd0               :
                                                                       {mfrsd_64Kaddr,1'b1}   :
                                        subSlot == 2'b10 ? 26'd0                              :
                                                           SDrom     ? {mfrsd_SDaddr,1'b1} :
                                                                       26'd0                  ;

wire mfrsd_oe = mapper_en & rd & mreq;

wire sd_card_en = subSlot3_en & bankRegsSubSlot3[0][7:6] == 2'b01 & addr[15:13] == 3'b010; // 4000 - 5FFF
wire sdcard_oe  = sd_card_en & mreq & rd;

logic sd_rx, sd_tx;
always @(posedge clk) begin
   logic old_wr, old_rd, select_sd = 0;
   sd_rx <= 1'b0;
   sd_tx <= 1'b0;
   if (~old_rd & mreq & rd) sd_rx <= ~select_sd & addr[12];
   if (~old_wr & mreq & wr) begin
      if (addr[15:11] == 5'b01011) // >= 5800
         select_sd <= d_from_cpu[0];
      else
         sd_tx <= ~select_sd & addr[12];
   end
   old_rd <= rd;
   old_wr <= wr;
end

// SPI
wire [7:0] d_from_sd;
spi_divmmc spi
(
   .clk_sys(clk),
   .tx(sd_tx),
   .rx(sd_rx),
   .din(d_from_cpu),
   .dout(d_from_sd),
   .ready(),

   .spi_ce(1'b1),
   .spi_clk(spi_clk),
   .spi_di(spi_di),
   .spi_do(spi_do)
);

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

// SPI module
module spi_divmmc
(
	input        clk_sys,
	output       ready,

	input        tx,        // Byte ready to be transmitted
	input        rx,        // request to read one byte
	input  [7:0] din,
	output [7:0] dout,

	input        spi_ce,
	output       spi_clk,
	input        spi_di,
	output       spi_do
);

assign    ready   = counter[4];
assign    spi_clk = counter[0];
assign    spi_do  = io_byte[7]; // data is shifted up during transfer
assign    dout    = data;

reg [4:0] counter = 5'b10000;  // tx/rx counter is idle
reg [7:0] io_byte, data;

always @(posedge clk_sys) begin
	if(counter[4]) begin
		if(rx | tx) begin
			counter <= 0;
			data    <= io_byte;
			io_byte <= tx ? din : 8'hff;
		end
	end
	else if (spi_ce) begin
		if(spi_clk) io_byte <= { io_byte[6:0], spi_di };
		counter <= counter + 2'd1;
	end
end

endmodule