- IDC * 1

Benchmark from TiDB
```
[root@l-monitor-labroom-1 benchmark-tidb]# date ; ./a_genReport.sh sysbench_results_#1_tidb/
Mon Aug 18 10:53:37 CST 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        21.50                         16.79                 63.02                 9.84                  17864.6250               299.9722                         7621.74 per sec.    2399777.58          476.36 per sec.
oltp_read_write       31.37                         25.42                 81.66                 15.41                 11798.8750               299.9862                         6292.23 per sec.    2399889.72          314.61 per sec.
oltp_write_only       10.84                         8.19                  48.56                 3.26                  36628.2500               299.9501                         5860.25 per sec.    2399600.61          976.71 per sec.
select_random_points  4.33                          2.60                  43.01                 0.73                  115160.2500              299.8759                         3070.88 per sec.    2399007.02          3070.88 per sec.
select_random_ranges  3.49                          2.32                  27.84                 0.88                  129176.6250              299.8739                         3444.65 per sec.    2398991.52          3444.65 per sec.
```

Benchmark from TiProxy
```
[root@l-monitor-labroom-1 benchmark-tidb]# date ; ./a_genReport.sh sysbench_results_#1_tiproxy/
Mon Aug 18 11:21:59 CST 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        21.50                         17.05                 65.18                 10.16                 17588.5000               299.9395                         7503.99 per sec.    2399516.06          469.00 per sec.
oltp_read_write       31.94                         26.27                 87.87                 17.00                 11416.6250               299.9632                         6088.41 per sec.    2399705.41          304.42 per sec.
oltp_write_only       11.45                         8.48                  156.69                3.75                  35376.3750               299.9089                         5660.05 per sec.    2399271.26          943.34 per sec.
select_random_points  4.41                          2.72                  33.28                 0.74                  110115.0000              299.8389                         2936.30 per sec.    2398711.56          2936.30 per sec.
select_random_ranges  3.55                          2.37                  27.49                 0.86                  126765.0000              299.8118                         3380.35 per sec.    2398494.43          3380.35 per sec.
```

- IDC * 3 (4vCPU 8GB Ram)

Benchmark from TiDB
```
[root@l-monitor-labroom-1 benchmark-tidb]# date ; ./a_genReport.sh sysbench_results_#2_tidb
Mon Aug 18 13:11:52 CST 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        19.29                         14.91                 60.86                 8.42                  20121.5000               299.9338                         8584.75 per sec.    2399470.12          536.55 per sec.
oltp_read_write       30.81                         23.90                 809.77                14.52                 12552.2500               299.9713                         6693.06 per sec.    2399770.39          334.65 per sec.
oltp_write_only       10.65                         8.20                  35.96                 4.32                  36552.8750               299.9060                         5848.28 per sec.    2399248.21          974.71 per sec.
select_random_points  3.96                          2.31                  174.16                0.78                  130037.1250              299.8231                         3467.61 per sec.    2398584.53          3467.61 per sec.
select_random_ranges  3.13                          1.95                  29.62                 0.84                  153417.5000              299.7851                         4091.08 per sec.    2398280.45          4091.08 per sec.
```

Benchmark from TiProxy
```
[root@l-monitor-labroom-1 benchmark-tidb]# date ; ./a_genReport.sh sysbench_results_#2_tiproxy/
Mon Aug 18 13:12:30 CST 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        18.61                         14.37                 145.59                8.83                  20869.0000               299.9442                         8903.67 per sec.    2399553.59          556.48 per sec.
oltp_read_write       28.16                         22.79                 64.23                 14.54                 13163.2500               299.9658                         7019.79 per sec.    2399726.48          350.99 per sec.
oltp_write_only       10.65                         8.32                  38.05                 4.38                  36065.1250               299.9151                         5770.23 per sec.    2399320.49          961.70 per sec.
select_random_points  3.96                          2.28                  37.92                 0.75                  131615.3750              299.8247                         3509.69 per sec.    2398597.29          3509.69 per sec.
select_random_ranges  3.19                          1.93                  19.37                 0.85                  155384.2500              299.8055                         4143.52 per sec.    2398444.19          4143.52 per sec.
```

- IDC * 3 (8vCPU 16GB Ram)

Benchmark from TiDB
```
Wed Aug 20 10:49:47 CST 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        16.41                         12.37                 37.00                 8.04                  9703.7500                119.9897                         10349.42 per sec.   959917.48           646.84 per sec.
oltp_read_write       23.10                         18.65                 237.12                12.94                 6435.6250                119.9947                         8579.39 per sec.    959957.94           428.97 per sec.
oltp_write_only       7.56                          6.12                  28.07                 3.64                  19618.6250               119.9741                         7846.96 per sec.    959792.64           1307.83 per sec.
select_random_points  3.25                          1.80                  23.90                 0.78                  66620.8750               119.9371                         4441.26 per sec.    959496.86           4441.26 per sec.
select_random_ranges  2.43                          1.65                  16.15                 0.78                  72656.7500               119.9354                         4843.63 per sec.    959483.33           4843.63 per sec.
```

