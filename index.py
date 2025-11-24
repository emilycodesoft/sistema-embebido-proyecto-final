#!/usr/bin/env python3
"""
Procesa una imagen para el proyecto embebido:
- Carga `entrada.jpg`
- Convierte a escala de grises
- Redimensiona a 640x480 (si no lo es)
- Binariza con umbral 128 (siempre)
- Guarda vista previa PNG y BMP 1-bit
- Empaqueta bits (MSB-first) en bytes y envía por serial a COM4@115200
"""
from pathlib import Path
from typing import List, Tuple
import logging
import sys

from PIL import Image
import serial

# Configuración fija del flujo del proyecto
INPUT_IMAGE = "entrada.jpg"
PREVIEW_PNG = "salida_bn_640x480.png"
OUTPUT_BMP = "imagen_1bit_640x480.bmp"
SERIAL_PORT = "COM4"
BAUDRATE = 115200
TIMEOUT = 1  # segundos
SIZE: Tuple[int, int] = (640, 480)
THRESHOLD = 128

# Logging sencillo
logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger("image_to_serial")


def load_and_prepare(path: str, size: Tuple[int, int]) -> Image.Image:
    """
    Carga una imagen, la convierte a escala de grises y la redimensiona
    a `size` si es necesario.
    """
    img_path = Path(path)
    if not img_path.exists():
        raise FileNotFoundError(f"Archivo no encontrado: {path}")

    img = Image.open(img_path).convert("L")
    if img.size != size:
        logger.info("Redimensionando imagen de %s a %s", img.size, size)
        img = img.resize(size, Image.LANCZOS)
    else:
        logger.debug("Imagen ya tiene tamaño %s", size)
    return img


def binarize(img: Image.Image, threshold: int = THRESHOLD) -> Image.Image:
    """
    Binariza la imagen en modo '1' usando el umbral especificado.
    Resultado en modo '1' (píxeles 0 o 255).
    """
    if not (0 <= threshold <= 255):
        raise ValueError("threshold must be between 0 and 255")
    binary = img.point(lambda x: 255 if x > threshold else 0, "1")
    return binary


def binary_to_bits(binary_img: Image.Image) -> List[int]:
    """
    Convierte una imagen modo '1' en una lista de bits (0/1) en orden row-major.
    """
    if binary_img.mode != "1":
        raise ValueError("binary_img debe estar en modo '1'")
    width, height = binary_img.size
    pixels = binary_img.load()
    bits: List[int] = []
    for y in range(height):
        for x in range(width):
            bits.append(1 if pixels[x, y] == 255 else 0)
    return bits


def bits_to_bytes_msbf(bits: List[int]) -> bytearray:
    """
    Empaqueta bits en bytes usando MSB-first dentro de cada byte.
    Completa con ceros al final si hace falta.
    """
    ba = bytearray()
    # rellenar hasta múltiplo de 8
    extra = (-len(bits)) % 8
    if extra:
        bits = bits + [0] * extra
    for i in range(0, len(bits), 8):
        byte = 0
        for b in bits[i:i + 8]:
            byte = (byte << 1) | (1 if b else 0)
        ba.append(byte)
    return ba


def save_outputs(preview_img: Image.Image, binary_img: Image.Image) -> None:
    """
    Guarda la vista previa (PNG) y la imagen 1-bit BMP.
    - `preview_img`: imagen en modo 'L' o convertida para mejor visualización.
    - `binary_img`: imagen en modo '1' (guardada como BMP 1-bit).
    """
    # Guardar preview PNG en escala de grises para visualización
    try:
        preview_img.save(PREVIEW_PNG)
        logger.info("Preview guardado: %s", PREVIEW_PNG)
    except Exception as e:
        logger.warning("No se pudo guardar preview PNG: %s", e)

    try:
        binary_img.save(OUTPUT_BMP)
        logger.info("BMP 1-bit guardado: %s", OUTPUT_BMP)
    except Exception as e:
        logger.warning("No se pudo guardar BMP 1-bit: %s", e)


def send_serial(port: str, data: bytes, baudrate: int = BAUDRATE, timeout: int = TIMEOUT) -> None:
    """
    Envía los bytes por el puerto serial. Usa context manager para cerrar correctamente.
    """
    logger.info("Abriendo puerto serial %s @ %d", port, baudrate)
    try:
        with serial.Serial(port, baudrate, timeout=timeout) as ser:
            sent = ser.write(data)
            ser.flush()
            logger.info("Enviados %d bytes por %s", sent, port)
    except serial.SerialException as e:
        logger.error("Error en puerto serial %s: %s", port, e)
        raise


def main() -> None:
    try:
        logger.info("Iniciando procesamiento obligatorio: entrada=%s", INPUT_IMAGE)
        img = load_and_prepare(INPUT_IMAGE, SIZE)

        # Guardar preview en escala de grises para visualización
        preview = img.copy()
        preview.save(PREVIEW_PNG)

        binary = binarize(img, THRESHOLD)

        # Guardar salidas
        save_outputs(preview, binary)

        # Convertir a bytes y enviar
        bits = binary_to_bits(binary)
        print("Bits: ", bits)
        ba = bits_to_bytes_msbf(bits)
        print("Bytes: ", ba)
        send_serial(SERIAL_PORT, bytes(ba), BAUDRATE, TIMEOUT)

        logger.info("Proceso terminado correctamente.")
        sys.exit(0)
    except FileNotFoundError as e:
        logger.error(str(e))
        sys.exit(2)
    except Exception as e:
        logger.exception("Error inesperado durante el proceso: %s", e)
        sys.exit(1)


if __name__ == "__main__":
    main()