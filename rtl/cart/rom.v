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
    //SDRAM
    input            clk_sdram,
    input            locked_sdram,
    inout     [15:0] SDRAM_DQ,
    output    [12:0] SDRAM_A,
    output           SDRAM_DQML,
    output           SDRAM_DQMH,
    output     [1:0] SDRAM_BA,
    output           SDRAM_nCS,
    output           SDRAM_nWE,
    output           SDRAM_nRAS,
    output           SDRAM_nCAS,
    output           SDRAM_CKE,
    output           SDRAM_CLK
);
wire sdram = 0;

assign d_to_cpu = mapper == 4 && scc_ack ? d_to_cpu_scc   :
                  sdram                  ? d_to_cpu_sdram :
                                           d_to_cpu_bram;

assign sound = mapper == 4 ? scc_sound :
                             14'h0;

wire rom_we = ioctl_isROM & ioctl_wr;
wire [7:0] d_to_cpu_bram;
spram #(.addr_width(18),.mem_name("CART")) rom_cart
(
    .clock(clk),
    .address(mem_addr[17:0]),
    .wren(rom_we & ioctl_addr < 24'h20000),
    .q(d_to_cpu_bram),
    .data(ioctl_dout)
);

wire sdram_ready;
assign ioctl_wait = ~sdram_ready && ioctl_isROM;
wire [24:0] mem_addr;
wire [7:0] d_to_cpu_sdram;
sdram rom_cart2
(
    .init(~locked_sdram),
    .clk(clk_sdram),
    .SDRAM_DQ(SDRAM_DQ),
    .SDRAM_A(SDRAM_A),
    .SDRAM_DQML(SDRAM_DQML),
    .SDRAM_DQMH(SDRAM_DQMH),
    .SDRAM_BA(SDRAM_BA),
    .SDRAM_nCS(SDRAM_nCS),
    .SDRAM_nWE(SDRAM_nWE),
    .SDRAM_nRAS(SDRAM_nRAS),
    .SDRAM_nCAS(SDRAM_nCAS),
    .SDRAM_CKE(SDRAM_CKE),
    .SDRAM_CLK(SDRAM_CLK),

    .dout(d_to_cpu_sdram),
    .din (ioctl_dout),
    .addr(mem_addr),
    .we(rom_we),
    .rd(~SLTSL_n && ~ioctl_isROM),
    .ready(sdram_ready)
);

// 0 uknown
// 1 nomaper
// 2 gamemaster2
// 3 konami
// 4 konami SCC
// 5 ASCII 8
// 6 ASCII 16
assign mem_addr = ioctl_isROM ? ioctl_addr :
                  mapper == 3 ? mem_addr_konami :
                  mapper == 4 ? mem_addr_konami_scc :
                  addr - {offset,12'd0}; // default nomaper

wire [3:0]  offset;
wire [24:0] rom_size;
wire [2:0]  mapper;

rom_detect rom_detect
(
    .clk(clk),
    .ioctl_isROM(ioctl_isROM),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout),
    .rom_we(rom_we),
    .mapper(mapper),
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

endmodule
