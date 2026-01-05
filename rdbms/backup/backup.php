#!/usr/bin/php
<?php
$user = 'wnlin';
$pass = 'password';
$fqdnList = 'backupHost.list';
$fileContents = file($fqdnList);

foreach($fileContents as $line) {
    $line = trim($line);
    system('rm -rf -- ' . escapeshellarg(trim("/data/backup/mysqldump/$line/*")), $retval);
    exec("mkdir -p /data/backup/mysqldump/$line");

    $dbList = getDatabases($line);

    foreach ($dbList as $dbName) {
        exec("/104/backup/mysqldumpp.sh $line $user $pass $dbName");
    }
    exec("chmod -R 777 /data/backup/mysqldump/$line");
}

function getDatabases($fqdn) {
    global $user;
    global $pass;
    $sqlCommand = "SHOW DATABASES;";
    $byPassDB = array("Database","information_schema","performance_schema","mysql","sys","test");
    exec("/usr/bin/mysql -h$fqdn -u$user -p$pass -e '$sqlCommand' 2>&1", $results);

    $results = array_diff($results, $byPassDB);
    return (array_values($results));
}
