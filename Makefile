z: z.S
	gcc -I. -m32 z.S -nodefaultlibs -nostartfiles -Wl,-N -Wl,-Ttext -Wl,100000 -Wl,--build-id=none -o z
