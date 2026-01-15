/**
 * coincidence_logic.v
 *
 * Coincidence detection logic for dual-channel trigger inputs
 *
 * Detects when two trigger pulses occur within a programmable time window.
 * Uses a "capture window" approach where a trigger on either channel opens
 * a time window, and a trigger on the other channel within that window
 * constitutes a coincidence.
 *
 * Algorithm:
 * - When trigger_a occurs, open a window for trigger_b
 * - When trigger_b occurs, open a window for trigger_a
 * - If both conditions are met within the window, output coincidence pulse
 * - Prevent duplicate coincidences from the same event pair
 *
 * Timing resolution: 1 clock cycle (8 ns @ 125 MHz)
 * Maximum window: 2^32 - 1 clock cycles (~34 ms @ 125 MHz)
 *
 * Author: Muon Detection Project
 * License: MIT
 */

module coincidence_logic #(
    parameter COUNTER_WIDTH = 32
)(
    input  wire                        clk,
    input  wire                        rst_n,
    input  wire                        enable,

    input  wire                        trigger_a,    // Channel A trigger pulse
    input  wire                        trigger_b,    // Channel B trigger pulse
    input  wire [COUNTER_WIDTH-1:0]    window,       // Coincidence window (clock cycles)

    output reg                         coincidence   // Coincidence detected (single cycle pulse)
);

    //=========================================================================
    // Window Timers
    //=========================================================================
    // When a trigger occurs on one channel, we open a time window and wait
    // for a trigger on the other channel within that window.

    reg [COUNTER_WIDTH-1:0] timer_a;  // Counts down when waiting for B after A
    reg [COUNTER_WIDTH-1:0] timer_b;  // Counts down when waiting for A after B
    reg                     window_a_active;
    reg                     window_b_active;

    //=========================================================================
    // Coincidence Detection Logic
    //=========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            timer_a <= 0;
            timer_b <= 0;
            window_a_active <= 1'b0;
            window_b_active <= 1'b0;
            coincidence <= 1'b0;
        end else begin
            // Default: no coincidence
            coincidence <= 1'b0;

            if (!enable) begin
                // Disabled: reset all
                timer_a <= 0;
                timer_b <= 0;
                window_a_active <= 1'b0;
                window_b_active <= 1'b0;
            end else begin
                //=====================================================
                // Window A: Waiting for B after A triggered
                //=====================================================
                if (trigger_a) begin
                    // New trigger on A: open window for B
                    window_a_active <= 1'b1;
                    timer_a <= window;

                    // Check if B window is already active (B happened recently)
                    if (window_b_active) begin
                        // Coincidence! Both A and B occurred within window
                        coincidence <= 1'b1;
                        // Close both windows to prevent duplicate coincidence
                        window_a_active <= 1'b0;
                        window_b_active <= 1'b0;
                        timer_a <= 0;
                        timer_b <= 0;
                    end
                end else if (window_a_active) begin
                    // Window A is active: count down
                    if (timer_a > 0) begin
                        timer_a <= timer_a - 1;

                        // Check if B triggers during this window
                        if (trigger_b) begin
                            // Coincidence!
                            coincidence <= 1'b1;
                            // Close window A
                            window_a_active <= 1'b0;
                            timer_a <= 0;
                            // Don't open window B since we just had a coincidence
                        end
                    end else begin
                        // Window expired without coincidence
                        window_a_active <= 1'b0;
                    end
                end

                //=====================================================
                // Window B: Waiting for A after B triggered
                //=====================================================
                // This is symmetric to window A logic
                if (trigger_b && !trigger_a) begin  // Don't process if A also triggered (handled above)
                    // New trigger on B: open window for A
                    window_b_active <= 1'b1;
                    timer_b <= window;

                    // Check if A window is already active (handled above in trigger_a section)
                    // If coincidence was detected above, window_a will be closed
                end else if (window_b_active) begin
                    // Window B is active: count down
                    if (timer_b > 0) begin
                        timer_b <= timer_b - 1;

                        // Check if A triggers during this window
                        if (trigger_a) begin
                            // Coincidence!
                            coincidence <= 1'b1;
                            // Close window B
                            window_b_active <= 1'b0;
                            timer_b <= 0;
                            // Don't open window A since we just had a coincidence
                        end
                    end else begin
                        // Window expired without coincidence
                        window_b_active <= 1'b0;
                    end
                end
            end
        end
    end

    //=========================================================================
    // Debug: Window Active Signals
    //=========================================================================
    // These can be useful for debugging/testing
    // synthesis translate_off
    wire debug_window_a_active = window_a_active;
    wire debug_window_b_active = window_b_active;
    wire [COUNTER_WIDTH-1:0] debug_timer_a = timer_a;
    wire [COUNTER_WIDTH-1:0] debug_timer_b = timer_b;
    // synthesis translate_on

endmodule
