#!/bin/sh

#init初始化配置 公共config

export remote_ip="192.168.1.4"
export remote_pwd="123456"
export local_ip="192.168.1.5"
export local_pwd="123456"
export vms="Redos-autotest"
export main_vms="Redos-autotest"
export localhost="RedOS-5"
export remotehost="RedOS-4"
export bridge="br0"
export image_name="/home/source/templet/redos_autotest.img"
export source_vm_image="/home/source/templet/redos_autotest.img"
export backup_vm_image="/home/source/templet-bck/redos_autotest.img"

CURRENT_DIR=$(pwd)
cd $CURRENT_DIR/../autotest
AUTOTEST_PATH=$(pwd)
cd $CURRENT_DIR/../tp-libvirt
TP_LIBVIRT=$(pwd)
cd $CURRENT_DIR/../tp-qemu
TP_QEMU=$(pwd)
cd $CURRENT_DIR
LIBVIRT_BASE_PATH=$CURRENT_DIR/backends/libvirt/cfg/base.cfg
QEMU_BASE_PATH=$CURRENT_DIR/backends/qemu/cfg/base.cfg

#
result_of_domiflist=`virsh domiflist $main_vms`
mac_nic1=`echo $result_of_domiflist|cut -d ' ' -f 11`
export tmp=`mount |grep boot`
export ENTER_YOUR_AVAILABLE_PARTITION=${tmp:5:5} #为用例libvirt_scsi指定测试分区为boot分区
mkdir $CURRENT_DIR/shared/pool > /dev/null 
export PATH_OF_POOL_XML="$CURRENT_DIR/shared/pool/virt-test-pool.xml" #指定用例pool_create创建的pool.xml的路径

usage()
{
    cat <<-EOF >&2
    usage: [ -h ][ -t testcase][ -T testcase -v]
    -h             Prints all available options.
    -t             libvirt:testcase
    -T             libvirt:testcase -v
EOF
exit 0
}

while getopts ht:T: arg
      do case $arg in
         h) usage;;
         t)
            ./run -t libvirt --no-downloads -k --keep-image-between-tests --tests $OPTARG
            exit 0;;
         T) 
            ./run -t libvirt --no-downloads -k --keep-image-between-tests --tests $OPTARG -v
            exit 0;;
         esac
      done


#autotest测试基本环境
#AUTOTEST路径
#qemu-system-ppc64做链接
#防火墙关闭

setenv()

