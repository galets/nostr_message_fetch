import 'dart:convert';
import 'dart:typed_data';
import 'package:kepler/kepler.dart';
import 'package:nostr/nostr.dart';
import "package:pointycastle/export.dart";

class Nip04 {
  final String key;

  Nip04(this.key);

  String decrypt(String privateKeyHex, String publicKeyHex, String cipherTextBase64, String ivBase64) {
    final cipherText = base64.decode(cipherTextBase64);
    final iv = base64.decode(ivBase64);
    final sharedSecret = Kepler.byteSecret(privateKeyHex, publicKeyHex);
    final key = Uint8List.fromList(sharedSecret[0]);

    final params = PaddedBlockCipherParameters(ParametersWithIV(KeyParameter(key), iv), null);

    final cipherImpl = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()));
    cipherImpl.init(false, params);

    int ptr = 0;
    final buffer = Uint8List(cipherText.length);
    while (ptr < cipherText.length - 16) {
      ptr += cipherImpl.processBlock(cipherText, ptr, buffer, ptr);
    }
    ptr += cipherImpl.doFinal(cipherText, ptr, buffer, ptr);

    final rawData = buffer.sublist(0, ptr).toList();
    return const Utf8Decoder().convert(rawData);
  }

  String decryptContent(Event event) {
    final fragments = event.content.split("?iv=");
    if (fragments.length != 2) {
      throw Exception("bad content");
    }

    final cipher = fragments[0];
    final iv = fragments[1];

    return decrypt(key, '02${event.pubkey}', cipher, iv);
  }
}

String generatePrivateKey() {
  final kp = Kepler.generateKeyPair();
  return Kepler.strinifyPrivateKey(kp.privateKey as ECPrivateKey);
}

String getPublicKeyFromPrivate(String privateKey) {
  var keyParams = ECCurve_secp256k1();
  final kp = Kepler.loadPrivateKey(privateKey);
  final q = ECCurve_secp256k1().G * kp.d;
  final publicKey = ECPublicKey(q, keyParams);
  return Kepler.strinifyPublicKey(publicKey).substring(2);
}
