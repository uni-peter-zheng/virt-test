#!/bin/sh

#init初始化配置 公共config
export remote_ip="192.168.1.92"
export remote_pwd="123456"
export local_ip="192.168.1.71"
export local_pwd="123456"
export vms="RedOS-autotest RedOS-autotest2"
export main_vms="RedOS-autotest"
export localhost="RedOS-71"
export remotehost="RedOS-92"
export bridge="br0"
export AUTOTEST_PATH="/home/autotest/"

#
export ENTER.YOUR.AVAILABLE.PARTITION="dev/sda2" #为用例libvirt_scsi指定测试分区
export PATH_OF_POOL_XML="/home/virt-test/pool/pool.xml" #指定用例pool_create创建的pool.xml的路径

usage()
{
    cat <<-EOF >&2
    usage: [ -h ] [ -r remote_ip ] [ -g vms ] [ -G main_vms ] [ -l localhost ][ -R remotehost ][ -t testcase][ -T testcase -v]
    -h                               Prints all available options.
    -r              remote_ip        The default user is root 
    -L              local_ip
    -P              local_pwd
    -g              vms              Default will be the main test guest
    -G              main_vms
    -l              localhost name
    -R              remotehost name
    -t              testcase
    -T              testcase -v
EOF
exit 0
}

sed -i "s/^remote_ip.*$/remote_ip = $remote_ip/" ./backends/libvirt/cfg/base.cfg
echo "set remote_ip = $remote_ip"
         
sed -i "s/^local_ip.*$/local_ip = $local_ip/" ./backends/libvirt/cfg/base.cfg
echo "set local_ip = $local_ip"

sed -i "s/^local_pwd.*$/local_pwd = $local_pwd/" ./backends/libvirt/cfg/base.cfg
echo "set local_pwd = $local_pwd"

sed -i "s/^main_vm.*$/main_vm = $main_vms/" ./backends/libvirt/cfg/base.cfg
echo "set main_vms = $main_vms"

sed -i "s/^vms.*$/vms = $vms/" ./backends/libvirt/cfg/base.cfg
echo "set vms = $vms"

echo "set localhost=$localhost"
hostname $localhost

remotehost=${remotehost:-$OPTARG}

while getopts hr:L:P:g:G:l:R:t:T: arg
      do case $arg in
         h) usage;;
         r)
            remote_ip=${remote_ip:-$OPTARG}
            sed -i "s/^remote_ip.*$/remote_ip = $remote_ip/" ./backends/libvirt/cfg/base.cfg
            echo "set remote_ip = $remote_ip";;
         L)
            local_ip=${local_ip:-$OPTARG}
            sed -i "s/^local_ip.*$/local_ip = $local_ip/" ./backends/libvirt/cfg/base.cfg
            echo "set local_ip = $local_ip";;
         P)
            local_pwd=${local_pwd:-$OPTARG}
            sed -i "s/^local_pwd.*$/local_pwd = $local_pwd/" ./backends/libvirt/cfg/base.cfg
            echo "set local_pwd = $local_pwd";;
         g)
            main_vms=${main_vms:-$OPTARG}
            sed -i "s/^main_vm.*$/main_vm = $main_vms/" ./backends/libvirt/cfg/base.cfg
            echo "set main_vms = $main_vms";;
         G)
            vms=${vms:-$OPTARG}
            sed -i "s/^vms =/vms = $vms/" ./backends/libvirt/cfg/base.cfg
            echo "set vms = $vms";;
         l)
            localhost=${localhost:-$OPTARG}
            echo "set localhost=$localhost"
            hostname $localhost;;
         R)
            remotehost=${remotehost:-$OPTARG};;
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
        grep -rn "AUTOTEST" ~/.bashrc
        if [ $? = 1 ];then
                echo "export AUTOTEST_PATH=$AUTOTEST_PATH" >> ~/.bashrc
                echo "export AUTOTEST_PATH=$AUTOTEST_PATH"
        else
        echo "AUTOTEST_PATH has been set!"
        fi
        ln -s /usr/bin/qemu-system-ppc64 /usr/bin/qemu-kvm
        ln -s /usr/bin/qemu-system-ppc64 /usr/bin/kvm
        echo "make link qemu-system-ppc64 to qemu-kvm"

        systemctl stop firewalld
        systemctl mask firewalld
        systemctl stop iptables
        systemctl mask iptables
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
}

