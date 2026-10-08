/// XP levels, daily goal and points for the learning games.
library;

import 'dart:math';

/// XP needed to reach each level (level 1 starts at 0).
const List<int> kLevelXp = [0, 100, 250, 500, 850, 1300, 1900, 2700, 3700, 5000];

/// XP to earn each day for the daily goal.
const int kDailyGoalXp = 50;

/// XP per answer.
const int kXpCorrect = 10;
const int kXpFlashKnew = 5;
const int kXpFlashTried = 2;

class LevelInfo {
  const LevelInfo(this.level, this.floor, this.next);

  /// 1-based level.
  final int level;

  /// XP at the start of this level, and of the next (null at the top).
  final int floor;
  final int? next;

  /// 0..1 progress to the next level.
  double progress(int xp) => next == null ? 1 : ((xp - floor) / (next! - floor)).clamp(0, 1).toDouble();

  /// Title index: 0 Beginner … 5 Master.
  int get rank => min(5, (level - 1) ~/ 2);
}

LevelInfo levelFor(int xp) {
  var i = 0;
  while (i + 1 < kLevelXp.length && xp >= kLevelXp[i + 1]) {
    i++;
  }
  return LevelInfo(i + 1, kLevelXp[i], i + 1 < kLevelXp.length ? kLevelXp[i + 1] : null);
}

/// Speed sort: points for a correct answer with [combo] correct answers in a
/// row before it (×1, then ×2 from 3 in a row … up to ×5).
int comboMultiplier(int combo) => min(5, 1 + combo ~/ 3);

int speedPoints(int combo) => 10 * comboMultiplier(combo);
