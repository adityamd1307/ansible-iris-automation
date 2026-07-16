# Licensed IRIS Container Setup (required for full green)

The POC needs a **licensed InterSystems IRIS container image** from the
InterSystems Container Registry (ICR). The public `iris-community` image
does **not** include ISCAgent (mirroring) or `Ens.Director` (interop
production), even when an enterprise license key is mounted.

Use **`containers.intersystems.com/intersystems/iris:latest-cd`** (not
`irishealth`) for full Topic 1 acceptance: mirroring, interoperability,
and production auto-start. The `latest-cd` tag is multi-arch and pulls
**arm64** on Apple Silicon automatically (there is no separate
`-arm64` suffix tag in ICR).

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
docker pull containers.intersystems.com/intersystems/iris:latest-cd
docker pull containers.intersystems.com/intersystems/webgateway:latest-cd
```

## 3. Provide the license key

If the key path contains spaces, pass it as JSON or use a symlink:

```bash
ln -sf "/path/to/iris 6.key" /tmp/iris-arm.key
export IRIS_KEY_SOURCE=/tmp/iris-arm.key

ansible-playbook playbooks/prepare.yml -i inventories/poc \
  -e "iris_key_source=${IRIS_KEY_SOURCE}"
```

Keys are copied to `irisa/iris.key` and `irisb/iris.key` (git-ignored).

## 4. Bring up the licensed stack

```bash
ansible-playbook playbooks/stack_up.yml -i inventories/poc \
  -e iris_image=containers.intersystems.com/intersystems/iris:latest-cd \
  -e webgateway_image=containers.intersystems.com/intersystems/webgateway:latest-cd
```

`prepare.yml` seeds Bryan-compatible Web Gateway `CSP.ini` / `CSP.conf`
files (superserver port **1972**, `CSPSystem` user) and clears stale
`webgateway*/durable` state so portals serve IRIS on first boot.

Do **not** use `docker-compose.community.yml.example` with licensed images.

## 5. Run the full Topic 1 flow

```bash
ansible-playbook playbooks/site_full.yml -i inventories/poc \
  -e "iris_key_source=${IRIS_KEY_SOURCE}"
```

## Capability matrix

| Feature | Community image | Licensed `intersystems/iris` image |
| ------- | ----------------- | --------------------------------- |
| Namespace / DB / web app / security | Yes | Yes |
| Security sync primary→backup | Yes | Yes |
| Mirroring (ISCAgent) | No | Yes |
| Interop production auto-start | No | Yes |
| Full `configure.yml` green | No | Yes |
