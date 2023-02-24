module msx2
(
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
   //SHARED VRAM
   output   [15:0] VRAM_address,
   output    [7:0] VRAM_do,
   input     [7:0] VRAM_di_lo,
   input     [7:0] VRAM_di_hi,
   output          VRAM_we_lo,
   output          VRAM_we_hi,
   input MSX::config_t MSXconf
);

//unused signals 
assign hblank = 1'b0;
assign vblank = 1'b0;

//IO PORTS
wire vdp_en = (addr[7:3] == 5'b10011)    & ~iorq_n & m1_n;
wire rtc_en = (addr[7:1] == 7'b1011010)  & ~iorq_n & m1_n;

//Data Bus
assign d_to_cpu = rd_n                             ? 8'hFF                         :
                  vdp_en                           ? d_from_vdp                    :
                  rtc_en                           ? d_from_rtc                    :
                                                     8'hFF;

assign dataBusRQ = ~rd_n & (vdp_en | rtc_en );

//VDP
assign R  = {VideoR,VideoR[5:4]};
assign G  = {VideoG,VideoG[5:4]};
assign B  = {VideoB,VideoB[5:4]};
assign HS = ~VideoHS_n;
assign VS = ~VideoVS_n;
assign DE = VideoDE;

reg iack;
always @(posedge clk21m) begin
   if (reset) iack <= 0;
   else begin
      if (iorq_n  & mreq_n)
         iack <= 0;
      else
         if (req)
            iack <= 1;
   end
end
wire req = ~((iorq_n & mreq_n) | (wr_n & rd_n) | iack);

wire [7:0] d_from_vdp;
wire [5:0] VideoR, VideoG, VideoB;
wire VideoHS_n, VideoVS_n, VideoDE, VideoDLClk, Blank;
wire [16:0] vram_a;
wire        vram_we_n;

vdp vdp (
   .CLK21M(clk21m),
   .RESET(reset),
   .REQ(req & vdp_en),
   .ACK(),
   .WRT(~wr_n),
   .ADR(addr),
   .DBI(d_from_vdp),
   .DBO(d_from_cpu),
   .INT_N(vdp_int_n),
   .PRAMOE_N(),
   .PRAMWE_N(vram_we_n),
   .PRAMADR(vram_a),
   .PRAMDBI({VRAM_di_hi, VRAM_di_lo}),
   .PRAMDBO(VRAM_do),
   .VDPSPEEDMODE(0),
   .CENTERYJK_R25_N(0),
   .PVIDEOR(VideoR),
   .PVIDEOG(VideoG),
   .PVIDEOB(VideoB),
   .PVIDEODE(VideoDE),
   .BLANK_O(Blank),
   .PVIDEOHS_N(VideoHS_n),
   .PVIDEOVS_N(VideoVS_n),
   .PVIDEOCS_N(),
   .PVIDEODHCLK(),
   .PVIDEODLCLK(VideoDLClk),
   .DISPRESO(scandoubler),
   .LEGACY_VGA(1),
   .RATIOMODE(3'b000),
   .NTSC_PAL_TYPE(MSXconf.video_mode == AUTO),
   .FORCED_V_MODE(MSXconf.video_mode == PAL)
);

assign VRAM_we_lo   = ~vram_we_n & VideoDLClk & ~vram_a[16];
assign VRAM_we_hi   = ~vram_we_n & VideoDLClk & vram_a[16];
assign VRAM_address = vram_a[15:0];

//RTC
wire [7:0] d_from_rtc;
rtc rtc
(
   .clk21m(clk21m),
   .reset(reset),
   .setup(reset),
   .rt(rtc_time),
   .clkena(ce_10hz),
   .req(req & rtc_en),
   .ack(),
   .wrt(~wr_n),
   .adr(addr),
   .dbi(d_from_rtc),
   .dbo(d_from_cpu)
);

endmodule
