#sudo apt-get install lsb-release
#On Red Hat-based systems, you can use yum or dnf:
#sudo yum install redhat-lsb-core  # for CentOS, RHEL
#sudo dnf install redhat-lsb-core  # for Fedora

echo "Checking lsb-release"
dpkg -s lsb-release | grep -i status
echo "Checking jq"
dpkg -s jq | grep -i status
echo "Checking curl"
dpkg -s curl | grep -i status
echo "Checking sed"
dpkg -s sed | grep -i status
echo "Checking netcat - To run NC - Looks like not needed"
dpkg -s netcat | grep -i status

