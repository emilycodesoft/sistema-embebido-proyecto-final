// ============================================================================
// Módulo: vga_controller
// Descripción: Controlador VGA 640×480 @ 60Hz
// Genera: hsync, vsync, coordenadas x/y, display_enable
// ============================================================================

module vga_controller (
    input  wire clk_25mhz,          // Pixel clock (25 MHz)
    input  wire reset,              // Reset asíncrono
    
    output reg  hsync,              // Sincronización horizontal
    output reg  vsync,              // Sincronización vertical
    output wire display_enable,     // Indica área visible
    output reg  [9:0] hcount,       // Contador horizontal (0-799)
    output reg  [9:0] vcount        // Contador vertical (0-524)
);

    // ========================================================================
    // Parámetros de timing VGA 640×480 @ 60Hz
    // ========================================================================
    
    // Timing horizontal
    localparam H_VISIBLE    = 640;  // Píxeles visibles
    localparam H_FRONT      = 16;   // Front porch
    localparam H_SYNC       = 96;   // Sync pulse
    localparam H_BACK       = 48;   // Back porch
    localparam H_TOTAL      = 800;  // Total horizontal
    
    // Timing vertical
    localparam V_VISIBLE    = 480;  // Líneas visibles
    localparam V_FRONT      = 10;   // Front porch
    localparam V_SYNC       = 2;    // Sync pulse
    localparam V_BACK       = 33;   // Back porch
    localparam V_TOTAL      = 525;  // Total vertical
    
    // Límites para sync pulses
    localparam H_SYNC_START = H_VISIBLE + H_FRONT;
    localparam H_SYNC_END   = H_VISIBLE + H_FRONT + H_SYNC;
    localparam V_SYNC_START = V_VISIBLE + V_FRONT;
    localparam V_SYNC_END   = V_VISIBLE + V_FRONT + V_SYNC;
    
    // ========================================================================
    // Contadores horizontal y vertical
    // ========================================================================
    
    always @(posedge clk_25mhz or posedge reset) begin
        if (reset) begin
            hcount <= 0;
            vcount <= 0;
        end else begin
            // Contador horizontal
            if (hcount == H_TOTAL - 1) begin
                hcount <= 0;
                
                // Contador vertical (incrementa al final de cada línea)
                if (vcount == V_TOTAL - 1)
                    vcount <= 0;
                else
                    vcount <= vcount + 1;
            end else begin
                hcount <= hcount + 1;
            end
        end
    end
    
    // ========================================================================
    // Generación de señales de sincronización
    // ========================================================================
    
    always @(posedge clk_25mhz or posedge reset) begin
        if (reset) begin
            hsync <= 1;
            vsync <= 1;
        end else begin
            // Hsync (activo en bajo)
            hsync <= ~((hcount >= H_SYNC_START) && (hcount < H_SYNC_END));
            
            // Vsync (activo en bajo)
            vsync <= ~((vcount >= V_SYNC_START) && (vcount < V_SYNC_END));
        end
    end
    
    // ========================================================================
    // Display enable (área visible)
    // ========================================================================
    
    assign display_enable = (hcount < H_VISIBLE) && (vcount < V_VISIBLE);

endmodule