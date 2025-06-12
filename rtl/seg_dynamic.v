// canal_display_ctrl.v
// Controla o display de canal quando o sistema está ligado

module canal_display_ctrl (
    input wire clk,
    input wire rst_n,
    input wire power_on,
    input wire [6:0] canal, // de 1 a 64
    output wire sr_clk,
    output wire sr_data,
    output wire [3:0] digit_enable
);

    reg [1:0] digito_idx;
    reg [7:0] seg_data;
    reg [3:0] digit_sel;
    reg start;
    wire busy;

    // BCD para os dígitos do canal
    reg [3:0] dezena, unidade;
    wire [7:0] seg_dezena, seg_unidade;

    // Atualiza dígitos BCD
    always @(*) begin
        dezena  = (canal / 10) % 10;
        unidade = canal % 10;
    end

    // Conversores para 7 segmentos
    bin_to_7seg conv_dez (
        .bin(dezena),
        .seg(seg_dezena)
    );

    bin_to_7seg conv_uni (
        .bin(unidade),
        .seg(seg_unidade)
    );

    // Controle do multiplexador (contagem 0 a 3)
    reg [15:0] mux_cnt;
    parameter MUX_MAX = 50_000; // 1ms @ 50MHz

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            mux_cnt <= 0;
        else if (mux_cnt >= MUX_MAX)
            mux_cnt <= 0;
        else
            mux_cnt <= mux_cnt + 1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            digito_idx <= 0;
        else if (mux_cnt == MUX_MAX)
            digito_idx <= digito_idx + 1;
    end

    // Multiplexa os dígitos com base no estado e power_on
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            seg_data <= 8'hFF;
            digit_sel <= 0;
            start <= 0;
        end else if (mux_cnt == MUX_MAX && !busy) begin
            if (!power_on) begin
                seg_data <= 8'hFF;
                digit_sel <= digito_idx;
                start <= 1;
            end else begin
                case (digito_idx)
                    2'd0: begin seg_data <= 8'b1000_0110; digit_sel <= 0; end // C
                    2'd1: begin seg_data <= 8'hFF; digit_sel <= 1; end       // em branco
                    2'd2: begin seg_data <= seg_dezena; digit_sel <= 2; end
                    2'd3: begin seg_data <= seg_unidade; digit_sel <= 3; end
                endcase
                start <= 1;
            end
        end else begin
            start <= 0;
        end
    end

    // Instância do driver de shift register
    shift_display_driver driver (
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

endmodule

// Testbench para canal_display_ctrl

`timescale 1ns/1ps

module tb_canal_display_ctrl;
    reg clk;
    reg rst_n;
    reg power_on;
    reg [6:0] canal;

    wire sr_clk;
    wire sr_data;
    wire [3:0] digit_enable;

    canal_display_ctrl uut (
        .clk(clk),
        .rst_n(rst_n),
        .power_on(power_on),
        .canal(canal),
        .sr_clk(sr_clk),
        .sr_data(sr_data),
        .digit_enable(digit_enable)
    );

    // Clock de 50 MHz
    always #10 clk = ~clk;

    initial begin
        $display("Iniciando Testbench do canal_display_ctrl");

        clk = 0;
        rst_n = 0;
        canal = 7'd1;
        power_on = 0;

        #100;
        rst_n = 1;
        #100;

        power_on = 1; // Liga o sistema

        // Testa todos os 64 canais
        repeat (64) begin
            @(posedge clk);
            canal = canal + 1;
            #200000; // Espera para exibir o canal (4 ciclos de 1ms + margem)
        end

        power_on = 0; // volta para standby
        #500_000;

        $display("Finalizando Testbench");
        $stop;
    end
endmodule