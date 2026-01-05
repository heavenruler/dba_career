### Function for Processing
function logoutIdracSession($idracHost, $authToken){
    $session = getIdracSessionID($idracHost, $authToken);
    $shellCommand = "curl --noproxy '*' -s --header \"X-Auth-Token: $authToken\" -k -X DELETE https://$idracHost$session";
    exec($shellCommand);
}

function getIdracSessionID($idracHost, $authToken){
    $shellCommand = "curl --noproxy '*' -s --header \"X-Auth-Token: $authToken\" -k https://$idracHost/redfish/v1/Sessions";
    $result = shell_exec($shellCommand);
    $result = json_decode($result);
    foreach ($result as $resultSet) {
        if (!is_array($resultSet)) {continue;}
        $resultSet = (array) $resultSet;
        $tmp = (array) $resultSet[0];
        return ($tmp["@odata.id"]);
    }
}

function getIdracLog($idracHost, $authToken){
    $shellCommand = "curl --noproxy '*' -s --header \"X-Auth-Token: $authToken\" -k https://$idracHost/redfish/v1/Managers/iDRAC.Embedded.1/Logs/Sel";
    $result = shell_exec($shellCommand);

    # execute logout idrac sessions
    logoutIdracSession($idracHost, $authToken);

    return $result;
}

function getIdracAuthToken($idracHost, $idracUsername, $idracPassword) {
    $shellCommand = "curl --noproxy '*' -D 'token.file' -v -k -X POST -d '{\"UserName\":\"$idracUsername\",\"Password\":\"$idracPassword\"}' -H 'Content-Type: application/json' https://$idracHost/redfish/
v1/Sessions";
    shell_exec($shellCommand);
    $shellCommand = "cat token.file | grep X-Auth-Token | awk '{print $2}'";
    $result = shell_exec($shellCommand);
    unlink("token.file");
    return $result;
}

function sent2Slack($message, $channel) {
    global $slackToken;
    $env = getEnvironment();
    $channel = ($channel) ? $channel : "104_alert_db_test";
    $slackUserName = "DB-Monitor";
    $ch = curl_init("https://slack.com/api/chat.postMessage");

    $data = http_build_query(array(
        "token" => $slackToken,
        "channel" => "#" . $channel,
        "text" => $message,
        "username" => $slackUserName,
        ));

    if ("staging" == $env) {
        $proxy = "http://sproxy.104-staging.com.tw:3128/";
    } else if ("production" == $env) {
        $proxy = "http://sproxy.104.com.tw:3128/";
    }
    curl_setopt($ch, CURLOPT_PROXY, $proxy);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'POST');
    curl_setopt($ch, CURLOPT_POSTFIELDS, $data);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    $result = curl_exec($ch);
    curl_close($ch);

    return $result;
}
