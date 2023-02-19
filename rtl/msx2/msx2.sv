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
   //RAM MAPPER
   output   [7:0] ram_bank,   
   //ROM MAPPER
   //input    [7:0] addr_map,
   //input          map_valid,
   //output         CS0_n,
   //output         CS1_n,
   //output         CS2_n,
   //output         CS01_n,
   //output         CS12_n,
   //output   [3:0] SLTSL_n,
   //output   [3:0] SLT3_n,
   //output   [1:0] slot,
   //output   [1:0] sub_slot,
   input MSX::config_t MSXconf
);

//unused signals 
assign hblank = 1'b0;
assign vblank = 1'b0;

//IO PORTS
wire vdp_en = (addr[7:3] == 5'b10011)    & ~iorq_n & m1_n;
wire rtc_en = (addr[7:1] == 7'b1011010)  & ~iorq_n & m1_n;
wire mpr_en = (addr[7:2] == 6'b111111)   & ~iorq_n & m1_n;
wire mpr_wr = mpr_en & ~wr_n;

//Data Bus
//wire slt3_en    = (addr == 16'hFFFF & ~SLTSL_n[3]);
assign d_to_cpu = rd_n                             ? 8'hFF                         :
                  vdp_en                           ? d_from_vdp                    :
                  rtc_en                           ? d_from_rtc                    :
                  mpr_en                           ? mem_seg[addr[1:0]] | ram_mask :
                  //slt3_en                        	? ~sl3                          :
                                                     8'hFF;

assign dataBusRQ = ~rd_n & (vdp_en | rtc_en | mpr_en );

//MAPPER
//assign CS0_n  = ~(addr[15:14] == 2'b00); //0000-3fff
//assign CS1_n  = ~(addr[15:14] == 2'b01); //4000-7fff
//assign CS2_n  = ~(addr[15:14] == 2'b10); //8000-BFFF
//assign CS01_n = CS0_n & CS1_n;
//assign CS12_n = CS1_n & CS2_n;

//wire [1:0] map = ~map_valid            ? 2'b00         :
//                  addr[15:14] == 2'b00 ? addr_map[1:0] :
//                  addr[15:14] == 2'b01 ? addr_map[3:2] :
//                  addr[15:14] == 2'b10 ? addr_map[5:4] :
//                                         addr_map[7:6] ;

//assign SLTSL_n[0] = ~(map == 2'b00 & ~mreq_n & rfrsh_n);
//assign SLTSL_n[1] = ~(map == 2'b01 & ~mreq_n & rfrsh_n);
//assign SLTSL_n[2] = ~(map == 2'b10 & ~mreq_n & rfrsh_n);
//assign SLTSL_n[3] = ~(map == 2'b11 & ~mreq_n & rfrsh_n);

//assign slot =  map;


//MAPPER SLOT 3
/*
reg [7:0] sl3 = 0;
wire wr = ~wr_n;
always @(posedge reset, posedge clk21m) begin
   if (reset)
      sl3 <= 0;
   else 
      if (slt3_en & wr)
         sl3 <= d_from_cpu;
end

wire [1:0]  SL3CS = addr[15:14] == 2'b00 ? sl3[1:0] :
                    addr[15:14] == 2'b01 ? sl3[3:2] :
                    addr[15:14] == 2'b10 ? sl3[5:4] :
                                           sl3[7:6] ;

assign SLT3_n[0] = ~(SL3CS == 2'b00) | SLTSL_n[3];
assign SLT3_n[1] = ~(SL3CS == 2'b01) | SLTSL_n[3];
assign SLT3_n[2] = ~(SL3CS == 2'b10) | SLTSL_n[3];
assign SLT3_n[3] = ~(SL3CS == 2'b11) | SLTSL_n[3];
*/
//RAM Mapper
assign ram_bank = mem_seg[addr[15:14]];
reg [7:0] mem_seg [0:3];
always @( posedge reset, posedge clk21m ) begin
   if (reset) begin
      mem_seg[0] <= 3;
      mem_seg[1] <= 2;
      mem_seg[2] <= 1;
      mem_seg[3] <= 0;
   end else if (mpr_wr)
      mem_seg[addr[1:0]] <= d_from_cpu & ~ram_mask;
end

wire [7:0] ram_mask = MSXconf.ram_size == SIZE64  ? 8'b11111100 :
                      MSXconf.ram_size == SIZE128 ? 8'b11111000 :
                      MSXconf.ram_size == SIZE256 ? 8'b11110000 :
                                                    8'b11100000 ; //512kB
//                                                  8'b11000000 ; //1024kB
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
