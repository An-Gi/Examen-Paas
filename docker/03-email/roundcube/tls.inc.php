<?php
// Roundcube verifica el certificado de mail.paas.internal con la raíz de nuestra CA — Estudiante A (Fase 3)
// Sin esto, PHP solo confía en las CA públicas y la conexión STARTTLS a IMAP y SMTP falla.
$tls = ['ssl' => [
    'verify_peer'      => true,
    'verify_peer_name' => true,
    'cafile'           => '/etc/ssl/paas/ca.crt',
]];
$config['imap_conn_options'] = $tls;
$config['smtp_conn_options'] = $tls;
