#!/bin/bash
set -eox pipefail

if [[ `whoami` == "root" ]]
then
  echo "Please DO NOT run with sudo!"
  exit 1
fi

# install gperftools
TEMP=`date +%s`
sudo rm -rf /tmp/$TEMP
mkdir /tmp/$TEMP
tar xzf $(dirname $0)/resources/gperftools-2.5.tar.gz -C /tmp/$TEMP
cd /tmp/$TEMP/gperftools-2.5/
./configure --enable-frame-pointers
sudo make install
cd -
sudo rm -rf /tmp/$TEMP

#install docker for gvis ut
curl -fsSL https://get.docker.com/ | sh
sudo usermod -aG docker $USER
curl -L https://github.com/docker/compose/releases/download/1.11.2/docker-compose-`uname -s`-`uname -m` > /tmp/docker-compose
sudo mv /tmp/docker-compose /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
sudo service docker start || true

# setup password-less login
GUSER=$USER
KEY_FILE=/home/$GUSER/.ssh/id_rsa
if [ ! -f ${KEY_FILE} ]; then
  ssh-keygen -t rsa -N "" -f ${KEY_FILE}
fi
cat ${KEY_FILE}.pub >> /home/$GUSER/.ssh/authorized_keys
sudo chmod 700 /home/$GUSER/.ssh
sudo chmod 600 /home/$GUSER/.ssh/authorized_keys

# configure timeout for test
echo -e '500\n500\n500\n500\n500\n500\nn\ny' | gadmin --configure timeout &> /dev/null
gadmin config-apply -v
