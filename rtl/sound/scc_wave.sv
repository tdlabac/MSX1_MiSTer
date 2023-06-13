//
// scc_wave.sv
//   Sound generator with wave table
//   Revision 1.00
//
// Copyright (c) 2006 Kazuhiro Tsujikawa (ESE Artists' factory)
// All rights reserved.
//
// Redistribution and use of this source code or any derivative works, are
// permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
// 3. Redistributions may not be sold, nor may they be used in a commercial
//    product or activity without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
// PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
// OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

//  2007/01/31  modified by t.hara
//  2023/05/24  rewriting from VHDL to SystemVerilog, added scc+ mode by Molekula


module scc_wave
(
   input                clk,
   input                clkena,
   input                reset,
   input                req,
   output               ack,
   input                wrt,
   input          [7:0] adr,
   input          [7:0] dbo,
   output         [7:0] dbi,
   output signed [14:0] wave,
   input                sccPlusChip,
   input                sccPlusMode
);
/*verilator tracing_off*/
//scc registers
logic [11:0] reg_freq[5];
logic  [3:0] reg_vol[5];
logic  [4:0] reg_ch_sel;
logic  [7:0] reg_mode_sel;

//internal register
logic  [4:0] ff_rst;
logic  [4:0] ff_ptr[5];
logic  [2:0] ff_ch_num;
logic        ff_req_dl;
logic  [7:0] ff_wave_dat;
logic  [2:0] ff_ch_num_dl;
logic [14:0] ff_mix;
logic [14:0] ff_wave;

assign ack = ff_req_dl;
wire mode = sccPlusMode & sccPlusChip;

