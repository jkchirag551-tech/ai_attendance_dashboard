# Use a pre-built image with dlib and face_recognition already installed
FROM python:3.10-slim

# Install system dependencies for OpenCV and other tools
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    libopenblas-dev \
    liblapack-dev \
    libx11-dev \
    libgtk-3-dev \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Install dlib using a pre-built wheel to save memory and time
RUN pip install --no-cache-dir https://github.com/u76602/dlib-binaries/raw/main/dlib-19.24.1-cp310-cp310-linux_x86_64.whl

# Set working directory
WORKDIR /app

# Copy requirements and install the rest
COPY requirements.txt .
# Remove dlib and face-recognition from pip to avoid re-installation
RUN sed -i '/dlib/d' requirements.txt && \
    sed -i '/face-recognition/d' requirements.txt && \
    pip install --no-cache-dir -r requirements.txt

# Install face-recognition (it will use the dlib we just installed)
RUN pip install --no-cache-dir face-recognition

# Copy the rest of the application
COPY . .

# Expose the port
EXPOSE 10000

# Start
CMD ["gunicorn", "--worker-class", "eventlet", "-w", "1", "--bind", "0.0.0.0:10000", "app:app"]
