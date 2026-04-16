# 🐘 hadoop-installer

> Install Apache Hadoop 3.2.3 on Ubuntu in the simplest way possible — just **2 commands**.

---

## ✅ Requirements

- Ubuntu **20.04** or **22.04** LTS (ARM64 / AMD64)
- A non-root user with **sudo** privileges
- Internet connection

---

## 🚀 Installation — Only 2 Commands

### Step 1 — Download the script

```bash
wget https://raw.githubusercontent.com/YOUR_USERNAME/hadoop-installer/main/install_hadoop.sh
```

> Or clone the repo:
> ```bash
> git clone https://github.com/YOUR_USERNAME/hadoop-installer.git
> cd hadoop-installer
> ```

---

### Step 2 — Run the installer

```bash
chmod +x install_hadoop.sh
./install_hadoop.sh
```

> ⚠️ Do **NOT** run with `sudo`. The script handles privileges internally.

---

## 🔑 During Installation

At one point the script will prompt you to **set a password for the new `hadoop` user**.

**Suggested password:** `hadoop`

```
Enter new UNIX password: hadoop
Retype new UNIX password: hadoop
```

Press **Enter** through the remaining prompts (Full Name, Room Number, etc.).

---

## ✔️ Verify the Installation

Once the script finishes, switch to the hadoop user and check running daemons:

```bash
su - hadoop
jps
```

You should see all **5 daemons** running:

```
12345 NameNode
12346 DataNode
12347 SecondaryNameNode
12348 ResourceManager
12349 NodeManager
```

---

## 🧪 Quick Smoke Test

```bash
su - hadoop
hdfs dfs -mkdir /test
hdfs dfs -ls /
```

Expected output:

```
Found 1 items
drwxr-xr-x  - hadoop supergroup  0  2024-01-01  /test
```

---

## 🌐 Web UIs

After installation, open these in your browser:

| Service | URL |
|---|---|
| HDFS NameNode | http://localhost:9870 |
| YARN Resource Manager | http://localhost:8088 |
| Secondary NameNode | http://localhost:9868 |

---

## 📁 What Gets Installed

| Component | Details |
|---|---|
| **Hadoop version** | 3.2.3 |
| **Java** | OpenJDK 8 |
| **Install location** | `/home/hadoop/hadoop-3.2.3` |
| **HDFS data** | `/home/hadoop/dfsdata/` |
| **Temp directory** | `/home/hadoop/tmpdata/` |
| **Config files** | `core-site.xml`, `hdfs-site.xml`, `mapred-site.xml`, `yarn-site.xml` |

---

## ❓ Troubleshooting

**A daemon is missing from `jps`?**
```bash
cat /home/hadoop/hadoop-3.2.3/logs/*.log
```

**SSH issues?**
```bash
sudo service ssh status
sudo service ssh start
```

**Re-running the script?**
It is safe to re-run — user creation and download are skipped if already done.
> ⚠️ Note: Re-running **will reformat the NameNode**, which erases existing HDFS data.

---

## 📄 License

MIT License — free to use, modify, and distribute.

---

<p align="center">Made with ❤️ to make Hadoop setup painless</p>


