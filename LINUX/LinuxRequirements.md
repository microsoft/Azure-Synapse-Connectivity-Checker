
# Install dependencies
``` bash
sudo apt-get update
sudo apt-get -y install lsb-release jq curl sed netcat-traditional
```
On Red Hat-based systems, you can use yum or dnf, as in the examples below
``` bash
sudo yum install redhat-lsb-core  # for CentOS, RHEL
```
``` bash
sudo dnf install redhat-lsb-core  # for Fedora
```

### Check if dependencies are installed
``` bash
echo "Checking lsb-release" | dpkg -s lsb-release | grep -i status
echo "Checking jq" | dpkg -s jq | grep -i status
echo "Checking curl" | dpkg -s curl | grep -i status
echo "Checking sed" | dpkg -s sed | grep -i status
echo "Checking netcat - To run NC" | dpkg -s netcat | grep -i status
echo "Checking netcat-traditional - To run NC" | dpkg -s netcat | grep -i status
```

### get script
``` bash
wget https://raw.githubusercontent.com/microsoft/Azure-Synapse-Connectivity-Checker/main/LINUX/Synapse-TestConnection-linux.sh
```

### make executable
``` bash
chmod +x Synapse-TestConnection-linux.sh
```

### run
``` bash
./Synapse-TestConnection-linux.sh
```

