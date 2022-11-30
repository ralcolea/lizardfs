timeout_set 60 seconds
CHUNKSERVERS=1 \
	USE_RAMDISK=YES \
	MOUNT_EXTRA_CONFIG="mfscachemode=NEVER" \
	CHUNKSERVER_EXTRA_CONFIG="READ_AHEAD_KB = 1024|MAX_READ_BEHIND_KB = 2048"
	setup_local_empty_lizardfs info

mkdir -p ${TEMP_DIR}/mnt/ganesha
mkdir -p ${info[mount0]}/data
mkdir -p ${info[mount0]}/etc/ganesha
mkdir -p ${info[mount0]}/lib/ganesha
mkdir -p ${info[mount0]}/bin

MAX_PATH_DEPH=9

USER_ID=$(id -u lizardfstest)
GROUP_ID=$(id -g lizardfstest)
GANESHA_BS="$((1<<20))"

PID_FILE=${info[mount0]}/var/run/ganesha/ganesha.pid
if [ ! -f ${PID_FILE} ]; then  
	mkdir -p ${info[mount0]}/var/run/ganesha
	touch ${PID_FILE}
fi

cp -a /usr/lib/ganesha/libfsalcrashfs* ${info[mount0]}/lib/ganesha/
cp -a /usr/bin/ganesha.nfsd ${info[mount0]}/bin/

cd ${info[mount0]}/data
for i in $(seq 1 ${MAX_PATH_DEPH}); do
	mkdir -p dir${i}
	cd dir${i}
done

touch ./file
echo 'Ganesha_Test_Ok' > ./file
INODE=$(stat -c %i ./file)

cat <<EOF > ${info[mount0]}/etc/ganesha/ganesha.conf
NFS_KRB5 {
	Active_krb5=false;
} 
NFSV4 {
  Grace_Period = 5;
}
EXPORT
{
	Attr_Expiration_Time = 0;
	Export_Id = 99;
	Path = /data;
	Pseudo = /data;
	Access_Type = RW;
	FSAL {
		# Name = LizardFS;
		Name = CrashFS;
		hostname = localhost;
		port = ${lizardfs_info_[matocl]};
		# How often to retry to connect
       		io_retries = 5;
       		cache_expiration_time_ms = 2500;
	}
	Protocols = 4;
	CLIENT {
		Clients = localhost;
	}
}

# LizardFS {
CrashFS {
	PNFS_DS = true;
	PNFS_MDS = true;
}
EOF

sudo ${info[mount0]}/bin/ganesha.nfsd -f ${info[mount0]}/etc/ganesha/ganesha.conf
sudo mount -vvvv localhost:/data $TEMP_DIR/mnt/ganesha

cd ${TEMP_DIR}/mnt/ganesha
MAX_FILES=300
### Check mkdir / rmdir syscall
mkdir -p ./dir_on_ganesha
test -d ./dir_on_ganesha
rmdir ./dir_on_ganesha
test ! -d ./dir_on_ganesha

for i in $(seq ${MAX_FILES}); do
  touch ./file.${i};
  test -f ./file.${i};
done

### Check getattr / stat / syscall
STATS_REPORT="$(stat "$(find -name file)")"
assert_equals ${INODE} "$(echo "${STATS_REPORT}" | grep -i inode | cut -d: -f3 | cut -d" " -f2)"
assert_equals ${USER_ID} "$(echo "${STATS_REPORT}" | grep -i uid | cut -d/ -f2 | rev | awk '{print $1}' | rev)"
assert_equals ${GROUP_ID} "$(echo "${STATS_REPORT}" | grep -i gid | cut -d/ -f3 | rev | awk '{print $1}' | rev)"
assert_equals ${GANESHA_BS} "$(echo "${STATS_REPORT}" | grep -i 'io block' | cut -d: -f4 | awk '{print $1}')"

### Check readdir / ls|tree / syscall
assert_equals ${MAX_PATH_DEPH} $(tree ${TEMP_DIR}/mnt/ganesha | grep directories | awk '{print $1}')
assert_equals "$((${MAX_FILES} + 1))" "$(ls ${TEMP_DIR}/mnt/ganesha/ | wc -l)"

### Check open2 / cat|dd / syscall
assert_equals "Ganesha_Test_Ok" $(cat $(find -name file))

cd ${TEMP_DIR}
sudo umount -l ${TEMP_DIR}/mnt/ganesha
sudo kill -9 $(pgrep '^ganesha.nfsd$')
