#!/bin/bash
# =============================================================================
#  Hadoop 3.2.3 — Automated Installer for Ubuntu 20.04/22.04 LTS (ARM64)
#  Run this script as a NON-ROOT user with sudo privileges.
#  Usage:  chmod +x install_hadoop.sh && ./install_hadoop.sh
# =============================================================================

set -e  # Exit immediately on any error

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()    { echo -e "${CYAN}[INFO]${NC}  $1"; }
success() { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# =============================================================================
# STEP 0 — Preflight checks
# =============================================================================
info "Starting Hadoop 3.2.3 automated installation..."

if [ "$EUID" -eq 0 ]; then
    error "Do NOT run this script as root. Run as a regular user with sudo access."
fi

ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ]; then
    warn "This script is tuned for ARM64 (aarch64). Detected: $ARCH"
    warn "Java path will be adjusted automatically — review if install fails."
fi

# =============================================================================
# STEP 1 — Update system & install Java 8 + SSH
# =============================================================================
info "Updating system packages..."
sudo apt update -y && sudo apt upgrade -y
success "System updated."

info "Installing OpenJDK 8..."
sudo apt install -y openjdk-8-jdk
java -version 2>/dev/null && success "Java installed." || error "Java installation failed."

info "Installing OpenSSH server & client..."
sudo apt install -y openssh-server openssh-client
success "SSH installed."

# =============================================================================
# STEP 2 — Create hadoop user & grant sudo
# =============================================================================
if id "hadoop" &>/dev/null; then
    warn "User 'hadoop' already exists — skipping creation."
else
    info "Creating 'hadoop' user..."
    sudo adduser --gecos "" hadoop
fi

info "Granting sudo privileges to 'hadoop' user..."
sudo usermod -aG sudo hadoop
success "hadoop user configured."

# =============================================================================
# STEP 3 — Configure passwordless SSH for hadoop user
# =============================================================================
info "Configuring passwordless SSH login for hadoop user..."

# Run SSH setup as hadoop user
sudo -u hadoop bash -c '
    mkdir -p ~/.ssh
    if [ ! -f ~/.ssh/id_rsa ]; then
        ssh-keygen -t rsa -P "" -f ~/.ssh/id_rsa -q
    fi
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
    chmod 0600 ~/.ssh/authorized_keys
    chmod 700 ~/.ssh
'

# Accept host key for localhost silently
sudo -u hadoop bash -c 'ssh-keyscan -H localhost >> ~/.ssh/known_hosts 2>/dev/null'
success "Passwordless SSH configured."

# =============================================================================
# STEP 4 — Download & extract Hadoop 3.2.3
# =============================================================================
HADOOP_TAR="hadoop-3.2.3.tar.gz"
HADOOP_URL="https://archive.apache.org/dist/hadoop/common/hadoop-3.2.3/${HADOOP_TAR}"
HADOOP_DIR="/home/hadoop/hadoop-3.2.3"

if [ -d "$HADOOP_DIR" ]; then
    warn "Hadoop directory already exists at $HADOOP_DIR — skipping download."
else
    info "Downloading Hadoop 3.2.3 (this may take a few minutes)..."
    sudo -u hadoop bash -c "cd ~ && wget -q --show-progress '$HADOOP_URL'"
    info "Extracting Hadoop..."
    sudo -u hadoop bash -c "cd ~ && tar xzf $HADOOP_TAR"
    sudo -u hadoop bash -c "rm ~/$HADOOP_TAR"
    success "Hadoop extracted to $HADOOP_DIR"
fi

# =============================================================================
# STEP 5 — Detect Java path (ARM64 vs AMD64)
# =============================================================================
if [ -d "/usr/lib/jvm/java-8-openjdk-arm64" ]; then
    JAVA_HOME_PATH="/usr/lib/jvm/java-8-openjdk-arm64"
elif [ -d "/usr/lib/jvm/java-8-openjdk-amd64" ]; then
    JAVA_HOME_PATH="/usr/lib/jvm/java-8-openjdk-amd64"
