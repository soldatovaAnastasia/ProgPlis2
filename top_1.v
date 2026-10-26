`timescale 1ns/1ps

module top_1 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        bit_in,
    input  wire        done,
    output reg         found1,
    output reg         found2,
    output reg         timer_done,
    output reg  [31:0] sum_out
);
    localparam [7:0]  TARGET_BYTE = 8'b00101110;
    localparam [31:0] TIMER_MULT  = 32'd68;
    localparam [2:0]  EXIT_STATE  = 3'd4;

    localparam [1:0] S_SEARCH   = 2'd0,
                     S_TRAVERSE = 2'd1,
                     S_TIMER    = 2'd2,
                     S_WAIT     = 2'd3;

    reg [1:0]  phase;
    reg [7:0]  shift_reg;
    reg [2:0]  gstate, next_g;
    reg [31:0] sum_cur;      // сумма с учётом текущего состояния
    reg [31:0] sum_full;     // полная сумма пути (с финальным состоянием)
    reg [39:0] timer_cnt;
    reg        add_last;     // нужно досуммировать вклад состояния-выхода

    // таблица переходов графа
    function [2:0] next_state;
        input [2:0] s;
        input       b;
        case (s)
            3'd0:    next_state = b ? 3'd1 : 3'd0;
            3'd1:    next_state = b ? 3'd0 : 3'd2;
            3'd2:    next_state = b ? 3'd3 : 3'd1;
            3'd3:    next_state = b ? 3'd0 : 3'd4;
            default: next_state = 3'd4;
        endcase
    endfunction

    // выход состояния
    function [31:0] state_out;
        input [2:0] s;
        case (s)
            3'd0:    state_out = 32'd57;
            3'd1:    state_out = 32'd89;
            3'd2:    state_out = 32'd92;
            3'd3:    state_out = 32'd56;
            default: state_out = 32'd36;
        endcase
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase      <= S_SEARCH;
            shift_reg  <= 8'd0;
            gstate     <= 3'd0;
            sum_out    <= 32'd0;
            timer_cnt  <= 40'd0;
            add_last   <= 1'b0;
            found1     <= 1'b0;
            found2     <= 1'b0;
            timer_done <= 1'b0;
        end else begin
            // импульсы по умолчанию гаснут через такт
            found1     <= 1'b0;
            found2     <= 1'b0;
            timer_done <= 1'b0;

            case (phase)
                S_SEARCH: begin
                    if (found1) begin            // такт перехода, bit_in не используется
                        phase   <= S_TRAVERSE;
                        gstate  <= 3'd0;
                        sum_out <= 32'd0;
                    end else begin
                        shift_reg <= {shift_reg[6:0], bit_in};
                        // сравниваем уже с учётом только что пришедшего бита
                        if ({shift_reg[6:0], bit_in} == TARGET_BYTE)
                            found1 <= 1'b1;
                    end
                end

                S_TRAVERSE: begin
                    next_g  = next_state(gstate, bit_in);
                    sum_cur = sum_out + state_out(gstate) * gstate;
                    gstate  <= next_g;
                    sum_out <= sum_cur;
                    if (next_g == EXIT_STATE) begin
                        sum_full  = sum_cur + state_out(EXIT_STATE) * EXIT_STATE;
                        found2    <= 1'b1;
                        timer_cnt <= sum_full * TIMER_MULT;
                        add_last  <= 1'b1;
                        phase     <= S_TIMER;
                    end
                end

                S_TIMER: begin
                    // на первом такте таймера добавляем вклад состояния-выхода
                    if (add_last) begin
                        sum_out  <= sum_out + state_out(EXIT_STATE) * EXIT_STATE;
                        add_last <= 1'b0;
                    end
                    if (timer_cnt <= 1) begin
                        timer_done <= 1'b1;
                        phase      <= S_WAIT;
                    end else
                        timer_cnt <= timer_cnt - 1'b1;
                end

                S_WAIT: begin
                    if (done) begin
                        phase     <= S_SEARCH;
                        shift_reg <= 8'd0;
                        gstate    <= 3'd0;
                        sum_out   <= 32'd0;
                    end
                end
            endcase
        end
    end
endmodule