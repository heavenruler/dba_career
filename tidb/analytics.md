## 數據解讀有哪些關鍵指標需要關注

- 有沒有經過 NAT Load Balance 差異
- 直接存取 TiDB / TiProxy 差異
- 分散式資料庫 RPS 指標
- 分散式資料庫 Sysbench 指標
- 分散式資料庫 TPC-C 指標
- Latency 與 Performance 的影響
- 跨專線的延遲對 Performance 的影響及應對
- Scale 辦法對 Performance 的影響
  - Scale UP
  - Scale Out
- 不同 TiDB Cluster Component Scale Strategy 對效能的影響
- 分散式資料庫與 Galera 相關指標比較

----
直連與經過 Loas Balance 差異				
TiDB 直連				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	1.283	0	778.56
	100	19.55	0	4797.6
	200	36.055	0	4939.65
	250	44.815	0	4772.84
	500	93.319	0	4083.94
	750	119.752	0	3081.47
	1000	151.809	0	3208.78
TiDB 直連與經過 Load Balance 的差異				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	1.365	0	731.98
	100	27.986	0	3320.8
	200	61.253	13.03	2371.37
	250	72.621	10.22	2729.77
	500	147.603	3.97	1448.33
	750	47.002	23.36	1465.61
	1000	172.086	5.73	1675.65
TiProxy 直連				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	1.912	0	522.68
	100	28.626	0	3318.58
	200	55.745	0	3353.27
	250	70.404	0	3189.01
	500	135.323	0	3120.87
	750	201.128	0	2869.02
	1000	226.734	0	3017.78
TiProxy 直連與經過 Load Balance 的差異				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	2.047	0	488.2
	100	36.111	0	2583.71
	200	64.722	0	2772.31
	250	93.353	7.61	2456.69
	500	161.022	0	2649.55
	750	262.926	6.58	1371.37
	1000	299.571	0	1473.18
				
從 IDC 連 GCP 及 從 GCP 連 GCP 的差異				
IDC 問 GCP TiDB				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	29.863	0	33.48
	100	38.139	0	2546.21
	200	72.666	0	2581.29
	250	72.064	0	3176.38
	500	137.343	0	2724.03
	750	223.993	0	2766.02
	1000	266.745	0	2694.99
IDC 問 GCP TiProxy				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	34.511	0	28.97
	100	46.863	0	2078.38
	200	82.78	0	2291.83
	250	108.604	0	2157.11
	500	205.574	0	2146.93
	750	314.731	0	1965.44
	1000	393.24	0	2009.63
GCP 問 GCP TiDB				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	1.396	0	716.08
	100	38.508	0	2422.24
	200	77.414	5.01	1971.58
	250	93.799	18.11	2266.35
	500	206.096	3.93	1871.4
	750	56.879	15.49	1420.28
	1000	357.425	25.62	1624.45
GCP 問 GCP TiProxy				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	1.994	0	501.38
	100	68.464	0	1403.35
	200	107.233	0	1740.74
	250	162.06	0	1422.28
	500	279.924	0	1564.99
	750	474.001	0	1294.17
	1000	527.272	0	1404.79
				
IDC * 3				
TiDB with Load Balance				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	1.664	0	600.34
	100	22.738	0	3712.11
	200	40.3	0	2085.69
	250	32.968	23.21	2608.15
	500	21.953	4	2530.23
	750	26.442	10.52	2122.34
	1000	28.267	30.72	1834.19
TiProxy with Load Balance				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	2.589	0	386.08
	100	26.422	0	3443.11
	200	28.692	0	2630.35
	250	41.932	0	3704.11
	500	30.8	0	5187.93
	750	38.636	0	2794.06
	1000	29.584	0	3791.55
				
GCP * 3				
TiDB with Load Balance				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	1.053	0	948.95
	100	29.547	0	3019.17
	200	48.152	20.63	1712.52
	250	20.738	2.49	6766.1
	500	18.596	4.01	2279.26
	750	34.512	23.66	1352.09
	1000	9.478	9.92	2818.24
TiProxy with Load Balance				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	1.615	0	619.05
	100	32.605	0	2758.27
	200	35.245	0	2340.78
	250	74.652	23.18	2596.57
	500	164.195	3.89	2090.81
	750	51.96	10.42	1544.79
	1000	24.919	30.66	1743.19
				
跨專線混合部署 IDC * 1 + GCP * 2				
RPS From TiDB with IDC				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	1.455	0	686.54
	100	28.748	0	3158.77
	200	61.28	11.32	2372
	250	63.37	11.83	1982.13
	500	149.822	3.79	1424.94
	750	36.522	21.81	1814.39
	1000	191.716	13.83	1653.15
RPS From TiProxy with IDC				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	2.187	0	457.01
	100	24.834	0	3290.5
	200	38.835	0	4488.76
	250	45.694	0	4757.46
	500	81.255	0	4477.06
	750	110.156	0	4430.6
	1000	78.857	0	3715.82
RPS From TiDB with GCP				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	1.098	0	910.29
	100	30.643	0	2978.68
	200	50.27	20.72	1729.94
	250	37.753	2.46	4683.38
	500	151.511	3.94	2230.73
	750	34.602	31.18	1289.5
	1000	19.577	9.97	2701.37
