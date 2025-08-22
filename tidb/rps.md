- IDC * 1

RPS From TiDB
```
Test Type                 Total Tests     Avg Response (ms)    Error Rate %    Total Time (s)  Req/sec         Threads
------------------------------------------------------------------------------------------------------------------------
multi_thread_multi_conn   10000           1.283                0.00            12.844          778.56          1
multi_thread_multi_conn   10000           19.550               0.00            2.084           4797.60         100
multi_thread_multi_conn   10000           36.055               0.00            2.024           4939.65         200
multi_thread_multi_conn   10000           44.815               0.00            2.095           4772.84         250
multi_thread_multi_conn   10000           93.319               0.00            2.449           4083.94         500
multi_thread_multi_conn   10000           119.752              0.00            3.245           3081.47         750
multi_thread_multi_conn   10000           151.809              0.00            3.116           3208.78         1000
```

RPS From TiDB passthrough A10 NAT
```
multi_thread_multi_conn   10000           1.365                0.00            13.661          731.98          1
multi_thread_multi_conn   10000           27.986               0.00            3.011           3320.80         100
multi_thread_multi_conn   10000           61.253               13.03           4.217           2371.37         200
multi_thread_multi_conn   10000           72.621               10.22           3.663           2729.77         250
multi_thread_multi_conn   10000           147.603              3.97            6.905           1448.33         500
multi_thread_multi_conn   10000           47.002               23.36           6.823           1465.61         750
multi_thread_multi_conn   10000           172.086              5.73            5.968           1675.65         1000
```

RPS From TiProxy
```
multi_thread_multi_conn   10000           1.912                0.00            19.132          522.68          1
multi_thread_multi_conn   10000           28.626               0.00            3.013           3318.58         100
multi_thread_multi_conn   10000           55.745               0.00            2.982           3353.27         200
multi_thread_multi_conn   10000           70.404               0.00            3.136           3189.01         250
multi_thread_multi_conn   10000           135.323              0.00            3.204           3120.87         500
multi_thread_multi_conn   10000           201.128              0.00            3.486           2869.02         750
multi_thread_multi_conn   10000           226.734              0.00            3.314           3017.78         1000
```

RPS From TiProxy passthrough A10 NAT
```
multi_thread_multi_conn   10000           2.047                0.00            20.483          488.20          1
multi_thread_multi_conn   10000           36.111               0.00            3.870           2583.71         100
multi_thread_multi_conn   10000           64.722               0.00            3.607           2772.31         200
multi_thread_multi_conn   10000           93.353               7.61            4.071           2456.69         250
multi_thread_multi_conn   10000           161.022              0.00            3.774           2649.55         500
multi_thread_multi_conn   10000           262.926              6.58            7.292           1371.37         750
multi_thread_multi_conn   10000           299.571              0.00            6.788           1473.18         1000
```

==================================
==================================
==================================
==================================

- GCP * 1

RPS From TiDB ; Connect From IDC
```
Test Type                 Total Tests     Avg Response (ms)    Error Rate %    Total Time (s)  Req/sec         Threads
------------------------------------------------------------------------------------------------------------------------
multi_thread_multi_conn   10000           29.863               0.00            298.654         33.48           1
multi_thread_multi_conn   10000           38.139               0.00            3.927           2546.21         100
multi_thread_multi_conn   10000           72.666               0.00            3.874           2581.29         200
multi_thread_multi_conn   10000           72.064               0.00            3.148           3176.38         250
multi_thread_multi_conn   10000           137.343              0.00            3.671           2724.03         500
multi_thread_multi_conn   10000           223.993              0.00            3.615           2766.02         750
multi_thread_multi_conn   10000           266.745              0.00            3.711           2694.99         1000
```

RPS From TiProxy ; Connect From IDC
```
multi_thread_multi_conn   10000           34.511               0.00            345.144         28.97           1
multi_thread_multi_conn   10000           46.863               0.00            4.811           2078.38         100
multi_thread_multi_conn   10000           82.780               0.00            4.363           2291.83         200
multi_thread_multi_conn   10000           108.604              0.00            4.636           2157.11         250
multi_thread_multi_conn   10000           205.574              0.00            4.658           2146.93         500
multi_thread_multi_conn   10000           314.731              0.00            5.088           1965.44         750
multi_thread_multi_conn   10000           393.240              0.00            4.976           2009.63         1000
```

