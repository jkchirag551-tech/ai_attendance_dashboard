# Use a more complete Python image that includes dlib binaries
FROM python:3.11-slim-bookworm

# Install pre-compiled dlib and other system dependencies
RUN apt-get update && apt-get install -y \
    python3-dlib \
    libopenblas-dev \
    liblapack-dev \
    libx11-dev \
    libgtk-3-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements and remove dlib/face-recognition from pip to use system version
COPY requirements.txt .
RUN sed -i '/dlib/d' requirements.txt && \
    sed -i '/face-recognition/d' requirements.txt && \
    pip install --no-cache-dir -r requirements.txt

# Manually install face-recognition without its dlib dependency
RUN pip install --no-cache-dir face-recognition --no-dependencies

# Copy the rest of the application
COPY . .

# Expose the port
EXPOSE 10000

# Start
CMD ["gunicorn", "--worker-class", "eventlet", "-w", "1", "--bind", "0.0.0.0:10000", "app:app"]