RPS From TiProxy with GCP				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	38.154	0	26.21
	100	20.255	0	4473.26
	200	35.209	0	4549.24
	250	43.833	0	4450.11
	500	71.906	0	4169.54
	750	96.755	0	3749.86
	1000	50.684	0	3326.43
				
跨專線混合部署 IDC * 2 + GCP * 1				
RPS From TiDB with IDC				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	1.558	0	641.42
	100	24.899	0	3503.67
	200	39.203	0	2206.28
	250	61.753	23.22	1556.18
	500	37.747	4	2836.72
	750	30.245	10.51	1986.34
	1000	28.601	30.73	2035.11
RPS From TiProxy with IDC				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	2.335	0	427.99
	100	17.391	0	4638.07
	200	49.741	0	3445.76
	250	34.701	0	5737.6
	500	62.091	0	5099.12
	750	55.255	0	4665.75
	1000	37.937	0	4278.9
RPS From TiDB with GCP				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	0.998	0	1001.43
	100	35.867	0	2576.9
	200	52.555	20.62	1733.41
	250	69.397	2.5	3051.45
	500	70.521	62.13	1441.89
	750	23.433	0	1622.11
	1000	170.395	0	2391.69
RPS From TiProxy with GCP				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	33.495	0	29.85
	100	189.346	0	472.43
	200	45.681	0	3757.28
	250	56.192	0	3622.17
	500	104.712	0	3468.11
	750	89.237	0	3493.87
	1000	177.149	0	2787.94
				
跨專線混合部署 IDC * 3 + GCP * 2				
RPS From TiDB with IDC				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	1.605	0	622.51
	100	22.498	0	3878.91
	200	41.033	1.06	2970.5
	250	31.783	22.19	3775.71
	500	19.744	3.99	3020.64
	750	29.293	11.55	1461.68
	1000	21.929	29.67	2393.85
RPS From TiProxy with IDC				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	2.609	0	383.04
	100	25.519	0	3571.46
	200	22.83	0	2649.38
	250	59.658	0	3232.77
	500	42.184	0	6096.11
	750	36.36	0	5008.76
	1000	32.234	0	2947.51
RPS From TiDB with GCP				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	0.98	0	1019.27
	100	31.677	0	2917.25
	200	48.202	20.75	1710.83
	250	34.806	5.56	4785.39
	500	61.696	35.27	1849.41
	750	23.176	0	1554.61
	1000	21.738	36.53	1841.02
RPS From TiProxy with GCP				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	36.797	0	27.18
	100	35.268	0	2730.93
	200	34.041	0	4779.98
	250	36.206	0	5030.6
	500	57.468	0	4084.91
	750	41.62	0	3774.03
	1000	54.022	0	3163.58
				
跨專線混合部署 IDC * 2 + GCP * 3				
RPS From TiDB with IDC				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	1.48	0	675.02
	100	23.21	0	3896.01
	200	46.773	8.86	2575.13
	250	36.196	14.28	2219.82
	500	35.938	4	2958.15
	750	33.194	19.34	1814.32
	1000	21.095	21.88	2739.32
RPS From TiProxy with IDC				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	2.427	0	411.85
	100	19.294	0	4232.26
	200	27.465	0	5788.76
	250	32.883	0	5978.74
	500	60.793	0	5622.82
	750	59.5	0	5013.66
	1000	47.387	0	4646.92
RPS From TiDB with GCP				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	1.054	0	948.18
	100	29.537	0	3039.49
	200	49.53	20.71	1704.71
	250	24.351	2.48	6219.94
	500	53.446	62.78	1541.65
	750	22.688	0	1557.38
	1000	6.172	0	3803.42
RPS From TiProxy with GCP				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	31.418	0	31.83
	100	31.325	0	3013.08
	200	35.173	0	4682.24
	250	27.626	0	5694.75
	500	41.35	0	4862.79
	750	52.64	0	3759.3
	1000	46.738	0	3180.53
				
跨專線混合部署 IDC * 2 + GCP * 3 (兩機房同時執行 RPS 測試)				
RPS From TiDB with IDC				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	1.485	0	672.81
	100	24.372	0	3632.48
	200	54.522	8.53	2537.45
	250	40.081	14.7	3709.59
	500	29.858	4.02	2778.59
	750	35.053	19.02	1783.72
	1000	23.595	22.2	2502.78
RPS From TiProxy with IDC				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	2.352	0	424.94
	100	27.769	0	3201.66
	200	25.908	0	6093.34
	250	32.465	0	6132.87
	500	50.214	0	5620.78
	750	68.755	0	3846.16
	1000	47.83	0	4218.96
RPS From TiDB with GCP				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	1.048	0	953.85
	100	29.059	0	3043.38
	200	48.382	20.67	1707.85
	250	22.354	2.48	6646.97
	500	65.526	3.92	2280.04
	750	31.777	23.68	1387.2
	1000	31.907	66.06	1307.07
RPS From TiProxy with GCP				
	Threads	Avg Response (ms)	Error Rate %	Req/sec
	1	32.81	0	30.48
	100	32.76	0	2907.92
	200	35.048	0	3513.05
	250	36.499	0	5083.99
	500	40.711	0	4866.94
	750	28.842	0	3879.08
	1000	19.633	0	3390