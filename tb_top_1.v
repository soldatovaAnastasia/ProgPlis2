`timescale 1ns/1ps
`include "top_1.v"
`ifdef USE_REF
`include "top_1_ref.v"
`endif

module tb_top_1;

    parameter TIMEOUT_NS = 10_000_000;

    reg clk;
    reg rst_n;
    reg bit_in;
    reg done;

    wire found1_dut, found2_dut, timer_done_dut;
    wire [31:0] sum_out_dut;
`ifdef USE_REF
    wire found1_ref, found2_ref, timer_done_ref;
    wire [31:0] sum_out_ref;
    integer errors;
    integer total_checks;
`endif

    top_1 dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .bit_in     (bit_in),
        .done       (done),
        .found1     (found1_dut),
        .found2     (found2_dut),
        .timer_done (timer_done_dut),
        .sum_out    (sum_out_dut)
    );
`ifdef USE_REF
    top_1_ref dut_check (
        .clk        (clk),
        .rst_n      (rst_n),
        .bit_in     (bit_in),
        .done       (done),
        .found1     (found1_ref),
        .found2     (found2_ref),
        .timer_done (timer_done_ref),
        .sum_out    (sum_out_ref)
    );
`endif

    // тактовый генератор, период 10нс
    initial clk = 1'b0;
    always #5 clk = ~clk;

`ifdef USE_REF
    // на каждом такте сверяем выходы проверяемого модуля dut с эталоном dut_check
    always @(posedge clk) begin
        if (rst_n) begin
            total_checks = total_checks + 1;
            if (found1_dut !== found1_ref || found2_dut !== found2_ref ||
                timer_done_dut !== timer_done_ref || sum_out_dut !== sum_out_ref) begin
                errors = errors + 1;
                $display("FAIL @t=%0t: found1=%b(exp %b) found2=%b(exp %b) timer_done=%b(exp %b) sum_out=%0d(exp %0d)",
                          $time, found1_dut, found1_ref, found2_dut, found2_ref,
                          timer_done_dut, timer_done_ref, sum_out_dut, sum_out_ref);
            end
        end
    end
`endif

    task feed_bit;
        input bv;
        begin
            bit_in <= bv;
            @(posedge clk);
        end
    endtask

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_top_1);
        elapsed_ns = 0;
`ifdef USE_REF
        errors = 0;
        total_checks = 0;
`endif
        rst_n <= 1'b0;
        bit_in <= 1'b0;
        done <= 1'b0;
        repeat (3) @(posedge clk);
        rst_n <= 1'b1;
        @(posedge clk);

        $display("Running tests for module top_1 (NUM_STATES=5, paths to explore: 1)...");

        // --- Path 1 of 1: states [0, 1, 2, 3, 4] ---
        // stage 1: feeding the bits of the sought 8-bit number
        feed_bit(1'b0);
        feed_bit(1'b0);
        feed_bit(1'b1);
        feed_bit(1'b0);
        feed_bit(1'b1);
        feed_bit(1'b1);
        feed_bit(1'b1);
        feed_bit(1'b0);
        // TARGET_BYTE уже записан в shift_reg, поэтому ожидаем фронт found1.
        @(posedge found1_dut);
        // Дать FSM ещё один такт для перехода SEARCH -> TRAVERSE.
        @(posedge clk);
        // stage 2: feeding the transition bits along the selected path
        feed_bit(1'b1);
        feed_bit(1'b0);
        feed_bit(1'b1);
        feed_bit(1'b0);
        // stage 3: waiting for the timer to finish
        bit_in <= 1'b0;
        while (timer_done_dut !== 1'b1) @(posedge clk);
        // stage 4: confirming done, the machine should close the loop and start over
        done <= 1'b1;
        @(posedge clk);
        done <= 1'b0;

`ifdef USE_REF
        if (errors == 0)
            $display("Test passed successfully. All %0d checks matched the reference.", total_checks);
        else
            $display("FAIL: %0d/%0d checks did not match the reference.", errors, total_checks);
`else
        $display("Simulation finished. Check found1/found2/timer_done/sum_out in GTKWave (waveform.vcd).");
`endif

        $finish;
    end
integer elapsed_ns;

always @(posedge clk) begin
        if (elapsed_ns * 10 < TIMEOUT_NS) begin
            elapsed_ns = elapsed_ns + 1;
        end else begin
            $display("FAIL: timeout (%0d ns) waiting for %0d frames.",
                      TIMEOUT_NS, elapsed_ns);
            $finish;
        end
end

endmodule // tb_top_1
