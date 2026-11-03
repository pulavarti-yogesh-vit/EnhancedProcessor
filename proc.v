// ============================================================================
// Laboratory Exercise 10 - Part III
// Enhanced Processor
// r7 is used as the Program Counter (pc)
//
// Instructions: 000 mv, 001 mvt, 010 add, 011 sub, 100 ld, 101 st, 110 and
//
// CHANGE: ld now finishes in T4 (5 cycles) - only for reading switches.
// ============================================================================

module proc (DIN, Resetn, Clock, Run, DOUT, ADDR, W, Done);

    input  [15:0] DIN;
    input         Resetn, Clock, Run;

    output [15:0] DOUT;
    output [15:0] ADDR;
    output        W;
    output        Done;

    wire [15:0] BusWires;
    wire [15:0] IR;
    wire [15:0] A;
    wire [15:0] G;
    wire [15:0] ALUout;

    wire [15:0] r0, r1, r2, r3;
    wire [15:0] r4, r5, r6, pc;

    wire [7:0] R_in;

    wire IR_in;
    wire A_in;
    wire G_in;

    wire ADDR_in;
    wire DOUT_in;

    wire pc_incr;

    wire AddSub;
    wire ALU_and;

    wire W_D;

    wire [3:0] Select;

    // CONTROL UNIT
    control_fsm CU (
        Clock, Resetn, Run, IR,
        IR_in, R_in,
        A_in, G_in,
        ADDR_in, DOUT_in,
        pc_incr,
        AddSub, ALU_and,
        W_D,
        Select, Done
    );

    // INSTRUCTION REGISTER
    regn #(.n(16)) reg_IR (DIN, Resetn, IR_in, Clock, IR);

    // GENERAL-PURPOSE REGISTERS
    regn #(.n(16)) reg_0 (BusWires, Resetn, R_in[0], Clock, r0);
    regn #(.n(16)) reg_1 (BusWires, Resetn, R_in[1], Clock, r1);
    regn #(.n(16)) reg_2 (BusWires, Resetn, R_in[2], Clock, r2);
    regn #(.n(16)) reg_3 (BusWires, Resetn, R_in[3], Clock, r3);
    regn #(.n(16)) reg_4 (BusWires, Resetn, R_in[4], Clock, r4);
    regn #(.n(16)) reg_5 (BusWires, Resetn, R_in[5], Clock, r5);
    regn #(.n(16)) reg_6 (BusWires, Resetn, R_in[6], Clock, r6);

    // r7 = PROGRAM COUNTER
    pc_reg reg_pc (BusWires, Resetn, R_in[7], pc_incr, Clock, pc);

    // A REGISTER
    regn #(.n(16)) reg_A (BusWires, Resetn, A_in, Clock, A);

    // ALU
    alu ALU (A, BusWires, AddSub, ALU_and, ALUout);

    // G REGISTER
    regn #(.n(16)) reg_G (ALUout, Resetn, G_in, Clock, G);

    // ADDRESS REGISTER
    regn #(.n(16)) reg_ADDR (BusWires, Resetn, ADDR_in, Clock, ADDR);

    // DATA OUTPUT REGISTER
    regn #(.n(16)) reg_DOUT (BusWires, Resetn, DOUT_in, Clock, DOUT);

    // WRITE FLIP-FLOP
    flipflop reg_W (W_D, Resetn, Clock, W);

    // BUS MULTIPLEXER
    busmux MUX (
        Select,
        r0, r1, r2, r3, r4, r5, r6, pc,
        G, IR, DIN,
        BusWires
    );

endmodule


