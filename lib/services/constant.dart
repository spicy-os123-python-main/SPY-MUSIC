import 'app_secrets.dart';

String get domain => AppSecrets.ytMusicDomain;
String get baseUrl => '${domain}youtubei/v1/';

String get fixedParms => '?prettyPrint=false&alt=json&key=${AppSecrets.ytPublicKey}';

const userAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
