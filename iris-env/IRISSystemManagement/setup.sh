source parameters.cfg

#; Prior to running docker compose, ensure the instances have
#; read-write permissions to the bindmounts.
for path in irisa irisb webgatewaya webgatewayb arbiter; do
	chmod -R 755 "$path"
done

docker compose build
docker compose up -d

# Wait for containers to start, then install arping and curl
echo "Waiting for containers to start..."
sleep 10
for instance in irisa irisb; do
  echo "Installing arping and curl on $instance..."
  docker exec -u root "$instance" /bin/bash -c "apt-get update && apt-get install -y arping curl"
done

# SSL SETUP - omit if opting out of SSL
# It takes several seconds for iris to spin up, so wait for it
# before configuring it for SSL. Adjust sleep time if need be.
# sleep 30
# for instance in irisa irisb; do
#   docker exec "$instance" /bin/sh -c "/iris-shared/configure.sh"
# done
