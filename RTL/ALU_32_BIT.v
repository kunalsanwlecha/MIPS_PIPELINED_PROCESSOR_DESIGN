// ============================================================================
// Arithmetic Logic Unit (ALU)
// 32-bit ALU supporting multiple operations
// ============================================================================

module alu (
    input wire [31:0] a,
    input wire [31:0] b,
    input wire [3:0] alu_control,
    output reg [31:0] result,
    output wire zero
);

    // ALU Operations
    localparam ALU_AND = 4'b0000;
    localparam ALU_OR  = 4'b0001;
    localparam ALU_ADD = 4'b0010;
    localparam ALU_SUB = 4'b0110;
    localparam ALU_SLT = 4'b0111; // Set on Less Than
    localparam ALU_NOR = 4'b1100;
    localparam ALU_XOR = 4'b1101;
    localparam ALU_SLL = 4'b1000; // Shift Left Logical
    localparam ALU_SRL = 4'b1001; // Shift Right Logical
    
    always @(*) begin
        case (alu_control)
            ALU_AND: result = a & b;
            ALU_OR:  result = a | b;
            ALU_ADD: result = a + b;
            ALU_SUB: result = a - b;
            ALU_SLT: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            ALU_NOR: result = ~(a | b);
            ALU_XOR: result = a ^ b;
            ALU_SLL: result = a << b[4:0];
            ALU_SRL: result = a >> b[4:0];
            default: result = 32'd0;
        endcase
    end
    
    assign zero = (result == 32'd0);
    
endmodule

// ============================================================================
// ALU Control Unit
// Generates ALU control signal from ALUOp and function code
// ============================================================================

module alu_control (
    input wire [2:0] alu_op,
    input wire [5:0] funct,
    output reg [3:0] alu_control
);

    // ALU Operations (from control unit)
    localparam ALU_OP_ADD = 3'b000;
    localparam ALU_OP_SUB = 3'b001;
    localparam ALU_OP_RTYPE = 3'b010;
    localparam ALU_OP_AND = 3'b011;
    localparam ALU_OP_OR = 3'b100;
    localparam ALU_OP_SLT = 3'b101;
    
    // Function codes for R-type instructions
    localparam FUNCT_ADD = 6'b100000;
    localparam FUNCT_SUB = 6'b100010;
    localparam FUNCT_AND = 6'b100100;
    localparam FUNCT_OR  = 6'b100101;
    localparam FUNCT_SLT = 6'b101010;
    localparam FUNCT_NOR = 6'b100111;
    localparam FUNCT_XOR = 6'b100110;
    localparam FUNCT_SLL = 6'b000000;
    localparam FUNCT_SRL = 6'b000010;
    
    always @(*) begin
        case (alu_op)
            ALU_OP_ADD: alu_control = 4'b0010; // ADD
            ALU_OP_SUB: alu_control = 4'b0110; // SUB
            ALU_OP_AND: alu_control = 4'b0000; // AND
            ALU_OP_OR:  alu_control = 4'b0001; // OR
            ALU_OP_SLT: alu_control = 4'b0111; // SLT
            
            ALU_OP_RTYPE: begin
                case (funct)
                    FUNCT_ADD: alu_control = 4'b0010; // ADD
                    FUNCT_SUB: alu_control = 4'b0110; // SUB
                    FUNCT_AND: alu_control = 4'b0000; // AND
                    FUNCT_OR:  alu_control = 4'b0001; // OR
                    FUNCT_SLT: alu_control = 4'b0111; // SLT
                    FUNCT_NOR: alu_control = 4'b1100; // NOR
                    FUNCT_XOR: alu_control = 4'b1101; // XOR
                    FUNCT_SLL: alu_control = 4'b1000; // SLL
                    FUNCT_SRL: alu_control = 4'b1001; // SRL
                    default:   alu_control = 4'b0000;
                endcase
            end
            
            default: alu_control = 4'b0000;
        endcase
    end
    
endmodule
