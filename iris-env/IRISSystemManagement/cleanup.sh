for instance in irisa irisb; do
	docker stop "$instance"
	docker rm "$instance"
	rm -rf "$instance/durable"
done

docker stop arbiter
docker rm arbiter
rm -rf arbiter/durable

for gateway in webgatewaya webgatewayb; do
	docker stop "$gateway"
	docker rm "$gateway"
	rm -rf "$gateway/durable"
done
