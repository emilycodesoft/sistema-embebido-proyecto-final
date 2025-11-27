`timescale 1ns/1ps

module vga_controller_tb;

    // Señales del testbench
    reg clk;
    reg rst;
    wire h_sync;
    wire v_sync;
    wire [2:0] red;
    wire [2:0] green;
    wire [1:0] blue;
    wire [9:0] x_pos;
    wire [9:0] y_pos;

    // Instancia del DUT (Device Under Test)
    vga_controller uut (
        .clk_25mhz(clk),
        .rst(rst),
        .h_sync(h_sync),
        .v_sync(v_sync),
        .red(red),
        .green(green),
        .blue(blue),
        .x_pos(x_pos),
        .y_pos(y_pos)
    );

    // Generación del reloj de 25 MHz (período de 40 ns)
    initial clk = 0;
    always #20 clk = ~clk;  // 25 MHz
	 
	 integer file;
    integer r8, g8, b8;
	 
	 always @(posedge clk) begin
			 if (uut.y_pos < 5 && uut.x_pos % 80 == 0) begin
				  $display("x=%d | R=%b G=%b B=%b", uut.x_pos, uut.red, uut.green, uut.blue);
			 end
	 end

    // Secuencia de reset y simulación
    initial begin
        rst = 1;
        #100;
        rst = 0;
		  
		  // Abrir el archivo PPM
        file = $fopen("vga_output.ppm", "w");
        $fwrite(file, "P3\n");
        $fwrite(file, "640 480\n");
        $fwrite(file, "255\n");
		  
		  // Capturar toda la imagen visible
        // Esperar a que comience el frame (x_pos=0, y_pos=0)
        wait (x_pos == 0 && y_pos == 0);

        forever begin
            @(posedge clk);

            if (y_pos < 480 && x_pos < 640) begin
                // Escalar a 8 bits
                r8 = red   * 36; // 3 bits -> 0–255 aprox
                g8 = green * 36;
                b8 = blue  * 85; // 2 bits -> 0–255 aprox

                $fwrite(file, "%0d %0d %0d\n", r8, g8, b8);
            end

            if (y_pos == 479 && x_pos == 639) begin
                $display("Frame completo guardado.");
                $fclose(file);
                $stop;
            end
        end
        
        // Simular unas cuantas líneas y cuadros
        #17000000;  // Simula un tiempo suficiente (~17ms)
        $stop;
    end

endmodule
