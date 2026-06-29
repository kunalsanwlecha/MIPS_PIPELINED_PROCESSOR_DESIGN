// ============================================================================
// Hazard Detection Unit
// Detects load-use hazards and generates stall signal
// ============================================================================

module hazard_detection_unit (
    input wire idex_mem_read,
    input wire [4:0] idex_rt,
    input wire [4:0] ifid_rs,
    input wire [4:0] ifid_rt,
    output reg stall
);

    // Detect load-use hazard
    // If the instruction in EX stage is a load (mem_read=1) and
    // its destination register (rt) matches with source registers
    // of the instruction in ID stage, we need to stall
    always @(*) begin
        if (idex_mem_read && 
            ((idex_rt == ifid_rs) || (idex_rt == ifid_rt)) &&
            (idex_rt != 5'd0)) begin
            stall = 1'b1;
        end else begin
            stall = 1'b0;
        end
    end
    
endmodule

// ============================================================================
// Forwarding Unit
// Handles data forwarding to resolve data hazards
// Implements EX-to-EX and MEM-to-EX forwarding
// ============================================================================

module forwarding_unit (
    input wire [4:0] idex_rs,
    input wire [4:0] idex_rt,
    input wire exmem_reg_write,
    input wire [4:0] exmem_write_reg,
    input wire memwb_reg_write,
    input wire [4:0] memwb_write_reg,
    output reg [1:0] forward_a,
    output reg [1:0] forward_b
);

    // Forward A (for RS register)
    always @(*) begin
        // EX hazard (EX-to-EX forwarding) - highest priority
        if (exmem_reg_write && 
            (exmem_write_reg != 5'd0) && 
            (exmem_write_reg == idex_rs)) begin
            forward_a = 2'b10;
        end
        // MEM hazard (MEM-to-EX forwarding) - only if no EX hazard
        else if (memwb_reg_write && 
                 (memwb_write_reg != 5'd0) && 
                 !(exmem_reg_write && (exmem_write_reg == idex_rs)) &&
                 (memwb_write_reg == idex_rs)) begin
            forward_a = 2'b01;
        end
        // No forwarding needed
        else begin
            forward_a = 2'b00;
        end
    end
    
    // Forward B (for RT register)
    always @(*) begin
        // EX hazard (EX-to-EX forwarding) - highest priority
        if (exmem_reg_write && 
            (exmem_write_reg != 5'd0) && 
            (exmem_write_reg == idex_rt)) begin
            forward_b = 2'b10;
        end
        // MEM hazard (MEM-to-EX forwarding) - only if no EX hazard
        else if (memwb_reg_write && 
                 (memwb_write_reg != 5'd0) && 
                 !(exmem_reg_write && (exmem_write_reg == idex_rt)) &&
                 (memwb_write_reg == idex_rt)) begin
            forward_b = 2'b01;
        end
        // No forwarding needed
        else begin
            forward_b = 2'b00;
        end
    end
    
endmodule
