import os
from PIL import Image

# Cấu hình mặc định
# IMG_INPUT  = "input_image.png"
# HEX_FILE   = "D:\\verilog_projects\\VIDEO_SYSTEM_HDL\\VIDEO_SYSTEM_HDL.srcs\\sources_1\\new\\image_data.hex"

INPUT_FOLDER  = "input_images"  # Thư mục chứa các ảnh gốc (.png, .jpg, .bmp...)
HEX_OUTPUT_DIR = "output_images"  # Thư mục lưu các file hex đầu ra

# HEX_FILE_O   = "D:\\verilog_projects\\VIDEO_SYSTEM_HDL\\VIDEO_SYSTEM_HDL.sim\\sim_1\\behav\\xsim\\output_sim.hex"
# IMG_OUTPUT = "output_sim.png"
# 1. Thư mục chứa các file .hex xuất ra từ Testbench (Vivado)
SIM_HEX_INPUT_DIR = "output_testbench"
# 2. Thư mục để lưu các ảnh .png sau khi chuyển đổi xong
SIM_IMG_OUTPUT_DIR = "converted_results"
WIDTH      = 640
HEIGHT     = 480

def convert_batch_to_hex():
    try:
        # Kiểm tra và tạo thư mục đầu ra nếu chưa có
        if not os.path.exists(HEX_OUTPUT_DIR):
            os.makedirs(HEX_OUTPUT_DIR)
            print(f"--- Đã tạo thư mục: {HEX_OUTPUT_DIR} ---")

        if not os.path.exists(INPUT_FOLDER):
            print(f"--- LỖI: Không tìm thấy thư mục đầu vào '{INPUT_FOLDER}' ---")
            return

        # Lấy danh sách các file ảnh
        valid_extensions = ('.png', '.jpg', '.jpeg', '.bmp')
        image_files = [f for f in os.listdir(INPUT_FOLDER) if f.lower().endswith(valid_extensions)]

        if not image_files:
            print("--- Không tìm thấy file ảnh nào trong thư mục! ---")
            return

        print(f"--- Bắt đầu xử lý {len(image_files)} ảnh ---")

        for filename in image_files:
            img_path = os.path.join(INPUT_FOLDER, filename)
            
            # Tạo tên file hex tương ứng (VD: image1.png -> image1.hex)
            hex_filename = os.path.splitext(filename)[0] + ".hex"
            hex_path = os.path.join(HEX_OUTPUT_DIR, hex_filename)

            img = Image.open(img_path).convert('RGB')
            img = img.resize((WIDTH, HEIGHT))
            
            with open(hex_path, 'w') as f:
                for y in range(img.height):
                    for x in range(img.width):
                        r, g, b = img.getpixel((x, y))
                        # Chuyển đổi RGB888 -> RGB565 (16-bit)
                        rgb565 = ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)
                        f.write(f"{rgb565:04x}\n")
            
            print(f"  > Đã chuyển: {filename} -> {hex_filename}")

        print(f"\n--- XONG: Tất cả ảnh đã được chuyển vào '{HEX_OUTPUT_DIR}' ---")

    except Exception as e:
        print(f"--- LỖI: {e} ---")
       
# def convert_to_hex():
#     try:
#         if not os.path.exists(IMG_INPUT):
#             print(f"--- LỖI: Không tìm thấy file '{IMG_INPUT}' ---")
#             return
        
#         img = Image.open(IMG_INPUT).convert('RGB')
#         img = img.resize((WIDTH, HEIGHT))
        
#         with open(HEX_FILE, 'w') as f:
#             for y in range(img.height):
#                 for x in range(img.width):
#                     r, g, b = img.getpixel((x, y))
#                     # RGB888 -> RGB565
#                     rgb565 = ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)
#                     f.write(f"{rgb565:04x}\n")
#         print(f"--- XONG: Đã chuyển '{IMG_INPUT}' thành '{HEX_FILE}' ---")
#     except Exception as e:
#         print(f"--- LỖI: {e} ---")

# def convert_hex_to_image():
#     try:
#         if not os.path.exists(HEX_FILE_O):
#             print(f"--- LỖI: Không tìm thấy file '{HEX_FILE_O}' ---")
#             return

#         img = Image.new('RGB', (WIDTH, HEIGHT))
#         pixels = img.load()

#         with open(HEX_FILE_O, 'r') as f:
#             # Lấy các dòng dữ liệu, đảm bảo bỏ qua frame rác nếu có
#             lines = [line.strip() for line in f.readlines() if len(line.strip()) >= 6]
        
