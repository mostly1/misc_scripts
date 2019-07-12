#!/bin/bash

#get all conf files
source .backup_conf

prep_icinga2_directories() {
#prepare satellites directories.
echo "Preparing backup directories for icinga....."
for i in $(cat node_list); do
  bd_full_path="${backup_dir}$i-${today}"
  mkdir -p ${bd_full_path}
  for x in ${main_dir} ${includes} ${certs}; do
    mkdir -p ${bd_full_path}/${x}
  done
done

#prepare main monitor directories, including icingaweb2 and apache
mkdir ${backup_dir}/${master}
for x in ${main_dir} ${includes} ${certs} ${apache} ${icingaweb2} ${mysql}; do
  mkdir -p ${backup_dir}/${master}/${x}
done

}

prep_rt_directories() {
#prepare racktables directories
echo "Preparing backup directories for racktables....."
mkdir ${backup_dir}/${racktables}
for i in ${racktables_main} ${apache} ${mysql}; do
  mkdir -p ${backup_dir}/${racktables}/${i}
done

}

prep_ob_directories() {
#prepare observium directories
echo "Preparing backup directories for observium....."
mkdir ${backup_dir}/${observium}
for i in ${observium_main} ${librenms} ${nginx} ${mysql}; do
  mkdir -p ${backup_dir}/${observium}/${i}
done

}

pull_icinga_files(){
#get all needed remote files for icinga. using parallel to speed up process.
echo "Starting icinga satellite backup in parallel....."
echo "Downloading stage 1/3....."
cat node_list | parallel -j 4 rsync  -az  --rsync-path=\"sudo rsync\" {}:${icinga_main}* ${backup_dir}{}-${today}/${main_dir}
echo "Downloading stage 2/3....."
cat node_list | parallel -j 4 rsync  -az  --rsync-path=\"sudo rsync\" {}:${icinga_includes}* ${backup_dir}{}-${today}/${includes}
echo "Downloading stage 3/3....."
cat node_list | parallel -j 4 rsync  -az  --rsync-path=\"sudo rsync\" {}:${icinga_var}* ${backup_dir}{}-${today}/${certs}
echo "Getting list of installed packages....."
for i in $(cat node_list); do
  ssh -A ${i} sudo dpkg -l >> ${backup_dir}${i}-${today}/installed_packages.list
done
#rsync from main node locally.
echo "Syncing master node....."
sudo rsync  -az ${icinga_main} ${backup_dir}${master}/${main_dir}
sudo rsync  -az ${icinga_includes} ${backup_dir}${master}/${includes}
sudo rsync  -az ${icinga_var} ${backup_dir}${master}/${certs}
sudo rsync  -az ${icinga_apache} ${backup_dir}${master}/${apache}
sudo rsync  -az ${icinga_web2} ${backup_dir}${master}/${icingaweb2}
sudo dpkg -l >> ${backup_dir}${master}/installed_packages.list
echo "Dumping local mysql.....Ignore password warnings.."
sudo mysqldump -u ${username} -p${password} --all-databases >> ${backup_dir}${master}/${mysql}/${mysql_dump_name}
}

pull_rt_files() {
#pull all needed racktable files
echo "Starting racktables backup in parallel....."
(sudo rsync -az lacadmin@${rt_host}:${rt_main} ${backup_dir}${racktables}/${racktables_main};sudo rsync -az lacadmin@${rt_host}:${rt_apache} ${backup_dir}${racktables}/${apache}) | parallel
echo "Getting list of installed packages....."
ssh -A ${rt_host} sudo dpkg -l >> ${backup_dir}${racktables}/installed_packages.list
echo "Dumping remote mysql.....Ignore any warnings.."
ssh -A lacadmin@${rt_host} sudo mysqldump -u ${rt_user} -p${rt_pass} --all-databases >> ${backup_dir}${racktables}/${mysql}/${rt_mysql_dump_name}
}

pull_ob_files() {
#pull all needed observium files, including librenms
echo "Starting observium backup in parallel....."
(sudo rsync -az lacadmin@${ob_host}:${ob_nginx} ${backup_dir}${observium}/${nginx};sudo rsync -az --exclude "rrd.*" --exclude "logs*" lacadmin@${ob_host}:${ob_main} ${backup_dir}${observium}/${observium_main};sudo rsync -az --exclude "logs" lacadmin@${ob_host}:${ob_librenms} ${backup_dir}${observium}/${librenms}) | parallel
echo "Getting list of installed packages....."
ssh -A ${ob_host} sudo dpkg -l >> ${backup_dir}${observium}/installed_packages.list
echo "Dumping remote mysql.....Ignore any warnings.."
ssh -A lacadmin@${ob_host} sudo mysqldump -u ${ob_user} -p${ob_pass} --all-databases >> ${backup_dir}${observium}/${mysql}/${ob_mysql_dump_name}
}

archive(){
#tar up everything in the working directory into one archive
echo "Compressing backup....."
cd /home/lacadmin/internal_backups/
sudo tar -czf ${1}-${today}.tar.gz working/
}

cleanup(){
echo "Cleaning up directories....."
#empty out working directory after everything has been tared and is ready to be pushed.
sudo rm -rf ${backup_dir}*
}

stats() {

backup_size=$(du -sh /home/lacadmin/internal_backups/internal_backup-${today}.tar.gz)
echo "Backup Size = ${backup_size}"
echo "Total time elapsed = ${1}s"
}


backup() {
echo "Starting backup process....."
start=$(date +%s)
prep_icinga2_directories
prep_rt_directories
prep_ob_directories
pull_icinga_files
pull_rt_files
pull_ob_files
archive internal_backup
#cleanup
echo "Complete!"
end=$(date +%s)
time_completed=$((${end} - ${start}))
stats ${time_completed}
}



backup
