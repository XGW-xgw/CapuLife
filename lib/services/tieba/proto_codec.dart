import 'dart:typed_data';

import 'proto_wire.dart';
import 'tieba_session.dart';

const tiebaVersionV11 = '11.10.8.6';
const tiebaVersionV12 = '12.52.1.0';
const tiebaVersionV22 = '22.10.1.0';

/// CommonRequest shared by every protobuf endpoint.
Uint8List encodeCommonRequest({
  required TiebaDevice device,
  String clientVersion = tiebaVersionV12,
  String bduss = '',
  String stoken = '',
  String tbs = '',
  String zid = '',
  bool isPost = false,
}) {
  final writer = ProtoWriter();
  writer.int32(1, 2);
  writer.string(2, clientVersion);
  writer.string(3, device.clientId);
  writer.string(5, device.imei);
  writer.string(6, clientVersion == tiebaVersionV11 ? '1024324o' : '1020031h');
  writer.string(7, device.newCuidValue);
  writer.int64(8, DateTime.now().millisecondsSinceEpoch);
  writer.string(9, device.model);
  if (bduss.isNotEmpty) writer.string(10, bduss);
  if (tbs.isNotEmpty && clientVersion != tiebaVersionV22) writer.string(11, tbs);
  writer.int32(12, 1);
  writer.string(24, '1.0.3');
  writer.string(25, device.osVersion);
  writer.string(26, device.brand);
  writer.string(28, '3.0.0');
  if (isPost) writer.string(29, '', true);
  if (stoken.isNotEmpty) writer.string(30, stoken);
  if (zid.isNotEmpty) writer.string(31, zid);
  writer.string(32, device.newCuidValue);
  writer.string(33, '', true);
  writer.string(34, clientVersion == tiebaVersionV11 ? device.oaidJson : '', clientVersion != tiebaVersionV11);
  writer.string(35, device.c3Aid);
  if (device.sampleId.isNotEmpty) writer.string(36, device.sampleId);

  if (clientVersion != tiebaVersionV11) {
    writer.int32(37, device.screenWidth);
    writer.int32(38, device.screenHeight);
    writer.doubleValue(39, device.screenDensity);
    writer.int32(40, 0, true);
    writer.int32(41, 0, true);
    if (clientVersion == tiebaVersionV22) {
      writer.string(42, '3.36.0');
      writer.string(43, '4220001');
      writer.string(44, '2035000');
    } else {
      writer.string(42, '2.34.0');
      writer.string(43, '3340042');
      writer.string(44, '1038000');
    }
    writer.int64(49, device.activeTimestamp);
    writer.int64(50, device.firstInstallTime);
    writer.int64(51, device.lastUpdateTime);
    writer.string(53, device.eventDay);
    writer.string(54, isPost ? device.androidId : device.base64AndroidIdValue);
    writer.int32(55, 1);
    writer.string(56, '', true);
    writer.int32(57, 1);
    writer.string(61, '', true);
    writer.string(62, device.webUserAgent('tieba/$clientVersion'));
    writer.int32(63, 1);
    if (isPost) writer.string(70, device.deviceScore);
  } else {
    writer.int32(41, 0, true);
  }
  return writer.toBytes();
}

Uint8List encodeGetUserInfoRequest({
  required TiebaDevice device,
  required int uid,
  String bduss = '',
  String stoken = '',
  String zid = '',
}) {
  final writer = ProtoWriter();
  writer.message(1, encodeCommonRequest(
    device: device,
    clientVersion: tiebaVersionV12,
    bduss: bduss,
    stoken: stoken,
    zid: zid,
  ));
  writer.int64(2, uid);
  writer.int32(3, device.screenWidth);
  final outer = ProtoWriter();
  outer.message(1, writer.toBytes(), true);
  return outer.toBytes();
}

({Uint8List data, int errorCode, String errorMsg}) unwrapResponse(Uint8List bytes) {
  var errorCode = 0;
  var errorMsg = '';
  var userMsg = '';
  var data = Uint8List(0);
  ProtoReader(bytes).forEachField((tag, wire, reader) {
    if (tag == 1 && wire == wireLen) {
      reader.readSubReader().forEachField((innerTag, innerWire, inner) {
        if (innerTag == 1 && innerWire == wireVarint) {
          errorCode = inner.readInt32();
          return true;
        }
        if (innerTag == 2 && innerWire == wireLen) {
          errorMsg = inner.readString();
          return true;
        }
        if (innerTag == 3 && innerWire == wireLen) {
          userMsg = inner.readString();
          return true;
        }
        return false;
      });
      return true;
    }
    if (tag == 2 && wire == wireLen) {
      data = reader.readBytes();
      return true;
    }
    return false;
  });
  return (data: data, errorCode: errorCode, errorMsg: userMsg.isNotEmpty ? userMsg : errorMsg);
}

