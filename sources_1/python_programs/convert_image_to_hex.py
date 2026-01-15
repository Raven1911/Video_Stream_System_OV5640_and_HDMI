import os
from PIL import Image

# Cấu hình mặc định
IMG_INPUT  = "input_image.jpg"
HEX_FILE   = "D:\\verilog_projects\\VIDEO_SYSTEM_HDL\\VIDEO_SYSTEM_HDL.srcs\\sources_1\\new\\image_data.hex"
HEX_FILE_O   = "D:\\verilog_projects\\VIDEO_SYSTEM_HDL\\VIDEO_SYSTEM_HDL.sim\\sim_1\\behav\\xsim\\output_sim.hex"
IMG_OUTPUT = "output_sim.png"
WIDTH      = 640
HEIGHT     = 480

def convert_to_hex():
    try:
        if not os.path.exists(IMG_INPUT):
            print(f"--- LỖI: Không tìm thấy file '{IMG_INPUT}' ---")
            return
        
        img = Image.open(IMG_INPUT).convert('RGB')
        img = img.resize((WIDTH, HEIGHT))
        
        with open(HEX_FILE, 'w') as f:
            for y in range(img.height):
                for x in range(img.width):
                    r, g, b = img.getpixel((x, y))
                    # RGB888 -> RGB565
                    rgb565 = ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)
                    f.write(f"{rgb565:04x}\n")
        print(f"--- XONG: Đã chuyển '{IMG_INPUT}' thành '{HEX_FILE}' ---")
    except Exception as e:
        print(f"--- LỖI: {e} ---")
def convert_hex_to_image():
    try:
        if not os.path.exists(HEX_FILE_O):
            print(f"--- LỖI: Không tìm thấy file '{HEX_FILE_O}' ---")
            return

        img = Image.new('RGB', (WIDTH, HEIGHT))
        pixels = img.load()

        with open(HEX_FILE_O, 'r') as f:
            # Lấy các dòng dữ liệu, đảm bảo bỏ qua frame rác nếu có
            lines = [line.strip() for line in f.readlines() if len(line.strip()) >= 6]
        
        # Lấy 1 frame cuối cùng (tránh trường hợp file hex chứa nhiều frame)
        total_pixels = WIDTH * HEIGHT
        if len(lines) > total_pixels:
            lines = lines[-total_pixels:] 

        for y in range(HEIGHT):
            for x in range(WIDTH):
                idx = y * WIDTH + x
                if idx < len(lines):
                    hex_val = int(lines[idx], 16)
                    # Tách RGB888 trực tiếp
                    r = (hex_val >> 16) & 0xFF
                    g = (hex_val >> 8) & 0xFF
                    b = hex_val & 0xFF
                    pixels[x, y] = (r, g, b)

        img.save(IMG_OUTPUT)
        print(f"--- XONG: Đã chuyển '{HEX_FILE_O}' thành '{IMG_OUTPUT}' ---")
    except Exception as e:
        print(f"--- LỖI: {e} ---")

if __name__ == "__main__":
    while True:
        print("\n[1] Ảnh -> Hex  |  [2] Hex -> Ảnh  |  [0] Thoát")
        chon = input("Chọn: ")

        if chon == '1':
            convert_to_hex()
        elif chon == '2':
            convert_hex_to_image()
        elif chon == '0':
            break
        else:
            print("Nhập sai rồi!")