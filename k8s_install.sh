#!/bin/bash 

hostname_auto=`echo $RANDOM`
pwd_dir=`pwd`



yum_source(){
	hostnamectl set-hostname k8s$hostname_auto
	systemctl disable firewalld && systemctl stop firewalld 
	swapoff -a && sysctl -w vm.swappiness=0
	sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
	sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux 
	sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
	setenforce 0

	rpm -ivh rpms/deltarpm-3.6-3.el7.x86_64.rpm
	rpm -ivh rpms/python-deltarpm-3.6-3.el7.x86_64.rpm
	rpm -ivh rpms/createrepo-0.9.9-28.el7.noarch.rpm --nodeps --force
        rpm -ivh rpms/bash-completion-2.1-8.el7.noarch.rpm --nodeps --force
        rm -rf rpms/repodata
	createrepo $pwd_dir/rpms
        mkdir -p /etc/yum.repos.d/wmh
        mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/wmh

cat <<EOF >  /etc/yum.repos.d/my.repo
[local-yum]
name=local-yum
baseurl=file://${pwd_dir}/rpms
enabled=1
gpgcheck=0
EOF


	yum clean all
        yum install -y yum-utils device-mapper-persistent-data lvm2
        yum install docker-ce-19.03.9 docker-ce-cli-19.03.9 containerd.io -y
	systemctl start docker
	systemctl enable docker
	#yum -y install  kubeadm-1.21.2-0 kubelet-1.21.2-0 kubectl-1.21.2-0
	yum -y install  kubectl-1.21.2-0  kubeadm-1.21.2-0 kubelet-1.21.2-0 
	#yum -y install  kubeadm kubelet kubectl
	systemctl enable kubelet.service
        mv /etc/yum.repos.d/wmh/*.repo /etc/yum.repos.d
	docker load -i image.tar 
}




install_master(){
	kubeadm init --config init.yml 
	mkdir -p $HOME/.kube
	sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
	sudo chown $(id -u):$(id -g) $HOME/.kube/config
	kubectl taint nodes k8s$hostname_auto  node-role.kubernetes.io/master:NoSchedule- >/dev/null 2>&1
        source /usr/share/bash-completion/bash_completion
        echo 'source <(kubectl completion bash)' >> ~/.bashrc

	#\cp calico.yaml calico-etcd.yaml
	#POD_CIDR=`grep 'cluster-cidr' /etc/kubernetes/manifests/kube-controller-manager.yaml | awk -F= '{print $2}'` 
 	#sed -i -e "s?192.168.0.0/16?$POD_CIDR?g" calico-etcd.yaml


        #sed -i 's/# \(etcd-.*\)/\1/' calico-etcd.yaml
        #etcd_key=$(cat /etc/kubernetes/pki/etcd/peer.key | base64 -w 0)
        #etcd_crt=$(cat /etc/kubernetes/pki/etcd/peer.crt | base64 -w 0)
        #etcd_ca=$(cat /etc/kubernetes/pki/etcd/ca.crt | base64 -w 0)
        #sed -i -e 's/\(etcd-key: \).*/\1'$etcd_key'/' \
        #    -e 's/\(etcd-cert: \).*/\1'$etcd_crt'/' \
        #    -e 's/\(etcd-ca: \).*/\1'$etcd_ca'/' calico-etcd.yaml


        #ETCD=$(grep 'advertise-client-urls=' /etc/kubernetes/manifests/etcd.yaml | awk -F= '{print $2}' | sed 's#\/#\\\/#g')
        #sed -i -e "s/http:\/\/<ETCD_IP>:<ETCD_PORT>/$ETCD/g" \
        #     -e 's/\(etcd_.*:\).*#/\1/' \
        #     -e 's/replicas: 1/replicas: 2/' calico-etcd.yaml


        #netcard=`ip a | grep "state UP" | awk -F": "+ '{print $2}'`
        #sed "/autodetect/a\            - name: IP_AUTODETECTION_METHOD\n              value: "interface=$netcard"" -i calico-etcd.yaml
        kubectl apply -f calico.yaml >/dev/null 2>&1

}



delete_all(){
	kubeadm reset -f
	modprobe -r ipip
	lsmod
	rm -rf ~/.kube/
	rm -rf /etc/kubernetes/
	rm -rf /etc/systemd/system/kubelet.service.d
	rm -rf /etc/systemd/system/kubelet.service
        yum -y remove  kubectl-1.21.2-0  kubeadm-1.21.2-0 kubelet-1.21.2-0
	rm -rf /usr/bin/kube*
	rm -rf /etc/cni
	rm -rf /opt/cni
	rm -rf /var/lib/etcd
	rm -rf /var/etcd
	yum clean all
	yum remove kube* -y 

yum remove docker \
           docker-client \
           docker-client-latest \
           docker-common \
           docker-latest \
           docker-latest-logrotate \
           docker-logrotate \
           docker-selinux \
           docker-engine-selinux \
           docker-engine   -y 

yum remove docker-ce \
           docker-ce-cli \
           containerd  -y 


	systemctl stop docker
        #cat /proc/mounts | grep "docker"
        umount /var/run/docker/netns/default
	rm -rf /etc/systemd/system/docker.service.d
	rm -rf /etc/systemd/system/docker.service
	rm -rf /var/lib/docker
	rm -rf /var/run/docker
	rm -rf /usr/local/docker
	rm -rf /etc/docker
	rm -rf /usr/bin/docker* /usr/bin/containerd* /usr/bin/runc /usr/bin/ctr


}


case "$1" in
   master)
       yum_source
       install_master
   ;;
   node)
       yum_source
   ;;
   delete)
       delete_all
   ;;
   *)
       echo "-------- Install: $0  master or node ---------"
       echo "-------- Delete:  $0  delete -----------------"
   ;;
esac



