
FROM python:3.11-slim

WORKDIR /app

# Build tools and libraries needed by InsightFace and OpenCV
RUN apt-get update && apt-get install -y --no-install-recommends \
    g++ \
    gcc \
    make \
    cmake \
    libglib2.0-0 \
    libgl1 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN pip install --no-cache-dir --upgrade pip setuptools wheel \
    && pip install --no-cache-dir -r requirements.txt

COPY app ./app

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