// ============================================================================
// CONTROL FSM
//
// T0 : pc -> ADDR, pc <- pc + 1
// T1 : wait for synchronous memory
// T2 : DIN -> IR
// T3-T5 : execute instruction
// ============================================================================
module control_fsm (
    Clock,
    Resetn,
    Run,
    IR,

    IR_in,
    R_in,

    A_in,
    G_in,

    ADDR_in,
    DOUT_in,

    pc_incr,

    AddSub,
    ALU_and,

    W_D,

    Select,
    Done
);

    input         Clock, Resetn, Run;
    input  [15:0] IR;

    output reg       IR_in;
    output [7:0]     R_in;

    output reg       A_in;
    output reg       G_in;

    output reg       ADDR_in;
    output reg       DOUT_in;

    output reg       pc_incr;

    output reg       AddSub;
    output reg       ALU_and;

    output reg       W_D;

    output reg [3:0] Select;
    output reg       Done;

    // INSTRUCTION FIELDS
    wire [2:0] III;
    wire       IMM;
    wire [2:0] rX;
    wire [2:0] rY;

    assign III = IR[15:13];
    assign IMM = IR[12];
    assign rX  = IR[11:9];
    assign rY  = IR[2:0];

    // OPCODES
    parameter mv     = 3'b000;
    parameter mvt    = 3'b001;
    parameter add    = 3'b010;
    parameter sub    = 3'b011;
    parameter ld     = 3'b100;
    parameter st     = 3'b101;
    parameter and_op = 3'b110;

    // BUS MULTIPLEXER SELECT CODES
    parameter _G         = 4'b1000;
    parameter _IR8_IR8_0 = 4'b1001;
    parameter _IR7_0_0   = 4'b1010;
    parameter _DIN       = 4'b1011;

    // FSM STATES
    parameter T0 = 3'd0;
    parameter T1 = 3'd1;
    parameter T2 = 3'd2;
    parameter T3 = 3'd3;
    parameter T4 = 3'd4;
    parameter T5 = 3'd5;

    reg [2:0] Tstep_Q;
    reg [2:0] Tstep_D;

    reg rX_in;

    // rX DECODER
    dec3to8 decX (rX_in, rX, R_in);

    // STATE REGISTER
    always @(posedge Clock or negedge Resetn) begin
        if (!Resetn)
            Tstep_Q <= T0;
        else
            Tstep_Q <= Tstep_D;
    end

    // NEXT-STATE LOGIC
    always @(*) begin

        Tstep_D = Tstep_Q;

        case (Tstep_Q)

            T0: begin
                if (Run)
                    Tstep_D = T1;
                else
                    Tstep_D = T0;
            end

            T1:
                Tstep_D = T2;

            T2:
                Tstep_D = T3;

            T3: begin
                case (III)
                    mv, mvt:
                        Tstep_D = T0;
                    add, sub, and_op:
                        Tstep_D = T4;
                    ld, st:
                        Tstep_D = T4;
                    default:
                        Tstep_D = T0;
                endcase
            end

            T4: begin
                case (III)
                    add, sub, and_op:
                        Tstep_D = T5;
                    ld:
                        Tstep_D = T0;   // CHANGED: ld ends in T4
                    st:
                        Tstep_D = T0;
                    default:
                        Tstep_D = T0;
                endcase
            end

            T5:
                Tstep_D = T0;

            default:
                Tstep_D = T0;

        endcase
    end

    // CONTROL OUTPUT LOGIC
    always @(*) begin

        // Defaults
        IR_in    = 1'b0;
        rX_in    = 1'b0;

        A_in     = 1'b0;
        G_in     = 1'b0;

        ADDR_in  = 1'b0;
        DOUT_in  = 1'b0;

        pc_incr  = 1'b0;

        AddSub   = 1'b0;
        ALU_and  = 1'b0;

        W_D      = 1'b0;

        Select   = 4'b0000;

        Done     = 1'b0;

        case (Tstep_Q)

            // T0 : ADDR <- pc, pc <- pc + 1
            T0: begin
                if (Run) begin
                    Select  = 4'b0111;
                    ADDR_in = 1'b1;
                    pc_incr = 1'b1;
                end
            end

            // T1 : wait for synchronous memory
            T1: begin
            end

            // T2 : IR <- DIN
            T2: begin
                IR_in = 1'b1;
            end

            // T3
            T3: begin
                case (III)

                    // mv rX, Op2
                    mv: begin
                        if (IMM)
                            Select = _IR8_IR8_0;
                        else
                            Select = {1'b0, rY};
                        rX_in = 1'b1;
                        Done  = 1'b1;
                    end

                    // mvt rX,#D
                    mvt: begin
                        Select = _IR7_0_0;
                        rX_in  = 1'b1;
                        Done   = 1'b1;
                    end

                    // add / sub / and : A <- rX
                    add, sub, and_op: begin
                        Select = {1'b0, rX};
                        A_in   = 1'b1;
                    end

                    // ld rX,[rY] : ADDR <- rY
                    ld: begin
                        Select  = {1'b0, rY};
                        ADDR_in = 1'b1;
                    end

                    // st rX,[rY] : ADDR <- rY
                    st: begin
                        Select  = {1'b0, rY};
                        ADDR_in = 1'b1;
                    end

                    default: begin
                        Done = 1'b1;
                    end

                endcase
            end

            // T4
            T4: begin
                case (III)

                    // ADD : G <- A + Op2
                    add: begin
                        if (IMM)
                            Select = _IR8_IR8_0;
                        else
                            Select = {1'b0, rY};
                        G_in = 1'b1;
                    end

                    // SUB : G <- A - Op2
                    sub: begin
                        if (IMM)
                            Select = _IR8_IR8_0;
                        else
                            Select = {1'b0, rY};
                        AddSub = 1'b1;
                        G_in   = 1'b1;
                    end

                    // AND : G <- A & Op2
                    and_op: begin
                        if (IMM)
                            Select = _IR8_IR8_0;
                        else
                            Select = {1'b0, rY};
                        ALU_and = 1'b1;
                        G_in    = 1'b1;
                    end

                    // LD : rX <- DIN   (CHANGED: done here in T4)
                    ld: begin
                        Select = _DIN;
                        rX_in  = 1'b1;
                        Done   = 1'b1;
                    end

                    // ST : DOUT <- rX, W = 1
                    st: begin
                        Select  = {1'b0, rX};
                        DOUT_in = 1'b1;
                        W_D     = 1'b1;
                        Done    = 1'b1;
                    end

                    default: begin
                    end

                endcase
            end

            // T5
            T5: begin
                case (III)

                    // ADD / SUB / AND : rX <- G
                    add, sub, and_op: begin
                        Select = _G;
                        rX_in  = 1'b1;
                        Done   = 1'b1;
                    end

                    // (ld branch removed - ld ends in T4 now)

                    default: begin
                    end

                endcase
            end

            default: begin
            end

        endcase
    end

endmodule


// ============================================================================
// PARAMETERIZED REGISTER
// ============================================================================
module regn (R, Resetn, Rin, Clock, Q);

    parameter n = 16;

    input      [n-1:0] R;
    input              Resetn;
    input              Rin;
    input              Clock;

    output reg [n-1:0] Q;

    always @(posedge Clock or negedge Resetn) begin
        if (!Resetn)
            Q <= {n{1'b0}};
        else if (Rin)
            Q <= R;
    end

endmodule


// ============================================================================
// PROGRAM COUNTER REGISTER (r7 = pc)
// ============================================================================
module pc_reg (R, Resetn, Rin, incr, Clock, Q);

    input [15:0] R;

    input Resetn;
    input Rin;
    input incr;
    input Clock;

    output reg [15:0] Q;

    always @(posedge Clock or negedge Resetn) begin
        if (!Resetn)
            Q <= 16'b0;
        else if (Rin)
            Q <= R;
        else if (incr)
            Q <= Q + 16'd1;
    end

endmodule


// ============================================================================
// ALU
// ============================================================================
module alu (A, B, AddSub, ALU_and, S);

    input [15:0] A;
    input [15:0] B;

    input AddSub;
    input ALU_and;

    output reg [15:0] S;

    always @(*) begin
        if (ALU_and)
            S = A & B;
        else if (AddSub)
            S = A - B;
        else
            S = A + B;
    end

endmodule


// ============================================================================
// BUS MULTIPLEXER
// ============================================================================
module busmux (
    Select,

    r0, r1, r2, r3, r4, r5, r6, pc,

    G, IR, DIN,

    BusWires
);

    input [3:0] Select;

    input [15:0] r0;
    input [15:0] r1;
    input [15:0] r2;
    input [15:0] r3;

    input [15:0] r4;
    input [15:0] r5;
    input [15:0] r6;
    input [15:0] pc;

    input [15:0] G;
    input [15:0] IR;
    input [15:0] DIN;

    output reg [15:0] BusWires;

    always @(*) begin
        case (Select)

            4'b0000: BusWires = r0;
            4'b0001: BusWires = r1;
            4'b0010: BusWires = r2;
            4'b0011: BusWires = r3;
            4'b0100: BusWires = r4;
            4'b0101: BusWires = r5;
            4'b0110: BusWires = r6;
            4'b0111: BusWires = pc;

            4'b1000: BusWires = G;

            // Sign-extended 9-bit immediate
            4'b1001: BusWires = {{7{IR[8]}}, IR[8:0]};

            // mvt immediate << 8
            4'b1010: BusWires = {IR[7:0], 8'b00000000};

            // External DIN
            4'b1011: BusWires = DIN;

            default: BusWires = 16'b0;

        endcase
    end

endmodule


// ============================================================================
// 3-TO-8 DECODER
// ============================================================================
module dec3to8 (E, W, Y);

    input E;
    input [2:0] W;

    output reg [7:0] Y;

    always @(*) begin
        if (!E)
            Y = 8'b00000000;
        else begin
            case (W)
                3'b000: Y = 8'b00000001;
                3'b001: Y = 8'b00000010;
                3'b010: Y = 8'b00000100;
                3'b011: Y = 8'b00001000;
                3'b100: Y = 8'b00010000;
                3'b101: Y = 8'b00100000;
                3'b110: Y = 8'b01000000;
                3'b111: Y = 8'b10000000;
                default: Y = 8'b00000000;
            endcase
        end
    end

endmodule


// ============================================================================
// WRITE FLIP-FLOP
// ============================================================================
module flipflop (D, Resetn, Clock, Q);

    input D;
    input Resetn;
    input Clock;

    output reg Q;

    always @(posedge Clock or negedge Resetn) begin
        if (!Resetn)
            Q <= 1'b0;
        else
            Q <= D;
    end

endmodule