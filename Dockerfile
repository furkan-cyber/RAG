# Base image
FROM python:3.9-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
ENV DEBIAN_FRONTEND noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libssl-dev \
    libffi-dev \
    python3-dev \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install NLTK data
RUN python -m nltk.downloader punkt stopwords

# Set working directory
WORKDIR /app

# Copy requirements first to leverage Docker cache
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p /app/data/pdfs /app/data/processed /app/data/vector_db /app/static /app/tests

# Environment setup
ENV GOOGLE_APPLICATION_CREDENTIALS=/app/service-account.json

# Expose ports
EXPOSE 8000  # FastAPI
EXPOSE 7860  # Gradio
EXPOSE 8001  # Prometheus metrics

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/api/health || exit 1

# Command to run the application
CMD ["sh", "-c", "python -m main"]
