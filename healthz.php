<?php
// Railway health check: 200 when the database answers, 503 otherwise. Reveals nothing else.
header('Content-Type: text/plain');
header('Cache-Control: no-store');
mysqli_report(MYSQLI_REPORT_OFF);
$db = mysqli_init();
mysqli_options($db, MYSQLI_OPT_CONNECT_TIMEOUT, 3);
$ok = @mysqli_real_connect(
    $db,
    getenv('DB_HOST') ?: 'localhost',
    getenv('DB_USERNAME') ?: '',
    getenv('DB_PASSWORD') ?: '',
    getenv('DB_NAME') ?: '',
    (int) (getenv('DB_PORT') ?: 3306)
);
if (!$ok) {
    http_response_code(503);
    echo "database unavailable\n";
    exit;
}
mysqli_close($db);
echo "ok\n";
