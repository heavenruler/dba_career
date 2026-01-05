# fio
```
#!/bin/bash

echo "readwrite 4K";
fio -directory=/data/fio -iodepth=1 -thread -rw=rw -ioengine=libaio -direct=1 -bs=4K -size=50G -numjobs=32 -group_reporting -name=mytest -runtime=60
rm -rf /data/fio/*
echo "";

echo "readwrite 8K";
fio -directory=/data/fio -iodepth=1 -thread -rw=rw -ioengine=libaio -direct=1 -bs=8K -size=50G -numjobs=32 -group_reporting -name=mytest -runtime=60
rm -rf /data/fio/*
echo "";

echo "readwrite 16K";
fio -directory=/data/fio -iodepth=1 -thread -rw=rw -ioengine=libaio -direct=1 -bs=16K -size=50G -numjobs=32 -group_reporting -name=mytest -runtime=60
rm -rf /data/fio/*
echo "";

echo "randreadwrite 4K";
fio -directory=/data/fio -iodepth=1 -thread -rw=randrw -ioengine=libaio -direct=1 -bs=4K -size=50G -numjobs=32 -group_reporting -name=mytest -runtime=60
rm -rf /data/fio/*
echo "";

echo "randreadwrite 8K";
fio -directory=/data/fio -iodepth=1 -thread -rw=randrw -ioengine=libaio -direct=1 -bs=8K -size=50G -numjobs=32 -group_reporting -name=mytest -runtime=60
rm -rf /data/fio/*
echo "";

echo "randreadwrite 16K";
fio -directory=/data/fio -iodepth=1 -thread -rw=randrw -ioengine=libaio -direct=1 -bs=16K -size=50G -numjobs=32 -group_reporting -name=mytest -runtime=60
rm -rf /data/fio/*
echo "";
```
