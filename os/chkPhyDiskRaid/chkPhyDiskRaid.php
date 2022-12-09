#!/usr/bin/php
<?php
# http://jira.104.com.tw/browse/ITDBA-464
# dba-misc/new-dba-cronjob/chkPhyDiskRaidStaging

include_once "/104/dba-include/include.php";

$alertTrigger = false;
$alertMessage = "[Warning]" . PHP_EOL;
$alertMessage .= "Staging: 實體機硬碟異常." . PHP_EOL;

$phyIPList = array("172.21.47.1",
                   "172.21.47.2",
                   "172.21.47.5",
                   "172.21.47.6",
                   "172.21.47.7",
                   "172.21.47.8",
                   "172.21.47.9",
                   "172.21.47.10");
$sshCommandPrefix = "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=2";

foreach ($phyIPList as $host) {
    $commandArray = array('/bin/hostname -s',
                          '/usr/sbin/megacli -AdpAllInfo -aALL | grep \'Critical Disks\' | awk \'{print $NF}\'',
                          '/usr/sbin/megacli -AdpAllInfo -aALL | grep \'Failed Disks\' | awk \'{print $NF}\'');
    $executeCommand = implode(" ; ", $commandArray);
    $executeResult = executeCommand("$sshCommandPrefix -q -i /root/.ssh/id_rsa root@$host \"$executeCommand\" < /dev/null");

    foreach ($executeResult as $line) {
        $result = explode(":", $line);
        if (1 == count($result)) {
            $hostname = $line;
        } else if (2 == count($result)) {
            if (0 == $line[1]) { continue; }
            $alertTrigger = true;
            $alertMessage .= "$hostname -> $line" . PHP_EOL;
        }
    }
}

if ($alertTrigger) { alert2SlackStaging("$alertMessage" . " from " . basename(__FILE__)); }
