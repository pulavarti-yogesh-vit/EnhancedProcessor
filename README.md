# Enhanced 16-bit Processor on DE2-115 FPGA

A multicycle 16-bit processor implemented in Verilog HDL and integrated
with synchronous on-chip RAM, slide-switch input, and LED output on the
**Altera/Intel DE2-115 FPGA development board**.

## Project Overview

This project implements an enhanced processor with a shared 16-bit
datapath bus and a finite-state-machine (FSM) based control unit. The
processor supports register and immediate operations, arithmetic and
logical instructions, and memory load/store instructions.

The design is connected to a memory-mapped interface:

-   **Instruction/data memory:** 256 words × 16 bits.
-   **Switch input:** 9-bit input from `SW[8:0]`.
-   **LED output:** 9-bit output to `LEDR[8:0]`.
-   **Run control:** `SW[9]`.
-   **Reset:** active-low `KEY[0]`.
-   **Manual clock:** `KEY[1]`.

The initialized program reads the switch value and transfers it to the
LED output register.

## Main Features

-   16-bit processor datapath.
-   Seven general-purpose registers (`r0`--`r6`).
-   Register `r7` is used as the program counter (PC).
-   Shared 16-bit bus selected through a multiplexer.
-   ALU operations: addition, subtraction, and bitwise AND.
-   Multicycle FSM with time steps `T0`--`T5`.
-   Synchronous single-port RAM configured as **256 × 16**.
-   Memory-mapped switch input and LED output.
-   MIF-based memory initialization.
-   DE2-115 pin assignments provided in a Tcl file.

## Processor Architecture

The processor contains the following main blocks:

  -----------------------------------------------------------------------
  Block                               Function
  ----------------------------------- -----------------------------------
  Register bank                       Stores 16-bit general-purpose
                                      values in `r0`--`r6`

  Program counter                     `r7`; supplies the instruction
                                      address and can be loaded through
                                      the datapath

  Instruction register                Holds the fetched 16-bit
                                      instruction

  Bus multiplexer                     Selects the source that drives the
                                      shared 16-bit bus

  A register                          Holds the first operand for ALU
                                      operations

  ALU                                 Performs addition, subtraction, or
                                      bitwise AND

  G register                          Stores the intermediate ALU result

  ADDR register                       Holds the memory-mapped address

  DOUT register                       Holds data to be written to a
                                      selected destination

  Control FSM                         Generates the datapath control
                                      signals and sequences instruction
                                      execution
  -----------------------------------------------------------------------

### Instruction Set

The instruction opcode is taken from `IR[15:13]`. The destination/source
register field `rX` is `IR[11:9]`, and the low register field `rY` is
`IR[2:0]`. `IR[12]` selects the immediate or register operand form where
applicable.

  ------------------------------------------------------------------------
  Instruction                                 Opcode Description
  --------------------- ---------------------------- ---------------------
  `mv`                                         `000` Move a register or
                                                     sign-extended
                                                     immediate operand
                                                     into `rX`

  `mvt`                                        `001` Move the 8-bit
                                                     immediate field into
                                                     the upper byte of
                                                     `rX`; lower byte is
                                                     zero

  `add`                                        `010` Add the selected
                                                     second operand to
                                                     `rX`

  `sub`                                        `011` Subtract the selected
                                                     second operand from
                                                     `rX`

  `ld`                                         `100` Load a 16-bit value
                                                     from the address in
                                                     `rY` into `rX`

  `st`                                         `101` Store the contents of
                                                     `rX` at the address
                                                     in `rY`

  `and`                                        `110` Perform bitwise AND
                                                     between `rX` and the
                                                     selected second
                                                     operand
  ------------------------------------------------------------------------

For `add`, `sub`, and `and`, the first operand is captured in the A
register and the result is captured in G before being written back to
`rX`. In this implementation, the `ld` instruction completes in state
`T4`.

### FSM Execution Sequence

  -----------------------------------------------------------------------
  Time step                           Main operation
  ----------------------------------- -----------------------------------
  `T0`                                Select PC onto the bus, load
                                      `ADDR`, and increment PC when `Run`
                                      is asserted

  `T1`                                Wait for the synchronous memory
                                      access

  `T2`                                Load the fetched instruction from
                                      `DIN` into the instruction register

  `T3`                                Execute `mv`/`mvt`, capture ALU
                                      operand, or prepare load/store
                                      address

  `T4`                                Perform ALU operation, complete
                                      `ld`, or perform `st`

  `T5`                                Write the ALU result from G into
                                      destination register for
                                      `add`/`sub`/`and`
  -----------------------------------------------------------------------

## Memory Map and Board Interface

