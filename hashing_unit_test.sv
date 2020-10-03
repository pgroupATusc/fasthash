module Hashing_Unit_tb;
  localparam HASH_ENTRIES = 256;
  localparam HASH_WIDTH = $clog2(HASH_ENTRIES);
  bit clk;
  bit reset;
	logic [31:0] key;
  logic [HASH_WIDTH-1:0] hash_value;

  //clock generation
  always #5 clk = ~clk;
  always #10 key = key + 1;
  
  //reset Generation
  initial begin
    reset = 1;
    key = 0;
    #5 reset = 0;
  end
  
  Hashing_Unit #(
    .NUM_ENTRIES_PER_HASH_TABLE(HASH_ENTRIES)) 
  DUT (
    .clock(clk),
    .reset(reset),
		.key(key),
    .hash_value(hash_value)
  );

endmodule
