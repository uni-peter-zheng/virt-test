#!/bin/sh

#init初始化配置 公共config
export remote_ip="192.168.1.3"
remote_pwd="123456"
export local_ip="192.168.1.5"
local_pwd="123456"
export vms="autotest-qcow2"
export vms_raw="autotest-raw"
export main_vms="autotest-qcow2"
export main_vms_raw="autotest-raw"
localhost="RedOS-5"
remotehost="RedOS-3"
export bridge="br0"
export image_name="/home/source/templet/redos-le1-1-5"
export source_vm_image="/home/source/templet/redos-le1-1-5.qcow2"
export source_vm_image_raw="/home/source/templet/redos-le1-1-5.img"
export backup_vm_image="/home/source/templet-bck/redos-le1-1-5.qcow2"
export backup_vm_image_raw="/home/source/templet-bck/redos-le1-1-5.img"
BLOCK_DEVICE="/DEV/EXAMPLE" #填写host上可用的空物理盘/dev/sdf


export CONFIG_DIR=$(pwd)
cd $CONFIG_DIR/../autotest
AUTOTEST_PATH=$(pwd)
cd $CONFIG_DIR/../tp-libvirt
TP_LIBVIRT=$(pwd)
cd $CONFIG_DIR/../tp-qemu
TP_QEMU=$(pwd)
cd $CONFIG_DIR
LIBVIRT_BASE_PATH=$CONFIG_DIR/backends/libvirt/cfg/base.cfg
QEMU_BASE_PATH=$CONFIG_DIR/backends/qemu/cfg/base.cfg

#
result_of_domiflist=`virsh domiflist $main_vms`
export mac_nic1=`echo $result_of_domiflist|cut -d ' ' -f 11`
tmp=`mount |grep boot`
ENTER_YOUR_AVAILABLE_PARTITION=${tmp:5:5} #为用例libvirt_scsi指定测试分区为boot分区
mkdir $CONFIG_DIR/shared/pool >/dev/null 2>&1
PATH_OF_POOL_XML="$CONFIG_DIR/shared/pool/virt-test-pool.xml" #指定用例pool_create创建的pool.xml的路径

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

while getopts ht:T:r arg
    do case $arg in
        h) usage;;
        t)
           $CONFIG_DIR/./run -t libvirt --no-downloads -k --keep-image-between-tests --tests $OPTARG
           exit 0;;
        T) 
           $CONFIG_DIR/./run -t libvirt --no-downloads -k --keep-image-between-tests --tests $OPTARG -v
           exit 0;;
        r)
	   virsh undefine 

        esac
    done


#autotest测试基本环境
#AUTOTEST路径
#qemu-system-ppc64做链接
#防火墙关闭

setenv()

