// ============================================================================
// Testbench for RISC Processor
// Comprehensive testing with performance monitoring
// ============================================================================

`timescale 1ns/1ps

module tb_risc_processor;

    // Clock and reset
    reg clk;
    reg rst;
    
    // Outputs from processor
    wire [31:0] pc_out;
    wire [31:0] instruction_out;
    wire [31:0] alu_result_out;
    wire [4:0] write_reg_out;
    wire reg_write_out;
    wire [1:0] pipeline_stall_indicator;
    wire branch_taken_out;
    wire [31:0] branch_target_out;
    
    // Performance counters
    integer cycle_count;
    integer instruction_count;
    integer stall_cycles;
    integer branch_count;
    
    // Test control
    integer test_phase;
    
    // Instantiate processor
    risc_processor uut (
        .clk(clk),
        .rst(rst),
        .pc_out(pc_out),
        .instruction_out(instruction_out),
        .alu_result_out(alu_result_out),
        .write_reg_out(write_reg_out),
        .reg_write_out(reg_write_out),
        .pipeline_stall_indicator(pipeline_stall_indicator),
        .branch_taken_out(branch_taken_out),
        .branch_target_out(branch_target_out)
    );
    
    // Clock generation - 10ns period (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Waveform dump for GTKWave
    initial begin
        $dumpfile("risc_processor.vcd");
        $dumpvars(0, tb_risc_processor);
        // Dump all registers
        $dumpvars(1, uut.regfile.registers[0]);
        $dumpvars(1, uut.regfile.registers[1]);
        $dumpvars(1, uut.regfile.registers[2]);
        $dumpvars(1, uut.regfile.registers[3]);
        $dumpvars(1, uut.regfile.registers[4]);
        $dumpvars(1, uut.regfile.registers[5]);
        $dumpvars(1, uut.regfile.registers[6]);
        $dumpvars(1, uut.regfile.registers[7]);
        $dumpvars(1, uut.regfile.registers[8]);
        $dumpvars(1, uut.regfile.registers[9]);
        $dumpvars(1, uut.regfile.registers[10]);
    end
    
    // Monitor critical signals
    initial begin
        $display("========================================");
        $display("RISC PROCESSOR SIMULATION START");
        $display("========================================");
        $display("Time\tPC\tInstruction\tStall\tBranch");
        $display("----------------------------------------");
        $monitor("%0t\t%h\t%h\t%b\t%b", 
                 $time, pc_out, instruction_out, 
                 pipeline_stall_indicator[1], branch_taken_out);
    end
    
    // Performance monitoring
    always @(posedge clk) begin
        if (!rst) begin
            cycle_count = cycle_count + 1;
            
            if (pipeline_stall_indicator[1])
                stall_cycles = stall_cycles + 1;
                
            if (branch_taken_out)
                branch_count = branch_count + 1;
        end
    end
    
    // Test procedure
    initial begin
        // Initialize
        rst = 1;
        cycle_count = 0;
        instruction_count = 0;
        stall_cycles = 0;
        branch_count = 0;
        test_phase = 0;
        
        // Reset pulse
        #20;
        rst = 0;
        
        $display("\n[TEST PHASE 1] Basic ALU Operations");
        test_phase = 1;
        #100; // Let some instructions execute
        
        // Check register values after initialization
        #50;
        $display("\n[VERIFICATION] Checking initialized registers:");
        $display("R1 (expected 5): %d", uut.regfile.registers[1]);
        $display("R2 (expected 3): %d", uut.regfile.registers[2]);
        
        if (uut.regfile.registers[1] == 32'd5 && uut.regfile.registers[2] == 32'd3) begin
            $display("✓ PASS: Register initialization successful");
        end else begin
            $display("✗ FAIL: Register initialization failed");
        end
        
        $display("\n[TEST PHASE 2] Data Forwarding Test");
        test_phase = 2;
        #100;
        
        // Check forwarding results
        $display("\n[VERIFICATION] Checking data forwarding:");
        $display("R3 (expected 8): %d", uut.regfile.registers[3]);
        $display("R4 (expected 18): %d", uut.regfile.registers[4]);
        
        if (uut.regfile.registers[3] == 32'd8 && uut.regfile.registers[4] == 32'd18) begin
            $display("✓ PASS: Data forwarding working correctly");
        end else begin
            $display("✗ FAIL: Data forwarding issue detected");
        end
        
        $display("\n[TEST PHASE 3] Load-Use Hazard (Pipeline Stall)");
        test_phase = 3;
        #100;
        
        $display("\n[VERIFICATION] Checking load-use hazard handling:");
        $display("R5 (expected 10): %d", uut.regfile.registers[5]);
        
        if (uut.regfile.registers[5] == 32'd10) begin
            $display("✓ PASS: Load-use hazard handled with stall");
        end else begin
            $display("✗ FAIL: Load-use hazard not handled correctly");
        end
        
        $display("\n[TEST PHASE 4] Branch Instructions");
        test_phase = 4;
        #150;
        
        $display("\n[VERIFICATION] Checking branch execution:");
        $display("R8 (expected 0, should be skipped): %d", uut.regfile.registers[8]);
        $display("R10 (expected 15): %d", uut.regfile.registers[10]);
        
        if (uut.regfile.registers[8] == 32'd0 && uut.regfile.registers[10] == 32'd15) begin
            $display("✓ PASS: Branch prediction and execution correct");
        end else begin
            $display("✗ FAIL: Branch execution issue");
        end
        
        $display("\n[TEST PHASE 5] Logical Operations");
        test_phase = 5;
        #100;
        
        $display("\n[VERIFICATION] Checking logical operations:");
        $display("R13 (expected 0, AND result): %d", uut.regfile.registers[13]);
        $display("R14 (expected 255, OR result): %d", uut.regfile.registers[14]);
        
        if (uut.regfile.registers[13] == 32'd0 && uut.regfile.registers[14] == 32'd255) begin
            $display("✓ PASS: Logical operations working correctly");
        end else begin
            $display("✗ FAIL: Logical operation issue");
        end
        
        $display("\n[TEST PHASE 6] Set Less Than (SLT)");
        test_phase = 6;
        #80;
        
        $display("\n[VERIFICATION] Checking SLT operation:");
        $display("R17 (expected 1, 10<20): %d", uut.regfile.registers[17]);
        
        if (uut.regfile.registers[17] == 32'd1) begin
            $display("✓ PASS: SLT operation correct");
        end else begin
            $display("✗ FAIL: SLT operation issue");
        end
        
        $display("\n[TEST PHASE 7] Memory Operations");
        test_phase = 7;
        #120;
        
        $display("\n[VERIFICATION] Checking memory operations:");
        $display("R18 (expected 20, loaded from mem): %d", uut.regfile.registers[18]);
        $display("R19 (expected 30, sum): %d", uut.regfile.registers[19]);
        
        if (uut.regfile.registers[18] == 32'd20 && uut.regfile.registers[19] == 32'd30) begin
            $display("✓ PASS: Memory load/store working correctly");
        end else begin
            $display("✗ FAIL: Memory operation issue");
        end
        
        $display("\n[TEST PHASE 8] Loop Execution");
        test_phase = 8;
        #200; // Loops take more cycles
        
        $display("\n[VERIFICATION] Checking loop execution:");
        $display("R22 (expected 5, loop counter): %d", uut.regfile.registers[22]);
        
        if (uut.regfile.registers[22] == 32'd5) begin
            $display("✓ PASS: Loop execution correct");
        end else begin
            $display("✗ FAIL: Loop execution issue");
        end
        
        // Let remaining instructions execute
        #300;
        
        // Final performance report
        instruction_count = cycle_count - stall_cycles;
        
        $display("\n========================================");
        $display("PERFORMANCE METRICS");
        $display("========================================");
        $display("Total Cycles:        %d", cycle_count);
        $display("Stall Cycles:        %d", stall_cycles);
        $display("Branch Count:        %d", branch_count);
        $display("Pipeline Efficiency: %0.2f%%", 
                 (100.0 * (cycle_count - stall_cycles)) / cycle_count);
        $display("CPI (Cycles/Inst):   %0.2f", 
                 real'(cycle_count) / real'(cycle_count - stall_cycles));
        
        $display("\n========================================");
        $display("FINAL REGISTER VALUES");
        $display("========================================");
        $display("R0:  %d (hardwired to 0)", uut.regfile.registers[0]);
        $display("R1:  %d", uut.regfile.registers[1]);
        $display("R2:  %d", uut.regfile.registers[2]);
        $display("R3:  %d", uut.regfile.registers[3]);
        $display("R4:  %d", uut.regfile.registers[4]);
        $display("R5:  %d", uut.regfile.registers[5]);
        $display("R6:  %d", uut.regfile.registers[6]);
        $display("R7:  %d", uut.regfile.registers[7]);
        $display("R8:  %d", uut.regfile.registers[8]);
        $display("R9:  %d", uut.regfile.registers[9]);
        $display("R10: %d", uut.regfile.registers[10]);
        $display("R11: %d", uut.regfile.registers[11]);
        $display("R12: %d", uut.regfile.registers[12]);
        $display("R13: %d", uut.regfile.registers[13]);
        $display("R14: %d", uut.regfile.registers[14]);
        $display("R15: %d", uut.regfile.registers[15]);
        $display("R16: %d", uut.regfile.registers[16]);
        $display("R17: %d", uut.regfile.registers[17]);
        $display("R18: %d", uut.regfile.registers[18]);
        $display("R19: %d", uut.regfile.registers[19]);
        $display("R20: %d", uut.regfile.registers[20]);
        $display("R21: %d", uut.regfile.registers[21]);
        $display("R22: %d", uut.regfile.registers[22]);
        $display("R23: %d", uut.regfile.registers[23]);
        $display("R24: %d", uut.regfile.registers[24]);
        $display("R25: %d", uut.regfile.registers[25]);
        $display("R26: %d", uut.regfile.registers[26]);
        $display("R27: %d", uut.regfile.registers[27]);
        
        $display("\n========================================");
        $display("SIMULATION COMPLETE");
        $display("========================================\n");
        
        #100;
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #10000;
        $display("\nERROR: Simulation timeout!");
        $finish;
    end
    
endmodule
