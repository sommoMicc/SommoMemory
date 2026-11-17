import 'package:flutter_test/flutter_test.dart';
import 'package:mymemory/online.dart';

Map<String, dynamic> preview(int n, {List<String>? winners}) => {
  'code': 'ABCDEF',
  'phase': 'finished',
  'finishReason': 'completed',
  'winnerId': winners?.length == 1 ? winners!.first : null,
  'winnerIds': winners ?? <String>[],
  'players': [
    for (var i = 0; i < n; i++)
      {'id': 'p$i', 'name': 'P$i', 'score': i, 'connected': true},
  ],
};

void main() {
  test('a preview accepts up to eight distinct players and shared winners', () {
    final shared = RoomPreview.fromJson(preview(8, winners: ['p6', 'p7']));
    expect(shared.players, hasLength(8));
    expect(shared.winnerIds, ['p6', 'p7']);
    expect(shared.winnerId, isNull);
    expect(RoomPreview.fromJson(preview(3, winners: ['p2'])).winnerId, 'p2');
  });

  test('a preview rejects one, nine or unknown-winner rosters', () {
    expect(() => RoomPreview.fromJson(preview(1)), throwsFormatException);
    expect(() => RoomPreview.fromJson(preview(9)), throwsFormatException);
    expect(
      () => RoomPreview.fromJson(preview(3, winners: ['ghost'])),
      throwsFormatException,
    );
  });
}
