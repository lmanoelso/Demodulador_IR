module led_status_ctrl (
    input wire clk,
    input wire rst_n,
    input wire [7:0] ir_cmd,
    input wire ir_valid,       // Pulso que indica comando IR recebido
    output reg led             // 1 = LED aceso (standby), 0 = apagado (ligado)
);

    // Definição dos estados
    parameter STANDBY  = 2'b00;
    parameter LIGADO   = 2'b01;

    reg [1:0] state;
    reg [1:0] next_state;

    // Máquina de estados: transição de estado
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= STANDBY;
        else
            state <= next_state;
    end

    // Lógica de transição
    always @(*) begin
        case (state)
            STANDBY: begin
                if (ir_valid && ir_cmd == 8'h80)  // Comando POWER ON
                    next_state = LIGADO;
                else
                    next_state = STANDBY;
            end

            LIGADO: begin
                if (ir_valid && ir_cmd == 8'h80)  // Comando POWER OFF
                    next_state = STANDBY;
                else
                    next_state = LIGADO;  // Ligado
            end

            default: next_state = STANDBY;
        endcase
    end

    // Saída LED: 1 = standby (ligado), 0 = ligado (apagado)
    always @(*) begin
        case (state)
            STANDBY: led = 1'b1;
            LIGADO:  led = 1'b0;
            default: led = 1'b1;
        endcase
    end

endmodule

`timescale 1ns / 1ps

module tb_led_status_ctrl;

    // Entradas
    reg clk;
    reg rst_n;
    reg [7:0] ir_cmd;
    reg ir_valid;

    // Saída
    wire led;

    // Instância do módulo testado
    led_status_ctrl uut (
        .clk(clk),
        .rst_n(rst_n),
        .ir_cmd(ir_cmd),
        .ir_valid(ir_valid),
        .led(led)
    );

/*    `timescale 1ns / 100ps

    // Geração de clock (100MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $display("Início do Teste - LED Standby");

        // Inicialização
        rst_n = 0;
        ir_cmd = 8'h00;
        ir_valid = 0;

        #20;
        rst_n = 1; // Libera reset

        #20;
        $display("LED após reset = %b (esperado: 1)", led);

        // Simula comando aleatório (não é POWER ON)
        ir_cmd = 8'h1F;
        ir_valid = 1;
        #10;
        ir_valid = 0;

        #20;
        $display("LED após comando inválido = %b (esperado: 1)", led);

        // Simula comando POWER ON 
        ir_cmd = 8'h80;
        ir_valid = 1;
        #10;
        ir_valid = 0;

        #20;
        $display("LED após POWER ON = %b (esperado: 0)", led);

        // Simula novo comando após POWER ON (deve permanecer apagado)
        ir_cmd = 8'h12;
        ir_valid = 1;
        #10;
        ir_valid = 0;

        #20;
        $display("LED após outro comando = %b (esperado: 0)", led);

        // Simula novo comando após POWER ON (deve permanecer apagado)
        ir_cmd = 8'h80;
        ir_valid = 1;
        #10;
        ir_valid = 0;

        #20;
        $display("LED após outro comando = %b (esperado: 0)", led);
        // Aplica reset
        rst_n = 0;
        #20;
        rst_n = 1;

        #20;
        $display("LED após novo reset = %b (esperado: 1)", led);

        $finish;
    end

endmodule
    */
