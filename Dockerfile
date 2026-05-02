# Use Python 3.10 slim for compatibility with dlib-bin
FROM python:3.10-slim

# Install system dependencies for OpenCV and other tools
RUN apt-get update && apt-get install -y \
    libopenblas-dev \
    liblapack-dev \
    libx11-dev \
    libgtk-3-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# 1. Install dlib-bin (pre-compiled binary, no memory crash)
RUN pip install --no-cache-dir dlib-bin==19.24.1

# 2. Install face-recognition WITHOUT dependencies
# (This prevents it from trying to build the standard dlib from source)
RUN pip install --no-cache-dir face-recognition==1.3.0 --no-dependencies

# 3. Copy requirements and install the rest of the stack
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application
COPY . .

# Expose the port
EXPOSE 10000

# Start
CMD ["gunicorn", "--worker-class", "eventlet", "-w", "1", "--bind", "0.0.0.0:10000", "app:app"]