{
        echo "##########   SET TEST ENVIRONMENT  ##########"
	echo
	grep -rn "AUTOTEST" ~/.bashrc > /dev/null
        if [ $? = 1 ];then
                echo "export AUTOTEST_PATH=$AUTOTEST_PATH" >> ~/.bashrc
                export AUTOTEST_PATH=$AUTOTEST_PATH
        else
        	echo "AUTOTEST_PATH has been set!"
        fi
	#修改redos_autorun的配置
	sed -i "s|^virt-test.*$|virt-test = "$CURRENT_DIR/"|g" ./redos_autorun/cfg/base.cfg
        sed -i "s|^backup_vm_image =.*$|backup_vm_image = "$backup_vm_image"|g" ./redos_autorun/cfg/base.cfg
        sed -i "s|^source_vm_image =.*$|source_vm_image = "$source_vm_image"|g" ./redos_autorun/cfg/base.cfg
        sed -i "s|^extra_cmd = -t qemu.*$|extra_cmd = -t qemu --machine-type pseries --g Linux.RHEL.7.1.ppc64.pseries --qemu_sandbox off --netdst="$bridge"|g" ./redos_autorun/cfg/base.cfg
        #修改test-providers.d
        sed -i 's|^uri.*$|uri: file:\/\/'$TP_LIBVIRT'|g' ./test-providers.d/io-github-autotest-libvirt.ini
        sed -i 's|^uri.*$|uri: file:\/\/'$TP_QEMU'|g' ./test-providers.d/io-github-autotest-qemu.ini

	ln -s /usr/bin/qemu-system-ppc64 /usr/bin/qemu-kvm > /dev/null 
        ln -s /usr/bin/qemu-system-ppc64 /usr/bin/kvm > /dev/null 
        echo "make link qemu-system-ppc64 to qemu-kvm"
	echo

	ppc64_cpu --smt=off
        systemctl stop firewalld
        systemctl mask firewalld
        systemctl stop iptables
        systemctl mask iptables
        setenforce 0
        yum install expect -y
        
	if [ ! -f $LIBVIRT_BASE_PATH ];then
		echo "build libvirt base.cfg,wait a minute!"
                ./run -t libvirt --list-tests > /dev/null
	else
		echo "libvirt base.cfg exit!"
	fi
	if [ ! -f $QEMU_BASE_PATH ];then
                echo "build qemu base.cfg,wait a minute!"
                ./run -t qemu --list-tests > /dev/null
        else
                echo "qemu base.cfg exit!"
        fi


        sed -i "s/^remote_ip.*$/remote_ip = $remote_ip/" ./backends/libvirt/cfg/base.cfg
        sed -i "s/^remote_ip.*$/remote_ip = $remote_ip/" ./backends/qemu/cfg/base.cfg
	echo "set remote_ip = $remote_ip"

	sed -i "s/^local_ip.*$/local_ip = $local_ip/" ./backends/libvirt/cfg/base.cfg
        sed -i "s/^local_ip.*$/local_ip = $local_ip/" ./backends/qemu/cfg/base.cfg
	echo "set local_ip = $local_ip"

	sed -i "s/^local_pwd.*$/local_pwd = $local_pwd/" ./backends/libvirt/cfg/base.cfg
        sed -i "s/^local_pwd.*$/local_pwd = $local_pwd/" ./backends/qemu/cfg/base.cfg
	echo "set local_pwd = $local_pwd"

	sed -i "s/^main_vm.*$/main_vm = $main_vms/" ./backends/libvirt/cfg/base.cfg
        sed -i "s/^main_vm.*$/main_vm = $main_vms/" ./backends/qemu/cfg/base.cfg
	echo "set main_vms = $main_vms"

	sed -i "s/^vms.*$/vms = $vms/" ./backends/libvirt/cfg/base.cfg
        sed -i "s/^vms.*$/vms = $vms/" ./backends/qemu/cfg/base.cfg
	echo "set vms = $vms"
	
	sed -i "s/^# mac_nic1.*$/mac_nic1 = $mac_nic1/" ./backends/qemu/cfg/base.cfg
	sed -i "s/^mac_nic1.*$/mac_nic1 = $mac_nic1/" ./backends/qemu/cfg/base.cfg
	echo "set mac_nic1 = $mac_nic1"

	echo "set localhost=$localhost"
	hostname $localhost
        
        sed -i "s|^    image_name =.*$|    image_name ="$image_name"|" ./shared/cfg/guest-os/Linux/RHEL/7.1/ppc64.cfg
	
	#默认关闭截屏选项
	sed -i "s/^take_regular_screendumps.*$/take_regular_screendumps = no/" ./backends/libvirt/cfg/base.cfg
	sed -i "s/^keep_screendumps_on_error.*$/keep_screendumps_on_error = no/" ./backends/libvirt/cfg/base.cfg
	sed -i "s/^keep_screendumps.*$/keep_screendumps = no/" ./backends/libvirt/cfg/base.cfg
	
	remotehost=${remotehost:-$OPTARG}
}

#配置locoalhost和remote的ssh无密码访问
auto_ssh_copy_id () {
    expect -c "set timeout -1;
               spawn ssh-keygen
               expect {
                   *y/n* {send -- y\r;exp_continue;}
                   */root/.ssh/id_rsa* {send -- \r;exp_continue;}
                   *empty* {send -- \r;exp_continue;}
                   *same* {send -- \r;exp_continue;}
               }
               spawn ssh-copy-id root@$2;
               expect {
                   *(yes/no)* {send -- yes\r;exp_continue;}
                   *assword:* {send -- $1\r;exp_continue;}
               }"
}

auto_scp_is_rsa() {
    expect -c "set timeout -1;
               spawn ssh root@$remote_ip "ssh-keygen"
               expect {
                   *y/n* {send -- y\r;exp_continue;}
                   */root/.ssh/id_rsa* {send -- \r;exp_continue;}
                   *empty* {send -- \r;exp_continue;}
                   *same* {send -- \r;exp_continue;}
                }"
    scp root@$remote_ip:/root/.ssh/id_rsa.pub /root/.ssh/authorized_keys
    ssh root@$remote_ip "sed -i -e 's|#   StrictHostKeyChecking ask|StrictHostKeyChecking no|' /etc/ssh/ssh_config"
}

