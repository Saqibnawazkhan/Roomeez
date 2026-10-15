import 'dart:math';

/// Produces join codes. In production the code must be generated and checked
/// for uniqueness on the server; this interface lets that be swapped in.
abstract interface class GroupCodeGenerator {
  String generate();
}

/// Random 6-character codes without look-alike characters (0/O, 1/I/L).
class RandomGroupCodeGenerator implements GroupCodeGenerator {
  RandomGroupCodeGenerator({Random? random}) : _random = random ?? Random.secure();

  static const String _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const int length = 6;

  final Random _random;

  @override
  String generate() {
    return List.generate(length, (_) => _alphabet[_random.nextInt(_alphabet.length)]).join();
  }
}

abstract final class GroupCodeFormat {
  static final RegExp _pattern = RegExp(r'^[A-Z0-9]{6,8}$');

  static String normalize(String input) => input.replaceAll(RegExp(r'\s'), '').toUpperCase();

  static bool isValid(String input) => _pattern.hasMatch(normalize(input));
}
