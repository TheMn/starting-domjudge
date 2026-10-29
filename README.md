# Starting DOMjudge

Run a complete [DOMjudge](https://www.domjudge.org) contest system (database, web server, judgehosts)
on **one Ubuntu machine** with Docker. Tested with DOMjudge 9.0.1. Needs Ubuntu 24.04 or newer (or any
Linux with cgroup v2 and kernel 5.19+), 4+ CPU cores, 8+ GB RAM and 40 GB of free disk.

| File | Purpose |
| --- | --- |
| `config.sh` | Settings: versions, passwords, port, number of judgehosts |
| `install.sh` | Installs Docker and downloads the images |
| `start.sh` | Starts everything and prints the admin password. Safe to run again. |
| `backup.sh` | Saves the database to `backups/` |

## Coming from the old version of this repo

The old scripts installed DOMjudge 8.2 and forced the kernel into cgroup v1 mode, which DOMjudge 9 and
Ubuntu 26.04 don't use. Undo that once:

```bash
sudo sed -i '/systemd.unified_cgroup_hierarchy=0/d' /etc/default/grub   # remove the line the old script added
sudo update-grub
sudo docker rm -f dj-mariadb domserver $(sudo docker ps -aq --filter name=judgehost)
sudo reboot
```

After the reboot, `stat -fc %T /sys/fs/cgroup` must print `cgroup2fs`.

## Install and start

```bash
git clone https://github.com/TheMn/starting-domjudge.git
cd starting-domjudge
nano config.sh    # change both passwords (before the first start!) and check TIMEZONE
./install.sh
./start.sh        # first start takes a few minutes; prints the admin password
```

Then open `http://<server>:12345`, log in as `admin`, and check *Jury > Config checker* and *Jury > Judgehosts*.
Your judgehosts are `judgehost-1-1`, `judgehost-2-2`, ... You can ignore `example-judgehost1`, which comes
from the demo data and stays disabled.

## Managing it remotely over SSH

Run everything above in an SSH session. To use the web interface from your own computer without
opening it to the internet, tunnel it:

```bash
ssh -L 12345:localhost:12345 user@server
```

Then browse to <http://localhost:12345> on your computer.

## Letting the contestants in

Contestants only need a browser. For lab PCs to reach a server at home:

1. On the home router, forward a port (e.g. `12345`) to the server's local IP, port `12345`.
   If the internet provider uses CGNAT, port forwarding won't work; ask the provider for a public IP.
2. Find the public IP (`curl ifconfig.me` on the server). The lab firewall must allow that IP. Home IPs can change,
   so check it again on contest day.
3. Test from the lab: `http://<public-IP>:12345`.
4. Recommended: accept connections only from the university's public IP. Docker bypasses `ufw`, so use:
   ```bash
   sudo iptables -I DOCKER-USER -p tcp -m conntrack --ctorigdstport 12345 --ctdir ORIGINAL ! -s <UNIVERSITY_IP> -j DROP
   ```
   This rule is lost on reboot; run it again after one. SSH tunnel access keeps working.

The site uses plain HTTP, so passwords travel unencrypted. Give teams contest-only passwords.

## Contest checklist

- Before: delete or disable the `demo` contest, upload problems with jury solutions, create the teams
  (*Jury > Import / export* for many), set contest times, and print team passwords.
- Set time limits from how the jury solutions run **on this server**.
- During: run `./backup.sh` every 15 to 30 minutes and copy the files elsewhere.
  Watch *Jury > Clarifications* and *Jury > Judgehosts*.
- Don't update or reboot the server on contest days. If it does reboot, everything starts again
  automatically; check with `sudo docker ps`.

## Useful commands

```bash
sudo docker ps -a                     # what is running
sudo docker logs -f domserver         # server log
sudo docker logs -f judgehost-1       # judgehost log ("No submissions in queue" = working)
sudo docker stop $(sudo docker ps -q) # stop everything (./start.sh starts it again)
```

Start from scratch (**deletes all contest data**):

```bash
sudo docker rm -f dj-mariadb domserver $(sudo docker ps -aq --filter name=judgehost-)
sudo docker volume rm dj-mariadb-data
```

To restore a backup, see the comment at the top of `backup.sh`.
