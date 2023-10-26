from PIL import Image
from stereogram import Stereogram

def generate_hidden_3d_stereogram(input_image_path, output_image_path):
    # Load the input image
    input_image = Image.open(input_image_path)

    # Initialize the stereogram generator
    stereogram_generator = Stereogram(input_image)

    # Generate the hidden 3D stereogram
    hidden_3d_stereogram = stereogram_generator.create_stereogram()

    # Save the output image
    hidden_3d_stereogram.save(output_image_path)

if __name__ == "__main__":
    input_image_path = "input_image.png"  # Replace with the path to your input image
    output_image_path = "output_stereogram.png"  # Path to save the generated stereogram

    generate_hidden_3d_stereogram(input_image_path, output_image_path)
