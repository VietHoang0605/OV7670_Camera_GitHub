module i2c_clk_gen #(
    parameter SYS_CLK_FREQ = 50000000, // 50 MHz
    parameter I2C_CLK_FREQ = 100000    // 400 kHz (Fast Mode - Original System Speed)
)(
    input  clk,
    input  reset_n,
    input  enable,
    output reg i2c_tick_4x
);

    // ============================================================
    // BÀI TẬP DÀNH CHO BẠN (Sinh viên Hardcore):
    // 1. Tính toán hằng số MAX_COUNT để tạo ra Xung Tick 4x.
       parameter MAX_COUNT = SYS_CLK_FREQ/(I2C_CLK_FREQ*4)-1;
       reg [7:0] count; 
    //    (Gợi ý: Tần số Tick phải bằng 4 lần I2C_CLK_FREQ).
    // 2. Viết khối logic (always) sinh ra nhịp i2c_tick_4x.
    // ============================================================
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            count <= 8'd0;
            i2c_tick_4x <= 1'b0;
        end
        else if (enable) begin 
            if (count == MAX_COUNT) begin
                i2c_tick_4x <= 1'b1;
                count <= 8'd0;
            end
            else begin
                count <= count + 1'd1;
                i2c_tick_4x <= 1'b0;
            end
        end
        else begin
            // Dọn dẹp rác khi enable = 0
            i2c_tick_4x <= 1'b0;
            count <= 8'd0;
        end
    end

endmodule