Benchmark from TiProxy
```
Wed Aug 20 10:49:47 CST 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        19.65                         15.15                 38.77                 8.89                  7922.6250                119.9936                         8449.29 per sec.    959948.98           528.08 per sec.
oltp_read_write       27.66                         21.65                 48.64                 14.37                 5541.2500                119.9930                         7387.28 per sec.    959943.69           369.36 per sec.
oltp_write_only       8.90                          6.91                  35.87                 4.16                  17365.7500               119.9765                         6945.77 per sec.    959812.25           1157.63 per sec.
select_random_points  3.07                          1.94                  15.81                 0.84                  61701.6250               119.9426                         4113.32 per sec.    959540.60           4113.32 per sec.
select_random_ranges  2.52                          1.78                  13.92                 0.79                  67431.7500               119.9402                         4495.30 per sec.    959521.59           4495.30 per sec.
```

- GCP * 1

Benchmark from TiDB
```
[root@l-monitor-labroom-1 benchmark-tidb]# date ; ./a_genReport.sh sysbench_results_#3_tidb
Mon Aug 18 15:14:46 CST 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        22.69                         18.79                 45.81                 12.63                 15965.8750               299.9827                         6811.74 per sec.    2399861.52          425.73 per sec.
oltp_read_write       36.24                         30.66                 68.37                 19.83                 9784.0000                299.9893                         5217.79 per sec.    2399914.43          260.89 per sec.
oltp_write_only       12.98                         9.89                  36.57                 4.51                  30334.5000               299.9666                         4853.39 per sec.    2399732.73          808.90 per sec.
select_random_points  6.21                          3.52                  35.79                 1.04                  85323.7500               299.9262                         2275.27 per sec.    2399409.81          2275.27 per sec.
select_random_ranges  4.74                          3.09                  23.51                 1.20                  97190.8750               299.9211                         2591.72 per sec.    2399368.65          2591.72 per sec.
```

Benchmark from TiProxy
```
[root@l-monitor-labroom-1 benchmark-tidb]# date ; ./a_genReport.sh sysbench_results_#3_tiproxy/
Mon Aug 18 15:14:50 CST 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        22.69                         18.72                 50.24                 12.09                 16024.2500               299.9796                         6836.67 per sec.    2399836.84          427.29 per sec.
oltp_read_write       39.65                         32.02                 78.78                 20.42                 9368.6250                299.9907                         4996.25 per sec.    2399925.46          249.81 per sec.
oltp_write_only       13.22                         10.05                 33.14                 4.25                  29833.8750               299.9644                         4773.30 per sec.    2399715.00          795.55 per sec.
select_random_points  6.21                          3.65                  20.51                 1.08                  82276.3750               299.9278                         2194.00 per sec.    2399422.73          2194.00 per sec.
select_random_ranges  5.09                          3.27                  25.38                 1.28                  91782.7500               299.9243                         2447.51 per sec.    2399394.01          2447.51 per sec.
```

- GCP * 3

Benchmark from TiDB
```
[root@l-monitor-labroom-1 benchmark-tidb]# date ; ./a_genReport.sh sysbench_results_#4_tidb
Mon Aug 18 16:34:11 CST 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        12.52                         10.70                 32.49                 7.95                  28036.1250               299.9655                         11961.66 per sec.   2399724.29          747.60 per sec.
oltp_read_write       25.74                         20.21                 104.08                12.61                 14840.6250               299.9868                         7914.49 per sec.    2399894.37          395.72 per sec.
oltp_write_only       9.73                          7.46                  32.75                 3.58                  40181.7500               299.9558                         6428.93 per sec.    2399646.42          1071.49 per sec.
select_random_points  3.68                          2.06                  20.86                 0.83                  145409.1250              299.8955                         3877.52 per sec.    2399163.64          3877.52 per sec.
select_random_ranges  2.35                          1.58                  18.70                 0.94                  189318.0000              299.8663                         5048.42 per sec.    2398930.45          5048.42 per sec.
```

Benchmark from TiProxy
```
[root@l-monitor-labroom-1 benchmark-tidb]# date ; ./a_genReport.sh sysbench_results_#4_tiproxy/
Mon Aug 18 16:34:15 CST 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        12.98                         11.05                 27.33                 8.05                  27145.3750               299.9631                         11581.67 per sec.   2399704.99          723.85 per sec.
oltp_read_write       23.52                         19.78                 57.86                 13.56                 15162.5000               299.9844                         8086.11 per sec.    2399875.10          404.31 per sec.
oltp_write_only       10.46                         7.76                  58.37                 3.56                  38641.7500               299.9585                         6182.53 per sec.    2399667.76          1030.42 per sec.
select_random_points  3.75                          2.20                  19.88                 0.84                  136338.8750              299.8950                         3635.66 per sec.    2399159.76          3635.66 per sec.
select_random_ranges  2.66                          1.82                  15.72                 0.97                  165113.5000              299.8846                         4402.98 per sec.    2399076.44          4402.98 per sec.
```

- IDC * 1 + GCP * 2

Benchmark from TiDB with IDC
```
Wed Aug 20 01:12:27 CST 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        86.00                         58.41                 290.04                8.17                  2055.0000                120.0240                         2190.60 per sec.    960192.14           136.91 per sec.
oltp_read_write       110.66                        83.32                 333.02                20.01                 1440.6250                120.0274                         1919.40 per sec.    960218.88           95.97 per sec.
oltp_write_only       27.17                         21.54                 256.09                8.50                  5570.6250                119.9932                         2227.79 per sec.    959945.90           371.30 per sec.
select_random_points  5.37                          2.76                  205.66                0.76                  43532.2500               119.9335                         2902.03 per sec.    959467.70           2902.03 per sec.
select_random_ranges  6.67                          2.81                  223.80                0.91                  42640.6250               119.9312                         2842.59 per sec.    959449.60           2842.59 per sec.
```

