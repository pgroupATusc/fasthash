module Shift_Register #(
    NPIPE_DEPTH = 2,
    DATA_WIDTH = 32) (
    clock,
    reset,
    input_data,
    output_data);

  input                         clock;
  input                         reset;
  input logic[DATA_WIDTH-1:0]   input_data;
  output logic[DATA_WIDTH-1:0]  output_data;

  logic[DATA_WIDTH-1:0]         pipe_reg[NPIPE_DEPTH-1:0];

  integer i;

  always_ff @ (posedge clock) begin
    if (reset) begin
      output_data <= 0;
    end else begin
      output_data <= pipe_reg[NPIPE_DEPTH-1];
      pipe_reg[0] <= input_data;
      for (i = 0; i < NPIPE_DEPTH-1; i = i+1)
        pipe_reg[i+1] <= pipe_reg[i];
    end
  end

endmodule
