module cart_ascii16
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
/*verilator tracing_off*/
reg  [7:0] bank0[2], bank1[2];
wire [7:0] bank_base;

always @(posedge clk) begin
    if (reset) begin
        bank0 <= '{'h00,'h00};
        bank1 <= '{'h00,'h00};
    end else begin
        if (cs && wr) begin
            case (addr[15:11])
                5'b01100: // 6000-67ffh
                    bank0[slot] <= d_from_cpu;
                5'b01110: // 7000-77ffh
                    bank1[slot] <= d_from_cpu;
                default: ;
            endcase
        end
    end
end

assign bank_base = addr[14] == 1'b1 ? bank0[slot] : bank1[slot];
assign mem_addr = 25'({bank_base, addr[13:0]});
assign mem_unmaped = cs & mem_addr > rom_size;

endmodule