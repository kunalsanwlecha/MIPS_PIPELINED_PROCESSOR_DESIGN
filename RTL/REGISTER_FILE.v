// ============================================================================
// Register File
// 32 x 32-bit registers with 2 read ports and 1 write port
// Register 0 is hardwired to 0
// ============================================================================

module register_file (
    input wire clk,
    input wire rst,
    input wire [4:0] read_reg1,
    input wire [4:0] read_reg2,
    input wire [4:0] write_reg,
    input wire [31:0] write_data,
    input wire reg_write,
    output wire [31:0] read_data1,
    output wire [31:0] read_data2
);

    // 32 registers, each 32 bits wide
    reg [31:0] registers [0:31];
    
    integer i;
    
    // Initialize registers on reset
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 32'd0;
            end
        end else if (reg_write && write_reg != 5'd0) begin
            // Register 0 is hardwired to 0, cannot be written
            registers[write_reg] <= write_data;
        end
    end
    
    // Asynchronous read with internal forwarding
    // If we're writing to the register being read in the same cycle, forward the write data
    assign read_data1 = (read_reg1 == 5'd0) ? 32'd0 :
                        (reg_write && (write_reg == read_reg1) && (write_reg != 5'd0)) ? write_data :
                        registers[read_reg1];
    
    assign read_data2 = (read_reg2 == 5'd0) ? 32'd0 :
                        (reg_write && (write_reg == read_reg2) && (write_reg != 5'd0)) ? write_data :
                        registers[read_reg2];
    
endmodule
