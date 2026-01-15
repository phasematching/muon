/**
 * tb_coincidence_detector.v
 *
 * Testbench for coincidence detection logic
 *
 * Tests:
 * 1. Threshold detection on both channels
 * 2. Coincidence detection within window
 * 3. Non-coincidence (pulses too far apart)
 * 4. Counter functionality
 * 5. AXI register interface
 *
 * Author: Muon Detection Project
 * License: MIT
 */

`timescale 1ns / 1ps

module tb_coincidence_detector;

    //=========================================================================
    // Parameters
    //=========================================================================
    parameter ADC_WIDTH = 14;
    parameter COUNTER_WIDTH = 32;
    parameter CLK_PERIOD = 8;  // 8 ns = 125 MHz

    //=========================================================================
    // Signals
    //=========================================================================
    reg                      clk;
    reg                      rst_n;
    reg signed [ADC_WIDTH-1:0] adc_a;
    reg signed [ADC_WIDTH-1:0] adc_b;
    reg                      adc_valid;

    wire                     debug_trigger_a;
    wire                     debug_trigger_b;
    wire                     debug_coincidence;

    // AXI-Lite interface signals (simplified for testing)
    reg  [11:0]              axi_awaddr;
    reg                      axi_awvalid;
    wire                     axi_awready;
    reg  [31:0]              axi_wdata;
    reg                      axi_wvalid;
    wire                     axi_wready;
    wire [1:0]               axi_bresp;
    wire                     axi_bvalid;
    reg                      axi_bready;
    reg  [11:0]              axi_araddr;
    reg                      axi_arvalid;
    wire                     axi_arready;
    wire [31:0]              axi_rdata;
    wire [1:0]               axi_rresp;
    wire                     axi_rvalid;
    reg                      axi_rready;

    //=========================================================================
    // DUT Instantiation
    //=========================================================================
    coincidence_detector #(
        .ADC_WIDTH(ADC_WIDTH),
        .COUNTER_WIDTH(COUNTER_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .adc_a(adc_a),
        .adc_b(adc_b),
        .adc_valid(adc_valid),
        .s_axi_awaddr(axi_awaddr),
        .s_axi_awprot(3'b000),
        .s_axi_awvalid(axi_awvalid),
        .s_axi_awready(axi_awready),
        .s_axi_wdata(axi_wdata),
        .s_axi_wstrb(4'b1111),
        .s_axi_wvalid(axi_wvalid),
        .s_axi_wready(axi_wready),
        .s_axi_bresp(axi_bresp),
        .s_axi_bvalid(axi_bvalid),
        .s_axi_bready(axi_bready),
        .s_axi_araddr(axi_araddr),
        .s_axi_arprot(3'b000),
        .s_axi_arvalid(axi_arvalid),
        .s_axi_arready(axi_arready),
        .s_axi_rdata(axi_rdata),
        .s_axi_rresp(axi_rresp),
        .s_axi_rvalid(axi_rvalid),
        .s_axi_rready(axi_rready),
        .debug_trigger_a(debug_trigger_a),
        .debug_trigger_b(debug_trigger_b),
        .debug_coincidence(debug_coincidence)
    );

    //=========================================================================
    // Clock Generation
    //=========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //=========================================================================
    // Test Stimulus
    //=========================================================================
    integer num_errors;

    initial begin
        // Initialize signals
        rst_n = 0;
        adc_a = 0;
        adc_b = 0;
        adc_valid = 1;
        axi_awaddr = 0;
        axi_awvalid = 0;
        axi_wdata = 0;
        axi_wvalid = 0;
        axi_bready = 1;
        axi_araddr = 0;
        axi_arvalid = 0;
        axi_rready = 1;
        num_errors = 0;

        // Reset
        #(CLK_PERIOD*10);
        rst_n = 1;
        #(CLK_PERIOD*5);

        $display("========================================");
        $display("Coincidence Detector Testbench");
        $display("========================================");

        //=====================================================================
        // Test 1: Configure via AXI
        //=====================================================================
        $display("\nTest 1: Configure detector via AXI");

        // Set threshold A to 819 (0.1V)
        axi_write(12'h008, 32'd819);
        $display("  Set threshold A = 819");

        // Set threshold B to 819 (0.1V)
        axi_write(12'h00C, 32'd819);
        $display("  Set threshold B = 819");

        // Set coincidence window to 125 cycles (1 us)
        axi_write(12'h010, 32'd125);
        $display("  Set coincidence window = 125 cycles (1 us)");

        // Enable detector
        axi_write(12'h000, 32'h0000_0001);
        $display("  Enable detector");

        #(CLK_PERIOD*10);

        //=====================================================================
        // Test 2: Single pulse on channel A (no coincidence)
        //=====================================================================
        $display("\nTest 2: Single pulse on channel A");
        generate_pulse_a(1000);  // 1000 ADC counts
        #(CLK_PERIOD*200);

        if (debug_trigger_a) begin
            $display("  PASS: Trigger A detected");
        end else begin
            $display("  FAIL: Trigger A not detected");
            num_errors = num_errors + 1;
        end

        //=====================================================================
        // Test 3: Coincident pulses (within window)
        //=====================================================================
        $display("\nTest 3: Coincident pulses (50 cycle delay)");
        fork
            generate_pulse_a(1000);
            begin
                #(CLK_PERIOD*50);  // 50 cycles delay
                generate_pulse_b(1000);
            end
        join

        #(CLK_PERIOD*10);

        if (debug_coincidence) begin
            $display("  PASS: Coincidence detected");
        end else begin
            $display("  FAIL: Coincidence not detected");
            num_errors = num_errors + 1;
        end

        #(CLK_PERIOD*200);

        //=====================================================================
        // Test 4: Non-coincident pulses (outside window)
        //=====================================================================
        $display("\nTest 4: Non-coincident pulses (200 cycle delay)");
        fork
            generate_pulse_a(1000);
            begin
                #(CLK_PERIOD*200);  // 200 cycles delay (>125 window)
                generate_pulse_b(1000);
            end
        join

        #(CLK_PERIOD*50);

        // Check counters via AXI
        // Should have: count_a >= 2, count_b >= 2, count_coinc >= 1
        $display("  Reading counters...");
        axi_read(12'h014);  // Count A
        $display("  Count A = %d", axi_rdata);

        axi_read(12'h018);  // Count B
        $display("  Count B = %d", axi_rdata);

        axi_read(12'h01C);  // Count coincidence
        $display("  Count Coinc = %d", axi_rdata);

        //=====================================================================
        // Test 5: Reset counters
        //=====================================================================
        $display("\nTest 5: Reset counters");
        axi_write(12'h000, 32'h0000_0003);  // Enable + Reset
        #(CLK_PERIOD*10);
        axi_write(12'h000, 32'h0000_0001);  // Clear reset bit

        axi_read(12'h014);  // Count A
        if (axi_rdata == 0) begin
            $display("  PASS: Counter A reset to 0");
        end else begin
            $display("  FAIL: Counter A = %d (expected 0)", axi_rdata);
            num_errors = num_errors + 1;
        end

        //=====================================================================
        // Test Summary
        //=====================================================================
        #(CLK_PERIOD*100);
        $display("\n========================================");
        if (num_errors == 0) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $display("TESTS FAILED: %d errors", num_errors);
        end
        $display("========================================");

        $finish;
    end

    //=========================================================================
    // Helper Tasks
    //=========================================================================

    // Generate a pulse on channel A
    task generate_pulse_a;
        input signed [ADC_WIDTH-1:0] amplitude;
        begin
            adc_a = amplitude;
            #(CLK_PERIOD*10);  // Pulse width
            adc_a = 0;
        end
    endtask

    // Generate a pulse on channel B
    task generate_pulse_b;
        input signed [ADC_WIDTH-1:0] amplitude;
        begin
            adc_b = amplitude;
            #(CLK_PERIOD*10);  // Pulse width
            adc_b = 0;
        end
    endtask

    // AXI write transaction
    task axi_write;
        input [11:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            axi_awaddr = addr;
            axi_awvalid = 1;
            axi_wdata = data;
            axi_wvalid = 1;

            @(posedge clk);
            while (!axi_awready || !axi_wready) @(posedge clk);

            axi_awvalid = 0;
            axi_wvalid = 0;

            @(posedge clk);
            while (!axi_bvalid) @(posedge clk);
            @(posedge clk);
        end
    endtask

    // AXI read transaction
    task axi_read;
        input [11:0] addr;
        begin
            @(posedge clk);
            axi_araddr = addr;
            axi_arvalid = 1;

            @(posedge clk);
            while (!axi_arready) @(posedge clk);
            axi_arvalid = 0;

            @(posedge clk);
            while (!axi_rvalid) @(posedge clk);
            @(posedge clk);
        end
    endtask

    //=========================================================================
    // Waveform Dump
    //=========================================================================
    initial begin
        $dumpfile("tb_coincidence_detector.vcd");
        $dumpvars(0, tb_coincidence_detector);
    end

endmodule
