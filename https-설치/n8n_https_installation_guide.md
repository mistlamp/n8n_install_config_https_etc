# n8n HTTPS 설치 및 설정 가이드

Ubuntu 서버에서 n8n을 설치하고 HTTPS로 서비스하기 위한 완전한 가이드입니다.

---

## 📋 사전 요구 사항

- Ubuntu 서버 (20.04 LTS 이상 권장)
- 도메인 (예: `n8n-cho.ddns.net`)
- 서버의 80, 443 포트 개방

---

## 1️⃣ n8n 설치 (Docker)

### Docker 설치

```bash
sudo apt update
sudo apt install -y docker.io docker-compose

# Docker 서비스 시작
sudo systemctl start docker
sudo systemctl enable docker
```

### n8n 컨테이너 설치

제공된 스크립트를 사용하여 n8n을 설치합니다:

```bash
# 스크립트 실행
chmod +x ./n8n-설치/install_docker_n8n_1.sh
./n8n-설치/install_docker_n8n_1.sh
```

> 📁 **스크립트 위치**: `n8n-설치/install_docker_n8n_1.sh`

**스크립트 주요 기능:**
- Watchtower 자동 업데이트 라벨 설정
- 데이터 경로: `/home/ubuntu/n8n`
- 타임존: `Asia/Seoul`
- HTTPS 환경 변수 자동 설정 (N8N_PROTOCOL, WEBHOOK_URL 등)

> **확인**: `curl http://127.0.0.1:5678` 으로 n8n 응답 확인

---

## 2️⃣ Nginx 설치

```bash
sudo apt update
sudo apt install -y nginx
```

---

## 3️⃣ Let's Encrypt SSL 인증서 발급

### Certbot 설치

```bash
sudo apt install -y certbot python3-certbot-nginx
```

### 인증서 발급

```bash
# 도메인을 본인의 도메인으로 변경
sudo certbot --nginx -d n8n-cho.ddns.net
```

프롬프트에 따라 이메일 입력 및 약관 동의

---

## 4️⃣ Nginx 설정

### 4.1 nginx.conf 수정 (보안 강화)

```bash
sudo nano /etc/nginx/nginx.conf
```

**SSL Settings 섹션을 다음으로 교체:**

```nginx
##
# SSL Settings
##

ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 1d;
```

### 4.2 n8n 사이트 설정 생성

```bash
sudo nano /etc/nginx/sites-available/n8n.conf
```

**아래 내용 입력 (도메인 수정 필요):**

```nginx
server {
    listen 80;
    server_name n8n-cho.ddns.net;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name n8n-cho.ddns.net;

    ssl_certificate /etc/letsencrypt/live/n8n-cho.ddns.net/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/n8n-cho.ddns.net/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location / {
        proxy_pass http://127.0.0.1:5678/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # --- WebSocket Support ---
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_set_header Origin $scheme://$host;
        proxy_cache off;
        proxy_buffering off;

        # --- Prevent connection timeout ---
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }
}
```

### 4.3 사이트 활성화

```bash
# 심볼릭 링크 생성
sudo ln -s /etc/nginx/sites-available/n8n.conf /etc/nginx/sites-enabled/

# 기본 사이트 비활성화 (선택)
sudo rm /etc/nginx/sites-enabled/default
```

---

## 5️⃣ 적용 및 시작

```bash
# Nginx 설정 테스트
sudo nginx -t

# Nginx 재시작
sudo systemctl reload nginx

# Nginx 자동 시작 설정
sudo systemctl enable nginx
```

---

## 6️⃣ 확인

브라우저에서 접속:
```
https://n8n-cho.ddns.net
```

---

## 🔄 유지보수

### SSL 인증서 자동 갱신 확인

```bash
# 갱신 테스트
sudo certbot renew --dry-run
```

### n8n 업데이트

**Docker:**
```bash
sudo docker pull n8nio/n8n
sudo docker stop n8n
sudo docker rm n8n
# 위의 docker run 명령어 다시 실행
```

**npm:**
```bash
sudo npm update -g n8n
```

---

## 📁 주요 파일 경로

| 파일 | 경로 |
|------|------|
| Nginx 메인 설정 | `/etc/nginx/nginx.conf` |
| n8n 사이트 설정 | `/etc/nginx/sites-available/n8n.conf` |
| SSL 인증서 | `/etc/letsencrypt/live/{도메인}/` |
| Nginx 로그 | `/var/log/nginx/` |

---

## ⚠️ 문제 해결

### Nginx 오류 확인
```bash
sudo nginx -t
sudo tail -f /var/log/nginx/error.log
```

### n8n 상태 확인
```bash
# Docker
sudo docker logs n8n

# 포트 확인
sudo netstat -tlnp | grep 5678
```

### 방화벽 설정
```bash
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable
```

---

> 📅 작성일: 2026-01-17  
> 🔧 테스트 환경: Ubuntu, Nginx, Let's Encrypt, n8n
