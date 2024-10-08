#!/bin/bash

set -x  # Enable debugging

now=$(date +%d%b%Y-%H%M)
USER="devops"
GROUP="devops"
passw="today@1234"

exp() {
	"$1" <(cat <<-EOF
	spawn passwd $USER
	expect "Enter new UNIX password:"
	send -- "$passw\r"
	expect "Retype new UNIX password:"
	send -- "$passw\r"
	expect eof
	EOF
	)
	echo "Password for user $USER updated successfully - adding to sudoers file now."
}

setup_pass() {
	if [ ! -f /usr/bin/expect ] && [ ! -f /bin/expect ]; then
		case "$1" in
			sles) zypper install -y expect ;;
			ubuntu) apt-get update && apt install -y expect ;;
			amzn|centos) 
				rpm -Uvh http://epel.mirror.net.in/epel/6/x86_64/epel-release-6-8.noarch.rpm
				yum install -y expect
				;;
		esac
	fi
	exp "/usr/bin/expect"
}

update_conf() {
	sudofile="/etc/sudoers"
	sshdfile="/etc/ssh/sshd_config"
	backup_dir="/home/backup"
	mkdir -p "$backup_dir"

	# Update sudoers
	if [ -f "$sudofile" ]; then
		cp -p "$sudofile" "$backup_dir/sudoers-$now"
		if ! grep -q "$USER" "$sudofile"; then
			echo "$USER ALL=(ALL) NOPASSWD: ALL" >> "$sudofile"
			echo "Sudoers file updated successfully."
		else
			echo "$USER already exists in sudoers."
		fi
	else
		echo "Sudoers file not found."
	fi

	# Update sshd_config
	if [ -f "$sshdfile" ]; then
		cp -p "$sshdfile" "$backup_dir/sshd_config-$now"
		sed -i '/ClientAliveInterval.*0/d' "$sshdfile"
		echo "ClientAliveInterval 240" >> "$sshdfile"
		sed -i '/PasswordAuthentication.*/d' "$sshdfile"
		echo "PasswordAuthentication yes" >> "$sshdfile"
		echo "SSHD config updated, restarting SSHD."
		service sshd restart
	else
		echo "SSHD config not found."
	fi
}

install_tools() {
	{
		# Update package lists and install dependencies
		sudo apt-get update -y
		sudo apt-get upgrade -y

		# Install Java
                apt install -y openjdk-17-jre-headless 

                

		# Install Docker
		sudo apt-get install -y docker.io
		sudo systemctl start docker
		sudo systemctl enable docker



#!/bin/bash

# Update package lists and install dependencies
sudo apt-get update -y
sudo apt-get upgrade -y

# Install Java (OpenJDK 17)
sudo apt install -y openjdk-17-jre-headless 

# Verify Java installation
java -version

# Install Docker (optional for Jenkins if needed)
sudo apt-get install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker

# Download Jenkins WAR file
wget https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/2.479/jenkins-war-2.479.war

# Move Jenkins WAR file to /opt/jenkins and set permissions
sudo mkdir -p /opt/jenkins
sudo mv jenkins-war-2.479.war /opt/jenkins/
sudo chown -R jenkins:jenkins /opt/jenkins
sudo chmod 755 /opt/jenkins/jenkins-war-2.479.war

# Set up environment variables
export JENKINS_HOME=/var/jenkins_home
export JENKINS_SLAVE_AGENT_PORT=50000
export JENKINS_VERSION=2.479

# Check if Jenkins group exists, if not create it
if ! getent group jenkins > /dev/null; then
    sudo groupadd -g 1112 jenkins
fi

# Check if Jenkins user exists, if not create it
if ! id -u jenkins > /dev/null 2>&1; then
    sudo useradd -m -d /var/jenkins_home -u 1112 -g 1112 -s /bin/bash jenkins
fi

# Ensure correct permissions on JENKINS_HOME directory
sudo mkdir -p /var/jenkins_home
sudo chown -R jenkins:jenkins /var/jenkins_home
sudo chmod 755 /var/jenkins_home

# Download Jenkins Plugin Manager
wget https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.13.0/jenkins-plugin-manager-2.13.0.jar

# Create Jenkins systemd service file
sudo bash -c 'cat > /etc/systemd/system/jenkins.service <<EOF
[Unit]
Description=Jenkins Continuous Integration Server
Documentation=https://jenkins.io/doc/
After=network.target

[Service]
User=jenkins
Group=jenkins
Environment="JENKINS_HOME=/var/jenkins_home"
ExecStart=/usr/bin/java -jar /opt/jenkins/jenkins-war-2.479.war
SuccessExitStatus=143
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF'

# Reload systemd to recognize the new Jenkins service
sudo systemctl daemon-reload

# Enable Jenkins service to start on boot
sudo systemctl enable jenkins

# Start Jenkins service
sudo systemctl start jenkins

# Verify the status of Jenkins service
sudo systemctl status jenkins




		# Install Git
		sudo apt-get install -y git

		# Install Terraform
		sudo wget https://raw.githubusercontent.com/lerndevops/labs/master/scripts/installTerraform.sh -P /tmp
                sudo chmod 755 /tmp/installTerraform.sh
                sudo bash /tmp/installTerraform.sh

		# Install Maven
		MAVEN_VERSION=3.8.6
		sudo wget https://downloads.apache.org/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz -P /tmp
		sudo tar -xzf /tmp/apache-maven-$MAVEN_VERSION-bin.tar.gz -C /opt/
		sudo mv /opt/apache-maven-$MAVEN_VERSION /opt/maven

		# Install kubectl
		curl -LO "https://storage.googleapis.com/kubernetes-release/release/v1.23.6/bin/linux/amd64/kubectl"
		sudo chmod +x ./kubectl
		sudo mv ./kubectl /usr/local/bin/kubectl

		# Install Ansible
		if [ "$osname" == "ubuntu" ]; then
			sudo apt-get install -y software-properties-common
			sudo apt-add-repository --yes --update ppa:ansible/ansible
			sudo apt-get install -y ansible
			echo "Ansible installed successfully."
		fi

	} || {
		echo "An error occurred during the installation process."
		exit 1
	}
}

############### MAIN ###################

if id -u "$USER" &>/dev/null; then 
	echo "$USER user exists, no action required."
	exit 0
else
	echo "$USER user missing, creating user..."
fi

if [ -f /etc/os-release ]; then
	osname=$(grep ID /etc/os-release | egrep -v 'VERSION|LIKE|VARIANT|PLATFORM' | cut -d'=' -f2 | tr -d '"')
else
	echo "Cannot locate /etc/os-release - unable to find the OS name."
	exit 8
fi

case "$osname" in
	sles|amzn|ubuntu|centos)
		userdel -r "$USER"
		groupdel "$GROUP"
		sleep 3
		groupadd "$GROUP"
		useradd "$USER" -m -d /home/"$USER" -s /bin/bash -g "$GROUP"
		setup_pass "$osname"
		update_conf
		install_tools
		;;
	*)
		echo "Could not determine the correct OS name -- found $osname."
		;;
esac

exit 0
