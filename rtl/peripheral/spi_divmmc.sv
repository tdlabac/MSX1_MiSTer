// SPI module
module spi_divmmc
(
	input        clk_sys,
	output       ready,

	input        tx,        // Byte ready to be transmitted
	input        rx,        // request to read one byte
	input  [7:0] din,
	output [7:0] dout,

	input        spi_ce,
	output       spi_clk,
	input        spi_di,
	output       spi_do
);

assign    ready   = counter[4];
assign    spi_clk = counter[0];
assign    spi_do  = io_byte[7]; // data is shifted up during transfer
assign    dout    = data;

reg [4:0] counter = 5'b10000;  // tx/rx counter is idle
reg [7:0] io_byte, data;

always @(posedge clk_sys) begin
	if(counter[4]) begin
		if(rx | tx) begin
			counter <= 0;
			data    <= io_byte;
			io_byte <= tx ? din : 8'hff;
		end
	end
	else if (spi_ce) begin
		if(spi_clk) io_byte <= { io_byte[6:0], spi_di };
		counter <= counter + 2'd1;
	end
end

endmodule