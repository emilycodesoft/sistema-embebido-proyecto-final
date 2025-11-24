module bram_image (
    input wire clk,
    input wire [18:0] addr,    // 307,200 direcciones -> 19 bits
    input wire [7:0] din,      // datos de escritura (solo 3 bits relevantes)
    input wire we,             // write enable
    output reg [7:0] dout      // datos de lectura
);

    reg [7:0] memory [0:307199]; // 640*480 bytes (cada píxel 3 bits)

    always @(posedge clk) begin
        if (we)
            memory[addr] <= din;      // guardar todo el byte (3 bits activos)
        dout <= memory[addr];          // leer todo el byte
    end

endmodule
