# Running the contest in the university lab

Setup assumed here:

- **One Ubuntu 22.04 server** runs MariaDB and the domserver (the web interface).
- **Judgehosts** run on Linux. They can run on the server itself or on extra Ubuntu machines.
- **Contestant PCs run Windows.** They only need a web browser: teams submit at
  `http://<server-IP>:12345`. Nothing from this repository is installed on them.

## Timeline

| When | What |
| --- | --- |
| Now to Oct 31 | Learn DOMjudge on your laptop ([wsl-laptop.md](wsl-laptop.md)). Prepare problem packages, team list, contest settings. Run `./offline_images.sh save` and copy the repository folder to a USB drive. |
| By Nov 1 | Get access to the lab server. Install it (sections 1 to 4 below). Upload the real problems and **set time limits on the lab judgehosts**. Create the test-round contest and team accounts. |
| **Nov 2: test round** | Full rehearsal: same machines, same network, same procedure as the real day. Note every problem. |
| Nov 3 | Fix what went wrong. Create the real contest (section 6). Take a backup. Print team passwords. |
| **Nov 4: contest** | Follow the contest-day checklist (section 7). |

## 1. Questions to settle with the lab admins first

- [ ] **Server IP address.** It must not change between Nov 2 and Nov 4. Ask for a static IP or a DHCP reservation.
- [ ] **Can contestant PCs reach the server** on port 12345 (or 80)? Test from one Windows PC with a browser.
- [ ] **Internet blocking for contestants.** Contestant PCs should reach *only* the DOMjudge server
      (and any allowed documentation). This is a firewall/proxy job for the lab admins, not something DOMjudge does.
- [ ] **Which Linux machines can run judgehosts**, and how many CPU cores they have.
      Each judgehost uses one core. A small contest (under ~50 teams, 3 to 4 hours) is fine with 2 to 4 judgehosts.
- [ ] **sudo access** on the server and the judge machines.
- [ ] **Internet on the server** (for `apt` and `docker pull`). If there's none, bring the images on USB (section 2).
- [ ] **Power and reboots.** Make sure no automatic updates or reboots happen on Nov 2 and Nov 4.
- [ ] **Compilers and IDEs** on the Windows PCs are the lab's job, but check that teams' local versions roughly match
      the judge (GCC, Java, Python 3).

## 2. Docker images

The server and judge machines need three images (about 4 GB in total):
`mariadb:11.8`, `domjudge/domserver:9.0.1`, `domjudge/judgehost:9.0.1`.

`config_docker.sh` pulls them from Docker Hub. Three things can break this:

- **Docker Hub can block some countries** (HTTP 403 "export control regulations"). Then configure a registry mirror
  that works in your country in `/etc/docker/daemon.json`, e.g.
  ```json
  { "registry-mirrors": ["https://<mirror-address>"] }
  ```
  and `sudo systemctl restart docker`. Or use the offline method below.
- **Rate limits** (HTTP 429). Docker Hub limits anonymous pulls per IP address, and a whole university often shares
  one IP. Retry later, or `docker login` with a free account.
- **Slow or filtered network.**

**USB method (no internet needed on the lab machines):** on your laptop (WSL), where downloading works:

```bash
./offline_images.sh save                    # server runs Ubuntu 22.04
./offline_images.sh save ubuntu noble       # server runs Ubuntu 24.04
./offline_images.sh save debian bookworm    # server runs Debian 12
./offline_images.sh save debian trixie      # server runs Debian 13
```

