module msx1
(
	input         clk,
	input         ce_10m7,
	input         reset,
	input         border,
	output  [7:0] R,
	output  [7:0] G,
	output  [7:0] B,
	output        hsync_n,
	output        vsync_n,
	output        hblank,
	output        vblank

);


//  -----------------------------------------------------------------------------
//  -- Clock generation
//  -----------------------------------------------------------------------------
wire clk_en_3m58_p, clk_en_3m58_n;
cv_clock clock
(
	.clk_i(clk),
	.clk_en_10m7_i(ce_10m7),
	.reset_n_i(~reset),
	.clk_en_3m58_p_o(clk_en_3m58_p),
	.clk_en_3m58_n_o(clk_en_3m58_n)
);

//  -----------------------------------------------------------------------------
//  -- T80 CPU
//  -----------------------------------------------------------------------------
wire [15:0] a;
wire [7:0] d_to_cpu, d_from_cpu;
wire mreq_n, wr_n, m1_n, iorq_n, rd_n, rfrsh_n, wait_n = 1; 
t80pa #(.Mode(0)) T80
(
	.RESET_n(~reset),
	.CLK(clk),
	.CEN_p(clk_en_3m58_p),
	.CEN_n(clk_en_3m58_n),
	.WAIT_n(wait_n),
	.INT_n(vdp_int_n),
	.NMI_n(1),
	.BUSRQ_n(1),
	.M1_n(m1_n),
	.MREQ_n(mreq_n),
	.IORQ_n(iorq_n),
	.RD_n(rd_n),
	.WR_n(wr_n),
	.RFSH_n(rfrsh_n),
	.HALT_n(1),
	.BUSAK_n(),
	.A(a),
	.DI(d_to_cpu),
	.DO(d_from_cpu)
);

//  -----------------------------------------------------------------------------
//  -- ROM
//  -----------------------------------------------------------------------------
wire [7:0] rom_q;
spram #(.addr_width(15), .mem_init_file("rtl/rom/8020-00bios.mif"), .mem_name("ROM")) rom
(   
	.clock(clk),
	.address(a[14:0]),
	.q(rom_q)
);

//  -----------------------------------------------------------------------------
//  -- Video RAM 16k
//  -----------------------------------------------------------------------------
wire [13:0] vram_a;
wire [7:0]  vram_do;
wire [7:0]  vram_di;
wire        vram_we;
spram #(14) vram
(
	.clock(clk),
	.address(vram_a),
	.wren(vram_we),
	.data(vram_do),
	.q(vram_di)
);

//  -----------------------------------------------------------------------------
//  -- TMS9928A Video Display Processor
//  -----------------------------------------------------------------------------
wire [7:0] d_from_vdp;
wire vdp_n, vdp_int_n;
assign vdp_n = ~(~iorq_n & m1_n & (a[7:1] == 7'b1001100));
vdp18_core #(.is_pal_g(1),.compat_rgb_g(1)) vdp18
(
	.clk_i(clk),
	.clk_en_10m7_i(ce_10m7),
	.reset_n_i(~reset),
	.csr_n_i(vdp_n | rd_n),
	.csw_n_i(vdp_n | wr_n),
	.mode_i(a[0]),
	.cd_i(d_from_cpu),
	.cd_o(d_from_vdp),
	.int_n_o(vdp_int_n),
	.vram_we_o(vram_we),
	.vram_a_o(vram_a),
	.vram_d_o(vram_do),
	.vram_d_i(vram_di),
	.border_i(border),
	.rgb_r_o(R),
	.rgb_g_o(G),
	.rgb_b_o(B),
	.hsync_n_o(hsync_n),
	.vsync_n_o(vsync_n),
	.hblank_o(hblank),
	.vblank_o(vblank)
);

endmodule