#配置locoalhost和remote的ssh无密码访问
auto_ssh_copy_id () {
    expect -c " set timeout -1;
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
                    eof        {exit 0;}
                }";
}
auto_ssh_copy_id  $local_pwd $remote_ip
expect -c "set timeout -1;
           spawn ssh root@$remote_ip "ssh-keygen"
           expect {
               *y/n* {send -- y\r;exp_continue;}
               */root/.ssh/id_rsa* {send -- \r;exp_continue;}
               *empty* {send -- \r;exp_continue;}
               *same* {send -- \r;exp_continue;}
           }"
scp root@$remote_ip:/root/.ssh/id_rsa.pub /root/.ssh/authorized_keys

#单独测试用例配置的修改
specialcfg()
{
      #config remote-test ip for teset: virsh_nodesuspend
       sed -i -e 's|ENTER.YOUR.REMOTE.EXAMPLE.COM|'$remote_ip'|' ../tp-libvirt/libvirt/tests/cfg/virsh_cmd/host/virsh_nodesuspend.cfg
       sed -i -e "s|EXAMPLE.PWD|$remote_pwd|" ../tp-libvirt/libvirt/tests/cfg/virsh_cmd/host/virsh_nodesuspend.cfg

      #libvirt_scsi_partition = "/dev/sda2" 为用例libvirt_scsi指定测试分区
       sed -i -e "s|"ENTER.YOUR.AVAILABLE.PARTITION"|$ENTER.YOUR.AVAILABLE.PARTITION|" ../tp-libvirt/libvirt/tests/cfg/libvirt_scsi.cfg
      
      #virsh_iface 配置修改 iface_name，unprivileged_user，ping_ip
      # sed -i -e "s|"ENTER.BRIDGE.NAME"|$bridge|" ../tp-libvirt/libvirt/tests/cfg/virsh_cmd/interface/virsh_iface.cfg
      # sed -i -e "s|"EXAMPLE"|root|" ../tp-libvirt/libvirt/tests/cfg/virsh_cmd/interface/virsh_iface.cfg
      # sed -i -e "s|"ENTER.VALID.IP.ADDRESS"|192.168.1.1|" ../tp-libvirt/libvirt/tests/cfg/virsh_cmd/interface/virsh_iface.cfg
      # sed -i -e "s|"ENTER.ETH.IP.ADDRESS"|192.168.1.72|" ../tp-libvirt/libvirt/tests/cfg/virsh_cmd/interface/virsh_iface.cfg
      # sed -i -e "s|"ENTER.ETHERNET.CARD"|eth0|" ../tp-libvirt/libvirt/tests/cfg/virsh_cmd/interface/virsh_iface.cfg
 
      #virsh_nodesuspend 配置修改nodesuspend_remote_ip和nodesuspend_remote_pwd
       sed -i -e "s|"ENTER.YOUR.REMOTE.EXAMPLE.COM"|$remote_ip|" ../tp-libvirt/libvirt/tests/cfg/virsh_cmd/host/virsh_nodesuspend.cfg
       sed -i -e "s|"EXAMPLE.PWD"|$remote_pwd|" ../tp-libvirt/libvirt/tests/cfg/virsh_cmd/host/virsh_nodesuspend.cfg
       
       #为用例pool_create创建pool.xml
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
    <path>/home/virt-test/shared/pool</path>
  </target>
</pool>
EOF
       #用例virsh.pool_acl，iscsi默认收ipv6连接，修改/eth/hosts，注释掉::1
        sed -i 's/^::1/#::1/g' /etc/hosts
     
       #为用例virsh.cpu_baseline指定测试机
        sed -i -e "s|virt-tests-vm1|$main_vms|" ../tp-libvirt/libvirt/tests/cfg/virsh_cmd/domain/virsh_cpu_baseline.cfg
 
       #修改guest_numa的配置文件，改动qemu默认配置参数node,nodeid=1,cpus=2-3,mem=301 
        sed -i -e "s|node,nodeid=0,cpus=0-1,mem=300|node,nodeid=0,cpus=0-1,memdev=ram-node0|" ../tp-libvirt/libvirt/tests/cfg/numa/guest_numa.cfg
        sed -i -e "s|node,nodeid=1,cpus=2-3,mem=301|node,nodeid=1,cpus=2-3,memdev=ram-node1|" ../tp-libvirt/libvirt/tests/cfg/numa/guest_numa.cfg
}

#测试用例所需的软件包安装
install()
{
        yum install iscsi* -y
        yum install targetcli* -y
        yum install targetd -y
        yum install numactl -y
        yum install policycoreutils-python -y
        yum install mkisofs -y
        yum install perf -y
        yum install fuse-sshfs -y
}

setenv
specialcfg
install

