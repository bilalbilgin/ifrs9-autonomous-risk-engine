FROM python:3.10-slim

WORKDIR /app

# Install PostgreSQL client for healthchecks and migration validation
RUN apt-get update && apt-get install -y postgresql-client && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Cloud Run default port specification
ENV PORT=8080
EXPOSE 8080

CMD ["python", "-m", "pytest", "tests/"]