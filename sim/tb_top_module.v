`timescale 1ns / 1ps

module tb_top_module;

    // Inputs
    reg sys_clk;
    reg sys_rst_n;
    reg infrared_in;

    // Outputs
    wire [5:0] sel;
    wire [7:0] seg;
    wire led;

    // Instantiate the Unit Under Test (UUT)
    top_module uut (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .infrared_in(infrared_in),
        .sel(sel),
        .seg(seg),
        .led(led)
    );

    // Clock 50 MHz
    always #10 sys_clk = ~sys_clk;

    // Task para enviar bit 0 (pulso base + intervalo base)
    task send_bit_0;
    begin
        infrared_in <= 0; #562_500;
        infrared_in <= 1; #562_500;
    end
    endtask

    // Task para enviar bit 1 (pulso base + 3× intervalo base)
    task send_bit_1;
    begin
        infrared_in <= 0; #562_500;
        infrared_in <= 1; #1_687_500;
    end
    endtask

    // Task para enviar 8 bits (LSB-first)
    task send_byte(input [7:0] byte_data);
        integer i;
    begin
        for (i = 0; i < 8; i = i + 1) begin
            if (byte_data[i] == 1'b0)
                send_bit_0;
            else
                send_bit_1;
        end
    end
    endtask

    // Task para enviar START code (9ms LOW + 4.5ms HIGH)
    task send_start;
    begin
        infrared_in <= 0; #9_000_000;
        infrared_in <= 1; #4_500_000;
    end
    endtask

    // Task para enviar REPEAT code (9ms LOW + 2.25ms HIGH)
    task send_repeat;
    begin
        infrared_in <= 0; #9_000_000;
        infrared_in <= 1; #2_250_000;
    end
    endtask

    // Sequência principal de estímulo
    initial begin
        // Inicialização
        sys_clk      = 1;
        sys_rst_n    = 0;
        infrared_in  = 1;
        #100;
        sys_rst_n    = 1;

        // Espera para estabilização
        #1_000;

        // Enviar START
        send_start;

        // Exemplo: Enviar código NEC de 32 bits
        // Address = 0x99, ~Address = 0x66
        // Command = 0x22, ~Command = 0xDD
        // Formato: [Address][~Address][Command][~Command]
        send_byte(8'h99); // Address
        send_byte(~8'h99); // ~Address
        send_byte(8'h22); // Command
        send_byte(~8'h22); // ~Command

        // Espera após envio do pacote
        #50_000;

        // Enviar código de repetição
        send_repeat;

        // Finalizar simulação
        #10_000;
        $finish;
    end

endmodule
