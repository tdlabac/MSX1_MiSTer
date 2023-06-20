module dev_reset_status
(
   input                   clk,
   input                   reset,
   input                   cpu_iorq,
   input                   cpu_m1,
   input                   cpu_wr,
   input                   cpu_rd,
   input             [7:0] cpu_addr,
   input             [7:0] cpu_dout,
   input                   cs,
   output            [7:0] dout
);

logic [7:0] status;
wire        status_en = cpu_iorq & cpu_addr == 8'hF4 & cs;
always @(posedge clk) begin
   if (reset) begin
      status <= 8'h00;
   end else begin
      if (cpu_wr & status_en) 
         status <= (status & 8'h20) | (cpu_dout & 8'hA0);
   end
end

assign dout = cpu_rd & status_en ? status : 8'hFF;

endmodule