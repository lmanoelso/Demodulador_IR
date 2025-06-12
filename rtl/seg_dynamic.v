// shift_display_driver.v
// Controla o envio serial para o 74HC164 com dados vindos de seg_dynamic

module shift_display_driver (
    input wire clk,             // clock do sistema
    input wire rst_n,          // reset ativo baixo
    input wire [7:0] seg_data, // dado a ser exibido (7 segmentos)
    input wire [3:0] digit_sel,// dígito ativo (0-3)
    input wire start,          // inicia transmissão serial
    output reg sr_clk,         // clock serial para o 74HC164
    output reg sr_data,        // dado serial (bit a bit)
    output reg [3:0] digit_enable, // ativação do dígito correspondente
    output reg busy            // sinaliza transmissão em andamento
);

    reg [3:0] bit_cnt;
    reg [7:0] shift_reg;
    reg [3:0] state;

    parameter IDLE = 4'd0;
    parameter LOAD = 4'd1;
    parameter SHIFT = 4'd2;
    parameter HOLD = 4'd3;

    reg [7:0] clk_cnt;
    parameter CLK_DIV = 1315; // para 38kHz a partir de 50MHz
    reg clk_38khz;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt <= 0;
            clk_38khz <= 0;
        end else if (clk_cnt >= CLK_DIV/2) begin
            clk_cnt <= 0;
            clk_38khz <= ~clk_38khz;
        end else begin
            clk_cnt <= clk_cnt + 1;
        end
    end

    always @(posedge clk_38khz or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sr_clk <= 0;
            sr_data <= 0;
            busy <= 0;
            bit_cnt <= 0;
            digit_enable <= 4'b0000;
        end else begin
            case (state)
                IDLE: begin
                    sr_clk <= 0;
                    sr_data <= 0;
                    busy <= 0;
                    if (start) begin
                        shift_reg <= seg_data;
                        bit_cnt <= 0;
                        busy <= 1;
                        state <= SHIFT;
                    end
                end

                SHIFT: begin
                    if (bit_cnt < 8) begin
                        sr_data <= shift_reg[7];
                        shift_reg <= shift_reg << 1;
                        sr_clk <= 1;
                        bit_cnt <= bit_cnt + 1;
                    end else begin
                        sr_clk <= 0;
                        state <= HOLD;
                        digit_enable <= (4'b0001 << digit_sel);
                    end
                end

                HOLD: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule

// Testbench para shift_display_driver

`timescale 1ns/100ps

module tb_shift_display_driver;
    reg clk;
    reg rst_n;
    reg [7:0] seg_data;
    reg [3:0] digit_sel;
    reg start;
    wire sr_clk;
    wire sr_data;
    wire [3:0] digit_enable;
    wire busy;

    // Instância do módulo
    shift_display_driver uut (
        .clk(clk),
        .rst_n(rst_n),
        .seg_data(seg_data),
        .digit_sel(digit_sel),
        .start(start),
        .sr_clk(sr_clk),
        .sr_data(sr_data),
        .digit_enable(digit_enable),
        .busy(busy)
    );

    // Clock 50 MHz
    always #10 clk = ~clk;

    initial begin
        $display("Inicio da simulação");

        clk = 0;
        rst_n = 0;
        seg_data = 8'hC0;  // número 0 nos 7 segmentos comuns
        digit_sel = 0;
        start = 0;

        #100;
        rst_n = 1;

        // Simula exibição sequencial de 0 a 3
        repeat (4) begin
            @(posedge clk);
            seg_data = seg_data + 8'h01; // próxima codificação (simulada)
            digit_sel = digit_sel + 1;
            start = 1;
            @(posedge clk);
            start = 0;
            // espera até busy ser 0
            wait (!busy);
        end

        $display("Fim da simulação");
        $stop;
    end
endmodule
