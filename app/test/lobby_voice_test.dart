import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mymemory/voice/lobby_voice.dart';
import 'package:mymemory/voice/voice_engine.dart';

class FakeChannel extends ChangeNotifier implements VoiceChannel {
  @override
  String? playerId = 'a';
  @override
  bool seated = true;
  @override
  int sessionSerial = 1;
  @override
  Map<String, dynamic>? voiceRoster;
  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final sent = <Map<String, dynamic>>[];

  @override
  Stream<Map<String, dynamic>> get voiceMessages => _messages.stream;

  @override
  void send(Map<String, dynamic> action) => sent.add(action);

  List<Map<String, dynamic>> sentOf(String action) =>
      sent.where((m) => m['action'] == action).toList();

  void receive(Map<String, dynamic> message) => _messages.add(message);

  void roster(List<(String, int, bool)> members) => receive({
    'type': 'voice',
    'action': 'state',
    'members': [
      for (final (id, generation, muted) in members)
        {'id': id, 'generation': generation, 'muted': muted},
    ],
  });

  void reconnect() {
    sessionSerial++;
    notifyListeners();
  }

  void drop() {
    seated = false;
    notifyListeners();
  }
}

class FakeLink implements VoiceLink {
  FakeLink(this.onCandidate, this.onState);
  final void Function(Map<String, dynamic>) onCandidate;
  final void Function(VoiceLinkState) onState;
  final accepted = <String>[];
  final candidates = <Map<String, dynamic>>[];
  bool closed = false;
  bool audible = true;

  @override
  Future<Map<String, dynamic>> createOffer() async => {
    'type': 'offer',
    'sdp': 'offer-sdp',
  };
  @override
  Future<Map<String, dynamic>> acceptOffer(Map<String, dynamic> offer) async {
    accepted.add('offer');
    return {'type': 'answer', 'sdp': 'answer-sdp'};
  }

  @override
  Future<void> acceptAnswer(Map<String, dynamic> answer) async =>
      accepted.add('answer');
  @override
  Future<void> addCandidate(Map<String, dynamic> candidate) async =>
      candidates.add(candidate);
  @override
  void setAudible(bool value) => audible = value;
  @override
  Future<void> close() async => closed = true;
}

class FakeEngine implements VoiceEngine {
  bool denied = false, micOpen = false, live = false;
  final links = <FakeLink>[];
  final iceRequests = <List<Map<String, dynamic>>>[];

  @override
  Future<void> openMicrophone() async {
    if (denied) throw StateError('denied');
    micOpen = true;
  }

  @override
  void setMicrophoneLive(bool value) => live = value;
  @override
  Future<void> closeMicrophone() async => micOpen = false;

  @override
  Future<VoiceLink> connect({
    required List<Map<String, dynamic>> iceServers,
    required void Function(Map<String, dynamic> candidate) onCandidate,
    required void Function(VoiceLinkState state) onState,
  }) async {
    iceRequests.add(iceServers);
    final link = FakeLink(onCandidate, onState);
    links.add(link);
    return link;
  }

  List<FakeLink> get open => links.where((l) => !l.closed).toList();
}

const fast = VoiceTimings(
  connect: Duration(milliseconds: 200),
  answererGrace: Duration(milliseconds: 100),
  disconnectGrace: Duration(milliseconds: 100),
  stable: Duration(milliseconds: 150),
  operation: Duration(milliseconds: 500),
  backoff: [Duration.zero, Duration(milliseconds: 50)],
);

