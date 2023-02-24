module msx_memory
(
   input             clk,
   input             clk_sdram,
   input             reset,
   output            reset_req,
   input             sram_write,
   input             sram_load,
   input       [2:0] sram_size[2],
   input       [1:0] sdram_size,
   input       [1:0] cart_changed,
   //Memory
   input      [24:0] mem_addr[8],
   input       [7:0] mem_data[8],
   input       [7:0] mem_wren,
   input       [7:0] mem_rden,
   output      [7:0] mem_q[8],

   input MSX::slot_t slot[4],
   input MSX::block_t        block_config[16],
   //input MSX::fw_blocks_t     fw_blocks,
    // SD config
	input       [2:0] img_mounted,  // signaling that new image has been mounted
	input             img_readonly, // mounted as read only. valid only for active bit in img_mounted
	input      [63:0] img_size,     // size of image in bytes. valid only for active bit in img_mounted
	// SD block level access
	output     [31:0] sd_lba[3],
	output reg  [2:0] sd_rd = 3'd0,
	output reg  [2:0] sd_wr = 3'd0,
	input       [2:0] sd_ack,
	// SD byte level access. Signals for 2-PORT altsyncram.
	input      [13:0] sd_buff_addr,
	input       [7:0] sd_buff_dout,
	output      [7:0] sd_buff_din[3],
	input             sd_buff_wr,
   // IMAGE handle
   input             ioctl_download,
   input      [15:0] ioctl_index,
   input             ioctl_wr,
   input      [26:0] ioctl_addr,
   input       [7:0] ioctl_dout,
   output            ioctl_wait,
   input       [1:0] rom_eject,
   //ROM info 
   output reg  [3:0] cart_rom_offset[2],
   output reg [24:0] cart_rom_size[2],
   output reg  [5:0] cart_rom_auto_mapper[2],
   output reg  [2:0] cart_sram_size[2],
   //SDRAM
   input             locked_sdram,
   output            SDRAM_CLK,
   output            SDRAM_CKE,
   output     [12:0] SDRAM_A,
   output      [1:0] SDRAM_BA,
   inout      [15:0] SDRAM_DQ,
   output            SDRAM_DQML,
   output            SDRAM_DQMH,
   output            SDRAM_nCS,
   output            SDRAM_nCAS,
   output            SDRAM_nRAS,
   output            SDRAM_nWE,

   input               [24:0] sdram_addr,
   input                [7:0] sdram_din,
   input                      sdram_we,
   input                      sdram_download,
   output                     sdram_ready
);


wire        is_ram_msx1 = 1'b1;

//wire  [1:0] sub_slot    = is_ram_msx1 ? 2'd0 : mem2_addr[15:14];

//MSX::block_t block;
//MSX::block_t root_block;
//assign block = block_config[slot[mem2_slot].subslot[sub_slot].block_id];
//assign root_block = block_config[slot[mem2_slot].subslot[0].block_id];

/*
assign     mem2_is_mem = block.typ      == BLOCK_TYP_ROM                               ? 1'b1 :
                         root_block.typ == BLOCK_TYP_RAM  ? 1'b1 : 
                         //& block_count >= mem2_addr[15:14]                             ? 1'b1 : 
                                                                                         1'b0 ;
*/

//assign     sdram_addr = block.mem_offset + mem2_addr; 

/*
assign     sdram_rd   = mem2_is_mem & mem2_rden;
assign     sdram_we   = mem2_is_mem & mem2_wren;
assign     sdram_din  = mem2_din;
assign     mem2_dout  = sdram_dout;
*/

//wire  [7:0] sdram_dout;
//wire  [7:0] sdram_din;
//wire [24:0] sdram_addr;
//wire        sdram_we;
//wire        sdram_rd;
//wire        sdram_ready;




   //input   [15:0] mem2_addr,
   //input    [1:0] mem2_block,
   //input    [1:0] mem2_slot,
   //input    [1:0] mem2_sub_slot,
   //input    [7:0] mem2_din,
   //output   [7:0] mem2_dout,   
   //input          mem2_wren,
   //input          mem2_rden,
   //output         mem2_is_mem,
   //input          memory_layout






