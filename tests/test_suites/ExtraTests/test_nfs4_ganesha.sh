#
# To run this test you need to install ganesha and liblizardfs-client.so
#
#
timeout_set 60 seconds
CHUNKSERVERS=1 \
	USE_RAMDISK=YES \
	MOUNT_EXTRA_CONFIG="mfscachemode=NEVER" \
	CHUNKSERVER_EXTRA_CONFIG="READ_AHEAD_KB = 1024|MAX_READ_BEHIND_KB = 2048"
	setup_local_empty_lizardfs info

mkdir -p ${TEMP_DIR}/mnt/ganesha
mkdir -p ${TEMP_DIR}/mnt/ganesha/cthon_test
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
  echo "File doesn't exists, creating...";
	mkdir -p ${info[mount0]}/var/run/ganesha;
	touch ${PID_FILE};
else
	echo "File exists";
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

test_error_cleanup() {
  cd ${TEMP_DIR}
  sudo umount -l ${TEMP_DIR}/mnt/ganesha
  sudo kill -9 "$(pgrep '^ganesha.nfsd' | awk '{print $1}')"
}

sudo ${info[mount0]}/bin/ganesha.nfsd -f ${info[mount0]}/etc/ganesha/ganesha.conf
sudo mount -vvvv localhost:/data $TEMP_DIR/mnt/ganesha

cat <<EOF > "${TEMP_DIR}/mnt/ganesha/cthon04.patch"
diff --git a/lock/tlock.c b/lock/tlock.c
index 8c837a8..7060cca 100644
--- a/lock/tlock.c
+++ b/lock/tlock.c
@@ -479,21 +479,21 @@ fmtrange(offset, length)

 #ifdef LARGE_LOCKS                     /* non-native 64-bit */
        if (length != 0)
-               sprintf(buf, "[%16llx,%16llx] ", offset, length);
+               sprintf(buf, "[%16lx,%16lx] ", offset, length);
        else
-               sprintf(buf, "[%16llx,          ENDING] ", offset);
+               sprintf(buf, "[%16lx,          ENDING] ", offset);
 #else /* LARGE_LOCKS */
        if (sizeof (offset) == 4) {
                if (length != 0)
-                       sprintf(buf, "[%8lx,%8lx] ", (int32_t)offset,
+                       sprintf(buf, "[%i,%i] ", (int32_t)offset,
                                (int32_t)length);
                else
-                       sprintf(buf, "[%8lx,  ENDING] ", (int32_t)offset);
+                       sprintf(buf, "[%i,  ENDING] ", (int32_t)offset);
        } else {
                if (length != 0)
-                       sprintf(buf, "[%16llx,%16llx] ", offset, length);
+                       sprintf(buf, "[%16lx,%16lx] ", offset, length);
                else
-                       sprintf(buf, "[%16llx,          ENDING] ", offset);
+                       sprintf(buf, "[%16lx,          ENDING] ", offset);
        }
 #endif /* LARGE_LOCKS */

EOF

sudo -i -u lizardfstest bash << EOF
 cd "${TEMP_DIR}/mnt/ganesha"
 chmod o+w "$(pwd)"
 if test -d "${TEMP_DIR}/mnt/ganesha/cthon04"; then
    rm -rf "${TEMP_DIR}/mnt/ganesha/cthon04"
 fi

 git clone --no-checkout git://git.linux-nfs.org/projects/steved/cthon04.git
 cd cthon04
 git reset --hard HEAD
 git apply --ignore-whitespace "${TEMP_DIR}/mnt/ganesha/cthon04.patch"
# sudo chown -R lizardfstest:lizardfstest $TEMP_DIR/mnt/ganesha/cthon04
 make all
# git status
 export NFSTESTDIR=${TEMP_DIR}/mnt/ganesha/cthon_test
 ./runtests -b -n
 ./runtests -l -n
 ./runtests -s -n
EOF

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
assert_equals $((${MAX_PATH_DEPH} + 12)) $(tree ${TEMP_DIR}/mnt/ganesha | grep directories | awk '{print $1}')
assert_equals "$((${MAX_FILES} + 3))" "$(ls ${TEMP_DIR}/mnt/ganesha/ | wc -l)"

### Check open2 / cat|dd / syscall
assert_equals "Ganesha_Test_Ok" $(cat $(find -name file))

test_error_cleanup || true
