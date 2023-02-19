module msx_download
(
   input                       clk,
   input                       clk_en,
   input                       reset,
   input                       rom_eject,
   output                      need_reset,
   output                      msx_type,
   input MSX::config_cart_t    cart_conf[2],
   //IOCTL
   input                       ioctl_download,
   input                [15:0] ioctl_index,
   input                [26:0] ioctl_addr,
   //DDR3
   output         logic [27:0] ddr3_addr,
   output                      ddr3_rd,
   output                      ddr3_wr,
   input                 [7:0] ddr3_dout,
   output                [7:0] ddr3_din,
   input                       ddr3_ready,
   output                      ddr3_request,
   //SDRAM
   output               [24:0] sdram_addr,
   output                [7:0] sdram_din,
   output                      sdram_we,
   output                      sdram_rd,
   input                       sdram_ready,
   input                 [7:0] sdram_dout,
   //SD FDC
   input                       img_mounted,
   input                [31:0] img_size,
   input                       img_readonly,
   output               [31:0] fdc_sd_lba,
   output                      fdc_sd_rd,
   output                      fdc_sd_wr,
   input                       fdc_sd_ack,
   input                 [8:0] fdc_sd_buff_addr,
   input                 [7:0] fdc_sd_buff_dout,
   output                [7:0] fdc_sd_buff_din,
   input                       fdc_sd_buff_wr,
      
   //Memory 2
   input                [15:0] mem2_addr,
   input                 [7:0] mem2_din,
   output                [7:0] mem2_dout,   
   input                       mem2_wren,
   input                       mem2_rden,
   input                 [7:0] mem2_ram_bank,
   input                 [1:0] active_slot,
//   input                 [3:0] SLTSL_n,

   output                [3:0] debug_block_id,
   output                [1:0] debug_block_offset,
   output               [24:0] debug_offset,
   output                [1:0] debug_typ, 
   output                [1:0] debug_active_subslot,
   output                [1:0] debug_active_block,
   output                      debug_block_init,
   output           slot_typ_t debug_slot_typ,
   output                      debug_missmas
);


localparam MAX_MEM_BLOCK = 16;
MSX::block_t memory_block[MAX_MEM_BLOCK];
MSX::slot_t msx_slot[4];
MSX::rom_info_t rom_info[2];

wire        dw_sdram_upload;
wire        dw_sdram_we;
wire [24:0] dw_sdram_addr;
wire  [7:0] dw_sdram_din;

download download
(
   .sdram_addr(dw_sdram_addr),
   .sdram_din(dw_sdram_din),
   .sdram_we(dw_sdram_we),
   .sdram_request(dw_sdram_upload),
   .*
);

logic [7:0] mapper_slot[4];
logic mapper_en;

