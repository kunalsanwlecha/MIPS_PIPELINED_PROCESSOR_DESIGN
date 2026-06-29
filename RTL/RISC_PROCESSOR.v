// ============================================================================
// 32-bit Pipelined RISC Processor with Branch Prediction
// Author: KUNAL SANWLECHA
// Description: 5-stage pipeline (IF, ID, EX, MEM, WB) with hazard detection
// ============================================================================

module risc_processor (
    input wire clk,
    input wire rst,
    output wire [31:0] pc_out,
    output wire [31:0] instruction_out,
    output wire [31:0] alu_result_out,
    output wire [4:0] write_reg_out,
    output wire reg_write_out,
    output wire [1:0] pipeline_stall_indicator,
    output wire branch_taken_out,
    output wire [31:0] branch_target_out
);

    // ========== Pipeline Stage Registers ==========
    // IF/ID Pipeline Register
    reg [31:0] ifid_pc;
    reg [31:0] ifid_instruction;
    reg ifid_valid;
    
    // ID/EX Pipeline Register
    reg [31:0] idex_pc;
    reg [31:0] idex_read_data1;
    reg [31:0] idex_read_data2;
    reg [31:0] idex_sign_extended;
    reg [4:0] idex_rs;
    reg [4:0] idex_rt;
    reg [4:0] idex_rd;
    reg [5:0] idex_opcode;
    reg [5:0] idex_funct;
    reg idex_reg_dst;
    reg idex_alu_src;
    reg idex_mem_to_reg;
    reg idex_reg_write;
    reg idex_mem_read;
    reg idex_mem_write;
    reg idex_branch;
    reg [2:0] idex_alu_op;
    reg idex_valid;
    
    // EX/MEM Pipeline Register
    reg [31:0] exmem_alu_result;
    reg [31:0] exmem_write_data;
    reg [4:0] exmem_write_reg;
    reg exmem_zero_flag;
    reg exmem_mem_to_reg;
    reg exmem_reg_write;
    reg exmem_mem_read;
    reg exmem_mem_write;
    reg exmem_branch;
    reg [5:0] exmem_opcode;
    reg [31:0] exmem_branch_target;
    reg exmem_valid;
    
    // MEM/WB Pipeline Register
    reg [31:0] memwb_read_data;
    reg [31:0] memwb_alu_result;
    reg [4:0] memwb_write_reg;
    reg memwb_mem_to_reg;
    reg memwb_reg_write;
    reg memwb_valid;
    
    // ========== Internal Signals ==========
    wire [31:0] pc_current;
    wire [31:0] pc_next;
    wire [31:0] pc_plus4;
    wire [31:0] instruction;
    
    // Control signals
    wire reg_dst, alu_src, mem_to_reg, reg_write, mem_read, mem_write, branch;
    wire [2:0] alu_op;
    
    // Register file signals
    wire [31:0] read_data1, read_data2;
    wire [31:0] write_data;
    wire [4:0] write_reg;
    
    // ALU signals
    wire [31:0] alu_input2;
    wire [31:0] alu_result;
    wire zero_flag;
    wire [3:0] alu_control;
    
    // Data memory signals
    wire [31:0] mem_read_data;
    
    // Sign extension
    wire [31:0] sign_extended;
    
    // Branch calculation
    wire [31:0] branch_target;
    wire branch_taken;
    reg branch_taken_reg; // Registered version for next-cycle flush
    
    // Hazard detection
    wire stall;
    wire [1:0] forward_a, forward_b;
    wire [31:0] forwarded_read_data1, forwarded_read_data2;
    
    // Branch prediction
    reg [31:0] branch_history_table [0:15]; // 16-entry BHT
    reg [1:0] branch_predictor [0:15]; // 2-bit saturating counter
    wire [3:0] bht_index;
    wire branch_prediction;
    
    // Performance counters
    reg [31:0] cycle_count;
    reg [31:0] instruction_count;
    reg [31:0] stall_count;
    reg [31:0] branch_miss_count;
    
    // ========== Program Counter ==========
    reg [31:0] pc;
    
    assign pc_current = pc;
    assign pc_plus4 = pc + 4;
    
    // Branch target calculation
    // In MIPS, branches are relative to PC+4 (the instruction after the branch)
    assign branch_target = (idex_pc + 4) + (idex_sign_extended << 2);
    // Branch taken logic: BEQ branches if zero=1, BNE branches if zero=0
    assign branch_taken = exmem_branch && 
                          ((exmem_opcode == 6'b000100) ? exmem_zero_flag :     // BEQ
                           (exmem_opcode == 6'b000101) ? !exmem_zero_flag :    // BNE
                           1'b0);
    
    // PC update logic with branch prediction
    assign pc_next = (branch_taken) ? exmem_branch_target :
                     (stall) ? pc_current : pc_plus4;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc <= 32'h00000000;
            cycle_count <= 0;
            instruction_count <= 0;
            stall_count <= 0;
            branch_miss_count <= 0;
            branch_taken_reg <= 0;
        end else begin
            pc <= pc_next;
            cycle_count <= cycle_count + 1;
            if (!stall && ifid_valid)
                instruction_count <= instruction_count + 1;
            if (stall)
                stall_count <= stall_count + 1;
            if (branch_taken && !branch_prediction)
                branch_miss_count <= branch_miss_count + 1;
            branch_taken_reg <= branch_taken; // Register for next cycle
        end
    end
    
    // ========== Instruction Memory ==========
    instruction_memory imem (
        .address(pc_current[9:2]), // Word-aligned, 256 instructions
        .instruction(instruction)
    );
    
    // ========== IF/ID Pipeline Stage ==========
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ifid_pc <= 0;
            ifid_instruction <= 32'h00000000; // NOP
            ifid_valid <= 0;
        end else if (branch_taken) begin
            // Flush on branch taken
            ifid_pc <= 0;
            ifid_instruction <= 32'h00000000; // NOP
            ifid_valid <= 0;
        end else if (!stall) begin
            ifid_pc <= pc_current;
            ifid_instruction <= instruction;
            ifid_valid <= 1;
        end
    end
    
    // ========== Instruction Decode ==========
    wire [5:0] opcode = ifid_instruction[31:26];
    wire [4:0] rs = ifid_instruction[25:21];
    wire [4:0] rt = ifid_instruction[20:16];
    wire [4:0] rd = ifid_instruction[15:11];
    wire [5:0] funct = ifid_instruction[5:0];
    wire [15:0] immediate = ifid_instruction[15:0];
    
    // Sign extension
    assign sign_extended = {{16{immediate[15]}}, immediate};
    
    // Control Unit
    control_unit ctrl (
        .opcode(opcode),
        .reg_dst(reg_dst),
        .alu_src(alu_src),
        .mem_to_reg(mem_to_reg),
        .reg_write(reg_write),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .branch(branch),
        .alu_op(alu_op)
    );
    
    // Register File
    register_file regfile (
        .clk(clk),
        .rst(rst),
        .read_reg1(rs),
        .read_reg2(rt),
        .write_reg(memwb_write_reg),
        .write_data(write_data),
        .reg_write(memwb_reg_write && memwb_valid),
        .read_data1(read_data1),
        .read_data2(read_data2)
    );
    
    // Hazard Detection Unit
    hazard_detection_unit hdu (
        .idex_mem_read(idex_mem_read),
        .idex_rt(idex_rt),
        .ifid_rs(rs),
        .ifid_rt(rt),
        .stall(stall)
    );
    
    // Branch prediction logic
    assign bht_index = ifid_pc[5:2];
    assign branch_prediction = branch_predictor[bht_index][1]; // MSB of 2-bit counter
    
    // Update branch predictor
    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 16; i = i + 1) begin
                branch_history_table[i] <= 0;
                branch_predictor[i] <= 2'b01; // Weakly not taken
            end
        end else if (exmem_branch && exmem_valid) begin
            if (exmem_zero_flag) begin
                // Branch taken - increment counter (saturate at 11)
                if (branch_predictor[bht_index] < 2'b11)
                    branch_predictor[bht_index] <= branch_predictor[bht_index] + 1;
            end else begin
                // Branch not taken - decrement counter (saturate at 00)
                if (branch_predictor[bht_index] > 2'b00)
                    branch_predictor[bht_index] <= branch_predictor[bht_index] - 1;
            end
        end
    end
    
    // ========== ID/EX Pipeline Stage ==========
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            idex_pc <= 0;
            idex_read_data1 <= 0;
            idex_read_data2 <= 0;
            idex_sign_extended <= 0;
            idex_rs <= 0;
            idex_rt <= 0;
            idex_rd <= 0;
            idex_opcode <= 0;
            idex_funct <= 0;
            idex_reg_dst <= 0;
            idex_alu_src <= 0;
            idex_mem_to_reg <= 0;
            idex_reg_write <= 0;
            idex_mem_read <= 0;
            idex_mem_write <= 0;
            idex_branch <= 0;
            idex_alu_op <= 0;
            idex_valid <= 0;
        end else if (stall) begin
            // Insert bubble (NOP) on stall
            idex_pc <= 0;
            idex_read_data1 <= 0;
            idex_read_data2 <= 0;
            idex_sign_extended <= 0;
            idex_rs <= 0;
            idex_rt <= 0;
            idex_rd <= 0;
            idex_opcode <= 0;
            idex_funct <= 0;
            idex_reg_dst <= 0;
            idex_alu_src <= 0;
            idex_mem_to_reg <= 0;
            idex_reg_write <= 0;
            idex_mem_read <= 0;
            idex_mem_write <= 0;
            idex_branch <= 0;
            idex_alu_op <= 0;
            idex_valid <= 0;
        end else if (branch_taken) begin
            // Flush on branch taken
            idex_pc <= 0;
            idex_read_data1 <= 0;
            idex_read_data2 <= 0;
            idex_sign_extended <= 0;
            idex_rs <= 0;
            idex_rt <= 0;
            idex_rd <= 0;
            idex_opcode <= 0;
            idex_funct <= 0;
            idex_reg_dst <= 0;
            idex_alu_src <= 0;
            idex_mem_to_reg <= 0;
            idex_reg_write <= 0;
            idex_mem_read <= 0;
            idex_mem_write <= 0;
            idex_branch <= 0;
            idex_alu_op <= 0;
            idex_valid <= 0;
        end else begin
            idex_pc <= ifid_pc;
            idex_read_data1 <= read_data1;
            idex_read_data2 <= read_data2;
            idex_sign_extended <= sign_extended;
            idex_rs <= rs;
            idex_rt <= rt;
            idex_rd <= rd;
            idex_opcode <= opcode;
            idex_funct <= funct;
            idex_reg_dst <= reg_dst;
            idex_alu_src <= alu_src;
            idex_mem_to_reg <= mem_to_reg;
            idex_reg_write <= reg_write;
            idex_mem_read <= mem_read;
            idex_mem_write <= mem_write;
            idex_branch <= branch;
            idex_alu_op <= alu_op;
            idex_valid <= ifid_valid;
        end
    end
    
    // ========== Execution Stage ==========
    
    // Forwarding Unit
    forwarding_unit fwd (
        .idex_rs(idex_rs),
        .idex_rt(idex_rt),
        .exmem_reg_write(exmem_reg_write && exmem_valid),
        .exmem_write_reg(exmem_write_reg),
        .memwb_reg_write(memwb_reg_write && memwb_valid),
        .memwb_write_reg(memwb_write_reg),
        .forward_a(forward_a),
        .forward_b(forward_b)
    );
    
    // Forwarding multiplexers
    assign forwarded_read_data1 = (forward_a == 2'b10) ? exmem_alu_result :
                                   (forward_a == 2'b01) ? write_data :
                                   idex_read_data1;
    
    assign forwarded_read_data2 = (forward_b == 2'b10) ? exmem_alu_result :
                                   (forward_b == 2'b01) ? write_data :
                                   idex_read_data2;
    
    // ALU input multiplexer
    assign alu_input2 = idex_alu_src ? idex_sign_extended : forwarded_read_data2;
    
    // ALU Control
    alu_control alu_ctrl (
        .alu_op(idex_alu_op),
        .funct(idex_funct),
        .alu_control(alu_control)
    );
    
    // ALU
    alu main_alu (
        .a(forwarded_read_data1),
        .b(alu_input2),
        .alu_control(alu_control),
        .result(alu_result),
        .zero(zero_flag)
    );
    
    // Write register multiplexer
    assign write_reg = idex_reg_dst ? idex_rd : idex_rt;
    
    // ========== EX/MEM Pipeline Stage ==========
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            exmem_alu_result <= 0;
            exmem_write_data <= 0;
            exmem_write_reg <= 0;
            exmem_zero_flag <= 0;
            exmem_mem_to_reg <= 0;
            exmem_reg_write <= 0;
            exmem_mem_read <= 0;
            exmem_mem_write <= 0;
            exmem_branch <= 0;
            exmem_opcode <= 0;
            exmem_branch_target <= 0;
            exmem_valid <= 0;
        end else if (branch_taken_reg) begin
            // Flush the instruction that entered EX/MEM last cycle
            exmem_alu_result <= 0;
            exmem_write_data <= 0;
            exmem_write_reg <= 0;
            exmem_zero_flag <= 0;
            exmem_mem_to_reg <= 0;
            exmem_reg_write <= 0;
            exmem_mem_read <= 0;
            exmem_mem_write <= 0;
            exmem_branch <= 0;
            exmem_opcode <= 0;
            exmem_branch_target <= 0;
            exmem_valid <= 0;
        end else begin
            exmem_alu_result <= alu_result;
            exmem_write_data <= forwarded_read_data2;
            exmem_write_reg <= write_reg;
            exmem_zero_flag <= zero_flag;
            exmem_mem_to_reg <= idex_mem_to_reg;
            exmem_reg_write <= idex_reg_write;
            exmem_mem_read <= idex_mem_read;
            exmem_mem_write <= idex_mem_write;
            exmem_branch <= idex_branch;
            exmem_opcode <= idex_opcode;
            exmem_branch_target <= branch_target;
            exmem_valid <= idex_valid;
        end
    end
    
    // ========== Memory Stage ==========
    data_memory dmem (
        .clk(clk),
        .address(exmem_alu_result[9:2]), // Word-aligned, 256 words
        .write_data(exmem_write_data),
        .mem_read(exmem_mem_read && exmem_valid),
        .mem_write(exmem_mem_write && exmem_valid),
        .read_data(mem_read_data)
    );
    
    // ========== MEM/WB Pipeline Stage ==========
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            memwb_read_data <= 0;
            memwb_alu_result <= 0;
            memwb_write_reg <= 0;
            memwb_mem_to_reg <= 0;
            memwb_reg_write <= 0;
            memwb_valid <= 0;
        end else begin
            memwb_read_data <= mem_read_data;
            memwb_alu_result <= exmem_alu_result;
            memwb_write_reg <= exmem_write_reg;
            memwb_mem_to_reg <= exmem_mem_to_reg;
            memwb_reg_write <= exmem_reg_write;
            memwb_valid <= exmem_valid;
        end
    end
    
    // ========== Write Back Stage ==========
    assign write_data = memwb_mem_to_reg ? memwb_read_data : memwb_alu_result;
    
    // ========== Output Assignments ==========
    assign pc_out = pc_current;
    assign instruction_out = ifid_instruction;
    assign alu_result_out = exmem_alu_result;
    assign write_reg_out = memwb_write_reg;
    assign reg_write_out = memwb_reg_write;
    assign pipeline_stall_indicator = {stall, branch_taken};
    assign branch_taken_out = branch_taken;
    assign branch_target_out = exmem_branch_target;
    
endmodule

// ============================================================================
// Control Unit - Generates control signals based on opcode
// ============================================================================
module control_unit (
    input wire [5:0] opcode,
    output reg reg_dst,
    output reg alu_src,
    output reg mem_to_reg,
    output reg reg_write,
    output reg mem_read,
    output reg mem_write,
    output reg branch,
    output reg [2:0] alu_op
);

    // MIPS Instruction Opcodes
    localparam R_TYPE = 6'b000000;
    localparam LW     = 6'b100011;
    localparam SW     = 6'b101011;
    localparam BEQ    = 6'b000100;
    localparam BNE    = 6'b000101;
    localparam ADDI   = 6'b001000;
    localparam ANDI   = 6'b001100;
    localparam ORI    = 6'b001101;
    localparam SLTI   = 6'b001010;

    always @(*) begin
        // Default values
        reg_dst = 0;
        alu_src = 0;
        mem_to_reg = 0;
        reg_write = 0;
        mem_read = 0;
        mem_write = 0;
        branch = 0;
        alu_op = 3'b000;
        
        case (opcode)
            R_TYPE: begin // R-type instructions (ADD, SUB, AND, OR, SLT, etc.)
                reg_dst = 1;
                alu_src = 0;
                mem_to_reg = 0;
                reg_write = 1;
                mem_read = 0;
                mem_write = 0;
                branch = 0;
                alu_op = 3'b010; // R-type ALU operation
            end
            
            LW: begin // Load Word
                reg_dst = 0;
                alu_src = 1;
                mem_to_reg = 1;
                reg_write = 1;
                mem_read = 1;
                mem_write = 0;
                branch = 0;
                alu_op = 3'b000; // ADD for address calculation
            end
            
            SW: begin // Store Word
                reg_dst = 0; // Don't care
                alu_src = 1;
                mem_to_reg = 0; // Don't care
                reg_write = 0;
                mem_read = 0;
                mem_write = 1;
                branch = 0;
                alu_op = 3'b000; // ADD for address calculation
            end
            
            BEQ: begin // Branch if Equal
                reg_dst = 0; // Don't care
                alu_src = 0;
                mem_to_reg = 0; // Don't care
                reg_write = 0;
                mem_read = 0;
                mem_write = 0;
                branch = 1;
                alu_op = 3'b001; // SUB for comparison
            end
            
            BNE: begin // Branch if Not Equal
                reg_dst = 0; // Don't care
                alu_src = 0;
                mem_to_reg = 0; // Don't care
                reg_write = 0;
                mem_read = 0;
                mem_write = 0;
                branch = 1;
                alu_op = 3'b001; // SUB for comparison
            end
            
            ADDI: begin // Add Immediate
                reg_dst = 0;
                alu_src = 1;
                mem_to_reg = 0;
                reg_write = 1;
                mem_read = 0;
                mem_write = 0;
                branch = 0;
                alu_op = 3'b000; // ADD
            end
            
            ANDI: begin // And Immediate
                reg_dst = 0;
                alu_src = 1;
                mem_to_reg = 0;
                reg_write = 1;
                mem_read = 0;
                mem_write = 0;
                branch = 0;
                alu_op = 3'b011; // AND
            end
            
            ORI: begin // Or Immediate
                reg_dst = 0;
                alu_src = 1;
                mem_to_reg = 0;
                reg_write = 1;
                mem_read = 0;
                mem_write = 0;
                branch = 0;
                alu_op = 3'b100; // OR
            end
            
            SLTI: begin // Set Less Than Immediate
                reg_dst = 0;
                alu_src = 1;
                mem_to_reg = 0;
                reg_write = 1;
                mem_read = 0;
                mem_write = 0;
                branch = 0;
                alu_op = 3'b101; // SLT
            end
            
            default: begin
                // All outputs already set to 0
            end
        endcase
    end
endmodule
