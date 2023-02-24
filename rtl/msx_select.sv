module msx_select
(
   input MSX::config_t MSXconf,
   input          clk21m,
   input          ce_10m7_p,
   input          ce_10hz,
   input          reset,
   input   [15:0] addr,
   input   [7:0]  d_from_cpu,
   output  [7:0]  d_to_cpu,
   output         dataBusRQ,
   input          wr_n,
   input          rd_n,
   input          iorq_n,
   input          mreq_n,
   input          m1_n,
   input          rfrsh_n,
   //RTC
   input   [64:0] rtc_time,
   //VIDEO
   //input    [1:0] vdp_pal,
   //input          border,
   output   [7:0] R,
   output   [7:0] G,
   output   [7:0] B,
   output         HS,
   output         VS,
   output         DE,
   output         vdp_int_n,
   output         hblank,
   output         vblank   
);

assign d_to_cpu  =  MSXconf.typ == MSX1 ? d_to_cpu_msx1  : d_to_cpu_msx2;
assign dataBusRQ =  MSXconf.typ == MSX1 ? dataBusRQ_msx1 : dataBusRQ_msx2;
assign R         =  MSXconf.typ == MSX1 ? R_msx1         : R_msx2;
assign G         =  MSXconf.typ == MSX1 ? G_msx1         : G_msx2;
assign B         =  MSXconf.typ == MSX1 ? B_msx1         : B_msx2;
assign HS        =  MSXconf.typ == MSX1 ? HS_msx1        : HS_msx2;
assign VS        =  MSXconf.typ == MSX1 ? VS_msx1        : VS_msx2;
assign DE        =  MSXconf.typ == MSX1 ? DE_msx1        : DE_msx2;
assign vdp_int_n =  MSXconf.typ == MSX1 ? vdp_int_n_msx1 : vdp_int_n_msx2;
assign hblank    =  MSXconf.typ == MSX1 ? hblank_msx1    : hblank_msx2;
assign vblank    =  MSXconf.typ == MSX1 ? vblank_msx1    : vblank_msx2;

assign VRAM_address = MSXconf.typ == MSX1 ? VRAM_address_msx1 : VRAM_address_msx2;
assign VRAM_we_lo   = MSXconf.typ == MSX1 ? VRAM_we_msx1      : VRAM_we_lo_msx2;
assign VRAM_we_hi   = MSXconf.typ == MSX1 ? 1'b0              : VRAM_we_hi_msx2;
assign VRAM_do      = MSXconf.typ == MSX1 ? VRAM_do_msx1      : VRAM_do_msx2;


wire [7:0] d_to_cpu_msx1;
wire       dataBusRQ_msx1;
wire [7:0] R_msx1, G_msx1, B_msx1;
wire       HS_msx1, VS_msx1, DE_msx1, CE_PIXEL_msx1, vdp_int_n_msx1, hblank_msx1, vblank_msx1;

wire [15:0] VRAM_address, VRAM_address_msx1, VRAM_address_msx2;
wire  [7:0] VRAM_do, VRAM_do_msx1, VRAM_do_msx2;
wire        VRAM_we_lo, VRAM_we_hi, VRAM_we_msx1, VRAM_we_lo_msx2, VRAM_we_hi_msx2;

wire  [7:0] VRAM_di_lo, VRAM_di_hi;

msx1 msx1 (
   .clk21m(clk21m),
   .ce_10m7_p(ce_10m7_p),
   .reset(reset),
   .addr(addr),
   .d_from_cpu(d_from_cpu),
   .d_to_cpu(d_to_cpu_msx1),
   .dataBusRQ(dataBusRQ_msx1),
   .wr_n(MSXconf.typ == MSX2 | wr_n),
   .rd_n(rd_n),
   .iorq_n(iorq_n),
   .mreq_n(mreq_n),
   .m1_n(m1_n),
   .rfrsh_n(rfrsh_n),
   //.vdp_pal(vdp_pal[0]),
   //.border(border),
   .R(R_msx1),
   .G(G_msx1),
   .B(B_msx1),
   .HS(HS_msx1),
   .VS(VS_msx1),
   .DE(DE_msx1),
   .vdp_int_n(vdp_int_n_msx1),
   .hblank(hblank_msx1),
   .vblank(vblank_msx1),
   .rtc_time(rtc_time),
   .VRAM_address(VRAM_address_msx1),
   .VRAM_do(VRAM_do_msx1),
   .VRAM_di(VRAM_di_lo),
   .VRAM_we(VRAM_we_msx1),
   .MSXconf(MSXconf)
);

wire [7:0] d_to_cpu_msx2;
wire       dataBusRQ_msx2;
wire [7:0] R_msx2, G_msx2, B_msx2;
wire       HS_msx2, VS_msx2, DE_msx2, CE_PIXEL_msx2, vdp_int_n_msx2, hblank_msx2, vblank_msx2;

msx2 msx2 (
   .clk21m(clk21m),
   .ce_10m7_p(ce_10m7_p),
   .ce_10hz(ce_10hz),
   .reset(reset),
   .addr(addr),
   .d_from_cpu(d_from_cpu),
   .d_to_cpu(d_to_cpu_msx2),
   .dataBusRQ(dataBusRQ_msx2),
   .wr_n(MSXconf.typ == MSX1 | wr_n),
   .rd_n(rd_n),
   .iorq_n(iorq_n),
   .mreq_n(mreq_n),
   .m1_n(m1_n),
   .rfrsh_n(rfrsh_n),
   //.vdp_pal(vdp_pal),
   //.border(border),
   .scandoubler(MSXconf.scandoubler),
   .R(R_msx2),
   .G(G_msx2),
   .B(B_msx2),
   .HS(HS_msx2),
   .VS(VS_msx2),
   .DE(DE_msx2),
   .vdp_int_n(vdp_int_n_msx2),
   .hblank(hblank_msx2),
   .vblank(vblank_msx2),   
   .rtc_time(rtc_time),
   .VRAM_address(VRAM_address_msx2),
   .VRAM_do(VRAM_do_msx2),
   .VRAM_di_lo(VRAM_di_lo),
   .VRAM_di_hi(VRAM_di_hi),
   .VRAM_we_lo(VRAM_we_lo_msx2),
   .VRAM_we_hi(VRAM_we_hi_msx2),
   .MSXconf(MSXconf)
);

spram #(.addr_width(16),.mem_name("VRA2")) vram_lo
(
   .clock(clk21m),
   .address(VRAM_address),
   .wren(VRAM_we_lo),
   .data(VRAM_do),
   .q(VRAM_di_lo)
);
spram #(.addr_width(16),.mem_name("VRA3")) vram_hi
(
   .clock(clk21m),
   .address(VRAM_address),
   .wren(VRAM_we_hi),
   .data(VRAM_do),
   .q(VRAM_di_hi)
);

endmodule