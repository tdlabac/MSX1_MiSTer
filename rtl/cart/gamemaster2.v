module cart_gamemaster2
(
    input            clk,
    input            reset,
    input     [15:0] addr,
    input      [7:0] d_from_cpu,
    input            wr,
    input            cs,
    output    [24:0] mem_addr,
    output    [12:0] sram_addr,
    output           sram_we,
    output           sram_oe
);
reg  [7:0] bank1, bank2, bank3;

always @(posedge reset, posedge clk) begin
    if (reset) begin
        bank1 <= 8'h01;
        bank2 <= 8'h02;
        bank3 <= 8'h03;
    end else begin
        if (cs && wr) begin
            case (addr[15:12])
                4'b0110: // 6000-6fffh
                    bank1 <= d_from_cpu;
                4'b1000: // 8000-8fffh
                    bank2 <= d_from_cpu;
                4'b1010: // a000-afffh
                    bank3 <= d_from_cpu;
            endcase
        end
    end
end

wire [7:0] bank_base = addr[15:13] == 3'b010 ? 8'h00 :
                       addr[15:13] == 3'b011 ? bank1 :
                       addr[15:13] == 3'b100 ? bank2 : bank3;

assign mem_addr  = {3'h0, (bank_base[3:0]), addr[12:0]};
assign sram_addr = {bank_base[5], addr[11:0]};
assign sram_oe   = cs && bank_base[4];
assign sram_we   = cs && bank_base[4] && addr[15:12] == 4'b1011 && wr;

endmodule
