`timescale 1ns / 1ps
// ============================================================================
// Module Name:    ov7670_top
// Project Name:   OV7670 Camera to VGA Framebuffer via SDRAM
// Target Devices: FPGA (Altera Cyclone II / Cyclone IV / DE1 Board / Xilinx)
// Tool Versions:  Quartus II / Modelsim / Vivado
// Description:    GIÃ€N GIÃO TOP-LEVEL (SCAFFOLDING) TOÃ€N Há»† THá»NG
//                 GhÃ©p ná»‘i 6 phÃ¢n há»‡ cá»‘t lÃµi:
//                   1. ov7670_config  : Cáº¥u hÃ¬nh thanh ghi OV7670 qua I2C/SCCB.
//                   2. ov7670_capture : ÄÃ³n byte DVP, ghÃ©p 2 byte -> RGB565.
//                   3. W-FIFO (Async) : Äá»‡m chuyá»ƒn miá»n xung nhá»‹p PCLK -> SDRAM CLK.
//                   4. sdram_arbiter  : Trá»ng tÃ i Ä‘iá»u phá»‘i Ping-Pong & Burst Read/Write.
//                   5. R-FIFO (Async) : Äá»‡m dá»¯ liá»‡u tá»« SDRAM CLK -> VGA CLK (25MHz).
//                   6. vga_sync       : Bá»™ quÃ©t Ä‘á»“ng bá»™ hiá»ƒn thá»‹ 640x480 @ 60Hz.
//
// Author:         Agent 2 - ChuyÃªn gia Scaffolding & Review Code
// Reviewer:       Sáº¿p (Hardware Lead)
// Note:           ToÃ n bá»™ mapping chÃ¢n á»Ÿ cÃ¡c module con Ä‘Ã£ Ä‘Æ°á»£c Ä‘á»ƒ sáºµn TODO 
//                 kÃ¨m hÆ°á»›ng dáº«n chi tiáº¿t Ä‘á»ƒ Sáº¿p tá»± tay báº¥m dÃ¢y hÃ n máº¡ch!
// ============================================================================

module ov7670_top (
    // ========================================================================
    // 1. SYSTEM CLOCK & ASYNC RESET
    // ========================================================================
    input  wire        clk_50m,        // Xung nhá»‹p há»‡ thá»‘ng 50MHz (VÃ­ dá»¥: OSC 50MHz trÃªn máº¡ch DE1)
    input  wire        rst_n,          // Reset há»‡ thá»‘ng toÃ n cá»¥c (Active-low, ná»‘i vÃ o nÃºt nháº¥n KEY[0])

    // ========================================================================
    // 2. CAMERA INTERFACE (OV7670 DVP & SCCB PINS)
    // ========================================================================
    input  wire        cam_pclk,       // Pixel Clock tá»« OV7670 (~12.5MHz - 24MHz)
    input  wire        cam_vsync,      // TÃ­n hiá»‡u Ä‘á»“ng bá»™ khung hÃ¬nh tá»« Camera (Active-high)
    input  wire        cam_href,       // TÃ­n hiá»‡u bÃ¡o dá»¯ liá»‡u dÃ²ng há»£p lá»‡ (Active-high)
    input  wire [7:0]  cam_data,       // Bus dá»¯ liá»‡u 8-bit tá»« Camera (D0 -> D7)
    output wire        cam_xclk,       // Xung nhá»‹p master cáº¥p cho Camera (24MHz hoáº·c 25MHz)
    output wire        cam_pwdn,       // Power Down: 0 = Hoáº¡t Ä‘á»™ng bÃ¬nh thÆ°á»ng, 1 = Cháº¿ Ä‘á»™ ngá»§
    output wire        cam_reset,      // Reset pháº§n cá»©ng Camera: 1 = BÃ¬nh thÆ°á»ng, 0 = Reset cá»©ng
    output wire        cam_scl,        // Xung nhá»‹p giao tiáº¿p cáº¥u hÃ¬nh I2C / SCCB (100kHz - 400kHz)
    inout  wire        cam_sda,        // ÄÆ°á»ng dá»¯ liá»‡u hai chiá»u I2C / SCCB (Pull-up ngoÃ i)

    // ========================================================================
    // 3. VGA INTERFACE (DAC RGB 4-4-4 & SYNC TIMING)
    // ========================================================================
    output wire        vga_hsync,      // Xung Ä‘á»“ng bá»™ ngang (Horizontal Sync)
    output wire        vga_vsync,      // Xung Ä‘á»“ng bá»™ dá»c (Vertical Sync)
    output wire [3:0]  vga_r,          // KÃªnh mÃ u Äá» (Red) 4-bit DAC
    output wire [3:0]  vga_g,          // KÃªnh mÃ u Xanh lÃ¡ (Green) 4-bit DAC
    output wire [3:0]  vga_b,          // KÃªnh mÃ u Xanh dÆ°Æ¡ng (Blue) 4-bit DAC

    // ========================================================================
    // 4. SDRAM PHYSICAL INTERFACE (IS42S16400 / DE1 ON-BOARD SDRAM)
    // ========================================================================
    output wire        sdram_clk,      // Xung nhá»‹p SDRAM (Lá»‡ch pha -3ns hoáº·c Ä‘áº£o pha Ä‘á»ƒ bÃ¹ trá»… PCB)
    output wire        sdram_cke,      // Clock Enable cá»§a SDRAM
    output wire        sdram_cs_n,     // Chip Select (Active-low)
    output wire        sdram_ras_n,    // Row Address Strobe (Active-low)
    output wire        sdram_cas_n,    // Column Address Strobe (Active-low)
    output wire        sdram_we_n,     // Write Enable (Active-low)
    output wire [1:0]  sdram_ba,       // Bank Select (BA0, BA1)
    output wire [11:0] sdram_addr,     // Address Bus (A0 -> A11)
    inout  wire [15:0] sdram_dq,       // Data Bus song cÃ´ng 16-bit (DQ0 -> DQ15)
    output wire        sdram_ldqm,     // Mask Byte tháº¥p (DQ0 -> DQ7)
    output wire        sdram_udqm,     // Mask Byte cao (DQ8 -> DQ15)
    output wire [9:0]  LED             // [DEBUG] Virtual Dashboard LEDs
);

    // ========================================================================
    // Cá» Äá»ŠNH CÃC CHÃ‚N TÄ¨NH Cá»¦A CAMERA & SDRAM (FIXED LOGIC LEVELS)
    // ========================================================================
    assign cam_pwdn   = 1'b0;  // ÄÆ°a chÃ¢n PWDN vá» GND Ä‘á»ƒ Camera luÃ´n thá»©c giáº¥c hoáº¡t Ä‘á»™ng
    assign cam_reset  = 1'b1;  // ChÃ¢n RESET camera tÃ­ch cá»±c má»©c 0 -> giá»¯ má»©c 1 Ä‘á»ƒ camera cháº¡y bÃ¬nh thÆ°á»ng
    assign sdram_cke  = 1'b1;  // SDRAM CKE luÃ´n á»Ÿ má»©c 1 (cho phÃ©p nháº­n clock liÃªn tá»¥c)
    assign sdram_ldqm = 1'b0;  // KhÃ´ng cháº·n byte tháº¥p (luÃ´n cho phÃ©p Ä‘á»c/ghi 16-bit Ä‘áº§y Ä‘á»§)
    assign sdram_udqm = 1'b0;  // KhÃ´ng cháº·n byte cao

    // ========================================================================
    // AUTO POWER-ON RESET (POR) GENERATOR
    // ========================================================================
    // Tá»± Ä‘á»™ng giá»¯ reset má»©c tháº¥p (0) trong khoáº£ng 40ms sau khi náº¡p bitstream / báº­t nguá»“n.
    // 50MHz: 40ms = 2,000,000 chu ká»³ clk_50m.
    // Káº¿t há»£p vá»›i nÃºt cá»©ng KEY[0]: sys_rst_n = rst_n & por_rst_n.
    // GiÃºp camera vÃ  toÃ n bá»™ há»‡ thá»‘ng khá»Ÿi Ä‘á»™ng chuáº©n xÃ¡c mÃ  khÃ´ng cáº§n báº¥m KEY[0].
    reg [21:0] por_cnt = 22'd0;
    reg        por_rst_n = 1'b0;

    always @(posedge clk_50m) begin
        if (por_cnt < 22'd2_000_000) begin
            por_cnt   <= por_cnt + 22'd1;
            por_rst_n <= 1'b0;
        end else begin
            por_rst_n <= 1'b1;
        end
    end

    wire sys_rst_n = rst_n & por_rst_n;


    // ========================================================================
    // PHáº¦N A: KHAI BÃO CÃC DÃ‚Y Ná»I Ná»˜I Bá»˜ (INTERNAL WIRES & BUSES)
    // ========================================================================

    // ------------------------------------------------------------------------
    // [NhÃ³m 1] DÃ¢y ná»‘i khá»‘i Cáº¥u hÃ¬nh Camera (ov7670_config & i2c_master)
    // ------------------------------------------------------------------------
    wire        cfg_i2c_ready;     // BÃ¡o i2c_master sáºµn sÃ ng nháº­n lá»‡nh má»›i
    wire        cfg_i2c_start;     // Xung kÃ­ch hoáº¡t phÃ¡t gÃ³i I2C 3-byte
    wire [15:0] cfg_i2c_data;      // Bus náº¡p {Sub-Address, Data} tá»« ROM ra I2C master
    wire        cfg_done;          // Cá» bÃ¡o toÃ n bá»™ 156 thanh ghi Ä‘Ã£ Ä‘Æ°á»£c náº¡p xong

    // ------------------------------------------------------------------------
    // [NhÃ³m 2] DÃ¢y ná»‘i tá»« ngÃµ ra Camera Capture (ov7670_capture)
    // ------------------------------------------------------------------------
    wire [18:0] cap_pixel_addr;    // Tá»a Ä‘á»™ Ä‘á»‹a chá»‰ pixel (0 -> 307,199) trong khung 640x480
    wire [15:0] cap_pixel_data;    // Dá»¯ liá»‡u mÃ u ghÃ©p hoÃ n chá»‰nh chuáº©n RGB565 (16-bit)
    wire        cap_pixel_we;      // Xung cho phÃ©p ghi (Write Enable) phÃ¡t ra má»—i 2 nhá»‹p PCLK

    // ------------------------------------------------------------------------
    // [NhÃ³m 3] DÃ¢y ná»‘i W-FIFO (Write FIFO: Miá»n PCLK -> Miá»n SDRAM CLK 50MHz)
    // ------------------------------------------------------------------------
    wire        w_fifo_wr_clk;     // Xung nhá»‹p ghi W-FIFO (ná»‘i tá»« PCLK)
    wire        w_fifo_wr_en;      // Cá» cho phÃ©p náº¡p pixel vÃ o W-FIFO (ná»‘i tá»« cap_pixel_we)
    wire [15:0] w_fifo_wr_data;    // Dá»¯ liá»‡u Ä‘Æ°a vÃ o W-FIFO (ná»‘i tá»« cap_pixel_data)
    wire        w_fifo_full;       // Cá» bÃ¡o W-FIFO Ä‘áº§y (chá»‘ng trÃ n)

    wire        w_fifo_rd_clk;     // Xung nhá»‹p Ä‘á»c W-FIFO (ná»‘i tá»« xung SDRAM/Há»‡ thá»‘ng 50MHz)
    wire        w_fifo_rd_en;      // Cá» rÃºt dá»¯ liá»‡u ra khá»i W-FIFO (do Arbiter Ä‘iá»u khiá»ƒn)
    wire [15:0] w_fifo_rd_data;    // Dá»¯ liá»‡u pixel láº¥y ra tá»« W-FIFO cáº¥p cho Arbiter náº¡p vÃ o SDRAM
    wire        w_fifo_empty;      // Cá» bÃ¡o W-FIFO cáº¡n
    wire [10:0] w_fifo_count;      // Sá»‘ lÆ°á»£ng pixel hiá»‡n cÃ³ trong W-FIFO (miá»n 50MHz)

    // ------------------------------------------------------------------------
    // [NhÃ³m 4] DÃ¢y ná»‘i giá»¯a SDRAM Arbiter vÃ  SDRAM Controller
    // ------------------------------------------------------------------------
    wire        arb_sys_ready;     // SDRAM Controller bÃ¡o sáºµn sÃ ng nháº­n lá»‡nh Burst má»›i
    wire        arb_sys_valid;     // Cá» dá»¯ liá»‡u Burst Ä‘ang truyá»n trÃ o ra/vÃ o há»£p lá»‡
    wire        arb_sys_wr_ack;    // Cá» Controller yÃªu cáº§u tiáº¿p dá»¯ liá»‡u ghi Burst tá»« W-FIFO
    wire        arb_sys_wr_req;    // Arbiter yÃªu cáº§u Controller thá»±c thi má»™t Burst Ghi (256 words)
    wire        arb_sys_rd_req;    // Arbiter yÃªu cáº§u Controller thá»±c thi má»™t Burst Äá»c (256 words)
    wire [21:0] arb_sys_addr;      // Bus Ä‘á»‹a chá»‰ toÃ n cá»¥c truy xuáº¥t SDRAM (Bank + Row + Col)
    wire [15:0] arb_sys_data_in;   // Dá»¯ liá»‡u Arbiter náº¡p vÃ o Controller Ä‘á»ƒ ghi xuá»‘ng SDRAM chip
    wire [15:0] arb_sys_data_out;  // Dá»¯ liá»‡u Controller Ä‘á»c trÃ o ra tá»« SDRAM chip tráº£ vá» cho Arbiter

    // ------------------------------------------------------------------------
    // [NhÃ³m 5] DÃ¢y ná»‘i R-FIFO (Read FIFO: Miá»n SDRAM CLK 50MHz -> Miá»n VGA 25MHz)
    // ------------------------------------------------------------------------
    wire        r_fifo_wr_clk;     // Xung nhá»‹p náº¡p R-FIFO (50MHz tá»« SDRAM domain)
    wire        r_fifo_wr_en;      // Cá» do Arbiter giÆ°Æ¡ng lÃªn khi rÃ³t dá»¯ liá»‡u Ä‘á»c tá»« SDRAM vÃ o R-FIFO
    wire [15:0] r_fifo_wr_data;    // Dá»¯ liá»‡u Arbiter rÃ³t vÃ o R-FIFO (16-bit pixel RGB565)
    wire        r_fifo_full;       // Cá» bÃ¡o R-FIFO Ä‘áº§y
    wire [10:0] r_fifo_count;      // Sá»‘ lÆ°á»£ng pixel hiá»‡n Ä‘ang tÃ­ch trá»¯ trong R-FIFO (giÃ¡m sÃ¡t má»©c nÆ°á»›c)
    wire        r_fifo_clear;      // Cá» xÃ³a sáº¡ch R-FIFO khi Ä‘áº¿n Ä‘áº§u khung hÃ¬nh má»›i (VGA VSYNC)

    wire        r_fifo_rd_clk;     // Xung nhá»‹p rÃºt R-FIFO (25MHz pixel clock hoáº·c 50MHz cÃ³ ce)
    wire        r_fifo_rd_en;      // Cá» cho phÃ©p rÃºt pixel ra Ä‘á»ƒ báº¯n lÃªn mÃ n hÃ¬nh VGA
    wire [15:0] r_fifo_rd_data;    // Pixel RGB565 láº¥y ra tá»« R-FIFO chuáº©n bá»‹ Ä‘Æ°a sang DAC
    wire        r_fifo_empty;      // Cá» bÃ¡o R-FIFO cáº¡n (náº¿u cáº¡n sáº½ báº¯n ra mÃ u Ä‘en)

    // ------------------------------------------------------------------------
    // [NhÃ³m 6] DÃ¢y ná»‘i Bá»™ quÃ©t mÃ n hÃ¬nh (vga_sync) & Video Output Logic
    // ------------------------------------------------------------------------
    wire        vga_ce;            // Xung cho phÃ©p nhá»‹p 25MHz (táº¡o tá»« chia Ä‘Ã´i 50MHz)
    wire        vga_video_on;      // Cá» bÃ¡o tia quÃ©t Ä‘ang náº±m trong vÃ¹ng hiá»ƒn thá»‹ kháº£ dá»¥ng (640x480)
    wire [9:0]  vga_pixel_x;       // Tá»a Ä‘á»™ pixel cá»™t hiá»‡n táº¡i (0 -> 639)
    wire [9:0]  vga_pixel_y;       // Tá»a Ä‘á»™ pixel dÃ²ng hiá»‡n táº¡i (0 -> 479)
    wire        vga_frame_start;   // Xung bÃ¡o báº¯t Ä‘áº§u má»™t khung hÃ¬nh hiá»ƒn thá»‹ má»›i

    // ========================================================================
    // PHáº¦N B: Máº CH Táº O XUNG Bá»” TRá»¢ (CLOCK GENERATION SCAFFOLDING)
    // ========================================================================

    // 1. Táº¡o xung nhá»‹p 25MHz cho Camera XCLK (Chia Ä‘Ã´i tá»« 50MHz)
    //    OV7670 cáº§n clock ngoÃ i XCLK tá»« 10MHz Ä‘áº¿n 48MHz (khuyÃªn dÃ¹ng 24MHz - 25MHz)
    reg clk_25m_reg;
    always @(posedge clk_50m or negedge sys_rst_n) begin
        if (!sys_rst_n) clk_25m_reg <= 1'b0;
        else            clk_25m_reg <= ~clk_25m_reg;
    end
    assign cam_xclk = clk_25m_reg;
    assign vga_ce   = clk_25m_reg; // Xung kÃ­ch hoáº¡t 25MHz cho VGA Timing Generator

    // 2. SDRAM Clock Ä‘áº£o pha Ä‘á»ƒ bÃ¹ trá»… Ä‘Æ°á»ng truyá»n PCB (DRAM_CLK = ~clk_50m)
    assign sdram_clk = ~clk_50m;


    // ========================================================================
    // PHáº¦N C: KHUNG Gá»ŒI MODULE CON (MODULE INSTANTIATIONS)
    // ========================================================================

    // ------------------------------------------------------------------------
    // 1. MODULE: ov7670_config
    // ------------------------------------------------------------------------
    ov7670_config u_ov7670_config (
        .clk         ( clk_50m ),
        .rst_n       ( sys_rst_n ),
        .i2c_ready   ( cfg_i2c_ready ),
        .i2c_start   ( cfg_i2c_start ),
        .i2c_data    ( cfg_i2c_data ),
        .config_done ( cfg_done )
    );

    // ------------------------------------------------------------------------
    // 2. MODULE: ov7670_capture
    // ------------------------------------------------------------------------
    ov7670_capture u_ov7670_capture (
        .pclk        ( cam_pclk ),
        .vsync       ( cam_vsync ),
        .href        ( cam_href ),
        .d           ( cam_data ),
        .addr        ( cap_pixel_addr ),
        .dout        ( cap_pixel_data ),
        .we          ( cap_pixel_we )
    );

    // ------------------------------------------------------------------------
    // [AGENT 2 - FIX BÆ¯á»šC 1: Xáº¢ ÄÃY W-FIFO KHI VSYNC CHUYá»‚N KHUNG HÃŒNH]
    // ========================================================================
    // Má»¥c Ä‘Ã­ch: Triá»‡t tiÃªu vÄ©nh viá»…n 280 pixel rÃ¡c bá»‹ Ä‘á»ng láº¡i lÃ m lá»‡ch khung hÃ¬nh!
    // NguyÃªn lÃ½: 
    // 1. Khi cam_vsync = 1 (Vertical Blanking giá»¯a 2 khung hÃ¬nh), Camera táº¡m dá»«ng
    //    phÃ¡t dá»¯ liá»‡u. ÄÃ¢y lÃ  khoáº£ng láº·ng vÃ ng Ä‘á»ƒ thÃ¡o cáº¡n toÃ n bá»™ W-FIFO.
    // 2. Miá»n Ghi (wclk = cam_pclk): DÃ¹ng trá»±c tiáº¿p (~cam_vsync) lÃ m wrst_n.
    // 3. Miá»n Äá»c (rclk = clk_50m): Äá»“ng bá»™ cam_vsync qua 2 táº§ng D-FF (CDC chuáº©n)
    //    Ä‘á»ƒ táº¡o rrst_n an toÃ n, chá»‘ng hiá»‡n tÆ°á»£ng báº¥t á»•n Ä‘á»‹nh (Metastability).
    // ========================================================================
    reg cam_vsync_r1, cam_vsync_r2;
    always @(posedge clk_50m or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            cam_vsync_r1 <= 1'b0;
            cam_vsync_r2 <= 1'b0;
        end else begin
            cam_vsync_r1 <= cam_vsync;
            cam_vsync_r2 <= cam_vsync_r1;
        end
    end

    wire w_fifo_wrst_n = sys_rst_n && (~cam_vsync);
    wire w_fifo_rrst_n = sys_rst_n && (~cam_vsync_r2);

    // ------------------------------------------------------------------------
    // 3. MODULE: async_fifo (W-FIFO: Bá»“n chá»©a Ä‘á»‡m Ghi)
    // ------------------------------------------------------------------------
    async_fifo #(
        .DATA_WIDTH  ( 16 ),
        .ADDR_WIDTH  ( 10 )
    ) u_w_fifo (
        .wclk        ( cam_pclk ),
        .wrst_n      ( w_fifo_wrst_n ),
        .winc        ( cap_pixel_we ),
        .wdata       ( cap_pixel_data ),
        .wfull       ( w_fifo_full ),
        .rclk        ( clk_50m ),
        .rrst_n      ( w_fifo_rrst_n ),
        .rinc        ( w_fifo_rd_en ),
        .rdata       ( w_fifo_rd_data ),
        .rempty      ( w_fifo_empty ),
        .rcount      ( w_fifo_count )
    );

    // ------------------------------------------------------------------------
    // 4. MODULE: sdram_arbiter
    // ------------------------------------------------------------------------
    sdram_arbiter #(
        .R_FIFO_DEPTH ( 1024 ),
        .BURST_LENGTH ( 256 )
    ) u_sdram_arbiter (
        .clk          ( clk_50m ),
        .rst_n        ( sys_rst_n ),
        .vga_vsync    ( vga_vsync ),
        .camera_vsync ( cam_vsync ),
        .w_fifo_empty ( w_fifo_empty ),
        .w_fifo_count ( w_fifo_count ),
        .w_fifo_data  ( w_fifo_rd_data ),
        .w_fifo_rd_en ( w_fifo_rd_en ),
        .r_fifo_count ( r_fifo_count ),
        .r_fifo_data  ( r_fifo_wr_data ),
        .r_fifo_wr_en ( r_fifo_wr_en ),
        .r_fifo_clear ( r_fifo_clear ),
        .sys_ready    ( arb_sys_ready ),
        .sys_valid    ( arb_sys_valid ),
        .sys_wr_ack   ( arb_sys_wr_ack ),
        .sys_write_req( arb_sys_wr_req ),
        .sys_read_req ( arb_sys_rd_req ),
        .sys_addr     ( arb_sys_addr ),
        .sys_data_in  ( arb_sys_data_in ),
        .sys_data_out ( arb_sys_data_out )
    );

    // ------------------------------------------------------------------------
    // 5. MODULE: fifo_sync (R-FIFO: Bá»“n chá»©a Ä‘á»‡m Äá»c Ä‘á»“ng bá»™ 50MHz)
    // ------------------------------------------------------------------------
    fifo_sync #(
        .DATA_WIDTH  ( 16 ),
        .ADDR_WIDTH  ( 10 )  // Dung lÆ°á»£ng 1024 tá»«
    ) u_r_fifo (
        .clk         ( clk_50m ),
        .rst_n       ( sys_rst_n ),
        .clear       ( r_fifo_clear ),
        .wr_en       ( r_fifo_wr_en ),
        .wr_data     ( r_fifo_wr_data ),
        .rd_en       ( r_fifo_rd_en ),
        .rd_data     ( r_fifo_rd_data ),
        .empty       ( r_fifo_empty ),
        .full        ( r_fifo_full ),
        .count       ( r_fifo_count )
    );

    // ------------------------------------------------------------------------
    // 6. MODULE: vga_sync
    // ------------------------------------------------------------------------
    wire vga_hsync_w, vga_vsync_w; vga_sync u_vga_sync (
        .clk         ( clk_50m ),
        .rst_n       ( sys_rst_n ),
        .ce          ( vga_ce ),
        .hsync(vga_hsync_w),
        .vsync(vga_vsync_w),
        .video_on    ( vga_video_on ),
        .pixel_x     ( vga_pixel_x ),
        .pixel_y     ( vga_pixel_y ),
        .frame_start ( vga_frame_start )
    );

    // ========================================================================
    // PHáº¦N D: CÃC MODULE NGOáº I VI Bá»” TRá»¢ (HELPER MODULES)
    // ========================================================================

    // ------------------------------------------------------------------------
    // 7. MODULE: sdram_controller
    // ------------------------------------------------------------------------
    sdram_controller u_sdram_controller (
        .clk         ( clk_50m ),
        .rst_n       ( sys_rst_n ),
        .write_req   ( arb_sys_wr_req ),
        .read_req    ( arb_sys_rd_req ),
        .sys_addr    ( arb_sys_addr ),
        .sys_data_in ( arb_sys_data_in ),
        .sys_data_out( arb_sys_data_out ),
        .sys_ready   ( arb_sys_ready ),
        .sys_valid   ( arb_sys_valid ),
        .sys_wr_ack  ( arb_sys_wr_ack ),
        .sdram_addr  ( sdram_addr ),
        .sdram_ba    ( sdram_ba ),
        .sdram_cs_n  ( sdram_cs_n ),
        .sdram_ras_n ( sdram_ras_n ),
        .sdram_cas_n ( sdram_cas_n ),
        .sdram_we_n  ( sdram_we_n ),
        .sdram_dq    ( sdram_dq )
    );

    // ------------------------------------------------------------------------
    // 8. MODULE: i2c_master
    // ------------------------------------------------------------------------
    i2c_master u_i2c_master (
        .clk         ( clk_50m ),
        .reset_n     ( sys_rst_n ),
        .start       ( cfg_i2c_start ),
        .slave_addr  ( 7'h21 ),     // Äá»‹a chá»‰ 7-bit cá»§a OV7670 (0x42 >> 1 = 0x21)
        .rw          ( 1'b0 ),      // 0 = Ghi (Write)
        .data_in     ( cfg_i2c_data ), // Gá»“m 8-bit Sub-Address vÃ  8-bit Data
        .scl         ( cam_scl ),
        .sda         ( cam_sda ),
        .ready       ( cfg_i2c_ready ),
        .ack_error   ( i2c_err_pulse )            // CÃ³ thá»ƒ bá» trá»‘ng náº¿u khÃ´ng cáº§n xá»­ lÃ½ lá»—i
    );

    // ========================================================================
    // PHáº¦N E: LOGIC HIá»‚N THá»Š Äáº¦U RA VGA (PIXEL RGB PIPELINE)
    // ========================================================================
    // Sáº¿p chá»‰ viá»‡c kÃ­ch hoáº¡t Ä‘á»c R-FIFO khi mÃ n hÃ¬nh cáº§n váº½ (video_on && vga_ce)
    assign r_fifo_rd_en = vga_video_on && (!r_fifo_empty) && vga_ce;

    // Láº¥y dá»¯ liá»‡u Ä‘iá»ƒm áº£nh (náº¿u ngoÃ i vÃ¹ng hiá»ƒn thá»‹ hoáº·c cáº¡n FIFO thÃ¬ cho mÃ u Ä‘en)
    wire [15:0] current_pixel = (vga_video_on && !r_fifo_empty) ? r_fifo_rd_data : 16'h0000;

    // Chuyá»ƒn Ä‘á»•i mÃ u RGB565 sang DAC 4-4-4 cá»§a máº¡ch DE1 theo chuáº©n Project 2:
    // Chá»‘t qua xung enable vga_ce (25MHz) Ä‘á»“ng bá»™ tuyá»‡t Ä‘á»‘i vá»›i chu ká»³ pixel VGA
    reg [3:0] vga_r_reg, vga_g_reg, vga_b_reg;
    always @(posedge clk_50m or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            vga_r_reg <= 4'h0;
            vga_g_reg <= 4'h0;
            vga_b_reg <= 4'h0;
        end else begin // [FIX PROJECT 2] Chot 50MHz loai bo soc doc
            vga_r_reg <= current_pixel[15:12];
            vga_g_reg <= current_pixel[10:7];
            vga_b_reg <= current_pixel[4:1];
        end
    end

    reg [3:0] vga_r_out, vga_g_out, vga_b_out;
    reg vga_hs_out, vga_vs_out;
    always @(posedge clk_50m or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            vga_r_out  <= 4'd0; vga_g_out  <= 4'd0; vga_b_out  <= 4'd0;
            vga_hs_out <= 1'b1; vga_vs_out <= 1'b1;
        end else begin
            vga_r_out  <= vga_r_reg; vga_g_out  <= vga_g_reg; vga_b_out  <= vga_b_reg;
            vga_hs_out <= vga_hsync_w; vga_vs_out <= vga_vsync_w;
        end
    end
    assign vga_r = vga_r_out; assign vga_g = vga_g_out; assign vga_b = vga_b_out; assign vga_hsync = vga_hs_out; assign vga_vsync = vga_vs_out;


    // ========================================================================
    // [DEBUG] VIRTUAL DASHBOARD (LED MAPPING)
    // ========================================================================
    assign LED[0] = cam_pwdn;
    assign LED[1] = cam_reset;

    // Blinker for cam_xclk
    reg [24:0] blink_cnt;
    always @(posedge cam_xclk) begin
        blink_cnt <= blink_cnt + 1'b1;
    end
    assign LED[2] = blink_cnt[24];

    assign LED[3] = cam_scl;
    assign LED[4] = cam_sda;
    assign LED[5] = cfg_i2c_ready;
    assign LED[6] = 1'b0;
    assign LED[7] = 1'b0;
        // wire i2c_err_pulse; (already implicitly declared)
    reg i2c_err_latch;
    always @(posedge clk_50m or negedge sys_rst_n) begin
        if (!sys_rst_n) i2c_err_latch <= 1'b0;
        else if (i2c_err_pulse) i2c_err_latch <= 1'b1;
    end

    assign LED[8] = i2c_err_latch;
    assign LED[9] = cfg_done;

endmodule






