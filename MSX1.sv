//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
   //Master input clock
   input         CLK_50M,

   //Async reset from top-level module.
   //Can be used as initial reset.
   input         RESET,

   //Must be passed to hps_io module
   inout  [48:0] HPS_BUS,

   //Base video clock. Usually equals to CLK_SYS.
   output        CLK_VIDEO,

   //Multiple resolutions are supported using different CE_PIXEL rates.
   //Must be based on CLK_VIDEO
   output        CE_PIXEL,

   //Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
   //if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
   output [12:0] VIDEO_ARX,
   output [12:0] VIDEO_ARY,

   output  [7:0] VGA_R,
   output  [7:0] VGA_G,
   output  [7:0] VGA_B,
   output        VGA_HS,
   output        VGA_VS,
   output        VGA_DE,    // = ~(VBlank | HBlank)
   output        VGA_F1,
   output [1:0]  VGA_SL,
   output        VGA_SCALER, // Force VGA scaler
   output        VGA_DISABLE, // analog out is off

   input  [11:0] HDMI_WIDTH,
   input  [11:0] HDMI_HEIGHT,
   output        HDMI_FREEZE,

`ifdef MISTER_FB
   // Use framebuffer in DDRAM
   // FB_FORMAT:
   //    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
   //    [3]   : 0=16bits 565 1=16bits 1555
   //    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
   //
   // FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
   output        FB_EN,
   output  [4:0] FB_FORMAT,
   output [11:0] FB_WIDTH,
   output [11:0] FB_HEIGHT,
   output [31:0] FB_BASE,
   output [13:0] FB_STRIDE,
   input         FB_VBL,
   input         FB_LL,
   output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
   // Palette control for 8bit modes.
   // Ignored for other video modes.
   output        FB_PAL_CLK,
   output  [7:0] FB_PAL_ADDR,
   output [23:0] FB_PAL_DOUT,
   input  [23:0] FB_PAL_DIN,
   output        FB_PAL_WR,
`endif
`endif

   output        LED_USER,  // 1 - ON, 0 - OFF.

   // b[1]: 0 - LED status is system status OR'd with b[0]
   //       1 - LED status is controled solely by b[0]
   // hint: supply 2'b00 to let the system control the LED.
   output  [1:0] LED_POWER,
   output  [1:0] LED_DISK,

   // I/O board button press simulation (active high)
   // b[1]: user button
   // b[0]: osd button
   output  [1:0] BUTTONS,

   input         CLK_AUDIO, // 24.576 MHz
   output [15:0] AUDIO_L,
   output [15:0] AUDIO_R,
   output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
   output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

   //ADC
   inout   [3:0] ADC_BUS,

   //SD-SPI
   output        SD_SCK,
   output        SD_MOSI,
   input         SD_MISO,
   output        SD_CS,
   input         SD_CD,

   //High latency DDR3 RAM interface
   //Use for non-critical time purposes
   output        DDRAM_CLK,
   input         DDRAM_BUSY,
   output  [7:0] DDRAM_BURSTCNT,
   output [28:0] DDRAM_ADDR,
   input  [63:0] DDRAM_DOUT,
   input         DDRAM_DOUT_READY,
   output        DDRAM_RD,
   output [63:0] DDRAM_DIN,
   output  [7:0] DDRAM_BE,
   output        DDRAM_WE,

   //SDRAM interface with lower latency
   output        SDRAM_CLK,
   output        SDRAM_CKE,
   output [12:0] SDRAM_A,
   output  [1:0] SDRAM_BA,
   inout  [15:0] SDRAM_DQ,
   output        SDRAM_DQML,
   output        SDRAM_DQMH,
   output        SDRAM_nCS,
   output        SDRAM_nCAS,
   output        SDRAM_nRAS,
   output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
   //Secondary SDRAM
   //Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
   input         SDRAM2_EN,
   output        SDRAM2_CLK,
   output [12:0] SDRAM2_A,
   output  [1:0] SDRAM2_BA,
   inout  [15:0] SDRAM2_DQ,
   output        SDRAM2_nCS,
   output        SDRAM2_nCAS,
   output        SDRAM2_nRAS,
   output        SDRAM2_nWE,
`endif

   input         UART_CTS,
   output        UART_RTS,
   input         UART_RXD,
   output        UART_TXD,
   output        UART_DTR,
   input         UART_DSR,

   // Open-drain User port.
   // 0 - D+/RX
   // 1 - D-/TX
   // 2..6 - USR2..USR6
   // Set USER_OUT to 1 to read from USER_IN.
   input   [6:0] USER_IN,
   output  [6:0] USER_OUT,

   input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////
assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign VGA_F1 = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;

assign AUDIO_S = 1;
assign AUDIO_L = audio;
assign AUDIO_R = audio;
assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign LED_USER = 0;
assign BUTTONS = 0;

//UNUSED signal 
assign mem_data[3]    = 'h00;
assign mem_wren[3]    = 'b0;
assign mem_rden[3]    = 'b0;

localparam VDNUM = 4;

MSX::config_t    MSXconf;
wire             forced_scandoubler;
wire      [21:0] gamma_bus;
wire       [1:0] buttons;
wire      [63:0] status;
wire      [10:0] ps2_key;
wire      [24:0] ps2_mouse;
wire       [5:0] joy0, joy1;
wire             ioctl_download;
wire      [15:0] ioctl_index;
wire             ioctl_wr;
wire             ioctl_wait;
wire      [26:0] ioctl_addr;
wire       [7:0] ioctl_dout;
wire      [31:0] sd_lba[VDNUM];
wire [VDNUM-1:0] sd_rd;
wire [VDNUM-1:0] sd_wr;
wire [VDNUM-1:0] sd_ack;
wire       [8:0] sd_buff_addr;
wire       [7:0] sd_buff_dout;
wire       [7:0] sd_buff_din[VDNUM];
wire             sd_buff_wr;
wire [VDNUM-1:0] hps_img_mounted;
wire      [31:0] hps_img_size;
wire             hps_img_readonly;
wire      [15:0] sdram_sz;
wire      [64:0] rtc;

//[0]     RESET
//[2:1]   Aspect ratio
//[4:3]   Scanlines
//[6:5]   Scale
//[7]     Vertical crop
//[8]     Tape input
//[9]     Tape rewind
//[10]    Reset & Detach
//[11]    MSX type
//[12]    MSX1 VideoMode 
//[14:13] MSX2 VideoMode
//[16:15] MSX2 RAM Size
//[19:17] SLOT A CART TYPE
//[23:20] ROM A TYPE MAPPER
//[25:24] RESERVA
//[28:26] SRAM SIZE 
//[31:29] SLOT B CART TYPE
//[34:32] ROM B TYPE MAPPER
//[37:35] RESERVA
//[38]    BORDER
`include "build_id.v" 
localparam CONF_STR = {
   "MSX1;",
   "-;",
   "O[11],MSX type,MSX2,MSX1;",
   CONF_STR_SLOT_A,
   "H3F6,ROM,Load;",
   CONF_STR_MAPPER_A,
   CONF_STR_SRAM_SIZE_A,
   "-;",
   CONF_STR_SLOT_B,
   "H4F7,ROM,Load;",
   CONF_STR_MAPPER_B,
   "H6-;",
   "H6R[38],SRAM Save;",
   "H6R[39],SRAM Load;",
   "h1-;",
   "h1S3,DSK,Mount Drive A:;",
   "-;",
   "O[8],Tape Input,File,ADC;",
   "H0F8,CAS,Cas File;",
   "H0T9,Tape Rewind;",
   "-;",
   "P1,Video settings;",
   "H2P1O[14:13],Video mode,AUTO,PAL,NTSC;",
   "h2P1O[12],Video mode,PAL,NTSC;",
   "P1O[2:1],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
   "P1O[4:3],Scanlines,No,25%,50%,75%;",
   "P1O[6:5],Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
   "P1O[7],Vertical Crop,No,Yes;",
   //"h2P1O[38],Border,No,Yes;",   //TODO
   "P2,Advanced settings;",
   "h2P2F1,ROM,Load MAIN;",
   "h2P2F2,ROM,Load HANGUL;",	
   "H2P2F1,ROM,Load MAIN;",
   "H2P2F2,ROM,Load SUB;",
   "H2P2F3,ROM,Load DISK;",
   "P2F8,ROM,Load FW A;",
   "P2F9,ROM,Load FW B;",
   CONF_STR_RAM_SIZE,
   "-;",
   "T[0],Reset;",
   "R[10],Reset & Detach ROM Cartridge;",					
   "R[0],Reset and close OSD;",
   "V,v",`BUILD_DATE 
};

