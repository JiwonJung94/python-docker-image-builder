#!/bin/bash

##################################################################################################
#                                                                                                #
#  Copyright (c) 2024 Jiwon Jung                                                                 #
#  This script is licensed under the MIT License. See LICENSE file for details.                  #
#  Contact: jiwon8297@gmail.com                                                                  #
#                                                                                                #
#  This script automates the process of building a Docker image based on a specified             #
#  Python version and a list of dependencies. It reads the dependencies from a provided          #
#  text file, where the first line indicates the Python version (e.g., "python_version==3.8")    #
#  and the subsequent lines list the required Python packages.                                   #
#                                                                                                #
#  The script employs a caching mechanism to optimize the Docker image build process. The        #
#  cache stores the order of dependencies as they are installed in the Docker image. If the      #
#  dependencies file changes, the script reuses the cached order for existing dependencies       #
#  and appends any new dependencies to the end. This approach minimizes the number of layers     #
#  that need to be rebuilt in the Docker image, thus speeding up the build process and reducing  #
#  build errors associated with frequently changing package versions or configurations.          #
#                                                                                                #
#  The cache is stored in a directory named 'cache', with one cache file per Python version.     #
#  This allows for efficient management of dependencies across different projects and Python     #
#  versions. By reordering the dependencies according to the cache and only appending new ones,  #
#  the script ensures that the Docker build process is as efficient as possible, reusing         #
#  previously built layers whenever feasible and only adding new layers for new or changed       #
#  dependencies.                                                                                 #
#                                                                                                #
#  Dependencies are installed in the Docker image using 'pip install', and the Docker build      #
#  context is set to the directory containing the Dockerfile. The resulting image is tagged      #
#  with the name derived from the dependencies file name, providing an easy way to identify      #
#  and manage Docker images created with this script.                                            #
#                                                                                                #
##################################################################################################

# Check the number of arguments required for the script
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 [dependencies_file_path]"
    exit 1
fi

# Assign variables from arguments
DEPENDENCIES_FILE=$1

# Check if the dependencies file exists and is readable
if [ ! -f "$DEPENDENCIES_FILE" ] || [ ! -r "$DEPENDENCIES_FILE" ]; then
    echo "Error: Dependencies file '$DEPENDENCIES_FILE' does not exist or cannot be read."
    exit 1
fi

# Read the first line of the dependencies file to extract the Python version
read -r PYTHON_VERSION_LINE < "$DEPENDENCIES_FILE"

# Validate the Python version line starts with "python_version=="
if [[ ! $PYTHON_VERSION_LINE =~ ^python_version== ]]; then
    echo "Error: The first line of '$DEPENDENCIES_FILE' must start with 'python_version=='."
    exit 1
fi

PYTHON_VERSION=${PYTHON_VERSION_LINE#python_version==}

# Set the cache directory and file name
CACHE_DIR="cache"
CACHE_FILE="${CACHE_DIR}/${PYTHON_VERSION}.txt"

# Create the cache directory if it does not exist
mkdir -p "$CACHE_DIR"

# Extract the file name and remove the .txt extension for the image name
IMAGE_NAME=$(basename -- "$DEPENDENCIES_FILE")
IMAGE_NAME="${IMAGE_NAME%.txt}"

# Start creating the Dockerfile with the extracted Python version
cat <<EOF > Dockerfile
ARG PYTHON_VERSION=$PYTHON_VERSION

FROM python:\$PYTHON_VERSION

WORKDIR /app

EOF

# Exclude the first line (Python version) and read the rest of dependencies into an array
mapfile -t dep_lines < <(tail -n +2 "$DEPENDENCIES_FILE")

# Read the cached dependencies into an array, if available
mapfile -t cache_lines < "$CACHE_FILE" 2>/dev/null

# Create a map from cache for easy lookup and maintain order
declare -A cache_map
for i in "${!cache_lines[@]}"; do
    cache_map["${cache_lines[i]}"]=$i
done

# Sort existing modules according to the cache and identify new modules
sorted_deps=()
new_modules=()

for line in "${dep_lines[@]}"; do
    if [[ ! -z "$line" && ! "$line" =~ ^# ]]; then
        if [[ ${cache_map[$line]+_} ]]; then
            sorted_deps["${cache_map[$line]}"]=$line
        else
            new_modules+=("$line")
        fi
    fi
done

# Update the cache file with the sorted and new modules
{
    for line in "${sorted_deps[@]}"; do
        [[ -n "$line" ]] && echo "$line"
    done
    for line in "${new_modules[@]}"; do
        echo "$line"
    done
} > "$CACHE_FILE"

# Add dependencies to Dockerfile
for line in "${sorted_deps[@]}"; do
    [[ -n "$line" ]] && echo "RUN pip install --no-cache-dir $line" >> Dockerfile
done
for line in "${new_modules[@]}"; do
    echo "RUN pip install --no-cache-dir $line" >> Dockerfile
done

# Build the Docker image with the specified Python version and dependencies
docker build -t "$IMAGE_NAME" -f Dockerfile . || { echo "Docker build failed"; exit 1; }

# Optionally, save the Docker image to a tar file (uncomment and specify OUTPUT_TAR_PATH)
# OUTPUT_TAR_PATH="<path_to_save>/<image_name>.tar"
# docker save "$IMAGE_NAME" > "$OUTPUT_TAR_PATH" || { echo "Docker save failed"; exit 1; }

# Optionally, remove the generated Dockerfile and the Docker image after saving (uncomment to use)
rm Dockerfile
# docker rmi "$IMAGE_NAME"