Benchmark from TiProxy with IDC
```
Wed Aug 20 01:12:27 CST 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        94.10                         66.79                 309.54                10.00                 1797.0000                120.0272                         1915.71 per sec.    960217.87           119.73 per sec.
oltp_read_write       123.28                        87.39                 327.31                20.53                 1373.7500                120.0453                         1830.36 per sec.    960362.39           91.52 per sec.
oltp_write_only       27.66                         21.93                 271.56                8.70                  5472.1250                119.9968                         2188.36 per sec.    959974.15           364.73 per sec.
select_random_points  12.98                         7.48                  43.22                 0.72                  16048.7500               119.9723                         1069.80 per sec.    959778.23           1069.80 per sec.
select_random_ranges  7.56                          4.87                  238.79                0.82                  24632.8750               119.9633                         1642.08 per sec.    959706.50           1642.08 per sec.
```

Benchmark from TiDB with GCP
```
Tue Aug 19 05:34:01 PM UTC 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        84.47                         45.57                 320.89                12.45                 2633.6250                120.0164                         2807.81 per sec.    960131.42           175.49 per sec.
oltp_read_write       114.72                        71.05                 342.97                20.99                 1689.7500                120.0536                         2250.76 per sec.    960429.12           112.54 per sec.
oltp_write_only       43.39                         32.78                 248.02                13.14                 3661.1250                120.0130                         1464.04 per sec.    960103.90           244.01 per sec.
select_random_points  20.74                         13.68                 287.81                5.68                  8770.6250                119.9995                         584.62 per sec.     959996.06           584.62 per sec.
select_random_ranges  15.83                         10.96                 27.73                 5.83                  10951.0000               119.9943                         730.01 per sec.     959954.63           730.01 per sec.
```

Benchmark from TiProxy with GCP
```
Tue Aug 19 05:34:01 PM UTC 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        167.44                        138.90                388.91                91.89                 864.3750                 120.0588                         920.81 per sec.     960470.67           57.55 per sec.
oltp_read_write       207.82                        179.04                442.05                123.56                670.7500                 120.0932                         892.93 per sec.     960745.55           44.65 per sec.
oltp_write_only       55.82                         50.12                 72.61                 38.71                 2394.5000                120.0228                         957.35 per sec.     960182.37           159.56 per sec.
select_random_points  30.81                         18.88                 1038.68               11.00                 6356.2500                120.0010                         423.66 per sec.     960007.77           423.66 per sec.
select_random_ranges  15.83                         15.43                 434.78                11.07                 7779.2500                119.9975                         518.58 per sec.     959979.69           518.58 per sec.
```

- IDC * 2 + GCP * 1

Benchmark from TiDB with IDC
```
Wed Aug 20 02:16:54 CST 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        78.60                         33.92                 300.46                8.24                  3538.3750                120.0129                         3771.30 per sec.    960103.32           235.71 per sec.
oltp_read_write       92.42                         43.73                 157.16                13.39                 2744.8750                120.0220                         3657.77 per sec.    960175.92           182.89 per sec.
oltp_write_only       31.94                         20.11                 679.20                4.18                  5965.5000                119.9918                         2385.65 per sec.    959934.29           397.61 per sec.
select_random_points  4.82                          2.85                  207.35                0.89                  42120.6250               119.9400                         2807.89 per sec.    959520.22           2807.89 per sec.
select_random_ranges  3.89                          2.56                  22.52                 1.04                  46847.2500               119.9318                         3123.03 per sec.    959454.76           3123.03 per sec.
```

Benchmark from TiProxy with IDC
```
Wed Aug 20 02:16:54 CST 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        80.03                         38.11                 311.67                9.21                  3148.7500                120.0115                         3356.62 per sec.    960092.20           209.79 per sec.
oltp_read_write       102.97                        56.88                 324.73                15.03                 2109.8750                120.0178                         2811.23 per sec.    960142.61           140.56 per sec.
oltp_write_only       31.37                         20.00                 53.31                 4.36                  6000.3750                119.9881                         2399.72 per sec.    959904.42           399.95 per sec.
select_random_points  4.82                          2.61                  52.86                 0.88                  45876.2500               119.9344                         3058.26 per sec.    959474.95           3058.26 per sec.
select_random_ranges  4.03                          2.51                  28.08                 1.02                  47799.6250               119.9309                         3186.53 per sec.    959447.57           3186.53 per sec.
```

Benchmark from TiDB with GCP
```
Tue Aug 19 06:54:43 PM UTC 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        87.56                         59.61                 301.55                12.86                 2013.5000                120.0343                         2146.35 per sec.    960274.54           134.15 per sec.
oltp_read_write       118.92                        87.34                 349.01                27.69                 1374.2500                120.0337                         1831.23 per sec.    960269.47           91.56 per sec.
oltp_write_only       43.39                         35.96                 269.15                20.91                 3337.6250                120.0166                         1334.70 per sec.    960132.90           222.45 per sec.
select_random_points  22.69                         18.32                 86.36                 11.05                 6550.1250                120.0006                         436.61 per sec.     960005.12           436.61 per sec.
select_random_ranges  16.41                         15.84                 81.49                 11.42                 7573.8750                120.0026                         504.85 per sec.     960020.46           504.85 per sec.
```