Map<String, dynamic> decodeUser(ProtoReader reader) {
  final user = <String, dynamic>{
    'id': 0,
    'name': '',
    'nameShow': '',
    'portrait': '',
    'levelId': 0,
    'levelName': '',
    'isBawu': false,
    'bawuType': '',
    'ipAddress': '',
    'tiebaUid': '',
    'sex': 0,
    'intro': '',
    'fansNum': 0,
    'concernNum': 0,
    'postNum': 0,
    'threadNum': 0,
    'myLikeNum': 0,
    'totalAgreeNum': 0,
    'hasConcerned': false,
    'isFans': false,
    'tbAge': '',
    'bgPic': '',
    'isDefaultAvatar': false,
  };
  reader.forEachField((tag, wire, r) {
    switch (tag) {
      case 2:
        user['id'] = r.readInt64();
        return true;
      case 3:
        user['name'] = r.readString();
        return true;
      case 4:
        user['nameShow'] = r.readString();
        return true;
      case 5:
        user['portrait'] = r.readString();
        return true;
      case 23:
        user['levelId'] = r.readInt32();
        return true;
      case 25:
        user['isBawu'] = r.readInt32() != 0;
        return true;
      case 26:
        user['bawuType'] = r.readString();
        return true;
      case 30:
        user['fansNum'] = r.readInt32();
        return true;
      case 31:
        user['concernNum'] = r.readInt32();
        return true;
      case 32:
        user['sex'] = r.readInt32();
        return true;
      case 33:
        user['myLikeNum'] = r.readInt32();
        return true;
      case 34:
        user['intro'] = r.readString();
        return true;
      case 35:
        user['hasConcerned'] = r.readInt32() != 0;
        return true;
      case 37:
        user['postNum'] = r.readInt32();
        return true;
      case 38:
        user['tbAge'] = r.readString();
        return true;
      case 42:
        if (user['sex'] == 0) {
          user['sex'] = r.readInt32();
        } else {
          r.skip(wireVarint);
        }
        return true;
      case 58:
        user['bgPic'] = r.readString();
        return true;
      case 87:
        user['threadNum'] = r.readInt32();
        return true;
      case 91:
        user['isFans'] = r.readInt32() != 0;
        return true;
      case 106:
        user['isDefaultAvatar'] = r.readInt32() != 0;
        return true;
      case 118:
        user['totalAgreeNum'] = r.readUint32();
        return true;
      case 120:
        user['tiebaUid'] = r.readString();
        return true;
      case 125:
        user['levelName'] = r.readString();
        return true;
      case 127:
        user['ipAddress'] = r.readString();
        return true;
      default:
        return false;
    }
  });
  return user;
}

Map<String, dynamic>? decodeUserInfoData(Uint8List data) {
  Map<String, dynamic>? user;
  ProtoReader(data).forEachField((tag, wire, reader) {
    if (tag == 1 && wire == wireLen) {
      user = decodeUser(reader.readSubReader());
      return true;
    }
    return false;
  });
  return user;
}

Uint8List encodeProfileRequest({
  required TiebaDevice device,
  int selfUid = 0,
  int targetUid = 0,
  String targetPortrait = '',
  int page = 1,
  String bduss = '',
  String stoken = '',
  String tbs = '',
  String zid = '',
}) {
  final isGuest = targetUid > 0 && targetUid != selfUid;
  final writer = ProtoWriter();
  if (selfUid > 0) writer.int64(1, selfUid);
  writer.uint32(2, 1);
  if (targetUid > 0) writer.int64(3, targetUid);
  writer.uint32(4, isGuest ? 1 : 0, true);
  writer.uint32(6, page);
  writer.uint32(7, 20);
  writer.uint32(8, 1);
  writer.message(9, encodeCommonRequest(
    device: device,
    clientVersion: tiebaVersionV12,
    bduss: bduss,
    stoken: stoken,
    tbs: tbs,
    zid: zid,
  ));
  writer.uint32(10, device.screenWidth);
  writer.uint32(11, device.screenHeight);
  writer.uint32(12, 0, true);
  writer.doubleValue(13, device.screenDensity);
  writer.int32(14, 1);
  writer.int32(15, page);
  if (targetPortrait.isNotEmpty) writer.string(16, targetPortrait);
  return wrapRequestData(writer.toBytes());
}

