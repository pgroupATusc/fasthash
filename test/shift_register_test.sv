module Shift_Register_tb;
  localparam NPIPE_DEPTH = 3;
  localparam DATA_WIDTH = 32;
  bit clk;
  bit reset;
	logic [DATA_WIDTH-1:0] input_data;
	logic [DATA_WIDTH-1:0] output_data;

  //clock generation
  always #5 clk = ~clk;
  always #10 input_data = input_data + 1;
  
  //reset Generation
  initial begin
    reset = 1;
    input_data = 0;
    #5 reset = 0;
  end
  
  Shift_Register #(
    .NPIPE_DEPTH(NPIPE_DEPTH),
    .DATA_WIDTH(DATA_WIDTH)) 
  DUT (
    .clock(clk),
    .reset(reset),
		.input_data(input_data),
    .output_data(output_data)
  );

endmodule
