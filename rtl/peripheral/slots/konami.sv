module cart_konami
(
    input            clk,
    input            reset,
    input     [24:0] rom_size,
    input     [15:0] addr,
    input      [7:0] d_from_cpu,
    input            wr,
    input            cs,
    input            slot,
    output           mem_unmaped,
    output    [24:0] mem_addr
);

   wire [24:0] mem_addr_A, mem_addr_B;
   wire        mem_unmaped_A, mem_unmaped_B;

   assign mem_addr     = slot ? mem_addr_B    : mem_addr_A;
   assign mem_unmaped  = slot ? mem_unmaped_B : mem_unmaped_A;
   konami konami_A
   (
      .mem_addr(mem_addr_A),
      .mem_unmaped(mem_unmaped_A),
      .cs(cs & ~slot),
      .*
   );

   konami konami_B
   (
      .mem_addr(mem_addr_B),
      .mem_unmaped(mem_unmaped_B),
      .cs(cs & slot),
      .*
   );

endmodule

module konami
(
    input            clk,
    input            reset,
    input     [24:0] rom_size,
    input     [15:0] addr,
    input      [7:0] d_from_cpu,
    input            wr,
    input            cs,
    output           mem_unmaped,
    output    [24:0] mem_addr
);
reg  [7:0] bank1, bank2, bank3;

always @(posedge reset, posedge clk) begin
    if (reset) begin
        bank1 <= 8'h01;
        bank2 <= 8'h02;
        bank3 <= 8'h03;
    end else begin
        if (cs && wr) begin
            case (addr[15:13])
                3'b011: // 6000-7fffh
                    bank1 <= d_from_cpu;
                3'b100: // 8000-9fffh
                    bank2 <= d_from_cpu;
                3'b101: // a000-bfffh
                    bank3 <= d_from_cpu;
                default: ;
            endcase
        end
    end
end

wire [7:0] bank_base = addr[15:13] == 3'b010 ? 8'h00 :
                       addr[15:13] == 3'b011 ? bank1 :
                       addr[15:13] == 3'b100 ? bank2 : bank3;

assign mem_addr = 25'({bank_base, addr[12:0]});
assign mem_unmaped = cs & ((addr < 16'h4000 | addr >= 16'hC000) | (mem_addr > rom_size));
endmodule
