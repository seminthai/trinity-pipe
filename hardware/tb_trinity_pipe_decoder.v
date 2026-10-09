`timescale 1ns/1ps

module tb_trinity_pipe_decoder;
    reg clk;
    reg rst_n;
    reg [1:0] trit_in;

    wire [3:0] data_out;
    wire data_ready;
    wire frame_error;

    // Instantiate Unit Under Test (UUT)
    trinity_pipe_decoder uut (
        .clk(clk),
        .rst_n(rst_n),
        .trit_in(trit_in),
        .data_out(data_out),
        .data_ready(data_ready),
        .frame_error(frame_error)
    );

    // Clock generator (Each bus clock cycle takes 10 nanoseconds)
    always #5 clk = ~clk;

    initial begin
        // Standard waveform dump directives
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_trinity_pipe_decoder);

        // System Initialization
        clk = 0;
        rst_n = 0;
        trit_in = 2'b00;
        #15;
        rst_n = 1; // Release reset, the channel goes active
        #5;

        // --- TEST 1: Transmission of Value 0 (Code: Z) ---
        trit_in = 2'b10; // TRIT_Z
        #10;

        // --- TEST 2: Transmission of Value 4 (Code: 0, 1, Z) ---
        trit_in = 2'b00; // TRIT_0
        #10;
        trit_in = 2'b01; // TRIT_1
        #10;
        trit_in = 2'b10; // TRIT_Z (Physical framing delimiter)
        #10;

        // --- TEST 3: Transmission of Value 15 (Code: 0, 0, 0, 0, Z) ---
        trit_in = 2'b00; #10; // TRIT_0
        trit_in = 2'b00; #10; // TRIT_0
        trit_in = 2'b00; #10; // TRIT_0
        trit_in = 2'b00; #10; // TRIT_0
        trit_in = 2'b10; #10; // TRIT_Z
        
        // --- TEST 4: Hardware Watchdog Validation (Stuck line / Short circuit) ---
        // Inject an overflowing stream of continuous bits without a Z delimiter
        trit_in = 2'b01; #10; // TRIT_1
        trit_in = 2'b01; #10; // TRIT_1
        trit_in = 2'b01; #10; // TRIT_1
        trit_in = 2'b01; #10; // TRIT_1
        trit_in = 2'b01; #10; // 5th continuous bit! Should trigger frame_error
        #10;

        $finish; // End design simulation execution
    end
endmodule
