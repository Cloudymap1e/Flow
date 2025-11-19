import sys
import os
from PIL import Image
from pillow_heif import register_heif_opener

# Register HEIC opener
register_heif_opener()

def convert_heic_to_jpg(file_path):
    """Converts a single HEIC file to JPG."""
    try:
        if not file_path.lower().endswith(('.heic', '.heif')):
            print(f"Skipping non-HEIC file: {file_path}")
            return

        directory, filename = os.path.split(file_path)
        name, ext = os.path.splitext(filename)
        new_filename = f"{name}.jpg"
        new_file_path = os.path.join(directory, new_filename)

        print(f"Converting {file_path} to {new_file_path}...")
        
        image = Image.open(file_path)
        image.save(new_file_path, "JPEG", quality=95)
        print(f"Successfully converted {filename}")
        
    except Exception as e:
        print(f"Error converting {file_path}: {e}")

def main():
    if len(sys.argv) < 2:
        print("Usage: python heic_converter.py <file_or_directory> ...")
        sys.exit(1)

    for path in sys.argv[1:]:
        if os.path.isfile(path):
            convert_heic_to_jpg(path)
        elif os.path.isdir(path):
            for root, dirs, files in os.walk(path):
                for file in files:
                    if file.lower().endswith(('.heic', '.heif')):
                        convert_heic_to_jpg(os.path.join(root, file))
        else:
            print(f"Path not found: {path}")

if __name__ == "__main__":
    main()