wire [7:0] status_menumask;
assign status_menumask[0] = MSXconf.cas_audio_src == CAS_AUDIO_ADC;
assign status_menumask[1] = fdc_enabled;
assign status_menumask[2] = MSXconf.typ == MSX1;
assign status_menumask[3] = ROM_A_load_hide;
assign status_menumask[4] = ROM_B_load_hide;
assign status_menumask[5] = sram_A_select_hide;
assign status_menumask[6] = sram_loadsave_hide;
assign status_menumask[7] = sdram_size == 2'd0;

hps_io #(.CONF_STR(CONF_STR),.VDNUM(VDNUM)) hps_io
(
   .clk_sys(clk21m),
   .HPS_BUS(HPS_BUS),
   .EXT_BUS(),
   .gamma_bus(gamma_bus),
   .forced_scandoubler(forced_scandoubler),
   .buttons(buttons),
   .status(status),
   .status_menumask(status_menumask),
   .ps2_key(ps2_key),
   .ps2_mouse(ps2_mouse),
   .joystick_0(joy0),
   .joystick_1(joy1),
   .ioctl_download(ioctl_download),
   .ioctl_index(ioctl_index),
   .ioctl_wr(ioctl_wr),
   .ioctl_addr(ioctl_addr),
   .ioctl_dout(ioctl_dout),
   .ioctl_wait(ioctl_wait),
   .img_mounted(hps_img_mounted),
   .img_size(hps_img_size),
   .img_readonly(hps_img_readonly),
   .sd_lba(sd_lba),
   .sd_rd(sd_rd),
   .sd_wr(sd_wr),
   .sd_ack(sd_ack),
   .sd_buff_addr(sd_buff_addr),
   .sd_buff_dout(sd_buff_dout),
   .sd_buff_din(sd_buff_din),
   .sd_buff_wr(sd_buff_wr),
   .sdram_sz(sdram_sz),
   .RTC(rtc)
);

wire [24:0] mem_addr[8];
wire  [7:0] mem_data[8], mem_q[8];
wire  [7:0] mem_wren,mem_rden;
wire  [3:0] cart_rom_offset[2];
wire [24:0] cart_rom_size[2];
wire  [5:0] cart_rom_auto_mapper[2];
wire  [2:0] cart_sram_size[2];
wire        ioctl_waitROM, img_reset;
wire  [1:0] sdram_size = sdram_sz[15] ? sdram_sz[1:0] : 2'b00;

msx_memory msx_memory
(
   .clk(clk21m),
   .clk_sdram(clk_sdram),
   .locked_sdram(locked_sdram),
   .reset(reset),
   .reset_req(img_reset),
   .sdram_size(sdram_size),
   .cart_changed(cart_changed),
   //FW ROM/SRAM
   .img_mounted(hps_img_mounted[2:0]),
   .img_readonly(hps_img_readonly),
   .img_size(hps_img_size),
   .sd_lba(sd_lba[0:2]),
   .sd_rd(sd_rd[2:0]),
   .sd_wr(sd_wr[2:0]),
   .sd_ack(sd_ack[2:0]),
   .sd_buff_addr(sd_buff_addr),
   .sd_buff_dout(sd_buff_dout),
   .sd_buff_din(sd_buff_din[0:2]),
   .sd_buff_wr(sd_buff_wr),
   .sram_write(status[38]),
   .sram_load(status[39]),
   .sram_size(sram_size),
   //ROM
   .rom_eject(rom_eject),
   .cart_rom_offset(cart_rom_offset),
   .cart_rom_size(cart_rom_size),
   .cart_rom_auto_mapper(cart_rom_auto_mapper),
   .cart_sram_size(cart_sram_size),
   .ioctl_wait(ioctl_waitROM),
   //Memory
   .mem_addr(mem_addr),
   .mem_data(mem_data),
   .mem_wren(mem_wren),
   .mem_rden(mem_rden),
   .mem_q(mem_q),
   .*
);

