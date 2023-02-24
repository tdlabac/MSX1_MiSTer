//http://bifi.msxnet.org/msxnet/tech/soundcartridge

module cart_konami_scc
(
    input            clk,
    input            clk_en,
    input            reset,
    input     [24:0] rom_size,
    input     [15:0] addr,
    input      [7:0] d_from_cpu,
    output     [7:0] d_to_cpu,
    output           cart_oe,
    input            wr,
    input            rd,
    input            cs,
    input            slot,
    input            scc,
    input            scc2,
    output    [24:0] mem_addr,
    output           mem_wren,
    output           mem_oe,
    output    [14:0] scc_sound[2],
    output     [7:0] scc_mode
);

assign mem_oe = (scc | scc2) ? cs & mem_used[slot] : cs;
assign scc_mode = scc_mode_int[slot];

assign d_to_cpu = slot ? d_to_cpu_B : d_to_cpu_A;


reg  [7:0] bank[2][4];
reg        mem_used[2];
reg  [7:0] scc_mode_int[2];

wire [7:0] mask = scc | scc2 ? 8'b00001111 : rom_size[20:13] - 1'd1;

always @(posedge clk) begin
    if (reset) begin
        bank[slot][0] <= 8'h00;
        bank[slot][1] <= 8'h01;
        bank[slot][2] <= 8'h02;
        bank[slot][3] <= 8'h03;
        scc_mode_int[slot] <= 8'h00;
        mem_used[slot] <= 1'b0;
    end else begin
        if (cs & wr) begin
            if (~en_ram_segment) begin
                case (addr[15:11])
                    5'b01010: // 5000-57ffh
                        bank[slot][0] <= d_from_cpu;
                    5'b01110: // 7000-77ffh
                        bank[slot][1] <= d_from_cpu;
                    5'b10010: // 9000-97ffh
                        bank[slot][2] <= d_from_cpu;
                    5'b10110: // b000-b7ffh
                        bank[slot][3] <= d_from_cpu;
                endcase
            end 
            if ({addr[15:1],1'b0} == 16'hBFFE & scc2) scc_mode_int[slot] <= d_from_cpu;
            if (mem_wren) mem_used[slot] <= 1'b1;
        end
    end
end
wire [7:0] bank_base;
wire en_ram_segment;

assign {en_ram_segment,bank_base} = addr[15:13] == 3'b010 ? {(scc_mode_int[slot][4] | scc_mode_int[slot][0]),bank[slot][0]}                       :   //4000 - 5FFF
                                    addr[15:13] == 3'b011 ? {(scc_mode_int[slot][4] | scc_mode_int[slot][1]),bank[slot][1]}                       :   //6000 - 7FFF
                                    addr[15:13] == 3'b100 ? {(scc_mode_int[slot][4] | (scc_mode_int[slot][5] & scc_mode_int[slot][2])),bank[slot][2]} :   //8000 - 9FFF
                                    addr[15:13] == 3'b101 ? {(scc_mode_int[slot][4]),bank[slot][3]}                                           :   //A000 - BFFF
                                                            9'd0 ;   

assign mem_addr = {3'h0, (bank_base & mask), addr[12:0]};
assign mem_wren = en_ram_segment & wr & (scc | scc2) ;


assign cart_oe      = (cs | scc | scc2) & scc_ack[slot];

wire mode_scc2 = scc_mode_int[slot][5]  & bank[slot][3][7];
wire mode_scc  = ~scc_mode_int[slot][5] & bank[slot][2][5:0] == 6'b111111;
wire scc_req   = ((mode_scc & addr[15:11] == 5'b10011) | (mode_scc2 & addr[15:11] == 5'b10111)) & (cs | scc | scc2) & (rd | (wr & ~en_ram_segment));
wire [7:0] scc_addr = (~addr[13] && addr[7]) ? addr[7:0] ^ 8'h20  : addr[7:0];
                      
wire scc_ack[2];
wire [7:0] d_to_cpu_A, d_to_cpu_B;


scc_wave  k051649_A
(
    .clk21m(clk),
    .reset(reset),
    .clkena(clk_en),
    .req(scc_req & ~slot),
    .ack(scc_ack[0]),
    .wrt(wr),
    .adr(scc_addr),
    .dbi(d_to_cpu_A),
    .dbo(d_from_cpu),
    .wave(scc_sound[0]),
    .sccplus(scc_mode_int[0][5])
);

scc_wave  k051649_B
(
    .clk21m(clk),
    .reset(reset),
    .clkena(clk_en),
    .req(scc_req & slot),
    .ack(scc_ack[1]),
    .wrt(wr),
    .adr(scc_addr),
    .dbi(d_to_cpu_B),
    .dbo(d_from_cpu),
    .wave(scc_sound[1]),
    .sccplus(scc_mode_int[1][5])
);


endmodule
