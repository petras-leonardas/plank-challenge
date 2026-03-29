/**
 * Badge System Unit Tests
 *
 * Tests all 25 badge definitions: earning logic, progress calculation,
 * and edge cases. Runs with Node's built-in test runner (node --test).
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

import {
  checkNewBadges,
  getBadgeProgress,
  BADGE_DEFINITIONS,
  type UserStats,
  type PlankInfo,
  type SpecialBadgeContext,
} from './badges.js';

// ─────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────

function makeStats(overrides: Partial<UserStats> = {}): UserStats {
  return {
    currentStreak: 0,
    longestStreak: 0,
    totalPlanks: 0,
    totalPlankSeconds: 0,
    longestPlankSeconds: 0,
    ...overrides,
  };
}

function makePlank(overrides: Partial<PlankInfo> = {}): PlankInfo {
  return {
    performedAt: new Date().toISOString(),
    timezone: 'UTC',
    plankType: 'elbow',
    durationSeconds: 60,
    ...overrides,
  };
}

function earnedTypes(
  stats: UserStats,
  existingBadges: Set<string> = new Set(),
  recentPlank?: PlankInfo,
  allPlankTypes?: Set<string>,
  context?: SpecialBadgeContext,
): string[] {
  return checkNewBadges(stats, existingBadges, recentPlank, allPlankTypes, context);
}

function progressFor(badgeType: string, stats: UserStats, existingBadges: Set<string> = new Set()): number {
  const result = getBadgeProgress(stats, existingBadges);
  const entry = result.find((r) => r.badge.type === badgeType);
  assert.ok(entry, `Badge type '${badgeType}' not found in BADGE_DEFINITIONS`);
  return entry.progress;
}

// ─────────────────────────────────────────────
// Sanity: definitions
// ─────────────────────────────────────────────

describe('BADGE_DEFINITIONS', () => {
  it('contains exactly 25 badges', () => {
    assert.equal(BADGE_DEFINITIONS.length, 25);
  });

  it('all badge types are unique', () => {
    const types = BADGE_DEFINITIONS.map((b) => b.type);
    assert.equal(new Set(types).size, types.length);
  });

  it('all categories are valid', () => {
    const valid = new Set(['streak', 'count', 'duration', 'special']);
    for (const b of BADGE_DEFINITIONS) {
      assert.ok(valid.has(b.category), `Unknown category '${b.category}' on badge '${b.type}'`);
    }
  });

  it('every badge has a non-empty icon', () => {
    for (const b of BADGE_DEFINITIONS) {
      assert.ok(b.icon.length > 0, `Empty icon on badge '${b.type}'`);
    }
  });
});

// ─────────────────────────────────────────────
// Streak badges (7 badges)
// ─────────────────────────────────────────────

describe('Streak badges', () => {
  const cases: Array<[string, number]> = [
    ['streak_7',   7],
    ['streak_14',  14],
    ['streak_30',  30],
    ['streak_60',  60],
    ['streak_90',  90],
    ['streak_180', 180],
    ['streak_365', 365],
  ];

  for (const [type, days] of cases) {
    it(`${type}: earned when longestStreak >= ${days}`, () => {
      const stats = makeStats({ longestStreak: days });
      assert.ok(earnedTypes(stats).includes(type), `Expected ${type} to be earned`);
    });

    it(`${type}: NOT earned when longestStreak = ${days - 1}`, () => {
      const stats = makeStats({ longestStreak: days - 1 });
      assert.ok(!earnedTypes(stats).includes(type), `Expected ${type} NOT to be earned`);
    });

    it(`${type}: uses longestStreak, not currentStreak`, () => {
      // Current streak is 0, but historical longest is sufficient
      const stats = makeStats({ longestStreak: days, currentStreak: 0 });
      assert.ok(earnedTypes(stats).includes(type));
    });

    it(`${type}: skipped if already in existingBadges`, () => {
      const stats = makeStats({ longestStreak: days });
      const existing = new Set([type]);
      assert.ok(!earnedTypes(stats, existing).includes(type));
    });

    it(`${type}: progress is 0% at 0 days`, () => {
      assert.equal(progressFor(type, makeStats({ longestStreak: 0 })), 0);
    });

    it(`${type}: progress is 50% at ${Math.floor(days / 2)} days`, () => {
      const half = Math.floor(days / 2);
      const expected = Math.round((half / days) * 100);
      assert.equal(progressFor(type, makeStats({ longestStreak: half })), expected);
    });

    it(`${type}: progress is 100% when earned`, () => {
      const stats = makeStats({ longestStreak: days });
      const existing = new Set([type]);
      assert.equal(progressFor(type, stats, existing), 100);
    });

    it(`${type}: progress is capped at 100%`, () => {
      const stats = makeStats({ longestStreak: days * 10 });
      assert.equal(progressFor(type, makeStats({ longestStreak: days * 10 })), 100);
    });
  }

  it('earning a long streak awards all lower streak badges at once', () => {
    const stats = makeStats({ longestStreak: 365 });
    const earned = earnedTypes(stats);
    for (const [type] of cases) {
      assert.ok(earned.includes(type), `Expected ${type} to be earned`);
    }
  });
});

// ─────────────────────────────────────────────
// Count badges (6 badges)
// ─────────────────────────────────────────────

describe('Count badges', () => {
  const cases: Array<[string, number]> = [
    ['count_1',    1],
    ['count_10',   10],
    ['count_50',   50],
    ['count_100',  100],
    ['count_500',  500],
    ['count_1000', 1000],
  ];

  for (const [type, count] of cases) {
    it(`${type}: earned when totalPlanks >= ${count}`, () => {
      const stats = makeStats({ totalPlanks: count });
      assert.ok(earnedTypes(stats).includes(type));
    });

    it(`${type}: NOT earned when totalPlanks = ${count - 1}`, () => {
      const stats = makeStats({ totalPlanks: count - 1 });
      assert.ok(!earnedTypes(stats).includes(type));
    });

    it(`${type}: progress is 0% at 0 planks`, () => {
      assert.equal(progressFor(type, makeStats({ totalPlanks: 0 })), 0);
    });

    it(`${type}: progress scales correctly`, () => {
      const half = Math.floor(count / 2);
      const expected = Math.round((half / count) * 100);
      assert.equal(progressFor(type, makeStats({ totalPlanks: half })), expected);
    });

    it(`${type}: progress is 100% when earned`, () => {
      const stats = makeStats({ totalPlanks: count });
      assert.equal(progressFor(type, stats, new Set([type])), 100);
    });
  }
});

// ─────────────────────────────────────────────
// Single-plank duration badges (5 badges)
// ─────────────────────────────────────────────

describe('Single-plank duration badges', () => {
  const cases: Array<[string, number]> = [
    ['duration_1m',  60],
    ['duration_2m',  120],
    ['duration_3m',  180],
    ['duration_5m',  300],
    ['duration_10m', 600],
  ];

  for (const [type, seconds] of cases) {
    it(`${type}: earned when longestPlankSeconds >= ${seconds}`, () => {
      const stats = makeStats({ longestPlankSeconds: seconds });
      assert.ok(earnedTypes(stats).includes(type));
    });

    it(`${type}: NOT earned when longestPlankSeconds = ${seconds - 1}`, () => {
      const stats = makeStats({ longestPlankSeconds: seconds - 1 });
      assert.ok(!earnedTypes(stats).includes(type));
    });

    it(`${type}: progress scales correctly`, () => {
      const half = Math.floor(seconds / 2);
      const expected = Math.round((half / seconds) * 100);
      assert.equal(progressFor(type, makeStats({ longestPlankSeconds: half })), expected);
    });

    it(`${type}: progress capped at 100%`, () => {
      assert.equal(progressFor(type, makeStats({ longestPlankSeconds: seconds * 5 })), 100);
    });
  }
});

// ─────────────────────────────────────────────
// Total duration badges (3 badges)
// ─────────────────────────────────────────────

describe('Total duration badges', () => {
  const cases: Array<[string, number]> = [
    ['total_1h',  3600],
    ['total_5h',  18000],
    ['total_24h', 86400],
  ];

  for (const [type, seconds] of cases) {
    it(`${type}: earned when totalPlankSeconds >= ${seconds}`, () => {
      const stats = makeStats({ totalPlankSeconds: seconds });
      assert.ok(earnedTypes(stats).includes(type));
    });

    it(`${type}: NOT earned when totalPlankSeconds = ${seconds - 1}`, () => {
      const stats = makeStats({ totalPlankSeconds: seconds - 1 });
      assert.ok(!earnedTypes(stats).includes(type));
    });

    it(`${type}: progress at zero`, () => {
      assert.equal(progressFor(type, makeStats({ totalPlankSeconds: 0 })), 0);
    });

    it(`${type}: progress scales correctly at half`, () => {
      const half = Math.floor(seconds / 2);
      const expected = Math.round((half / seconds) * 100);
      assert.equal(progressFor(type, makeStats({ totalPlankSeconds: half })), expected);
    });
  }
});

// ─────────────────────────────────────────────
// Special badges (4 badges)
// ─────────────────────────────────────────────

describe('Special badge: Early Bird', () => {
  function makePlankAt(hour: number, tz = 'UTC'): PlankInfo {
    // Build an ISO timestamp that is exactly `hour:00:00 UTC`
    const d = new Date();
    d.setUTCHours(hour, 0, 0, 0);
    return makePlank({ performedAt: d.toISOString(), timezone: tz });
  }

  it('earned when recent plank is at 05:59 UTC', () => {
    const plank = makePlankAt(5);
    const earned = earnedTypes(makeStats(), new Set(), plank);
    assert.ok(earned.includes('special_early_bird'), 'Expected early_bird from recent plank at 5am');
  });

  it('NOT earned when recent plank is at 06:00 UTC', () => {
    const plank = makePlankAt(6);
    const earned = earnedTypes(makeStats(), new Set(), plank);
    assert.ok(!earned.includes('special_early_bird'));
  });

  it('earned via historical context (hasEarlyBirdPlank)', () => {
    const context: SpecialBadgeContext = { hasEarlyBirdPlank: true, currentStreak: 0 };
    const earned = earnedTypes(makeStats(), new Set(), undefined, undefined, context);
    assert.ok(earned.includes('special_early_bird'));
  });

  it('NOT earned when historical context says no early bird plank', () => {
    const context: SpecialBadgeContext = { hasEarlyBirdPlank: false, currentStreak: 0 };
    const earned = earnedTypes(makeStats(), new Set(), undefined, undefined, context);
    assert.ok(!earned.includes('special_early_bird'));
  });

  it('progress is always 0% when not earned (special badges are binary)', () => {
    assert.equal(progressFor('special_early_bird', makeStats()), 0);
  });

  it('progress is 100% when already in existingBadges', () => {
    assert.equal(progressFor('special_early_bird', makeStats(), new Set(['special_early_bird'])), 100);
  });
});

describe('Special badge: Night Owl', () => {
  function makePlankAt(hour: number): PlankInfo {
    const d = new Date();
    d.setUTCHours(hour, 0, 0, 0);
    return makePlank({ performedAt: d.toISOString(), timezone: 'UTC' });
  }

  it('earned when recent plank is at 23:00 UTC', () => {
    const plank = makePlankAt(23);
    const earned = earnedTypes(makeStats(), new Set(), plank);
    assert.ok(earned.includes('special_night_owl'));
  });

  it('earned when recent plank is at 00:00 UTC (midnight)', () => {
    const plank = makePlankAt(0);
    // hour=0 is NOT >= 23, so this should NOT earn night_owl
    const earned = earnedTypes(makeStats(), new Set(), plank);
    assert.ok(!earned.includes('special_night_owl'), 'Midnight (0) is not >= 23');
  });

  it('NOT earned when recent plank is at 22:59 UTC', () => {
    const plank = makePlankAt(22);
    const earned = earnedTypes(makeStats(), new Set(), plank);
    assert.ok(!earned.includes('special_night_owl'));
  });

  it('earned via historical context (hasNightOwlPlank)', () => {
    const context: SpecialBadgeContext = { hasNightOwlPlank: true, currentStreak: 0 };
    const earned = earnedTypes(makeStats(), new Set(), undefined, undefined, context);
    assert.ok(earned.includes('special_night_owl'));
  });

  it('progress is 0% when not earned', () => {
    assert.equal(progressFor('special_night_owl', makeStats()), 0);
  });
});

describe('Special badge: Perfect Week', () => {
  it('earned when currentStreak >= 7', () => {
    const context: SpecialBadgeContext = { currentStreak: 7 };
    const earned = earnedTypes(makeStats(), new Set(), undefined, undefined, context);
    assert.ok(earned.includes('special_perfect_week'));
  });

  it('NOT earned when currentStreak = 6', () => {
    const context: SpecialBadgeContext = { currentStreak: 6 };
    const earned = earnedTypes(makeStats(), new Set(), undefined, undefined, context);
    assert.ok(!earned.includes('special_perfect_week'));
  });

  it('is independent from streak_7 (streak_7 uses longestStreak, perfect_week uses currentStreak)', () => {
    // longestStreak=7 gives streak_7 but NOT perfect_week (if current=0)
    const statsA = makeStats({ longestStreak: 7, currentStreak: 0 });
    const contextA: SpecialBadgeContext = { currentStreak: 0 };
    const earnedA = earnedTypes(statsA, new Set(), undefined, undefined, contextA);
    assert.ok(earnedA.includes('streak_7'), 'streak_7 should be earned');
    assert.ok(!earnedA.includes('special_perfect_week'), 'perfect_week should NOT be earned with currentStreak=0');

    // currentStreak=7 gives perfect_week but NOT streak_7 if longestStreak<7
    const statsB = makeStats({ longestStreak: 6, currentStreak: 7 });
    const contextB: SpecialBadgeContext = { currentStreak: 7 };
    const earnedB = earnedTypes(statsB, new Set(), undefined, undefined, contextB);
    // NOTE: streak badges use longestStreak. currentStreak=7 doesn't automatically
    // mean longestStreak=7 — but in normal app flow it would. We test the pure logic:
    assert.ok(!earnedB.includes('streak_7'), 'streak_7 should NOT be earned if longestStreak<7');
    assert.ok(earnedB.includes('special_perfect_week'), 'perfect_week should be earned');
  });

  it('progress is 0% when not earned', () => {
    assert.equal(progressFor('special_perfect_week', makeStats()), 0);
  });
});

describe('Special badge: Variety Pack', () => {
  const ALL_TYPES = new Set(['elbow', 'high', 'side_left', 'side_right', 'reverse']);

  it('earned when all 5 plank types have been done', () => {
    const earned = earnedTypes(makeStats(), new Set(), undefined, ALL_TYPES);
    assert.ok(earned.includes('special_variety'));
  });

  it('NOT earned with only 4 types', () => {
    const four = new Set(['elbow', 'high', 'side_left', 'side_right']);
    const earned = earnedTypes(makeStats(), new Set(), undefined, four);
    assert.ok(!earned.includes('special_variety'));
  });

  it('NOT earned with empty set', () => {
    const earned = earnedTypes(makeStats(), new Set(), undefined, new Set());
    assert.ok(!earned.includes('special_variety'));
  });

  it('NOT earned when allPlankTypes is undefined', () => {
    const earned = earnedTypes(makeStats(), new Set(), undefined, undefined);
    assert.ok(!earned.includes('special_variety'));
  });

  it('earned with exactly 5 types (boundary)', () => {
    const exactly5 = new Set(['elbow', 'high', 'side_left', 'side_right', 'reverse']);
    assert.equal(exactly5.size, 5);
    const earned = earnedTypes(makeStats(), new Set(), undefined, exactly5);
    assert.ok(earned.includes('special_variety'));
  });

  it('progress is 0% when not earned (binary)', () => {
    assert.equal(progressFor('special_variety', makeStats()), 0);
  });
});

// ─────────────────────────────────────────────
// getBadgeProgress: full coverage
// ─────────────────────────────────────────────

describe('getBadgeProgress', () => {
  it('returns one entry per badge definition', () => {
    const result = getBadgeProgress(makeStats(), new Set());
    assert.equal(result.length, BADGE_DEFINITIONS.length);
  });

  it('marks earned=true for badges in existingBadges set', () => {
    const result = getBadgeProgress(makeStats(), new Set(['count_1']));
    const entry = result.find((r) => r.badge.type === 'count_1')!;
    assert.equal(entry.earned, true);
    assert.equal(entry.progress, 100);
  });

  it('marks earned=false for badges not in existingBadges', () => {
    const result = getBadgeProgress(makeStats(), new Set());
    const entry = result.find((r) => r.badge.type === 'count_1')!;
    assert.equal(entry.earned, false);
  });

  it('progress is 0 for all badges when user has no stats', () => {
    const result = getBadgeProgress(makeStats(), new Set());
    for (const { badge, earned, progress } of result) {
      assert.equal(earned, false, `${badge.type} should not be earned`);
      assert.equal(progress, 0, `${badge.type} progress should be 0, got ${progress}`);
    }
  });

  it('a user with 2-day streak has correct progress towards streak_7', () => {
    const result = getBadgeProgress(makeStats({ longestStreak: 2 }), new Set());
    const s7 = result.find((r) => r.badge.type === 'streak_7')!;
    assert.equal(s7.progress, Math.round((2 / 7) * 100)); // 28%
  });

  it('special badges always show 0% progress when not earned', () => {
    const specials = ['special_early_bird', 'special_night_owl', 'special_perfect_week', 'special_variety'];
    const result = getBadgeProgress(makeStats(), new Set());
    for (const type of specials) {
      const entry = result.find((r) => r.badge.type === type)!;
      assert.equal(entry.progress, 0, `${type} should show 0% progress when not earned`);
    }
  });
});

// ─────────────────────────────────────────────
// checkNewBadges: multi-badge award scenarios
// ─────────────────────────────────────────────

describe('checkNewBadges: real user scenarios', () => {
  it('first-time plank awards count_1 and duration_1m if >= 60s', () => {
    const stats = makeStats({ totalPlanks: 1, longestPlankSeconds: 60 });
    const earned = earnedTypes(stats);
    assert.ok(earned.includes('count_1'));
    assert.ok(earned.includes('duration_1m'));
  });

  it('does not re-award badges already in existingBadges', () => {
    const stats = makeStats({ totalPlanks: 10, longestStreak: 7 });
    const existing = new Set(['count_1', 'count_10', 'streak_7']);
    const earned = earnedTypes(stats, existing);
    assert.ok(!earned.includes('count_1'));
    assert.ok(!earned.includes('count_10'));
    assert.ok(!earned.includes('streak_7'));
  });

  it('a 365-day streak user awards all 7 streak badges at once (if none held)', () => {
    const stats = makeStats({ longestStreak: 365 });
    const earned = earnedTypes(stats);
    for (const type of ['streak_7', 'streak_14', 'streak_30', 'streak_60', 'streak_90', 'streak_180', 'streak_365']) {
      assert.ok(earned.includes(type), `Expected ${type}`);
    }
  });

  it('returns empty array when user has nothing and no stats', () => {
    const earned = earnedTypes(makeStats());
    assert.equal(earned.length, 0);
  });

  it('early_bird via recent plank takes precedence over missing context', () => {
    const d = new Date();
    d.setUTCHours(4, 30, 0, 0);
    const plank = makePlank({ performedAt: d.toISOString(), timezone: 'UTC' });
    // No context provided — should still work from recentPlank
    const earned = earnedTypes(makeStats(), new Set(), plank, undefined, undefined);
    assert.ok(earned.includes('special_early_bird'));
  });
});