/////////////////   CONFIG   /////////////////
wire [2:0] cart_type[2], sram_size[2];
wire [1:0] cart_changed, rom_eject;
wire [5:0] mapper_A, mapper_B;
wire       sram_A_select_hide, fdc_enabled, ROM_A_load_hide, ROM_B_load_hide,sram_loadsave_hide,config_reset;

msx_config msx_config 
(
   .clk(clk21m),
   .reset(reset),
   .reset_request(config_reset),
   .HPS_status(status),
   .scandoubler(scandoubler),
   .mapper_detected(cart_rom_auto_mapper),
   .sram_size_detected(cart_sram_size),
   .sdram_size(sdram_size),
   .cart_type(cart_type),
   .cart_changed(cart_changed),
   .rom_eject(rom_eject),
   .mapper_A(mapper_A),
   .mapper_B(mapper_B),
   .sram_size(sram_size),
   .sram_A_select_hide(sram_A_select_hide),
   .sram_loadsave_hide(sram_loadsave_hide),
   .ROM_A_load_hide(ROM_A_load_hide),
   .ROM_B_load_hide(ROM_B_load_hide),
   .fdc_enabled(fdc_enabled),
   .MSXconf(MSXconf)
);

/////////////////   CARTIGE   /////////////////
assign mem_addr[MEM_DSK]  = cart_addr[13:0];

wire [7:0] cart_d_to_cpu_A = cart_type[0] == CART_TYPE_FDC ? cart_d_to_cpu_FDC : cart_d_to_cpu_A_tmp;
wire [7:0] cart_d_to_cpu_FDC;
fdc fdc
(
   .clk(clk21m),
   .reset(reset),
   .clk_en(ce_3m58_p),
   .cs(fdc_enabled | en_FDC),
   .mirror_rom(0),
   .addr(cart_addr),
   .d_from_cpu(cart_d_from_cpu),
   .d_to_cpu(cart_d_to_cpu_FDC),
   .mreq(~cart_mreq_n),
   .rd(~cart_rd_n),
   .wr(~cart_wr_n),
   .d_from_fdc_rom(mem_q[MEM_DSK]),
   .img_mounted(hps_img_mounted[3]),
   .img_size(hps_img_size),
   .img_wp(hps_img_readonly),
   .sd_lba(sd_lba[3]),
   .sd_rd(sd_rd[3]),
   .sd_wr(sd_wr[3]),
   .sd_ack(sd_ack[3]),
   .sd_buff_addr(sd_buff_addr),
   .sd_buff_dout(sd_buff_dout),
   .sd_buff_din(sd_buff_din[3]),
   .sd_buff_wr(sd_buff_wr)
); 

wire  [7:0] cart_d_to_cpu_A_tmp;
wire [14:0] cart_sound_A;
cart_rom ROM_slot_A
(
   .clk(clk21m),
   .clk_en(ce_3m58_p),
   .reset(reset),
   .addr(cart_addr),
   .wr(~cart_wr_n),
   .rd(~cart_rd_n),
   .iorq(~cart_iorq_n),
   .m1(~cart_m1_n),
   .SLTSL_n(cart_SLTSL1_n),
   .d_from_cpu(cart_d_from_cpu),
   .d_to_cpu(cart_d_to_cpu_A_tmp),
   .sound(cart_sound_A),
   .mapper(mapper_A),
   .cart_type(cart_type[0]),
   .sram_size(sram_size[0]),
   .rom_offset(cart_rom_offset[0]),
   .rom_size(cart_rom_size[0]),
   //MEMORY
   .mem_addr(mem_addr[4:5]),
   .mem_data(mem_data[4:5]),
   .mem_wren(mem_wren[5:4]),
   .mem_rden(mem_rden[5:4]),
   .mem_q(mem_q[4:5])
);

