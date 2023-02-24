module msx1
(
   input          clk21m,
   input          ce_10m7_p,
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
   input          border,
   input          scandoubler,
   output   [7:0] R,
   output   [7:0] G,
   output   [7:0] B,
   output         HS,
   output         VS,
   output         DE,
   output         vdp_int_n,
   output         hblank,
   output         vblank,
   //VRAM
   output   [15:0] VRAM_address,
   output    [7:0] VRAM_do,
   input     [7:0] VRAM_di,
   output          VRAM_we,
   input MSX::config_t MSXconf
);

//IO PORTS
wire vdp_n = ~((addr[7:3] == 5'b10011)    & ~iorq_n & m1_n);

//Data Bus
assign d_to_cpu = rd_n   ? 8'hFF      :
                 ~vdp_n  ? d_from_vdp :
                           8'hFF;

assign dataBusRQ = ~rd_n & ~vdp_n;

//VDP
assign HS       = ~hsync_n;
assign VS       = ~vsync_n;
assign DE       = blank_n;

wire [7:0] d_from_vdp;
wire hsync_n, vsync_n, blank_n;
vdp18_core #(.compat_rgb_g(0)) vdp18
(
   .clk_i(clk21m),
   .clk_en_10m7_i(ce_10m7_p),
   .reset_n_i(~reset),
   .csr_n_i(vdp_n | rd_n),
   .csw_n_i(vdp_n | wr_n),
   .mode_i(addr[0]),
   .cd_i(d_from_cpu),
   .cd_o(d_from_vdp),
   .int_n_o(vdp_int_n),
   .vram_we_o(VRAM_we),
   .vram_a_o(vram_a),
   .vram_d_o(VRAM_do),
   .vram_d_i(VRAM_di),
   .border_i(MSXconf.border),
   .rgb_r_o(R),
   .rgb_g_o(G),
   .rgb_b_o(B),

   .hsync_n_o(hsync_n),
   .vsync_n_o(vsync_n),
   .hblank_o(hblank),
   .vblank_o(vblank),
   .blank_n_o(blank_n),
   .is_pal_i(MSXconf.video_mode == PAL)
);

wire [13:0] vram_a;
assign VRAM_address = {2'b00, vram_a};

endmodule