else
    JAVA_HOME_PATH=$(dirname $(dirname $(readlink -f $(which java))))
    warn "Could not find standard JVM path. Using: $JAVA_HOME_PATH"
fi
info "Java home detected: $JAVA_HOME_PATH"

# =============================================================================
# STEP 6 — Write all 6 configuration files
# =============================================================================

## --- File 1: ~/.bashrc ---
info "Configuring ~/.bashrc for hadoop user..."
sudo -u hadoop bash -c "cat >> ~/.bashrc << 'BASHRC_EOF'

# ---- Hadoop Environment Variables ----
export HADOOP_HOME=/home/hadoop/hadoop-3.2.3
export HADOOP_INSTALL=\$HADOOP_HOME
export HADOOP_MAPRED_HOME=\$HADOOP_HOME
export HADOOP_COMMON_HOME=\$HADOOP_HOME
export HADOOP_HDFS_HOME=\$HADOOP_HOME
export YARN_HOME=\$HADOOP_HOME
export HADOOP_COMMON_LIB_NATIVE_DIR=\$HADOOP_HOME/lib/native
export PATH=\$PATH:\$HADOOP_HOME/sbin:\$HADOOP_HOME/bin
export HADOOP_OPTS=\"-Djava.library.path=\$HADOOP_HOME/lib/native\"
BASHRC_EOF
"
success ".bashrc updated."

## --- File 2: hadoop-env.sh ---
info "Configuring hadoop-env.sh..."
sudo -u hadoop bash -c "echo 'export JAVA_HOME=${JAVA_HOME_PATH}' >> ${HADOOP_DIR}/etc/hadoop/hadoop-env.sh"
success "hadoop-env.sh updated."

## --- File 3: core-site.xml ---
info "Configuring core-site.xml..."
sudo -u hadoop bash -c "cat > ${HADOOP_DIR}/etc/hadoop/core-site.xml << 'EOF'
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<?xml-stylesheet type=\"text/xsl\" href=\"configuration.xsl\"?>
<configuration>
  <property>
    <name>hadoop.tmp.dir</name>
    <value>/home/hadoop/tmpdata</value>
    <description>A base for other temporary directories.</description>
  </property>
  <property>
    <name>fs.default.name</name>
    <value>hdfs://localhost:9000</value>
    <description>The name of the default file system.</description>
  </property>
</configuration>
EOF
"
success "core-site.xml configured."

## --- File 4: hdfs-site.xml ---
info "Configuring hdfs-site.xml..."
sudo -u hadoop bash -c "cat > ${HADOOP_DIR}/etc/hadoop/hdfs-site.xml << 'EOF'
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<?xml-stylesheet type=\"text/xsl\" href=\"configuration.xsl\"?>
<configuration>
  <property>
    <name>dfs.namenode.name.dir</name>
    <value>/home/hadoop/dfsdata/namenode</value>
  </property>
  <property>
    <name>dfs.datanode.data.dir</name>
    <value>/home/hadoop/dfsdata/datanode</value>
  </property>
  <property>
    <name>dfs.replication</name>
    <value>1</value>
  </property>
</configuration>
EOF
"
success "hdfs-site.xml configured."

## --- File 5: mapred-site.xml ---
info "Configuring mapred-site.xml..."
sudo -u hadoop bash -c "cat > ${HADOOP_DIR}/etc/hadoop/mapred-site.xml << 'EOF'
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<?xml-stylesheet type=\"text/xsl\" href=\"configuration.xsl\"?>
<configuration>
  <property>
    <name>mapreduce.framework.name</name>
    <value>yarn</value>
  </property>
  <property>
    <name>yarn.app.mapreduce.am.env</name>
    <value>HADOOP_MAPRED_HOME=\${HADOOP_HOME}</value>
  </property>
  <property>
    <name>mapreduce.map.env</name>
    <value>HADOOP_MAPRED_HOME=\${HADOOP_HOME}</value>
  </property>
  <property>
    <name>mapreduce.reduce.env</name>
    <value>HADOOP_MAPRED_HOME=\${HADOOP_HOME}</value>
  </property>
