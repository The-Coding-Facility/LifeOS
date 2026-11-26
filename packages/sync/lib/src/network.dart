import 'dart:io';

import 'sync_protocol.dart';

/// Private IPv4-Adressen dieses Geräts, Heimnetz-Adressen (192.168.x.x) zuerst.
Future<List<String>> localAddresses() async {
  final interfaces = await NetworkInterface.list(
    includeLoopback: false,
    type: InternetAddressType.IPv4,
  );
  final result = <String>{};
  for (final networkInterface in interfaces) {
    for (final address in networkInterface.addresses) {
      if (isPrivateIPv4(address.address)) result.add(address.address);
    }
  }
  final sorted = result.toList()
    ..sort((a, b) {
      final aHome = a.startsWith('192.168.') ? 0 : 1;
      final bHome = b.startsWith('192.168.') ? 0 : 1;
      return aHome != bHome ? aHome - bHome : a.compareTo(b);
    });
  return sorted;
}

final RegExp _private172 = RegExp(r'^172\.(1[6-9]|2\d|3[01])\.');

bool isPrivateIPv4(String ip) =>
    ip.startsWith('192.168.') || ip.startsWith('10.') || _private172.hasMatch(ip);

/// `192.168.1.5` → `192.168.1.5:47321`. Leerzeichen werden entfernt.
String normalizeAddress(String input) {
  final trimmed = input.trim().replaceAll(' ', '');
  if (trimmed.isEmpty) throw const FormatException('Adresse fehlt');
  return trimmed.contains(':') ? trimmed : '$trimmed:${SyncProtocol.defaultPort}';
}
