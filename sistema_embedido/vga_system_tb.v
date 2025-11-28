`timescale 1ns / 1ps

// ============================================================================
// Testbench para sistema VGA completo
// Prueba: Genera patrón de prueba y verifica señales VGA
// ============================================================================

module vga_system_tb;

    // ========================================================================
    // Señales
    // ========================================================================
    reg         clk_50mhz;
    reg         reset;
    
    wire        clk_25mhz;
    wire        hsync;
    wire        vsync;
    wire [7:0]  vga_r;
    wire [7:0]  vga_g;
    wire [7:0]  vga_b;
    
    // ========================================================================
    // Parámetros
    // ========================================================================
    localparam CLK_PERIOD = 20;  // 50 MHz
    
    // Contadores para verificación
    integer frame_count = 0;
    integer hsync_count = 0;
    integer pixel_count = 0;
    
    // ========================================================================
    // Clock divider para 25 MHz
    // ========================================================================
    clk_divider clk_div (
        .clk_50mhz  (clk_50mhz),
        .reset      (reset),
        .clk_25mhz  (clk_25mhz)
    );
    
    // ========================================================================
    // VGA Controller
    // ========================================================================
    wire [9:0]  hcount;
    wire [9:0]  vcount;
    wire        display_enable;
    
    vga_controller vga_ctrl (
        .clk_25mhz      (clk_25mhz),
        .reset          (reset),
        .hsync          (hsync),
        .vsync          (vsync),
        .display_enable (display_enable),
        .hcount         (hcount),
        .vcount         (vcount)
    );
    
    // ========================================================================
    // Generador de patrón de prueba (en lugar de BRAM)
    // ========================================================================
    reg [7:0] test_pattern;
    
    always @(*) begin
        if (display_enable) begin
            // Patrón de barras de colores verticales
            if (hcount < 80)
                test_pattern = 8'b00000111;      // Blanco (RGB=111)
            else if (hcount < 160)
                test_pattern = 8'b00000110;      // Amarillo (RG=11, B=0)
            else if (hcount < 240)
                test_pattern = 8'b00000011;      // Cian (GB=11, R=0)
            else if (hcount < 320)
                test_pattern = 8'b00000010;      // Verde (G=1)
            else if (hcount < 400)
                test_pattern = 8'b00000101;      // Magenta (RB=11, G=0)
            else if (hcount < 480)
                test_pattern = 8'b00000100;      // Rojo (R=1)
            else if (hcount < 560)
                test_pattern = 8'b00000001;      // Azul (B=1)
            else
                test_pattern = 8'b00000000;      // Negro
        end else begin
            test_pattern = 8'b00000000;
        end
    end
    
    // Extraer bits RGB
    wire bit_r = test_pattern[2];
    wire bit_g = test_pattern[1];
    wire bit_b = test_pattern[0];
    
    // Expandir a 8 bits
    assign vga_r = display_enable ? {8{bit_r}} : 8'h00;
    assign vga_g = display_enable ? {8{bit_g}} : 8'h00;
    assign vga_b = display_enable ? {8{bit_b}} : 8'h00;
    
    // ========================================================================
    // Generador de reloj 50 MHz
    // ========================================================================
    initial begin
        clk_50mhz = 0;
        forever #(CLK_PERIOD/2) clk_50mhz = ~clk_50mhz;
    end
    
    // ========================================================================
    // Detectar eventos VGA
    // ========================================================================
    reg hsync_prev = 1;
    reg vsync_prev = 1;
    
    always @(posedge clk_25mhz or posedge reset) begin
        hsync_prev <= hsync;
        vsync_prev <= vsync;
        
        // Detectar inicio de linea (flanco de bajada de hsync)
        if (hsync_prev && !hsync) begin
            hsync_count <= hsync_count + 1;
            if (hsync_count % 100 == 0)
                $display("[%0d] Linea %0d completada", $time, hsync_count);
        end
        
        // Detectar inicio de frame (flanco de bajada de vsync)
        if (vsync_prev && !vsync) begin
            frame_count <= frame_count + 1;
            $display("\n[%0d] ========================================", $time);
            $display("[%0d] FRAME %0d COMPLETADO", $time, frame_count);
            $display("[%0d] Total lineas: %0d", $time, hsync_count);
            $display("[%0d] ========================================\n", $time);
            hsync_count <= 0;
        end
        
        // Contar pixeles visibles
        if (display_enable) begin
            pixel_count <= pixel_count + 1;
        end
    end
    
    // ========================================================================
    // Estimulos de prueba
    // ========================================================================
    initial begin
        reset = 1;
        
        $display("========================================");
        $display("TESTBENCH: Sistema VGA");
        $display("========================================");
        $display("Resolucion: 640x480 @ 60Hz");
        $display("Pixel clock: 25 MHz");
        $display("========================================\n");
        
        #1000;
        reset = 0;

        $display("Reset desactivado - Iniciando generacion VGA\n");

        // Simular 3 frames completos
        // 1 frame @ 60Hz = 16.67 ms
        // 3 frames = ~50 ms = 50,000,000 ns
        #50_000_000;
        
        $display("\n========================================");
        $display("RESULTADOS FINALES");
        $display("========================================");
        $display("Frames generados:     %0d", frame_count);
        $display("Lineas por frame:     ~480 (esperado)");
        $display("Pixeles visibles:     %0d", pixel_count);
        $display("Pixeles esperados:    %0d", 640 * 480 * frame_count);
        
        if (frame_count >= 2) begin
            $display("\n PRUEBA EXITOSA");
        end else begin
            $display("\n PRUEBA FALLIDA");
        end
        
        $display("========================================\n");
        
        $finish;
    end
    
    // ========================================================================
    // Monitor de señales RGB durante área visible
    // ========================================================================
    always @(posedge clk_25mhz) begin
        // Mostrar primeros pixeles de la primera linea
        if (display_enable && vcount == 0 && hcount < 10) begin
            $display("[%0d] Pixel(%0d,%0d): R=%02h G=%02h B=%02h Pattern=%03b", 
                     $time, hcount, vcount, vga_r, vga_g, vga_b, test_pattern[2:0]);
        end
    end
    
	 
    // ========================================================================
    // Verificación de timing VGA
    // ========================================================================
	 real frame_start;
		real frame_end;
		real frame_time;
		real frame_freq;
    initial begin
        #1000;
        
        // Esperar primer vsync
        @(negedge vsync);
        
        // Medir tiempo de un frame
        frame_start = $realtime;
        @(negedge vsync);
        frame_end = $realtime;
        
        frame_time = (frame_end - frame_start) / 1000.0;  // en us
        frame_freq = 1000000.0 / frame_time;  // en Hz
        
        $display("\n--- Verificacion de Timing ---");
        $display("Tiempo por frame: %.2f µs", frame_time);
        $display("Frecuencia:       %.2f Hz (esperado: ~60Hz)", frame_freq);
        
        if (frame_freq >= 59.0 && frame_freq <= 61.0) begin
            $display("Timing correcto\n");
        end else begin
            $display("Timing incorrecto\n");
        end
    end
    
    // ========================================================================
    // Timeout de seguridad
    // ========================================================================
    initial begin
        #100_000_000;  // 100 ms
        $display("\nTIMEOUT - Simulacion detenida");
        $finish;
    end
    
    // ========================================================================
    // Generar VCD para GTKWave
    // ========================================================================
    initial begin
        $dumpfile("vga_system_tb.vcd");
        $dumpvars(0, vga_system_tb);
    end

endmodule