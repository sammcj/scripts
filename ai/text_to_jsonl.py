import json
import os
import glob
import pdfplumber

# pip install pdfplumber

def convert_to_jsonl(input_directory, output_file):
    """
    Convert all markdown and text files in the input directory to a single JSONL file.

    Args:
    input_directory (str): Directory containing markdown and text files.
    output_file (str): Output JSONL file.
    """
    files = glob.glob(f"{input_directory}/*")
    with open(output_file, "w") as outfile:
        for file in files:
            if file.endswith(".md") or file.endswith(".txt"):
                with open(file, "r") as infile:
                    content = infile.read()
                    json_data = {"text": content}
                    json_line = json.dumps(json_data)
                    outfile.write(json_line + "\n")

def convert_pdf_to_jsonl(input_directory, output_file):
    """
    Convert all PDF files in the input directory to a single JSONL file.

    Args:
    input_directory (str): Directory containing PDF files.
    output_file (str): Output JSONL file.
    """
    files = glob.glob(f"{input_directory}/*.pdf")
    with open(output_file, "w") as outfile:
        for file in files:
            with pdfplumber.open(file) as pdf:
                content = ''
                for page in pdf.pages:
                    content += page.extract_text() + "\n"
                json_data = {"text": content}
                json_line = json.dumps(json_data)
                outfile.write(json_line + "\n")


# Example usage
input_directory = "/Users/samm/Downloads/convert"  # Replace with your directory path
output_file = "output.jsonl"

convert_pdf_to_jsonl(input_directory, output_file)
# convert_to_jsonl(input_directory, output_file)