Benchmark from TiProxy with GCP
```
Tue Aug 19 06:54:43 PM UTC 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        161.51                        123.33                407.17                91.98                 973.3750                 120.0450                         1037.51 per sec.    960359.82           64.84 per sec.
oltp_read_write       204.11                        164.66                454.26                116.76                729.2500                 120.0811                         970.94 per sec.     960649.14           48.55 per sec.
oltp_write_only       56.84                         47.86                 292.09                33.55                 2507.6250                120.0191                         1002.70 per sec.    960152.59           167.12 per sec.
select_random_points  13.95                         10.16                 238.12                5.85                  11812.7500               119.9936                         787.43 per sec.     959949.11           787.43 per sec.
select_random_ranges  12.30                         9.76                  434.01                5.71                  12297.7500               119.9969                         819.76 per sec.     959975.51           819.76 per sec.
```

- IDC * 3 + GCP * 2

Benchmark from TiDB with IDC
```
Wed Aug 20 00:00:01 CST 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        78.60                         36.64                 921.44                8.33                  3275.5000                120.0212                         3491.61 per sec.    960169.26           218.23 per sec.
oltp_read_write       112.67                        79.82                 1000.73               18.07                 1503.6250                120.0210                         2003.82 per sec.    960168.31           100.19 per sec.
oltp_write_only       27.17                         17.72                 873.76                3.58                  6772.7500                119.9862                         2708.77 per sec.    959889.48           451.46 per sec.
select_random_points  3.68                          2.09                  206.89                0.72                  57337.8750               119.9291                         3822.38 per sec.    959432.96           3822.38 per sec.
select_random_ranges  6.43                          2.15                  842.92                0.75                  55697.3750               119.9344                         3712.91 per sec.    959475.22           3712.91 per sec.
```

Benchmark from TiProxy with IDC
```
Wed Aug 20 00:00:01 CST 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        81.48                         38.90                 1876.76               9.23                  3085.6250                120.0213                         3288.70 per sec.    960170.16           205.54 per sec.
oltp_read_write       110.66                        71.90                 1190.23               17.19                 1669.2500                120.0272                         2224.53 per sec.    960217.34           111.23 per sec.
oltp_write_only       31.37                         22.22                 1541.48               4.22                  5399.2500                119.9912                         2159.26 per sec.    959929.30           359.88 per sec.
select_random_points  4.33                          2.39                  206.08                0.81                  50107.6250               119.9351                         3340.25 per sec.    959480.64           3340.25 per sec.
select_random_ranges  3.13                          1.99                  211.58                0.84                  60294.2500               119.9248                         4019.43 per sec.    959398.08           4019.43 per sec.
```

Benchmark from TiDB with GCP
```
Tue Aug 19 04:23:21 PM UTC 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        116.80                        79.11                 4526.11               12.98                 1517.5000                120.0457                         1617.30 per sec.    960365.21           101.08 per sec.
oltp_read_write       147.61                        101.34                1683.01               22.65                 1184.7500                120.0633                         1578.12 per sec.    960506.19           78.91 per sec.
oltp_write_only       49.21                         39.41                 264.59                13.85                 3045.5000                120.0152                         1217.77 per sec.    960121.88           202.96 per sec.
select_random_points  32.53                         22.12                 1789.86               11.13                 5426.1250                120.0047                         361.68 per sec.     960037.31           361.68 per sec.
select_random_ranges  17.95                         16.66                 506.38                11.53                 7201.2500                120.0014                         480.02 per sec.     960011.43           480.02 per sec.
```

Benchmark from TiProxy with GCP
```
Tue Aug 19 04:23:21 PM UTC 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        193.38                        155.81                2269.94               95.58                 770.6250                 120.0714                         821.10 per sec.     960571.17           51.32 per sec.
oltp_read_write       253.35                        214.05                2120.40               122.25                561.0000                 120.0797                         747.24 per sec.     960637.34           37.36 per sec.
oltp_write_only       61.08                         50.66                 270.90                36.42                 2369.0000                120.0254                         947.25 per sec.     960202.89           157.87 per sec.
select_random_points  21.11                         12.76                 319.54                5.98                  9401.1250                119.9971                         626.67 per sec.     959976.85           626.67 per sec.
select_random_ranges  14.21                         10.31                 522.44                5.93                  11639.3750               119.9936                         775.90 per sec.     959948.53           775.90 per sec.
```

- IDC * 2 + GCP * 3

Benchmark from TiDB with IDC # 上班時段
```
Tue Aug 19 16:10:14 CST 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        511.33                        135.70                2478.60               14.26                 887.8750                 120.4846                         940.48 per sec.     963876.66           58.78 per sec.
oltp_read_write       419.45                        142.32                3359.08               36.20                 844.8750                 120.2441                         1118.76 per sec.    961952.74           55.94 per sec.
oltp_write_only       314.45                        76.76                 1494.25               16.05                 1563.6250                120.0226                         625.19 per sec.     960180.44           104.20 per sec.
select_random_points  15.00                         14.78                 927.59                6.02                  8118.1250                119.9820                         541.15 per sec.     959855.69           541.15 per sec.
select_random_ranges  12.98                         11.32                 456.86                6.40                  10597.1250               119.9752                         706.40 per sec.     959801.29           706.40 per sec.
```