{
    echo "##########   SET TEST ENVIRONMENT  ##########"
	
    export AUTOTEST_PATH=$AUTOTEST_PATH

    cat > ~/.bashrc <<-EOF
# .bashrc

# User specific aliases and functions

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Source global definitions
if [ -f /etc/bashrc ]; then
        . /etc/bashrc
fi

export AUTOTEST_PATH=$AUTOTEST_PATH
export CONFIG_DIR=$CONFIG_DIR
export remote_ip=$remote_ip
export local_ip=$local_ip
export vms=$vms
export vms_raw=$vms_raw
export main_vms=$main_vms
export main_vms_raw=$main_vms_raw
export source_vm_image=$source_vm_image
export source_vm_image_raw=$source_vm_image_raw
export backup_vm_image=$backup_vm_image
export source_vm_image_raw=$source_vm_image_raw
export mac_nic1=$mac_nic1
EOF
	#修改redos_autorun的配置
    sed -i "s|^virt-test.*$|virt-test = "$CONFIG_DIR/"|g" $CONFIG_DIR/redos_autorun/cfg/base.cfg
    sed -i "s|^backup_vm_image =.*$|backup_vm_image = "$backup_vm_image"|g" $CONFIG_DIR/redos_autorun/cfg/base.cfg
    sed -i "s|^source_vm_image =.*$|source_vm_image = "$source_vm_image"|g" $CONFIG_DIR/redos_autorun/cfg/base.cfg
    sed -i "s/br0/$bridge/g" $CONFIG_DIR/redos_autorun/cfg/base.cfg
    #修改test-providers.d
    sed -i 's|^uri.*$|uri: file:\/\/'$TP_LIBVIRT'|g' $CONFIG_DIR/test-providers.d/io-github-autotest-libvirt.ini
    sed -i 's|^uri.*$|uri: file:\/\/'$TP_QEMU'|g' $CONFIG_DIR/test-providers.d/io-github-autotest-qemu.ini

    ppc64_cpu --smt=off
    systemctl stop firewalld
    systemctl mask firewalld
    systemctl stop iptables
    systemctl mask iptables
    systemctl stop NetworkManager
    setenforce 0
    
    #打开libvirtd日志
    sed -i "s|#log_level = 3|log_level = 3|g" /etc/libvirt/libvirtd.conf
    sed -i "s|^#log_outputs=.*$|log_outputs=\"3:file:/var/log/libvirt/libvirtd.log\"|g" /etc/libvirt/libvirtd.conf
    yum install expect -y
        
	if [ ! -f $LIBVIRT_BASE_PATH ];then
		echo "build libvirt base.cfg,wait a minute!"
        $CONFIG_DIR/./run -t libvirt --list-tests > /dev/null
	else
		echo "libvirt base.cfg exit!"
	fi
	if [ ! -f $QEMU_BASE_PATH ];then
        echo "build qemu base.cfg,wait a minute!"
        $CONFIG_DIR/./run -t qemu --list-tests > /dev/null
    else
        echo "qemu base.cfg exit!"
    fi

    sed -i "s/^remote_ip.*$/remote_ip = $remote_ip/" $CONFIG_DIR/backends/libvirt/cfg/base.cfg
    sed -i "s/^remote_ip.*$/remote_ip = $remote_ip/" $CONFIG_DIR/backends/qemu/cfg/base.cfg
	echo "set remote_ip = $remote_ip"

	sed -i "s/^local_ip.*$/local_ip = $local_ip/" $CONFIG_DIR/backends/libvirt/cfg/base.cfg
    sed -i "s/^local_ip.*$/local_ip = $local_ip/" $CONFIG_DIR/backends/qemu/cfg/base.cfg
	echo "set local_ip = $local_ip"

	sed -i "s/^local_pwd.*$/local_pwd = $local_pwd/" $CONFIG_DIR/backends/libvirt/cfg/base.cfg
    sed -i "s/^local_pwd.*$/local_pwd = $local_pwd/" $CONFIG_DIR/backends/qemu/cfg/base.cfg
	echo "set local_pwd = $local_pwd"

	sed -i "s/^main_vm.*$/main_vm = $main_vms/" $CONFIG_DIR/backends/libvirt/cfg/base.cfg
    sed -i "s/^main_vm.*$/main_vm = $main_vms/" $CONFIG_DIR/backends/qemu/cfg/base.cfg
	echo "set main_vms = $main_vms"

	sed -i "s/^vms.*$/vms = $vms/" $CONFIG_DIR/backends/libvirt/cfg/base.cfg
    sed -i "s/^vms.*$/vms = $vms/" $CONFIG_DIR/backends/qemu/cfg/base.cfg
	echo "set vms = $vms"
	
	sed -i "s/^# mac_nic1.*$/mac_nic1 = $mac_nic1/" $CONFIG_DIR/backends/qemu/cfg/base.cfg
	sed -i "s/^mac_nic1.*$/mac_nic1 = $mac_nic1/" $CONFIG_DIR/backends/qemu/cfg/base.cfg
	echo "set mac_nic1 = $mac_nic1"
        
    sed -i "s|^    image_name =.*$|    image_name ="$image_name"|" $CONFIG_DIR/shared/cfg/guest-os/Linux/RHEL/7.1/ppc64.cfg

	#修改migration的配置选项
	sed -i "s/^migrate_source_host =.*$/migrate_source_host = $local_ip/" $CONFIG_DIR/backends/libvirt/cfg/base.cfg
	sed -i "s/^migrate_source_pwd =.*$/migrate_source_pwd = $local_pwd/" $CONFIG_DIR/backends/libvirt/cfg/base.cfg
    sed -i "s/^migrate_dest_host =.*$/migrate_dest_host = $remote_ip/" $CONFIG_DIR/backends/libvirt/cfg/base.cfg
    sed -i "s/^migrate_dest_pwd =.*$/migrate_dest_pwd = $local_pwd/" $CONFIG_DIR/backends/libvirt/cfg/base.cfg

	#默认关闭截屏选项
	sed -i "s/^take_regular_screendumps.*$/take_regular_screendumps = no/" $CONFIG_DIR/backends/libvirt/cfg/base.cfg
	sed -i "s/^keep_screendumps_on_error.*$/keep_screendumps_on_error = no/" $CONFIG_DIR/backends/libvirt/cfg/base.cfg
	sed -i "s/^keep_screendumps.*$/keep_screendumps = no/" $CONFIG_DIR/backends/libvirt/cfg/base.cfg
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
    	sed -i -e 's|^    nodesuspend_remote_ip =.*$|    nodesuspend_remote_ip = '$remote_ip'|' $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/virsh_cmd/host/virsh_nodesuspend.cfg
    	sed -i -e "s|^    nodesuspend_remote_pwd =.*$|    nodesuspend_remote_pwd = $remote_pwd|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/virsh_cmd/host/virsh_nodesuspend.cfg

    	#libvirt_scsi_partition = "" 为用例libvirt_scsi指定测试分区
    	echo "set partition for testcases:libvirt_scsi!"
    	echo
    	sed -i "s/^    libvirt_scsi_partition =.*$/    libvirt_scsi_partition = \/dev\/$ENTER_YOUR_AVAILABLE_PARTITION/" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/libvirt_scsi.cfg
	
	#block_device =“” 为用例virsh_volume_application指定磁盘设备
        echo "set block_device for testcases:virsh_volume_application!"
        echo
        sed -i "s|^    block_device =.*$|    block_device = $BLOCK_DEVICE|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/virsh_cmd/volume/virsh_volume_application.cfg
	
        #block_device =“” 为用例storage_discard指定磁盘设备
        echo "set discard_device for testcases:storage_discard!"
        echo
        sed -i "s|^    discard_device =.*$|    discard_device = $BLOCK_DEVICE|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/storage_discard.cfg
         
    	#为用例pool_create创建pool.xml
    	echo "build pool.xml for testcases:virsh_pool_create!"
    	echo
    	sed -i -e "s|"/PATH/TO/POOL.XML"|$PATH_OF_POOL_XML|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/virsh_cmd/pool/virsh_pool_create.cfg
    	cat > $PATH_OF_POOL_XML  <<-EOF
<pool type='dir'>
  <name>virt-test-pool</name>
  <capacity unit='bytes'>0</capacity>
  <allocation unit='bytes'>0</allocation>
  <available unit='bytes'>0</available>
  <source>
  </source>
  <target>
    <path>$CONFIG_DIR/shared/pool</path>
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
	sed -i -e "s/^                    vms*$/                    vms = $vms/" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/virsh_cmd/domain/virsh_cpu_baseline.cfg
	sed -i -e "s/^                    main_vm =*$/                    main_vm = $main_vms/" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/virsh_cmd/domain/virsh_cpu_baseline.cfg
 
    	#为用例virsh.domstats指定测试机
    	echo "set config for testcases:virsh.domstats!"
    	echo
    	sed -i -e "s/^    vm_list.*$/    vm_list = "$vms"/" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/virsh_cmd/monitor/virsh_domstats.cfg
    	sed -i -e "s|virt-tests-vm1||" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/virsh_cmd/monitor/virsh_domstats.cfg
       
    	#修改guest_numa的配置文件，改动qemu默认配置参数node,nodeid=1,cpus=2-3,mem=301   libvirt1.1.9版本需要做修改，1.1.19版本不需改动
    	#echo "modify config for testcases:guest_numa!"
    	#echo
    	#sed -i -e "s|node,nodeid=0,cpus=0-1,mem=300|node,nodeid=0,cpus=0-1,memdev=ram-node0|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/numa/guest_numa.cfg
    	#sed -i -e "s|node,nodeid=1,cpus=2-3,mem=301|node,nodeid=1,cpus=2-3,memdev=ram-node1|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/numa/guest_numa.cfg
       
    	#为用例virsh.domcapabilities指定远程测试主机
    	echo "set config for testcases:virsh.domcapabilities!"
    	echo
    	sed -i -e "s|^                    target_uri =.*$|                    target_uri = \"qemu+ssh://$remote_ip/system\"|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/virsh_cmd/host/virsh_domcapabilities.cfg
       
    	#为用例virsh.cpu_models指定远程测试主机
    	echo "set config for testcases:virsh.cpu_models!"
    	echo
    	sed -i -e "s|^                    target_uri = \"qemu+ssh://.*$|                    target_uri = \"qemu+ssh://$remote_ip/system\"|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/virsh_cmd/host/virsh_cpu_models.cfg
        sed -i -e "s|^    cpu_arch =.*$|    cpu_arch = "ppc64"|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/virsh_cmd/host/virsh_cpu_models.cfg
	
	#为用例remote_access指定测试配置
	#remote_with_ssh
	sed -i -e "s|^    server_ip =.*$|    server_ip = $remote_ip|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/remote_access/remote_with_ssh.cfg
	sed -i -e "s|ENTER.YOUR.REMOTE.USER|root|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/remote_access/remote_with_ssh.cfg
	sed -i -e "s|^    server_pwd =.*$|    server_pwd = $local_pwd|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/remote_access/remote_with_ssh.cfg
	sed -i -e "s|^    client_ip =.*$|    client_ip = $local_ip|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/remote_access/remote_with_ssh.cfg
        sed -i -e "s|ENTER.YOUR.CLIENT.USER|root|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/remote_access/remote_with_ssh.cfg
        sed -i -e "s|^    client_pwd =.*$|    client_pwd = $local_pwd|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/remote_access/remote_with_ssh.cfg	
	#remote_with_tcp
	sed -i -e "s|^    server_ip =.*$|    server_ip = $remote_ip|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/remote_access/remote_with_tcp.cfg
        sed -i -e "s|ENTER.YOUR.REMOTE.USER|root|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/remote_access/remote_with_tcp.cfg
        sed -i -e "s|^    server_pwd =.*$|    server_pwd = $local_pwd|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/remote_access/remote_with_tcp.cfg
	#remote_with_tls
	sed -i -e "s|^    server_ip =.*$|    server_ip = $remote_ip|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/remote_access/remote_with_tls.cfg
        sed -i -e "s|ENTER.YOUR.REMOTE.USER|root|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/remote_access/remote_with_tls.cfg
        sed -i -e "s|^    server_pwd =.*$|    server_pwd = $local_pwd|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/remote_access/remote_with_tls.cfg
	sed -i -e "s|^    client_ip =.*$|    client_ip = $local_ip|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/remote_access/remote_with_tls.cfg
        sed -i -e "s|ENTER.YOUR.CLIENT.USER|root|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/remote_access/remote_with_tls.cfg
        sed -i -e "s|^    client_pwd =.*$|    client_pwd = $local_pwd|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/remote_access/remote_with_tls.cfg
	sed -i -e "s|^    server_cn =.*$|    server_cn = $remotehost|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/remote_access/remote_with_tls.cfg
	sed -i -e "s|^    client_cn =.*$|    client_cn = $localhost|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/remote_access/remote_with_tls.cfg
	#remote_with_unix	
	sed -i -e "s|^    server_ip =.*$|    server_ip = $remote_ip|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/remote_access/remote_with_unix.cfg
        sed -i -e "s|ENTER.YOUR.REMOTE.USER|root|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/remote_access/remote_with_unix.cfg
        sed -i -e "s|^    server_pwd =.*$|    server_pwd = $local_pwd|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/remote_access/remote_with_unix.cfg
	sed -i -e "s|^    client_ip =.*$|    client_ip = $local_ip|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/remote_access/remote_with_unix.cfg
        sed -i -e "s|ENTER.YOUR.CLIENT.USER|root|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/remote_access/remote_with_unix.cfg
        sed -i -e "s|^    client_pwd =.*$|    client_pwd = $local_pwd|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/remote_access/remote_with_unix.cfg

	#为用例graphics_functional指定测试bridge_device和macvtap_device
	sed -i -e "s|^    macvtap_device =.*$|    macvtap_device = $bridge|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/graphics/graphics_functional.cfg
	sed -i -e "s|^    bridge_device =.*$|    bridge_device = $bridge|" $CONFIG_DIR/../tp-libvirt/libvirt/tests/cfg/graphics/graphics_functional.cfg
}

