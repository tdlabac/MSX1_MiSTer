module cart_rom
(
    input            clk,
    input            reset,
    input     [15:0] addr,
    input            wr,
    input            CS1_n,
    input            CS2_n,
    input            CS12_n,
    input	         SLTSL_n,
    input      [7:0] d_from_cpu,
    output     [7:0] d_to_cpu,

    input            ioctl_wr,
    input     [24:0] ioctl_addr,
    input      [7:0] ioctl_dout,
    input            ioctl_isROM
);

assign d_to_cpu = d_to_cpu_bram;

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

wire [24:0] mem_addr;
// 0 uknown
// 1 nomaper
// 2 gamemaster2
// 3 konami
// 4 konami SCC
// 5 ASCII 8
// 6 ASCII 16
assign mem_addr = ioctl_isROM ? ioctl_addr :
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
endmodule
