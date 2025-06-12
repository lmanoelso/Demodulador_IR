// Módulo de exibição serial com 74HC164 para 4 displays de 7 segmentos
// Cada dígito BCD (4 bits) é convertido em 7 segmentos, e serializado bit a bit

module serial_display_74hc164 (
    input wire clk,                // Clock do sistema
    input wire rst_n,             // Reset ativo baixo
    input wire [15:0] bcd_data,   // 4 dígitos BCD (MSB à esquerda)
    output reg ser,               // Saída de dados para 74HC164
    output reg clk_out            // Pulso de clock serial

    
);

    // Tabela de conversão BCD para 7 segmentos
    function [6:0] bcd_to_seg;
        input [3:0] bcd;
        case (bcd)
            4'd0:  bcd_to_seg = 7'b0111111;
            4'd1:  bcd_to_seg = 7'b0000110;
            4'd2:  bcd_to_seg = 7'b1011011;
            4'd3:  bcd_to_seg = 7'b1001111;
            4'd4:  bcd_to_seg = 7'b1100110;
            4'd5:  bcd_to_seg = 7'b1101101;
            4'd6:  bcd_to_seg = 7'b1111101;
            4'd7:  bcd_to_seg = 7'b0000111;
            4'd8:  bcd_to_seg = 7'b1111111;
            4'd9:  bcd_to_seg = 7'b1101111;
            4'd10: bcd_to_seg = 7'b1110111; // A
            4'd11: bcd_to_seg = 7'b1111100; // b
            4'd12: bcd_to_seg = 7'b0111001; // C
            4'd13: bcd_to_seg = 7'b1110110; // H
            4'd14: bcd_to_seg = 7'b1110000; // V
            4'd15: bcd_to_seg = 7'b1111001; // F
            default: bcd_to_seg = 7'b0000000;
        endcase
    endfunction

    reg [27:0] shift_data;     // 4 x 7 segmentos = 28 bits
    reg [4:0] bit_cnt;         // Contador de bits
    reg [15:0] bcd_latch;      // Latched input
    reg [15:0] clk_div;        // Divisor de clock

    wire tick = (clk_div == 16'd0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div <= 0;
        end else begin
            clk_div <= clk_div + 1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt <= 0;
            shift_data <= 0;
            bcd_latch <= 0;
            ser <= 0;
            clk_out <= 0;
        end else if (tick) begin
            if (bit_cnt == 0) begin
                // Latch entrada BCD e monta shift_data com 7 segmentos
                bcd_latch <= bcd_data;
                shift_data <= {
                    bcd_to_seg(bcd_data[15:12]),
                    bcd_to_seg(bcd_data[11:8]),
                    bcd_to_seg(bcd_data[7:4]),
                    bcd_to_seg(bcd_data[3:0])
                };
                bit_cnt <= 28;
            end else begin
                ser <= shift_data[27];
                shift_data <= {shift_data[26:0], 1'b0};
                bit_cnt <= bit_cnt - 1;
            end

            clk_out <= ~clk_out; // Gera pulso de clock
        end
    end

endmodule


// Testbench para o modulo serial_display_74hc164

`timescale 1ns/1ps

module tb_serial_display_74hc164;

    reg clk;
    reg rst_n;
    reg [15:0] bcd_data;
    wire ser;
    wire clk_out;

    // Instancia o DUT
    serial_display_74hc164 dut (
        .clk(clk),
        .rst_n(rst_n),
        .bcd_data(bcd_data),
        .ser(ser),
        .clk_out(clk_out)
    );

    // Clock 10ns (100 MHz)
    always #5 clk = ~clk;

    // Inicialização
    initial begin
        $display("=== Teste do Display Serial 74HC164 ===");
        clk = 0;
        rst_n = 0;
        bcd_data = 16'h0000;
        #50;
        rst_n = 1;

        // Teste 1: Mostrar "C012"
        bcd_data = {4'd12, 4'd0, 4'd1, 4'd2};
        $display("Tempo: %0t | Enviando: C012", $time);
        #3000;

        // Teste 2: Mostrar "V050"
        bcd_data = {4'd14, 4'd0, 4'd5, 4'd0};
        $display("Tempo: %0t | Enviando: V050", $time);
        #3000;

        // Teste 3: Mostrar "H1A5"
        bcd_data = {4'd13, 4'd1, 4'd10, 4'd5};
        $display("Tempo: %0t | Enviando: H1A5", $time);
        #3000;

        // Teste 4: Mostrar "C064"
        bcd_data = {4'd12, 4'd0, 4'd6, 4'd4};
        $display("Tempo: %0t | Enviando: C064", $time);
        #3000;

        $display("=== Fim do Teste ===");
        $stop;
    end

endmodule
