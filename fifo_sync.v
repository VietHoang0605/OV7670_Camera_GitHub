module fifo_sync #(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 5 // Depth = 2^ADDR_WIDTH (VD: 5 -> 32, 9 -> 512)
)(
    input wire clk,
    input wire rst_n,
    input wire clear,
    input wire wr_en,
    input wire [DATA_WIDTH-1:0] wr_data,
    input wire rd_en,
    output reg [DATA_WIDTH-1:0] rd_data,
    output wire empty,
    output wire full,
    output reg [ADDR_WIDTH:0] count
);

    localparam DEPTH = 1 << ADDR_WIDTH;
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_WIDTH-1:0] readpointer;
    reg [ADDR_WIDTH-1:0] writepointer;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) writepointer <= 0;
        else if (clear) writepointer <= 0;
        else if(wr_en && !full) begin
            mem[writepointer] <= wr_data;
            writepointer <= writepointer + 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) readpointer <= 0;
        else if (clear) readpointer <= 0;
        else if(rd_en && !empty) begin
            rd_data <= mem[readpointer];
            readpointer <= readpointer + 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) count <= 0;
        else if (clear) count <= 0;
        else if ((wr_en && !full) && !(rd_en && !empty)) count <= count + 1'b1;
        else if (!(wr_en && !full) && (rd_en && !empty)) count <= count - 1'b1;
    end

    assign empty = (count == 0);
    assign full = (count == DEPTH);
endmodule
