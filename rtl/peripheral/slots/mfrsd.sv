module mapper_mfrsd1
(
   input clk,
   input reset, 
   input cs,
   input [1:0] slot, 
   input [15:0] addr,
   input [7:0] din,
   input wr,
   output logic [3:0] mapper_mask,
   output [19:0] mem_addr,
   output mem_unmaped
);

logic [7:0] configReg, mapperReg, sccMode;
logic [9:0] offsetReg;
logic sccChip;

assign mem_unmaped = cs & 1'd1;

always @(posedge clk) begin
   if (reset) begin
      configReg   <= 8'd3;
      mapperReg   <= 8'd0;
      offsetReg   <= 10'd0;
      mapper_mask <= 4'b1111;
      sccChip     <= 1'b0;
      sccMode     <= 8'd0;
   end else begin
      if (cs) begin
         case(addr)
            16'h7FFC: begin
               if (~configReg[7]) begin
                  configReg <= din;
                  mapper_mask[slot] <= ~din[2];
               end
            end
            16'h7FFD : begin
               if (~mapperReg[1]) begin
                  offsetReg[7:0] <= din;
               end
            end
            16'h7FFE : begin
               if (~mapperReg[1]) begin
                  offsetReg[9:8] <= din[1:0];
               end
            end
            16'h7FFF : begin
               if (~mapperReg[2]) begin
                  mapperReg <= din;
               end
            end
            16'hBFFE,
            16'hBFFF: begin
               if (mapperReg[7:5] == 3'd0) begin
                  sccChip <= din[5];
               end
            end
            default:;
         endcase
      end
   end
end

endmodule



module mapper_mfrsd2
(
   input clk,
   input reset, 
   input  [15:0] cpu_addr,
   input   [7:0] cpu_dout,
   output  [7:0] mapper_dout,
   input         cpu_wr,
   input         cpu_rd,
   input         cpu_iorq,
   input         cpu_m1,
   input         en,
   //input   [7:0] ram_block_count,
   output [21:0] mem_addr
);

msx2_ram_mapper ram_mapper
(
    .mapper_dout(mapper_dout),
    .mapper_addr(mem_addr),
    .ram_block_count(8'd32),
    .*
);

endmodule

module mapper_mfrsd3
(
   input clk,
   input reset, 
   input cs,
   input [15:0] addr,
   input [7:0] din,
   output [7:0] mapper_dout,
   input wr,
   input rd,
   // output oe,
   output [19:0] mem_addr,
   output mem_unmaped,
   output logic sd_rx,
   output logic sd_tx,
   input  [7:0] d_from_sd
);


logic [7:0] bank[4];
//logic selectedCard;

always @(posedge clk) begin
   if (reset) begin
      bank <= '{8'd0, 8'd1, 8'd0, 8'd0};
   end else begin
      if (cs & wr & addr[15:13] == 3'd3) begin // 6000 - 7fff
         if (bank[addr[12:11]] != din) begin
            //$display("Set BANK %d value %x <= %x (addr %x)", addr[12:11], bank[addr[12:11]], din, addr);
            bank[addr[12:11]] <= din;
         end
      end
   end
end



wire SDrom = addr[15:14] == 2'b01 | addr[15:14] == 2'b10;

wire  [1:0] page       = {addr[15] ^ addr[14] ? addr[15] : ~addr[15], addr[13]};
assign mem_addr        = {bank[page][6:0],13'd0} + 20'(addr[12:0]);
wire   mem_valid       = (addr[15:14] == 2'b01 | addr[15:14] == 2'b10);
wire   sd_card_en      = cs & bank[0][7:6] == 2'b01 & addr[15:13] == 3'b010; // 4000 - 5FFF
wire   sd_card_data_en = sd_card_en & rd;
assign mem_unmaped     = cs & (~mem_valid | sd_card_data_en);

assign mapper_dout = sd_card_data_en &  ~addr[12] ? d_from_sd : 8'hFF;

always @(posedge clk) begin
   logic old_wr, old_rd, select_sd;
   sd_rx <= 1'b0;
   sd_tx <= 1'b0;
   if (~old_rd & cs & rd & sd_card_en) sd_rx <= ~select_sd & ~addr[12];
   if (~old_wr & cs & wr & sd_card_en) begin
      if (addr[15:11] == 5'b01011) // >= 5800
         select_sd <= din[0];
      else
         sd_tx <= ~select_sd & ~addr[12];
   end
   old_rd <= rd;
   old_wr <= wr;
end



//.mem_unmaped(fmpac_mem_unmaped),
//.mem_addr(fmpac_addr),
//wire SDrom = addr[15:14] == 2'b01 | addr[15:14] == 2'b10;

/*
always @(posedge clk) begin
   if (bank[0][7:6] == 2'b01 & addr[15:13] = 3'b010) begin   //4000 - 5fff
      if (addr[15:8] >= 8'h58) begin
         selectedCard <= din[0];
      end else begin

      end
   end

end
*/

// 4000 - BFFF WRITE TO FLASH
//unsigned page8kB = (addr >> 13) - 2;
//flashaddr = (bank[page8kB] & 0x7f) * 0x2000 + (addr & 0x1fff) + 0x700000;


endmodule