module cart_konami
(
    input            clk,
    input            reset,
    input     [24:0] rom_size,
    input     [15:0] cpu_addr,
    input      [7:0] din,
    input            cpu_mreq,
    input            cpu_wr,
    input            cs,
    input            cart_num,
    output           mem_unmaped,
    output    [24:0] mem_addr
);
/*verilator tracing_off*/
reg  [7:0] bank1[2], bank2[2], bank3[2];

always @(posedge clk) begin
    if (reset) begin
        bank1 <= '{'h01,'h01};
        bank2 <= '{'h02,'h02};
        bank3 <= '{'h03,'h03};
    end else begin
        if (cs & cpu_mreq & cpu_wr) begin
            case (cpu_addr[15:13])
                3'b011: // 6000-7fffh
                    bank1[cart_num] <= din;
                3'b100: // 8000-9fffh
                    bank2[cart_num] <= din;
                3'b101: // a000-bfffh
                    bank3[cart_num] <= din;
                default: ;
            endcase
        end
    end
end

wire [7:0] bank_base = cpu_addr[15:13] == 3'b010 ? 8'h00 :
                       cpu_addr[15:13] == 3'b011 ? bank1[cart_num] :
                       cpu_addr[15:13] == 3'b100 ? bank2[cart_num] : bank3[cart_num];

assign mem_addr    = 25'({bank_base, cpu_addr[12:0]});
assign mem_unmaped = cs & ((cpu_addr < 16'h4000 | cpu_addr >= 16'hC000) | (mem_addr > rom_size));

endmodule