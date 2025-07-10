name: GPU Accelerated CI/CD Pipeline

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

env:
  DOCKER_IMAGE: ghcr.io/furkan-cyber/ragnttdata:latest
  PYTHON_VERSION: '3.9'
  COMPOSE_FILE: docker-compose.gpu.yml

jobs:
  test:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: ${{ env.PYTHON_VERSION }}
        cache: 'pip'
    
    - name: Cache dependencies
      uses: actions/cache@v3
      with:
        path: |
          ~/.cache/pip
          ~/.cache/nltk
        key: ${{ runner.os }}-python-${{ env.PYTHON_VERSION }}-${{ hashFiles('requirements.txt') }}
    
    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install -r requirements.txt
        python -m nltk.downloader punkt stopwords
    
    - name: Run tests with coverage
      run: |
        pytest -v -s --cov=. --cov-report=xml --durations=10 main.py
    
    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3

  build-and-push:
    needs: test
    runs-on: ubuntu-latest
    timeout-minutes: 30
    permissions:
      contents: read
      packages: write
    steps:
    - uses: actions/checkout@v3
    
    # Set up NVIDIA container toolkit for GPU support
    - name: Set up NVIDIA Container Toolkit
      run: |
        distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
        curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
        curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
        sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
        sudo systemctl restart docker
    
    - name: Set up Docker Buildx with GPU support
      uses: docker/setup-buildx-action@v2
      with:
        driver: docker-container
        buildkitd-flags: --allow-insecure-entitlement security.insecure --allow-insecure-entitlement network.host
        install: true
    
    - name: Cache Docker layers
      uses: actions/cache@v3
      with:
        path: /tmp/.buildx-cache
        key: ${{ runner.os }}-buildx-${{ github.sha }}
        restore-keys: |
          ${{ runner.os }}-buildx-
    
    - name: Log in to GitHub Container Registry
      uses: docker/login-action@v2
      with:
        registry: ghcr.io
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
    
    - name: Build and push GPU-optimized Docker image
      uses: docker/build-push-action@v4
      with:
        context: .
        push: true
        tags: ${{ env.DOCKER_IMAGE }}
        labels: |
          org.opencontainers.image.source=${{ github.repository_url }}
        cache-from: type=gha,scope=${{ github.ref }}-${{ github.workflow }}
        cache-to: type=gha,mode=max,scope=${{ github.ref }}-${{ github.workflow }}
        platforms: linux/amd64
        secrets: |
          GCP_SA_KEY=${{ secrets.GCP_SA_KEY }}
          GCP_PROJECT_ID=${{ secrets.GCP_PROJECT_ID }}
          GCP_BUCKET_NAME=${{ secrets.GCP_BUCKET_NAME }}
        outputs: type=docker,name=${{ env.DOCKER_IMAGE }}
    
    - name: Test GPU image
      run: |
        docker run --gpus all ${{ env.DOCKER_IMAGE }} python -c "import torch; print(torch.cuda.is_available()); print('GPU:', torch.cuda.get_device_name(0))"

  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    timeout-minutes: 20
    if: github.ref == 'refs/heads/main'
    steps:
    - uses: actions/checkout@v3
    
    - name: Authenticate to Google Cloud
      uses: google-github-actions/auth@v1
      with:
        credentials_json: ${{ secrets.GCP_SA_KEY }}
    
    - name: Set up Cloud SDK
      uses: google-github-actions/setup-gcloud@v1
    
    - name: Deploy to Vertex AI with GPU
      run: |
        gcloud config set project ${{ secrets.GCP_PROJECT_ID }}
        gcloud auth configure-docker
        
        # Deploy with GPU acceleration
        gcloud ai endpoints deploy-model ${{ secrets.VERTEX_AI_ENDPOINT }} \
          --region=${{ secrets.GCP_REGION }} \
          --model=${{ secrets.VERTEX_AI_MODEL }} \
          --display-name=rag-gpu-service \
          --machine-type=n1-standard-4 \
          --accelerator=count=1,type=nvidia-tesla-t4 \
          --min-replica-count=1 \
          --max-replica-count=3 \
          --container-image-uri=${{ env.DOCKER_IMAGE }} \
          --container-command="python" \
          --container-args="-m,main" \
          --service-account=${{ secrets.GCP_SERVICE_ACCOUNT }}