Benchmark from TiProxy with IDC # 上班時段
```
Tue Aug 19 16:10:14 CST 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        102.97                        73.34                 2423.24               15.61                 1636.6250                120.0266                         1744.74 per sec.    960212.99           109.05 per sec.
oltp_read_write       139.85                        102.10                2638.35               35.75                 1175.6250                120.0263                         1566.09 per sec.    960210.69           78.30 per sec.
oltp_write_only       51.02                         40.58                 1022.64               15.30                 2957.2500                120.0041                         1182.54 per sec.    960033.05           197.09 per sec.
select_random_points  12.75                         11.09                 855.35                6.16                  10821.5000               119.9775                         721.36 per sec.     959820.29           721.36 per sec.
select_random_ranges  13.95                         11.69                 1087.71               6.21                  10262.2500               119.9754                         684.09 per sec.     959803.53           684.09 per sec.
```

Benchmark from TiDB with IDC # 離峰時段
```
Tue Aug 19 21:52:49 CST 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        89.16                         63.53                 318.37                13.16                 1889.6250                120.0460                         2013.68 per sec.    960368.39           125.85 per sec.
oltp_read_write       123.28                        95.83                 304.06                27.19                 1252.5000                120.0266                         1668.52 per sec.    960212.40           83.43 per sec.
oltp_write_only       44.17                         40.99                 2146.90               17.60                 2927.5000                120.0024                         1170.63 per sec.    960018.81           195.11 per sec.
select_random_points  12.75                         15.07                 3076.83               5.94                  7962.2500                119.9853                         530.76 per sec.     959882.78           530.76 per sec.
select_random_ranges  11.65                         10.87                 157.78                6.21                  11036.1250               119.9820                         735.65 per sec.     959856.35           735.65 per sec.
```

Benchmark from TiProxy with IDC # 離峰時段
```
Tue Aug 19 21:52:50 CST 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        94.10                         64.67                 166.30                14.70                 1856.2500                120.0394                         1978.59 per sec.    960314.96           123.66 per sec.
oltp_read_write       130.13                        111.16                2584.99               34.56                 1079.8750                120.0384                         1438.38 per sec.    960307.08           71.92 per sec.
oltp_write_only       45.79                         39.93                 3081.18               17.76                 3005.6250                120.0145                         1201.83 per sec.    960116.32           200.30 per sec.
select_random_points  12.30                         11.79                 877.62                6.15                  10175.6250               119.9799                         678.31 per sec.     959839.30           678.31 per sec.
select_random_ranges  11.87                         10.84                 55.59                 6.22                  11069.6250               119.9807                         737.90 per sec.     959845.20           737.90 per sec.
```

Benchmark from TiDB with GCP # 上班時段
```
Tue Aug 19 08:55:52 AM UTC 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        99.33                         52.72                 816.14                7.91                  2277.0000                120.0416                         2427.12 per sec.    960332.52           151.69 per sec.
oltp_read_write       123.28                        78.29                 1383.52               11.65                 1533.2500                120.0449                         2042.66 per sec.    960359.37           102.13 per sec.
oltp_write_only       41.10                         24.96                 1002.05               3.38                  4809.2500                120.0276                         1922.63 per sec.    960221.08           320.44 per sec.
select_random_points  14.21                         6.52                  1523.12               0.81                  18416.5000               119.9882                         1227.68 per sec.    959905.52           1227.68 per sec.
select_random_ranges  6.32                          1.84                  937.52                0.95                  65228.7500               119.9552                         4348.39 per sec.    959641.61           4348.39 per sec.
```

Benchmark from TiProxy with GCP # 上班時段
```
Tue Aug 19 08:55:52 AM UTC 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        1427.08                       342.54                4775.25               105.14                350.6250                 120.1034                         373.46 per sec.     960827.29           23.34 per sec.
oltp_read_write       3982.86                       1052.53               5687.05               160.90                115.6250                 121.6983                         150.58 per sec.     973586.63           7.53 per sec.
oltp_write_only       1869.60                       389.37                2610.38               51.42                 310.3750                 120.8506                         122.42 per sec.     966804.94           20.40 per sec.
select_random_points  369.77                        61.96                 1149.75               10.86                 1936.7500                120.0071                         129.10 per sec.     960056.82           129.10 per sec.
select_random_ranges  55.82                         33.45                 1516.40               11.21                 3587.5000                120.0066                         239.12 per sec.     960052.86           239.12 per sec.
```

Benchmark from TiDB with GCP # 離峰時段
```
Tue Aug 19 02:59:00 PM UTC 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        78.60                         43.32                 313.49                7.51                  2770.7500                120.0262                         2953.50 per sec.    960209.72           184.59 per sec.
oltp_read_write       97.55                         55.98                 126.46                11.40                 2144.3750                120.0355                         2857.34 per sec.    960283.71           142.87 per sec.
oltp_write_only       29.72                         19.91                 315.74                3.32                  6027.7500                120.0022                         2410.69 per sec.    960017.39           401.78 per sec.
select_random_points  4.41                          2.38                  31.54                 0.84                  50424.7500               119.9669                         3361.54 per sec.    959735.28           3361.54 per sec.
select_random_ranges  2.81                          1.81                  27.19                 0.90                  66306.0000               119.9535                         4420.27 per sec.    959628.38           4420.27 per sec.
```