assign mapper_en = (mem2_addr == 16'hFFFF & msx_slot[active_slot].typ == SLOT_TYP_MAPPER);

always @(posedge reset, posedge clk) begin
   if (reset) begin
      mapper_slot[0] <= 8'h00;
      mapper_slot[1] <= 8'h00;
      mapper_slot[2] <= 8'h00;
      mapper_slot[3] <= 8'h00;
   end else begin
      if (mapper_en & mem2_wren)
         mapper_slot[active_slot] <= mem2_din;
   end
end

//Memory mapping
wire  [1:0] active_subslot, active_block;

assign {active_subslot, active_block}  = msx_slot[active_slot].typ == SLOT_TYP_CART_A ? 4'd0                                                  :
                                         msx_slot[active_slot].typ == SLOT_TYP_CART_B ? 4'd0                                                  :
                                         msx_slot[active_slot].typ != SLOT_TYP_MAPPER     ? {2'd0, mem2_addr[15:14]}                          :
                                         mem2_addr[15:14] == 2'b00                        ? {mapper_slot[active_slot][1:0], mem2_addr[15:14]} :
                                         mem2_addr[15:14] == 2'b01                        ? {mapper_slot[active_slot][3:2], mem2_addr[15:14]} :
                                         mem2_addr[15:14] == 2'b10                        ? {mapper_slot[active_slot][5:4], mem2_addr[15:14]} :
                                                                                            {mapper_slot[active_slot][7:6], mem2_addr[15:14]} ;

wire  [3:0] block_id       = msx_slot[active_slot].subslot[active_subslot].block[active_block].block_id;
wire  [1:0] block_offset   = msx_slot[active_slot].subslot[active_subslot].block[active_block].offset;
wire        block_init     = msx_slot[active_slot].subslot[active_subslot].block[active_block].init;
wire [24:0] offset         = memory_block[block_id].mem_offset;
wire        cpu_we         = memory_block[block_id].typ == BLOCK_TYP_RAM & mem2_wren & block_init;
wire [24:0] cpu_addr       = offset + (memory_block[block_id].typ == BLOCK_TYP_RAM & ~msx_type    ? {mem2_ram_bank, mem2_addr[13:0]} : 
                                       msx_slot[active_slot].typ == SLOT_TYP_CART_A               ? mem_cart_rom                     :                                 
                                       msx_slot[active_slot].typ == SLOT_TYP_CART_B               ? mem_cart_rom                     :                                
                                                                                                    {block_offset, mem2_addr[13:0]}) ;



assign debug_block_id = block_id;
assign debug_block_offset = block_offset;
assign debug_offset = offset;
assign debug_typ = memory_block[block_id].typ;
assign debug_active_subslot = active_subslot;
assign debug_active_block = active_block;
assign debug_block_init = block_init;
assign debug_slot_typ = msx_slot[active_slot].typ;

assign ram_addr   = dw_sdram_upload ? dw_sdram_addr[16:0] : cpu_addr[16:0];
assign sdram_addr = dw_sdram_upload ? dw_sdram_addr       : cpu_addr;
assign sdram_din  = dw_sdram_upload ? dw_sdram_din        : mem2_din;
assign sdram_we   = dw_sdram_upload ? dw_sdram_we         : cpu_we & ~ mapper_en;
assign sdram_rd   = dw_sdram_upload ? 1'b0                : mem2_rden;
assign mem2_dout  = FDC_output_en   ? d_to_cpu_FDC              :
                    mapper_en       ? ~mapper_slot[active_slot] :
                    //block_init    ? ram_dout     :
                    block_init    ? sdram_dout                  :
                                    8'hFF                       ;

assign debug_missmas = ram_addr[16:0] < 17'h18000 & mem2_rden & sdram_ready & ram_dout != sdram_dout & ~dw_sdram_upload;

wire [16:0] ram_addr;
wire [7:0] ram_dout;
spram #(.addr_width(17), .mem_name("TEST")) BIOS
(
   .clock(clk),
   .address(ram_addr),
   .q(ram_dout),
   .data(dw_sdram_upload ? dw_sdram_din : mem2_din), 
   .wren(dw_sdram_upload ? dw_sdram_we  : sdram_we)            
);

wire FDC_output_en;
wire [7:0] d_to_cpu_FDC;
fdc fdc
(
   .clk(clk),
   .reset(reset),
   .clk_en(clk_en),
   .cs(memory_block[block_id].typ == BLOCK_TYP_FDC),
   .addr(mem2_addr[13:0]),
   .d_from_cpu(mem2_din),
   .d_to_cpu(d_to_cpu_FDC),
   .output_en(FDC_output_en),
   .rd(mem2_rden),
   .wr(mem2_wren),
   .img_mounted(img_mounted),
   .img_size(img_size),
   .img_readonly(img_readonly),
   .sd_lba(fdc_sd_lba),
   .sd_rd(fdc_sd_rd),
   .sd_wr(fdc_sd_wr),
   .sd_ack(fdc_sd_ack),
   .sd_buff_addr(fdc_sd_buff_addr),
   .sd_buff_dout(fdc_sd_buff_dout),
   .sd_buff_din(fdc_sd_buff_din),
   .sd_buff_wr(fdc_sd_buff_wr)
);

wire CARTROM_output_en;
wire  [7:0] d_to_cpu_CARTROM;
wire [24:0] mem_cart_rom;
cart_rom cart_rom
(
   .clk(clk),
   .clk_en(clk_en),
   .reset(reset),
   .addr(mem2_addr),
   .d_from_cpu(mem2_din),
   .d_to_cpu(d_to_cpu_CARTROM),
   .rd(mem2_rden),
   .wr(mem2_wren),
   //.output_en(CARTROM_output_en),
   .mapper(rom_info[msx_slot[active_slot].typ == SLOT_TYP_CART_A ? 0 : 1].mapper),
   .rom_offset(rom_info[msx_slot[active_slot].typ == SLOT_TYP_CART_A ? 0 : 1].offset),
   .rom_size(rom_info[msx_slot[active_slot].typ == SLOT_TYP_CART_A ? 0 : 1].size),
   .mem_addr(mem_cart_rom)
);

endmodule