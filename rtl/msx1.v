module msx1
(
	input         clk,
	input         clk_sdram,
	input         locked_sdram, 
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
	input         vdp_pal,
	output [15:0] audio,
	input  [10:0] ps2_key,
	input   [5:0] joy0,
	input   [5:0] joy1,
	input         ioctl_download,
	input   [7:0] ioctl_index,
	input         ioctl_wr,
	input  [24:0] ioctl_addr,
	input   [7:0] ioctl_dout,
	input         ioctl_isROM,
	input         ioctl_isBIOS,
	output        ioctl_wait,
	input         rom_loaded,
	output        cas_motor,
	input         cas_audio_in,
	input   [3:0] user_mapper,
	    //SDRAM
    inout  [15:0] SDRAM_DQ,
    output [12:0] SDRAM_A,
    output        SDRAM_DQML,
    output        SDRAM_DQMH,
    output  [1:0] SDRAM_BA,
    output        SDRAM_nCS,
    output        SDRAM_nWE,
    output        SDRAM_nRAS,
    output        SDRAM_nCAS,
    output        SDRAM_CKE,
	output        SDRAM_CLK,
	input         img_mounted,
	input  [31:0] img_size,
	input         img_wp,
	output [31:0] sd_lba,
	output        sd_rd,
	output        sd_wr,
	input         sd_ack,
	input   [8:0] sd_buff_addr,
	input   [7:0] sd_buff_dout,
	output  [7:0] sd_buff_din,
	input         sd_buff_wr,
	input         sd_din_strobe,
	input         fdd_enable
);

//  -----------------------------------------------------------------------------
//  -- Audio MIX
//  -----------------------------------------------------------------------------

wire [9:0]  audio_core_mix = ay_ch_mix + {keybeep, 7'h0} + {(cas_audio_in & ~cas_motor),6'h0};
wire [15:0] audio_core    = 16'h0 | {audio_core_mix,3'b000};
wire [16:0] audio_cart    = {sound_cart_1[14],sound_cart_1[14],sound_cart_1};
wire [16:0] audio_mix = audio_cart + audio_core;
wire [15:0] compr[7:0] = '{ {1'b1, audio_mix[13:0], 1'b0}, 16'h8000, 16'h8000, 16'h8000, 16'h7FFF, 16'h7FFF, 16'h7FFF,  {1'b0, audio_mix[13:0], 1'b0}};
assign audio = compr[audio_mix[16:14]];

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
reg wait_n2;
ls74 u1_1
(
   .clr(exwait_n),
   .pre(u1_2_q),
   .clk(clk_en_3m58_p),
   .d(m1_n),
   .q(wait_n)
);

wire u1_2_q;
ls74 u1_2
(
   .clr(1),
   .pre(exwait_n),
   .clk(clk_en_3m58_p),
   .d(wait_n),
   .q(u1_2_q)
);
//  -----------------------------------------------------------------------------
//  -- ROM
//  -----------------------------------------------------------------------------
wire [7:0] rom_q;
spram #(.addr_width(15), .mem_init_file("rtl/rom/8020-00bios.mif"), .mem_name("ROM")) rom
(   
	.clock(clk),
	.address(ioctl_isBIOS ? ioctl_addr[14:0] : a[14:0]),
	.q(rom_q),
	.wren(ioctl_isBIOS),
	.data(ioctl_dout)
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
vdp18_core #(.compat_rgb_g(0)) vdp18
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
	.vblank_o(vblank),
	.is_pal_i(vdp_pal)
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
						~(SLTSL_n[1] | ~rom_loaded)   ? d_from_cart_1 :
						~(SLTSL_n[2] | ~fdd_enable)   ? d_from_cart_2 :
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
wire [7:0] d_from_psg, psg_ioa, psg_iob;
wire [5:0] joy_a = psg_iob[4] ? 6'b111111 : {~joy0[5], ~joy0[4], ~joy0[0], ~joy0[1], ~joy0[2], ~joy0[3]};
wire [5:0] joy_b = psg_iob[5] ? 6'b111111 : {~joy1[5], ~joy1[4], ~joy1[0], ~joy1[1], ~joy1[2], ~joy1[3]};
wire [5:0] joyA = joy_a & {psg_iob[0], psg_iob[1], 4'b1111};
wire [5:0] joyB = joy_b & {psg_iob[2], psg_iob[3], 4'b1111};
assign psg_ioa = {cas_audio_in,1'b0, psg_iob[6] ? joyB : joyA};
wire [9:0] ay_ch_mix;

wire u21_1_q;
ls74 u21_1
(
   .clr(!psg_n),
   .pre(1),
   .clk(clk_en_3m58_p),
   .d(!psg_n),
   .q(u21_1_q)
);

wire u21_2_q;
ls74 u21_2
(
   .clr(!psg_n),
   .pre(1),
   .clk(clk_en_3m58_p),
   .d(u21_1_q),
   .q(u21_2_q)
);

wire psg_e = !(!u21_2_q | clk_en_3m58_p) | psg_n;
wire psg_bc   = !(a[0] | psg_e);
wire psg_bdir = !(a[1] | psg_e);
jt49_bus PSG
(
	.rst_n(~reset),
	.clk(clk),
	.clk_en(clk_en_3m58_n),
	.bdir(psg_bdir),
	.bc1(psg_bc),
	.din(d_from_cpu),
	.sel(0),
	.dout(d_from_psg),
	.sound(ay_ch_mix),
	.A(),
	.B(),
	.C(),
	.IOA_in(psg_ioa),
	.IOA_out(),
	.IOB_in(8'hFF),
	.IOB_out(psg_iob)
);

//  -----------------------------------------------------------------------------
//  -- ROM CARTRIGE
//  -----------------------------------------------------------------------------
wire [7:0] d_from_cart_1;
wire [14:0] sound_cart_1; 
cart_rom cart1
(
	.clk(clk),
	.clk_en(clk_en_3m58_p),
	.reset(reset),
	.addr(a),
	.wr(~wr_n),
	.rd(~rd_n),
	.CS1_n(CS1_n),    
	.CS2_n(CS2_n),
	.CS12_n(CS12_n),
	.SLTSL_n(SLTSL_n[1]),
	.d_from_cpu(d_from_cpu),
	.d_to_cpu(d_from_cart_1),
	.sound(sound_cart_1),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_isROM(ioctl_isROM),
	.ioctl_wait(ioctl_wait),

	.user_mapper(user_mapper),
	.clk_sdram(clk_sdram),
	.locked_sdram(locked_sdram),
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
	.SDRAM_CLK(SDRAM_CLK)
);

wire [7:0] d_from_cart_2;
vy0010 cart2
(
	.clk(clk),
	.clk_en(clk_en_3m58_p),
	.reset(reset),
	.addr(a),
	.d_to_cpu(d_from_cart_2),
	.d_from_cpu(d_from_cpu),
	.wr_n(wr_n),
	.rd_n(rd_n),
	.CS1_n(CS1_n),
	.stlsl_n(SLTSL_n[2]),
	.img_mounted(img_mounted),
	.img_size(img_size),
	.img_wp(img_wp),
	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),
	.sd_din_strobe(sd_din_strobe),
	.fdd_enable(fdd_enable)
);
endmodule
