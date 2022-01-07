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
	output        vblank,
	output [10:0] audio,
	input  [10:0] ps2_key,
	input   [5:0] joy0,
	input   [5:0] joy1,
	input         ioctl_download,
	input   [7:0] ioctl_index,
	input         ioctl_wr,
	input  [24:0] ioctl_addr,
	input   [7:0] ioctl_dout,
	input         ioctl_isROM,
	output        cas_motor,
	input         cas_audio_in
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
wire mreq_n, wr_n, m1_n, iorq_n, rd_n, rfrsh_n, wait_n; 
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
//  -- WAIT
//  -----------------------------------------------------------------------------
wire exwait_n = 1;
wire exwait = ~exwait_n;

reg powait;
always @(posedge clk_en_3m58_p, posedge exwait, posedge powait) begin
	if (exwait)
		wait_n <= 0;
	else if (powait)
		wait_n <= 1;
	else
		wait_n <= (m1_n & a[1]) | (m1_n & psg_n);
end

always @(posedge clk_en_3m58_p, posedge exwait) begin
	if (exwait)
		powait <= 0;
	else
		powait <= ~wait_n;
end

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
//  -- RAM
//  -----------------------------------------------------------------------------

wire [7:0] ram_q;
spram #(.addr_width(16), .mem_name("RAM")) ram
(   
	.clock(clk),
	.address (a[15:0]),
	.q(ram_q),
	.data(d_from_cpu),
	.wren(~(SLTSL_n[3] | wr_n ))
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
wire vdp_int_n;
vdp18_core #(.is_pal_g(1),.compat_rgb_g(0)) vdp18
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

//  -----------------------------------------------------------------------------
//  -- IO Decoder
//  -----------------------------------------------------------------------------
wire vdp_n, psg_n, ppi_n, cen_n;
io_decoder io_decoder
(
	.addr(a),
	.iorq_n(iorq_n),
	.m1_n(m1_n),
	.vdp_n(vdp_n),
	.psg_n(psg_n),
	.ppi_n(ppi_n),
	.cen_n(cen_n)
);

//  -----------------------------------------------------------------------------
//  -- 82C55 PPI
//  -----------------------------------------------------------------------------
wire [7:0] d_from_8255;
wire [7:0] ppi_out_a, ppi_out_c;
wire keybeep = ppi_out_c[7];
assign cas_motor =  ppi_out_c[4];
jt8255 PPI
(
	.rst(reset),
	.clk(clk),
	.addr(a[1:0]),
	.din(d_from_cpu),
	.dout(d_from_8255),
	.rdn(rd_n),
	.wrn(wr_n),
	.csn(ppi_n),
	
	.porta_din(8'h0),
	.portb_din(d_from_kb),
	.portc_din(8'h0),

	.porta_dout(ppi_out_a),
	.portb_dout(),
   .portc_dout(ppi_out_c)
 );

//  -----------------------------------------------------------------------------
//  -- Memory mapper
//  -----------------------------------------------------------------------------
wire CS1_n, CS01_n, CS12_n, CS2_n;
wire [3:0] SLTSL_n;
memory_mapper memory_mapper
(
	.reset(reset),
	.addr(a),
	.ppi_n(ppi_n),
	.RAM_CS(ppi_out_a),
	.mreq_n(mreq_n),
	.rfrsh_n(rfrsh_n),
	.rd_n(rd_n),
	.SLTSL_n(SLTSL_n),
	.CS1_n(CS1_n),
	.CS01_n(CS01_n),
	.CS12_n(CS12_n),
	.CS2_n(CS2_n)
); 

//  -----------------------------------------------------------------------------
//  -- CPU data multiplex
//  ----------------------------------------------------------------------------- 
assign d_to_cpu = ~(CS01_n | SLTSL_n[0]) ? rom_q :
						~(mreq_n | rd_n | ~rfrsh_n | SLTSL_n[3]) ? ram_q :
						~(SLTSL_n[1])   ? d_from_cart_1 :
						~(vdp_n | rd_n) ? d_from_vdp :
						~(psg_n | rd_n) ? d_from_psg :
						~(ppi_n | rd_n) ? d_from_8255 : 8'hFF;

//  -----------------------------------------------------------------------------
//  -- Keyboard decoder
//  -----------------------------------------------------------------------------
wire [7:0] d_from_kb;
keyboard msx_key
(
	.reset_n_i(~reset),
	.clk_i(clk),
	.ps2_code_i(ps2_key),
	.kb_addr_i(ppi_out_c[3:0]),
	.kb_data_o(d_from_kb)
);

//  -----------------------------------------------------------------------------
//  -- Sound AY-3-8910
//  -----------------------------------------------------------------------------
wire [7:0] d_from_psg,ay_ch_a, ay_ch_b, ay_ch_c, psg_ioa, psg_iob;
wire psg_bdir = ~(~(~wait_n | powait) | wr_n);
wire psg_bc = ~((~(~rd_n & a[1]) | psg_n ) & ~(~a[0] & psg_bdir));
assign audio = {keybeep, (cas_audio_in & ~cas_motor), 9'h0} | (ay_ch_a + ay_ch_b + ay_ch_c);
wire [5:0] joy_a = {~joy1[5], ~joy1[4], ~joy1[0], ~joy1[1], ~joy1[2], ~joy1[3]};
wire [5:0] joy_b = {~joy0[5], ~joy0[4], ~joy0[0], ~joy0[1], ~joy0[2], ~joy0[3]};
assign psg_ioa = {cas_audio_in,1'b0, psg_iob[6] ? joy_a : joy_b};
YM2149 PSG
(
	.CLK(clk),
	.CE(clk_en_3m58_p),
	.RESET(reset),
	.BDIR(psg_bdir),
	.BC(psg_bc),
	.DI(d_from_cpu),
	.DO(d_from_psg),
	.CHANNEL_A(ay_ch_a),
	.CHANNEL_B(ay_ch_b),
	.CHANNEL_C(ay_ch_c),

	.SEL(1),
	.MODE(1),
	.ACTIVE(),

	.IOA_in(psg_ioa),
	.IOA_out(),
	.IOB_in(8'h0),
	.IOB_out(psg_iob)
);

//  -----------------------------------------------------------------------------
//  -- ROM CARTRIGE
//  -----------------------------------------------------------------------------
wire [7:0] d_from_cart_1;
cart_rom cart1
(
	.clk(clk),
	.addr(a),
	.CS1_n(CS1_n),    
	.CS2_n(CS2_n),
	.CS12_n(CS12_n),
	.SLTSL_n(SLTSL_n[1]),
	.d_to_cpu(d_from_cart_1),

	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_isROM(ioctl_isROM)
);

endmodule