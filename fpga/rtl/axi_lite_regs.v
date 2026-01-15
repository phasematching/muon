/**
 * axi_lite_regs.v
 *
 * AXI-Lite register interface for coincidence detector
 *
 * Provides memory-mapped access to control registers and counters via AXI-Lite.
 * This allows software running on the Red Pitaya ARM processor to configure
 * the coincidence detector and read event counters.
 *
 * Register Map (byte addresses):
 * 0x000: Control register (R/W)
 *        [0]: Enable detection
 *        [1]: Reset counters (write 1 to reset)
 * 0x004: Status register (R/O)
 * 0x008: Threshold A (R/W, signed)
 * 0x00C: Threshold B (R/W, signed)
 * 0x010: Coincidence window in clock cycles (R/W)
 * 0x014: Event counter A (R/O)
 * 0x018: Event counter B (R/O)
 * 0x01C: Coincidence counter (R/O)
 * 0x020: Version/ID register (R/O)
 *
 * Author: Muon Detection Project
 * License: MIT
 */

module axi_lite_regs #(
    parameter AXI_DATA_WIDTH = 32,
    parameter AXI_ADDR_WIDTH = 12,
    parameter ADC_WIDTH = 14,
    parameter COUNTER_WIDTH = 32
)(
    input  wire                        clk,
    input  wire                        rst_n,

    // AXI-Lite slave interface
    input  wire [AXI_ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  wire [2:0]                  s_axi_awprot,
    input  wire                        s_axi_awvalid,
    output reg                         s_axi_awready,

    input  wire [AXI_DATA_WIDTH-1:0]   s_axi_wdata,
    input  wire [3:0]                  s_axi_wstrb,
    input  wire                        s_axi_wvalid,
    output reg                         s_axi_wready,

    output reg  [1:0]                  s_axi_bresp,
    output reg                         s_axi_bvalid,
    input  wire                        s_axi_bready,

    input  wire [AXI_ADDR_WIDTH-1:0]   s_axi_araddr,
    input  wire [2:0]                  s_axi_arprot,
    input  wire                        s_axi_arvalid,
    output reg                         s_axi_arready,

    output reg  [AXI_DATA_WIDTH-1:0]   s_axi_rdata,
    output reg  [1:0]                  s_axi_rresp,
    output reg                         s_axi_rvalid,
    input  wire                        s_axi_rready,

    // Control and status signals
    output reg                         enable,
    output reg                         reset_counters,
    output reg  signed [ADC_WIDTH-1:0] threshold_a,
    output reg  signed [ADC_WIDTH-1:0] threshold_b,
    output reg  [COUNTER_WIDTH-1:0]    coincidence_window,

    input  wire [COUNTER_WIDTH-1:0]    count_a,
    input  wire [COUNTER_WIDTH-1:0]    count_b,
    input  wire [COUNTER_WIDTH-1:0]    count_coinc
);

    //=========================================================================
    // Register Addresses
    //=========================================================================
    localparam ADDR_CONTROL       = 12'h000;
    localparam ADDR_STATUS        = 12'h004;
    localparam ADDR_THRESHOLD_A   = 12'h008;
    localparam ADDR_THRESHOLD_B   = 12'h00C;
    localparam ADDR_COINC_WINDOW  = 12'h010;
    localparam ADDR_COUNT_A       = 12'h014;
    localparam ADDR_COUNT_B       = 12'h018;
    localparam ADDR_COUNT_COINC   = 12'h01C;
    localparam ADDR_VERSION       = 12'h020;

    localparam VERSION_ID         = 32'h0001_0000;  // Version 1.0

    //=========================================================================
    // AXI Write Channel
    //=========================================================================
    reg [AXI_ADDR_WIDTH-1:0] write_addr;
    reg                      write_addr_valid;

    // Write address channel
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_awready <= 1'b0;
            write_addr <= 0;
            write_addr_valid <= 1'b0;
        end else begin
            if (s_axi_awvalid && !s_axi_awready) begin
                s_axi_awready <= 1'b1;
                write_addr <= s_axi_awaddr;
                write_addr_valid <= 1'b1;
            end else begin
                s_axi_awready <= 1'b0;
                if (s_axi_bvalid && s_axi_bready) begin
                    write_addr_valid <= 1'b0;
                end
            end
        end
    end

    // Write data channel and register updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_wready <= 1'b0;
            s_axi_bvalid <= 1'b0;
            s_axi_bresp <= 2'b00;
            enable <= 1'b0;
            reset_counters <= 1'b0;
            threshold_a <= 14'sd819;  // Default: 0.1V (0.1/1.0 * 2^13 = 819)
            threshold_b <= 14'sd819;
            coincidence_window <= 250;  // Default: 250 cycles = 2 us @ 125 MHz
        end else begin
            // Default: clear reset_counters (it's a pulse)
            reset_counters <= 1'b0;

            // Write transaction
            if (s_axi_wvalid && write_addr_valid && !s_axi_wready) begin
                s_axi_wready <= 1'b1;
                s_axi_bvalid <= 1'b1;
                s_axi_bresp <= 2'b00;  // OKAY response

                // Decode address and write to register
                case (write_addr)
                    ADDR_CONTROL: begin
                        if (s_axi_wstrb[0]) begin
                            enable <= s_axi_wdata[0];
                            reset_counters <= s_axi_wdata[1];
                        end
                    end

                    ADDR_THRESHOLD_A: begin
                        threshold_a <= s_axi_wdata[ADC_WIDTH-1:0];
                    end

                    ADDR_THRESHOLD_B: begin
                        threshold_b <= s_axi_wdata[ADC_WIDTH-1:0];
                    end

                    ADDR_COINC_WINDOW: begin
                        coincidence_window <= s_axi_wdata[COUNTER_WIDTH-1:0];
                    end

                    default: begin
                        // Invalid address or read-only register
                        s_axi_bresp <= 2'b10;  // SLVERR
                    end
                endcase
            end else begin
                s_axi_wready <= 1'b0;
                if (s_axi_bready) begin
                    s_axi_bvalid <= 1'b0;
                end
            end
        end
    end

    //=========================================================================
    // AXI Read Channel
    //=========================================================================
    reg [AXI_ADDR_WIDTH-1:0] read_addr;

    // Read address channel
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_arready <= 1'b0;
            read_addr <= 0;
        end else begin
            if (s_axi_arvalid && !s_axi_arready) begin
                s_axi_arready <= 1'b1;
                read_addr <= s_axi_araddr;
            end else begin
                s_axi_arready <= 1'b0;
            end
        end
    end

    // Read data channel
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rdata <= 0;
            s_axi_rresp <= 2'b00;
        end else begin
            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rresp <= 2'b00;  // OKAY response

                // Decode address and read from register
                case (read_addr)
                    ADDR_CONTROL: begin
                        s_axi_rdata <= {{30{1'b0}}, reset_counters, enable};
                    end

                    ADDR_STATUS: begin
                        s_axi_rdata <= 32'h0000_0001;  // Bit 0: Always ready
                    end

                    ADDR_THRESHOLD_A: begin
                        s_axi_rdata <= {{(AXI_DATA_WIDTH-ADC_WIDTH){threshold_a[ADC_WIDTH-1]}}, threshold_a};
                    end

                    ADDR_THRESHOLD_B: begin
                        s_axi_rdata <= {{(AXI_DATA_WIDTH-ADC_WIDTH){threshold_b[ADC_WIDTH-1]}}, threshold_b};
                    end

                    ADDR_COINC_WINDOW: begin
                        s_axi_rdata <= coincidence_window;
                    end

                    ADDR_COUNT_A: begin
                        s_axi_rdata <= count_a;
                    end

                    ADDR_COUNT_B: begin
                        s_axi_rdata <= count_b;
                    end

                    ADDR_COUNT_COINC: begin
                        s_axi_rdata <= count_coinc;
                    end

                    ADDR_VERSION: begin
                        s_axi_rdata <= VERSION_ID;
                    end

                    default: begin
                        s_axi_rdata <= 32'hDEADBEEF;
                        s_axi_rresp <= 2'b10;  // SLVERR
                    end
                endcase
            end else if (s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