/*

reg        image_mounted[3];
reg [14:0] image_size[3];
//reg        image_readonly[7];  
reg  [7:0] lba[3];
reg  [3:0] num = 4'd0;
reg  [7:0] loaded = 8'd0;
reg  [7:0] write_rq = 8'd0;
reg        old_ack  = 1'b0;

//IMAGE DOWNLOAD
wire       dw_fw, dw_rom, slot, dw_bios, dw_ext, dw_dsk, download; 
reg  [1:0] mem_enabled = 2'd0;
assign {download,dw_dsk,dw_ext,dw_bios,dw_fw,dw_rom,slot} = ~ioctl_download          ? 7'b0000000 :
                                                            ioctl_index[5:0] == 6'd1 ? 7'b1001000 :    //BIOS
                                                            ioctl_index[5:0] == 6'd2 ? 7'b1010000 :    //EXT
                                                            ioctl_index[5:0] == 6'd3 ? 7'b1100000 :    //DISK
                                                            ioctl_index[5:0] == 6'd6 ? 7'b1000010 :    //ROM A
                                                            ioctl_index[5:0] == 6'd7 ? 7'b1000011 :    //ROM B
                                                            ioctl_index[5:0] == 6'd8 ? 7'b1000100 :    //FW  A
                                                            ioctl_index[5:0] == 6'd9 ? 7'b1000101 :    //FW  B
                                                            ioctl_index[5:0] == 6'd0 ? ioctl_index[15:6] == 10'd0 ? 7'b1001000 : //BIOS
                                                                                       ioctl_index[15:6] == 10'd1 ? 7'b1010000 : //EXT
                                                                                       ioctl_index[15:6] == 10'd2 ? 7'b1100000 : //DISK
                                                                                                                    7'b0000000 :
                                                                                       7'b0000000 ;
always @(posedge clk) begin
   if (rom_eject[0])      mem_enabled[0]    <= 1'b0; 
   if (rom_eject[1])      mem_enabled[1]    <= 1'b0; 
   if (cart_changed[0])   mem_enabled[0]    <= 1'b0;
   if (cart_changed[1])   mem_enabled[1]    <= 1'b0;
   if (dw_fw | dw_rom)    mem_enabled[slot] <= 1'b1;
   if (mem_wren[MEM_FWA]) mem_enabled[0]    <= 1'b1;
   if (mem_wren[MEM_FWB]) mem_enabled[1]    <= 1'b1;
end 

always @(posedge clk) begin
reg last_dw_rom = 1'b0;
   if (last_dw_rom & ~dw_rom) begin
      cart_rom_offset[slot]      <= detect_offset;
      cart_rom_size[slot]        <= detect_rom_size;
      cart_rom_auto_mapper[slot] <= ioctl_index[15] ? ioctl_index[11:6] : detect_mapper;
      cart_sram_size[slot]       <= ioctl_index[15] ? ioctl_index[14:12] : 3'd0;
   end
   last_dw_rom <= dw_rom;
end 

assign reset_req = download;

// IMG HANDLING

genvar i;
generate 
   for (i=0; i < 3; i++) begin :generateMount
      always @(posedge clk) begin
         if (img_mounted[i]) begin
            image_size[i]     <= img_size[14:0];               //MAX 32kB
//            image_readonly[i] <= img_readonly;
            image_mounted[i]  <= img_size[63:15] == 0 & ~img_readonly; //Big file ignore.
         end
      end
   end
endgenerate 

wire [7:0] max_lba = sd_wr[num] ? (7'd1 << sram_size[num == IMG_SRAM_B ? 1 : 0])-8'd1 : (image_size[num][14:9])-8'd1 ;

always @(posedge clk) begin
   if (sd_wr == 0 & sd_rd == 0) begin                                         //Standby
      if ((image_mounted[num] & ~loaded[num]) | write_rq[num] ) begin         //request upload
         if (write_rq[num]) begin
            lba[num] <= 0;
            sd_wr[num]  <= 1'b1;
         end else begin
            if (image_size[num] > 0) begin
               lba[num] <= 0;
               sd_rd[num]  <= 1'b1;
            end else begin 
               loaded[num] <= 1'b1;                                           //mount empty sram file
            end
         end
      end else begin                                                          //not request
         if (num == 2) begin
            num = 4'd0;
         end else begin
            num = num + 1'b1;
         end
      end
end else begin                                                                //RD/RW state
      if (old_ack & ~sd_ack[num]) begin                                       //End cycle         
         if (lba[num] < max_lba) begin
            lba[num] <= lba[num] + 1'b1;                                      //Next block
         end else begin
            if (sd_wr[num]) begin
               write_rq[num] <= 1'b0;
               sd_wr[num] <= 1'b0;
            end else begin
               sd_rd[num] <= 1'b0;            
               loaded[num] <= 1'b1;
            end
         end             
      end
      old_ack <= sd_ack[num];  
   end
   if (~image_mounted[num] & loaded[num]) begin
      loaded[num] <= 1'b0;
   end
   if (sram_write) begin
      write_rq[0] = image_mounted[0] & sram_size[0] > 3'd0;
      write_rq[1] = image_mounted[1] & sram_size[0] > 3'd0;
      write_rq[2] = image_mounted[2] & sram_size[1] > 3'd0;
   end
   if (sram_load) begin
      loaded[0] = ~image_mounted[0];
      loaded[1] = ~image_mounted[1];
      loaded[2] = ~image_mounted[2];
   end 
end 

assign sd_lba = lba;
*/
/*
M
S
X
Machine type 0 - Not specific, 1 - MSX1,  2 - MSX2
Block Size block = 15kB
Type
slot
subslot
page start
reserva 8

Type 
00 RAM
01 BIOS to SLOT 
02 FW FM_PAC
03 FW GAMEMASTER2
04 FW FDC

#/bin/bash
printf "MSX\x02\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" > vg8240.msx
printf "MSX\x00\x02\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" >> vg8240.msx
cat msx2_bios.rom >> vg8240.msx
printf "MSX\x00\x01\x01\x03\x00\x00\x00\x00\x00\x00\x00\x00\x00" >> vg8240.msx
cat msx2_ext.rom >> vg8240.msx
printf "MSX\x00\x01\x01\x03\x03\x01\x00\x00\x00\x00\x00\x00\x00" >> vg8240.msx
cat msx2_disk.rom >> vg8240.msx
printf "MSX\x00\x04\x02\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" >> vg8240.msx
cat FMPAC.ROM >> vg8240.msx
printf "MSX\x00\x08\x03\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" >> vg8240.msx
cat KONAMIGM2.rom >> vg8240.msx
*/

