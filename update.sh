#!/bin/bash

script_path=$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/"

config_file='deploy/config'

# source variables
if [ ! -e ${script_path}${config_file} ]; then
    echo "Config file does not exist."
    exit 1
fi
source ${script_path}${config_file}

deploy_key=${script_path}${deploy_file}
git_update=0
allowed_user=0
iam=$(whoami)
run_as=''

# authenticate user
for valid_user in ${valid_users[@]}; do
    if [ "$iam" = "$valid_user" ]; then
        allowed_user=1
        break
    fi
done

if [ $allowed_user -eq 0 ]; then 
    echo "User is not in valid users."
    exit 1
fi

# run script as correct user
if [ "$iam" != "$user" ]; then
      run_as="sudo -H -u$user "  
fi

# allow script to run with either git update file or -f arg
if [ -e $script_path"var/tmp/git_update" ]; then
    git_update=1
fi

if [ -n "$1" ]; then
    if [ $1 = "-f" ]; then
        git_update=1
    fi
fi

# deploy
if [ $git_update -eq 1 ]; then
    ${run_as}php $script_path"bin/magento" maintenance:enable
    ${run_as}php $script_path"bin/magento" cache:disable
    ${run_as}php $script_path"bin/magento" cache:flush

    ${run_as}ssh-agent bash -c 'ssh-add '$deploy_key'; git --git-dir='$script_path'.git/ --work-tree='$script_path' reset --hard HEAD; git --git-dir='$script_path'.git/ --work-tree='$script_path' clean -f -d; git --git-dir='$script_path'.git/ --work-tree='$script_path' pull; composer install --no-dev; git --git-dir='$script_path'.git/ --work-tree='$script_path' reset --hard HEAD; git --git-dir='$script_path'.git/ --work-tree='$script_path' clean -f -d'

    chown -R $permiss $script_path*
    chown -R $permiss $script_path.??*

    chmod -R 775 $script_path*
    chmod -R 775 $script_path.??*

    ${run_as}php $script_path"bin/magento" setup:upgrade
    ${run_as}php $script_path"bin/magento" setup:di:compile
    ${run_as}php $script_path"bin/magento" setup:static-content:deploy fr_CA en_US --jobs 1

    chown -R $permiss $script_path*
    chown -R $permiss $script_path.??*

    chmod -R 775 $script_path*
    chmod -R 775 $script_path.??*

    chmod 700 $deploy_key
    chmod +x $script_path"update.sh"
    
    chmod 700 ${script_path}${config_file}

    rm -f $script_path"var/tmp/git_update"

    ${run_as}php $script_path"bin/magento" cache:enable
    ${run_as}php $script_path"bin/magento" maintenance:disable
fi
