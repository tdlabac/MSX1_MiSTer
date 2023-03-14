module msx2_ram_mapper
(
   input    clk,
   input    reset,
   input    cpu_iorq,
   input    cpu_m1,
   input    cpu_wr,
   input    cs,
   input [15:0] cpu_addr,
   input  [7:0] cpu_dout,
   input  [7:0] ram_block_count,
   output [7:0] ram_bank,
   output [7:0] mapper_dout,
   output       mapper_req
);

   wire mpr_wr;
   reg [7:0] mem_seg [0:3];

   assign mapper_dout = mem_seg[cpu_addr[1:0]] | 8'(~(ram_block_count-1));
   assign mapper_req  = (cpu_addr[7:2] == 6'b111111) & cpu_iorq & ~cpu_m1 & cs;
   assign ram_bank    = mem_seg[cpu_addr[15:14]];   
   assign mpr_wr      = mapper_req & cpu_wr;

   always @( posedge reset, posedge clk ) begin
   if (reset) begin
      mem_seg[0] <= 3;
      mem_seg[1] <= 2;
      mem_seg[2] <= 1;
      mem_seg[3] <= 0;
   end else if (mpr_wr)
      mem_seg[cpu_addr[1:0]] <= cpu_dout & 8'(ram_block_count-1'b1);
   end

endmodule