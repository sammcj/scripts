import pandas as pd
import json

# Read the Parquet file
df = pd.read_parquet("v1/sams_svg_dataset_alpaca.parquet")

# Convert DataFrame to list of dictionaries
data = df.to_dict("records")

# Write to JSON file
with open("v1/output.json", "w") as f:
    json.dump(data, f, indent=2)

print("Conversion complete. Data saved to output.json")
