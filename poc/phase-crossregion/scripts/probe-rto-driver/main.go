// probe-rto-driver — Go RTO probe (per RTO-RPO-methodology.md §3.2 / codex F8)
//
// Uses os/exec to call DB CLI per probe; time.Since() gives monotonic latency.
// Outputs probe.txt (ts_ms ok|err kind) + probe-stats.json (jitter stats) on exit.
//
// Build:  go build -o probe-rto-driver .
// Run:    ./probe-rto-driver -db tidb -artifact-dir /tmp/probe
//
// DB defaults (haproxy):  tidb :4000 / crdb :26257 / ybdb :5433
// Stop:  touch $artifact-dir/.probe.stop  OR  SIGTERM/SIGINT
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"math"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"sort"
	"strings"
	"syscall"
	"time"
)

// ProbeStats is written to probe-stats.json on exit.
type ProbeStats struct {
	TotalProbes     int     `json:"total_probes"`
	OkCount         int     `json:"ok_count"`
	ErrCount        int     `json:"err_count"`
	LatP50Ms        float64 `json:"lat_p50_ms"`
	LatP95Ms        float64 `json:"lat_p95_ms"`
	LatP99Ms        float64 `json:"lat_p99_ms"`
	LatMeanMs       float64 `json:"lat_mean_ms"`
	LatStddevMs     float64 `json:"lat_stddev_ms"`
	JitterStddevMs  float64 `json:"jitter_stddev_ms"`
	DurationSec     float64 `json:"duration_sec"`
}

func main() {
	db := flag.String("db", "", "tidb|crdb|ybdb")
	host := flag.String("host", "", "DB host (default: haproxy 172.24.47.20)")
	port := flag.Int("port", 0, "DB port (default per DB)")
	user := flag.String("user", "root", "DB user")
	artifactDir := flag.String("artifact-dir", "", "output directory (required)")
	intervalMs := flag.Int("interval-ms", 100, "probe interval in ms")
	flag.Parse()

	if *db == "" || *artifactDir == "" {
		fmt.Fprintln(os.Stderr, "usage: probe-rto-driver -db tidb|crdb|ybdb -artifact-dir <dir>")
		os.Exit(1)
	}
	if *db != "tidb" && *db != "crdb" && *db != "ybdb" {
		fmt.Fprintln(os.Stderr, "db must be tidb, crdb, or ybdb")
		os.Exit(1)
	}

	if *host == "" {
		*host = "172.24.47.20"
	}
	if *port == 0 {
		switch *db {
		case "tidb":
			*port = 4000
		case "crdb":
			*port = 26257
		case "ybdb":
			*port = 5433
		}
	}

	if err := os.MkdirAll(*artifactDir, 0o755); err != nil {
		fmt.Fprintf(os.Stderr, "mkdir %s: %v\n", *artifactDir, err)
		os.Exit(1)
	}

	probeTxt := filepath.Join(*artifactDir, "probe.txt")
	stopFile := filepath.Join(*artifactDir, ".probe.stop")
	os.Remove(stopFile)

	f, err := os.OpenFile(probeTxt, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "open %s: %v\n", probeTxt, err)
		os.Exit(1)
	}
	defer f.Close()

	setupTable(*db, *host, *port, *user)

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGTERM, syscall.SIGINT)

	ticker := time.NewTicker(time.Duration(*intervalMs) * time.Millisecond)
	defer ticker.Stop()

	start := time.Now()
	var lats []float64
	var jitters []float64
	var prevLat float64
	ok, errs := 0, 0
	seq := 0

	fmt.Printf("[probe-rto] db=%s host=%s:%d interval=%dms → %s\n",
		*db, *host, *port, *intervalMs, probeTxt)

	for {
		select {
		case <-sigCh:
			writeStats(*artifactDir, start, lats, jitters, ok, errs)
			return
		case <-ticker.C:
			if _, serr := os.Stat(stopFile); serr == nil {
				writeStats(*artifactDir, start, lats, jitters, ok, errs)
				fmt.Printf("[probe-rto] stopped via stop-file (seq=%d)\n", seq)
				return
			}

			tsMs := time.Now().UnixMilli()
			t0 := time.Now() // monotonic reference
			errKind := runProbe(*db, *host, *port, *user, tsMs, seq)
			latMs := float64(time.Since(t0).Nanoseconds()) / 1e6 // monotonic elapsed

			if errKind == "" {
				fmt.Fprintf(f, "%d ok -\n", tsMs)
				ok++
				lats = append(lats, latMs)
				if prevLat > 0 {
					jitters = append(jitters, math.Abs(latMs-prevLat))
				}
				prevLat = latMs
			} else {
				fmt.Fprintf(f, "%d err %s\n", tsMs, errKind)
				errs++
				prevLat = 0
			}
			seq++
		}
	}
}

