import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import '../enum/enum.dart';
import '../models/models.dart';
import '../common/common.dart';
import 'generated/clash_ffi.dart';

class ClashCore {
  static ClashCore? _instance;
  static final receiver = ReceivePort();

  late final ClashFFI clashFFI;
  late final DynamicLibrary lib;

  ClashCore._internal() {
    if (Platform.isWindows) {
      lib = DynamicLibrary.open("libclash.dll");
      clashFFI = ClashFFI(lib);
    }
    if (Platform.isMacOS) {
      lib = DynamicLibrary.open("libclash.dylib");
      clashFFI = ClashFFI(lib);
    }
    if (Platform.isAndroid || Platform.isLinux) {
      lib = DynamicLibrary.open("libclash.so");
      clashFFI = ClashFFI(lib);
    }
    clashFFI.initNativeApiBridge(
      NativeApi.initializeApiDLData,
      receiver.sendPort.nativePort,
    );
  }

  factory ClashCore() {
    _instance ??= ClashCore._internal();
    return _instance!;
  }

  bool init(String homeDir) {
    return clashFFI.initClash(
          homeDir.toNativeUtf8().cast(),
        ) ==
        1;
  }

  shutdown() {
    clashFFI.shutdownClash();
    lib.close();
  }

  bool get isInit => clashFFI.getIsInit() == 1;

  bool validateConfig(String data) {
    return clashFFI.validateConfig(
          data.toNativeUtf8().cast(),
        ) ==
        1;
  }

  bool updateConfig(UpdateConfigParams updateConfigParams) {
    final params = json.encode(updateConfigParams);
    return clashFFI.updateConfig(
          params.toNativeUtf8().cast(),
        ) ==
        1;
  }

  Future<List<Group>> getProxiesGroups() {
    final proxiesRaw = clashFFI.getProxies();
    final proxiesRawString = proxiesRaw.cast<Utf8>().toDartString();
    return Isolate.run<List<Group>>(() {
      final proxies = json.decode(proxiesRawString);
      final groupsRaw = (proxies[UsedProxy.GLOBAL.name]["all"] as List)
          .where((e) {
        final proxy = proxies[e];
        final excludeName = !UsedProxyExtension.valueList
            .where((element) => element != UsedProxy.GLOBAL.name)
            .contains(proxy['name']);
        final validType = GroupTypeExtension.valueList.contains(proxy['type']);
        return excludeName && validType;
      }).map((groupName) {
        final group = proxies[groupName];
        group["all"] = ((group["all"] ?? []) as List)
            .map(
              (name) => proxies[name],
            )
            .toList();
        return group;
      }).toList();
      return groupsRaw.map((e) => Group.fromJson(e)).toList();
    });
  }

  bool changeProxy(ChangeProxyParams changeProxyParams) {
    final params = json.encode(changeProxyParams);
    return clashFFI.changeProxy(params.toNativeUtf8().cast()) == 1;
  }

  bool delay(String proxyName) {
    final delayParams = {
      "proxy-name": proxyName,
      "timeout": appConstant.httpTimeoutDuration.inMilliseconds,
    };
    clashFFI.asyncTestDelay(json.encode(delayParams).toNativeUtf8().cast());
    return true;
  }

  VersionInfo getVersionInfo() {
    final versionInfoRaw = clashFFI.getVersionInfo();
    final versionInfo = json.decode(versionInfoRaw.cast<Utf8>().toDartString());
    return VersionInfo.fromJson(versionInfo);
  }

  Traffic getTraffic() {
    final trafficRaw = clashFFI.getTraffic();
    final trafficMap = json.decode(trafficRaw.cast<Utf8>().toDartString());
    return Traffic.fromMap(trafficMap);
  }

  void startLog() {
    clashFFI.startLog();
  }

  stopLog() {
    clashFFI.stopLog();
  }

  startTun(int fd) {
    clashFFI.startTUN(fd);
  }

  void stopTun() {
    clashFFI.stopTun();
  }

  List<Connection> getConnections() {
    final connectionsDataRaw = clashFFI.getConnections();
    final connectionsData =
        json.decode(connectionsDataRaw.cast<Utf8>().toDartString()) as Map;
    final connectionsRaw = connectionsData['connections'] as List? ?? [];
    return connectionsRaw.map((e) => Connection.fromJson(e)).toList();
  }
}

final clashCore = ClashCore();
