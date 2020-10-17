// process engine

module Process_Engine #(
    parameter PE_ID = 0,
    parameter NUM_HASH_TABLES = 16,
    parameter NUM_ENTRIES_PER_HASH_TABLE = 4096,
    parameter NUM_SLOTS_PER_ENTRY = 4,
    parameter KEY_WIDTH = 32,
    parameter VAL_WIDTH = 32,
    parameter NUM_OPCODES = 16,
    parameter NUM_RESCODES = 32
  ) (
    clock,
    reset,
    // horizontal
    input_valid,
    opcode,
    key,
    wr_data,
    output_valid,
    val_out,
    rescode,
    stall,
    // vertical
    input_ht_wr_valid,
    input_ht_wr_key,
    input_ht_wr_hash_index,
    input_ht_wr_wr_data,
    input_ht_wr_wr_mask,
    output_ht_wr_valid,
    output_ht_wr_key,
    output_ht_wr_hash_index,
    output_ht_wr_wr_data,
    output_ht_wr_wr_mask
  );

  // system params
  localparam SLOT_WIDTH = KEY_WIDTH + VAL_WIDTH;
  localparam LINE_WIDTH = NUM_SLOTS_PER_ENTRY * SLOT_WIDTH;
  localparam LINE_MASK_WIDTH = LINE_WIDTH / 8;
  localparam ENTRY_ADDR_WIDTH = $clog2(NUM_ENTRIES_PER_HASH_TABLE);
  localparam OPCODE_WIDTH = $clog2(NUM_OPCODES);
  localparam RESCODE_WIDTH = $clog2(NUM_RESCODES);
  localparam NUM_SLOTS_WIDTH = $clog2(NUM_SLOTS_PER_ENTRY);

  // pe specific params
  localparam HASH_TABLE_BITS = NUM_ENTRIES_PER_HASH_TABLE * LINE_WIDTH;
  localparam HASHING_PIPE_DEPTH = 1;
  localparam RAM_PIPE_DEPTH = 4;
  localparam RAM_WR_PIPE_DEPTH = 1;

  /*
  * opcode: 0000 - nop; 0001 - search; 0010 - insert; 0011 - delete;
  *         x1xx - reserved
  * rescode: 0xxxx - not found; 10000 - found, hash table block 0 owns the
  * entry; 10001 - found, hash table block 1 owns the entry, et al
  */

  // input signals
  // horizontal
  input                             clock;
  input                             reset;
  input                             input_valid;
  input   [OPCODE_WIDTH-1:0]        opcode;
  input   [KEY_WIDTH-1:0]           key;
  input   [VAL_WIDTH-1:0]           wr_data;

  // output signals
  // horizontal
  output  logic                     output_valid;
  output  logic[VAL_WIDTH-1:0]      val_out;
  output  logic[RESCODE_WIDTH-1:0]  rescode;
  output  logic                     stall;

  // write processing
  input   [NUM_HASH_TABLES-1:0]                      input_ht_wr_valid;
  input   [NUM_HASH_TABLES*KEY_WIDTH-1:0]            input_ht_wr_key;
  input   [NUM_HASH_TABLES*ENTRY_ADDR_WIDTH-1:0]     input_ht_wr_hash_index;
  input   [NUM_HASH_TABLES*VAL_WIDTH-1:0]            input_ht_wr_wr_data;
  input   [NUM_HASH_TABLES*LINE_MASK_WIDTH-1:0]      input_ht_wr_wr_mask;
  output  logic[NUM_HASH_TABLES-1:0]                      output_ht_wr_valid;
  output  logic[NUM_HASH_TABLES*KEY_WIDTH-1:0]            output_ht_wr_key;
  output  logic[NUM_HASH_TABLES*ENTRY_ADDR_WIDTH-1:0]     output_ht_wr_hash_index;
  output  logic[NUM_HASH_TABLES*VAL_WIDTH-1:0]            output_ht_wr_wr_data;
  output  logic[NUM_HASH_TABLES*LINE_MASK_WIDTH-1:0]      output_ht_wr_wr_mask;

  // hash function related registers
  logic   [ENTRY_ADDR_WIDTH-1:0]    hu_out_hash_index;
  // shift registers for valid, op, and value
  // because hash function is pipelined with 2 stages
  logic                             hu_sr_out_valid;
  logic   [OPCODE_WIDTH-1:0]        hu_sr_out_opcode;
  logic   [KEY_WIDTH-1:0]           hu_sr_out_key;
  logic   [VAL_WIDTH-1:0]           hu_sr_out_wr_data;

  // data processing related registers
  // for common data path
  logic                             ht_sr_out_valid[NUM_HASH_TABLES-1:0];
  logic   [KEY_WIDTH-1:0]           ht_sr_out_key[NUM_HASH_TABLES-1:0];
  logic   [ENTRY_ADDR_WIDTH-1:0]    ht_sr_out_hash_index[NUM_HASH_TABLES-1:0];
  logic   [OPCODE_WIDTH-1:0]        ht_sr_out_opcode[NUM_HASH_TABLES-1:0];
  // for read data path
  logic   [LINE_WIDTH-1:0]          ht_ram_out_val[NUM_HASH_TABLES-1:0];
  // ht_out_val[i] means output after mux between sr and ht
  logic   [VAL_WIDTH-1:0]           ht_out_val[NUM_HASH_TABLES-1:0];
  // ht_sr_out_val[i] means output from shift register at hash table *i*
  logic   [VAL_WIDTH-1:0]           ht_sr_out_val[NUM_HASH_TABLES-1:0];
  // for write data path
  logic   [VAL_WIDTH-1:0]           ht_sr_out_wr_data[NUM_HASH_TABLES-1:0];
  // ht_out_wr_mask[i] means output after mux between sr and ht
  logic   [LINE_MASK_WIDTH-1:0]     ht_out_wr_mask[NUM_HASH_TABLES-1:0];
  // ht_sr_out_wr_mask[i] means output from shift register at hash table *i*
  logic   [LINE_MASK_WIDTH-1:0]     ht_sr_out_wr_mask[NUM_HASH_TABLES-1:0];
  // for output
  logic   [RESCODE_WIDTH-1:0]       ht_out_rescode[NUM_HASH_TABLES-1:0];
  logic   [RESCODE_WIDTH-1:0]       ht_sr_out_rescode[NUM_HASH_TABLES-1:0];

  // write processing
  logic                             master_ht_in_wr_valid;
  logic   [KEY_WIDTH-1:0]           master_ht_in_wr_key;
  logic   [ENTRY_ADDR_WIDTH-1:0]    master_ht_in_wr_hash_index;
  logic   [VAL_WIDTH-1:0]           master_ht_in_wr_wr_data;

  // hashing unit
  Hashing_Unit #(
    .KEY_WIDTH(KEY_WIDTH),
    .NUM_ENTRIES_PER_HASH_TABLE(NUM_ENTRIES_PER_HASH_TABLE)) 
  hu (
    .clock(clock),
    .reset(reset),
		.key(key),
    .hash_value(hu_out_hash_index)
  );

  Shift_Register #(
    .NPIPE_DEPTH(HASHING_PIPE_DEPTH),
    .DATA_WIDTH(1))
  hu_sr_valid (
    .clock(clock),
    .reset(reset),
    .input_data(input_valid),
    .output_data(hu_sr_out_valid)
  );

  Shift_Register #(
    .NPIPE_DEPTH(HASHING_PIPE_DEPTH),
    .DATA_WIDTH(KEY_WIDTH))
  hu_sr_key (
    .clock(clock),
    .reset(reset),
    .input_data(key),
    .output_data(hu_sr_out_key)
  );

  Shift_Register #(
    .NPIPE_DEPTH(HASHING_PIPE_DEPTH),
    .DATA_WIDTH(OPCODE_WIDTH))
  hu_sr_opcode (
    .clock(clock),
    .reset(reset),
    .input_data(opcode),
    .output_data(hu_sr_out_opcode)
  );

  Shift_Register #(
    .NPIPE_DEPTH(HASHING_PIPE_DEPTH),
    .DATA_WIDTH(VAL_WIDTH))
  hu_sr_wr_data (
    .clock(clock),
    .reset(reset),
    .input_data(wr_data),
    .output_data(hu_sr_out_wr_data)
  );
  // end hashing unit

  // data processing unit
  genvar j;
  generate for (j = 0; j < NUM_HASH_TABLES; j = j + 1) begin
    always_ff @ (posedge clock) begin
      // check hit or miss
      if (ht_ram_out_val[j][SLOT_WIDTH*0+KEY_WIDTH-1:SLOT_WIDTH*0] == ht_sr_out_key[j]) begin
        ht_out_val[j] <= ht_ram_out_val[j][SLOT_WIDTH*1-1:KEY_WIDTH+SLOT_WIDTH*0];
        ht_out_rescode[j] <= (1 << 4) | j;    // hardcode
      end else if (ht_ram_out_val[j][SLOT_WIDTH*1+KEY_WIDTH-1:SLOT_WIDTH*1] == ht_sr_out_key[j]) begin
        ht_out_val[j] <= ht_ram_out_val[j][SLOT_WIDTH*2-1:KEY_WIDTH+SLOT_WIDTH*1];
        ht_out_rescode[j] <= (1 << 4) | j;    // hardcode
      // HARDCODE
      end else if (ht_ram_out_val[j][SLOT_WIDTH*2+KEY_WIDTH-1:SLOT_WIDTH*2] == ht_sr_out_key[j]) begin
        ht_out_val[j] <= ht_ram_out_val[j][SLOT_WIDTH*3-1:KEY_WIDTH+SLOT_WIDTH*2];
        ht_out_rescode[j] <= (1 << 4) | j;    // hardcode
      end else if (ht_ram_out_val[j][SLOT_WIDTH*3+KEY_WIDTH-1:SLOT_WIDTH*3] == ht_sr_out_key[j]) begin
        ht_out_val[j] <= ht_ram_out_val[j][SLOT_WIDTH*4-1:KEY_WIDTH+SLOT_WIDTH*3];
        ht_out_rescode[j] <= (1 << 4) | j;    // hardcode
      end else begin
        ht_out_val[j] <= ht_sr_out_val[j];
        ht_out_rescode[j] <= ht_sr_out_rescode[j];
      end
      // generate write mask -- find an empty slot
      if (j == PE_ID) begin
        if (ht_ram_out_val[j][SLOT_WIDTH*0+KEY_WIDTH-1:SLOT_WIDTH*0] == 0) begin
          ht_out_wr_mask[j] <= {(SLOT_WIDTH/8){1'b1}} << 0*(SLOT_WIDTH/8);
        end else if (ht_ram_out_val[j][SLOT_WIDTH*1+KEY_WIDTH-1:SLOT_WIDTH*1] == 0) begin
          ht_out_wr_mask[j] <= {(SLOT_WIDTH/8){1'b1}} << 1*(SLOT_WIDTH/8);
        // HARDCODE
        end else if (ht_ram_out_val[j][SLOT_WIDTH*2+KEY_WIDTH-1:SLOT_WIDTH*2] == 0) begin
          ht_out_wr_mask[j] <= {(SLOT_WIDTH/8){1'b1}} << 2*(SLOT_WIDTH/8);
        end else if (ht_ram_out_val[j][SLOT_WIDTH*3+KEY_WIDTH-1:SLOT_WIDTH*3] == 0) begin
          ht_out_wr_mask[j] <= {(SLOT_WIDTH/8){1'b1}} << 3*(SLOT_WIDTH/8);
        end else begin
          ht_out_wr_mask[j] <= {(SLOT_WIDTH/8){1'b1}} << 0*(SLOT_WIDTH/8);
        end
      end else begin
        ht_out_wr_mask[j] <= ht_sr_out_wr_mask[j];
      end
    end
  end endgenerate

  genvar i;
  generate for (i = 0; i < NUM_HASH_TABLES; i = i + 1) begin
    if (i == 0) begin
      // input valid shift register
      Shift_Register #(
        .NPIPE_DEPTH(RAM_PIPE_DEPTH-1),
        .DATA_WIDTH(1))
      ht_sr_valid (
        .clock(clock),
        .reset(reset),
        .input_data(hu_sr_out_valid),
        .output_data(ht_sr_out_valid[i])
      );
      // hash index shift register
      Shift_Register #(
        .NPIPE_DEPTH(RAM_PIPE_DEPTH-1),
        .DATA_WIDTH(ENTRY_ADDR_WIDTH))
      ht_sr_hash_index (
        .clock(clock),
        .reset(reset),
        .input_data(hu_out_hash_index),
        .output_data(ht_sr_out_hash_index[i])
      );
      // opcode shift register
      Shift_Register #(
        .NPIPE_DEPTH(RAM_PIPE_DEPTH-1),
        .DATA_WIDTH(OPCODE_WIDTH))
      ht_sr_opcode (
        .clock(clock),
        .reset(reset),
        .input_data(hu_sr_out_opcode),
        .output_data(ht_sr_out_opcode[i])
      );
      // key shift register
      Shift_Register #(
        .NPIPE_DEPTH(RAM_PIPE_DEPTH-1),
        .DATA_WIDTH(KEY_WIDTH))
      ht_sr_key (
        .clock(clock),
        .reset(reset),
        .input_data(hu_sr_out_key),
        .output_data(ht_sr_out_key[i])
      );
      // wr_data shift register
      Shift_Register #(
        .NPIPE_DEPTH(RAM_PIPE_DEPTH-1),
        .DATA_WIDTH(VAL_WIDTH))
      ht_sr_wr_data (
        .clock(clock),
        .reset(reset),
        .input_data(hu_sr_out_wr_data),
        .output_data(ht_sr_out_wr_data[i])
      );
      // read data path shift register
      Shift_Register #(
        .NPIPE_DEPTH(RAM_PIPE_DEPTH-2), // -2 because need 1 cycle to check hit/miss
        .DATA_WIDTH(VAL_WIDTH))
      ht_sr_val (
        .clock(clock),
        .reset(reset),
        .input_data(0),
        .output_data(ht_sr_out_val[i])
      );
      // slot id shift register
      Shift_Register #(
        .NPIPE_DEPTH(RAM_PIPE_DEPTH-1),
        .DATA_WIDTH(LINE_MASK_WIDTH))
      ht_sr_wr_mask (
        .clock(clock),
        .reset(reset),
        .input_data(0),
        .output_data(ht_sr_out_wr_mask[i])
      );
      // rescode shift register
      Shift_Register #(
        .NPIPE_DEPTH(RAM_PIPE_DEPTH-2), // -2 because need 1 cycle to check hit/miss
        .DATA_WIDTH(RESCODE_WIDTH))
      ht_sr_rescode (
        .clock(clock),
        .reset(reset),
        .input_data(0),
        .output_data(ht_sr_out_rescode[i])
      );
    end else begin
      // input valid shift register
      Shift_Register #(
        .NPIPE_DEPTH(RAM_PIPE_DEPTH-1),
        .DATA_WIDTH(1))
      ht_sr_valid (
        .clock(clock),
        .reset(reset),
        .input_data(ht_sr_out_valid[i-1]),
        .output_data(ht_sr_out_valid[i])
      );
      // hash index shift register
      Shift_Register #(
        .NPIPE_DEPTH(RAM_PIPE_DEPTH-1),
        .DATA_WIDTH(ENTRY_ADDR_WIDTH))
      ht_sr_hash_index (
        .clock(clock),
        .reset(reset),
        .input_data(ht_sr_out_hash_index[i-1]),
        .output_data(ht_sr_out_hash_index[i])
      );
      // opcode shift register
      Shift_Register #(
        .NPIPE_DEPTH(RAM_PIPE_DEPTH-1),
        .DATA_WIDTH(OPCODE_WIDTH))
      ht_sr_opcode (
        .clock(clock),
        .reset(reset),
        .input_data(ht_sr_out_opcode[i-1]),
        .output_data(ht_sr_out_opcode[i])
      );
      // key shift register
      Shift_Register #(
        .NPIPE_DEPTH(RAM_PIPE_DEPTH-1),
        .DATA_WIDTH(KEY_WIDTH))
      ht_sr_key (
        .clock(clock),
        .reset(reset),
        .input_data(ht_sr_out_key[i-1]),
        .output_data(ht_sr_out_key[i])
      );
      // read data path shift register
      Shift_Register #(
        .NPIPE_DEPTH(RAM_PIPE_DEPTH-2), // -2 because need 1 cycle to check hit/miss
        .DATA_WIDTH(VAL_WIDTH))
      ht_sr_val (
        .clock(clock),
        .reset(reset),
        .input_data(ht_out_val[i-1]),
        .output_data(ht_sr_out_val[i])
      );
      // slot id shift register
      Shift_Register #(
        .NPIPE_DEPTH(RAM_PIPE_DEPTH-1),
        .DATA_WIDTH(LINE_MASK_WIDTH))
      ht_sr_wr_mask (
        .clock(clock),
        .reset(reset),
        .input_data(ht_out_wr_mask[i-1]),
        .output_data(ht_sr_out_wr_mask[i])
      );
      // wr_data shift register
      Shift_Register #(
        .NPIPE_DEPTH(RAM_PIPE_DEPTH-1),
        .DATA_WIDTH(VAL_WIDTH))
      ht_sr_wr_data (
        .clock(clock),
        .reset(reset),
        .input_data(ht_sr_out_wr_data[i-1]),
        .output_data(ht_sr_out_wr_data[i])
      );
      // rescode shift register
      Shift_Register #(
        .NPIPE_DEPTH(RAM_PIPE_DEPTH-2), // -2 because need 1 cycle to check hit/miss
        .DATA_WIDTH(RESCODE_WIDTH))
      ht_sr_rescode (
        .clock(clock),
        .reset(reset),
        .input_data(ht_out_rescode[i-1]),
        .output_data(ht_sr_out_rescode[i])
      );
    end
  end endgenerate

  generate for (i = 0; i < NUM_HASH_TABLES; i = i + 1) begin
    if (i == 0 && i == PE_ID) begin
      // xpm_memory_sdpram: Simple Dual Port RAM
      // Xilinx Parameterized Macro, version 2018.3
      xpm_memory_sdpram #(
         .ADDR_WIDTH_A(ENTRY_ADDR_WIDTH),// DECIMAL
         .ADDR_WIDTH_B(ENTRY_ADDR_WIDTH),// DECIMAL
         .BYTE_WRITE_WIDTH_A(8),         // DECIMAL
         .CLOCKING_MODE("common_clock"), // String
         .ECC_MODE("no_ecc"),            // String
         .MEMORY_PRIMITIVE("ultra"),     // String
         .MEMORY_SIZE(HASH_TABLE_BITS),  // DECIMAL
         .READ_DATA_WIDTH_B(LINE_WIDTH), // DECIMAL
         .READ_LATENCY_B(RAM_PIPE_DEPTH),// DECIMAL
         .WRITE_DATA_WIDTH_A(LINE_WIDTH),// DECIMAL
         .WRITE_MODE_B("read_first"))    // String
      hash_table_block (
         .rstb(reset),
         .clka(clock),
         .ena(master_ht_in_wr_valid),
         .wea(ht_out_wr_mask[NUM_HASH_TABLES-1]),
         .addra(master_ht_in_wr_hash_index),
         .dina({
              // HARDCODE
              master_ht_in_wr_wr_data, master_ht_in_wr_key,
              master_ht_in_wr_wr_data, master_ht_in_wr_key,
              master_ht_in_wr_wr_data, master_ht_in_wr_key,
              master_ht_in_wr_wr_data, master_ht_in_wr_key
            }),
         .enb(hu_sr_out_valid),
         .addrb(hu_out_hash_index),
         .doutb(ht_ram_out_val[i]),
         .regceb(1'b1)
      );
    end else if (i == 0 && i != PE_ID) begin
      // xpm_memory_sdpram: Simple Dual Port RAM
      // Xilinx Parameterized Macro, version 2018.3
      xpm_memory_sdpram #(
         .ADDR_WIDTH_A(ENTRY_ADDR_WIDTH),// DECIMAL
         .ADDR_WIDTH_B(ENTRY_ADDR_WIDTH),// DECIMAL
         .BYTE_WRITE_WIDTH_A(8),         // DECIMAL
         .CLOCKING_MODE("common_clock"), // String
         .ECC_MODE("no_ecc"),            // String
         .MEMORY_PRIMITIVE("ultra"),      // String
         .MEMORY_SIZE(HASH_TABLE_BITS),  // DECIMAL
         .READ_DATA_WIDTH_B(LINE_WIDTH), // DECIMAL
         .READ_LATENCY_B(RAM_PIPE_DEPTH),// DECIMAL
         .WRITE_DATA_WIDTH_A(LINE_WIDTH),// DECIMAL
         .WRITE_MODE_B("read_first"))    // String
      hash_table_block (
         .rstb(reset),
         .clka(clock),
         .ena(input_ht_wr_valid[i:i]),
         .wea(input_ht_wr_wr_mask[(i+1)*LINE_MASK_WIDTH-1:i*LINE_MASK_WIDTH]),
         .addra(input_ht_wr_hash_index[(i+1)*ENTRY_ADDR_WIDTH-1:i*ENTRY_ADDR_WIDTH]),
         .dina({
              // HARDCODE
              input_ht_wr_wr_data[(i+1)*VAL_WIDTH-1:i*VAL_WIDTH], input_ht_wr_key[(i+1)*KEY_WIDTH-1:i*KEY_WIDTH],
              input_ht_wr_wr_data[(i+1)*VAL_WIDTH-1:i*VAL_WIDTH], input_ht_wr_key[(i+1)*KEY_WIDTH-1:i*KEY_WIDTH],
              input_ht_wr_wr_data[(i+1)*VAL_WIDTH-1:i*VAL_WIDTH], input_ht_wr_key[(i+1)*KEY_WIDTH-1:i*KEY_WIDTH],
              input_ht_wr_wr_data[(i+1)*VAL_WIDTH-1:i*VAL_WIDTH], input_ht_wr_key[(i+1)*KEY_WIDTH-1:i*KEY_WIDTH]
            }),
         .enb(hu_sr_out_valid),
         .addrb(hu_out_hash_index),
         .doutb(ht_ram_out_val[i]),
         .regceb(1'b1)
      );
    end else if (i != 0 && i == PE_ID) begin
      // xpm_memory_sdpram: Simple Dual Port RAM
      // Xilinx Parameterized Macro, version 2018.3
      xpm_memory_sdpram #(
         .ADDR_WIDTH_A(ENTRY_ADDR_WIDTH),// DECIMAL
         .ADDR_WIDTH_B(ENTRY_ADDR_WIDTH),// DECIMAL
         .BYTE_WRITE_WIDTH_A(8),         // DECIMAL
         .CLOCKING_MODE("common_clock"), // String
         .ECC_MODE("no_ecc"),            // String
         .MEMORY_PRIMITIVE("ultra"),      // String
         .MEMORY_SIZE(HASH_TABLE_BITS),  // DECIMAL
         .READ_DATA_WIDTH_B(LINE_WIDTH), // DECIMAL
         .READ_LATENCY_B(RAM_PIPE_DEPTH),// DECIMAL
         .WRITE_DATA_WIDTH_A(LINE_WIDTH),// DECIMAL
         .WRITE_MODE_B("read_first"))    // String
      hash_table_block (
         .rstb(reset),
         .clka(clock),
         .ena(master_ht_in_wr_valid),
         .wea(ht_out_wr_mask[NUM_HASH_TABLES-1]),
         .addra(master_ht_in_wr_hash_index),
         .dina({
              // HARDCODE
              master_ht_in_wr_wr_data, master_ht_in_wr_key,
              master_ht_in_wr_wr_data, master_ht_in_wr_key,
              master_ht_in_wr_wr_data, master_ht_in_wr_key,
              master_ht_in_wr_wr_data, master_ht_in_wr_key
            }),
         .enb(ht_sr_out_valid[i-1]),
         .addrb(ht_sr_out_hash_index[i-1]),
         .doutb(ht_ram_out_val[i]),
         .regceb(1'b1)
      );
    end else begin
      // xpm_memory_sdpram: Simple Dual Port RAM
      // Xilinx Parameterized Macro, version 2018.3
      xpm_memory_sdpram #(
         .ADDR_WIDTH_A(ENTRY_ADDR_WIDTH),// DECIMAL
         .ADDR_WIDTH_B(ENTRY_ADDR_WIDTH),// DECIMAL
         .BYTE_WRITE_WIDTH_A(8),         // DECIMAL
         .CLOCKING_MODE("common_clock"), // String
         .ECC_MODE("no_ecc"),            // String
         .MEMORY_PRIMITIVE("ultra"),      // String
         .MEMORY_SIZE(HASH_TABLE_BITS),  // DECIMAL
         .READ_DATA_WIDTH_B(LINE_WIDTH), // DECIMAL
         .READ_LATENCY_B(RAM_PIPE_DEPTH),// DECIMAL
         .WRITE_DATA_WIDTH_A(LINE_WIDTH),// DECIMAL
         .WRITE_MODE_B("read_first"))    // String
      hash_table_block (
         .rstb(reset),
         .clka(clock),
         .ena(input_ht_wr_valid[i:i]),
         .wea(input_ht_wr_wr_mask[(i+1)*LINE_MASK_WIDTH-1:i*LINE_MASK_WIDTH]),
         .addra(input_ht_wr_hash_index[(i+1)*ENTRY_ADDR_WIDTH-1:i*ENTRY_ADDR_WIDTH]),
         .dina({
              // HARDCODE
              input_ht_wr_wr_data[(i+1)*VAL_WIDTH-1:i*VAL_WIDTH], input_ht_wr_key[(i+1)*KEY_WIDTH-1:i*KEY_WIDTH],
              input_ht_wr_wr_data[(i+1)*VAL_WIDTH-1:i*VAL_WIDTH], input_ht_wr_key[(i+1)*KEY_WIDTH-1:i*KEY_WIDTH],
              input_ht_wr_wr_data[(i+1)*VAL_WIDTH-1:i*VAL_WIDTH], input_ht_wr_key[(i+1)*KEY_WIDTH-1:i*KEY_WIDTH],
              input_ht_wr_wr_data[(i+1)*VAL_WIDTH-1:i*VAL_WIDTH], input_ht_wr_key[(i+1)*KEY_WIDTH-1:i*KEY_WIDTH]
            }),
         .enb(ht_sr_out_valid[i-1]),
         .addrb(ht_sr_out_hash_index[i-1]),
         .doutb(ht_ram_out_val[i]),
         .regceb(1'b1)
      );
    end
  end endgenerate
  // end data processing unit
  
  assign output_valid = ht_sr_out_valid[NUM_HASH_TABLES-1] && (ht_sr_out_opcode[NUM_HASH_TABLES-1] == 4'b0001);
  assign val_out = ht_out_val[NUM_HASH_TABLES-1];
  assign rescode = ht_sr_out_rescode[NUM_HASH_TABLES-1];

  always_ff @ (posedge clock) begin
    if (reset) begin
      master_ht_in_wr_valid <= 0;
      master_ht_in_wr_key <= 0;
      master_ht_in_wr_hash_index <= 0;
      master_ht_in_wr_wr_data <= 0;
    end else begin
      // always write for insert
      if (ht_sr_out_valid[NUM_HASH_TABLES-1] && ht_sr_out_opcode[NUM_HASH_TABLES-1] == 4'b0010) begin
        master_ht_in_wr_valid <= ht_sr_out_valid[NUM_HASH_TABLES-1];
        master_ht_in_wr_key <= ht_sr_out_key[NUM_HASH_TABLES-1];
        master_ht_in_wr_hash_index <= ht_sr_out_hash_index[NUM_HASH_TABLES-1];
        master_ht_in_wr_wr_data <= ht_sr_out_wr_data[NUM_HASH_TABLES-1];
      // only write for delete with hit
      end else if (ht_sr_out_valid[NUM_HASH_TABLES-1] &&                // valid
                   ht_sr_out_opcode[NUM_HASH_TABLES-1] == 4'b0011 &&    // delete
                   ht_sr_out_rescode[NUM_HASH_TABLES-1][4] == 1'b1) begin   // hit
        master_ht_in_wr_valid <= ht_sr_out_valid[NUM_HASH_TABLES-1];
        master_ht_in_wr_key <= ht_sr_out_key[NUM_HASH_TABLES-1];
        master_ht_in_wr_hash_index <= ht_sr_out_hash_index[NUM_HASH_TABLES-1];
        master_ht_in_wr_wr_data <= ht_sr_out_wr_data[NUM_HASH_TABLES-1];
      end else begin
        master_ht_in_wr_valid <= 0;
        master_ht_in_wr_key <= 0;
        master_ht_in_wr_hash_index <= 0;
        master_ht_in_wr_wr_data <= 0;
      end
    end
  end

  generate for (i = 0; i < NUM_HASH_TABLES; i = i + 1) begin
    if (i == PE_ID) begin
      Shift_Register #(
        .NPIPE_DEPTH(RAM_WR_PIPE_DEPTH),
        .DATA_WIDTH(1))
      ht_wr_sr_valid (
        .clock(clock),
        .reset(reset),
        .input_data(master_ht_in_wr_valid),
        .output_data(output_ht_wr_valid[i:i])
      );
      Shift_Register #(
        .NPIPE_DEPTH(RAM_WR_PIPE_DEPTH),
        .DATA_WIDTH(KEY_WIDTH))
      ht_wr_sr_key (
        .clock(clock),
        .reset(reset),
        .input_data(master_ht_in_wr_key),
        .output_data(output_ht_wr_key[(i+1)*KEY_WIDTH-1:i*KEY_WIDTH])
      );
      Shift_Register #(
        .NPIPE_DEPTH(RAM_WR_PIPE_DEPTH),
        .DATA_WIDTH(ENTRY_ADDR_WIDTH))
      ht_wr_sr_hash_index (
        .clock(clock),
        .reset(reset),
        .input_data(master_ht_in_wr_hash_index),
        .output_data(output_ht_wr_hash_index[(i+1)*ENTRY_ADDR_WIDTH-1:i*ENTRY_ADDR_WIDTH])
      );
      Shift_Register #(
        .NPIPE_DEPTH(RAM_WR_PIPE_DEPTH),
        .DATA_WIDTH(LINE_MASK_WIDTH))
      ht_wr_sr_wr_mask (
        .clock(clock),
        .reset(reset),
        .input_data(ht_out_wr_mask[NUM_HASH_TABLES-1]),
        .output_data(output_ht_wr_wr_mask[(i+1)*LINE_MASK_WIDTH-1:i*LINE_MASK_WIDTH])
      );
      Shift_Register #(
        .NPIPE_DEPTH(RAM_WR_PIPE_DEPTH),
        .DATA_WIDTH(VAL_WIDTH))
      ht_wr_sr_wr_data (
        .clock(clock),
        .reset(reset),
        .input_data(master_ht_in_wr_wr_data),
        .output_data(output_ht_wr_wr_data[(i+1)*VAL_WIDTH-1:i*VAL_WIDTH])
      );
    end else begin
      Shift_Register #(
        .NPIPE_DEPTH(RAM_WR_PIPE_DEPTH),
        .DATA_WIDTH(1))
      ht_wr_sr_valid (
        .clock(clock),
        .reset(reset),
        .input_data(input_ht_wr_valid[i:i]),
        .output_data(output_ht_wr_valid[i:i])
      );
      Shift_Register #(
        .NPIPE_DEPTH(RAM_WR_PIPE_DEPTH),
        .DATA_WIDTH(KEY_WIDTH))
      ht_wr_sr_key (
        .clock(clock),
        .reset(reset),
        .input_data(input_ht_wr_key[(i+1)*KEY_WIDTH-1:i*KEY_WIDTH]),
        .output_data(output_ht_wr_key[(i+1)*KEY_WIDTH-1:i*KEY_WIDTH])
      );
      Shift_Register #(
        .NPIPE_DEPTH(RAM_WR_PIPE_DEPTH),
        .DATA_WIDTH(ENTRY_ADDR_WIDTH))
      ht_wr_sr_hash_index (
        .clock(clock),
        .reset(reset),
        .input_data(input_ht_wr_hash_index[(i+1)*ENTRY_ADDR_WIDTH-1:i*ENTRY_ADDR_WIDTH]),
        .output_data(output_ht_wr_hash_index[(i+1)*ENTRY_ADDR_WIDTH-1:i*ENTRY_ADDR_WIDTH])
      );
      Shift_Register #(
        .NPIPE_DEPTH(RAM_WR_PIPE_DEPTH),
        .DATA_WIDTH(LINE_MASK_WIDTH))
      ht_wr_sr_wr_mask (
        .clock(clock),
        .reset(reset),
        .input_data(input_ht_wr_wr_mask[(i+1)*LINE_MASK_WIDTH-1:i*LINE_MASK_WIDTH]),
        .output_data(output_ht_wr_wr_mask[(i+1)*LINE_MASK_WIDTH-1:i*LINE_MASK_WIDTH])
      );
      Shift_Register #(
        .NPIPE_DEPTH(RAM_WR_PIPE_DEPTH),
        .DATA_WIDTH(VAL_WIDTH))
      ht_wr_sr_wr_data (
        .clock(clock),
        .reset(reset),
        .input_data(input_ht_wr_wr_data[(i+1)*VAL_WIDTH-1:i*VAL_WIDTH]),
        .output_data(output_ht_wr_wr_data[(i+1)*VAL_WIDTH-1:i*VAL_WIDTH])
      );
    end
  end endgenerate

endmodule
