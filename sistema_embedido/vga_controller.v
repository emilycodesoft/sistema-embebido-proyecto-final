// ============================================================================
// Módulo: vga_controller (VERSIÓN MEJORADA CON CLOCK ENABLE)
// Descripción: Controlador VGA 640×480 @ 60Hz
// Genera: hsync, vsync, coordenadas x/y, display_enable
// ============================================================================

module vga_controller (
    input  wire clk_50mhz,          // Clock principal (50 MHz)
    input  wire clk_enable_25mhz,   // Enable de 25 MHz
    input  wire reset,              // Reset síncrono activo alto
    
    output reg  hsync,              // Sincronización horizontal
    output reg  vsync,              // Sincronización vertical
    output reg  display_enable,     // Indica área visible
    output reg  [9:0] hcount,       // Contador horizontal (0-799)
    output reg  [9:0] vcount        // Contador vertical (0-524)
);

    // ========================================================================
    // Parámetros de timing VGA 640×480 @ 60Hz
    // Referencia: VESA Standard - VGA 640x480 @ 60Hz
    // Pixel clock: 25.175 MHz (usamos 25 MHz, error -0.7%)
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
    localparam H_SYNC_START = H_VISIBLE + H_FRONT;                // 656
    localparam H_SYNC_END   = H_VISIBLE + H_FRONT + H_SYNC;       // 752
    localparam V_SYNC_START = V_VISIBLE + V_FRONT;                // 490
    localparam V_SYNC_END   = V_VISIBLE + V_FRONT + V_SYNC;       // 492
    
    // ========================================================================
    // Contadores horizontal y vertical (operan a 25MHz mediante enable)
    // ========================================================================
    
    always @(posedge clk_50mhz) begin
        if (reset) begin
            hcount <= 10'd0;
            vcount <= 10'd0;
        end else if (clk_enable_25mhz) begin  // Solo incrementa con enable
            // Contador horizontal
            if (hcount == H_TOTAL - 1) begin
                hcount <= 10'd0;
                
                // Contador vertical (incrementa al final de cada línea)
                if (vcount == V_TOTAL - 1)
                    vcount <= 10'd0;
                else
                    vcount <= vcount + 10'd1;
            end else begin
                hcount <= hcount + 10'd1;
            end
        end
    end
    
    // ========================================================================
    // Generación de señales de sincronización
    // ========================================================================
    
    always @(posedge clk_50mhz) begin
        if (reset) begin
            hsync <= 1'b1;
            vsync <= 1'b1;
        end else if (clk_enable_25mhz) begin
            // Hsync (activo en bajo)
            hsync <= ~((hcount >= H_SYNC_START) && (hcount < H_SYNC_END));
            
            // Vsync (activo en bajo)
            vsync <= ~((vcount >= V_SYNC_START) && (vcount < V_SYNC_END));
        end
    end
    
    // ========================================================================
    // Display enable (área visible)
    // ========================================================================
    
    always @(posedge clk_50mhz) begin
        if (reset)
            display_enable <= 1'b0;
        else if (clk_enable_25mhz)
            display_enable <= (hcount < H_VISIBLE) && (vcount < V_VISIBLE);
    end

endmodule