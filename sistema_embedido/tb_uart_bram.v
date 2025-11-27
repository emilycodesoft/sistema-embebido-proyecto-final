`timescale 1ns/1ps

module tb_uart_bram();

    // clock
    reg clk = 0;
    always #10 clk = ~clk;   // 50 MHz

    // UART RX line (simula FT232)
    reg rx = 1;  // idle = high

    // señales del UART
    wire data_valid;
    wire [7:0] data_out;
	 wire [2:0]  state;
	 wire        frame_error;

    // BRAM signals
    reg  [18:0] addr_a = 0;   // write address
    wire [7:0]  dout_b;
    reg  [18:0] addr_b = 0;

    // instantiate UART FSM
    uart_rx uut_uart (
        .clk(clk),
        .rx_raw(rx),
        .data_valid(data_valid),
        .data_out(data_out),
		  .state (state),
		  .frame_error(frame_error)
    );

    ram_2port bram (
        .data      (data_out),
        .rdaddress (addr_b),
        .rdclock   (clk),
		  .q         (dout_b),
        
		  .wraddress (addr_a),
        .wrclock   (clk),
        .wren      (data_valid)
        
    );


    // Procedimiento para enviar 1 byte al UART
    task send_byte;
        input [7:0] b;
        integer i;
        begin
            // start bit
            rx = 0;
            #(8680);  // 1 bit @115200 baud ≈ 8680 ns

            // 8 data bits LSB first
            for(i=0;i<8;i=i+1) begin
                rx = b[i];
                #(8680);
            end

            // stop bits (2 bits)
            rx = 1;
            #(2*8680);
        end
    endtask

    initial begin
        $display("---- Iniciando simulación UART + BRAM ----");

        // esperar unos ciclos
        #100000;

        // Enviar byte 0xAB
        send_byte(8'd16);

        // dar tiempo a que la FSM lo procese
        #50000;

        // Como data_valid debe haber sido 1, la direccion 0 debe tener AB
        addr_b = 0;
        #20;
        $display("Dato en BRAM[0] = %d", dout_b);

        // Terminar simulación
        #50000;
        $finish;
    end

endmodule
