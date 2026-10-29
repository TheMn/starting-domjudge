# Starting DOMjudge

Helper scripts for running [DOMjudge](https://www.domjudge.org) with Docker on Ubuntu or Debian
(as root if `sudo` is not installed).
They start MariaDB, the DOMjudge server (domserver) and any number of judgehosts (workers).

- Trying it on a Windows laptop with WSL: see [docs/wsl-laptop.md](docs/wsl-laptop.md)
- Running a real contest in a lab: see [docs/contest-checklist.md](docs/contest-checklist.md)

## Scripts

| Script | What it does |
| --- | --- |
| `config.sh` | **All settings** (DOMjudge version, passwords, timezone, port, server URL). Every other script reads it. |
| `config_docker.sh` | Installs Docker and downloads the DOMjudge and MariaDB images. |
| `check_cgroups.sh` | Checks that a machine can run judgehosts and fixes the kernel options if needed. |
| `start_server.sh` | Starts MariaDB and the domserver, then prints the admin and judgehost passwords. |
| `start_worker.sh <ID>` | Starts judgehost number `<ID>`, pinned to CPU core `<ID>`. |
| `backup_db.sh` | Saves a compressed database dump to `backups/`. |
| `offline_images.sh save\|load` | Installs on machines without internet: `save` puts Docker and the images in `offline/` (copy it by USB), `load` installs them. |

All scripts can be run more than once: existing containers are restarted, not recreated.

## Start the server

1. Clone this repository and `cd` into it.
2. Edit `config.sh`. At least change `MYSQL_PASSWORD` and `MYSQL_ROOT_PASSWORD`.
   Do this **before** the first start: the database keeps the passwords it was created with.
3. Run `./config_docker.sh`
4. Run `./start_server.sh`. The first start takes a few minutes.
5. Open [http://localhost:12345](http://localhost:12345) and log in as `admin` with the password printed by the script.
6. Open *Jury > Config checker* and resolve any errors it reports.

## Start judgehosts

A judgehost must run on Linux and use the same DOMjudge version as the server.

On the **same machine** as the server:

1. Run `./check_cgroups.sh` and follow its instructions until it prints `OK`.
2. Run `./start_worker.sh 1` (and `2`, `3`, ... for more). Leave core 0 for the server and the database.

On a **separate judge machine**:

1. Clone this repository and copy `config.sh` from the server machine.
2. In `config.sh`, set `DOMSERVER_URL` to the server address, e.g. `http://192.168.1.10:12345/`,
   and `JUDGEDAEMON_PASSWORD` to the judgehost password printed by `start_server.sh`.
3. Run `./config_docker.sh`, then `./check_cgroups.sh` until it prints `OK`.
4. Run `./start_worker.sh 0`, `./start_worker.sh 1`, ... (one per CPU core at most).

Started judgehosts appear under *Jury > Judgehosts* within a minute. Follow one's log with
`sudo docker logs -f judgehost-0`.

## Useful commands

```bash
sudo docker ps -a                       # list containers and their state
sudo docker logs -f domserver           # server log
sudo docker logs -f judgehost-0         # judgehost log
sudo docker exec -it domserver cat /opt/domjudge/domserver/etc/initial_admin_password.secret
sudo docker exec -it domserver cat /opt/domjudge/domserver/etc/restapi.secret   # judgehost password
sudo docker stop judgehost-0 domserver dj-mariadb    # stop everything
```

Start from scratch (**deletes all contest data**):

```bash
sudo docker rm -f $(sudo docker ps -aq --filter name=judgehost-) domserver dj-mariadb
sudo docker volume rm dj-mariadb-data
```

## Troubleshooting

- **Judgehost exits with a cgroup error**: run `./check_cgroups.sh`. DOMjudge 9 uses cgroup v2 and needs
  kernel 5.19 or newer; Ubuntu 22.04's default kernel is 5.15. Install the HWE kernel or let the script switch to cgroup v1.
- **Judgehost says `401 Unauthorized`**: `JUDGEDAEMON_PASSWORD` is wrong. Read it from the server with the
  `restapi.secret` command above, or set a new password for the `judgehost` user in the web interface.
- **The judgehost password changed after recreating the domserver container**: a new domserver container generates
  a new password, but the database keeps the old one. Set a new password for the `judgehost` user in the web
  interface and use it in `config.sh`. To avoid this, restart containers instead of removing them.
- **domserver log shows `nginx ... Address family not supported`**: IPv6 is disabled on the machine
  (`ipv6.disable=1`). Re-enable it, or run
  `sudo docker exec domserver sed -i --follow-symlinks '/listen \[::\]/d' /etc/nginx/sites-enabled/default && sudo docker exec domserver supervisorctl restart nginx`.
- **`docker pull` fails** (403, 429 or timeouts): see "Docker images" in [docs/contest-checklist.md](docs/contest-checklist.md).
- **`/bin/bash^M: bad interpreter`**: the scripts got Windows line endings. Clone inside Linux/WSL, not from Windows.

## See also

- [DOMjudge manual](https://www.domjudge.org/docs/manual/9.0/)
- [DOMjudge Docker images documentation](https://github.com/DOMjudge/domjudge-packaging/tree/main/docker)
- [domjudge/domserver - Docker Hub](https://hub.docker.com/r/domjudge/domserver)
- [domjudge/judgehost - Docker Hub](https://hub.docker.com/r/domjudge/judgehost)
