import time
import numpy as np
from PIL import Image
import matplotlib.pyplot as plt
import struct

import serial

# --------------------------------------------
# Convertir un pixel RGB (0-255) a RGB111
# con formato: byte = 00000RGB
# --------------------------------------------

THRESHOLD = 127

def rgb_to_rgb111_byte(r, g, b, threshold=THRESHOLD):
    R = 1 if r > threshold else 0
    G = 1 if g > threshold else 0
    B = 1 if b > threshold else 0
    return (R << 2) | (G << 1) | B


# --------------------------------------------
# Convertir imagen completa a RGB111
# y generar imagen visualizable en matplotlib
# --------------------------------------------
def convert_image_rgb111(img, threshold=THRESHOLD):
    w, h = img.size
    arr = np.array(img)

    rgb111_img = np.zeros((h, w, 3), dtype=np.uint8)

    for y in range(h):
        for x in range(w):
            r, g, b = arr[y, x]

            # bits RGB111
            R = 255 if r > threshold else 0
            G = 255 if g > threshold else 0
            B = 255 if b > threshold else 0

            rgb111_img[y, x] = [R, G, B]

    return rgb111_img


# --------------------------------------------
# Guardar archivo .bin con 3 LSB = RGB
# --------------------------------------------
def save_bin_rgb111(img, output_path, threshold=THRESHOLD):
    w, h = img.size
    arr = np.array(img)

    with open(output_path, "wb") as f:
        for y in range(h):
            for x in range(w):
                r, g, b = arr[y, x]
                byte = rgb_to_rgb111_byte(r, g, b, threshold)
                f.write(struct.pack("B", byte))


# --------------------------------------------
# PROGRAMA PRINCIPAL
# --------------------------------------------
def process_image(input_path, width=640, height=480, save_bin=False, send_image = False):
    # Abrir imagen en RGB
    img = Image.open(input_path).convert("RGB")

    # Redimensionar por defecto a 640x480
    if width and height:
        img = img.resize((width, height), Image.Resampling.NEAREST)

    # Convertir a 3-bit RGB
    img_rgb111 = convert_image_rgb111(img)

    # Mostrar comparación
    plt.figure(figsize=(10, 5))

    plt.subplot(1, 2, 1)
    plt.title("Imagen Original")
    plt.imshow(img)
    plt.axis("off")

    plt.subplot(1, 2, 2)
    plt.title("Imagen RGB111 (8 colores)")
    plt.imshow(img_rgb111)
    plt.axis("off")

    plt.show()

    def rgb111_to_rgb(color_bits):
        R = 255 if (color_bits & 0b100) else 0
        G = 255 if (color_bits & 0b010) else 0
        B = 255 if (color_bits & 0b001) else 0
        return np.array([R, G, B], dtype=np.uint8)

    # ---- Definir color con el que quieres pintar ----
    color_bits = 0b101   # rojo + azul = magenta
    color_rgb = rgb111_to_rgb(color_bits)


    # ---- EMULACIÓN DE PINTADO EN FPGA ----
    # ---- Pintar una zona ----
    """ x0, y0 = 200, 150   # punto inicial
    x1, y1 = 260, 210   # punto final
    img_np = np.array(img)
    img_np[y0:y1, x0:x1] = color_rgb

    # ---- Mostrar resultado ----
    plt.figure(figsize=(10,5))
    plt.subplot(1,2,1)
    plt.title("Original")
    plt.imshow(img)
    plt.axis("off")

    plt.subplot(1,2,2)
    plt.title("Modificada (emulación FPGA)")
    plt.imshow(img_np)
    plt.axis("off")
    plt.show() """

    # Guardar .bin si se pidió
    if save_bin:
        output_path = input_path + ".bin"
        save_bin_rgb111(img, output_path)
        print(f"Archivo binario generado: {output_path}")
    
    if send_image:
        # --------------------------------------------------------
        # 3. Flatten para envío secuencial por UART
        # --------------------------------------------------------
        
        # Generar arreglo 1 byte por pixel con RGB111
        w, h = img.size
        arr = np.array(img)
        pixels = []

        for y in range(h):
            for x in range(w):
                r, g, b = arr[y, x]
                byte = rgb_to_rgb111_byte(r, g, b)
                # print(f"Pixel ({x}, {y}): R={r} G={g} B={b} -> Byte={byte:08b}")
                pixels.append(byte)

        flat = np.array(pixels, dtype=np.uint8)

        print("Tamaño en bytes a enviar:", len(flat))

        # --------------------------------------------------------
        # 5. Enviar por UART usando PySerial
        # --------------------------------------------------------
        # Ajusta el puerto COM según tu PC:
        # En Windows es COM3, COM4...
        # En Linux /dev/ttyUSB0
        ser = serial.Serial(
            port="COM4",
            baudrate=115200,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_TWO,
            timeout=1
        )

        time.sleep(2)  # espera a que el FT232 se estabilice

        # Enviar imagen byte por byte
        for value in flat:
            ser.write(bytes([value]))
            # time.sleep(0.00001)  # 10 microsegundos opcional

        ser.close()

        print("Imagen enviada correctamente.")


# --------------------------------------------
# EJEMPLO DE USO:
# process_image("foto.png", 640, 480, save_bin=True)
# --------------------------------------------

process_image("imagen.jpeg", send_image=True)