wire  [7:0] cart_d_to_cpu_B;
wire [14:0] cart_sound_B;
cart_rom ROM_slot_B
(
   .clk(clk21m),
   .clk_en(ce_3m58_p),
   .reset(reset),
   .addr(cart_addr),
   .wr(~cart_wr_n),
   .rd(~cart_rd_n),
   .iorq(~cart_iorq_n),
   .mreq(~cart_mreq_n),
   .m1(~cart_m1_n),
   .SLTSL_n(cart_SLTSL2_n),
   .d_from_cpu(cart_d_from_cpu),
   .d_to_cpu(cart_d_to_cpu_B),
   .sound(cart_sound_B),
   .mapper(mapper_B),
   .cart_type(cart_type[1]),
   .sram_size(sram_size[1]),
   .rom_offset(cart_rom_offset[1]),
   .rom_size(cart_rom_size[1]),
   //MEMORY
   .mem_addr(mem_addr[6:7]),
   .mem_data(mem_data[6:7]),
   .mem_wren(mem_wren[7:6]),
   .mem_rden(mem_rden[7:6]),
   .mem_q(mem_q[6:7])
);

/////////////////   CLOCKS   /////////////////
wire clk21m, clk_sdram, locked_sdram;
pll pll
(
   .refclk(CLK_50M),
   .rst(0),
   .outclk_0(clk_sdram), //85.909090
   .outclk_1(clk21m),    //21.477270
   .locked(locked_sdram)
);

wire ce_10m7_p, ce_10m7_n, ce_5m39_p, ce_5m39_n, ce_3m58_p, ce_3m58_n, ce_10hz;
clock clock
(
   .*
);

/////////////////    RESET   /////////////////
wire reset = RESET | status[0] | status[10] | img_reset | config_reset;

///////////////// Computer /////////////////

wire [7:0] R,G,B;
wire hsync, vsync, blank_n, hblank, vblank, ce_pix;
wire [15:0] audio;
wire [15:0] cart_addr;
wire  [7:0] cart_d_from_cpu;
wire        cart_wr_n, cart_rd_n, cart_SLTSL1_n, cart_SLTSL2_n, cart_iorq_n, cart_m1_n, cart_mreq_n, en_FDC; 

msx MSX
(
   .clk21m(clk21m),
   .ce_10m7_p(ce_10m7_p),
   .ce_3m58_p(ce_3m58_p),
   .ce_3m58_n(ce_3m58_n),
   .ce_10hz(ce_10hz),
   .reset(reset),
   .R(R),
   .G(G),
   .B(B),
   .HS(hsync),
   .DE(blank_n),
   .VS(vsync),
   .hblank(hblank),
   .vblank(vblank),
   .audio(audio),
   .ps2_key(ps2_key),
   .joy0(joy0),
   .joy1(joy1),
   //CART SLOT interface
   .cart_addr(cart_addr),
   .cart_d_from_cpu(cart_d_from_cpu),
   .cart_d_to_cpu_A(cart_d_to_cpu_A),
   .cart_d_to_cpu_B(cart_d_to_cpu_B),
   .cart_d_to_cpu_FDC(cart_d_to_cpu_FDC),
   .cart_wr_n(cart_wr_n),
   .cart_rd_n(cart_rd_n),
   .cart_iorq_n(cart_iorq_n),
   .cart_mreq_n(cart_mreq_n),
   .cart_m1_n(cart_m1_n),
   .cart_SLTSL1_n(cart_SLTSL1_n),
   .cart_SLTSL2_n(cart_SLTSL2_n),
   .cart_sound_A(cart_sound_A),
   .cart_sound_B(cart_sound_B),
   .en_FDC(en_FDC),
   //MEMORY
   .mem_addr(mem_addr[0:2]),
   .mem_data(mem_data[0:2]),
   .mem_wren(mem_wren[2:0]),
   .mem_rden(mem_rden[2:0]),
   .mem_q(mem_q[0:2]),
   .cas_motor(motor),
   .cas_audio_in(MSXconf.cas_audio_src == CAS_AUDIO_FILE  ? CAS_dout : tape_in),
   .rtc_time(rtc),
   .MSXconf(MSXconf)
);

/////////////////  VIDEO  /////////////////
assign CLK_VIDEO = clk21m;
assign CE_PIXEL = ce_10m7_p;
assign VGA_SL = status[4:3];

