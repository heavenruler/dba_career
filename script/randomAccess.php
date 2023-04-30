#!/usr/bin/php
<?php
$url = 'https://blog.wnlin.org/post-sitemap.xml';
$curlCommand = "curl -s -L -o /dev/null -w '%{http_code}' ";

$urls = array();
$fp = fopen($url, 'r');
if ($fp) {
    while (($line = fgets($fp)) !== false) {
        if (preg_match('/<loc>(.*)<\/loc>/', $line, $match)) {
            $urls[] = $match[1];
        }
    }
    fclose($fp);
}

// Randomly select user agent from list
$userAgents = [
    // Desktop browsers
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3',
    'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:54.0) Gecko/20100101 Firefox/54.0',
    'Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3',

    // Mobile browsers
    'Mozilla/5.0 (iPhone; CPU iPhone OS 10_3_1 like Mac OS X) AppleWebKit/603.1.30 (KHTML, like Gecko) Version/10.0 Mobile/14E304 Safari/602.1',
    'Mozilla/5.0 (Linux; Android 7.0; SM-G930V Build/NRD90M) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.83 Mobile Safari/537.36',
    'Mozilla/5.0 (iPad; CPU OS 10_3_1 like Mac OS X) AppleWebKit/603.1.30 (KHTML, like Gecko) Version/10.0 Mobile/14E304 Safari/602.1',
];

$maxThreads = 10;
$curThreads = 0;

while (true) {
    if ($curThreads < $maxThreads && !empty($urls)) {
        $url = array_shift($urls);
        $userAgent = $userAgents[array_rand($userAgents)];
        $pid = pcntl_fork();
        if ($pid == -1) {
            echo "Failed to fork process" . PHP_EOL;
        } elseif ($pid == 0) {
            // Child process
            $sleepTime = mt_rand(1, 30);
            $curlUrl = escapeshellarg($url);
            $curlCommandWithUserAgent = $curlCommand . " -H 'User-Agent: $userAgent'";
            $command = "sleep $sleepTime && $curlCommandWithUserAgent $curlUrl";
            exec($command);
            exit(0);
        } else {
            // Parent process
            $curThreads++;
        }
    }

    if (pcntl_waitpid(-1, $status, WNOHANG) > 0) {
        $curThreads--;
    }

    // If there are no more child processes and no more urls to process, exit loop
    if ($curThreads == 0 && empty($urls)) {
        break;
    }

    usleep(50000); // Wait 50ms before checking again
}
