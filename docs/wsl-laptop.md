# Trying DOMjudge on a Windows laptop with WSL

This runs the same Ubuntu + Docker setup as the lab server, inside WSL 2 on your laptop.
It's for learning the system and preparing the contest (problems, teams, settings). Don't use it to set time limits:
judging speed on a laptop differs from the lab machines.

## 1. Prepare WSL (Windows PowerShell)

```powershell
wsl --update
wsl --install -d Ubuntu-22.04      # skip if you already have an Ubuntu distro
wsl -l -v                          # Ubuntu-22.04 must show VERSION 2
```

Open the Ubuntu terminal and create your Linux user when asked.

## 2. Enable systemd in WSL (Ubuntu terminal)

Docker runs as a service, which is easiest with systemd:

```bash
sudo tee /etc/wsl.conf <<'EOF'
[boot]
systemd=true
EOF
```

Then in PowerShell run `wsl --shutdown`, and open Ubuntu again. Check that `ps -p 1 -o comm=` prints `systemd`.

> **Docker Desktop:** if you have Docker Desktop installed, either quit it or turn off
> *Settings > Resources > WSL integration* for this distro. Two Docker engines fighting over
> the same `docker` command cause confusing errors. These scripts install Docker inside Ubuntu,
> the same way it will be on the lab server.

## 3. Get the scripts (Ubuntu terminal)

Clone **inside the Linux file system** (`~`), not under `/mnt/c/...`. Windows folders are slow
in WSL and break file permissions.

```bash
cd ~
git clone https://github.com/TheMn/starting-domjudge.git
cd starting-domjudge
```

## 4. Install Docker and start the server

```bash
./config_docker.sh        # installs docker.io and downloads ~1.1 GB of images (~4.5 GB unpacked)
./start_server.sh         # first start takes a few minutes
```

If `docker pull` fails, see "Docker images" in [contest-checklist.md](contest-checklist.md).

At the end the script prints something like:

```
DOMjudge is running at http://localhost:12345/
Admin login:        admin / aGp-iZ4xgG6lbgpQ
Judgehost password: 7+3kpaUcDbfkc1Oc9A/FfdeJm/vwoMI0
```

Open <http://localhost:12345> in your **Windows** browser (WSL forwards `localhost`) and log in as `admin`.

## 5. Start a judgehost

```bash
./check_cgroups.sh        # must print "OK"
./start_worker.sh 1
sudo docker logs -f judgehost-1     # Ctrl+C to stop following
```

The log should end with `No submissions in queue ... waiting...`.
If `check_cgroups.sh` complains about the kernel, run `wsl --update` and `wsl --shutdown` in PowerShell and try again
(current WSL ships kernel 6.x).

## 6. Check that judging works

A fresh install contains a **demo** contest with three problems and a team user called `demo`.

1. In the web interface go to *Jury > Config checker*. Read the warnings; most are fine for a test.
2. Go to *Jury > Users > demo*, click *Edit* and set a password.
3. Log in as `demo` in a private browser window and submit a solution for problem A ("Hello World"):

   ```c
   #include <stdio.h>
   int main() { printf("Hello world!\n"); return 0; }
   ```

4. Within seconds it should show **CORRECT**. Also try a wrong answer and an infinite loop
   to see **WRONG-ANSWER** and **TIMELIMIT**.

## 7. Practice the contest setup

The laptop is the right place to rehearse everything you'll do on the lab server:

- Create the contest (*Jury > Contests*): start time, end time, scoreboard freeze, and **Activate** time.
- Upload your problems as ZIP packages (*Jury > Problems > Import*), with test data and jury solutions.
- Create teams and team users. For many teams, import them (*Jury > Import / export*) and
  print the generated passwords.
- Choose the allowed languages (*Jury > Languages*): typically C, C++, Java, Python 3.
- Log in as a team in a private window and walk through submitting and asking a clarification.
- Practise `./backup_db.sh` and restoring from a backup.

Write down every setting you change. You'll repeat them on the lab server.

## 8. Letting other devices on your network reach the laptop (optional)

By default WSL is only reachable from your own laptop. For a test with friends' laptops or phones:

- **Windows 11 22H2+**: create `%UserProfile%\.wslconfig` with
  ```ini
  [wsl2]
  networkingMode=mirrored
  ```
  then `wsl --shutdown`. Others open `http://<your-laptop-IP>:12345`.
- In both cases allow the port in Windows Firewall (PowerShell as Administrator):
  ```powershell
  New-NetFirewallRule -DisplayName "DOMjudge" -Direction Inbound -Protocol TCP -LocalPort 12345 -Action Allow
  ```

## 9. Stopping and cleaning up

- Containers restart automatically when WSL starts again. To stop them:
  `sudo docker stop judgehost-1 domserver dj-mariadb`.
- WSL can use a lot of memory while DOMjudge runs. `wsl --shutdown` in PowerShell frees it.
- To start over with an empty database, see "Start from scratch" in the [README](../README.md).
