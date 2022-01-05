module cart_rom
(
	input         clk,
	input  [15:0] addr,
	input         CS1_n,
	input         CS2_n,
	input         CS12_n,
	input	        SLTSL_n,
	output  [7:0] d_to_cpu,

	input         ioctl_download,
	input   [7:0] ioctl_index,
	input         ioctl_wr,
	input  [24:0] ioctl_addr,
	input   [7:0] ioctl_dout,
	input         ioctl_isROM
);

wire rom_we = ioctl_download & ioctl_isROM & ioctl_wr;
spram #(.addr_width(16),.mem_name("CART")) rom_cart
(   
	.clock(clk),
	.address(ioctl_download && ioctl_isROM ? ioctl_addr[15:0] : addr - start_addr),
	.wren(rom_we),
	.q(d_to_cpu),
	.data(ioctl_dout)
);

reg [7:0] head [0:7];
reg [7:0] head2 [0:7];
always @(posedge rom_we) begin
	rom_size <= ioctl_addr;
	if (ioctl_addr[15:3] == 0)
		head [ioctl_addr[2:0]] <= ioctl_dout;
	if (ioctl_addr[15:3] == 13'b0100000000000)
		head2[ioctl_addr[2:0]] <= ioctl_dout;	
end

wire [15:0] start = head[3] << 8 | head[2];
wire [15:0] start4000 = head2[3] << 8 | head2[2];
wire romSig_at_0000 = head[0] == "A" && head[1] == "B";
wire romSig_at_4000 = head[0] == "A" && head[1] == "B";
reg [15:0] start_addr;
reg [24:0] rom_size;

always @(clk, start, start4000, romSig_at_0000, romSig_at_4000, rom_size) begin
	start_addr <= 16'h4000;
	case (rom_size)
		16'h1fff,
		16'h3fff: begin
			if (start == 0) begin
				if ((head[5] & 8'hC0) != 8'h40)
					start_addr <= 16'h8000;
			end else if ((start & 16'hC000) == 16'h8000)
					start_addr <= 16'h8000;
		end
		16'h7fff: begin
			if (~romSig_at_0000 && romSig_at_4000)
				if ((start4000 == 0 && (head2[5] & 8'hC0) == 8'h40) || start4000 < 16'h8000 || start4000 >= 16'hC000)
					start_addr <= 16'h0000;
		end
		16'hbfff: begin
			if (~(romSig_at_0000 && ~romSig_at_4000))
				start_addr <= 16'h0000;
		end
		default:
			start_addr <= 16'h0000;
	endcase
end

endmodule
