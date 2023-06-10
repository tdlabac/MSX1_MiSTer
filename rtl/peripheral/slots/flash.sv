module flash (
	input             clk,
	input             clk_sdram,
	input      [22:0] addr,
	input       [7:0] din,
	output      [7:0] dout,
	output            data_valid,
	input             we,
	input             ce,
	input             sdram_ready,
	input             sdram_done,
	output reg [26:0] sdram_addr,
	output reg  [7:0] sdram_din,
	output reg        sdram_req,
	input      [26:0] sdram_offset,
	output            debug_erase
);
/*verilator tracing_off*/

	reg [2:0] index;
	reg [7:0] cmd[5];
	
	assign debug_erase = erase;
	
	initial begin
		index = 3'd0;
	end
	
	assign dout = ~ce     		     ? 8'hFF :
	              erase              ? 8'h00 :
	 			  ~state             ? 8'hFF :
				  addr[2:1] == 2'b00 ? 8'h20 : 
                  addr[2:1] == 2'b01 ? 8'h7e : 
				  addr[2:1] == 2'b10 ? 8'h00 : 
				                       8'h01 ;

	assign data_valid = ce & ~we & (state | erase);

	reg       erase_block = 0;
	reg [7:0] erase_block_num;
//	reg       erase_chip = 0;

	reg old_we;
	reg state;
	always @(posedge clk) begin
		old_we <= we;
	end
	
	always @(posedge clk) begin
		if (clk) begin
		   erase_block <= 0;
//			erase_chip  <= 0;
			if (~valid) index <= 0;
			if (we & ~old_we & ce) begin
				cmd[index] <= din;
				index <= index + 1'b1;
				if (int_valid5) begin
					index <= 0;
					if (din == 8'h30) begin erase_block <= 1; erase_block_num <= (addr > 23'hFFFF ? {1'b0,addr[22:16]} : {5'd0,addr[15:13]} ); end
					//if (din == 8'h10) erase_chip  <= 1;
				end
				if (addr[11:1] != (index == 3'd1 | index == 3'd4 ? 11'h2aa : 11'h555) & ~(din == 8'hF0 & index == 0) ) begin
					index <= 0;
				end	
			end
			if (reset) begin 
				index <= 0;
				state <= 0;
			end
			if (ident) begin 
				index <= 0;
				state <= 1;
			end
		end
	end
	
	//TODO potřebuji valid ?
	wire reset            = valid & int_valid1 & cmd[0] == 8'hF0;
	wire doubleProgram    = valid & int_valid1 & cmd[0] == 8'h50;
	wire quadrupleProgram = valid & int_valid1 & cmd[0] == 8'h56;
	wire bytePrgram       = valid & int_valid3 & cmd[2] == 8'hA0;
	wire ident            = valid & int_valid3 & cmd[2] == 8'h90;
    


	wire int_valid1 =              index > 3'd0 & (cmd[0] == 8'hF0 | cmd[0] == 8'h50 | cmd[0] == 8'h56 | cmd[0] == 8'hAA);
	wire int_valid2 = int_valid1 & index > 3'd1 & (cmd[1] == 8'h55);
	wire int_valid3 = int_valid2 & index > 3'd2 & (cmd[2] == 8'h80 | cmd[2] == 8'h90 | cmd[2] == 8'hA0);
	wire int_valid4 = int_valid3 & index > 3'd3 & (cmd[3] == 8'hAA);
	wire int_valid5 = int_valid4 & index > 3'd4 & (cmd[4] == 8'h55);	
	
	wire valid      = index == 3'd1 ? int_valid1 :
	                  index == 3'd2 ? int_valid2 :
					  index == 3'd3 ? int_valid3 :
					  index == 3'd4 ? int_valid4 :
					  index == 3'd5 ? int_valid5 :
					                  1'b0;
	
   //wire [7:0] num1 = {5'd0,addr[15:13]};
   //wire [7:0] num2 = addr[22:16] + 7;

	reg erase;
//write to SDRAM
	always @(posedge clk) begin
		reg sdram_need_wr;
		reg [15:0] write_cnt;
		
		if (sdram_req & sdram_done) begin
			sdram_req <= 0; //request se zpracovava
			write_cnt <= write_cnt - 1'b1;
			if (erase) begin
				if (write_cnt == 0) begin
					erase <= 0;
					write_cnt <= 0;
				end else begin
				//	write_cnt <= write_cnt - 1'b1;
				//if (erase) begin
					sdram_addr <= sdram_addr + 1'b1;
					sdram_need_wr <= 1;
				end
			end
		end
		if (sdram_need_wr & sdram_ready & ~sdram_req) begin
			sdram_need_wr <= 0;
			sdram_req <= 1;
		end
		if (erase_block) begin
			write_cnt <= 16'hFFFF;
			sdram_din <=  8'hFF;
			sdram_need_wr <= 1;
			sdram_addr <= sdram_offset + (27'(erase_block_num) << 16);
			erase <= 1;
		end else 
		if ((quadrupleProgram | write_cnt > 0) & we & ~old_we & ce ) begin
			//Zkontrolovat zda je writable sector num1 a num2 vypocet
			sdram_addr <= sdram_offset + 27'(addr);
			sdram_din <= din;
			if (sdram_ready) begin
				sdram_req <= 1;
			end else begin
				sdram_need_wr <= 1;
			end
			if (quadrupleProgram) write_cnt <= 4;
			if (doubleProgram) write_cnt <= 2;
			if (bytePrgram) write_cnt <= 1;
			if (erase_block) write_cnt <= 16'hFFFF;
		end
	end
	
endmodule
