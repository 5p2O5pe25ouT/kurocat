import type { CatSkinConfig } from '../../src/catSkins';
import { HAND_DRAWN_CATS } from '../../src/handDrawnCats';

export const BUILTIN_WEB_CATS: CatSkinConfig[] = [
  ...HAND_DRAWN_CATS,
  {
    id: 'dafeiyu',
    name: '大肥鱼',
    emoji: '🐳',
    builtin: true,
    furColor: '#2957a4',
    furSecondaryColor: '#1d3269',
    outlineColor: '#16203d',
    pattern: 'solid',
    tailColor: '#2957a4',
    tailTipColor: '#5cc8ff',
    eyeColorTop: '#2563eb',
    eyeColorBottom: '#5cc8ff',
    pupilColor: '#101b36',
    eyeCatchlight: true,
    squintColor: '#1e293b',
    blushColor: '#ff6e94',
    armColor: '#232745',
    pawColor: '#fde7df',
    pawOutlineColor: '#3d2c35',
    accentColor: '#5cc8ff',
    accentSideColor: '#2563eb',
    spots: [],
  },
];
