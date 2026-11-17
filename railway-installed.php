<?php
// Exit 0 when the database already holds an Easy!Appointments installation (table ea_users),
// 1 otherwise. Waits up to about a minute for the database to answer.
mysqli_report(MYSQLI_REPORT_OFF);
$port = (int) (getenv('DB_PORT') ?: 3306);
for ($i = 0; $i < 30; $i++) {
    $db = @mysqli_connect(getenv('DB_HOST'), getenv('DB_USERNAME'), getenv('DB_PASSWORD'), getenv('DB_NAME'), $port);
    if ($db) {
        $r = mysqli_query($db, "SHOW TABLES LIKE 'ea\\_users'");
        exit($r && mysqli_num_rows($r) > 0 ? 0 : 1);
    }
    sleep(2);
}
fwrite(STDERR, "railway-start: database not reachable\n");
exit(1);