/*
                   0      1      2     3
SDRAM SIZE       0Mbit  32 Mb  64 Mb  128Mb
                         4 MB   8 MB  16 MB
SDRAM  RAM       -----    1MB    2MB    4MB
SDRAM  ROM/FW_A  -----    1MB    2MB    4MB
SDRAM  ROM/FW_B  -----    2MB    4MB    4MB
BRAM   ROM/FW_A  128kB  -----  -----  -----
BRAM   ROM/FW_B   64kB  -----  -----  -----
BRAM   RAM        64kB  -----  -----  -----
BRAM   SRAM_A      8kB   32kB   32kB   32kB  
BRAM   SRAM_B      8kB    8kB    8kB    8kB
*/
/*
wire [5:0] maskRAM, maskROMA, maskROMB;
wire [7:0] bankRAM, bankROMA, bankROMB;
wire       overflow;

//[21:16]
assign {maskRAM, maskROMA, maskROMB} = sdram_size == 2'd1 ? {6'b001111, 6'b001111, 6'b011111} :
                                       sdram_size == 2'd2 ? {6'b011111, 6'b011111, 6'b111111} :
                                       sdram_size == 2'd3 ? {6'b111111, 6'b111111, 6'b111111} :
                                                            {6'b000000, 6'b000001, 6'b000000} ;
//[23:16]
assign {bankRAM, bankROMA, bankROMB} = sdram_size == 2'd1 ? {8'h00, 8'h10, 8'h20} :
                                       sdram_size == 2'd2 ? {8'h00, 8'h20, 8'h40} :
                                                            {8'h00, 8'h40, 8'h80} ;

assign {overflow, sdram_addr} = (dw_fw | dw_rom) & ~slot                ? {(ioctl_addr[21:16]        & ~maskROMA) != 0, bankROMA | ioctl_addr[23:16], ioctl_addr[15:0]}               :
                                (dw_fw | dw_rom) &  slot                ? {(ioctl_addr[21:16]        & ~maskROMB) != 0, bankROMB | ioctl_addr[23:16], ioctl_addr[15:0]}               :
                                mem_rden[MEM_RAM] | mem_wren[MEM_RAM]   ? {(mem_addr[MEM_RAM][21:16] & ~maskRAM ) != 0, bankRAM  | mem_addr[MEM_RAM][23:16], mem_addr[MEM_RAM][15:0]} :
                                mem_rden[MEM_FWA] | mem_wren[MEM_FWA]   ? {(mem_addr[MEM_FWA][21:16] & ~maskROMA) != 0, bankROMA | mem_addr[MEM_FWA][23:16], mem_addr[MEM_FWA][15:0]} :
                                                                          {(mem_addr[MEM_FWB][21:16] & ~maskROMB) != 0, bankROMB | mem_addr[MEM_FWB][23:16], mem_addr[MEM_FWB][15:0]} ;                                                                        

assign sdram_din  =             (dw_fw | dw_rom)                      ? ioctl_dout                                                :
                                mem_wren[MEM_RAM]                     ? mem_data[MEM_RAM]                                         :
                                mem_wren[MEM_FWA]                     ? mem_data[MEM_FWA]                                         :
                                mem_wren[MEM_FWB]                     ? mem_data[MEM_FWB]                                         :
                                                                        8'hFF                                                     ;

assign sdram_we   =             overflow                              ? 1'b0                                                      :
                                (dw_fw | dw_rom)                      ? ioctl_wr                                                  :
                                                                        mem_wren[MEM_RAM] | mem_wren[MEM_FWA] | mem_wren[MEM_FWB] ; 

assign sdram_rd   =             overflow                              ? 1'b0                                                      :
                                (dw_fw | dw_rom)                      ? 1'b0                                                      :
                                                                        mem_rden[MEM_RAM] | mem_rden[MEM_FWA] | mem_rden[MEM_FWB] ;

assign ioctl_wait = ~sdram_ready & download & ~overflow & sdram_size > 2'd0 ;

//BRAM
assign sd_buff_din[0] = sdram_size == 2'd0 ? srama_q : srama_q2;
assign sd_buff_din[1] = sdram_size == 2'd0 ? srama_q : srama_q2;
assign sd_buff_din[2] = sramb_q;

assign mem_q[MEM_RAM] = overflow                               ? 8'hFF      :
                        sdram_size > 2'd0 & mem_rden[MEM_RAM]  ? sdram_dout :
                        mem_rden[MEM_RAM]                      ? ram_q      :
                                                                 8'hFF      ;

assign mem_q[MEM_FWA] = overflow                               ? 8'hFF      :
                        ~mem_enabled[0] | ~mem_rden[MEM_FWA]   ? 8'hFF      :
                        sdram_size > 2'd0                      ? sdram_dout :
                                                                 fwa_q      ;
assign mem_q[MEM_FWB] = overflow                               ? 8'hFF      :
                        ~mem_enabled[1] | ~mem_rden[MEM_FWB]   ? 8'hFF      :
                        sdram_size > 2'd0                      ? sdram_dout :
                                                                 fwb_q      ; 

assign mem_q[MEM_SRAMA] = sdram_size == 2'd0                   ? mem_srama_q:
                                                                 fwa_q      ;

wire  [3:0] detect_offset;
wire [24:0] detect_rom_size;
wire  [5:0] detect_mapper;
rom_detect rom_detect
(
    .clk(clk),
    .ioctl_isROM(dw_rom),
    .mapper(detect_mapper),
    .offset(detect_offset),
    .rom_size(detect_rom_size),
    .*
);

localparam BIOS_WIDTH = 15;
spram #(.addr_width(BIOS_WIDTH), .mem_name("BIOS")) BIOS
(
   .clock(clk),
   .address(dw_bios ? ioctl_addr[BIOS_WIDTH-1:0] : mem_addr[MEM_BIOS][BIOS_WIDTH-1:0]),
   .q(mem_q[MEM_BIOS]),
   .data(ioctl_dout), 
   .wren(ioctl_wr & dw_bios & ioctl_addr[26:BIOS_WIDTH] == 0)            
);

localparam EXT_WIDTH = 14;
spram #(.addr_width(EXT_WIDTH), .mem_name("EXT")) EXT
(
   .clock(clk),
   .address(dw_ext ? ioctl_addr[EXT_WIDTH-1:0] : mem_addr[MEM_EXT][EXT_WIDTH-1:0]),
   .q(mem_q[MEM_EXT]),
   .data(ioctl_dout), 
   .wren(ioctl_wr & dw_ext & ioctl_addr[26:EXT_WIDTH] == 0) 
);

localparam DSK_WIDTH = 14;
wire [7:0] dsk_q_tmp;
wire disk_overflow = mem_addr[MEM_DSK][24:DSK_WIDTH] != 0;
assign mem_q[MEM_DSK] = disk_overflow ? 8'hFF : dsk_q_tmp;
spram #(.addr_width(DSK_WIDTH), .mem_name("DSK")) DSK
(
   .clock(clk),
   .address(dw_dsk ? ioctl_addr[DSK_WIDTH-1:0] : mem_addr[MEM_DSK][DSK_WIDTH-1:0]),
   .q(dsk_q_tmp),
   .data(ioctl_dout), 
   .wren(ioctl_wr & dw_dsk & ioctl_addr[26:DSK_WIDTH] == 0) 
);

localparam RAM_WIDTH = 16;
wire [7:0] ram_q, ram_q_tmp;                          
wire ram_overflow = mem_addr[MEM_RAM][24:RAM_WIDTH] != 0;
assign ram_q  = ram_overflow ? 8'hFF : ram_q_tmp;
spram #(.addr_width(RAM_WIDTH), .mem_name("RAM")) RAM
(
   .clock(clk),
   .address (mem_addr[MEM_RAM][RAM_WIDTH-1:0]),
   .q(ram_q_tmp),
   .data(mem_data[MEM_RAM]),
   .wren(mem_wren[MEM_RAM])
);

localparam FWA_WIDTH = 17;
wire [7:0] fwa_q;
spram #(.addr_width(FWA_WIDTH), .mem_name("FWA")) FWA
(
   .clock(clk),
   .address((dw_fw | dw_rom) & ~slot ? ioctl_addr[FWA_WIDTH-1:0] : mem_addr[MEM_FWA][FWA_WIDTH-1:0]),
   .q(fwa_q),
   .data((dw_fw | dw_rom) & ~slot ? ioctl_dout : mem_data[MEM_FWA]),
   .wren((dw_fw | dw_rom) & ~slot ? ioctl_wr & ioctl_addr[26:FWA_WIDTH] == 0 : mem_wren[MEM_FWA])
);

localparam FWB_WIDTH = 16;
wire [7:0] fwb_q, srama_q2;
dpram #(.addr_width(FWB_WIDTH)) FWB
(
   .clock(clk),
   .address_a(sdram_size == 2'd0 ? ioctl_addr[FWB_WIDTH-1:0] : {sd_lba[num][FWB_WIDTH-10:0], sd_buff_addr[8:0]}),
   .q_a(srama_q2),
   .data_a(sdram_size == 2'd0 ? ioctl_dout : sd_buff_dout),
   .wren_a(sdram_size == 2'd0 ? (dw_fw | dw_rom) & slot & ioctl_wr & ioctl_addr[26:FWB_WIDTH] == 0 : sd_buff_wr & (sd_rd[IMG_SRAM] | sd_rd[IMG_SRAM_A] ) & sd_buff_addr[13:9] == 0 & lba[num][7:FWB_WIDTH - 9] == 0),
   .address_b(sdram_size == 2'd0 ? mem_addr[MEM_FWB][FWB_WIDTH-1:0] : mem_addr[MEM_SRAMA][FWB_WIDTH-1:0]),
   .q_b(fwb_q),
   .data_b(sdram_size == 2'd0 ? mem_data[MEM_FWB] : mem_data[MEM_SRAMA]),
   .wren_b(sdram_size == 2'd0 ? mem_wren[MEM_FWB] & ~((dw_fw | dw_rom) & slot) : mem_wren[MEM_SRAMA])
);

localparam SRAMA_WIDTH = 13;
wire [7:0] srama_q, mem_srama_q;
dpram #(.addr_width(SRAMA_WIDTH)) SRAMA
(  
   .clock(clk),
   .address_a({sd_lba[num][SRAMA_WIDTH-10:0], sd_buff_addr[8:0]}),
   .q_a(srama_q),
   .data_a(sd_buff_dout),
   .wren_a(sd_buff_wr & (sd_rd[IMG_SRAM] | sd_rd[IMG_SRAM_A] ) & sd_buff_addr[13:9] == 0 & lba[num][7:SRAMA_WIDTH - 9] == 0),  
   .address_b(mem_addr[MEM_SRAMA][SRAMA_WIDTH-1:0]),
   .q_b(mem_srama_q),
   .data_b(mem_data[MEM_SRAMA]),
   .wren_b(mem_wren[MEM_SRAMA])
);

localparam SRAMB_WIDTH = 13;
wire [7:0] sramb_q;
dpram #(.addr_width(SRAMB_WIDTH)) SRAMB
(  
   .clock(clk),
   .address_a({sd_lba[num][SRAMB_WIDTH-10:0], sd_buff_addr[8:0]}),
   .q_a(sramb_q),
   .data_a(sd_buff_dout),
   .wren_a(sd_buff_wr & sd_rd[2] & sd_buff_addr[13:9] == 0 & lba[num][7:SRAMB_WIDTH - 9] == 0),  
   .address_b(mem_addr[MEM_SRAMB][SRAMB_WIDTH-1:0]),
   .q_b(mem_q[MEM_SRAMB]),
   .data_b(mem_data[MEM_SRAMB]),
   .wren_b(mem_wren[MEM_SRAMB])
);
*/
/////////////////  SDRAM  /////////////////////////
wire  [7:0] sdram_dout;
//wire  [7:0] sdram_din;
//wire [24:0] sdram_addr;
//wire        sdram_we;
wire        sdram_rd;
//wire        sdram_ready;

sdram sdram
(
    .init(~locked_sdram),
    .clk(clk_sdram),
    .dout(sdram_dout),
    .din (sdram_din),
    .addr(sdram_addr),
    .we(sdram_we),
    .rd(sdram_rd),
    .ready(sdram_ready),
    .*
);

endmodule