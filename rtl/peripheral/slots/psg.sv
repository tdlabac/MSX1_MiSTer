module psg
(
   input clk,
   input clk_en,
   input reset,
   input [7:0] cpu_dout,
   input [7:0] cpu_addr,
   input       cpu_wr,
   input       cpu_iorq,
   input       cpu_m1,
   input [1:0] cs,
   output signed [15:0] sound
);

logic [3:0] reg_latch;

assign sound = (cs[0] ? {2'b00, sound_PSG1, 4'b0000} : 16'd0) +
               (cs[1] ? {2'b00, sound_PSG2, 4'b0000} : 16'd0);

wire psg_n  = ~((cpu_addr[7:3] == 5'b00010) & cpu_iorq & ~cpu_m1);
logic u21_1_q = 1'b0;
always @(posedge clk,  posedge psg_n) begin
   if (psg_n)
      u21_1_q <= 1'b0;
   else if (clk_en)
      u21_1_q <= ~psg_n;
end

logic u21_2_q = 1'b0;
always @(posedge clk, posedge psg_n) begin
   if (psg_n)
      u21_2_q <= 1'b0;
   else if (clk_en)
      u21_2_q <= u21_1_q;
end

wire psg_e = !(!u21_2_q | clk_en) | psg_n;
wire psg_bc   = !(cpu_addr[0] | psg_e);
wire psg_bdir = !(cpu_addr[1] | psg_e);

wire [9:0] sound_PSG1;
jt49_bus psg1
(
    .rst_n(~reset),
    .clk(clk),
    .clk_en(clk_en),
    .bdir(psg_bdir & cs[0]),
    .bc1(psg_bc & cs[0]),
    .din(cpu_dout),
    .sel(0),
    .dout(),
    .sound(sound_PSG1),
    .A(),
    .B(),
    .C(),
    .sample(),
    .IOA_in(),
    .IOA_out(),
    .IOB_in(),
    .IOB_out()
);

wire [9:0] sound_PSG2;
jt49_bus psg2
(
    .rst_n(~reset),
    .clk(clk),
    .clk_en(clk_en),
    .bdir(psg_bdir & cs[1]),
    .bc1(psg_bc & cs[1]),
    .din(cpu_dout),
    .sel(0),
    .dout(),
    .sound(sound_PSG2),
    .A(),
    .B(),
    .C(),
    .sample(),
    .IOA_in(),
    .IOA_out(),
    .IOB_in(),
    .IOB_out()
);

endmodule