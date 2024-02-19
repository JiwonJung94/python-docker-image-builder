# Python Docker Image Builder Script

This script automates the process of building Docker images based on a specified Python version and a list of dependencies. It is designed to optimize the Docker image build process by employing a caching mechanism for dependency installation order. This approach minimizes the need to rebuild layers, thus speeding up the build process and reducing potential build errors.

## Features

- **Python Version and Dependency List**: The script reads a text file specifying the Python version and the required Python packages.
- **Caching Mechanism**: Utilizes a caching strategy to store the order of dependencies, optimizing subsequent builds by reusing previously built layers for unchanged dependencies.
- **Efficient Docker Builds**: By reordering dependencies according to the cache and appending new ones, the script ensures minimal layer rebuilds, making the build process quicker and more efficient.
- **Custom Image Tagging**: Tags the built Docker image with the name derived from the dependencies file name for easy identification and management.

## Usage

To use this script, you must provide a path to the dependencies file as an argument. The dependencies file should have the Python version specified on the first line (formatted as `python_version==x.x`) and list the required Python packages on the subsequent lines.

```bash
./run.sh [dependencies_file_path]
```

Ensure that the script has executable permissions:

```bash
chmod +x run.sh
```

## Dependencies File Format

The dependencies file should be structured as follows:

```
python_version==3.8
package1==version
package2
package3==version
...
```

## Prerequisites

- Docker must be installed and running on your system.
- Bash environment for executing the script.

## License

This script is licensed under the MIT License. See the LICENSE file in the source directory for more details.