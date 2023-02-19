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
   //input    [7:0] d_from_fdc_rom,
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

reg image_mounted = 1'b0;

always @(posedge clk) begin
   if (img_mounted) begin
      image_mounted <= img_size != 0;
   end
end


reg side_select, m_on;
//reg in_use = 1'b0;
reg [1:0] ds = 2'b0;
wire io_en    = cs & (addr[13:12] == 2'b11);
//wire rom_en   = addr[15:14] == 2'b01;

wire wdcs     = io_en & addr[11:2] == 10'b1111111110; 
wire ck1      = io_en & addr[11:0] == 12'hffc; 
wire ck2      = io_en & addr[11:0] == 12'hffd; 
wire status   = io_en & addr[11:0] == 12'hfff; 
//wire wd_romce = rom_en & mreq & cs ; 

always @(posedge reset, posedge clk) begin
   if (reset)
      side_select <= 1'b0;
   else 
      if (ck1 & wr)
         side_select <= d_from_cpu[0];
end

always @(posedge reset, posedge clk) begin
   if (reset) begin
      m_on        <= 1'b0;
//      in_use      <= 1'b0;
      ds          <= 2'b00;
   end else 
      if (ck2 & wr) begin
         ds[1:0]  <=  d_from_cpu[1:0];
//         in_use   <=  d_from_cpu[6];
         m_on     <=  d_from_cpu[7];
      end
end

wire ds0 = ds == 2'b00;
//wire ds1_n = ~(ds == 2'b01);
//wire ds2_n = ~(ds == 2'b10);
//wire ds3_n = ~(ds == 2'b11);

wire fdd_ready = image_mounted & m_on & ds0;

assign {output_en, d_to_cpu } = status   ? {1'b1, ~drq, ~intrq, 6'b111111}  :
                                ck1      ? {1'b1, 7'b1111111, ~side_select} :
                                ck2      ? {1'b1, m_on,5'b11110,~ds}        :
                                wdcs     ? {1'b1, d_from_wd17}              :
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
   .layout(1'b0),
   .size_code(3'h2),
   .side(side_select),
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
