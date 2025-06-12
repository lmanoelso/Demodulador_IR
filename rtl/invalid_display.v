// Verilog 2001
// Módulo para exibir comandos IR inválidos (não reconhecidos)

module invalid_cmd_display (
    input wire clk,
    input wire rst_n,
    input wire [7:0] ir_cmd,
    input wire ir_valid,
    output reg [19:0] display_data,
    output reg show_invalid
);

    // Códigos reconhecidos
    localparam CMD_POWER     = 8'h45;
    localparam CMD_CH_PLUS   = 8'h18;
    localparam CMD_CH_MINUS  = 8'h52;
    localparam CMD_VOL_PLUS  = 8'h16;
    localparam CMD_VOL_MINUS = 8'h19;

    // Tempo de exibição: 5 segundos (ajustado para simulação)
    parameter TIMEOUT_CYCLES = 250_000_000; // 5s @ 50 MHz

    reg [31:0] timer;
    reg active;
    reg [7:0] last_cmd;

    // Verifica se o comando é válido
    wire is_known_cmd = (ir_cmd == CMD_POWER) | (ir_cmd == CMD_CH_PLUS) |
                        (ir_cmd == CMD_CH_MINUS) | (ir_cmd == CMD_VOL_PLUS) |
                        (ir_cmd == CMD_VOL_MINUS);

    // FSM para controle da exibição
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            display_data <= 20'd0;
            timer <= 32'd0;
            active <= 1'b0;
            show_invalid <= 1'b0;
        end else begin
            if (ir_valid && !is_known_cmd) begin
                // Novo comando inválido recebido
                last_cmd <= ir_cmd;
                display_data <= {4'd0, 4'd0, 4'd15, ir_cmd[7:4], ir_cmd[3:0]}; // FXYX
                timer <= TIMEOUT_CYCLES;
                active <= 1'b1;
                show_invalid <= 1'b1;
            end else if (active) begin
                if (timer > 0)
                    timer <= timer - 1;
                else begin
                    active <= 1'b0;
                    show_invalid <= 1'b0;
                    display_data <= 20'd0;
                end
            end
        end
    end

endmodule


// Testbench para invalid_cmd_display - Testando múltiplos comandos inválidos
`timescale 1ns / 1ps

module tb_invalid_cmd_display;

    reg clk;
    reg rst_n;
    reg [7:0] ir_cmd;
    reg ir_valid;

    wire show_invalid;
    wire [19:0] display_data;

    // Instancia o módulo
    invalid_cmd_display dut (
        .clk(clk),
        .rst_n(rst_n),
        .ir_cmd(ir_cmd),
        .ir_valid(ir_valid),
        .show_invalid(show_invalid),
        .display_data(display_data)
    );

    // Clock 50MHz
    initial clk = 0;
    always #10 clk = ~clk;

    // Envia comando e espera curta
    task send_invalid_cmd;
        input [7:0] cmd;
        begin
            ir_cmd = cmd;
            ir_valid = 1;
            #20;
            ir_valid = 0;
            $display("[%0t] Comando inválido enviado: 0x%02h", $time, cmd);
            repeat (1000) begin
                #20;
                if (show_invalid) begin
                    $display("Tempo: %0t | Show_Invalid = %b | Display = %h", $time, show_invalid, display_data);
                end
            end
        end
    endtask

    initial begin
        $display("=== Teste de Múltiplos Comandos Inválidos ===");
        clk = 0;
        rst_n = 0;
        ir_cmd = 8'h00;
        ir_valid = 0;
        #100;

        rst_n = 1;
        #100;

        send_invalid_cmd(8'h82);
        send_invalid_cmd(8'h20);
        send_invalid_cmd(8'hA0);
        send_invalid_cmd(8'h98);

        $display("=== Fim do Teste ===");
        $stop;
    end

endmodule
