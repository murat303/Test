#!/bin/bash

echo "=== Nakama Docker Kurulum (Rocky Linux) ==="

# Rocky Linux için Docker kurulumu
echo "1. Docker kuruluyor (Rocky Linux)..."
dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
dnf install -y docker-ce docker-ce-cli containerd.io
systemctl start docker
systemctl enable docker

# Docker Compose kurulumu
echo "2. Docker Compose kuruluyor..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Nakama dizini oluştur
mkdir -p /opt/nakama
cd /opt/nakama

# Docker Compose dosyasını oluştur
echo "3. Docker Compose dosyası oluşturuluyor..."
cat > docker-compose.yml << 'EOF'
version: '3'
services:
  postgres:
    container_name: postgres
    image: postgres:12.2-alpine
    environment:
      - POSTGRES_DB=nakama
      - POSTGRES_PASSWORD=localdb
      - POSTGRES_USER=postgres
    volumes:
      - data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "postgres", "-d", "nakama"]
      interval: 3s
      timeout: 3s
      retries: 5

  nakama:
    container_name: nakama
    image: heroiclabs/nakama:3.21.1
    entrypoint:
      - "/bin/sh"
      - "-ecx"
      - "/nakama/nakama migrate up --database.address postgres:localdb@postgres:5432/nakama && exec /nakama/nakama --name nakama1 --database.address postgres:localdb@postgres:5432/nakama --logger.level INFO --session.token_expiry_sec 7200"
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    ports:
      - "7349:7349"
      - "7350:7350"
      - "7351:7351"

volumes:
  data:
EOF

# Firewall portları aç (Rocky Linux - firewalld)
echo "4. Firewall portları açılıyor..."
if command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-port=7349/tcp
    firewall-cmd --permanent --add-port=7350/tcp
    firewall-cmd --permanent --add-port=7351/tcp
    firewall-cmd --permanent --add-port=5432/tcp
    firewall-cmd --reload
fi

# Nakama'yı başlat
echo "5. Nakama başlatılıyor..."
docker-compose up -d

echo "=== Kurulum Tamamlandı ==="
echo "Nakama Console: http://51.159.39.9:7351"
echo "API Endpoint: http://51.159.39.9:7350"
echo ""
echo "Durumu kontrol et: docker-compose ps"
echo "Logları görüntüle: docker-compose logs -f nakama" 