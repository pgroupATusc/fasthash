# FASTHash: FPGA-Based High Throughput Parallel Hash Table
Source Code for the paper Titled FASTHash: FPGA-Based High Throughput Parallel Hash Table published in ISC high performance 2020

## Hardware/Tools
1. Targeted FPGA: Xilinx U250 <br />
2. Tools: Xilinx Vivado 2019.2  <br />

## Directory Structure
### rtl
This directory contains the RTL source code for the FastHASH implementation.

### test
This directory contains unit testbench for the RTL code.

## Setting up the projects
1. Create a new project using Xilinx Vivado and use Xilinx U250 FPGA as the targeted device. <br />
2. Include project files in rtl folder. <br />
3. Run synthesis and implementation flow. <br />
4. For simulating internal modules (Unit tests), use test benches in test folder <br />
