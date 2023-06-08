module fdc
(
   input          clk,
   input          reset,
   input          clk_en,
   input          cs,
   input   [13:0] addr,
   input    [7:0] d_from_cpu,
   output   [7:0] d_to_cpu,
   output         output_en,
   input          rd,
   input          wr,
   input          img_mounted,
   input   [31:0] img_size,
   input          img_readonly,
   output  [31:0] sd_lba,
   output         sd_rd,
   output         sd_wr,
   input          sd_ack,
   input    [8:0] sd_buff_addr,
   input    [7:0] sd_buff_dout,
   output   [7:0] sd_buff_din,
   input          sd_buff_wr
);

logic image_mounted = 1'b0;
logic layout = 1'b0;

always @(posedge clk) begin
   if (img_mounted) begin
      image_mounted <= img_size != 0;
      layout <= img_size > 'h5A000 ? 1'b0 : 1'b1;
   end
end

logic [7:0] sideReg, driveReg;

wire wdcs     = cs & addr[13:2] == 12'b111111111110; 
wire ck1      = cs & addr[13:0] == 14'h3ffc; 
wire ck2      = cs & addr[13:0] == 14'h3ffd; 
wire nu       = cs & addr[13:0] == 14'h3ffe;
wire status   = cs & addr[13:0] == 14'h3fff; 

always @(posedge reset, posedge clk) begin
   if (reset)
      sideReg <= 8'd0;
   else 
      if (ck1 & wr)
         sideReg     <= d_from_cpu;
end

always @(posedge reset, posedge clk) begin
   if (reset) begin
      driveReg    <= 8'd0;
   end else 
      if (ck2 & wr) begin
         driveReg <= d_from_cpu;
      end
end

wire fdd_ready = image_mounted & driveReg[7] & ~driveReg[0];

assign {output_en, d_to_cpu } = status   ? {1'b1, ~drq, ~intrq, 6'b111111}  :
                                ck1      ? {1'b1, sideReg}                  :
                                ck2      ? {1'b1, driveReg & 8'hFB }        :
                                wdcs     ? {1'b1, d_from_wd17}              :
                                nu       ? 9'h1FF                           :           
                                           9'h0FF;
wire [7:0] d_from_wd17;
wire drq, intrq;
wd1793 #(.RWMODE(1), .EDSK(0)) fdc1
(
   .clk_sys(clk),
   .ce(clk_en),
   .reset(reset),
   .io_en(wdcs),
   .rd(rd),
   .wr(wr),
   .addr(addr[1:0]),
   .din(d_from_cpu),
   .dout(d_from_wd17),
   .drq(drq),
   .intrq(intrq),
   .ready(fdd_ready),
   .layout(layout),
   .size_code(3'h2),
   .side(sideReg[0]),
   .img_mounted(img_mounted),
   .wp(img_readonly),
   .img_size(img_size[19:0]),
   .sd_lba(sd_lba),
   .sd_rd(sd_rd),
   .sd_wr(sd_wr),
   .sd_ack(sd_ack),
   .sd_buff_addr(sd_buff_addr),
   .sd_buff_dout(sd_buff_dout),
   .sd_buff_din(sd_buff_din),
   .sd_buff_wr(sd_buff_wr),
   .input_active(1'b0),
   .input_addr(20'h0),
   .input_data(8'h0),
   .input_wr(1'b0),
   .buff_din(8'h0)
);

endmodule