Benchmark from TiProxy with GCP # 離峰時段
```
Tue Aug 19 02:59:01 PM UTC 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        183.21                        155.62                2689.49               97.25                 771.6250                 120.0795                         822.09 per sec.     960636.35           51.38 per sec.
oltp_read_write       219.36                        192.16                2265.10               133.76                624.8750                 120.0746                         832.04 per sec.     960596.86           41.60 per sec.
oltp_write_only       69.29                         61.98                 611.29                43.22                 1936.7500                120.0323                         774.33 per sec.     960258.54           129.06 per sec.
select_random_points  23.10                         20.22                 1069.88               10.80                 5936.2500                120.0017                         395.69 per sec.     960013.23           395.69 per sec.
select_random_ranges  21.89                         19.56                 1309.93               10.94                 6134.0000                120.0034                         408.86 per sec.     960026.96           408.86 per sec.
```

- IDC * 2 + GCP * 3 (兩機房同時執行 Sysbench 測試)

Benchmark from TiDB with IDC # 上班時段
```
Tue Aug 19 15:45:13 CST 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        104.84                        69.37                 1037.30               13.90                 1730.1250                120.0206                         1844.12 per sec.    960164.69           115.26 per sec.
oltp_read_write       158.63                        103.38                1107.74               34.10                 1161.1250                120.0418                         1546.90 per sec.    960334.17           77.34 per sec.
oltp_write_only       49.21                         43.49                 1105.74               16.32                 2759.3750                120.0056                         1103.46 per sec.    960045.18           183.91 per sec.
select_random_points  14.73                         12.73                 646.67                6.22                  9423.5000                119.9755                         628.18 per sec.     959804.25           628.18 per sec.
select_random_ranges  55.82                         19.46                 743.06                6.19                  6167.8750                120.0045                         411.07 per sec.     960035.96           411.07 per sec.
```

Benchmark from TiProxy with IDC # 上班時段
```
Tue Aug 19 15:45:13 CST 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        116.80                        75.53                 712.72                16.09                 1589.3750                120.0476                         1693.81 per sec.    960380.83           105.86 per sec.
oltp_read_write       262.64                        108.85                2060.87               27.33                 1102.8750                120.0445                         1469.22 per sec.    960356.17           73.46 per sec.
oltp_write_only       297.92                        75.86                 1737.11               18.47                 1582.0000                120.0121                         632.58 per sec.     960096.52           105.43 per sec.
select_random_points  28.16                         20.68                 462.37                11.03                 5801.1250                119.9893                         386.67 per sec.     959914.52           386.67 per sec.
select_random_ranges  34.95                         23.45                 1782.15               11.24                 5117.1250                119.9936                         341.09 per sec.     959949.09           341.09 per sec.
```

Benchmark from TiDB with GCP # 上班時段
```
Tue Aug 19 07:41:33 AM UTC 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        106.75                        54.30                 1009.82               7.69                  2210.3750                120.0176                         2356.33 per sec.    960140.84           147.27 per sec.
oltp_read_write       127.81                        73.40                 3173.06               11.91                 1635.5000                120.0468                         2179.07 per sec.    960374.64           108.95 per sec.
oltp_write_only       33.12                         24.59                 776.52                3.45                  4880.2500                120.0064                         1951.73 per sec.    960050.95           325.29 per sec.
select_random_points  17.63                         10.16                 1525.97               5.75                  11807.8750               119.9947                         787.10 per sec.     959957.22           787.10 per sec.
select_random_ranges  46.63                         12.34                 620.73                5.89                  9724.5000                119.9921                         648.27 per sec.     959936.70           648.27 per sec.
```

Benchmark from TiProxy with GCP # 上班時段
```
Tue Aug 19 07:41:33 AM UTC 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        267.41                        206.61                4280.93               100.37                587.3750                 121.3580                         608.75 per sec.     970863.96           38.05 per sec.
oltp_read_write       657.93                        280.62                3366.28               136.03                428.0000                 120.1070                         569.57 per sec.     960856.30           28.48 per sec.
oltp_write_only       257.95                        107.93                2807.81               46.22                 1112.1250                120.0333                         444.54 per sec.     960266.02           74.09 per sec.
select_random_points  33.72                         25.37                 329.66                15.74                 4730.1250                120.0061                         315.28 per sec.     960048.41           315.28 per sec.
select_random_ranges  92.42                         38.43                 1789.86               15.88                 3126.7500                120.1614                         207.83 per sec.     961291.22           207.83 per sec.
```

Benchmark from TiDB with IDC # 離峰時段
```
Tue Aug 19 23:23:49 CST 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        89.16                         59.00                 1944.46               13.28                 2034.6250                120.0400                         2168.68 per sec.    960320.37           135.54 per sec.
oltp_read_write       114.72                        78.52                 357.22                29.28                 1528.6250                120.0316                         2036.53 per sec.    960253.06           101.83 per sec.
oltp_write_only       45.79                         37.00                 1362.43               15.54                 3243.7500                120.0031                         1297.15 per sec.    960024.92           216.19 per sec.
select_random_points  22.28                         16.67                 474.16                5.81                  7196.3750                119.9900                         479.67 per sec.     959920.30           479.67 per sec.
select_random_ranges  16.41                         13.32                 27.29                 5.97                  9007.8750                119.9858                         600.43 per sec.     959886.65           600.43 per sec.
```

Benchmark from TiProxy with IDC # 離峰時段
```
Tue Aug 19 23:23:50 CST 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        95.81                         66.20                 359.64                15.94                 1813.3750                120.0412                         1932.81 per sec.    960329.25           120.80 per sec.
oltp_read_write       125.52                        94.71                 634.43                34.15                 1267.3750                120.0322                         1688.62 per sec.    960257.21           84.43 per sec.
oltp_write_only       50.11                         40.05                 612.84                17.48                 2996.7500                120.0057                         1198.31 per sec.    960045.45           199.72 per sec.
select_random_points  22.28                         15.63                 740.13                6.15                  7674.6250                119.9822                         511.58 per sec.     959857.32           511.58 per sec.
select_random_ranges  17.32                         13.12                 32.93                 6.22                  9142.2500                119.9841                         609.41 per sec.     959873.18           609.41 per sec.
```

