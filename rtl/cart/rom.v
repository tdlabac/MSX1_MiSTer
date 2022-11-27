//https://www.msx.org/wiki/ROM_mappers

module cart_rom
(
    input            clk,
    input            clk_en,
    input            reset,
    input     [15:0] addr,
    input            wr,
    input            rd,
    input            CS1_n,
    input            CS2_n,
    input            CS12_n,
    input	         SLTSL_n,
    input      [7:0] d_from_cpu,
    output     [7:0] d_to_cpu,
    output    [14:0] sound,

    input            ioctl_wr,
    input     [24:0] ioctl_addr,
    input      [7:0] ioctl_dout,
    input            ioctl_isROM,
    output           ioctl_wait,
    input      [3:0] user_mapper,
    output     [2:0] detected_mapper,
    input      [7:0] ram_dout,
    output     [7:0] ram_din,
    output    [24:0] ram_addr,
    output           ram_we,
    output           ram_rd,
    input            ram_ready,
    input            rom_enabled
);

assign ram_din = ioctl_dout;
assign ram_rd = ~SLTSL_n & ~ioctl_isROM;
assign ram_we = rom_we;
assign detected_mapper = auto_mapper;

assign d_to_cpu = mapper == 4 && scc_ack             ? d_to_cpu_scc   :
                  mapper == 2 && sram_oe_gamemaster2 ? d_to_cpu_sram  :
                  ~rom_enabled                       ? 8'hFF :
                                                       ram_dout ;

assign sound = mapper == 4 ? scc_sound :
                             14'h0;

wire rom_we = ioctl_isROM & ioctl_wr;

wire [7:0] d_to_cpu_sram;
spram #(.addr_width(13),.mem_name("CART_SRAM")) cart_sram
(
    .clock(clk),
    .address(sram_addr_gamemaster2),
    .wren(sram_we_gamemaster2),
    .q(d_to_cpu_sram),
    .data(d_from_cpu)
);

assign ioctl_wait = ~ram_ready && ioctl_isROM;

wire [12:0] sram_addr;
wire [3:0] mapper;

// 0 uknown
// 1 nomaper
// 2 gamemaster2
// 3 konami
// 4 konami SCC
// 5 ASCII 8
// 6 ASCII 16
// 7 linear (nomaper) 64kb. Aligned ROM image is replicated to 64KB area.
// 8 R-TYPE
// 9 FDD VY0010

assign mapper   = user_mapper[3:0] == 0 ? {1'b0,auto_mapper} : user_mapper[3:0];
assign ram_addr = ioctl_isROM ? ioctl_addr :
                  mapper == 2 ? mem_addr_gamemaster2 :
                  mapper == 3 ? mem_addr_konami :
                  mapper == 4 ? mem_addr_konami_scc :
                  mapper == 5 ? mem_addr_ascii8 :
                  mapper == 6 ? mem_addr_ascii16 :
                  mapper == 8 ? mem_addr_ascii16 :
                  mapper == 7 ? addr & (rom_size - 1) :
                  addr - {offset,12'd0}; // default nomaper

wire [3:0]  offset;
wire [24:0] rom_size;
wire [2:0]  auto_mapper;

rom_detect rom_detect
(
    .clk(clk),
    .ioctl_isROM(ioctl_isROM),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout),
    .rom_we(rom_we),
    .mapper(auto_mapper),
    .offset(offset),
    .rom_size(rom_size)
);

wire [24:0] mem_addr_konami;
cart_konami konami
(
    .clk(clk),
    .reset(reset),
    .rom_size(rom_size),
    .addr(addr),
    .d_from_cpu(d_from_cpu),
    .wr(wr),
    .cs(~SLTSL_n),
    .mem_addr(mem_addr_konami)
);

wire [24:0] mem_addr_konami_scc;
wire [7:0]  d_to_cpu_scc;
wire        scc_ack;
wire [14:0] scc_sound;
cart_konami_scc konami_scc
(
    .clk(clk),
    .clk_en(clk_en),
    .reset(reset),
    .rom_size(rom_size),
    .addr(addr),
    .d_from_cpu(d_from_cpu),
    .d_to_cpu(d_to_cpu_scc),
    .ack(scc_ack),
    .wr(wr),
    .rd(rd),
    .cs(~SLTSL_n),
    .mem_addr(mem_addr_konami_scc),
    .scc_sound(scc_sound)
);

wire [24:0] mem_addr_ascii8;
cart_asci8 ascii8
(
    .clk(clk),
    .reset(reset),
    .rom_size(rom_size),
    .addr(addr),
    .d_from_cpu(d_from_cpu),
    .wr(wr),
    .cs(~SLTSL_n),
    .mem_addr(mem_addr_ascii8)
);

wire [24:0] mem_addr_ascii16;
cart_asci16 ascii16
(
    .clk(clk),
    .reset(reset),
    .rom_size(rom_size),
    .addr(addr),
    .d_from_cpu(d_from_cpu),
    .wr(wr),
    .cs(~SLTSL_n),
    .mem_addr(mem_addr_ascii16),
    .r_type(mapper == 8)
);

wire [24:0] mem_addr_gamemaster2;
wire [12:0] sram_addr_gamemaster2;
wire        sram_we_gamemaster2;
wire        sram_oe_gamemaster2;
cart_gamemaster2 gamemaster2
(
    .clk(clk),
    .reset(reset),
    .addr(addr),
    .d_from_cpu(d_from_cpu),
    .wr(wr),
    .cs(~SLTSL_n),
    .mem_addr(mem_addr_gamemaster2),
    .sram_addr(sram_addr_gamemaster2),
    .sram_we(sram_we_gamemaster2),
    .sram_oe(sram_oe_gamemaster2)
);

endmodule