</configuration>
EOF
"
success "mapred-site.xml configured."

## --- File 6: yarn-site.xml ---
info "Configuring yarn-site.xml..."
sudo -u hadoop bash -c "cat > ${HADOOP_DIR}/etc/hadoop/yarn-site.xml << 'EOF'
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<?xml-stylesheet type=\"text/xsl\" href=\"configuration.xsl\"?>
<configuration>
  <property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
  </property>
  <property>
    <name>yarn.nodemanager.aux-services.mapreduce.shuffle.class</name>
    <value>org.apache.hadoop.mapred.ShuffleHandler</value>
  </property>
  <property>
    <name>yarn.resourcemanager.hostname</name>
    <value>127.0.0.1</value>
  </property>
  <property>
    <name>yarn.acl.enable</name>
    <value>0</value>
  </property>
  <property>
    <name>yarn.nodemanager.env-whitelist</name>
    <value>JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,CLASSPATH_PREPEND_DISTCACHE,HADOOP_YARN_HOME,HADOOP_MAPRED_HOME</value>
  </property>
</configuration>
EOF
"
success "yarn-site.xml configured."

# =============================================================================
# STEP 7 — Create required HDFS directories
# =============================================================================
info "Creating required data directories..."
sudo -u hadoop bash -c "mkdir -p ~/tmpdata ~/dfsdata/namenode ~/dfsdata/datanode"
success "Directories created."

# =============================================================================
# STEP 8 — Format NameNode & Start Hadoop
# =============================================================================
info "Formatting HDFS NameNode (first time only)..."
sudo -u hadoop bash -c "
    export HADOOP_HOME=/home/hadoop/hadoop-3.2.3
    export JAVA_HOME=${JAVA_HOME_PATH}
    export PATH=\$PATH:\$HADOOP_HOME/sbin:\$HADOOP_HOME/bin
    hdfs namenode -format -force -nonInteractive
"
success "NameNode formatted."

info "Starting HDFS and YARN services..."
sudo -u hadoop bash -c "
    export HADOOP_HOME=/home/hadoop/hadoop-3.2.3
    export JAVA_HOME=${JAVA_HOME_PATH}
    export PATH=\$PATH:\$HADOOP_HOME/sbin:\$HADOOP_HOME/bin
    export HADOOP_OPTS=\"-Djava.library.path=\$HADOOP_HOME/lib/native\"
    \$HADOOP_HOME/sbin/start-dfs.sh
    \$HADOOP_HOME/sbin/start-yarn.sh
"
success "Hadoop services started."

# =============================================================================
# STEP 9 — Verify running daemons
# =============================================================================
info "Verifying Hadoop daemons (jps)..."
sleep 3
JPS_OUT=$(sudo -u hadoop bash -c "
    export JAVA_HOME=${JAVA_HOME_PATH}
    export PATH=\$PATH:\$JAVA_HOME/bin
    jps
")
echo "$JPS_OUT"

EXPECTED=("NameNode" "DataNode" "SecondaryNameNode" "ResourceManager" "NodeManager")
ALL_OK=true
for daemon in "${EXPECTED[@]}"; do
    if echo "$JPS_OUT" | grep -q "$daemon"; then
        success "$daemon is running."
    else
        warn "$daemon NOT found — check logs in $HADOOP_DIR/logs/"
        ALL_OK=false
    fi
done

# =============================================================================
# DONE
# =============================================================================
echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  Hadoop 3.2.3 Installation Complete!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo -e "  HDFS NameNode UI  →  ${CYAN}http://localhost:9870${NC}"
echo -e "  YARN Resource Mgr →  ${CYAN}http://localhost:8088${NC}"
echo -e "  Secondary NameNode→  ${CYAN}http://localhost:9868${NC}"
echo ""
echo -e "  To use Hadoop commands, switch to hadoop user:"
echo -e "  ${YELLOW}su - hadoop${NC}"
echo ""
if [ "$ALL_OK" = false ]; then
    warn "Some daemons may not have started. Check logs at: $HADOOP_DIR/logs/"
fi
