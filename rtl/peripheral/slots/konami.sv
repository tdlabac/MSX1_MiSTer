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
reg  [7:0] bank1[2], bank2[2], bank3[2];
/*verilator tracing_off*/
always @(posedge reset, posedge clk) begin
    if (reset) begin
        bank1 <= '{'h01,'h01};
        bank2 <= '{'h02,'h02};
        bank3 <= '{'h03,'h03};
    end else begin
        if (cs && wr) begin
            case (addr[15:13])
                3'b011: // 6000-7fffh
                    bank1[slot] <= d_from_cpu;
                3'b100: // 8000-9fffh
                    bank2[slot] <= d_from_cpu;
                3'b101: // a000-bfffh
                    bank3[slot] <= d_from_cpu;
                default: ;
            endcase
        end
    end
end

wire [7:0] bank_base = addr[15:13] == 3'b010 ? 8'h00 :
                       addr[15:13] == 3'b011 ? bank1[slot] :
                       addr[15:13] == 3'b100 ? bank2[slot] : bank3[slot];

assign mem_addr = 25'({bank_base, addr[12:0]});
assign mem_unmaped = cs & ((addr < 16'h4000 | addr >= 16'hC000) | (mem_addr > rom_size));
endmodule
