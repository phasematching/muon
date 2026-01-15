/**
 * threshold_detector.v
 *
 * Threshold-based pulse detector for scintillator signals
 *
 * Detects when ADC input crosses a programmable threshold and generates
 * a single-cycle trigger pulse. Includes hysteresis and re-arm logic to
 * prevent multiple triggers from a single pulse.
 *
 * Features:
 * - Programmable threshold (signed comparison)
 * - Hysteresis to prevent oscillation
 * - Re-arm delay to prevent double-triggering
 * - Single-cycle output pulse per detected event
 *
 * Author: Muon Detection Project
 * License: MIT
 */

module threshold_detector #(
    parameter ADC_WIDTH = 14,
    parameter REARM_DELAY = 8        // Cycles to wait before re-arming (prevents double-trigger)
)(
    input  wire                      clk,
    input  wire                      rst_n,
    input  wire                      enable,

    input  wire signed [ADC_WIDTH-1:0] adc_data,
    input  wire                      adc_valid,
    input  wire signed [ADC_WIDTH-1:0] threshold,

    output reg                       trigger
);

    //=========================================================================
    // State Machine for Trigger Detection
    //=========================================================================
    localparam STATE_IDLE     = 2'b00;  // Waiting for threshold crossing
    localparam STATE_TRIGGERED = 2'b01; // Pulse detected, output trigger
    localparam STATE_WAIT     = 2'b10;  // Waiting for signal to fall below threshold
    localparam STATE_REARM    = 2'b11;  // Re-arm delay before next detection

    reg [1:0] state;
    reg [7:0] rearm_counter;

    // Hysteresis: threshold for falling edge is slightly lower
    // This prevents oscillation around the threshold
    wire signed [ADC_WIDTH-1:0] threshold_lower;
    assign threshold_lower = threshold - (threshold >>> 4);  // ~6% hysteresis

    // Threshold comparison
    wire above_threshold;
    wire below_threshold_lower;

    assign above_threshold = (adc_data >= threshold);
    assign below_threshold_lower = (adc_data < threshold_lower);

    //=========================================================================
    // State Machine
    //=========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            trigger <= 1'b0;
            rearm_counter <= 0;
        end else begin
            // Default: no trigger
            trigger <= 1'b0;

            if (!enable) begin
                // Disabled: return to idle
                state <= STATE_IDLE;
                rearm_counter <= 0;
            end else if (adc_valid) begin
                case (state)
                    STATE_IDLE: begin
                        // Waiting for threshold crossing
                        if (above_threshold) begin
                            trigger <= 1'b1;          // Generate trigger pulse
                            state <= STATE_TRIGGERED;
                        end
                    end

                    STATE_TRIGGERED: begin
                        // Trigger generated, wait for signal to drop
                        if (below_threshold_lower) begin
                            state <= STATE_REARM;
                            rearm_counter <= REARM_DELAY;
                        end else begin
                            state <= STATE_WAIT;
                        end
                    end

                    STATE_WAIT: begin
                        // Wait for signal to fall below threshold
                        if (below_threshold_lower) begin
                            state <= STATE_REARM;
                            rearm_counter <= REARM_DELAY;
                        end
                    end

                    STATE_REARM: begin
                        // Re-arm delay to prevent double-triggering
                        if (rearm_counter > 0) begin
                            rearm_counter <= rearm_counter - 1;
                        end else begin
                            state <= STATE_IDLE;
                        end
                    end

                    default: begin
                        state <= STATE_IDLE;
                    end
                endcase
            end
        end
    end

endmodule
