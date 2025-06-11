`timescale 1ns / 1ps

module tb_top_module;

    // Entradas
    reg sys_clk;
    reg sys_rst_n;
    reg infrared_in;

    // Saídas
    wire [5:0] sel;
    wire [7:0] seg;
    wire led;

    // Instância do módulo principal (DUT)
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

    initial begin
        // Inicializações
        sys_clk     = 1'b1;
        sys_rst_n   = 1'b0;
        infrared_in = 1'b1;

        #100;
        sys_rst_n = 1'b1;
        #100;

        // Enviar comandos NEC
        send_nec("POWER", 8'h4D, 8'h80); // POWER ON/OFF
        send_nec("CH-",   8'h4D, 8'h38);
        send_nec("CH+",   8'h4D, 8'h18);
        send_nec("VOL-",  8'h4D, 8'h08);
        send_nec("VOL+",  8'h4D, 8'h30);
        send_nec("MENU",  8'h4D, 8'h50);
        send_nec("NUM 1", 8'h4D, 8'hA8);
        send_nec("NUM 2", 8'h4D, 8'h68);
        send_nec("NUM 3", 8'h4D, 8'hE8);

        // Espera final para observar comportamento
        #100_000_000;
        $stop;
    end

    // Task para enviar um bit (0 ou 1) no padrão NEC
    task send_bit;
        input value;
        begin
            infrared_in = 0; #560_000;
            infrared_in = 1;
            if (value)
                #1690_000;
            else
                #560_000;
        end
    endtask

    // Task para enviar um byte (8 bits, LSB-first)
    task send_byte;
        input [7:0] byte_val;
        integer i;
        begin
            for (i = 0; i < 8; i = i + 1)
                send_bit(byte_val[i]);
        end
    endtask

    // Task principal para enviar um frame NEC completo
    task send_nec;
        input [160*8:0] label;  // Nome do comando
        input [7:0] addr;
        input [7:0] cmd;
        reg [7:0] addr_inv, cmd_inv;
        begin
            addr_inv = ~addr;
            cmd_inv  = ~cmd;

            $display("== Comando: %s ==", label);
            $display("   ADDR = 0x%02X, CMD = 0x%02X", addr, cmd);

            // Pulso de início (START NEC)
            infrared_in = 0; #9000_000;
            infrared_in = 1; #4500_000;

            // Enviar dados
            send_byte(addr);
            send_byte(addr_inv);
            send_byte(cmd);
            send_byte(cmd_inv);

            // Pulso final
            infrared_in = 0; #560_000;
            infrared_in = 1;

            // Espera para o sistema processar
            #40_000_000;

            $display("   LED  = %b", led);
            $display("   SEL  = %b", sel);
            $display("   SEG  = %b\n", seg);
        end
    endtask

endmodule
