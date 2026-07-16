# 停止并移除 iris 容器
foreach ($instance in @("irisa", "irisb")) {
	docker stop $instance
	docker rm $instance
	Remove-Item -Recurse -Force ".\\$instance\\durable" -ErrorAction SilentlyContinue
}

docker stop arbiter
docker rm arbiter
Remove-Item -Recurse -Force .\arbiter\durable -ErrorAction SilentlyContinue

# 停止并移除 webgateway 容器
foreach ($gateway in @("webgatewaya", "webgatewayb")) {
	docker stop $gateway
	docker rm $gateway
	Remove-Item -Recurse -Force ".\\$gateway\\durable" -ErrorAction SilentlyContinue
}