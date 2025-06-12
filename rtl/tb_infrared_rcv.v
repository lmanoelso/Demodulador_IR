`timescale 1ns / 1ps

module tb_infrared_rcv;

    reg sys_clk;
    reg sys_rst_n;
    reg infrared_in;
    wire [19:0] data;
    wire repeat_en;
    wire data_valid;

    infrared_rcv uut (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .infrared_in(infrared_in),
        .data(data),
        .repeat_en(repeat_en),
        .data_valid(data_valid)
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

        send_nec(8'h4D, 8'h80); // POWER ON
        #50_000;
        send_nec(8'h4D, 8'h38); // CH-
        #50_000;
        send_nec(8'h4D, 8'h18); // CH+
        #50_000;
        send_nec(8'h4D, 8'h08); // VOL-
        #50_000;
        send_nec(8'h4D, 8'h30); // VOL+
        #50_000;

        $display("\nFim da simulação.");
        $finish;
    end

    // Task para bit NEC
    task send_bit;
        input value;
        begin
            infrared_in = 0; #560;
            infrared_in = 1;
            if (value) #1690;
            else       #560;
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
            infrared_in = 0; #9000;
            infrared_in = 1; #4500;
            // dados
            send_byte(addr);
            send_byte(addr_inv);
            send_byte(cmd);
            send_byte(cmd_inv);
            // pulso final
            infrared_in = 0; #560;
            infrared_in = 1;
        end
    endtask

endmodule