#         # Lấy 1 frame cuối cùng (tránh trường hợp file hex chứa nhiều frame)
#         total_pixels = WIDTH * HEIGHT
#         if len(lines) > total_pixels:
#             lines = lines[-total_pixels:] 

#         for y in range(HEIGHT):
#             for x in range(WIDTH):
#                 idx = y * WIDTH + x
#                 if idx < len(lines):
#                     hex_val = int(lines[idx], 16)
#                     # Tách RGB888 trực tiếp
#                     r = (hex_val >> 16) & 0xFF
#                     g = (hex_val >> 8) & 0xFF
#                     b = hex_val & 0xFF
#                     pixels[x, y] = (r, g, b)

#         img.save(IMG_OUTPUT)
#         print(f"--- XONG: Đã chuyển '{HEX_FILE_O}' thành '{IMG_OUTPUT}' ---")
#     except Exception as e:
#         print(f"--- LỖI: {e} ---")

def convert_batch_hex_to_image():
    try:
        # 1. Kiểm tra thư mục đầu vào
        if not os.path.exists(SIM_HEX_INPUT_DIR):
            print(f"--- LỖI: Không tìm thấy thư mục hex '{SIM_HEX_INPUT_DIR}' ---")
            return

        # 2. Tạo thư mục đầu ra nếu chưa có
        if not os.path.exists(SIM_IMG_OUTPUT_DIR):
            os.makedirs(SIM_IMG_OUTPUT_DIR)
            print(f"--- Đã tạo thư mục đầu ra: {SIM_IMG_OUTPUT_DIR} ---")

        # 3. Lấy danh sách các file .hex
        hex_files = [f for f in os.listdir(SIM_HEX_INPUT_DIR) if f.lower().endswith('.hex')]

        if not hex_files:
            print("--- Không tìm thấy file .hex nào để chuyển đổi! ---")
            return

        print(f"--- Bắt đầu chuyển đổi {len(hex_files)} file hex sang ảnh ---")

        for filename in hex_files:
            hex_path = os.path.join(SIM_HEX_INPUT_DIR, filename)
            
            # Tạo tên file ảnh tương ứng (VD: output_0.hex -> output_0.png)
            img_filename = os.path.splitext(filename)[0] + ".png"
            img_path = os.path.join(SIM_IMG_OUTPUT_DIR, img_filename)

            # Xử lý đọc file hex
            with open(hex_path, 'r') as f:
                # Chỉ lấy những dòng có dữ liệu (RGB888 thường có 6 ký tự hex)
                lines = [line.strip() for line in f.readlines() if len(line.strip()) >= 6]

            # Kiểm tra số lượng pixel
            total_pixels = WIDTH * HEIGHT
            if len(lines) < total_pixels:
                print(f"  [!] Cảnh báo: File {filename} thiếu dữ liệu ({len(lines)}/{total_pixels} pixels)")
            elif len(lines) > total_pixels:
                # Lấy 1 frame cuối cùng nếu file chứa nhiều frame
                lines = lines[-total_pixels:]

            # Tạo ảnh mới
            img = Image.new('RGB', (WIDTH, HEIGHT))
            pixels = img.load()

            for y in range(HEIGHT):
                for x in range(WIDTH):
                    idx = y * WIDTH + x
                    if idx < len(lines):
                        try:
                            hex_val = int(lines[idx], 16)
                            # Tách RGB888 (Dựa trên $fwrite %06x trong Verilog)
                            r = (hex_val >> 16) & 0xFF
                            g = (hex_val >> 8) & 0xFF
                            b = hex_val & 0xFF
                            pixels[x, y] = (r, g, b)
                        except ValueError:
                            pixels[x, y] = (0, 0, 0) # Lỗi định dạng thì để màu đen

            img.save(img_path)
            print(f"  > Đã lưu: {img_filename}")

        print(f"\n--- HOÀN THÀNH: Tất cả ảnh đã được lưu tại '{SIM_IMG_OUTPUT_DIR}' ---")

    except Exception as e:
        print(f"--- LỖI HỆ THỐNG: {e} ---")

if __name__ == "__main__":
    while True:
        print("\n[1] Ảnh -> Hex  |  [2] Hex -> Ảnh  |  [0] Thoát")
        chon = input("Chọn: ")

        if chon == '1':
            # convert_to_hex()
            convert_batch_to_hex()
        elif chon == '2':
            # convert_hex_to_image()
            convert_batch_hex_to_image()
        elif chon == '0':
            break
        else:
            print("Nhập sai rồi!")