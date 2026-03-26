# 🛍️ Luxe Shop — E-Commerce App with Full DevOps Pipeline

A production-ready e-commerce web application deployed via a complete **GitHub → Jenkins CI/CD → Docker → EC2** pipeline.

---

## 📁 Project Structure

```
luxe-shop/
├── src/
│   └── index.html          # Main application (HTML/CSS/JS)
├── nginx/
│   └── nginx.conf          # Custom Nginx config
├── scripts/
│   └── ec2-setup.sh        # One-time EC2 bootstrap script
├── Dockerfile              # Multi-stage Docker build
├── docker-compose.yml      # Local development
├── Jenkinsfile             # Full CI/CD pipeline
├── .gitignore
├── .dockerignore
└── README.md
```

---

## 🚀 CI/CD Pipeline Flow

```
GitHub Push
    │
    ▼
Jenkins (Checkout)
    │
    ▼
Lint & Validate
    │
    ▼
Docker Build Image
    │
    ▼
Test Container (smoke test on :8099)
    │
    ▼
Push to Docker Hub
    │
    ▼
SSH → EC2 → Pull & Run Container
    │
    ▼
Post-Deploy Smoke Test ✅
```

---

## ⚙️ Step-by-Step Setup

### 1️⃣ Push Code to GitHub

```bash
git init
git add .
git commit -m "initial commit"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/luxe-shop.git
git push -u origin main
```

---

### 2️⃣ Launch EC2 Instance

| Setting         | Value                        |
|----------------|------------------------------|
| AMI            | Ubuntu 22.04 LTS             |
| Instance Type  | t2.micro (free tier) or t3.small |
| Key Pair       | Create & download `.pem`     |
| Security Group | Allow: SSH (22), HTTP (80)   |

**Bootstrap EC2 (run once after SSH):**

```bash
# From your local machine
scp -i your-key.pem scripts/ec2-setup.sh ubuntu@<EC2_PUBLIC_IP>:~
ssh -i your-key.pem ubuntu@<EC2_PUBLIC_IP>
sudo bash ec2-setup.sh
```

---

### 3️⃣ Install & Configure Jenkins

**Option A — Run Jenkins on a separate EC2 (recommended):**

```bash
# Install Java
sudo apt-get install -y openjdk-17-jdk

# Install Jenkins
curl -fsSL https://pkg.jenkins.io/debian/jenkins.io-2023.key \
  | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian binary/ \
  | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt-get update && sudo apt-get install -y jenkins docker.io
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

Access Jenkins at: `http://<JENKINS_EC2_IP>:8080`

---

### 4️⃣ Configure Jenkins Credentials

Go to **Manage Jenkins → Credentials → Global** and add:

| ID                      | Type                  | Description                    |
|-------------------------|-----------------------|--------------------------------|
| `dockerhub-credentials` | Username/Password     | Docker Hub login               |
| `ec2-ssh-key`           | SSH Private Key       | Your `.pem` file contents      |

---

### 5️⃣ Create Jenkins Pipeline Job

1. New Item → **Pipeline**
2. Under **Pipeline**, choose **Pipeline script from SCM**
3. SCM: **Git** → enter your GitHub repo URL
4. Script Path: `Jenkinsfile`
5. Add **GitHub webhook** in repo settings:
   - URL: `http://<JENKINS_IP>:8080/github-webhook/`
   - Events: **Push**

---

### 6️⃣ Configure Jenkins Environment Variables

Go to **Manage Jenkins → Configure System → Global Properties → Environment Variables:**

| Variable           | Value                          |
|--------------------|-------------------------------|
| `DOCKERHUB_USERNAME` | your Docker Hub username     |
| `EC2_HOST`         | your EC2 public IP or domain  |

---

## 🐳 Local Development

```bash
# Build and run locally
docker-compose up --build

# Visit http://localhost:80

# Stop
docker-compose down
```

---

## 🔧 Manual Docker Commands

```bash
# Build
docker build -t luxe-shop:latest .

# Run
docker run -d -p 80:80 --name luxe-shop-app luxe-shop:latest

# Check health
curl http://localhost/health

# View logs
docker logs luxe-shop-app

# Stop & remove
docker stop luxe-shop-app && docker rm luxe-shop-app
```

---

## 🔒 Security Notes

- **Never** commit `.pem` files or `.env` files (already in `.gitignore`)
- Use **IAM roles** for EC2 instead of access keys when possible
- Restrict EC2 Security Group SSH to your IP only
- For production: add HTTPS with Let's Encrypt + Certbot

---

## 📊 Jenkins Pipeline Stages

| Stage | Description |
|-------|-------------|
| ✅ Checkout | Clone repo from GitHub |
| ✅ Lint & Validate | Check all required files exist |
| ✅ Build Docker Image | Build with build number tag |
| ✅ Test Container | Spin up & hit health endpoint |
| ✅ Push to Registry | Push tagged + latest to Docker Hub |
| ✅ Deploy to EC2 | SSH, pull, restart container |
| ✅ Smoke Test | Hit EC2 /health endpoint |

---

## 🌐 After Deployment

Your app will be live at:
```
http://<EC2_PUBLIC_IP>
```

---

## 📝 License

MIT — free to use and modify.