wire  scandoubler = forced_scandoubler || status[4:3];
wire vcrop_en = status[7];
reg [9:0] vcrop;
reg wide;
always @(posedge CLK_VIDEO) begin
	vcrop <= 0;
	wide <= 0;
	if(HDMI_WIDTH >= (HDMI_HEIGHT + HDMI_HEIGHT[11:1]) && !scandoubler) begin
		if(HDMI_HEIGHT == 480)  vcrop <= 240;
		if(HDMI_HEIGHT == 600)  begin vcrop <= 200; wide <= vcrop_en; end
		if(HDMI_HEIGHT == 720)  vcrop <= 240;
		if(HDMI_HEIGHT == 768)  vcrop <= 256; // NTSC mode has 250 visible lines only!
		if(HDMI_HEIGHT == 800)  begin vcrop <= 200; wide <= vcrop_en; end
		if(HDMI_HEIGHT == 1080) vcrop <= 10'd216;
		if(HDMI_HEIGHT == 1200) vcrop <= 240;
	end
	else if(HDMI_WIDTH >= 1440 && !scandoubler) begin
		// 1920x1440 and 2048x1536 are 4:3 resolutions and won't fit in the previous if statement ( width > height * 1.5 )
		if(HDMI_HEIGHT == 1440) vcrop <= 240;
		if(HDMI_HEIGHT == 1536) vcrop <= 256;
	end
end


wire [1:0] ar = status[2:1];
video_freak video_freak
(
	.*,
	.VGA_DE_IN(vga_de),
   .VGA_VS(vsync),
	.ARX((!ar) ? (wide ? 12'd340 : 12'd400) : (ar - 1'd1)),
	.ARY((!ar) ? 12'd300 : 12'd0),
	.CROP_SIZE(vcrop_en ? vcrop : 10'd0),
	.CROP_OFF(0),
	.SCALE(status[6:5])
);

wire vga_de;
gamma_fast gamma
(
	.clk_vid(CLK_VIDEO),
	.ce_pix(CE_PIXEL),
	.gamma_bus(gamma_bus),
	.HSync(hsync),
	.VSync(vsync),
	.DE(blank_n),
	.RGB_in({R,G,B}),

	.HSync_out(VGA_HS),
	.VSync_out(VGA_VS),
	.DE_out(vga_de),
	.RGB_out({VGA_R,VGA_G,VGA_B})
);

/////////////////  Tape In   /////////////////
wire tape_in = tape_adc_act & tape_adc;
wire tape_adc, tape_adc_act;
ltc2308_tape #(.ADC_RATE(120000), .CLK_RATE(21477272)) tape
(
  .clk(clk21m),
  .ADC_BUS(ADC_BUS),
  .dout(tape_adc),
  .active(tape_adc_act)
);

///////////////// CAS EMULATE /////////////////
assign DDRAM_CLK    = clk21m;
wire   ioctl_isCAS  = ioctl_download & (ioctl_index[5:0] == 6'd8);
assign ioctl_wait   = (ioctl_isCAS & ~buff_mem_ready) | ioctl_waitROM;
wire buff_mem_ready;
ddram buffer
(
   .*,
   .addr(ioctl_isCAS ? ioctl_addr[26:0] : CAS_addr),
   .dout(CAS_di),
   .din(ioctl_dout),
   .we(ioctl_wr && ioctl_isCAS),
   .rd(~ioctl_isCAS && CAS_rd),
   .ready(buff_mem_ready),
   .reset(reset)
);

wire motor;
wire CAS_dout;
wire play, rewind;
wire CAS_rd;
wire [26:0] CAS_addr;
wire [7:0] CAS_di;
assign play = ~motor;
assign rewind = status[9] | ioctl_isCAS | reset;
tape cass 
(
   .clk(clk21m),
   .ce_5m3(ce_5m39_p),
   .cas_out(CAS_dout),
   .ram_a(CAS_addr),
   .ram_di(CAS_di),
   .ram_rd(CAS_rd),
   .buff_mem_ready(buff_mem_ready),
   .play(play),
   .rewind(rewind)
);

endmodule
