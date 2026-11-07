import 'app_secrets.dart';

const domain = "https://music.youtube.com/";
const String baseUrl = '${domain}youtubei/v1/';

// Public YouTube Music web client key (retrieved from secure secrets vault)
final String _ytPublicKey = AppSecrets.ytPublicKey;
final String fixedParms = '?prettyPrint=false&alt=json&key=$_ytPublicKey';

const userAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
