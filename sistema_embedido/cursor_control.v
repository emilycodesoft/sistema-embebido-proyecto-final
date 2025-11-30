// ============================================================================
// Módulo: cursor_control
// Descripción: Control de cursor con botones y escritura en BRAM
// ============================================================================

module cursor_control (
    input  wire        clk,              // Reloj 50 MHz
    input  wire        reset,            // Reset síncrono
    
    // Botones (activos en bajo)
    input  wire [3:0]  KEY,              // KEY[0]=arriba, [1]=abajo, [2]=izq, [3]=der
    
    // Interruptores
    input  wire [3:0]  SW,               // SW[0]=enable modificar, SW[3:1]=color RGB
    
    // Posición del cursor (salida para VGA)
    output reg  [9:0]  cursor_x,         // Posición X (0-639)
    output reg  [9:0]  cursor_y,         // Posición Y (0-479)
    
    // Señales para escritura en BRAM
    output reg         cursor_write_en,  // Habilita escritura
    output wire [18:0] cursor_addr,      // Dirección en BRAM
    output wire [7:0]  cursor_data       // Dato a escribir (color RGB en 3 bits)
);

    // ========================================================================
    // Parámetros de límites de pantalla
    // ========================================================================
    localparam H_MAX = 639;  // Ancho máximo (640 píxeles)
    localparam V_MAX = 479;  // Alto máximo (480 píxeles)
    
    // ========================================================================
    // Sincronización de botones (2 etapas)
    // ========================================================================
    reg [3:0] key_sync1 = 4'b1111;
    reg [3:0] key_sync2 = 4'b1111;
    
    always @(posedge clk) begin
        if (reset) begin
            key_sync1 <= 4'b1111;
            key_sync2 <= 4'b1111;
        end else begin
            key_sync1 <= KEY;
            key_sync2 <= key_sync1;
        end
    end
    
    // ========================================================================
    // Detector de flancos de bajada (botón presionado)
    // ========================================================================
    reg [3:0] key_prev = 4'b1111;
    wire [3:0] key_press;  // Pulso de 1 ciclo cuando se presiona
    
    assign key_press = key_prev & ~key_sync2;  // Flanco de bajada
    
    always @(posedge clk) begin
        if (reset)
            key_prev <= 4'b1111;
        else
            key_prev <= key_sync2;
    end
    
    // ========================================================================
    // Control de posición del cursor
    // ========================================================================
    always @(posedge clk) begin
        if (reset) begin
            cursor_x <= 10'd320;  // Centro de pantalla
            cursor_y <= 10'd240;
        end else begin
            // KEY[0] = Arriba
            if (key_press[0] && cursor_y > 0)
                cursor_y <= cursor_y - 1;
            
            // KEY[1] = Abajo
            if (key_press[1] && cursor_y < V_MAX)
                cursor_y <= cursor_y + 1;
            
            // KEY[2] = Izquierda
            if (key_press[2] && cursor_x > 0)
                cursor_x <= cursor_x - 1;
            
            // KEY[3] = Derecha
            if (key_press[3] && cursor_x < H_MAX)
                cursor_x <= cursor_x + 1;
        end
    end
    
    // ========================================================================
    // Control de escritura en BRAM
    // ========================================================================
    // Calcular dirección: addr = y * 640 + x
    // Optimización: 640 = 512 + 128 = 2^9 + 2^7
    // addr = (y << 9) + (y << 7) + x  (solo shifts y sumas, sin multiplicación)
    assign cursor_addr = (cursor_y << 9) + (cursor_y << 7) + cursor_x;
    
    // Color RGB de 3 bits en formato compatible con VGA
    // Formato BRAM: 00000RGB (bits 2,1,0)
    // R=bit[2], G=bit[1], B=bit[0]
    wire [2:0] rgb_color = SW[3:1];  // R=SW[3], G=SW[2], B=SW[1]
    assign cursor_data = {5'b00000, rgb_color};  // 5 ceros + 3 bits RGB
    
    // Generar pulso de escritura cuando:
    // 1. SW[0] está activado (enable modificación)
    // 2. Se presiona cualquier botón
    always @(posedge clk) begin
        if (reset) begin
            cursor_write_en <= 0;
        end else begin
            cursor_write_en <= SW[0] && (|key_press);  // OR de todos los botones
        end
    end

endmodule
