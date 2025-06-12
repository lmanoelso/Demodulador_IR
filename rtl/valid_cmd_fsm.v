// Máquina de estados para gerar pulso ir_valid em Verilog 2001
// Gera um pulso de ir_valid quando o dado IR muda ou repeat_en sobe de 0 para 1

module ir_valid_fsm (
    input wire clk,
    input wire rst_n,
    input wire [19:0] ir_data,
    input wire repeat_en,
    output reg ir_valid
);

    // Armazena o último valor recebido
    reg [19:0] last_ir_data;
    reg        last_repeat_en;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ir_valid        <= 1'b0;
            last_ir_data    <= 20'd0;
            last_repeat_en  <= 1'b0;
        end else begin
            // Gera pulso se o comando mudou ou repeat_en subiu
            if ((ir_data != last_ir_data) || (repeat_en && !last_repeat_en))
                ir_valid <= 1'b1;
            else
                ir_valid <= 1'b0;

            // Atualiza históricos
            last_ir_data   <= ir_data;
            last_repeat_en <= repeat_en;
        end
    end

endmodule


`timescale 1ns/1ps

module tb_ir_valid_fsm;

    reg clk;
    reg rst_n;
    reg [19:0] ir_data;
    reg repeat_en;
    wire ir_valid;

    // Instancia o módulo sob teste
    ir_valid_fsm dut (
        .clk(clk),
        .rst_n(rst_n),
        .ir_data(ir_data),
        .repeat_en(repeat_en),
        .ir_valid(ir_valid)
    );

    // Clock de 10ns (100MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $display("Início do Teste - FSM ir_valid");
        $monitor("Tempo: %0t | ir_data = 0x%05X | repeat_en = %b | ir_valid = %b", $time, ir_data, repeat_en, ir_valid);

        // Reset
        rst_n = 0;
        ir_data = 20'h00000;
        repeat_en = 0;
        #20;
        rst_n = 1;

        // Envio de um dado válido
        #10;
        ir_data = 20'hABCDE;
        repeat_en = 0;  // novo comando
        #20;

        // Espera até que ir_valid vá para 0
        #40;

        // Reenvio do mesmo dado com repeat_en = 1
        repeat_en = 1;
        #20;

        // Envia novo dado
        ir_data = 20'h12345;
        repeat_en = 0;
        #20;

        // Espera
        #100;

        $finish;
    end

endmodule
