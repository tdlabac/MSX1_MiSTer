module mapper_detect
(
    input               clk,
    input               rst,
    input         [7:0] data,
    input               wr,
    input        [26:0] rom_size,
    output mapper_typ_t mapper,
    output        [3:0] offset,
    output        [7:0] mode,
    output        [7:0] param
);
/*averilator tracing_off*/

logic [7:0]  head  [0:7];
logic [7:0]  head2 [0:7];
logic signed [15:0] asc16, asc8, kon4, kon5;
logic [26:0] addr;

wire [15:0] kon, ascii;
wire [15:0] start, start4000;
wire romSig_at_0000, romSig_at_4000;
wire [3:0] start_1, start_2, start_3;


always @(posedge clk) begin
logic [7:0] a0,a1,a2;

    if (rst) begin
        asc16 <= 0;
        asc8  <= 0;
        kon4  <= 0;
        kon5  <= 0;
        a0    <= 0;
        a1    <= 0;
        a2    <= 0;
        addr  <= 27'd0;
    end else
        if (wr) begin
            addr <= addr + 27'd1;
            if (addr[26:7] == 0) begin
                if (addr[5:3] == 0) begin
                    if (addr[6] == 0) begin
                            head  [addr[2:0]] <= data;
                            head2 [addr[2:0]] <= 0;
                    end else begin
                            head2[addr[2:0]] <= data;
                    end
                end
            end
            a0 <= a1;
            a1 <= a2;
            a2 <= data;
            if (addr > 2)	begin
                if (a0 == 8'h32 && a1 == 0) begin
                    case (a2)
                            8'h60,
                            8'h70: begin
                                asc16 <= asc16 + 1'd1;
                                asc8  <= asc8 + 1'd1;
                            end
                            8'h68,
                            8'h78: begin
                                asc8  <= asc8 + 1'd1;
                                asc16 <= asc16 - 1'd1;
                            end
                            default: ;
                    endcase
                    case (a2)
                            8'h60,
                            8'h80,
                            8'ha0: begin
                                kon4 <= kon4 + 1'd1;
                            end
                            8'h50,
                            8'h70,
                            8'h90,
                            8'hb0: begin
                                kon5 <= kon5 + 1'd1;
                            end
                        default: ;
                    endcase
                end
            end
        end
end

assign kon    = kon4 > kon5  ? kon4 : kon5;
assign ascii  = asc8 > asc16 ? asc8 : asc16;
assign mapper = rom_size < 27'h1000                        ? MAPPER_UNUSED                 :
                rom_size < 27'h10000                       ? MAPPER_NONE                   :
                kon >= ascii                               ? (kon5 > kon4  ? MAPPER_KONAMI_SCC : 
                                                                             MAPPER_KONAMI)    :
                                                             (asc8 > asc16 ? MAPPER_ASCII8     : 
                                                                             MAPPER_ASCII16)   ;
assign start          = 16'(head[3])  << 8 | 16'(head[2]);
assign start4000      = 16'(head2[3]) << 8 | 16'(head2[2]);
assign romSig_at_0000 = head [0] == "A" && head [1] == "B";
assign romSig_at_4000 = head2[0] == "A" && head2[1] == "B";

assign start_1 = start == 0 ?  ((head[5] & 8'hC0) != 8'h40 ? 4'h8 : 4'h4) : ((start & 16'hC000) == 16'h8000 ? 4'h8 : 4'h4);
assign start_2 = (~romSig_at_0000 && romSig_at_4000) ? ((start4000 == 0 && (head2[5] & 8'hC0) == 8'h40) || start4000 < 16'h8000 || start4000 >= 16'hC000) ? 4'h0 : 4'h4 : 4'h4;
assign start_3 = (~(romSig_at_0000 && ~romSig_at_4000)) ? 4'h0 : 4'h4;
assign offset  = rom_size == 27'h1000 ? start_1 :
                 rom_size == 27'h2000 ? start_1 :
                 rom_size == 27'h4000 ? start_1 :
                 rom_size == 27'h8000 ? start_2 :
                 rom_size == 27'hC000 ? start_3 :
                                        4'h0;
wire [15:0] size =  rom_size[15:0] - 16'd1;
wire [1:0] rsize = size[15:14];

assign {mode,param} = {rsize,offset[3:2]} == {2'd0,2'd0} ? {8'h02, 8'h00}:
                      {rsize,offset[3:2]} == {2'd0,2'd1} ? {8'h08, 8'h00} :
                      {rsize,offset[3:2]} == {2'd0,2'd2} ? {8'h20, 8'h00} :
                      {rsize,offset[3:2]} == {2'd1,2'd0} ? {8'h0A, 8'h04} :
                      {rsize,offset[3:2]} == {2'd1,2'd1} ? {8'hAA, 8'h11} :
                      {rsize,offset[3:2]} == {2'd1,2'd2} ? {8'hA0, 8'h40} :
                      {rsize,offset[3:2]} == {2'd2,2'd0} ? {8'h2A, 8'h24} :
                      {rsize,offset[3:2]} == {2'd2,2'd1} ? {8'hA8, 8'h90} :
                      {rsize,offset[3:2]} == {2'd3,2'd0} ? {8'hAA, 8'hE4} :
                                                           {8'h00, 8'h00} ;                                        
endmodule
