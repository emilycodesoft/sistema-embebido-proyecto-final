module bram_image (
    input wire clk,
    input wire [15:0] addr,    // dirección de lectura/escritura
    input wire [7:0] din,      // datos de escritura
    input wire we,             // write enable
    output reg [7:0] dout      // datos de lectura
);

    reg [7:0] memory [0:38399]; // 38,400 bytes (8 bits por palabra)

    always @(posedge clk) begin
        if (we)
            memory[addr] <= din;
        dout <= memory[addr];
    end

endmodule
