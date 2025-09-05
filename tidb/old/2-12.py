# TiProxy with GCP 離峰測試 #2-12

test_results = [
    {
        "threads": 1,
        "single_thread_single_conn": {"total_tests": 10000, "avg_response_ms": 11.141, "error_rate": 0.00, "total_time_s": 111.440, "req_per_sec": 89.73},
        "single_thread_multi_conn": {"total_tests": 10000, "avg_response_ms": 11.359, "error_rate": 0.00, "total_time_s": 113.612, "req_per_sec": 88.02},
        "multi_thread_multi_conn": {"total_tests": 10000, "avg_response_ms": 34.252, "error_rate": 0.00, "total_time_s": 342.529, "req_per_sec": 29.19}
    },
    {
        "threads": 100,
        "single_thread_single_conn": {"total_tests": 10000, "avg_response_ms": 11.437, "error_rate": 0.00, "total_time_s": 114.399, "req_per_sec": 87.41},
        "single_thread_multi_conn": {"total_tests": 10000, "avg_response_ms": 11.442, "error_rate": 0.00, "total_time_s": 116.694, "req_per_sec": 85.69},
        "multi_thread_multi_conn": {"total_tests": 10000, "avg_response_ms": 33.849, "error_rate": 0.00, "total_time_s": 3.517, "req_per_sec": 2843.08}
    },
    {
        "threads": 200,
        "single_thread_single_conn": {"total_tests": 10000, "avg_response_ms": 11.154, "error_rate": 0.00, "total_time_s": 111.563, "req_per_sec": 89.64},
        "single_thread_multi_conn": {"total_tests": 10000, "avg_response_ms": 11.463, "error_rate": 0.00, "total_time_s": 119.145, "req_per_sec": 83.93},
        "multi_thread_multi_conn": {"total_tests": 10000, "avg_response_ms": 34.944, "error_rate": 0.00, "total_time_s": 2.166, "req_per_sec": 4615.91}
    },
    {
        "threads": 250,
        "single_thread_single_conn": {"total_tests": 10000, "avg_response_ms": 11.310, "error_rate": 0.00, "total_time_s": 113.122, "req_per_sec": 88.40},
        "single_thread_multi_conn": {"total_tests": 10000, "avg_response_ms": 11.571, "error_rate": 0.00, "total_time_s": 121.475, "req_per_sec": 82.32},
        "multi_thread_multi_conn": {"total_tests": 10000, "avg_response_ms": 37.116, "error_rate": 0.00, "total_time_s": 2.009, "req_per_sec": 4977.37}
    },
    {
        "threads": 500,
        "single_thread_single_conn": {"total_tests": 10000, "avg_response_ms": 11.425, "error_rate": 0.00, "total_time_s": 114.277, "req_per_sec": 87.51},
        "single_thread_multi_conn": {"total_tests": 10000, "avg_response_ms": 11.520, "error_rate": 0.00, "total_time_s": 126.558, "req_per_sec": 79.02},
        "multi_thread_multi_conn": {"total_tests": 10000, "avg_response_ms": 45.609, "error_rate": 0.00, "total_time_s": 2.277, "req_per_sec": 4391.55}
    },
    {
        "threads": 750,
        "single_thread_single_conn": {"total_tests": 10000, "avg_response_ms": 11.098, "error_rate": 0.00, "total_time_s": 111.005, "req_per_sec": 90.09},
        "single_thread_multi_conn": {"total_tests": 10000, "avg_response_ms": 11.727, "error_rate": 0.00, "total_time_s": 134.861, "req_per_sec": 74.15},
        "multi_thread_multi_conn": {"total_tests": 10000, "avg_response_ms": 45.643, "error_rate": 0.00, "total_time_s": 2.646, "req_per_sec": 3779.19}
    },
    {
        "threads": 1000,
        "single_thread_single_conn": {"total_tests": 10000, "avg_response_ms": 11.117, "error_rate": 0.00, "total_time_s": 111.196, "req_per_sec": 89.93},
        "single_thread_multi_conn": {"total_tests": 10000, "avg_response_ms": 11.827, "error_rate": 0.00, "total_time_s": 141.070, "req_per_sec": 70.89},
        "multi_thread_multi_conn": {"total_tests": 10000, "avg_response_ms": 43.773, "error_rate": 0.00, "total_time_s": 3.161, "req_per_sec": 3163.10}
    }
]

if __name__ == "__main__":
    import pprint
    pprint.pprint(test_results)