({Map<String, dynamic>? user, String tbs}) decodeProfileData(Uint8List data) {
  Map<String, dynamic>? user;
  var tbs = '';
  ProtoReader(data).forEachField((tag, wire, reader) {
    if (tag == 1 && wire == wireLen) {
      user = decodeUser(reader.readSubReader());
      return true;
    }
    if (tag == 2 && wire == wireLen) {
      final anti = reader.readSubReader();
      anti.forEachField((innerTag, innerWire, inner) {
        if (innerTag == 1 && innerWire == wireLen) {
          tbs = inner.readString();
          return true;
        }
        return false;
      });
      return true;
    }
    return false;
  });
  return (user: user, tbs: tbs);
}

Uint8List encodeAppPosInfo() {
  final writer = ProtoWriter();
  writer.string(1, '02:00:00:00:00:00');
  writer.boolean(2, true);
  writer.string(3, 'BD09LL');
  writer.int64(6, 0, true);
  writer.string(7, '', true);
  return writer.toBytes();
}

Uint8List encodePersonalizedRequest({
  required TiebaDevice device,
  int loadType = 1,
  int page = 1,
  String bduss = '',
  String stoken = '',
  String tbs = '',
  String zid = '',
}) {
  final writer = ProtoWriter();
  writer.message(1, encodeCommonRequest(
    device: device,
    clientVersion: tiebaVersionV12,
    bduss: bduss,
    stoken: stoken,
    tbs: tbs,
    zid: zid,
  ));
  writer.uint32(2, 0, true);
  writer.uint32(3, 0, true);
  writer.uint32(4, loadType);
  writer.uint32(5, 15);
  writer.uint32(6, page);
  writer.uint32(7, 0, true);
  writer.int32(8, device.screenWidth);
  writer.int32(9, device.screenHeight);
  writer.doubleValue(10, device.screenDensity);
  writer.int32(11, 1);
  writer.uint32(22, 0, true);
  writer.uint32(23, 1);
  writer.int32(26, 0, true);
  writer.int32(27, 0, true);
  writer.int32(28, 0, true);
  writer.message(36, encodeAppPosInfo());
  return wrapRequestData(writer.toBytes());
}

Uint8List encodeHotThreadListRequest({
  required TiebaDevice device,
  String tabCode = 'all',
  String tabId = '1',
  String bduss = '',
  String stoken = '',
}) {
  final writer = ProtoWriter();
  writer.message(1, encodeCommonRequest(
    device: device,
    clientVersion: tiebaVersionV11,
    bduss: bduss,
    stoken: stoken,
  ));
  writer.string(2, tabId.isEmpty ? '1' : tabId);
  writer.string(3, tabCode.isEmpty ? 'all' : tabCode);
  return wrapRequestData(writer.toBytes());
}

Map<String, dynamic>? _decodeMediaLite(ProtoReader reader) {
  var type = 0;
  var bigPic = '';
  var srcPic = '';
  var width = 0;
  var height = 0;
  var originPic = '';
  reader.forEachField((tag, wire, r) {
    switch (tag) {
      case 1:
        type = r.readInt32();
        return true;
      case 3:
        bigPic = r.readString();
        return true;
      case 8:
        srcPic = r.readString();
        return true;
      case 10:
        width = r.readUint32();
        return true;
      case 11:
        height = r.readUint32();
        return true;
      case 15:
        originPic = r.readString();
        return true;
      default:
        return false;
    }
  });
  if (type != 3 && type != 20 && srcPic.isEmpty && bigPic.isEmpty && originPic.isEmpty) {
    return null;
  }
  final display = bigPic.isNotEmpty ? bigPic : (srcPic.isNotEmpty ? srcPic : originPic);
  if (display.isEmpty) return null;
  return {
    'url': display,
    'big': originPic.isNotEmpty ? originPic : (bigPic.isNotEmpty ? bigPic : srcPic),
    'width': width,
    'height': height,
  };
}