// scc register access
always @(posedge clk) begin
   if (reset) begin
      reg_freq     <= '{12'd0, 12'd0, 12'd0, 12'd0, 12'd0};
      reg_vol      <= '{ 4'd0,  4'd0,  4'd0,  4'd0,  4'd0};
      reg_ch_sel   <= 5'd0;
      reg_mode_sel <= 8'd0;
      ff_rst       <= 5'd0;
      ff_req_dl    <= 1'd0;
   end else begin
      if (req & ~ff_req_dl & adr[7:5] == {2'b10, mode} & wrt) begin
         case(adr[3:0])
            4'b0000: begin reg_freq[0][7:0]  <= dbo[7:0]; ff_rst[0] <= reg_mode_sel[5]; end
            4'b0001: begin reg_freq[0][11:8] <= dbo[3:0]; ff_rst[0] <= reg_mode_sel[5]; end
            4'b0010: begin reg_freq[1][7:0]  <= dbo[7:0]; ff_rst[1] <= reg_mode_sel[5]; end
            4'b0011: begin reg_freq[1][11:8] <= dbo[3:0]; ff_rst[1] <= reg_mode_sel[5]; end
            4'b0100: begin reg_freq[2][7:0]  <= dbo[7:0]; ff_rst[2] <= reg_mode_sel[5]; end
            4'b0101: begin reg_freq[2][11:8] <= dbo[3:0]; ff_rst[2] <= reg_mode_sel[5]; end
            4'b0110: begin reg_freq[3][7:0]  <= dbo[7:0]; ff_rst[3] <= reg_mode_sel[5]; end
            4'b0111: begin reg_freq[3][11:8] <= dbo[3:0]; ff_rst[3] <= reg_mode_sel[5]; end
            4'b1000: begin reg_freq[4][7:0]  <= dbo[7:0]; ff_rst[4] <= reg_mode_sel[5]; end
            4'b1001: begin reg_freq[4][11:8] <= dbo[3:0]; ff_rst[4] <= reg_mode_sel[5]; end
            4'b1010: begin reg_vol[0] [3:0]  <= dbo[3:0]; end
            4'b1011: begin reg_vol[1] [3:0]  <= dbo[3:0]; end
            4'b1100: begin reg_vol[2] [3:0]  <= dbo[3:0]; end
            4'b1101: begin reg_vol[3] [3:0]  <= dbo[3:0]; end
            4'b1110: begin reg_vol[4] [3:0]  <= dbo[3:0]; end
            4'b1111: begin reg_ch_sel [4:0]  <= dbo[4:0]; end
         endcase
      end else begin
         if (clkena) begin
            ff_rst <= 5'd0;
         end
      end
      if (req & adr[7:5] == {2'b11, ~sccPlusChip} & wrt) begin
         reg_mode_sel <= dbo;
      end
      ff_req_dl <= req;
   end
end

// tone generator
always @(posedge clk) begin
   logic [11:0] ff_cnt[5];
   if (reset) begin
      ff_ptr <= '{ 5'd0,  5'd0,  5'd0,  5'd0,  5'd0};
      ff_cnt <= '{12'd0, 12'd0, 12'd0, 12'd0, 12'd0};
   end else begin
      if (clkena) begin
         if (reg_freq[0][11:3] == 9'd0 | ff_rst[0]) begin
            ff_ptr[0] <= 5'd0;
            ff_cnt[0] <= reg_freq[0];
         end else if (ff_cnt[0] == 12'd0) begin
               ff_ptr[0] <= ff_ptr[0] + 5'd1;
               ff_cnt[0] <= reg_freq[0];
            end else begin
               ff_cnt[0] <= ff_cnt[0] - 12'd1;
            end

         if (reg_freq[1][11:3] == 9'd0 | ff_rst[1]) begin
            ff_ptr[1] <= 5'd0;
            ff_cnt[1] <= reg_freq[1];
         end else begin
            if (ff_cnt[1] == 12'd0) begin
               ff_ptr[1] <= ff_ptr[1] + 5'd1;
               ff_cnt[1] <= reg_freq[1];
            end else begin
               ff_cnt[1] <= ff_cnt[1] - 12'd1;
            end
         end

         if (reg_freq[2][11:3] == 9'd0 | ff_rst[2]) begin
            ff_ptr[2] <= 5'd0;
            ff_cnt[2] <= reg_freq[2];
         end else begin
            if (ff_cnt[2] == 12'd0) begin
               ff_ptr[2] <= ff_ptr[2] + 5'd1;
               ff_cnt[2] <= reg_freq[2];
            end else begin
               ff_cnt[2] <= ff_cnt[2] - 12'd1;
            end
         end

         if (reg_freq[3][11:3] == 9'd0 | ff_rst[3]) begin
            ff_ptr[3] <= 5'd0;
            ff_cnt[3] <= reg_freq[3];
         end else begin
            if (ff_cnt[3] == 12'd0) begin
               ff_ptr[3] <= ff_ptr[3] + 5'd1;
               ff_cnt[3] <= reg_freq[3];
            end else begin
               ff_cnt[3] <= ff_cnt[3] - 12'd1;
            end
         end

         if (reg_freq[4][11:3] == 9'd0 | ff_rst[4]) begin
            ff_ptr[4] <= 5'd0;
            ff_cnt[4] <= reg_freq[4];
         end else begin
            if (ff_cnt[4] == 12'd0) begin
               ff_ptr[4] <= ff_ptr[4] + 5'd1;
               ff_cnt[4] <= reg_freq[4];
            end else begin
               ff_cnt[4] <= ff_cnt[4] - 12'd1;
            end
         end
      end
   end
end

// wave memory control
assign     dbi             = ram_ce ? ram_dbi : 8'hFF;
wire       ram_ce          = req & ram_adr < (mode ? 8'hA0 : 8'h80);
wire       ram_we          = ram_ce & ~ff_req_dl & wrt;
wire [2:0] ff_wawe_num_max = mode ? 3'd4 : 3'd3;
wire [2:0] ff_ch_num_max   = ff_ch_num > ff_wawe_num_max ? ff_wawe_num_max : ff_ch_num;
wire [7:0] w_wave_adr = {ff_ch_num_max, ff_ptr[ff_ch_num]};
wire [7:0] ram_adr         = ~wrt & sccPlusChip & ~sccPlusMode & adr[7:5] == 3'b101 ? {3'b011,adr[4:0]} : adr;

// delay signal
always @(posedge clk) begin
   if (reset) begin
      ff_wave_dat   <= 8'd0;
      ff_ch_num_dl  <= 3'd0;
   end else begin
      ff_wave_dat   <= wave_dbi;
      ff_ch_num_dl  <= ff_ch_num;
   end
end

wire [2:0] ff_ch_num_dl_sel = ff_ch_num_dl - 3'd1;
wire       w_ch_bit         = ff_ch_num_dl_sel > 3'd4 ? 1'b0        : reg_ch_sel[ff_ch_num_dl_sel];
wire [3:0] w_ch_vol         = ff_ch_num_dl_sel > 3'd4 ? 4'b0        : reg_vol[ff_ch_num_dl_sel];
wire [7:0] w_wave           = w_ch_bit                ? ff_wave_dat : 8'd0;


always @(posedge clk) begin
   if (reset) 
      ff_ch_num <= 3'd0;
   else 
      if (ff_ch_num == 3'd5)
         ff_ch_num <= 3'd0;
      else
         ff_ch_num <= ff_ch_num + 3'd1;
end

// mixer
always @(posedge clk) begin
   if (reset)
      ff_mix <= 15'd0;
   else
      if (ff_ch_num_dl == 3'd0)
         ff_mix <= 15'd0;
      else
         ff_mix <= {w_mul[11], w_mul[11], w_mul[11], w_mul} + ff_mix;
end

// wave out
always @(posedge clk) begin
   if (reset)
      ff_wave <= 15'd0;
   else
      if (ff_ch_num_dl == 3'd0)
         ff_wave <= ff_mix;
end

assign wave = ff_wave;

// Clear waveform ram
logic [7:0] clear_cnt;
logic       clear_wr;
logic       clear_wave;
always @(posedge clk) begin
   logic old_reset;
   clear_wr <= 1'b0;
   if (clear_wr) clear_cnt <= clear_cnt - 8'b1;
   if (reset & ~old_reset) begin
      clear_cnt <= 8'h9F;
      clear_wave <= 1'b1;
   end
   else
      if (~clear_wr)
         if (clear_cnt != 8'hFF)
            clear_wr <= 1'b1;
         else 
            clear_wave <= 1'b0;
   old_reset <= reset;
end

wire [7:0] wave_dbi, ram_dbi;
wave_ram wavemem
(
   .adr_a(clear_wave ? clear_cnt : ram_adr),
   .adr_b(w_wave_adr), 
   .clk(clk),
   .we_a(clear_wave ? clear_wr : ram_we),
   .data_a(clear_wave ? 8'hFF : dbo),
   .q_a(ram_dbi),
   .q_b(wave_dbi)
);

wire signed [11:0] w_mul;
scc_wave_mul u_mul
(
   .a(w_wave),
   .b(w_ch_vol),
   .c(w_mul)
);
endmodule

module wave_ram
(
   input  [7:0] adr_a,
   input  [7:0] adr_b,
   input        clk,
   input        we_a,
   input  [7:0] data_a,
   output [7:0] q_a,
   output [7:0] q_b
);

logic [7:0] blkram[256];
logic [7:0] iadr_a, iadr_b;

always @(posedge clk) begin
   if (we_a) begin
      blkram[adr_a] <= data_a;
   end
   iadr_b <= adr_b;
end

assign q_b = blkram[iadr_b];
assign q_a = blkram[adr_a];
endmodule

module scc_wave_mul
(
   input  signed  [7:0] a,
   input          [3:0] b,
   output signed [11:0] c
);

wire signed [12:0] w_mul = a * signed'({1'b0,b});
assign c = w_mul[11:0];
endmodule