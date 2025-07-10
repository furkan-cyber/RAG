# Base image
FROM python:3.9-slim as builder

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    libssl-dev \
    libffi-dev \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements first to leverage Docker cache
COPY requirements.txt .

# Install Python dependencies
RUN pip install --user --no-cache-dir -r requirements.txt

# Runtime image
FROM python:3.9-slim

# Copy only necessary files from builder
COPY --from=builder /root/.local /root/.local
COPY --from=builder /usr/lib/python3.9/site-packages /usr/lib/python3.9/site-packages

# Ensure scripts in .local are usable
ENV PATH=/root/.local/bin:$PATH
ENV PYTHONPATH=/usr/lib/python3.9/site-packages:$PYTHONPATH

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy application code
COPY . .

# Install NLTK data
RUN python -m nltk.downloader punkt stopwords

# Create necessary directories
RUN mkdir -p /app/data/pdfs /app/data/processed /app/data/vector_db /app/static /app/tests

# Environment setup
ENV GOOGLE_APPLICATION_CREDENTIALS=/app/service-account.json

# Expose ports
EXPOSE 8000 7860 8001

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/api/health || exit 1

# Command to run the application
CMD ["python", "-m", "main"]