RPS From TiDB ; Connect From GCP
```
multi_thread_multi_conn   10000           1.396                0.00            13.965          716.08          1
multi_thread_multi_conn   10000           38.508               0.00            4.128           2422.24         100
multi_thread_multi_conn   10000           77.414               5.01            5.072           1971.58         200
multi_thread_multi_conn   10000           93.799               18.11           4.412           2266.35         250
multi_thread_multi_conn   10000           206.096              3.93            5.344           1871.40         500
multi_thread_multi_conn   10000           56.879               15.49           7.041           1420.28         750
multi_thread_multi_conn   10000           357.425              25.62           6.156           1624.45         1000
```

RPS From TiProxy ; Connect From GCP
```
multi_thread_multi_conn   10000           1.994                0.00            19.945          501.38          1
multi_thread_multi_conn   10000           68.464               0.00            7.126           1403.35         100
multi_thread_multi_conn   10000           107.233              0.00            5.745           1740.74         200
multi_thread_multi_conn   10000           162.060              0.00            7.031           1422.28         250
multi_thread_multi_conn   10000           279.924              0.00            6.390           1564.99         500
multi_thread_multi_conn   10000           474.001              0.00            7.727           1294.17         750
multi_thread_multi_conn   10000           527.272              0.00            7.118           1404.79         1000
```

==================================
==================================
==================================
==================================

- IDC * 3

RPS From TiDB passthrough A10 NAT
```
Test Type                 Total Tests     Avg Response (ms)    Error Rate %    Total Time (s)  Req/sec         Threads
------------------------------------------------------------------------------------------------------------------------
multi_thread_multi_conn   10000           1.664                0.00            16.657          600.34          1
multi_thread_multi_conn   10000           22.738               0.00            2.694           3712.11         100
multi_thread_multi_conn   10000           40.300               0.00            4.795           2085.69         200
multi_thread_multi_conn   10000           32.968               23.21           3.834           2608.15         250
multi_thread_multi_conn   10000           21.953               4.00            3.952           2530.23         500
multi_thread_multi_conn   10000           26.442               10.52           4.712           2122.34         750
multi_thread_multi_conn   10000           28.267               30.72           5.452           1834.19         1000
```

RPS From TiProxy passthrough A10 NAT
```
multi_thread_multi_conn   10000           2.589                0.00            25.901          386.08          1
multi_thread_multi_conn   10000           26.422               0.00            2.904           3443.11         100
multi_thread_multi_conn   10000           28.692               0.00            3.802           2630.35         200
multi_thread_multi_conn   10000           41.932               0.00            2.700           3704.11         250
multi_thread_multi_conn   10000           30.800               0.00            1.928           5187.93         500
multi_thread_multi_conn   10000           38.636               0.00            3.579           2794.06         750
multi_thread_multi_conn   10000           29.584               0.00            2.637           3791.55         1000
```

==================================
==================================
==================================
==================================
- GCP * 3