#单独测试用例配置的修改
specialcfg()
{
       echo "######## SET CONFIGURE FOR SPECIAL TESTCASES #########"
       echo
      #config remote-test ip for teset: virsh_nodesuspend
       echo "set config for testcases:virsh_nodesuspend!"
       echo
       sed -i -e 's|ENTER.YOUR.REMOTE.EXAMPLE.COM|'$remote_ip'|' ../tp-libvirt/libvirt/tests/cfg/virsh_cmd/host/virsh_nodesuspend.cfg
       sed -i -e "s|EXAMPLE.PWD|$remote_pwd|" ../tp-libvirt/libvirt/tests/cfg/virsh_cmd/host/virsh_nodesuspend.cfg

      #libvirt_scsi_partition = "/dev/sda2" 为用例libvirt_scsi指定测试分区
       echo "set config for testcases:libvirt_scsi!"
       echo
       sed -i "s/^    libvirt_scsi_partition =.*$/    libvirt_scsi_partition = \/dev\/$ENTER_YOUR_AVAILABLE_PARTITION/" ../tp-libvirt/libvirt/tests/cfg/libvirt_scsi.cfg
 
       #为用例pool_create创建pool.xml
       echo "build pool.xml for testcases:virsh_pool_create!"
       echo
       sed -i -e "s|"/PATH/TO/POOL.XML"|$PATH_OF_POOL_XML|" ../tp-libvirt/libvirt/tests/cfg/virsh_cmd/pool/virsh_pool_create.cfg
       cat > $PATH_OF_POOL_XML  <<-EOF
<pool type='dir'>
  <name>virt-test-pool</name>
  <capacity unit='bytes'>0</capacity>
  <allocation unit='bytes'>0</allocation>
  <available unit='bytes'>0</available>
  <source>
  </source>
  <target>
    <path>$CURRENT_DIR/shared/pool</path>
  </target>
</pool>
EOF
       #用例virsh.pool_acl，iscsi默认收ipv6连接，修改/eth/hosts，注释掉::1
       echo "modify /etc/hosts for testcases:virsh.pool_acl!"
       echo
       sed -i 's/^::1/#::1/g' /etc/hosts
     
       #为用例virsh.cpu_baseline指定测试机
       echo "set config for testcases:virsh.cpu_baseline!"
       echo
       sed -i -e "s|virt-tests-vm1|$main_vms|" ../tp-libvirt/libvirt/tests/cfg/virsh_cmd/domain/virsh_cpu_baseline.cfg
 	
       #为用例virsh.domstats指定测试机
       echo "set config for testcases:virsh.domstats!"
       echo
       sed -i -e "s/^    vm_list.*$/    vm_list = "$main_vms"/" ../tp-libvirt/libvirt/tests/cfg/virsh_cmd/monitor/virsh_domstats.cfg
       sed -i -e "s|virt-tests-vm1||" ../tp-libvirt/libvirt/tests/cfg/virsh_cmd/monitor/virsh_domstats.cfg
       
       #修改guest_numa的配置文件，改动qemu默认配置参数node,nodeid=1,cpus=2-3,mem=301 
       echo "modify config for testcases:guest_numa!"
       echo
       sed -i -e "s|node,nodeid=0,cpus=0-1,mem=300|node,nodeid=0,cpus=0-1,memdev=ram-node0|" ../tp-libvirt/libvirt/tests/cfg/numa/guest_numa.cfg
       sed -i -e "s|node,nodeid=1,cpus=2-3,mem=301|node,nodeid=1,cpus=2-3,memdev=ram-node1|" ../tp-libvirt/libvirt/tests/cfg/numa/guest_numa.cfg
       
       #为用例virsh.domcapabilities指定远程测试主机
       echo "set config for testcases:virsh.domcapabilities!"
       echo
       sed -i -e "s|EXAMPLE.COM|$remote_ip|" ../tp-libvirt/libvirt/tests/cfg/virsh_cmd/host/virsh_domcapabilities.cfg
       
       #为用例virsh.cpu_models指定远程测试主机
       echo "set config for testcases:virsh.cpu_models!"
       echo
       sed -i -e "s|EXAMPLE.COM|$remote_ip|" ../tp-libvirt/libvirt/tests/cfg/virsh_cmd/host/virsh_cpu_models.cfg
}

#测试用例所需的软件包安装
install()
{
	echo "###########  INSTALL RPMS FOR　TESTS  ##########"
	echo
        yum install iscsi* -y
        yum install targetcli* -y
        yum install targetd -y
        yum install numactl -y
        yum install policycoreutils-python -y
        yum install mkisofs -y
        yum install perf -y
        yum install virt-install -y
        yum install gstreamer-python -y
}

main()
{	
	setenv
        
        
        echo "##### SET remote-local NO PASSWORD LOGIN  #####"
	echo
 	auto_ssh_copy_id  $local_pwd $remote_ip
        auto_scp_is_rsa
	ssh root@$remote_ip "hostname $remotehost"
        expect -c "set timeout -1;
        	spawn ssh-copy-id root@$local_ip;
                expect {
                   *(yes/no)* {send -- yes\r;exp_continue;}
                   *assword:* {send -- $local_pwd\r;exp_continue;}
                }"

	specialcfg

	install	
	
	echo
	echo "CONFIG FINISH,YOU CAN RUN TESTS!"
}

main
