# Licensed IRIS Container Setup (required for full green)

The POC needs a **licensed InterSystems IRIS container image** from the
InterSystems Container Registry (ICR). The public `iris-community` image
does **not** include ISCAgent (mirroring) or `Ens.Director` (interop
production), even when an enterprise license key is mounted.

## 1. Authenticate to the registry

1. Open https://containers.intersystems.com/contents
2. Log in with your **WRC** credentials
3. Copy the `docker login` command shown (uses a registry token, not your
   WRC web password)

```bash
docker login -u="<wrc-user>" -p="<token>" containers.intersystems.com
```

## 2. Pull the IRIS image

From the same portal, copy the `docker pull` command for your version.
Example:

```bash
docker pull containers.intersystems.com/intersystems/iris:latest-em
```

## 3. Provide the license key

```bash
export IRIS_KEY="/path/to/your/license.ISCkey"

ansible-playbook playbooks/prepare.yml -i inventories/poc \
  -e "iris_key_source=${IRIS_KEY}"
```

Keys are copied to `irisa/iris.key` and `irisb/iris.key` (git-ignored).

## 4. Bring up the licensed stack

```bash
ansible-playbook playbooks/stack_up.yml -i inventories/poc \
  -e iris_image=containers.intersystems.com/intersystems/iris:latest-em
```

Do **not** use `docker-compose.community.yml.example` with licensed images.

## 5. Run the full Topic 1 flow

```bash
ansible-playbook playbooks/site_full.yml -i inventories/poc \
  -e "iris_key_source=${IRIS_KEY}"
```

## Capability matrix

| Feature | Community image | Licensed `intersystems/iris` image |
| ------- | ----------------- | --------------------------------- |
| Namespace / DB / web app / security | Yes | Yes |
| Security sync primary→backup | Yes | Yes |
| Mirroring (ISCAgent) | No | Yes |
| Interop production auto-start | No | Yes |
| Full `configure.yml` green | No | Yes |
