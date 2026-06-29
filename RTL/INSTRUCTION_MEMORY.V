// ============================================================================
// Instruction Memory
// Read-only memory for storing program instructions
// 256 words (1KB) capacity
// ============================================================================

module instruction_memory (
    input wire [7:0] address,  // 8-bit address for 256 words
    output reg [31:0] instruction
);

    // Instruction memory array
    reg [31:0] memory [0:255];
    
    // Initialize with a sample program
    initial begin
        // Program: Calculate sum of array elements
        // Initialize all to NOP first
        integer i;
        for (i = 0; i < 256; i = i + 1) begin
            memory[i] = 32'h00000000; // NOP
        end
        
        // Test Program 1: Basic ALU operations and hazard testing
        // R0 = 0 (hardwired)
        // Initialize registers
        memory[0] = 32'h20010005;  // ADDI $1, $0, 5      # $1 = 5
        memory[1] = 32'h20020003;  // ADDI $2, $0, 3      # $2 = 3
        memory[2] = 32'h20030007;  // ADDI $3, $0, 7      # $3 = 7
        memory[3] = 32'h2004000A;  // ADDI $4, $0, 10     # $4 = 10
        
        // Test data forwarding (EX hazard)
        memory[4] = 32'h00221820;  // ADD $3, $1, $2      # $3 = 5 + 3 = 8
        memory[5] = 32'h00832020;  // ADD $4, $4, $3      # $4 = 10 + 8 = 18 (needs forwarding)
        
        // Test load-use hazard (forces pipeline stall)
        memory[6] = 32'hAC010000;  // SW $1, 0($0)        # MEM[0] = 5
        memory[7] = 32'h8C050000;  // LW $5, 0($0)        # $5 = MEM[0] = 5
        memory[8] = 32'h00A52820;  // ADD $5, $5, $5      # $5 = 5 + 5 = 10 (needs stall)
        
        // Test branch instructions
        memory[9] = 32'h20060008;  // ADDI $6, $0, 8      # $6 = 8
        memory[10] = 32'h20070008; // ADDI $7, $0, 8      # $7 = 8
        memory[11] = 32'h10C70002; // BEQ $6, $7, 2       # if $6==$7, skip 2 instructions
        memory[12] = 32'h20080064; // ADDI $8, $0, 100    # $8 = 100 (should be skipped)
        memory[13] = 32'h200900C8; // ADDI $9, $0, 200    # $9 = 200 (should be skipped)
        memory[14] = 32'h200A000F; // ADDI $10, $0, 15    # $10 = 15 (should execute)
        
        // Test logical operations
        memory[15] = 32'h200B000F; // ADDI $11, $0, 15    # $11 = 0x0F
        memory[16] = 32'h200C00F0; // ADDI $12, $0, 240   # $12 = 0xF0
        memory[17] = 32'h016C6824; // AND $13, $11, $12   # $13 = 0x0F & 0xF0 = 0
        memory[18] = 32'h016C7025; // OR $14, $11, $12    # $14 = 0x0F | 0xF0 = 0xFF
        
        // Test SLT (Set Less Than)
        memory[19] = 32'h200F0014; // ADDI $15, $0, 20    # $15 = 20
        memory[20] = 32'h2010000A; // ADDI $16, $0, 10    # $16 = 10
        memory[21] = 32'h020F882A; // SLT $17, $16, $15   # $17 = (10<20) = 1
        
        // Memory operations test
        memory[22] = 32'hAC0F0004; // SW $15, 4($0)       # MEM[1] = 20
        memory[23] = 32'hAC100008; // SW $16, 8($0)       # MEM[2] = 10
        memory[24] = 32'h8C120004; // LW $18, 4($0)       # $18 = MEM[1] = 20
        memory[25] = 32'h8C130008; // LW $19, 8($0)       # $19 = MEM[2] = 10
        memory[26] = 32'h02539820; // ADD $19, $18, $19   # $19 = 20 + 10 = 30
        
        // Test multiple dependencies
        memory[27] = 32'h201400FF; // ADDI $20, $0, 255   # $20 = 255
        memory[28] = 32'h2015000F; // ADDI $21, $0, 15    # $21 = 15
        memory[29] = 32'h0295A824; // AND $21, $20, $21   # $21 = 255 & 15 = 15
        memory[30] = 32'h22B50001; // ADDI $21, $21, 1    # $21 = 15 + 1 = 16
        
        // Loop test
        memory[31] = 32'h20160000; // ADDI $22, $0, 0     # $22 = 0 (counter)
        memory[32] = 32'h20170005; // ADDI $23, $0, 5     # $23 = 5 (limit)
        // Loop body starts at address 33
        memory[33] = 32'h22D60001; // ADDI $22, $22, 1    # $22++
        memory[34] = 32'h16D7FFFE; // BNE $22, $23, -2    # if $22!=5, go back to memory[33]
        
        // Final operations
        memory[35] = 32'h201800AA; // ADDI $24, $0, 170   # $24 = 0xAA
        memory[36] = 32'h20190055; // ADDI $25, $0, 85    # $25 = 0x55
        memory[37] = 32'h0319D025; // OR $26, $24, $25    # $26 = 0xAA | 0x55 = 0xFF
        memory[38] = 32'h0319D826; // XOR $27, $24, $25   # $27 = 0xAA ^ 0x55 = 0xFF
        
        // End program
        memory[39] = 32'h00000000; // NOP
        memory[40] = 32'h00000000; // NOP
    end
    
    // Asynchronous read
    always @(*) begin
        instruction = memory[address];
    end
    
endmodule

// ============================================================================
// Data Memory
// Read/Write memory for data storage
// 256 words (1KB) capacity
// ============================================================================

module data_memory (
    input wire clk,
    input wire [7:0] address,
    input wire [31:0] write_data,
    input wire mem_read,
    input wire mem_write,
    output reg [31:0] read_data
);

    // Data memory array
    reg [31:0] memory [0:255];
    
    integer i;
    
    // Initialize memory
    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            memory[i] = 32'd0;
        end
    end
    
    // Synchronous write
    always @(posedge clk) begin
        if (mem_write) begin
            memory[address] <= write_data;
        end
    end
    
    // Asynchronous read
    always @(*) begin
        if (mem_read) begin
            read_data = memory[address];
        end else begin
            read_data = 32'd0;
        end
    end
    
endmodule
