/**
 * coincidence_detector.v
 *
 * FPGA-based coincidence detection module for Red Pitaya
 *
 * This module implements hardware-accelerated coincidence detection with:
 * - Dual-channel ADC input processing
 * - Programmable threshold comparators
 * - Configurable coincidence window
 * - Event counters with 32-bit resolution
 * - AXI-Lite register interface for control
 *
 * Timing specifications:
 * - Clock: 125 MHz (8 ns period)
 * - Timing resolution: 8 ns minimum
 * - Maximum coincidence window: ~34 ms (32-bit counter @ 125 MHz)
 *
 * Author: Muon Detection Project
 * License: MIT
 */

module coincidence_detector #(
    parameter ADC_WIDTH = 14,           // Red Pitaya ADC resolution
    parameter COUNTER_WIDTH = 32,       // Event counter width
    parameter AXI_DATA_WIDTH = 32,
    parameter AXI_ADDR_WIDTH = 12
)(
    // Clock and reset
    input  wire                        clk,          // 125 MHz system clock
    input  wire                        rst_n,        // Active-low reset

    // ADC inputs from Red Pitaya (signed)
    input  wire signed [ADC_WIDTH-1:0] adc_a,        // Channel A ADC data
    input  wire signed [ADC_WIDTH-1:0] adc_b,        // Channel B ADC data
    input  wire                        adc_valid,    // ADC data valid

    // AXI-Lite slave interface
    input  wire [AXI_ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  wire [2:0]                  s_axi_awprot,
    input  wire                        s_axi_awvalid,
    output wire                        s_axi_awready,

    input  wire [AXI_DATA_WIDTH-1:0]   s_axi_wdata,
    input  wire [3:0]                  s_axi_wstrb,
    input  wire                        s_axi_wvalid,
    output wire                        s_axi_wready,

    output wire [1:0]                  s_axi_bresp,
    output wire                        s_axi_bvalid,
    input  wire                        s_axi_bready,

    input  wire [AXI_ADDR_WIDTH-1:0]   s_axi_araddr,
    input  wire [2:0]                  s_axi_arprot,
    input  wire                        s_axi_arvalid,
    output wire                        s_axi_arready,

    output wire [AXI_DATA_WIDTH-1:0]   s_axi_rdata,
    output wire [1:0]                  s_axi_rresp,
    output wire                        s_axi_rvalid,
    input  wire                        s_axi_rready,

    // Debug outputs (optional)
    output wire                        debug_trigger_a,
    output wire                        debug_trigger_b,
    output wire                        debug_coincidence
);

    //=========================================================================
    // Register Map (byte addresses)
    //=========================================================================
    localparam ADDR_CONTROL       = 12'h000;  // Control register
    localparam ADDR_STATUS        = 12'h004;  // Status register
    localparam ADDR_THRESHOLD_A   = 12'h008;  // Threshold for channel A
    localparam ADDR_THRESHOLD_B   = 12'h00C;  // Threshold for channel B
    localparam ADDR_COINC_WINDOW  = 12'h010;  // Coincidence window (clocks)
    localparam ADDR_COUNT_A       = 12'h014;  // Event counter A (read-only)
    localparam ADDR_COUNT_B       = 12'h018;  // Event counter B (read-only)
    localparam ADDR_COUNT_COINC   = 12'h01C;  // Coincidence counter (read-only)
    localparam ADDR_VERSION       = 12'h020;  // Version/ID register

    // Control register bits
    localparam CTRL_ENABLE        = 0;        // Enable detection
    localparam CTRL_RESET_COUNTERS = 1;       // Reset all counters

    // Version identifier
    localparam VERSION_ID         = 32'h0001_0000;  // Version 1.0

    //=========================================================================
    // Internal Registers
    //=========================================================================
    reg                           enable;
    reg signed [ADC_WIDTH-1:0]    threshold_a;
    reg signed [ADC_WIDTH-1:0]    threshold_b;
    reg [COUNTER_WIDTH-1:0]       coincidence_window;

    reg [COUNTER_WIDTH-1:0]       count_a;
    reg [COUNTER_WIDTH-1:0]       count_b;
    reg [COUNTER_WIDTH-1:0]       count_coinc;

    //=========================================================================
    // Threshold Detection
    //=========================================================================
    wire trigger_a;
    wire trigger_b;

    threshold_detector #(
        .ADC_WIDTH(ADC_WIDTH)
    ) detector_a (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .adc_data(adc_a),
        .adc_valid(adc_valid),
        .threshold(threshold_a),
        .trigger(trigger_a)
    );

    threshold_detector #(
        .ADC_WIDTH(ADC_WIDTH)
    ) detector_b (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .adc_data(adc_b),
        .adc_valid(adc_valid),
        .threshold(threshold_b),
        .trigger(trigger_b)
    );

    //=========================================================================
    // Coincidence Logic
    //=========================================================================
    wire coincidence;

    coincidence_logic #(
        .COUNTER_WIDTH(COUNTER_WIDTH)
    ) coinc_logic (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .trigger_a(trigger_a),
        .trigger_b(trigger_b),
        .window(coincidence_window),
        .coincidence(coincidence)
    );

    //=========================================================================
    // Event Counters
    //=========================================================================
    reg reset_counters_reg;
    reg reset_counters_prev;
    wire reset_pulse;

    // Detect rising edge of reset_counters
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reset_counters_prev <= 1'b0;
        end else begin
            reset_counters_prev <= reset_counters_reg;
        end
    end

    assign reset_pulse = reset_counters_reg & ~reset_counters_prev;

    // Counter A
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_a <= 0;
        end else if (reset_pulse) begin
            count_a <= 0;
        end else if (enable && trigger_a) begin
            count_a <= count_a + 1;
        end
    end

    // Counter B
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_b <= 0;
        end else if (reset_pulse) begin
            count_b <= 0;
        end else if (enable && trigger_b) begin
            count_b <= count_b + 1;
        end
    end

    // Coincidence counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_coinc <= 0;
        end else if (reset_pulse) begin
            count_coinc <= 0;
        end else if (enable && coincidence) begin
            count_coinc <= count_coinc + 1;
        end
    end

    //=========================================================================
    // AXI-Lite Register Interface
    //=========================================================================
    axi_lite_regs #(
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .ADC_WIDTH(ADC_WIDTH),
        .COUNTER_WIDTH(COUNTER_WIDTH)
    ) axi_regs (
        .clk(clk),
        .rst_n(rst_n),

        // AXI-Lite interface
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),

        // Control/status registers
        .enable(enable),
        .reset_counters(reset_counters_reg),
        .threshold_a(threshold_a),
        .threshold_b(threshold_b),
        .coincidence_window(coincidence_window),
        .count_a(count_a),
        .count_b(count_b),
        .count_coinc(count_coinc)
    );

    //=========================================================================
    // Debug outputs
    //=========================================================================
    assign debug_trigger_a = trigger_a;
    assign debug_trigger_b = trigger_b;
    assign debug_coincidence = coincidence;

endmodule
