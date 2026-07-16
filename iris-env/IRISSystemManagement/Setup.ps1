. .\parameters.ps1

$env:IRISTAG = $IRISTAG
$env:WEBGTAG = $WEBGTAG

# 构建并启动 Docker Compose
docker compose build 
docker compose up -d

# 等待容器启动后安装 arping
Write-Host "Waiting for containers to start..."
Start-Sleep -Seconds 10
foreach ($instance in @("irisa", "irisb")) {
    Write-Host "Installing arping on $instance..."
    docker exec -u root $instance /bin/bash -c "apt-get update && apt-get install -y arping curl"
}

# SSL 配置（如需启用，取消注释以下内容）
# Start-Sleep -Seconds 30
# foreach ($instance in @("irisa", "irisb")) {
#     docker exec $instance /bin/sh -c "/iris-shared/configure.sh"
# }