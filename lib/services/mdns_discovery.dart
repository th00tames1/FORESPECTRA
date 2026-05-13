import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';

/// Look up sensor IPs advertised over mDNS.
///
/// REQUIRES SENSOR FIRMWARE SUPPORT: the sensor must advertise itself
/// using a Bonjour/mDNS service. With NeoSpectra-class firmware this is
/// typically not enabled by default — coordinate with the sensor vendor
/// or firmware owner.
///
/// Expected advertisement (example): `_sinir._tcp.local`. Adjust the
/// service type below to whatever the firmware actually publishes.
Future<List<String>> discoverViaMdns({
  String serviceType = '_sinir._tcp.local',
  Duration timeout = const Duration(seconds: 2),
}) async {
  final client = MDnsClient();
  final results = <String>{};
  try {
    await client.start();
    final ptrStream = client
        .lookup<PtrResourceRecord>(
          ResourceRecordQuery.serverPointer(serviceType),
        )
        .timeout(timeout, onTimeout: (sink) => sink.close());

    await for (final PtrResourceRecord ptr in ptrStream) {
      final srvStream = client.lookup<SrvResourceRecord>(
        ResourceRecordQuery.service(ptr.domainName),
      );
      await for (final SrvResourceRecord srv in srvStream) {
        final ipStream = client.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4(srv.target),
        );
        await for (final IPAddressResourceRecord ip in ipStream) {
          results.add(ip.address.address);
        }
      }
    }
  } catch (error) {
    debugPrint('mDNS lookup failed: $error');
  } finally {
    client.stop();
  }
  return results.toList();
}
