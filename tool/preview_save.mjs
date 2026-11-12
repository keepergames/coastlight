// A keeper part-way through the year, for store screenshots and the video.
const day = (d) => {
  const x = new Date(); x.setDate(x.getDate() - d);
  return `${x.getFullYear()}-${String(x.getMonth() + 1).padStart(2, '0')}-${String(x.getDate()).padStart(2, '0')}`;
};
const lanterns = {};
for (let i = 1; i <= 27; i++) lanterns[i] = i % 5 === 0 ? 2 : 3;
export const midYear = {
  v: 1, lanterns, oil: 412,
  owned: ['beam_amber', 'paint_rust', 'boats_skiff', 'beam_candle', 'paint_tide', 'keep_vane', 'keep_garden', 'keep_bunting'],
  equipped: { beam: 'beam_amber', paint: 'paint_tide', boats: 'boats_skiff' },
  keepsakes: ['keep_vane', 'keep_garden', 'keep_bunting'],
  souls: 684, kept: 31, played: 38, embersLost: 14, convoys: 9, fog: 88, buoys: 0, streak: 31,
  seconds: 3900, longestBest: 74, longestPlays: 5,
  daily: [day(1), day(2), day(3), day(4), day(6), day(7), day(8), day(9), day(12)], dailyBest: 4,
  unlocked: ['first_soul', 'first_night', 'still_water', 'fog_season', 'convoy', 'fog_50', 'streak_20',
    'souls_100', 'daily_1', 'longest_60', 'chandler', 'bright_still'],
  sound: false, music: false, vibration: true, reduceMotion: false, seenDuty: true,
};