Future<void> settle([int ms = 20]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  late FakeChannel channel;
  late FakeEngine engine;
  late LobbyVoice voice;

  setUp(() {
    channel = FakeChannel();
    engine = FakeEngine();
    voice = LobbyVoice(channel, engine: engine, timings: fast);
  });
  tearDown(() async {
    voice.dispose();
    await settle();
  });

  Future<void> joinAs(int generation) async {
    await voice.join();
    channel.roster([('a', generation, false)]);
    await settle();
  }

  test('a refused microphone never reaches the server', () async {
    engine.denied = true;
    await voice.join();
    expect(voice.enabled, isFalse);
    expect(voice.micError, isNotNull);
    expect(channel.sentOf('join'), isEmpty);
    expect(voice.status, VoiceStatus.off);
  });

  test('joining carries the mute state and waits for the roster', () async {
    await voice.join();
    expect(channel.sentOf('join').single['muted'], false);
    expect(voice.status, VoiceStatus.connecting);
    channel.roster([('a', 1, false)]);
    await settle();
    expect(voice.status, VoiceStatus.alone);
  });

  test(
    'the lower id offers, the higher id answers, with generations',
    () async {
      await joinAs(1);
      channel.roster([('a', 1, false), ('b', 2, false)]);
      await settle();
      expect(engine.open, hasLength(1));
      final offer = channel
          .sentOf('signal')
          .firstWhere((m) => m['kind'] == 'offer');
      expect(offer['to'], 'b');
      expect(offer['generation'], 1);
      expect(offer['peerGeneration'], 2);

      // A stale answer from an older generation of b is ignored.
      channel.receive({
        'type': 'voice',
        'action': 'signal',
        'from': 'b',
        'kind': 'answer',
        'generation': 1,
        'peerGeneration': 1,
        'payload': {'type': 'answer', 'sdp': 'x'},
      });
      await settle();
      expect(engine.open.single.accepted, isEmpty);
      channel.receive({
        'type': 'voice',
        'action': 'signal',
        'from': 'b',
        'kind': 'answer',
        'generation': 2,
        'peerGeneration': 1,
        'payload': {'type': 'answer', 'sdp': 'x'},
      });
      await settle();
      expect(engine.open.single.accepted, ['answer']);
    },
  );

  test('the answerer replies to an offer and never offers itself', () async {
    voice.dispose();
    channel = FakeChannel()..playerId = 'b';
    engine = FakeEngine();
    voice = LobbyVoice(channel, engine: engine, timings: fast);
    await voice.join();
    channel.roster([('a', 1, false), ('b', 2, false)]);
    await settle();
    expect(channel.sentOf('signal'), isEmpty);
    channel.receive({
      'type': 'voice',
      'action': 'signal',
      'from': 'a',
      'kind': 'offer',
      'generation': 1,
      'peerGeneration': 2,
      'payload': {'type': 'offer', 'sdp': 'o'},
    });
    await settle();
    expect(channel.sentOf('signal').single['kind'], 'answer');
  });

  test('a rejoining peer gets a fresh link and the old one closes', () async {
    await joinAs(1);
    channel.roster([('a', 1, false), ('b', 2, false)]);
    await settle();
    final first = engine.open.single;
    channel.roster([('a', 1, false), ('b', 5, false)]);
    await settle();
    expect(first.closed, isTrue);
    expect(engine.open, hasLength(1));
    expect(
      channel
          .sentOf('signal')
          .where((m) => m['kind'] == 'offer')
          .last['peerGeneration'],
      5,
    );
  });

  test(
    'a link that never connects is rebuilt by joining again, then gives up',
    () async {
      await joinAs(1);
      channel.roster([('a', 1, false), ('b', 2, false)]);
      await settle();
      expect(channel.sentOf('join'), hasLength(1));
      await settle(260);
      expect(channel.sentOf('join'), hasLength(2));
      // The server answers each join with a new generation.
      channel.roster([('a', 3, false), ('b', 2, false)]);
      await settle(260);
      expect(channel.sentOf('join'), hasLength(3));
      channel.roster([('a', 4, false), ('b', 2, false)]);
      await settle(260);
      expect(voice.status, VoiceStatus.unreachable);
      final joins = channel.sentOf('join').length;
      await settle(300);
      expect(channel.sentOf('join'), hasLength(joins));
    },
  );

  test('a brief interruption heals without rebuilding', () async {
    await joinAs(1);
    channel.roster([('a', 1, false), ('b', 2, false)]);
    await settle();
    final link = engine.open.single;
    link.onState(VoiceLinkState.connected);
    await settle();
    expect(voice.status, VoiceStatus.live);
    link.onState(VoiceLinkState.disconnected);
    await settle(40);
    link.onState(VoiceLinkState.connected);
    await settle(200);
    expect(channel.sentOf('join'), hasLength(1));
    expect(voice.status, VoiceStatus.live);
  });

  test('a new room connection rejoins with its own roster', () async {
    await joinAs(1);
    channel.roster([('a', 1, false), ('b', 2, false)]);
    await settle();
    channel.drop();
    await settle();
    expect(engine.open, isEmpty);
    expect(voice.members, isEmpty);
    channel.seated = true;
    channel.reconnect();
    await settle();
    expect(channel.sentOf('join'), hasLength(2));
    expect(voice.enabled, isTrue);
    expect(engine.micOpen, isTrue);
  });

  test(
    'mute and background silence the microphone and tell the room',
    () async {
      await joinAs(1);
      voice.toggleMute();
      expect(engine.live, isFalse);
      expect(channel.sentOf('mute').last['muted'], true);
      voice.toggleMute();
      expect(engine.live, isTrue);
      voice.setForeground(false);
      expect(engine.live, isFalse);
      expect(channel.sentOf('mute').last['muted'], true);
      voice.setForeground(true);
      expect(channel.sentOf('mute').last['muted'], false);
    },
  );

  test('leaving releases the microphone and every link', () async {
    await joinAs(1);
    channel.roster([('a', 1, false), ('b', 2, false)]);
    await settle();
    await voice.leave();
    await settle();
    expect(channel.sentOf('leave'), hasLength(1));
    expect(engine.micOpen, isFalse);
    expect(engine.open, isEmpty);
    expect(voice.status, VoiceStatus.off);
  });

  test(
    'being dropped from the roster rejoins a bounded number of times',
    () async {
      await joinAs(1);
      for (var i = 0; i < 12; i++) {
        // The server confirms the join, then drops the seat again.
        channel.roster([('a', 10 + i, false)]);
        await settle(5);
        channel.roster([('b', 2, false)]);
        await settle(5);
      }
      expect(channel.sentOf('join').length, lessThanOrEqualTo(8));
      expect(voice.enabled, isFalse);
      expect(voice.micError, isNotNull);
    },
  );

  test('ICE servers from the service replace the built-in fallback', () async {
    await voice.join();
    channel.receive({
      'type': 'voice',
      'action': 'config',
      'iceServers': [
        {
          'urls': ['turn:t.example.org'],
          'username': 'u',
          'credential': 'c',
        },
      ],
    });
    channel.roster([('a', 1, false), ('b', 2, false)]);
    await settle();
    expect(engine.iceRequests.single.single['username'], 'u');
  });
}
