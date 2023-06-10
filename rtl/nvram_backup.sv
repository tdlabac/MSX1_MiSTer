module nvram_backup
(
   input                      clk,
   input MSX::lookup_SRAM_t   lookup_SRAM[4],
   input                      load_req,
   input                      save_req,
   // SD config
   input                [3:0] img_mounted,
   input                      img_readonly,
   input               [63:0] img_size,
   // SD block level access
   output              [31:0] sd_lba[4],
   output logic         [3:0] sd_rd = 4'd0,
   output logic         [3:0] sd_wr = 4'd0,
   input                [3:0] sd_ack,
   input               [13:0] sd_buff_addr,
   output               [7:0] sd_buff_din[4],
   // RAM access
   output              [17:0] ram_addr,   
   output                     ram_we,
   input                [7:0] ram_dout
);

logic [63:0] image_size[4], new_size;
logic  [3:0] image_mounted; 
logic        store_new_size = 1'b0;

always @(posedge clk) begin
   if (img_mounted[0]) begin image_mounted[0] <= ~img_readonly; image_size[0] <= img_size; end //ROM
   if (img_mounted[1]) begin image_mounted[1] <= ~img_readonly; image_size[1] <= img_size; end //Extension A
   if (img_mounted[2]) begin image_mounted[2] <= ~img_readonly; image_size[2] <= img_size; end //Extension B
   if (img_mounted[3]) begin image_mounted[3] <= ~img_readonly; image_size[3] <= img_size; end //Computer CMOS
   if (store_new_size) image_size[num] <= (64'(lookup_SRAM[num].size)) << 13;
end

logic [3:0] request_load = 4'b0, request_save = 4'b0;
logic [1:0] num          = 2'd0;
logic       wr           = 1'b0, rd = 1'b0;

always @(posedge clk) begin
   logic last_load_req, last_save_req; 
   if (~last_load_req & load_req) request_load <= 4'b1111;
   if (~last_save_req & save_req) request_save <= 4'b1111;
   if (done) begin
      wr <= 1'b0;
      rd <= 1'b0;
      if (wr) request_save[num] <= 1'b0;
      if (rd) request_load[num] <= 1'b0;
   end
   if (~wr & ~rd ) begin
      if (request_save[num]) begin
         wr  <= 1'b1;
      end else
         if (request_load[num]) begin
            rd  <= 1'b1;
         end else begin
            if (num == 3) num <= 0;
            else num <= num + 2'b1;
         end
   end
   last_load_req <= load_req;
   last_save_req <= save_req;
end

typedef enum logic [2:0] {STATE_SLEEP, STATE_CHECK_SIZE, STATE_FORMAT, STATE_PROCESS, STATE_NEXT} state_t;

logic [20:0] block_count;
logic [31:0] lba_start;
logic        done = 1'b0;

assign ram_we         = rd & sd_ack[num] ;
assign ram_addr       = lookup_SRAM[num].addr + 18'({sd_lba[num],sd_buff_addr[8:0]});
assign sd_buff_din[0] = ram_dout;
assign sd_buff_din[1] = ram_dout;
assign sd_buff_din[2] = ram_dout;
assign sd_buff_din[3] = ram_dout;

logic last_ack;
state_t state;

initial begin
   last_ack = 1'b0;
end
always @(posedge clk) begin
   done <= 1'b0;
   store_new_size <= 1'b0;
   case(state)
      STATE_SLEEP: begin
         if ((rd | wr) & ~done) begin
            if (lookup_SRAM[num].size > 16'h00 & image_mounted[num] & (wr | (rd & (image_size[num] > 0)))) begin
               sd_lba[num] <= 0;
               block_count <= 21'(lookup_SRAM[num].size) << 1;
               sd_wr[num]  <= wr;
               sd_rd[num]  <= rd;
               state       <= STATE_PROCESS;
               $display("START %d", num);
            end else begin
               done <= 1'b1;
            end
         end
      end
      STATE_PROCESS: begin
         if (~sd_ack[num] & last_ack) begin
            if (sd_lba[num][20:0] < (block_count - 21'd1)) begin
               sd_lba[num] <= sd_lba[num] + 1'b1;
            end else begin
               sd_wr[num]     <= 1'b0;
               sd_rd[num]     <= 1'b0;
               done           <= 1'b1;
               store_new_size <= wr;
               state          <= STATE_SLEEP;
            end
         end
      end
      default: ;
   endcase
   last_ack <= sd_ack[num];
end

endmodule
