module msx_slots
(
   input                       clk,
   //input                       clk_sdram,
   input                       clk_en,
   input                       reset,
   //input                       rom_eject,
   //input                       cart_changed,
   //output                      need_reset,
   //input                       sram_save,
   //input                       sram_load,
   //output                      msx_type,
   //input MSX::config_cart_t    cart_conf[2],
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
   //input                       ioctl_download,
   //input                [15:0] ioctl_index,
   //input                [26:0] ioctl_addr,
   //DDR3
   //output         logic [27:0] ddr3_addr,
   //output                      ddr3_rd,
   //output                      ddr3_wr,
   //input                 [7:0] ddr3_dout,
   //output                [7:0] ddr3_din,
   //input                       ddr3_ready,
   //output                      ddr3_request,
   //SDRAM
   output               [26:0] ram_addr,
   output                [7:0] ram_din,
   input                 [7:0] ram_dout,
   output                      ram_rnw,
   output                      ram_ce,
   //input                       sdram_ready,
   //input                 [1:0] sdram_size,

   //output               [24:0] dw_sdram_addr,
   //output                [7:0] dw_sdram_din,
   //output                      dw_sdram_we,
   //input                       dw_sdram_ready,
   
   //output               [24:0] flash_addr,
   //output                [7:0] flash_din,
   //output                      flash_wr,
   //input                       flash_ready,
   //input                       flash_done,

   //KBD LAYOUT
   //output                [9:0] kbd_addr,
   //output                [7:0] kbd_din,
   //output                      kbd_we,
   //output                      kbd_request,
   //SD FDC
   input                       img_mounted,
   input                [31:0] img_size,
   input                       img_readonly,

   output               [31:0] sd_lba,
   output                      sd_rd,
   output                      sd_wr,
   input                       sd_ack,
   input                [13:0] sd_buff_addr,
   input                 [7:0] sd_buff_dout,
   output                [7:0] sd_buff_din,
   input                       sd_buff_wr,

   input                 [1:0] active_slot,
   input  MSX::block_t         slot_layout[64],
   input  MSX::lookup_RAM_t    lookup_RAM[16],
   input  MSX::bios_config_t   bios_config,
   input  MSX::config_cart_t   cart_conf[2]

   //output                      spi_ss,
   //output                      spi_clk,
   //input                       spi_di,
   //output                      spi_do,
   //output                [2:0] debug_cpu_din_src
);

wire signed [15:0] sound_A, sound_B;
assign sound = sound_A + sound_B;

assign sound_A = cart_conf[0].typ == CART_TYP_FM_PAC       ? fmpac_sound[0] :
                                                             16'd0;

assign sound_B = cart_conf[1].typ == CART_TYP_FM_PAC       ? fmpac_sound[1] :
                                                             16'd0;                                                             

