module msx_slots
(
   input                       clk,
   input                       clk_en,
   input                       reset,
   input                       rom_eject,
   input                       cart_changed,
   output                      need_reset,
   input                       sram_save,
   input                       sram_load,
   output                      msx_type,
   input MSX::config_cart_t    cart_conf[2],
   //CPU                
   input                [15:0] cpu_addr,
   input                 [7:0] cpu_dout,
   output                [7:0] cpu_din,
   input                       cpu_wr,
   input                       cpu_rd,
   input                       cpu_mreq,
   input                       cpu_iorq,
   input                       cpu_m1,

   output signed        [15:0] sound,
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
   input                 [1:0] sdram_size,
   //SD FDC
   input                 [5:0] img_mounted,
   input                [31:0] img_size,
   input                       img_readonly,

   output               [31:0] sd_lba[6],
   output                [5:0] sd_rd,
   output                [5:0] sd_wr,
   input                 [5:0] sd_ack,
   input                [13:0] sd_buff_addr,
   input                 [7:0] sd_buff_dout,
   output                [7:0] sd_buff_din[6],
   input                       sd_buff_wr,

   input                 [1:0] active_slot,

   output                [3:0] debug_block_id,
   output                [1:0] debug_block_offset,
   output               [24:0] debug_offset,
   output                [1:0] debug_typ, 
   output                [1:0] debug_active_subslot,
   output                [1:0] debug_active_block,
   output                      debug_block_init,
   output                      debug_cpuWE_typ,
   output                      debug_cpuWE2,
   output           slot_typ_t debug_slot_typ,
   output                      debug_slot_id,
   output               [24:0] debug_sram_offset1,
   output               [24:0] debug_sram_offset2
);

//Unused port
assign sd_lba[0]      = 0;
assign sd_rd[0]       = 1'b0;
assign sd_wr[0]       = 1'b0;
assign sd_buff_din[0] = 8'h00;

localparam MAX_MEM_BLOCK = 16;
MSX::block_t memory_block[MAX_MEM_BLOCK];
MSX::sram_block_t sram_block[2];
MSX::slot_t msx_slot[4];
MSX::rom_info_t rom_info[2];


assign debug_sram_offset1 = sram_block[0].mem_offset;
assign debug_sram_offset2 = sram_block[1].mem_offset;


wire [12:0] ram_lba;
wire [24:0] ram_offset;
wire        ram_format, ram_we;

nvram_backup nvram_backup
(
   .img_mounted(img_mounted[4:1]),
   .img_readonly(img_readonly),
   .img_size(img_size),
   .save_req({2'b00,sram_save,1'b0}),
   .load_req({2'b00,sram_load,1'b0}),
   .sd_lba(sd_lba[1:4]),
   .sd_rd(sd_rd[4:1]),
   .sd_wr(sd_wr[4:1]),
   .sd_ack(sd_ack[4:1]),
   .ram_lba(ram_lba),
   .ram_offset(ram_offset),
   .ram_format(ram_format),
   .ram_we(ram_we),
   .debug_size(),
   .debug_lba_start(),
   .debug_block_count(),
   .debug_lba_start_to_init(),
   .debug_init_count(),
   .*
);


wire        dw_sdram_upload;
wire        dw_sdram_we;
wire [24:0] dw_sdram_addr;
wire  [7:0] dw_sdram_din;
wire  [7:0] ram_block_count;
wire [24:0] dw_bram_addr;
wire  [7:0] dw_bram_din;
wire        dw_bram_we;
wire        dw_bram_upload;
download download
(
   .sdram_addr(dw_sdram_addr),
   .sdram_din(dw_sdram_din),
   .sdram_we(dw_sdram_we),
   .sdram_request(dw_sdram_upload),
   .bram_addr(dw_bram_addr),
   .bram_din(dw_bram_din),
   .bram_we(dw_bram_we),
   .bram_request(dw_bram_upload),
   .*
);

logic [7:0] mapper_slot[4];
logic mapper_en;