Map<String, dynamic> decodeThreadLite(ProtoReader reader) {
  final item = <String, dynamic>{
    'id': 0,
    'tid': 0,
    'title': '',
    'replyCount': 0,
    'viewCount': 0,
    'agreeCount': 0,
    'authorId': 0,
    'author': null,
    'forumId': 0,
    'forumName': '',
    'createTime': 0,
    'lastTimeInt': 0,
    'hotNum': 0,
    'isLive': false,
    'abstractText': '',
    'images': <Map<String, dynamic>>[],
  };
  reader.forEachField((tag, wire, r) {
    switch (tag) {
      case 1:
        item['id'] = r.readInt64();
        return true;
      case 2:
        item['tid'] = r.readInt64();
        return true;
      case 3:
        item['title'] = r.readString();
        return true;
      case 4:
        item['replyCount'] = r.readInt32();
        return true;
      case 5:
        item['viewCount'] = r.readInt32();
        return true;
      case 7:
        item['lastTimeInt'] = r.readInt32();
        return true;
      case 18:
        item['author'] = decodeUser(r.readSubReader());
        return true;
      case 21:
        final sub = r.readSubReader();
        sub.forEachField((innerTag, innerWire, inner) {
          if (innerTag == 2 && innerWire == wireLen) {
            item['abstractText'] = '${item['abstractText']}${inner.readString()}';
            return true;
          }
          return false;
        });
        return true;
      case 22:
        final media = _decodeMediaLite(r.readSubReader());
        if (media != null) {
          (item['images'] as List<Map<String, dynamic>>).add(media);
        }
        return true;
      case 27:
        item['forumId'] = r.readInt64();
        return true;
      case 28:
        item['forumName'] = r.readString();
        return true;
      case 45:
        item['createTime'] = r.readInt32();
        return true;
      case 56:
        item['authorId'] = r.readInt64();
        return true;
      case 113:
        final bytes = r.readBytes();
        if (bytes.isNotEmpty) item['isLive'] = true;
        return true;
      case 124:
        item['agreeCount'] = r.readInt32();
        return true;
      case 126:
        final sub = r.readSubReader();
        sub.forEachField((innerTag, innerWire, inner) {
          if (innerTag == 1 && innerWire == wireVarint) {
            item['agreeCount'] = inner.readInt64();
            return true;
          }
          return false;
        });
        return true;
      case 155:
        final sub = r.readSubReader();
        var forumId = 0;
        var forumName = '';
        sub.forEachField((innerTag, innerWire, inner) {
          if (innerTag == 1 && innerWire == wireVarint) {
            forumId = inner.readInt64();
            return true;
          }
          if (innerTag == 2 && innerWire == wireLen) {
            forumName = inner.readString();
            return true;
          }
          return false;
        });
        if (item['forumId'] == 0) item['forumId'] = forumId;
        if ('${item['forumName']}'.isEmpty) item['forumName'] = forumName;
        return true;
      case 182:
        item['hotNum'] = r.readInt32();
        return true;
      default:
        return false;
    }
  });
  if (item['tid'] == 0) item['tid'] = item['id'];
  final author = item['author'];
  if (item['authorId'] == 0 && author is Map) item['authorId'] = author['id'] ?? 0;
  return item;
}

List<Map<String, dynamic>> decodePersonalizedData(Uint8List data) {
  final threads = <Map<String, dynamic>>[];
  ProtoReader(data).forEachField((tag, wire, reader) {
    if (tag == 2 && wire == wireLen) {
      final thread = decodeThreadLite(reader.readSubReader());
      if (thread['isLive'] != true) threads.add(thread);
      return true;
    }
    return false;
  });
  return threads;
}

({int id, String name, int discuss}) _decodeRecommendTopic(ProtoReader reader) {
  var id = 0;
  var name = '';
  var discuss = 0;
  reader.forEachField((tag, wire, r) {
    switch (tag) {
      case 1:
        id = r.readInt64();
        return true;
      case 2:
        name = r.readString();
        return true;
      case 4:
        discuss = r.readInt64();
        return true;
      default:
        return false;
    }
  });
  return (id: id, name: name, discuss: discuss);
}

({int id, String name, String code}) _decodeHotTab(ProtoReader reader) {
  var id = 0;
  var name = '';
  var code = '';
  reader.forEachField((tag, wire, r) {
    switch (tag) {
      case 1:
        id = r.readInt32();
        return true;
      case 3:
        name = r.readString();
        return true;
      case 8:
        code = r.readString();
        return true;
      default:
        return false;
    }
  });
  return (id: id, name: name, code: code);
}

