// hash table

module Hash_Table #(
    parameter NUM_PES = 16,
    parameter NUM_ENTRIES_PER_HASH_TABLE = 4096,
    parameter NUM_SLOTS_PER_ENTRY = 4,
    parameter KEY_WIDTH = 32,
    parameter VAL_WIDTH = 32,
    parameter NUM_OPCODES = 16,
    parameter NUM_RESCODES = 32
  ) (
    clock,
    reset,
    in_input_valid,
    in_opcode,
    in_key,
    in_wr_data,
    out_output_valid,
    out_val_out,
    out_rescode
  );

  localparam NUM_PE_WIDTH = $clog2(NUM_PES);
  localparam SLOT_WIDTH = KEY_WIDTH + VAL_WIDTH;
  localparam LINE_WIDTH = NUM_SLOTS_PER_ENTRY * SLOT_WIDTH;
  localparam LINE_MASK_WIDTH = LINE_WIDTH / 8;
  localparam ENTRY_ADDR_WIDTH = $clog2(NUM_ENTRIES_PER_HASH_TABLE);
  localparam OPCODE_WIDTH = $clog2(NUM_OPCODES);
  localparam RESCODE_WIDTH = $clog2(NUM_RESCODES);

  input                             clock;
  input                             reset;
  input                             in_input_valid;
  input   [OPCODE_WIDTH-1:0]        in_opcode;
  input   [KEY_WIDTH-1:0]           in_key;
  input   [VAL_WIDTH-1:0]           in_wr_data;
  output  logic                     out_output_valid;
  output  logic[VAL_WIDTH-1:0]      out_val_out;
  output  logic[RESCODE_WIDTH-1:0]  out_rescode;

  logic                             input_valid[NUM_PES-1:0];
  logic   [OPCODE_WIDTH-1:0]        opcode[NUM_PES-1:0];
  logic   [KEY_WIDTH-1:0]           key[NUM_PES-1:0];
  logic   [VAL_WIDTH-1:0]           wr_data[NUM_PES-1:0];
  logic                             output_valid[NUM_PES-1:0];
  logic   [VAL_WIDTH-1:0]           val_out[NUM_PES-1:0];
  logic   [RESCODE_WIDTH-1:0]       rescode[NUM_PES-1:0];
  logic   [NUM_PE_WIDTH-1:0]        counter;

  logic   [NUM_PES-1:0]                     ht_wr_valid[NUM_PES-1:0];
  logic   [NUM_PES*KEY_WIDTH-1:0]           ht_wr_key[NUM_PES-1:0];
  logic   [NUM_PES*ENTRY_ADDR_WIDTH-1:0]    ht_wr_hash_index[NUM_PES-1:0];
  logic   [NUM_PES*VAL_WIDTH-1:0]           ht_wr_wr_data[NUM_PES-1:0];
  logic   [NUM_PES*LINE_MASK_WIDTH-1:0]     ht_wr_wr_mask[NUM_PES-1:0];

  integer i;
  always_ff @ (posedge clock) begin
    if (reset) begin
      counter <= 0;
    end else begin
      counter <= counter + 1'b1;
      out_output_valid <= output_valid[counter];
      out_val_out <= val_out[counter];
      out_rescode <= rescode[counter];
      for (i = 0; i < NUM_PES; i = i + 1) begin
        if (i == counter) begin
          input_valid[i] <= in_input_valid;
          opcode[i] <= in_opcode;
          key[i] <= in_key;
          wr_data[i] <= in_wr_data;
        end else begin
          input_valid[i] <= 0;
          opcode[i] <= 0;
          key[i] <= 0;
          wr_data[i] <= 0;
        end
      end
    end
  end

  genvar p;
  generate
    for (p=0; p<NUM_PES; p=p+1) begin
      if (p == NUM_PES-1)
        Process_Engine #(
          .PE_ID(p),
          .NUM_HASH_TABLES(NUM_PES),
          .NUM_ENTRIES_PER_HASH_TABLE(NUM_ENTRIES_PER_HASH_TABLE),
          .NUM_SLOTS_PER_ENTRY(NUM_SLOTS_PER_ENTRY),
          .KEY_WIDTH(KEY_WIDTH),
          .VAL_WIDTH(VAL_WIDTH),
          .NUM_OPCODES(NUM_OPCODES),
          .NUM_RESCODES(NUM_RESCODES))
        pe (
          .clock(clock),
          .reset(reset),
          .input_valid(input_valid[p]),
          .opcode(opcode[p]),
          .key(key[p]),
          .wr_data(wr_data[p]),
          .output_valid(output_valid[p]),
          .val_out(val_out[p]),
          .rescode(rescode[p]),
          .stall(),
          .input_ht_wr_valid(ht_wr_valid[p]),
          .input_ht_wr_key(ht_wr_key[p]),
          .input_ht_wr_hash_index(ht_wr_hash_index[p]),
          .input_ht_wr_wr_data(ht_wr_wr_data[p]),
          .input_ht_wr_wr_mask(ht_wr_wr_mask[p]),
          .output_ht_wr_valid(ht_wr_valid[0]),
          .output_ht_wr_key(ht_wr_key[0]),
          .output_ht_wr_hash_index(ht_wr_hash_index[0]),
          .output_ht_wr_wr_data(ht_wr_wr_data[0]),
          .output_ht_wr_wr_mask(ht_wr_wr_mask[0])
        );
      else
        Process_Engine #(
          .PE_ID(p),
          .NUM_HASH_TABLES(NUM_PES),
          .NUM_ENTRIES_PER_HASH_TABLE(NUM_ENTRIES_PER_HASH_TABLE),
          .NUM_SLOTS_PER_ENTRY(NUM_SLOTS_PER_ENTRY),
          .KEY_WIDTH(KEY_WIDTH),
          .VAL_WIDTH(VAL_WIDTH),
          .NUM_OPCODES(NUM_OPCODES),
          .NUM_RESCODES(NUM_RESCODES))
        pe (
          .clock(clock),
          .reset(reset),
          .input_valid(input_valid[p]),
          .opcode(opcode[p]),
          .key(key[p]),
          .wr_data(wr_data[p]),
          .output_valid(output_valid[p]),
          .val_out(val_out[p]),
          .rescode(rescode[p]),
          .stall(),
          .input_ht_wr_valid(ht_wr_valid[p]),
          .input_ht_wr_key(ht_wr_key[p]),
          .input_ht_wr_hash_index(ht_wr_hash_index[p]),
          .input_ht_wr_wr_data(ht_wr_wr_data[p]),
          .input_ht_wr_wr_mask(ht_wr_wr_mask[p]),
          .output_ht_wr_valid(ht_wr_valid[p+1]),
          .output_ht_wr_key(ht_wr_key[p+1]),
          .output_ht_wr_hash_index(ht_wr_hash_index[p+1]),
          .output_ht_wr_wr_data(ht_wr_wr_data[p+1]),
          .output_ht_wr_wr_mask(ht_wr_wr_mask[p+1])
        );
    end
  endgenerate

endmodule
