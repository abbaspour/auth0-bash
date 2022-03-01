<?php

declare(strict_types=1);

$NEW_LOCATION = 'https://shunsuke-saml-sp.auth0.com/login/callback?connection=shunsuke-saml-idp';

if (isset($_GET["SAMLResponse"])) {
    $SAMLResponse = $_GET["SAMLResponse"];
    $RelayState = $_GET["RelayState"];
}
else if (isset($_POST["SAMLResponse"])) {
    $SAMLResponse = $_POST["SAMLResponse"];
    $RelayState = $_POST["RelayState"];
} else {
    die("params input");
}
// Auth0
// The SAML Response Binding only supports HTTP-POST.
// HTTP-REDIRECT binding must be converted HTTP-POST
?>

<html lang="en">
    <body onload="document.forms[0].submit()">
        <form method="POST" action=<?= "$NEW_LOCATION" ?>>
            <input type="hidden" name="SAMLResponse" value="<?= $SAMLResponse ?>">
            <?php if (isset($RelayState)) { ?>
                <input type="hidden" name="RelayState" value="<?= $RelayState ?>">
            <?php } ?>
        </form>
    </body>
</html>
