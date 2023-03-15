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
    input            scc,
    input            scc2,
    input            slot,
    output    [24:0] mem_addr,
    output           mem_wren,
    output           mem_oe,
    output signed [15:0] sound[2]
    //output reg [7:0] scc_mode = 'h00
);

    wire [24:0] mem_addr_A, mem_addr_B;
    wire  [7:0] d_to_cpu_A, d_to_cpu_B;
    wire        sram_we_A, sram_we_B;
    wire        sram_oe_A, sram_oe_B;
    wire        cart_oe_A, cart_oe_B;
    wire        mem_wren_A, mem_wren_B;
    wire        mem_oe_A, mem_oe_B;

    assign d_to_cpu = slot ? d_to_cpu_B : d_to_cpu_A;
    assign mem_oe   = slot ? mem_oe_B   : mem_oe_A;
    assign mem_wren = slot ? mem_wren_B : mem_wren_A;
    assign mem_addr = slot ? mem_addr_B : mem_addr_A;
    //assign sram_we  = slot ? sram_we_B  : sram_we_A; //TODO SRAM NENI ale RAM
    //assign sram_oe  = slot ? sram_oe_B  : sram_oe_A;  
    assign cart_oe  = slot ? cart_oe_B  : cart_oe_A;

    konami_scc konami_scc_A
    (
        .d_to_cpu(d_to_cpu_A),
        .cart_oe(cart_oe_A),
        .mem_addr(mem_addr_A),
        .mem_oe(mem_oe_A),
        .mem_wren(mem_wren_A),
        //.sram_we(sram_we_A),
        //.sram_oe(sram_oe_A),
        .sound(sound[0]),
        .scc_mode(),
        .cs(cs & ~slot),
        .*
    );

    konami_scc konami_scc_B
    (
        .d_to_cpu(d_to_cpu_B),
        .cart_oe(cart_oe_B),
        .mem_addr(mem_addr_B),
        .mem_oe(mem_oe_B),
        .mem_wren(mem_wren_B),
        //.sram_we(sram_we_B),
        //.sram_oe(sram_oe_B),
        .sound(sound[1]),
        .scc_mode(),
        .cs(cs & slot),
        .*
    );

endmodule


module konami_scc
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
    input            scc,
    input            scc2,
    output    [24:0] mem_addr,
    output           mem_wren,
    output           mem_oe,
    output signed [15:0] sound,
    output reg [7:0] scc_mode = 'h00
);

    assign mem_oe = (scc | scc2) ? cs & mem_used : cs;

    reg  [7:0] bank0, bank1, bank2, bank3;
    reg        mem_used;
    wire [7:0] mask = scc | scc2 ? 8'b00001111 : rom_size[20:13] - 1'd1;

    always @(posedge clk) begin
        if (reset) begin
            bank0 <= 8'h00;
            bank1 <= 8'h01;
            bank2 <= 8'h02;
            bank3 <= 8'h03;
            scc_mode <= 8'h00;
            mem_used <= 1'b0;
        end else begin
            if (cs & wr) begin
                if (~en_ram_segment) begin
                    case (addr[15:11])
                        5'b01010: // 5000-57ffh
                            bank0 <= d_from_cpu;
                        5'b01110: // 7000-77ffh
                            bank1 <= d_from_cpu;
                        5'b10010: // 9000-97ffh
                            bank2 <= d_from_cpu;
                        5'b10110: // b000-b7ffh
                            bank3 <= d_from_cpu;
                    endcase
                end 
                if ({addr[15:1],1'b0} == 16'hBFFE & scc2) scc_mode <= d_from_cpu;
                if (mem_wren) mem_used <= 1'b1;
            end
        end
    end
    wire [7:0] bank_base;
    wire en_ram_segment;

    assign {en_ram_segment,bank_base} = addr[15:13] == 3'b010 ? {(scc_mode[4] | scc_mode[0]),bank0}                 :   //4000 - 5FFF
                                        addr[15:13] == 3'b011 ? {(scc_mode[4] | scc_mode[1]),bank1}                 :   //6000 - 7FFF
                                        addr[15:13] == 3'b100 ? {(scc_mode[4] | (scc_mode[5] & scc_mode[2])),bank2} :   //8000 - 9FFF
                                        addr[15:13] == 3'b101 ? {(scc_mode[4]),bank3}                               :   //A000 - BFFF
                                                                9'd0 ;   

    assign mem_addr = {3'h0, (bank_base & mask), addr[12:0]};
    assign mem_wren = en_ram_segment & wr & (scc | scc2) ;


    assign cart_oe      = (cs | scc | scc2) & scc_ack;

    wire mode_scc2 = scc_mode[5]  & bank3[7];
    wire mode_scc  = ~scc_mode[5] & bank2[5:0] == 6'b111111;
    wire scc_req   = ((mode_scc & addr[15:11] == 5'b10011) | (mode_scc2 & addr[15:11] == 5'b10111)) & (cs | scc | scc2) & (rd | (wr & ~en_ram_segment));
    wire [7:0] scc_addr = (~addr[13] && addr[7]) ? addr[7:0] ^ 8'h20  : addr[7:0];
                        
    assign sound = {sound_scc[14],sound_scc};
    
    wire scc_ack;
    wire signed [14:0] sound_scc;
    scc_wave  k051649
    (
        .clk21m(clk),
        .reset(reset),
        .clkena(clk_en),
        .req(scc_req),
        .ack(scc_ack),
        .wrt(wr),
        .adr(scc_addr),
        .dbi(d_to_cpu),
        .dbo(d_from_cpu),
        .wave(sound_scc),
        .sccplus(scc_mode[5])
    );

endmodule