Not sure which? Run `grep VERSION_CODENAME /etc/os-release` on the server.
This creates an `offline/` folder (about 1.2 GB) with the three images, plus Docker and every package it
depends on for that system.
Copy the **whole repository folder** to a USB drive formatted as **exFAT** (FAT32 can't hold files over 4 GB).
On the lab machine, copy the folder to the home directory, then:

```bash
cd ~/starting-domjudge
chmod +x *.sh                     # USB drives can lose the "executable" flag
./offline_images.sh load          # installs Docker if missing, then loads the images
```

Don't run `config_docker.sh` on an offline machine. It needs internet for `apt`.

**On Debian**, `sudo` is often missing. Then run the scripts as root: `su -`, `cd` to the folder,
and run them the same way. `load` also installs `sudo`; to use it as a normal user afterwards, run
`usermod -aG sudo <user>` as root and log in again. Debian 12 and 13 kernels are new enough for DOMjudge 9,
so `check_cgroups.sh` should print `OK` without changes.

## 3. Install the server

```bash
git clone https://github.com/TheMn/starting-domjudge.git   # or copy the folder from USB
cd starting-domjudge
nano config.sh             # set new MYSQL_PASSWORD and MYSQL_ROOT_PASSWORD; maybe DOMSERVER_PORT=80
./config_docker.sh         # without internet: ./offline_images.sh load instead
./start_server.sh
```

Save the printed **admin password** and **judgehost password** somewhere safe. Then:

- [ ] Log in as admin. Change the admin password (*Jury > Users > admin*).
- [ ] Open *Jury > Config checker*. Fix errors; read the warnings.
- [ ] From a Windows contestant PC, open `http://<server-IP>:12345`.

If the page doesn't load from other PCs but works on the server itself, check the server firewall:
`sudo ufw status` (allow it with `sudo ufw allow 12345/tcp`).

## 4. Install the judgehosts

On **each** judge machine (or on the server itself):

```bash
./check_cgroups.sh
```

Ubuntu 22.04 may still have kernel **5.15**, which is too old for DOMjudge 9 on cgroup v2. The script tells you
what to do. The recommended fix is the newer kernel:

```bash
sudo apt install -y linux-generic-hwe-22.04
sudo reboot
./check_cgroups.sh        # now it should print OK
```

The alternative, and the only option without internet, is letting the script switch the machine to cgroup v1
(it asks first; needs a reboot).

Then:

- **Judgehosts on the server itself:** `./start_worker.sh 1`, `./start_worker.sh 2`, ... Leave core 0
  for the web server and database.
- **Separate judge machine:** in `config.sh` set
  `DOMSERVER_URL=http://<server-IP>:12345/` and `JUDGEDAEMON_PASSWORD=<judgehost password>`, then
  `./start_worker.sh 0`, `./start_worker.sh 1`, ...

Check *Jury > Judgehosts*: every judgehost should be listed and checked in recently.

Judgehosts need Linux and cgroups, so running them on the Windows contestant PCs is not an option.

## 5. Problems and time limits

- Problems are uploaded as ZIP packages (*Jury > Problems > Import*), in the
  [ICPC problem package format](https://www.domjudge.org/docs/manual/9.0/problem-format.html):
  `problem.yaml`, `data/sample/`, `data/secret/`, and jury solutions in `submissions/accepted/`,
  `submissions/wrong_answer/`, `submissions/time_limit_exceeded/`.
- Including jury solutions is worth it: DOMjudge judges them on upload, which tells you right away whether
  the test data and time limits are right.
- **Set time limits on the lab judgehosts, not on your laptop.** Run the jury solutions there and set the limit to
  around 2 to 3 times the slowest accepted solution. Java and Python are slower, so either give them a
  multiplier (*Jury > Languages > Time factor*) or check that their solutions pass.
- Python 3 submissions run with **PyPy** (the judgehost image has no CPython). It is usually faster than CPython, but test your
  Python jury solutions with it.
- Enable only the languages you want (*Jury > Languages*, "Allow submit").

## 6. Contest, teams, accounts

- Create the contest (*Jury > Contests > Add new contest*): activate time, start time, freeze time, end time.
  Times use the server timezone (`Asia/Tehran` in `config.sh`).
- **Disable or delete the `demo` contest** and the demo team, so teams don't see it.
- Teams: for more than a handful, import them (*Jury > Import / export*) from a `teams.json`/`teams.tsv` and an
  `accounts.yaml`/`accounts.tsv` file (see the
  [import documentation](https://www.domjudge.org/docs/manual/9.0/import.html)). Keep the generated passwords and
  print one slip per team.
- Optionally add categories (e.g. "Participants" vs. "Observers") and affiliations.
- Optionally create a **jury account** for each judge who answers clarifications, instead of sharing `admin`.

### Test round on Nov 2 vs. real contest on Nov 4

Keep the same installation. Don't reinstall between the two days: a reinstall creates new passwords and you'd have
to reconfigure every judgehost.

- Use a separate **"Test round"** contest on Nov 2, with a simple practice problem or two plus the real setup.
- On Nov 3, create the **real contest** with the real problems, and disable the test-round contest (or set its end
  time in the past and hide it).
- If you want completely fresh team accounts, reset their passwords (*Jury > Teams*, or re-import accounts).

## 7. Contest-day checklist (Nov 2 and Nov 4)

**Before teams arrive (at least 1 hour before):**

- [ ] Server running; `sudo docker ps` shows `dj-mariadb`, `domserver` and all `judgehost-N` as "Up".
- [ ] *Jury > Judgehosts*: all judgehosts are active and recently checked in.
- [ ] *Jury > Config checker*: no errors.
- [ ] Submit a jury solution and a wrong solution for each problem (as a test team that is hidden from the scoreboard)
      and check the verdicts.
- [ ] From two or three contestant PCs: the page loads, a team can log in, and the internet is blocked.
- [ ] Contest times are right; the scoreboard shows the contest as not started yet.
- [ ] Team password slips are printed.
- [ ] Clock on the server is correct (`date`).

**During the contest:**

- [ ] Someone watches *Jury > Clarifications* and answers questions.
- [ ] Someone watches *Jury > Submissions* for "judging error" and *Jury > Judgehosts* for dead judgehosts.
- [ ] Back up the database every 15 to 30 minutes, and copy the files off the server:
      ```bash
      ./backup_db.sh
      ```
      Or automatically every 15 minutes: `crontab -e` and add
      `*/15 * * * * /home/<user>/starting-domjudge/backup_db.sh`
      (the user needs passwordless `sudo` for docker, or add the user to the `docker` group and remove `sudo` from the script).
- [ ] Don't run updates, `apt upgrade` or reboots on the server or the judge machines.

**If something breaks:**

| Problem | What to do |
| --- | --- |
| A judgehost died | `sudo docker logs judgehost-N`, then `./start_worker.sh N` (restarts it). If a submission stays stuck in "pending" or "judging", rejudge it. |
| Many "judging error" verdicts | Check the judgehost log. Fix the cause, then rejudge those submissions (*Jury > Rejudgings*). |
| The web interface is slow | Check `sudo docker stats`. Move judgehosts off the server so the domserver has CPU. |
| The server rebooted | Containers start again by themselves (restart policy). Check with `sudo docker ps`; otherwise run `./start_server.sh`. |
| The database got corrupted | Restore the latest backup (command at the top of `backup_db.sh`). |
| Wrong time limit or test data | Fix the problem, then rejudge the affected submissions (*Jury > Rejudgings*). |

**After the contest:**

- [ ] Unfreeze the scoreboard (*Jury > Contests > Unfreeze*), then announce the results.
- [ ] Take a final backup and keep it.
