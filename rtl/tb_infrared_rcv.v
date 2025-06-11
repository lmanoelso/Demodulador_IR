`timescale 1ns / 1ps

module tb_infrared_rcv;

    reg sys_clk;
    reg sys_rst_n;
    reg infrared_in;
    wire [19:0] data;
    wire repeat_en;

    infrared_rcv uut (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .infrared_in(infrared_in),
        .data(data),
        .repeat_en(repeat_en)
    );

    // Clock 50 MHz
    always #10 sys_clk = ~sys_clk;

    initial begin
        sys_clk = 1;
        sys_rst_n = 0;
        infrared_in = 1;
        #100;
        sys_rst_n = 1;
        #100;

        // Enviar frame NEC para POWER ON (0x807F)
        send_nec(8'h4D, 8'h80);
        #50_000_000;
        $display("Comando decodificado: %h", data);
        $stop;
    end

    // Task para bit NEC
    task send_bit;
        input value;
        begin
            infrared_in = 0; #560_000;
            infrared_in = 1;
            if (value) #1690_000;
            else       #560_000;
        end
    endtask

    // Task para byte
    task send_byte;
        input [7:0] byte_val;
        integer i;
        begin
            for (i = 0; i < 8; i = i + 1)
                send_bit(byte_val[i]);
        end
    endtask

    // Task para frame NEC
    task send_nec;
        input [7:0] addr;
        input [7:0] cmd;
        reg [7:0] addr_inv, cmd_inv;
        begin
            addr_inv = ~addr;
            cmd_inv = ~cmd;
            // start
            infrared_in = 0; #9000_000;
            infrared_in = 1; #4500_000;
            // dados
            send_byte(addr);
            send_byte(addr_inv);
            send_byte(cmd);
            send_byte(cmd_inv);
            // pulso final
            infrared_in = 0; #560_000;
            infrared_in = 1;
        end
    endtask

endmodule