({
  List<({int id, String name, int discuss})> topics,
  List<Map<String, dynamic>> threads,
  List<({int id, String name, String code})> tabs,
}) decodeHotThreadListData(Uint8List data) {
  final topics = <({int id, String name, int discuss})>[];
  final threads = <Map<String, dynamic>>[];
  final tabs = <({int id, String name, String code})>[];
  ProtoReader(data).forEachField((tag, wire, reader) {
    if (tag == 1 && wire == wireLen) {
      topics.add(_decodeRecommendTopic(reader.readSubReader()));
      return true;
    }
    if (tag == 2 && wire == wireLen) {
      final thread = decodeThreadLite(reader.readSubReader());
      if (thread['isLive'] != true) threads.add(thread);
      return true;
    }
    if (tag == 3 && wire == wireLen) {
      tabs.add(_decodeHotTab(reader.readSubReader()));
      return true;
    }
    return false;
  });
  return (
    topics: topics.where((item) => item.id != 0 && item.name.isNotEmpty).toList(),
    threads: threads,
    tabs: tabs.where((item) => item.name.isNotEmpty && item.code.isNotEmpty).toList(),
  );
}

Uint8List wrapRequestData(List<int> bytes) {
  final outer = ProtoWriter();
  outer.message(1, bytes, true);
  return outer.toBytes();
}

Uint8List encodeAddPostRequest({
  required TiebaDevice device,
  required int forumId,
  required String forumName,
  required int threadId,
  required String content,
  required String tbs,
  String bduss = '',
  String stoken = '',
  String zid = '',
  String nameShow = '',
  int quotePostId = 0,
  int subPostId = 0,
  int replyUid = 0,
}) {
  final writer = ProtoWriter();
  writer.message(1, encodeCommonRequest(
    device: device,
    clientVersion: tiebaVersionV12,
    bduss: bduss,
    stoken: stoken,
    tbs: tbs,
    zid: zid,
    isPost: true,
  ));
  writer.string(4, tbs);
  writer.string(6, '1');
  writer.string(7, '0');
  writer.string(8, '0');
  writer.string(9, '0');
  writer.string(10, '0');
  writer.string(16, '12');
  writer.string(18, '1');
  writer.string(19, content);
  if (replyUid > 0) writer.string(20, '$replyUid');
  writer.string(26, '$forumId');
  writer.string(28, '', true);
  writer.string(29, '', true);
  writer.string(30, forumName);
  writer.string(31, '0');
  writer.string(32, '0');
  writer.string(45, '$threadId');
  if (quotePostId > 0) {
    writer.string(46, '$quotePostId');
    writer.string(49, '$quotePostId');
  }
  writer.string(47, '0');
  writer.string(48, '0');
  if (subPostId > 0) writer.string(50, '$subPostId');
  writer.string(51, '0');
  writer.string(52, '0');
  writer.string(53, '0');
  if (subPostId <= 0) writer.string(55, quotePostId > 0 ? '0' : '13');
  if (nameShow.isNotEmpty) writer.string(58, nameShow);
  writer.string(60, '0');
  writer.int32(64, 0, true);
  writer.int32(67, 0, true);
  return wrapRequestData(writer.toBytes());
}

Uint8List encodeAddThreadRequest({
  required TiebaDevice device,
  required int forumId,
  required String forumName,
  required String title,
  required String content,
  required String tbs,
  String bduss = '',
  String stoken = '',
  String zid = '',
  String nameShow = '',
}) {
  final writer = ProtoWriter();
  writer.message(1, encodeCommonRequest(
    device: device,
    clientVersion: tiebaVersionV12,
    bduss: bduss,
    stoken: stoken,
    tbs: tbs,
    zid: zid,
    isPost: true,
  ));
  writer.string(4, tbs);
  writer.string(6, '1');
  writer.string(7, '0');
  writer.string(8, '0');
  writer.string(9, '0');
  writer.string(10, '0');
  writer.string(16, '12');
  writer.string(18, '1');
  writer.string(19, content);
  writer.string(26, '$forumId');
  writer.string(27, forumName);
  writer.string(29, '1');
  writer.string(38, title);
  writer.string(41, title.trim().isNotEmpty ? '0' : '1');
  if (nameShow.isNotEmpty) writer.string(75, nameShow);
  writer.string(77, '0');
  writer.int32(80, 0, true);
  writer.int32(87, 0, true);
  return wrapRequestData(writer.toBytes());
}