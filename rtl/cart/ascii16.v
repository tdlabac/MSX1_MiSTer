module cart_asci16
(
    input            clk,
    input            reset,
    input     [24:0] rom_size,
    input     [15:0] addr,
    input      [7:0] d_from_cpu,
    input            wr,
    input            cs,
    output    [24:0] mem_addr
);
reg  [7:0] bank0, bank1;
wire [7:0] mask = rom_size[20:13] - 1'd1;

always @(posedge reset, posedge clk) begin
    if (reset) begin
        bank0 <= 8'h00;
        bank1 <= 8'h00;
    end else begin
        if (cs && wr) begin
            case (addr[15:11])
                5'b01100: // 6000-67ffh
                    bank0 <= d_from_cpu;
                5'b01110: // 7000-77ffh
                    bank1 <= d_from_cpu;
            endcase
        end
    end
end

wire [7:0] bank_base = addr[15] == 0 ? bank0 : bank1;
assign mem_addr = {2'h0, (bank_base & mask), addr[13:0]};

endmodule
