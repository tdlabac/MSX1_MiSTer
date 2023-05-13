module msx2_ram_mapper
(
   input                   clk,
   input                   reset,
   input                   cpu_iorq,
   input                   cpu_m1,
   input                   cpu_wr,
   input                   cpu_rd,
   input            [15:0] cpu_addr,
   input             [7:0] cpu_dout,
   input             [7:0] ram_block_count,
   output            [7:0] mapper_dout,
   output                  mapper_req,
   output           [21:0] mapper_addr
);
/*verilator tracing_off*/
   wire mpr_wr, mpr_rq;
   logic [7:0] mem_seg [0:3];

   assign mpr_rq     = (cpu_addr[7:2] == 6'b111111) & cpu_iorq & ~cpu_m1;
   assign mpr_wr     = mpr_rq & cpu_wr;
   assign mapper_req = mpr_rq & cpu_rd;
   assign mapper_addr = {(mem_seg[cpu_addr[15:14]] & 8'(ram_block_count-1'b1)),cpu_addr[13:0]};

   assign mapper_dout = mem_seg[cpu_addr[1:0]] | 8'(~(ram_block_count-8'd1)); 
   always @( posedge reset, posedge clk ) begin
      if (reset) begin
            mem_seg[0] <= 0;
            mem_seg[1] <= 0;
            mem_seg[2] <= 0;
            mem_seg[3] <= 0;
      end else if (mpr_wr)
         mem_seg[cpu_addr[1:0]] <= cpu_dout;
   end

endmodule