module keyboard
(
   input         clk,
   input         reset,
   input  [10:0] ps2_key,
   input   [3:0] kb_row,
   output  [7:0] kb_data,
   input   [8:0] kbd_addr,
   input   [7:0] kbd_din,
   input         kbd_we,
   input         kbd_request
);

wire [3:0] row;

logic [7:0] row_state [16] = '{default:8'hFF};
logic [8:0] key_decode;
logic down, change;
logic [7:0] pos;

assign kb_data    = row_state[kb_row];
assign key_decode = ps2_key[8:0];

always @(posedge clk) begin
   logic [10:0] old_key = 11'd0;
   
   change     <= 1'b0;
   old_key <= ps2_key;
   if (old_key != ps2_key) begin
      down       <= ps2_key[9];
      change     <= 1'b1;
   end
end

assign row = map[7:4];
assign pos = 8'b1 << map[3:0];

always @(posedge clk) begin
   if (change) begin
      row_state[row] <= down ?  row_state[row] & ~pos : row_state[row] | pos;
   end
end

wire [7:0] map;
spram #(.addr_width(9), .mem_name("KBD"), .mem_init_file("kbd.mif")) kbd_ram 
(
   .clock(clk),
   .address(kbd_request ? kbd_addr : key_decode),
   .data(kbd_din),
   .q(map),
   .wren(kbd_we)
);

endmodule