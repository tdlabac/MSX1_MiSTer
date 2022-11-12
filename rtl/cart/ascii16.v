module cart_asci16
(
    input            clk,
    input            reset,
    input     [24:0] rom_size,
    input     [15:0] addr,
    input      [7:0] d_from_cpu,
    input            wr,
    input            cs,
    input            r_type,
    output    [24:0] mem_addr
);
reg  [7:0] bank0, bank1;
wire [7:0] mask = rom_size[20:13] - 1'd1;

always @(posedge reset, posedge clk) begin
   if (reset) begin
      bank0 <= r_type ? 8'h0f : 8'h00;
      bank1 <= 8'h00;
   end else begin
      if (cs && wr) begin
         if (r_type) begin
            if (addr[15:12] == 4'b0111) begin
               bank1 <= d_from_cpu[4] ? {5'b00010,d_from_cpu[2:0]} : {3'b000,d_from_cpu[4:0]};
            end
         end else begin
            case (addr[15:11])
               5'b01100: // 6000-67ffh
                  bank0 <= d_from_cpu;
               5'b01110: // 7000-77ffh
                  bank1 <= d_from_cpu;
             endcase
         end
      end
   end
end

wire [7:0] bank_base = addr[15] == 0 ? bank0 : bank1; 
assign mem_addr = {2'h0, (bank_base & mask), addr[13:0]};

endmodule
