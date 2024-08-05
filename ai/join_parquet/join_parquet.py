import glob, os
import pandas as pd


# Returns a dataframe that contains all of the directory's parquet files
def combine_directory_of_parquet(directory="./*.parquet", recursive=True, columns=[]):

    # Create an empty dataframe to hold our combined data
    merged_df = pd.DataFrame(columns=columns)

    # Iterate over all of the files in the provided directory and
    # configure if we want to recursively search the directory
    for filename in glob.iglob(pathname=directory, recursive=recursive):

        # Check if the file is actually a file (not a directory) and make sure it is a parquet file
        if os.path.isfile(filename):
            try:
                # Perform a read on our dataframe
                temp_df = pd.read_parquet(filename)

                # Attempt to merge it into our combined dataframe
                # merged_df = merged_df.append(temp_df, ignore_index=True)
                # fix for error: 'DataFrame' object has no attribute 'append'
                merged_df = pd.concat([merged_df, temp_df], ignore_index=True)

            except Exception as e:
                print("Skipping {} due to error: {}".format(filename, e))
                continue
        else:
            print("Not a file {}".format(filename))

    # Return the result!
    return merged_df


# Replace this with your column names that you are expecting in your parquet's
columns = ["input", "output"]

# You can modify the directory path below, the asterisks are wildcard selectors to match any file.
df = combine_directory_of_parquet(
    directory="./*.parquet", recursive=True, columns=columns
)

# Write the dataframe to a CSV file
# df.to_csv('./output.csv')

# You can also write the dataframe as a parquet file like so:
df.to_parquet("./combined.parquet")