logic [7:0] mapper_slot[4];
wire mapper_en;
assign mapper_en = (cpu_addr == 16'hFFFF & bios_config.slot_expander_en[active_slot] & cpu_mreq );

always @(posedge reset, posedge clk) begin
   if (reset) begin
      mapper_slot[0] <= 8'h00;
      mapper_slot[1] <= 8'h00;
      mapper_slot[2] <= 8'h00;
      mapper_slot[3] <= 8'h00;
   end else begin
      if (mapper_en & cpu_wr )
         mapper_slot[active_slot] <= cpu_dout;
   end
end


mapper_typ_t        mapper;
device_typ_t        device;

wire          [1:0] block      = cpu_addr[15:14];
wire          [1:0] subslot    = mapper_slot[active_slot][(3'd2 * block) +:2];
wire          [5:0] layout_id  = {active_slot, subslot, block};
wire          [3:0] ref_ram    = slot_layout[layout_id].ref_ram;
wire          [1:0] offset_ram = slot_layout[layout_id].offset_ram;
wire                cart_num   = slot_layout[layout_id].cart_num;
assign              mapper     = slot_layout[layout_id].mapper;
assign              device     = slot_layout[layout_id].device;
wire         [26:0] base_ram   = lookup_RAM[ref_ram].addr;
wire         [15:0] size       = lookup_RAM[ref_ram].size;  //16kB * size
wire                ram_ro     = lookup_RAM[ref_ram].ro;


assign ram_addr = base_ram + mapper_addr;

wire [26:0] mapper_addr = mem_unmaped             ? 27'hDEAD                  :
                          mapper == MAPPER_NONE   ? 27'(mapper_none_addr)     :
                          mapper == MAPPER_RAM    ? 27'(mapper_ram_addr)      :
                          mapper == MAPPER_LINEAR ? 27'(mapper_linear_addr)   :
                          mapper == MAPPER_OFFSET ? 27'(mapper_offset_addr)   :
                          mapper == MAPPER_KONAMI ? 27'(mapper_konami_addr)   :
                          device == DEVICE_FMPAC  ? 27'(fmpac_addr)           :
                                                    27'hDEAD                  ;


assign cpu_din          = mapper_ram_req          ? mapper_ram_dout           :
                          mapper_en & cpu_rd      ? ~mapper_slot[active_slot] :
                          FDC_req                 ? d_to_cpu_FDC              :
                          fmpac_req               ? fm_pac_dout               :
                          mapper == MAPPER_UNUSED ? 8'hFF                     :
                          mem_unmaped             ? 8'hFF                     :
                          device == DEVICE_FMPAC  ? ram_dout                  :
                                                    ram_dout                  ;  



assign ram_ce   = cpu_mreq & (cpu_rd | (cpu_wr & ~ram_ro)) & mapper != MAPPER_UNUSED;
assign ram_rnw  = cpu_rd;
assign ram_din  = cpu_dout;

wire mem_unmaped = mapper_konami_unmaped | fmpac_mem_unmaped;


wire debug_tick = mapper_none_addr == 27'(16'h8000) & active_slot == 2'd3 & cpu_mreq;

//MAPPER NONE
wire [26:0] mapper_none_addr = 27'(cpu_addr[13:0]) + (27'(offset_ram) << 14);

//MAPPER LINEAR
wire [26:0] mapper_linear_addr = 27'(cpu_addr[15:0]) & ((27'(size) << 14)-27'd1);

//NONE 
//wire [26:0] mapper_offset_addr  = 27'(cpu_addr) - 27'h2000;
wire [26:0] mapper_offset_addr  = 27'(cpu_addr) - {11'd0,4'd4,12'd0};

//MAPPER MSX RAM

wire [21:0] mapper_ram_addr;
wire  [7:0] mapper_ram_dout;
wire mapper_ram_req;
msx2_ram_mapper msx2_ram_mapper
(
   .clk(clk),
   .reset(reset),
   .cpu_iorq(cpu_iorq),
   .cpu_m1(cpu_m1),
   .cpu_wr(cpu_wr),
   .cpu_rd(cpu_rd),
   .cpu_addr(cpu_addr),
   .cpu_dout(cpu_dout),
   .ram_block_count(size[7:0]),
   .mapper_dout(mapper_ram_dout),
   .mapper_req(mapper_ram_req),
   .mapper_addr(mapper_ram_addr)
);

