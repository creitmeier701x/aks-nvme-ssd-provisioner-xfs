FROM debian:buster

RUN  apt-get update && apt-get -y install nvme-cli mdadm xfsprogs && apt-get -y clean && apt-get -y autoremove
COPY aks-nvme-ssd-provisioner.sh /usr/local/bin/aks-nvme-ssd-provisioner.sh
RUN chmod +x /usr/local/bin/aks-nvme-ssd-provisioner.sh
ENTRYPOINT ["sudo /usr/local/bin/aks-nvme-ssd-provisioner.sh"]