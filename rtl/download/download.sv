module download
(
   input                       clk,
   input                       reset,
   output                      need_reset,

   input                       ioctl_download,
   input                [15:0] ioctl_index,
   input                [26:0] ioctl_addr,
   input                       rom_eject,
   input                       cart_changed,
   //input                       need_reload,
   input MSX::config_cart_t    cart_conf[2],
   output               [27:0] ddr3_addr,
   output                      ddr3_rd,
   output                      ddr3_wr,
   output                [7:0] ddr3_din,
   input                 [7:0] ddr3_dout,
   input                       ddr3_ready,
   output                      ddr3_request,
   output               [24:0] bram_addr, 
   output                [7:0] bram_din,
   output                      bram_we,
   output                      bram_request,

   input                       sdram_ready,  
   output                      sdram_request,
   output               [24:0] sdram_addr,
   output                [7:0] sdram_din,
   output                      sdram_we,
   input                 [1:0] sdram_size,

   output MSX::block_t         memory_block[MAX_MEM_BLOCK],
   output MSX::slot_t          msx_slot[4],
   output MSX::rom_info_t      rom_info[2],
   output MSX::sram_block_t    sram_block[2],
   output                      msx_type,
   output                [7:0] ram_block_count
);

localparam MAX_CONFIG = 16;
localparam MAX_MEM_BLOCK = 16;
localparam MAX_FW_ROM = 8;

assign ddr3_addr = ddr3_upload_debug   ? ddr3_addr_debug  : 
                   config_ddr3_request ? config_ddr3_addr : 
                   fw_ddr3_request     ? fw_ddr3_addr     : 
                   init_ddr3_request   ? init_ddr3_addr   : 
                                         28'd0;
assign ddr3_rd   = config_ddr3_request ? config_ddr3_rd : 
                   fw_ddr3_request     ? fw_ddr3_rd     : 
                   init_ddr3_request   ? init_ddr3_rd   : 
                                         1'b0;
assign ddr3_wr   = ddr3_upload_debug   ? ddr3_wr_debug  : 
                                         1'b0;
assign ddr3_din  = ddr3_din_debug;
assign msx_type  = MSXtype == 0 ? 1'b1 : 1'b0;

assign sdram_we      = init_sdram_we;
assign sdram_din     = init_sdram_din;
assign sdram_addr    = init_sdram_addr;
assign sdram_request = init_sdram_request;

assign update_request = config_update_request | rom_update_request | fw_update_request | cart_changed;
assign ddr3_request   = ddr3_upload_debug | config_ddr3_request | fw_ddr3_request | init_ddr3_request;

wire rom_update_request;
MSX::ioctl_rom_t ioctl_rom[2];
download_rom download_rom
(
   .update_request(rom_update_request),
   .ioctl_rom(ioctl_rom),
   .*
);

wire        init_ddr3_rd;
wire        init_ddr3_request;
wire [27:0] init_ddr3_addr;
wire  [7:0] init_sdram_din;
wire [24:0] init_sdram_addr;
wire        init_sdram_we;
wire        init_sdram_request;
wire        update_ack;
wire        update_request;
download_msx download_msx 
(
   .ddr3_addr(init_ddr3_addr),
   .ddr3_rd(init_ddr3_rd),
   .ddr3_reqest(init_ddr3_request),
   .sdram_addr(init_sdram_addr),
   .sdram_din(init_sdram_din),
   .sdram_we(init_sdram_we),
   .sdram_request(init_sdram_request),
   .bram_addr(bram_addr),
   .bram_din(bram_din),
   .bram_we(bram_we),
   .bram_request(bram_request),
   .update_request(update_request),
   .update_ack(update_ack),
   .msx_config(msx_config),
   .msx_slot(msx_slot),
   .fw_store(fw_store), 
   .memory_block(memory_block),
   .need_reset(need_reset),
   .*
);

wire          config_ddr3_rd;
wire   [27:0] config_ddr3_addr;
wire          config_ddr3_request;
wire    [1:0] MSXtype;
wire          config_update_request;
MSX::msx_config_t msx_config[MAX_CONFIG];
download_config download_config
(
   .ddr3_addr(config_ddr3_addr),
   .ddr3_rd(config_ddr3_rd),
   .ddr3_reqest(config_ddr3_request),
   .update_request(config_update_request),
   .msx_type(MSXtype),
   .msx_config(msx_config),
   .ram_block_count(ram_block_count),
   .*
);

wire          fw_ddr3_rd;
wire   [27:0] fw_ddr3_addr;
wire          fw_ddr3_request;
wire          fw_update_request;
MSX::fw_rom_t fw_store[MAX_FW_ROM];
download_fw download_fw
(
   .ddr3_addr(fw_ddr3_addr),
   .ddr3_rd(fw_ddr3_rd),
   .ddr3_reqest(fw_ddr3_request),
   .update_request(fw_update_request),
   .fw_store(fw_store),
   .*
);

wire [27:0] ddr3_addr_debug;
wire  [7:0] ddr3_din_debug;
wire        ddr3_wr_debug;
wire        ddr3_upload_debug;
msx_download_debug msx_download_debug
(
   .msx_slot(msx_slot),
   .memory_block(memory_block),
   .rom_info(rom_info),
   .ioctl_rom(ioctl_rom),
   .fw_store(fw_store),
   .ddr3_addr(ddr3_addr_debug),
   .ddr3_din(ddr3_din_debug),
   .ddr3_wr(ddr3_wr_debug),
   .ddr3_upload(ddr3_upload_debug),
   .ddr3_ready(ddr3_ready),
   .*
);

endmodule