wire [24:0] mapper_konami_addr;
wire        mapper_konami_unmaped;
cart_konami konami
(
   .clk(clk),
   .reset(reset),
   .rom_size(25'(size) << 14),
   .addr(cpu_addr),
   .d_from_cpu(cpu_dout),
   .wr(cpu_mreq & cpu_wr),
   .cs(mapper == MAPPER_KONAMI),
   .slot(cart_num),
   .mem_unmaped(mapper_konami_unmaped),
   .mem_addr(mapper_konami_addr)
);

wire  [7:0] fm_pac_dout;
wire [24:0] fmpac_addr;
wire        fmpac_req, fmpac_mem_unmaped;
wire signed [15:0] fmpac_sound[2];

cart_fm_pac fm_pac
(
   .clk(clk),
   .clk_en(clk_en),
   .reset(reset),
   .addr(cpu_addr),
   .d_from_cpu(cpu_dout),
   .d_to_cpu(fm_pac_dout),  
   .cs(device == DEVICE_FMPAC),
   .slot(cart_num),
   .wr(cpu_wr),
   .rd(cpu_rd),
   .iorq(cpu_iorq),
   .mreq(cpu_mreq),
   .m1(cpu_m1),
   .sound(fmpac_sound),
   .cart_oe(fmpac_req),  
   .sram_we(),
   .sram_oe(),
   .mem_unmaped(fmpac_mem_unmaped),
   .mem_addr(fmpac_addr)
);

wire        FDC_req;
wire  [7:0] d_to_cpu_FDC;
fdc fdc
(
   .clk(clk),
   .reset(reset),
   .clk_en(clk_en),
   .cs(device == DEVICE_FDC),
   .addr(cpu_addr[13:0]),
   .d_from_cpu(cpu_dout),
   .d_to_cpu(d_to_cpu_FDC),
   .output_en(FDC_req),
   .rd(cpu_rd & cpu_mreq),
   .wr(cpu_wr & cpu_mreq),
   .img_mounted(img_mounted),
   .img_size(img_size),
   .img_readonly(img_readonly),
   
   .sd_lba(sd_lba),
   .sd_rd(sd_rd),
   .sd_wr(sd_wr),
   .sd_ack(sd_ack),
   .sd_buff_addr(sd_buff_addr[8:0]),
   .sd_buff_dout(sd_buff_dout),
   .sd_buff_din(sd_buff_din),
   .sd_buff_wr(sd_buff_wr)
);

/*
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
wire [24:0] mem_addr, offset;
wire        slot_id, block_init, cpu_we;
slot_typ_t  slot_typ;

assign {active_subslot, active_block}  = msx_slots.slot_typ[active_slot] == SLOT_TYP_CART_A ? 4'd0                                             :
                                         msx_slots.slot_typ[active_slot] == SLOT_TYP_CART_B ? 4'd0                                             :
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

assign cpu_we       = (slot_typ == SLOT_TYP_RAM | slot_typ == SLOT_TYP_MSX2_RAM) & cpu_wr & cpu_mreq & block_init;
assign mem_addr     = offset + (slot_typ == SLOT_TYP_RAM      ? {block_offset, cpu_addr[13:0]}   : 
                                slot_typ == SLOT_TYP_MSX2_RAM ? {msx2_ram_bank, cpu_addr[13:0]}  :
                                slot_typ == SLOT_TYP_CART_A   ? mem_cart_rom                     :
                                slot_typ == SLOT_TYP_CART_B   ? mem_cart_rom                     :
                                                                {block_offset, cpu_addr[13:0]})  ;

assign sdram_addr = mem_addr;
assign sdram_din  = cpu_dout;
assign sdram_we   = cpu_we & ~mapper_en & ~sram_oe;
assign sdram_rd   = cpu_rd & cpu_mreq;


assign {debug_cpu_din_src, cpu_din}  = ~cpu_rd                       ? {3'd07, 8'hFF                     }:
                                       mapper_en                     ? {3'd00, ~mapper_slot[active_slot] }:
                                       cart_output_en                ? {3'd01, d_to_cpu_cart             }:
                                       FDC_output_en                 ? {3'd02, d_to_cpu_FDC              }:
                                       msx2_mapper_req               ? {3'd03, msx2_mapper_dout          }:
                                       ~cpu_mreq                     ? {3'd07, 8'hFF                     }:
                                       sram_oe                       ? {3'd04, bram_dout                 }:
                                       sdram_size == 0 & block_init  ? {3'd05, bram_dout                 }:
                                       block_init                    ? {3'd06, sdram_dout                }:
                                                                       {3'd07, 8'hFF                     };

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
   .sound(sound),
   .flash_offset(offset),
   .debug_C_0(),
   .debug_S_0(),
   .debug_S_1(),
   .debug_S_2(),
   .debug_S_3(),
   .debug_1_0(),
   .debug_1_1(),
   .debug_1_2(),
   .debug_1_3(),
   .debug_3_0(),
   .debug_3_1(),
   .debug_3_2(),
   .debug_3_3(),
   .*
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

wire [24:0] dw_bram_addr;
wire  [7:0] dw_bram_din, ram_mapper_count;
wire        dw_sdram_upload, dw_bram_we, dw_bram_upload;
download download
(
   .sdram_addr(dw_sdram_addr),
   .sdram_din(dw_sdram_din),
   .sdram_we(dw_sdram_we),
   .sdram_request(dw_sdram_upload),
   .sdram_ready(dw_sdram_ready),
   .bram_addr(dw_bram_addr),
   .bram_din(dw_bram_din),
   .bram_we(dw_bram_we),
   .bram_request(dw_bram_upload),
   .*
);
*/
endmodule