The top-level module decodes the upper address nibble `ADDR[15:12]`.

  -----------------------------------------------------------------------
  Address range           Selected resource       Function
  ----------------------- ----------------------- -----------------------
  `0x0xxx`                Instruction/data RAM    256 × 16 memory; uses
                                                  `ADDR[7:0]`

  `0x1xxx`                LED output register     Captures `DOUT[8:0]`
                                                  when write is enabled

  `0x3xxx`                Switch input register   Returns the registered
                                                  `SW[8:0]` value,
                                                  zero-extended to 16
                                                  bits
  -----------------------------------------------------------------------

### DE2-115 Controls

  Board signal   Role
  -------------- ----------------------------------------------------------
  `KEY[0]`       Active-low asynchronous reset
  `KEY[1]`       Manual clock for processor, RAM, and interface registers
  `SW[9]`        Run control
  `SW[8:0]`      9-bit input data
  `LEDR[9]`      Displays the Run signal
  `LEDR[8:0]`    Displays the registered output data

## Demonstration Program

The memory initialization file contains five instruction words followed
by zeros. The program first forms the memory-mapped LED and switch
addresses, then repeatedly reads the switch input and writes the value
to the LED output.

  ------------------------------------------------------------------------
                Memory address Instruction word      Operation
                               (binary)              
  ---------------------------- --------------------- ---------------------
                           `0` `0011011000010000`    `mvt r3, #0x10` ---
                                                     forms address
                                                     `0x1000` in `r3`

                           `1` `0011100000110000`    `mvt r4, #0x30` ---
                                                     forms address
                                                     `0x3000` in `r4`

                           `2` `1000000000000100`    `ld r0, [r4]` ---
                                                     reads the switch
                                                     input

                           `3` `1010000000000011`    `st r0, [r3]` ---
                                                     writes the value to
                                                     the LED register

                           `4` `0001111000000010`    `mv r7, #2` --- loads
                                                     the PC with address 2
                                                     to repeat the
                                                     input/output sequence
  ------------------------------------------------------------------------

## Repository Contents

Keep the following files in the project repository:

``` text
.
├── README.md
├── part3.v
├── proc.v
├── inst_mem.v
├── inst_mem.mif
└── part3_pins.tcl
```

  -----------------------------------------------------------------------
  File                                Description
  ----------------------------------- -----------------------------------
  `part3.v`                           Top-level DE2-115 module;
                                      instantiates the processor and RAM,
                                      decodes addresses, selects input
                                      data, and drives the LED register

  `proc.v`                            Processor RTL, including the
                                      control FSM, datapath registers,
                                      program counter, ALU, bus
                                      multiplexer, and supporting modules

  `inst_mem.v`                        Quartus-generated single-port RAM
                                      wrapper using the `altsyncram`
                                      megafunction

  `inst_mem.mif`                      256 × 16 memory initialization file
                                      containing the demonstration
                                      program

  `part3_pins.tcl`                    DE2-115 pin-location and 3.3-V
                                      LVTTL I/O-standard assignments
  -----------------------------------------------------------------------

## Tools and Target Hardware

-   **Hardware:** Altera/Intel DE2-115 FPGA development board.
-   **FPGA family specified in the RAM wrapper:** Cyclone IV E.
-   **HDL:** Verilog.
-   **FPGA design software:** Intel/Altera Quartus Prime (the RAM
    wrapper was generated with Quartus Prime Lite Edition 23.1 Standard
    build).
-   **Simulation:** ModelSim may be used for RTL simulation.

The RAM wrapper instantiates the Intel/Altera `altsyncram` megafunction
and requires the corresponding `altera_mf` simulation library when
simulating the design.

## How to Build and Run

1.  Create or open a Quartus project targeting the Cyclone IV E device
    fitted to the DE2-115 board.
2.  Add `part3.v`, `proc.v`, and `inst_mem.v` to the project.
3.  Place `inst_mem.mif` in the project directory so that the RAM
    initialization-file reference can be resolved.
4.  Set `part3` as the top-level entity.
5.  Apply the board pin assignments from `part3_pins.tcl`. This can be
    done through the Quartus Tcl Console or by adding the assignments to
    the project.
6.  Compile the project in Quartus Prime.
7.  Program the DE2-115 FPGA with the generated programming file.
8.  Assert reset using `KEY[0]`, provide the input value on `SW[8:0]`,
    and use `SW[9]` to enable processor operation.
9.  Apply manual clock pulses using `KEY[1]`. The registered output is
    displayed on `LEDR[8:0]`; `LEDR[9]` mirrors the Run input.

**Note:** `KEY[0]` is active-low. The exact programming and
device-selection steps depend on the Quartus project setup and the
specific DE2-115 board revision.

## Results
<img width="4096" height="3072" alt="IMG20261103105312" src="https://github.com/user-attachments/assets/5b102989-f537-4d01-ac83-97f780c2e637" />



## GitHub Repository

Repository URL: https://github.com/pulavarti-yogesh-vit/EnhancedProcessor

## Author

**Pulavarti Yogesh**\
M.Tech -- VLSI Design\
Registration No.: 26MVD0064\
Course: Digital System Design with FPGA (MAVLD503)\
Semester: Fall 2025--2026
