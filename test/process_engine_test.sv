`timescale 1 ns / 1 ps

module Process_Engine_tb;

  localparam NUM_HASH_TABLES = 4;
  localparam NUM_ENTRIES_PER_HASH_TABLE = 1024;
  localparam NUM_SLOTS_PER_ENTRY = 2;
  localparam KEY_WIDTH = 32;
  localparam VAL_WIDTH = 32;
  localparam OPCODE_WIDTH = 4;
  localparam RESCODE_WIDTH = 5;

  localparam CLK_PERIOD = 10;

  bit clock;
  bit reset;
  bit input_valid;
  logic [OPCODE_WIDTH-1:0]  opcode;
  logic [KEY_WIDTH-1:0]     key;
  logic [VAL_WIDTH-1:0]     wr_data;
  bit output_valid;
  logic [VAL_WIDTH-1:0]     val_out;
  logic [RESCODE_WIDTH-1:0] rescode;
  bit stall;

  // clock generation
  initial begin
    clock = 0;
    forever begin
      #(CLK_PERIOD/2) clock = ~clock;
    end 
  end

  // clock counter
  integer clock_counter;
  initial begin
    clock_counter = 0;
    # (0.6 * CLK_PERIOD); // wait until a little after the positive edge
    forever begin
      #(CLK_PERIOD) clock_counter <= clock_counter + 1;
    end 
  end
  
  // reset generation
  initial begin
    reset = 1;
    #(2 * CLK_PERIOD) reset = 0;
  end

//  always @ (posedge clock) begin
//    key <= key + 1;
//    if (key == 99) begin
//      key <= 5;
//    end
//    wr_data <= wr_data + 2;
//    if (clock_counter < 100) begin
//      if (clock_counter % 5 == 0) begin
//        input_valid <= 1;
//        opcode <= 4'b0010;
//      end else begin
//        input_valid <= 0;
//        opcode <= 4'b0000;
//      end
//    end else begin
//      if (clock_counter % 5 == 0) begin
//        input_valid <= 1;
//        opcode <= 4'b0001;
//      end else begin
//        input_valid <= 0;
//        opcode <= 4'b0000;
//      end
//    end
//  end

  initial begin
    opcode = 4'b0010;
    input_valid = 0;
    wr_data = 0;
    wait (!reset);
    key = 0;

    // testing read after write
    # 100
    key = 10;
    wr_data = 100;
    input_valid = 1;
    opcode = 4'b0010;

    #CLK_PERIOD
    key = 0;
    wr_data = 0;
    input_valid = 0;
    opcode = 4'b0000;

    # 500
    key = 10;
    wr_data = 0;
    input_valid = 1;
    opcode = 4'b0001;

    #CLK_PERIOD
    key = 0;
    wr_data = 0;
    input_valid = 0;
    opcode = 4'b0000;
    // end testing

  end
  
  Process_Engine #(
    .NUM_HASH_TABLES(NUM_HASH_TABLES),
    .NUM_ENTRIES_PER_HASH_TABLE(NUM_ENTRIES_PER_HASH_TABLE),
    .NUM_SLOTS_PER_ENTRY(NUM_SLOTS_PER_ENTRY),
    .KEY_WIDTH(KEY_WIDTH),
    .VAL_WIDTH(VAL_WIDTH))
  DUT (
    .clock(clock),
    .reset(reset),
    .input_valid(input_valid),
    .opcode(opcode),
		.key(key),
    .wr_data(wr_data),
    .output_valid(output_valid),
    .val_out(val_out),
    .rescode(rescode),
    .stall(stall)
  );

endmodule