assign mapper_en = (cpu_addr == 16'hFFFF & msx_slot[active_slot].typ == SLOT_TYP_MAPPER);

always @(posedge reset, posedge clk) begin
   if (reset) begin
      mapper_slot[0] <= 8'h00;
      mapper_slot[1] <= 8'h00;
      mapper_slot[2] <= 8'h00;
      mapper_slot[3] <= 8'h00;
   end else begin
      if (mapper_en & cpu_wr & cpu_mreq)
         mapper_slot[active_slot] <= cpu_dout;
   end
end

//Memory mapping
wire  [1:0] active_subslot, active_block, block_offset;
wire  [3:0] block_id;
wire [24:0] mem_addr, offset;
wire        slot_id, block_init, cpu_we;
slot_typ_t  slot_typ;

assign {active_subslot, active_block}  = msx_slot[active_slot].typ == SLOT_TYP_CART_A ? 4'd0                                                 :
                                         msx_slot[active_slot].typ == SLOT_TYP_CART_B ? 4'd0                                                 :
                                         msx_slot[active_slot].typ != SLOT_TYP_MAPPER     ? {2'd0, cpu_addr[15:14]}                          :
                                         cpu_addr[15:14] == 2'b00                         ? {mapper_slot[active_slot][1:0], cpu_addr[15:14]} :
                                         cpu_addr[15:14] == 2'b01                         ? {mapper_slot[active_slot][3:2], cpu_addr[15:14]} :
                                         cpu_addr[15:14] == 2'b10                         ? {mapper_slot[active_slot][5:4], cpu_addr[15:14]} :
                                                                                            {mapper_slot[active_slot][7:6], cpu_addr[15:14]} ;

assign slot_typ     = msx_slot[active_slot].typ != SLOT_TYP_MAPPER ? msx_slot[active_slot].typ : msx_slot[active_slot].subslot[active_subslot].typ;
assign slot_id      = slot_typ == SLOT_TYP_CART_B;
assign block_id     = msx_slot[active_slot].subslot[active_subslot].block[active_block].block_id;
assign block_offset = msx_slot[active_slot].subslot[active_subslot].block[active_block].offset;
assign block_init   = msx_slot[active_slot].subslot[active_subslot].block[active_block].init;
assign offset       = sram_oe ? sram_block[slot_id].mem_offset : memory_block[block_id].mem_offset;
assign cpu_we       = (slot_typ == SLOT_TYP_RAM | slot_typ == SLOT_TYP_MSX2_RAM) & cpu_wr & cpu_mreq & block_init;
assign mem_addr     = offset + (slot_typ == SLOT_TYP_RAM      ? {block_offset, cpu_addr[13:0]}  : 
                                slot_typ == SLOT_TYP_MSX2_RAM ? {msx2_ram_bank, cpu_addr[13:0]}      :
                                slot_typ == SLOT_TYP_CART_A   ? mem_cart_rom                    :
                                slot_typ == SLOT_TYP_CART_B   ? mem_cart_rom                    :
                                                               {block_offset, cpu_addr[13:0]})  ;
                                                                                                    
assign debug_block_id = block_id;
assign debug_block_offset = block_offset;
assign debug_offset = offset;
assign debug_typ = memory_block[block_id].typ;
assign debug_active_subslot = active_subslot;
assign debug_active_block = active_block;
assign debug_block_init = block_init;
assign debug_slot_typ = slot_typ;
assign debug_cpuWE_typ = (slot_typ == SLOT_TYP_RAM | slot_typ == SLOT_TYP_MSX2_RAM);
assign debug_cpuWE2 = (slot_typ == SLOT_TYP_RAM | slot_typ == SLOT_TYP_MSX2_RAM) & cpu_wr & cpu_mreq & block_init;
assign debug_slot_id = slot_id;

//assign ram_addr   = dw_sdram_upload ? dw_sdram_addr[16:0] : mem_addr[16:0];
assign sdram_addr = dw_sdram_upload ? dw_sdram_addr       : mem_addr;
assign sdram_din  = dw_sdram_upload ? dw_sdram_din        : cpu_dout;
assign sdram_we   = dw_sdram_upload ? dw_sdram_we         : cpu_we & ~mapper_en & ~sram_oe;
assign sdram_rd   = dw_sdram_upload ? 1'b0                : cpu_rd & cpu_mreq;
assign cpu_din    = FDC_output_en   ? d_to_cpu_FDC                              :
                    msx2_mapper_req ? msx2_mapper_dout                          :
                    mapper_en       ? ~mapper_slot[active_slot]                 :
                    sram_oe         ? bram_dout                                 :
                    //block_init    ? bram_dout                                 :
                    block_init    ? sdram_dout                                  :
                                    8'hFF                                       ;

assign      bram_addr = mem_addr[16:0];
assign      bram_we   = sram_we;
wire [16:0] bram_addr;
wire  [7:0] bram_dout;
wire        bram_we;

wire   [7:0] sram_dout;

assign sd_buff_din[1] = ram_format ? 8'hFF : sram_dout; //MSX
assign sd_buff_din[2] = ram_format ? 8'hFF : sram_dout; //CART NVRAM
assign sd_buff_din[3] = ram_format ? 8'hFF : sram_dout; //ROM A NVRAM
assign sd_buff_din[4] = ram_format ? 8'hFF : sram_dout; //ROM_B NVRAM

dpram #(.addr_width(18)) SRAM
(
   .clock(clk),
   .address_a(dw_bram_upload ? dw_bram_addr[16:0] : bram_addr),
   .q_a(bram_dout),
   .data_a(dw_bram_upload ? dw_bram_din : cpu_dout), 
   .wren_a(dw_bram_upload ? dw_bram_we  : bram_we),          

   .address_b(ram_offset + {ram_lba[8:0],sd_buff_addr[8:0]}),
   .data_b(sd_buff_dout),
   .q_b(sram_dout),
   .wren_b(sd_buff_wr & sd_buff_addr[13:9] == 0 & ram_we ) 
);

wire FDC_output_en;
wire [7:0] d_to_cpu_FDC;
fdc fdc
(
   .clk(clk),
   .reset(reset),
   .clk_en(clk_en),
   .cs(memory_block[block_id].typ == BLOCK_TYP_FDC),
   .addr(cpu_addr[13:0]),
   .d_from_cpu(cpu_dout),
   .d_to_cpu(d_to_cpu_FDC),
   .output_en(FDC_output_en),
   .rd(cpu_rd & cpu_mreq),
   .wr(cpu_wr & cpu_mreq),
   .img_mounted(img_mounted[5]),
   .img_size(img_size),
   .img_readonly(img_readonly),
   .sd_lba(sd_lba[5]),
   .sd_rd(sd_rd[5]),
   .sd_wr(sd_wr[5]),
   .sd_ack(sd_ack[5]),
   .sd_buff_addr(sd_buff_addr),
   .sd_buff_dout(sd_buff_dout),
   .sd_buff_din(sd_buff_din[5]),
   .sd_buff_wr(sd_buff_wr)
);

wire CARTROM_output_en;
wire  [7:0] d_to_cpu_CARTROM;
wire [24:0] mem_cart_rom;
wire        sram_oe, sram_we;
cart_rom cart_rom
(
   .clk(clk),
   .clk_en(clk_en),
   .reset(reset),
   .addr(cpu_addr),
   .d_from_cpu(cpu_dout),
   .d_to_cpu(d_to_cpu_CARTROM),
   .rd(cpu_rd),
   .wr(cpu_wr),
   .iorq(cpu_iorq),
   .mreq(cpu_mreq),
   .m1(cpu_m1),
   .en(slot_typ == SLOT_TYP_CART_A  | slot_typ == SLOT_TYP_CART_B),
   .slot(slot_id),
   .rom_info(rom_info),
   .cart_conf(cart_conf),
   .mem_addr(mem_cart_rom),
   .sram_oe(sram_oe),
   .sram_we(sram_we),
   .sound(sound)
);

wire [7:0] msx2_ram_bank, msx2_mapper_dout;
wire       msx2_mapper_req;
msx2_ram_mapper msx2_ram_mapper
(
   .ram_bank(msx2_ram_bank),
   .mapper_dout(msx2_mapper_dout),
   .mapper_req(msx2_mapper_req),
   .*
);
/*
//Mapper MSX2 RAM
wire mpr_en = (cpu_addr[7:2] == 6'b111111)   & cpu_iorq & ~cpu_m1;
wire mpr_wr = mpr_en & cpu_wr;
wire [7:0] ram_bank = mem_seg[cpu_addr[15:14]];
reg [7:0] mem_seg [0:3];
always @( posedge reset, posedge clk ) begin
   if (reset) begin
      mem_seg[0] <= 3;
      mem_seg[1] <= 2;
      mem_seg[2] <= 1;
      mem_seg[3] <= 0;
   end else if (mpr_wr)
      mem_seg[cpu_addr[1:0]] <= cpu_dout & (ram_block_count-1'b1);
end
*/
endmodule