RPS From TiDB passthrough GCP Load Balance (#10.160.152.25:4000)
```
Test Type                 Total Tests     Avg Response (ms)    Error Rate %    Total Time (s)  Req/sec         Threads
------------------------------------------------------------------------------------------------------------------------
multi_thread_multi_conn   10000           1.053                0.00            10.538          948.95          1
multi_thread_multi_conn   10000           29.547               0.00            3.312           3019.17         100
multi_thread_multi_conn   10000           48.152               20.63           5.839           1712.52         200
multi_thread_multi_conn   10000           20.738               2.49            1.478           6766.10         250
multi_thread_multi_conn   10000           18.596               4.01            4.387           2279.26         500
multi_thread_multi_conn   10000           34.512               23.66           7.396           1352.09         750
multi_thread_multi_conn   10000           9.478                9.92            3.548           2818.24         1000
```

RPS From TiProxy passthrough GCP Load Balance (#10.160.152.26:6000)
```
multi_thread_multi_conn   10000           1.615                0.00            16.154          619.05          1
multi_thread_multi_conn   10000           32.605               0.00            3.625           2758.27         100
multi_thread_multi_conn   10000           35.245               0.00            4.272           2340.78         200
multi_thread_multi_conn   10000           74.652               23.18           3.851           2596.57         250
multi_thread_multi_conn   10000           164.195              3.89            4.783           2090.81         500
multi_thread_multi_conn   10000           51.960               10.42           6.473           1544.79         750
multi_thread_multi_conn   10000           24.919               30.66           5.737           1743.19         1000
```

==================================
==================================
==================================
==================================

- IDC * 1 + GCP * 2

RPS From TiDB with IDC
```
Test Type                 Total Tests     Avg Response (ms)    Error Rate %    Total Time (s)  Req/sec         Threads
------------------------------------------------------------------------------------------------------------------------
multi_thread_multi_conn   10000           1.455                0.00            14.566          686.54          1
multi_thread_multi_conn   10000           28.748               0.00            3.166           3158.77         100
multi_thread_multi_conn   10000           61.280               11.32           4.216           2372.00         200
multi_thread_multi_conn   10000           63.370               11.83           5.045           1982.13         250
multi_thread_multi_conn   10000           149.822              3.79            7.018           1424.94         500
multi_thread_multi_conn   10000           36.522               21.81           5.512           1814.39         750
multi_thread_multi_conn   10000           191.716              13.83           6.049           1653.15         1000
```

RPS From TiProxy with IDC
```
multi_thread_multi_conn   10000           2.187                0.00            21.881          457.01          1
multi_thread_multi_conn   10000           24.834               0.00            3.039           3290.50         100
multi_thread_multi_conn   10000           38.835               0.00            2.228           4488.76         200
multi_thread_multi_conn   10000           45.694               0.00            2.102           4757.46         250
multi_thread_multi_conn   10000           81.255               0.00            2.234           4477.06         500
multi_thread_multi_conn   10000           110.156              0.00            2.257           4430.60         750
multi_thread_multi_conn   10000           78.857               0.00            2.691           3715.82         1000
```

RPS From TiDB with GCP
```
multi_thread_multi_conn   10000           1.098                0.00            10.986          910.29          1
multi_thread_multi_conn   10000           30.643               0.00            3.357           2978.68         100
multi_thread_multi_conn   10000           50.270               20.72           5.781           1729.94         200
multi_thread_multi_conn   10000           37.753               2.46            2.135           4683.38         250
multi_thread_multi_conn   10000           151.511              3.94            4.483           2230.73         500
multi_thread_multi_conn   10000           34.602               31.18           7.755           1289.50         750
multi_thread_multi_conn   10000           19.577               9.97            3.702           2701.37         1000
```

RPS From TiProxy with GCP
```
multi_thread_multi_conn   10000           38.154               0.00            381.550         26.21           1
multi_thread_multi_conn   10000           20.255               0.00            2.236           4473.26         100
multi_thread_multi_conn   10000           35.209               0.00            2.198           4549.24         200
multi_thread_multi_conn   10000           43.833               0.00            2.247           4450.11         250
multi_thread_multi_conn   10000           71.906               0.00            2.398           4169.54         500
multi_thread_multi_conn   10000           96.755               0.00            2.667           3749.86         750
multi_thread_multi_conn   10000           50.684               0.00            3.006           3326.43         1000
```

==================================
==================================
==================================
==================================

- IDC * 2 + GCP * 1

RPS From TiDB with IDC
```
Test Type                 Total Tests     Avg Response (ms)    Error Rate %    Total Time (s)  Req/sec         Threads
------------------------------------------------------------------------------------------------------------------------
multi_thread_multi_conn   10000           1.558                0.00            15.590          641.42          1
multi_thread_multi_conn   10000           24.899               0.00            2.854           3503.67         100
multi_thread_multi_conn   10000           39.203               0.00            4.533           2206.28         200
multi_thread_multi_conn   10000           61.753               23.22           6.426           1556.18         250
multi_thread_multi_conn   10000           37.747               4.00            3.525           2836.72         500
multi_thread_multi_conn   10000           30.245               10.51           5.034           1986.34         750
multi_thread_multi_conn   10000           28.601               30.73           4.914           2035.11         1000
```

RPS From TiProxy with IDC
```
multi_thread_multi_conn   10000           2.335                0.00            23.365          427.99          1
multi_thread_multi_conn   10000           17.391               0.00            2.156           4638.07         100
multi_thread_multi_conn   10000           49.741               0.00            2.902           3445.76         200
multi_thread_multi_conn   10000           34.701               0.00            1.743           5737.60         250
multi_thread_multi_conn   10000           62.091               0.00            1.961           5099.12         500
multi_thread_multi_conn   10000           55.255               0.00            2.143           4665.75         750
multi_thread_multi_conn   10000           37.937               0.00            2.337           4278.90         1000
```

RPS From TiDB with GCP
```
multi_thread_multi_conn   10000           0.998                0.00            9.986           1001.43         1
multi_thread_multi_conn   10000           35.867               0.00            3.881           2576.90         100
multi_thread_multi_conn   10000           52.555               20.62           5.769           1733.41         200
multi_thread_multi_conn   10000           69.397               2.50            3.277           3051.45         250
multi_thread_multi_conn   10000           70.521               62.13           6.935           1441.89         500
multi_thread_multi_conn   10000           23.433               0.00            6.165           1622.11         750
multi_thread_multi_conn   10000           170.395              0.00            4.181           2391.69         1000
```

RPS From TiProxy with GCP
```
multi_thread_multi_conn   10000           33.495               0.00            334.957         29.85           1
multi_thread_multi_conn   10000           189.346              0.00            21.167          472.43          100
multi_thread_multi_conn   10000           45.681               0.00            2.661           3757.28         200
multi_thread_multi_conn   10000           56.192               0.00            2.761           3622.17         250
multi_thread_multi_conn   10000           104.712              0.00            2.883           3468.11         500
multi_thread_multi_conn   10000           89.237               0.00            2.862           3493.87         750
multi_thread_multi_conn   10000           177.149              0.00            3.587           2787.94         1000
```

==================================
==================================
==================================
==================================

- IDC * 3 + GCP * 2

RPS From TiDB with IDC
```
Test Type                 Total Tests     Avg Response (ms)    Error Rate %    Total Time (s)  Req/sec         Threads
------------------------------------------------------------------------------------------------------------------------
multi_thread_multi_conn   10000           1.605                0.00            16.064          622.51          1
multi_thread_multi_conn   10000           22.498               0.00            2.578           3878.91         100
multi_thread_multi_conn   10000           41.033               1.06            3.366           2970.50         200
multi_thread_multi_conn   10000           31.783               22.19           2.649           3775.71         250
multi_thread_multi_conn   10000           19.744               3.99            3.311           3020.64         500
multi_thread_multi_conn   10000           29.293               11.55           6.841           1461.68         750
multi_thread_multi_conn   10000           21.929               29.67           4.177           2393.85         1000
```

RPS From TiProxy with IDC
```
multi_thread_multi_conn   10000           2.609                0.00            26.107          383.04          1
multi_thread_multi_conn   10000           25.519               0.00            2.800           3571.46         100
multi_thread_multi_conn   10000           22.830               0.00            3.774           2649.38         200
multi_thread_multi_conn   10000           59.658               0.00            3.093           3232.77         250
multi_thread_multi_conn   10000           42.184               0.00            1.640           6096.11         500
multi_thread_multi_conn   10000           36.360               0.00            1.997           5008.76         750
multi_thread_multi_conn   10000           32.234               0.00            3.393           2947.51         1000
```

RPS From TiDB with GCP
```
multi_thread_multi_conn   10000           0.980                0.00            9.811           1019.27         1
multi_thread_multi_conn   10000           31.677               0.00            3.428           2917.25         100
multi_thread_multi_conn   10000           48.202               20.75           5.845           1710.83         200
multi_thread_multi_conn   10000           34.806               5.56            2.090           4785.39         250
multi_thread_multi_conn   10000           61.696               35.27           5.407           1849.41         500
multi_thread_multi_conn   10000           23.176               0.00            6.432           1554.61         750
multi_thread_multi_conn   10000           21.738               36.53           5.432           1841.02         1000
```

RPS From TiProxy with GCP
```
multi_thread_multi_conn   10000           36.797               0.00            367.982         27.18           1
multi_thread_multi_conn   10000           35.268               0.00            3.662           2730.93         100
multi_thread_multi_conn   10000           34.041               0.00            2.092           4779.98         200
multi_thread_multi_conn   10000           36.206               0.00            1.988           5030.60         250
multi_thread_multi_conn   10000           57.468               0.00            2.448           4084.91         500
multi_thread_multi_conn   10000           41.620               0.00            2.650           3774.03         750
multi_thread_multi_conn   10000           54.022               0.00            3.161           3163.58         1000
```

==================================
==================================
==================================
==================================

- IDC * 2 + GCP * 3

RPS From TiDB with IDC
```
Test Type                 Total Tests     Avg Response (ms)    Error Rate %    Total Time (s)  Req/sec         Threads
------------------------------------------------------------------------------------------------------------------------
multi_thread_multi_conn   10000           1.480                0.00            14.814          675.02          1
multi_thread_multi_conn   10000           23.210               0.00            2.567           3896.01         100
multi_thread_multi_conn   10000           46.773               8.86            3.883           2575.13         200
multi_thread_multi_conn   10000           36.196               14.28           4.505           2219.82         250
multi_thread_multi_conn   10000           35.938               4.00            3.380           2958.15         500
multi_thread_multi_conn   10000           33.194               19.34           5.512           1814.32         750
multi_thread_multi_conn   10000           21.095               21.88           3.651           2739.32         1000
```

RPS From TiProxy with IDC
```
multi_thread_multi_conn   10000           2.427                0.00            24.281          411.85          1
multi_thread_multi_conn   10000           19.294               0.00            2.363           4232.26         100
multi_thread_multi_conn   10000           27.465               0.00            1.727           5788.76         200
multi_thread_multi_conn   10000           32.883               0.00            1.673           5978.74         250
multi_thread_multi_conn   10000           60.793               0.00            1.778           5622.82         500
multi_thread_multi_conn   10000           59.500               0.00            1.995           5013.66         750
multi_thread_multi_conn   10000           47.387               0.00            2.152           4646.92         1000
```

RPS From TiDB with GCP
```
multi_thread_multi_conn   10000           1.054                0.00            10.546          948.18          1
multi_thread_multi_conn   10000           29.537               0.00            3.290           3039.49         100
multi_thread_multi_conn   10000           49.530               20.71           5.866           1704.71         200
multi_thread_multi_conn   10000           24.351               2.48            1.608           6219.94         250
multi_thread_multi_conn   10000           53.446               62.78           6.487           1541.65         500
multi_thread_multi_conn   10000           22.688               0.00            6.421           1557.38         750
multi_thread_multi_conn   10000           6.172                0.00            2.629           3803.42         1000
```

RPS From TiProxy with GCP
```
multi_thread_multi_conn   10000           31.418               0.00            314.189         31.83           1
multi_thread_multi_conn   10000           31.325               0.00            3.319           3013.08         100
multi_thread_multi_conn   10000           35.173               0.00            2.136           4682.24         200
multi_thread_multi_conn   10000           27.626               0.00            1.756           5694.75         250
multi_thread_multi_conn   10000           41.350               0.00            2.056           4862.79         500
multi_thread_multi_conn   10000           52.640               0.00            2.660           3759.30         750
multi_thread_multi_conn   10000           46.738               0.00            3.144           3180.53         1000
```

==================================
==================================
==================================
==================================

- IDC * 2 + GCP * 3 (RPS Benchmark co-work)

RPS From TiDB with IDC
```
Test Type                 Total Tests     Avg Response (ms)    Error Rate %    Total Time (s)  Req/sec         Threads
------------------------------------------------------------------------------------------------------------------------
multi_thread_multi_conn   10000           1.485                0.00            14.863          672.81          1
multi_thread_multi_conn   10000           24.372               0.00            2.753           3632.48         100
multi_thread_multi_conn   10000           54.522               8.53            3.941           2537.45         200
multi_thread_multi_conn   10000           40.081               14.70           2.696           3709.59         250
multi_thread_multi_conn   10000           29.858               4.02            3.599           2778.59         500
multi_thread_multi_conn   10000           35.053               19.02           5.606           1783.72         750
multi_thread_multi_conn   10000           23.595               22.20           3.996           2502.78         1000
```

RPS From TiProxy with IDC
```
multi_thread_multi_conn   10000           2.352                0.00            23.533          424.94          1
multi_thread_multi_conn   10000           27.769               0.00            3.123           3201.66         100
multi_thread_multi_conn   10000           25.908               0.00            1.641           6093.34         200
multi_thread_multi_conn   10000           32.465               0.00            1.631           6132.87         250
multi_thread_multi_conn   10000           50.214               0.00            1.779           5620.78         500
multi_thread_multi_conn   10000           68.755               0.00            2.600           3846.16         750
multi_thread_multi_conn   10000           47.830               0.00            2.370           4218.96         1000
```

RPS From TiDB with GCP
```
multi_thread_multi_conn   10000           1.048                0.00            10.484          953.85          1
multi_thread_multi_conn   10000           29.059               0.00            3.286           3043.38         100
multi_thread_multi_conn   10000           48.382               20.67           5.855           1707.85         200
multi_thread_multi_conn   10000           22.354               2.48            1.504           6646.97         250
multi_thread_multi_conn   10000           65.526               3.92            4.386           2280.04         500
multi_thread_multi_conn   10000           31.777               23.68           7.209           1387.20         750
multi_thread_multi_conn   10000           31.907               66.06           7.651           1307.07         1000
```

RPS From TiProxy with GCP
```
multi_thread_multi_conn   10000           32.810               0.00            328.113         30.48           1
multi_thread_multi_conn   10000           32.760               0.00            3.439           2907.92         100
multi_thread_multi_conn   10000           35.048               0.00            2.847           3513.05         200
multi_thread_multi_conn   10000           36.499               0.00            1.967           5083.99         250
multi_thread_multi_conn   10000           40.711               0.00            2.055           4866.94         500
multi_thread_multi_conn   10000           28.842               0.00            2.578           3879.08         750
multi_thread_multi_conn   10000           19.633               0.00            2.950           3390.00         1000
```

==================================
==================================
==================================
==================================

- Galera Cluster 可以與哪個參數比較？
