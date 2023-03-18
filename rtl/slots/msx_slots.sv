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
   //KBD LAYOUT
   output                [9:0] kbd_addr,
   output                [7:0] kbd_din,
   output                      kbd_we,
   output                      kbd_request,
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

   input                 [1:0] active_slot
);

//Unused port
assign sd_lba[0]      = 0;
assign sd_rd[0]       = 1'b0;
assign sd_wr[0]       = 1'b0;
assign sd_buff_din[0] = 8'h00;

localparam MAX_MEM_BLOCK = 16;

MSX::block_t memory_block[MAX_MEM_BLOCK];
MSX::sram_block_t sram_block[2];
MSX::rom_info_t rom_info[2];
MSX::msx_slots_t     msx_slots;

logic [7:0] mapper_slot[4];
logic mapper_en;

assign mapper_en = (cpu_addr == 16'hFFFF & msx_slots.slot_typ[active_slot] == SLOT_TYP_MAPPER);

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
wire  [7:0] block_count;
wire [24:0] mem_addr, offset;
wire        slot_id, block_init, cpu_we;
slot_typ_t  slot_typ;

assign {active_subslot, active_block}  = msx_slots.slot_typ[active_slot] == SLOT_TYP_CART_A ? 4'd0                                                 :
                                         msx_slots.slot_typ[active_slot] == SLOT_TYP_CART_B ? 4'd0                                                 :
                                         msx_slots.slot_typ[active_slot] != SLOT_TYP_MAPPER ? {2'd0, cpu_addr[15:14]}                          :
                                         cpu_addr[15:14] == 2'b00                           ? {mapper_slot[active_slot][1:0], cpu_addr[15:14]} :
                                         cpu_addr[15:14] == 2'b01                           ? {mapper_slot[active_slot][3:2], cpu_addr[15:14]} :
                                         cpu_addr[15:14] == 2'b10                           ? {mapper_slot[active_slot][5:4], cpu_addr[15:14]} :
                                                                                              {mapper_slot[active_slot][7:6], cpu_addr[15:14]} ;

assign slot_typ     = msx_slots.slot_typ[active_slot] == SLOT_TYP_MAPPER ? msx_slots.mem_block[active_slot][active_subslot][active_block].typ : msx_slots.slot_typ[active_slot] ;
assign slot_id      = slot_typ == SLOT_TYP_CART_B;
assign block_id     = msx_slots.mem_block[active_slot][active_subslot][active_block].block_id;
assign block_offset = msx_slots.mem_block[active_slot][active_subslot][active_block].offset;
assign block_init   = msx_slots.mem_block[active_slot][active_subslot][active_block].init;

assign offset       = sram_oe ? sram_block[slot_id].mem_offset : memory_block[block_id].mem_offset;
assign block_count  = memory_block[block_id].block_count;

assign cpu_we       = (slot_typ == SLOT_TYP_RAM | slot_typ == SLOT_TYP_MSX2_RAM) & cpu_wr & cpu_mreq & block_init;
assign mem_addr     = offset + (slot_typ == SLOT_TYP_RAM      ? {block_offset, cpu_addr[13:0]}   : 
                                slot_typ == SLOT_TYP_MSX2_RAM ? {msx2_ram_bank, cpu_addr[13:0]}  :
                                slot_typ == SLOT_TYP_CART_A   ? mem_cart_rom                     :
                                slot_typ == SLOT_TYP_CART_B   ? mem_cart_rom                     :
                                                                {block_offset, cpu_addr[13:0]})  ;

assign sdram_addr = dw_sdram_upload              ? dw_sdram_addr             : mem_addr;
assign sdram_din  = dw_sdram_upload              ? dw_sdram_din              : cpu_dout;
assign sdram_we   = dw_sdram_upload              ? dw_sdram_we               : cpu_we & ~mapper_en & ~sram_oe;
assign sdram_rd   = dw_sdram_upload              ? 1'b0                      : cpu_rd & cpu_mreq;
assign cpu_din    = ~cpu_rd                      ? 8'hFF                     :
                    mapper_en                    ? ~mapper_slot[active_slot] :
                    cart_output_en               ? d_to_cpu_cart             :
                    FDC_output_en                ? d_to_cpu_FDC              :
                    msx2_mapper_req              ? msx2_mapper_dout          :
                    ~cpu_mreq                    ? 8'hFF                     :                    
                    sram_oe                      ? bram_dout                 :
                    sdram_size == 0 & block_init ? bram_dout                 :
                    block_init                   ? sdram_dout                :
                                                   8'hFF                     ;

assign bram_addr = dw_bram_upload ? dw_bram_addr                                 :
                                    mem_addr                                     ;
assign bram_we   = dw_bram_upload ? dw_bram_we | (sdram_size == 0 & dw_sdram_we) :
                                    sram_we    | (sdram_size == 0 & sdram_we)    ;
assign bram_din  = dw_bram_upload ? (dw_bram_we ? dw_bram_din : dw_sdram_din)    :
                                    cpu_dout                                     ;    


assign sd_buff_din[1] = ram_format ? 8'hFF : sram_dout; //MSX
assign sd_buff_din[2] = ram_format ? 8'hFF : sram_dout; //CART NVRAM
assign sd_buff_din[3] = ram_format ? 8'hFF : sram_dout; //ROM A NVRAM
assign sd_buff_din[4] = ram_format ? 8'hFF : sram_dout; //ROM_B NVRAM

assign FDC_cs = slot_typ == SLOT_TYP_FDC |
                (slot_typ == SLOT_TYP_CART_A | slot_typ == SLOT_TYP_CART_B) & cart_conf[slot_id].typ == CART_TYP_FDC;

wire        FDC_cs, FDC_output_en;
wire  [7:0] d_to_cpu_FDC;
fdc fdc
(
   .clk(clk),
   .reset(reset),
   .clk_en(clk_en),
   .cs(FDC_cs),
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

wire [24:0] bram_addr;
wire  [7:0] bram_dout, bram_din, sram_dout;
wire        bram_we;
dpram #(.addr_width(18)) SRAM
(
   .clock(clk),
   .address_a(bram_addr[17:0]),
   .q_a(bram_dout),
   .data_a(bram_din), 
   .wren_a(bram_we),          

   .address_b(ram_offset + {ram_lba[8:0],sd_buff_addr[8:0]}),
   .data_b(sd_buff_dout),
   .q_b(sram_dout),
   .wren_b(sd_buff_wr & sd_buff_addr[13:9] == 0 & ram_we ) 
);

wire  [7:0] d_to_cpu_cart;
wire [24:0] mem_cart_rom;
wire        sram_oe, sram_we, cart_output_en;
cart_rom cart_rom
(
   .clk(clk),
   .clk_en(clk_en),
   .reset(reset),
   .addr(cpu_addr),
   .d_from_cpu(cpu_dout),
   .d_to_cpu(d_to_cpu_cart),
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
   .cart_oe(cart_output_en),
   .sound(sound)
);

wire  [7:0] msx2_ram_bank, msx2_mapper_dout;
wire        msx2_mapper_req;

msx2_ram_mapper msx2_ram_mapper
(
   .ram_bank(msx2_ram_bank),
   .mapper_dout(msx2_mapper_dout),
   .mapper_req(msx2_mapper_req),
   .ram_block_count(ram_mapper_count),
   .*
);

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
   .*
);

wire [24:0] dw_sdram_addr, dw_bram_addr;
wire  [7:0] dw_sdram_din, dw_bram_din, ram_mapper_count;
wire        dw_sdram_upload, dw_sdram_we, dw_bram_we, dw_bram_upload;
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

endmodule