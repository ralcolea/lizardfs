CHUNKSERVERS=1
USE_RAMDISK=YES
setup_local_empty_lizardfs info

cd ${info[mount0]}

# Checking that file .crash exists
assert_file_exists ".crash"

expected_content="Hello world crash!!!"
real_content=$(cat .crash)

# Checking that file .crash contains the expected text
expect_equals "$expected_content" "$real_content"

# Checking that file .crash doesn't contain other text than "Hello world crash!!!"
expect_not_equal "Hello" "$real_content"
expect_not_equal "world" "$real_content"
expect_not_equal "crash!!!" "$real_content"
