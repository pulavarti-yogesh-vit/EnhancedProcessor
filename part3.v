// ============================================================================
// Laboratory Exercise 10 - Part III
// DE2-115 Top Level
// ============================================================================

module part3 (KEY, SW, LEDR);

    input  [1:0] KEY;
    input  [9:0] SW;

    output [9:0] LEDR;

    wire [15:0] DOUT;
    wire [15:0] ADDR;

    wire Done;
    wire W;

    reg [15:0] DIN;

    wire inst_mem_cs;
    wire SW_cs;
    wire LED_reg_cs;

    wire [15:0] inst_mem_q;

    wire [8:0] LED_reg;
    wire [8:0] SW_reg;

    wire Resetn;


    // KEY[0] is active-low reset
    // KEY[1] is the manual clock
    assign Resetn = KEY[0];


    // ------------------------------------------------------------------------
    // PROCESSOR
    // ------------------------------------------------------------------------
    proc U3 (
        DIN,
        Resetn,
        KEY[1],
        SW[9],
        DOUT,
        ADDR,
        W,
        Done
    );


    // ------------------------------------------------------------------------
    // ADDRESS DECODER
    //
    // 0x0xxx -> instruction/data memory
    // 0x1xxx -> LED output register
    // 0x3xxx -> switch input register
    // ------------------------------------------------------------------------
    assign inst_mem_cs = (ADDR[15:12] == 4'h0);

    assign LED_reg_cs =
        (ADDR[15:12] == 4'h1);

    assign SW_cs =
        (ADDR[15:12] == 4'h3);


    // ------------------------------------------------------------------------
    // 256 x 16 SYNCHRONOUS MEMORY
    // ------------------------------------------------------------------------
    inst_mem U4 (
        ADDR[7:0],
        KEY[1],
        DOUT,
        inst_mem_cs & W,
        inst_mem_q
    );


    // ------------------------------------------------------------------------
    // INPUT MULTIPLEXER
    // ------------------------------------------------------------------------
    always @(*) begin

        if (inst_mem_cs == 1'b1)

            DIN = inst_mem_q;

        else if (SW_cs == 1'b1)

            DIN = {7'b0000000, SW_reg};

        else

            DIN = 16'bxxxxxxxxxxxxxxxx;

    end


    // ------------------------------------------------------------------------
    // LED OUTPUT REGISTER
    // ------------------------------------------------------------------------
    regn #(.n(9)) U5 (
        DOUT[8:0],
        Resetn,
        LED_reg_cs & W,
        KEY[1],
        LED_reg
    );


    assign LEDR[8:0] = LED_reg;

    assign LEDR[9] = SW[9];


    // ------------------------------------------------------------------------
    // SWITCH INPUT REGISTER
    // ------------------------------------------------------------------------
    regn #(.n(9)) U7 (
        SW[8:0],
        Resetn,
        1'b1,
        KEY[1],
        SW_reg
    );

endmodule