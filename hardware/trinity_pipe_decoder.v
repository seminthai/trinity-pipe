module trinity_pipe_decoder (
    input  wire        clk,         // Bus clock frequency
    input  wire        rst_n,       // Asynchronous hardware reset (active low)
    input  wire [1:0]  trit_in,     // Ternary input token: 00=T0, 01=T1, 10=TZ
    
    output reg  [3:0]  data_out,    // Restored 4-bit nibble
    output reg         data_ready,  // Data ready strobe (active for 1 clk cycle)
    output reg         frame_error  // Hardware framing error flag (timeout)
);

    // Ternary alphabet encoding for digital logic
    localparam TRIT_0 = 2'b00;
    localparam TRIT_1 = 2'b01;
    localparam TRIT_Z = 2'b10;

    // Internal hardware register counters
    reg [2:0] bit_count; // Tracks bits received before Z marker (0..4)
    reg [3:0] pattern;   // Shift register accumulating incoming binary patterns

    // Combinatorial decoding logic matrix
    reg [3:0] decoded_value;
    reg       invalid_combination;

    always @(*) begin
        decoded_value       = 4'b0000;
        invalid_combination = 1'b0;
        
        case (bit_count)
            3'd0: decoded_value = 4'd0; // 0 bits before Z: [Z] -> 0
            
            3'd1: begin // 1 bit before Z: [0Z] -> 1, [1Z] -> 2
                if (pattern == 1'b1) decoded_value = 4'd2;
                else                    decoded_value = 4'd1;
            end
            
            3'd2: begin // 2 bits before Z: [00Z] -> 3 ... [11Z] -> 6
                decoded_value = 4'd3 + pattern[1:0];
            end
            
            3'd3: begin // 3 bits before Z: [000Z] -> 7 ... [111Z] -> 14
                decoded_value = 4'd7 + pattern[2:0];
            end
            
            3'd4: begin // 4 bits before Z: [0000Z] -> 15
                if (pattern[3:0] == 4'b0000) decoded_value = 4'd15;
                else                         invalid_combination = 1'b1; // Protection block
            end
            
            default: invalid_combination = 1'b1;
        endcase
    end

    // Sequential Finite State Machine (FSM) logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_count   <= 3'b000;
            pattern     <= 4'b0000;
            data_out    <= 4'b0000;
            data_ready  <= 1'b0;
            frame_error <= 1'b0;
        end else begin
            // Default strobe state reset on every clock cycle
            data_ready <= 1'b0;

            case (trit_in)
                TRIT_0, TRIT_1: begin
                    // Hardware watchdog: signal crash if packet length exceeds 4 bits without Z
                    if (bit_count >= 3'd4) begin
                        frame_error <= 1'b1;
                        bit_count   <= 3'b000;
                        pattern     <= 4'b0000;
                    end else begin
                        // Shift incoming bit into pattern and increment clock counter
                        pattern   <= (pattern << 1) | trit_in;
                        bit_count <= bit_count + 1'b1;
                    end
                end

                TRIT_Z: begin
                    // Physical framing delimiter detected. Latency-free capture in 0 cycles!
                    if (!invalid_combination && !frame_error) begin
                        data_out   <= decoded_value;
                        data_ready <= 1'b1;
                    end
                    
                    // Instantaneous internal hardware reset for the next token sequence
                    bit_count   <= 3'b000;
                    pattern     <= 4'b0000;
                    frame_error <= 1'b0; // Reset error flag upon receiving a clean Z marker
                end

                default: begin
                    // Any undefined bus state forces a hardware error flag
                    frame_error <= 1'b1;
                    bit_count   <= 3'b000;
                end
            endcase
        end
    end

endmodule