Benchmark from TiDB with GCP # 離峰時段
```
Tue Aug 19 03:23:48 PM UTC 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        80.03                         43.40                 1296.19               7.58                  2765.7500                120.0202                         2948.50 per sec.    960161.94           184.28 per sec.
oltp_read_write       102.97                        66.46                 361.93                12.32                 1806.1250                120.0350                         2406.55 per sec.    960280.16           120.33 per sec.
oltp_write_only       29.72                         18.72                 1127.70               3.39                  6410.5000                119.9968                         2563.91 per sec.    959974.03           427.32 per sec.
select_random_points  6.91                          2.33                  956.38                0.83                  51542.2500               119.9663                         3435.86 per sec.    959730.39           3435.86 per sec.
select_random_ranges  6.67                          2.23                  236.27                0.94                  53865.8750               119.9647                         3590.83 per sec.    959717.33           3590.83 per sec.
```

Benchmark from TiProxy with GCP # 離峰時段
```
Tue Aug 19 03:23:48 PM UTC 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        179.94                        149.38                609.02                97.80                 804.0000                 120.1008                         856.46 per sec.     960806.25           53.53 per sec.
oltp_read_write       223.34                        191.47                961.15                136.40                627.1250                 120.0780                         835.13 per sec.     960623.78           41.76 per sec.
oltp_write_only       80.03                         69.62                 601.03                45.72                 1724.1250                120.0252                         689.31 per sec.     960201.59           114.89 per sec.
select_random_points  27.66                         21.86                 858.60                11.20                 5490.6250                120.0040                         365.99 per sec.     960031.84           365.99 per sec.
select_random_ranges  22.28                         18.49                 91.00                 11.15                 6488.5000                120.0007                         432.50 per sec.     960005.25           432.50 per sec.
```

- proxy.local-tidb-only enabled

Benchmark from TiDB with IDC # 離峰
```
Wed Aug 20 21:13:41 CST 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        75.82                         32.64                 300.12                7.77                  3676.5000                120.0052                         3919.76 per sec.    960041.67           244.98 per sec.
oltp_read_write       86.00                         40.38                 298.73                17.01                 2971.5000                119.9999                         3961.30 per sec.    959999.55           198.07 per sec.
oltp_write_only       25.28                         16.93                 523.08                3.61                  7087.1250                119.9859                         2834.46 per sec.    959887.36           472.41 per sec.
select_random_points  3.75                          2.20                  26.08                 0.70                  54512.5000               119.9232                         3634.02 per sec.    959385.80           3634.02 per sec.
select_random_ranges  6.32                          2.09                  59.41                 0.74                  57382.0000               119.9218                         3825.19 per sec.    959374.27           3825.19 per sec.
```

Benchmark from TiProxy with IDC # 離峰
```
Wed Aug 20 21:13:41 CST 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        81.48                         38.83                 174.99                9.60                  3091.2500                120.0204                         3295.50 per sec.    960163.15           205.97 per sec.
oltp_read_write       97.55                         50.12                 1855.20               13.83                 2394.8750                120.0197                         3190.88 per sec.    960157.75           159.54 per sec.
oltp_write_only       27.66                         18.00                 403.05                4.20                  6667.8750                119.9927                         2666.71 per sec.    959941.84           444.45 per sec.
select_random_points  7.43                          3.39                  1730.74               0.85                  35351.1250               119.9470                         2356.53 per sec.    959576.25           2356.53 per sec.
select_random_ranges  7.30                          2.58                  214.66                0.85                  46506.0000               119.9404                         3100.18 per sec.    959523.07           3100.18 per sec.
```

Benchmark from TiDB with GCP # 離峰
```
Wed Aug 20 01:36:28 PM UTC 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per secon
d
oltp_read_only        94.10                         70.24                 172.12                12.66                 1709.2500                120.0607                         1821.76 per sec.    960485.67           113.86 per sec.
oltp_read_write       132.49                        105.42                352.00                22.87                 1139.0000                120.0733                         1517.03 per sec.    960586.53           75.85 per sec.
oltp_write_only       48.34                         38.44                 1009.48               13.43                 3122.5000                120.0186                         1248.58 per sec.    960148.75           208.10 per sec.
select_random_points  24.83                         17.97                 1736.13               5.86                  6678.2500                120.0043                         445.15 per sec.     960034.21           445.15 per sec.
select_random_ranges  16.71                         15.80                 1714.74               6.05                  7593.0000                119.9968                         506.14 per sec.     959974.25           506.14 per sec.
```

Benchmark from TiProxy with GCP # 離峰
```
Wed Aug 20 01:36:28 PM UTC 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per secon
d
oltp_read_only        167.44                        129.50                380.83                93.13                 927.2500                 120.0812                         988.13 per sec.     960649.33           61.76 per sec.
oltp_read_write       200.47                        158.02                730.20                122.19                759.8750                 120.0749                         1011.71 per sec.    960599.26           50.59 per sec.
oltp_write_only       55.82                         48.25                 439.22                39.06                 2487.6250                120.0245                         994.63 per sec.     960195.80           165.77 per sec.
select_random_points  12.30                         9.12                  1498.51               5.70                  13163.1250               119.9914                         877.45 per sec.     959931.08           877.45 per sec.
select_random_ranges  11.87                         7.93                  25.42                 5.84                  15126.5000               119.9899                         1008.32 per sec.    959918.97           1008.32 per sec.
```

