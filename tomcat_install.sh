#!/bin/bash

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# 1. Check if java and wget are installed, if not, install them
dnf install wget java -y --nogpgcheck

# 2. Create Tomcat Service Account
useradd -m -U -d /opt/tomcat -s /bin/false tomcat

# 3. Download .gz file from tomcat website
wget -P /tmp https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.97/bin/apache-tomcat-9.0.97.tar.gz

# 4. Make a directory to store tomcat contents
mkdir -p /opt/tomcat

# 5. Extract the tomcat tarball file
tar xzf /tmp/apache-tomcat-9.*.tar.gz -C /opt/tomcat/ --strip-components=1

# 6. Change ownership of /opt/tomcat
chown -R tomcat: /opt/tomcat

# 7. Make sure /opt/bin/bin have executable
chmod +x /opt/tomcat/bin/*.sh

# 8. Create systemd service for tomcat
cat <<EOF > /etc/systemd/system/tomcat.service
[Unit]
Description=Tomcat web servlet container
After=network.target

[Service]
Type=forking
User=tomcat
Group=tomcat
Environment="JAVA_HOME=/usr/lib/jvm/jre"
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom"
Environment="CATALINA_BASE=/opt/tomcat"
Environment="CATALINA_HOME=/opt/tomcat"
Environment="CATALINA_PID=/opt/tomcat/temp/tomcat.pid"
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"
ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

[Install]
WantedBy=multi-user.target
EOF

# 9. Reload, enable and start systemd and tomcat
systemctl daemon-reload
systemctl enable --now tomcat

# 10. Start firewalld and configure firewall
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --zone=public --permanent --add-port=8080/tcp
firewall-cmd --add-service=http --permanent
firewall-cmd --reload

# 11. Take a backup of tomcat-users.xml
cp /opt/tomcat/conf/tomcat-users.xml /opt/tomcat/conf/tomcat-users.xml.orig

# 12. Append lines to tomcat-users.xml
cat <<EOT >> /opt/tomcat/conf/tomcat-users.xml
<role rolename="admin"/>
<role rolename="admin-gui"/>
<role rolename="manager"/>
<role rolename="manager-gui"/>
<user username="tcadmin" password="devops@ex11" roles="admin,admin-gui,manager,manager-gui"/>
EOT

# 13. Comment out lines in context.xml files and take backup
cp /opt/tomcat/webapps/manager/META-INF/context.xml /opt/tomcat/webapps/manager/META-INF/context.xml.orig
cp /opt/tomcat/webapps/host-manager/META-INF/context.xml /opt/tomcat/webapps/host-manager/META-INF/context.xml.orig

# 14. Restart Tomcat
systemctl restart tomcat

echo "Tomcat installation and configuration completed successfully."
