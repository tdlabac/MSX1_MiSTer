module nvram_backup
(
   input                      clk,

   input MSX::sram_block_t    sram_block[2],
   input MSX::config_cart_t   cart_conf[2],
   input                [3:0] load_req,
   input                [3:0] save_req,
   // SD config
   input                [3:0] img_mounted,
   input                      img_readonly,
   input               [63:0] img_size,
   // SD block level access
   output              [31:0] sd_lba[4],
   output logic         [3:0] sd_rd = 4'd0,
   output logic         [3:0] sd_wr = 4'd0,
   input                [3:0] sd_ack,
   // RAM access
   output logic        [12:0] ram_lba,
   output logic        [24:0] ram_offset,
   output logic               ram_format,
   output logic               ram_we
);

//Unused port
assign sd_lba[0]      = 0;
assign sd_lba[2]      = 0;
assign sd_lba[3]      = 0;

logic [63:0] image_size[4], new_size;
logic        store_new_size = 1'b0;

always @(posedge clk) begin
   if (img_mounted[0]) image_size[0]   <= img_size;
   if (img_mounted[1]) image_size[1]   <= img_size;
   if (img_mounted[2]) image_size[2]   <= img_size;
   if (img_mounted[3]) image_size[3]   <= img_size;
   if (store_new_size) image_size[num] <= new_size;
end

logic [3:0] request_load = 4'b0, request_save = 4'b0, last_load_req, last_save_req;
logic [1:0] num = 2'd0;
logic       wr = 1'b0, rd = 1'b0;

always @(posedge clk) begin
   if (last_load_req != load_req) request_load <= request_load | load_req;
   if (last_save_req != save_req) request_save <= request_save | save_req;
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

logic [12:0] block_count;
logic [31:0] lba_start;
logic        done = 1'b0;

assign sd_lba[1] = ram_format ? 32'((image_size[num] >> 9) + ram_lba) : 32'(lba_start + ram_lba);
assign ram_we    = sd_rd[num];

always @(posedge clk) begin
   logic slot = 1'b0;
   logic last_ack = 1'b0;
   state_t state;

   done <= 1'b0;
   store_new_size <= 1'b0;
   case(state)
      STATE_SLEEP: begin
         if ((rd | wr) & ~done) begin
            state <= STATE_NEXT;
            if (num == 2'd1) begin
               if (sram_block[slot].block_count > 8'h00) begin
                  case(cart_conf[slot].typ)
                     CART_TYP_GM2: begin
                        lba_start  <= 0;
                        state      <= STATE_CHECK_SIZE;
                     end
                     CART_TYP_FM_PAC: begin
                        lba_start  <= (2*16*4) + (slot << 6);
                        state      <= STATE_CHECK_SIZE;
                     end
                  endcase
                  ram_lba     <= 0;
                  ram_offset  <= sram_block[slot].mem_offset;
                  block_count <= (sram_block[slot].block_count << 5);
               end
            end
         end
      end
      STATE_CHECK_SIZE: begin
         if ((lba_start + block_count) > (image_size[num] >> 9)) state <= STATE_FORMAT;
         else state <= STATE_PROCESS;
      end
      STATE_FORMAT: begin
         sd_wr[num] <= 1'b1;
         ram_format <= 1'b1;
         if (last_ack & ~sd_ack[num]) begin
            if (ram_lba < (lba_start + block_count  - (image_size[num] >> 9))-1) begin
               ram_lba <= ram_lba + 1'b1;
            end else begin
               sd_wr[num]     <= 1'b0;
               ram_lba        <= 0;
               ram_format     <= 1'b0;
               new_size       <= image_size[num] + ((ram_lba + 1'b1) << 9);
               store_new_size <= 1'b1;
               state          <= STATE_PROCESS;
            end
         end
      end
      STATE_PROCESS: begin
         sd_wr[num] <= wr;
         sd_rd[num] <= rd;
         if (last_ack & ~sd_ack[num]) begin
            if (ram_lba < block_count-1) begin
               ram_lba <= ram_lba + 1'b1;
            end else begin
               sd_wr[num] <= 1'b0;
               sd_rd[num] <= 1'b0;
               state      <= STATE_NEXT;
            end
         end
      end
      STATE_NEXT: begin
         if (slot == 1'b1) done <= 1'b1;
         slot  <= ~slot;
         state <= STATE_SLEEP;
      end
   endcase
   last_ack <= sd_ack[num];
end

endmodule