Benchmark from TiDB with IDC both Execute # 離峰
```
Wed Aug 20 22:27:19 CST 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        77.19                         37.03                 305.67                7.79                  3241.5000                120.0199                         3455.64 per sec.    960159.38           215.98 per sec.
oltp_read_write       89.16                         49.21                 1825.70               16.94                 2439.0000                120.0251                         3250.18 per sec.    960201.19           162.51 per sec.
oltp_write_only       26.68                         18.17                 348.81                4.00                  6602.5000                119.9836                         2640.71 per sec.    959868.92           440.12 per sec.
select_random_points  3.55                          2.10                  72.49                 0.74                  56986.5000               119.9284                         3798.94 per sec.    959427.29           3798.94 per sec.
select_random_ranges  6.55                          2.08                  220.76                0.74                  57637.2500               119.9302                         3842.21 per sec.    959441.95           3842.21 per sec.
```

Benchmark from TiProxy with IDC both Execute # 離峰
```
Wed Aug 20 22:27:19 CST 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        81.48                         47.72                 1595.61               9.84                  2515.0000                120.0086                         2681.22 per sec.    960069.02           167.58 per sec.
oltp_read_write       106.75                        67.44                 1710.98               16.09                 1780.2500                120.0527                         2371.77 per sec.    960421.88           118.59 per sec.
oltp_write_only       30.26                         19.90                 653.24                4.23                  6028.8750                119.9935                         2411.09 per sec.    959948.24           401.85 per sec.
select_random_points  8.43                          3.35                  718.70                0.78                  35762.6250               119.9482                         2384.03 per sec.    959585.66           2384.03 per sec.
select_random_ranges  7.30                          3.95                  640.65                0.91                  30369.3750               119.9557                         2024.49 per sec.    959645.81           2024.49 per sec.
```

Benchmark from TiDB with GCP both Execute # 離峰
```
Wed Aug 20 02:27:18 PM UTC 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        90.78                         63.31                 340.18                12.45                 1896.0000                120.0411                         2021.01 per sec.    960329.00           126.31 per sec.
oltp_read_write       125.52                        98.29                 366.91                27.70                 1221.2500                120.0402                         1627.20 per sec.    960321.45           81.36 per sec.
oltp_write_only       47.47                         38.24                 650.83                13.91                 3138.7500                120.0162                         1255.14 per sec.    960129.99           209.19 per sec.
select_random_points  23.10                         17.64                 286.74                10.49                 6801.1250                119.9989                         453.35 per sec.     959990.86           453.35 per sec.
select_random_ranges  16.71                         13.96                 243.49                5.87                  8598.6250                119.9995                         573.17 per sec.     959996.01           573.17 per sec.
```

Benchmark from TiProxy with GCP both Execute # 離峰
```
Wed Aug 20 02:27:18 PM UTC 2025
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        183.21                        145.31                2448.17               90.18                 826.2500                 120.0609                         880.58 per sec.     960487.32           55.04 per sec.
oltp_read_write       227.40                        186.74                1874.16               115.94                643.1250                 120.0959                         856.35 per sec.     960767.00           42.82 per sec.
oltp_write_only       58.92                         50.12                 932.64                33.31                 2394.7500                120.0189                         957.55 per sec.     960150.93           159.59 per sec.
select_random_points  15.55                         9.53                  1705.63               5.53                  12594.5000               119.9952                         839.55 per sec.     959961.28           839.55 per sec.
select_random_ranges  12.08                         9.36                  669.08                5.65                  12820.5000               119.9945                         854.62 per sec.     959955.73           854.62 per sec.
```

- Galera Cluster 可以與哪些數據能參與比較？

- Mix GCP / IDC Galera Cluster
[Traffic is distributed across multi nodes with Multi ProxySQL: (172.24.40.14, 172.24.40.15, 10.160.152.14, 10.160.152.15)](https://codimd.104.com.tw/s/Idn1I_KD2#Traffic-is-distributed-across-multi-nodes-with-Multi-ProxySQL-172244014-172244015-1016015214-1016015215)
```
OLTP Type             95th percentile latency (ms)  Average latency (ms)  Maximum latency (ms)  Minimum latency (ms)  Events per thread (avg)  Execution time per thread (avg)  Queries per second  Total latency (ms)  Transactions per second
oltp_read_only        110.66                        94.99                 552.32                81.29                 3158.5000                300.0377                         1347.26 per sec.    2400301.38          84.20 per sec.
oltp_read_write       73.13                         31.88                 767.82                12.73                 9408.8750                299.9912                         5027.75 per sec.    2399929.58          250.86 per sec.
oltp_write_only       32.53                         16.87                 765.96                8.15                  17781.0000               299.9684                         2844.80 per sec.    2399747.59          474.13 per sec.
select_random_points  7.56                          6.04                  224.60                4.98                  49676.7500               299.9236                         1324.68 per sec.    2399388.59          1324.68 per sec.
select_random_ranges  6.67                          5.87                  239.84                4.95                  51052.0000               299.9100                         1361.37 per sec.    2399280.11          1361.37 per sec.
```