#测试用例所需的软件包安装
install()
{
	echo "###########  INSTALL RPMS FOR　TESTS  ##########"
	echo
	yum install virt-top -y
	yum install ksm -y
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

remotesh()
{
    cat > /home/set_remote_local.sh  <<-EOF  
#!/bin/sh    
#$1为local_ip  $2为local_hostname  $3为remote_ip   $4为remote_hostname
#做qemu命令链接
ln -s /usr/bin/qemu-system-ppc64 /usr/bin/qemu-kvm > /dev/null 2>&1
ln -s /usr/bin/qemu-system-ppc64 /usr/bin/kvm > /dev/null 2>&1
#修改主机名
hostname $2
#将远程主机名写入hosts文件
grep "$3" /etc/hosts
if [ \$? == 0 ]; then
    grep "$3 $4" /etc/hosts
    if [ \$? == 0 ]; then
        echo "remote_ip has been set to hosts"
    else
        sed -i "s|^$3.*$|$3 $4|" /etc/hosts
    fi
else
    echo "$3 $4" >> /etc/hosts
fi
#修改migration监听地址
grep "migration_address" /etc/libvirt/qemu.conf
if [ \$? == 0 ]; then
    grep "# migration_address" /etc/libvirt/qemu.conf
    if [ \$? == 0 ]; then
        sed -i "s|^# migration_address.*$|migration_address =  '0.0.0.0'|" /etc/libvirt/qemu.conf
    else
        sed -i "s|^migration_address.*$|migration_address =  '0.0.0.0'|" /etc/libvirt/qemu.conf
    fi
else
    echo "migration_address =  '0.0.0.0'" >> /etc/libvirt/qemu.conf
fi
EOF
        
}

main()
{	
	setenv
               
    	echo "##### SET remote-local NO PASSWORD LOGIN  #####"
	echo
 	auto_ssh_copy_id  $local_pwd $remote_ip
    	auto_scp_is_rsa
        
    	expect -c  "set timeout -1;
        	    spawn ssh-copy-id root@$local_ip;
                    expect {
                    *(yes/no)* {send -- yes\r;exp_continue;}
                    *assword:* {send -- $local_pwd\r;exp_continue;}
                   }"
    	remotesh $local_ip $localhost $remote_ip $remotehost
    	sh /home/set_remote_local.sh
    	remotesh $remote_ip $remotehost $local_ip $localhost
    	scp /home/set_remote_local.sh root@$remote_ip:/home/set_remote_local.sh
    	ssh root@$remote_ip "sh /home/set_remote_local.sh"
        ssh root@$remote_ip "rm -rf /home/set_remote_local.sh"
        rm -rf /home/set_remote_local.sh
    
	specialcfg
	install	
	
	echo
	echo "CONFIG FINISH,YOU CAN RUN TESTS!"
}

main