// runProbe executes one INSERT via DB CLI; returns "" on commit ACK, err-kind on failure.
// YBDB gets statement_timeout via PGOPTIONS to prevent post-failover hangs.
func runProbe(db, host string, port int, user string, tsMs int64, seq int) string {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	var cmd *exec.Cmd
	sql := fmt.Sprintf("INSERT INTO probe_db.probe_rto(ts,seq) VALUES(%d,%d);", tsMs, seq)

	switch db {
	case "tidb":
		cmd = exec.CommandContext(ctx, "mysql",
			"-h", host, fmt.Sprintf("-P%d", port),
			"-u", user, "--connect-timeout=3", "-e", sql)
	case "crdb":
		cmd = exec.CommandContext(ctx, "cockroach", "sql",
			"--insecure",
			fmt.Sprintf("--host=%s:%d", host, port),
			"-d", "probe_db",
			"-e", sql)
	case "ybdb":
		dsn := fmt.Sprintf("postgresql://%s@%s:%d/probe_db?sslmode=disable&connect_timeout=3", user, host, port)
		cmd = exec.CommandContext(ctx, "psql", dsn,
			"-v", "ON_ERROR_STOP=1",
			"-c", fmt.Sprintf("SET statement_timeout=3000; %s", sql))
		cmd.Env = append(os.Environ(), "PGOPTIONS=-c statement_timeout=3000")
	}

	out, err := cmd.CombinedOutput()
	if err == nil {
		return ""
	}
	if ctx.Err() != nil {
		return "timeout"
	}
	s := string(out)
	switch {
	case strings.Contains(s, "connection refused"):
		return "connection-refused"
	case strings.Contains(s, "no route to host"):
		return "no-route"
	case strings.Contains(s, "lost connection"), strings.Contains(s, "server has gone away"):
		return "lost-connection"
	default:
		return "db-error"
	}
}

// setupTable creates probe_db.probe_rto if not exists; failures are warnings only.
func setupTable(db, host string, port int, user string) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	var cmd *exec.Cmd
	switch db {
	case "tidb":
		sql := "CREATE DATABASE IF NOT EXISTS probe_db;" +
			"CREATE TABLE IF NOT EXISTS probe_db.probe_rto(" +
			"id BIGINT AUTO_INCREMENT PRIMARY KEY,ts BIGINT NOT NULL,seq INT NOT NULL);"
		cmd = exec.CommandContext(ctx, "mysql",
			"-h", host, fmt.Sprintf("-P%d", port),
			"-u", user, "--connect-timeout=5", "-e", sql)
	case "crdb":
		// create db first (ignore error if exists)
		exec.CommandContext(ctx, "cockroach", "sql", "--insecure",
			fmt.Sprintf("--host=%s:%d", host, port),
			"-e", "CREATE DATABASE IF NOT EXISTS probe_db;").Run()
		cmd = exec.CommandContext(ctx, "cockroach", "sql", "--insecure",
			fmt.Sprintf("--host=%s:%d", host, port), "-d", "probe_db",
			"-e", "CREATE TABLE IF NOT EXISTS probe_rto(id SERIAL PRIMARY KEY,ts BIGINT NOT NULL,seq INT NOT NULL);")
	case "ybdb":
		exec.CommandContext(ctx, "psql",
			fmt.Sprintf("postgresql://%s@%s:%d/yugabyte?sslmode=disable", user, host, port),
			"-c", "CREATE DATABASE IF NOT EXISTS probe_db;").Run()
		dsn := fmt.Sprintf("postgresql://%s@%s:%d/probe_db?sslmode=disable", user, host, port)
		cmd = exec.CommandContext(ctx, "psql", dsn,
			"-c", "CREATE TABLE IF NOT EXISTS probe_rto(id SERIAL PRIMARY KEY,ts BIGINT NOT NULL,seq INT NOT NULL);")
	}
	if cmd != nil {
		if err := cmd.Run(); err != nil {
			fmt.Fprintf(os.Stderr, "[probe-rto] WARN: table setup: %v\n", err)
		}
	}
}

func percentile(sorted []float64, p float64) float64 {
	if len(sorted) == 0 {
		return 0
	}
	idx := int(float64(len(sorted)-1) * p)
	return math.Round(sorted[idx]*1000) / 1000
}

func mean(vals []float64) float64 {
	if len(vals) == 0 {
		return 0
	}
	s := 0.0
	for _, v := range vals {
		s += v
	}
	return math.Round(s/float64(len(vals))*1000) / 1000
}

func stddev(vals []float64) float64 {
	if len(vals) < 2 {
		return 0
	}
	m := mean(vals)
	v := 0.0
	for _, x := range vals {
		d := x - m
		v += d * d
	}
	return math.Round(math.Sqrt(v/float64(len(vals)))*1000) / 1000
}

func writeStats(dir string, start time.Time, lats, jitters []float64, ok, errs int) {
	sort.Float64s(lats)
	sort.Float64s(jitters)
	stats := ProbeStats{
		TotalProbes:    ok + errs,
		OkCount:        ok,
		ErrCount:       errs,
		LatP50Ms:       percentile(lats, 0.50),
		LatP95Ms:       percentile(lats, 0.95),
		LatP99Ms:       percentile(lats, 0.99),
		LatMeanMs:      mean(lats),
		LatStddevMs:    stddev(lats),
		JitterStddevMs: stddev(jitters),
		DurationSec:    math.Round(time.Since(start).Seconds()*1000) / 1000,
	}
	data, _ := json.MarshalIndent(stats, "", "  ")
	path := filepath.Join(dir, "probe-stats.json")
	if err := os.WriteFile(path, append(data, '\n'), 0o644); err != nil {
		fmt.Fprintf(os.Stderr, "[probe-rto] writeStats: %v\n", err)
		return
	}
	fmt.Printf("[probe-rto] stats → %s  ok=%d err=%d p50=%.1fms p99=%.1fms jitter=%.1fms\n",
		path, ok, errs, stats.LatP50Ms, stats.LatP99Ms, stats.JitterStddevMs)
}
