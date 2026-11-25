import { KuroCatEngine } from '../src/catEngine';
import { KuroCatEngine3D } from '../src/catEngine3d';
import { HAND_DRAWN_CATS } from '../src/handDrawnCats';

const canvas2D = document.querySelector<HTMLCanvasElement>('#classic')!;
const canvas3D = document.querySelector<HTMLCanvasElement>('#model')!;
const classic = new KuroCatEngine(canvas2D, { embedded: true });
let model: KuroCatEngine3D | undefined;
let engine: KuroCatEngine | KuroCatEngine3D = classic;
let alternateTarget = false;
let practicing = false;
let modelUnavailable = false;
let release: number | undefined;
let lastTarget = 0;

function releasePaw(): void {
  window.clearTimeout(release);
  if (lastTarget) engine.onKeyUp(lastTarget);
  lastTarget = 0;
}

function appearance(id: string, use3D: boolean): void {
  releasePaw();
  engine.clearKeyboardFeedback();
  engine.stop();
  const skin = HAND_DRAWN_CATS.find(cat => cat.id === id) ?? HAND_DRAWN_CATS[0];
  const wantsModel = use3D && !modelUnavailable;
  if (wantsModel && !model) {
    try {
      model = new KuroCatEngine3D(canvas3D, { embedded: true });
    } catch {
      modelUnavailable = true;
    }
  }
  const activeModel = wantsModel ? model : undefined;
  canvas2D.hidden = Boolean(activeModel);
  canvas3D.hidden = !activeModel;
  if (activeModel) activeModel.setCatSkin(skin);
  else classic.setCatAppearance(skin.id, skin);
  engine = activeModel ?? classic;
  engine.setKeyboardConfig('65', 'cat');
  configureKeyboard();
  engine.setFpsCap(30);
  engine.resize();
  engine.start();
}

window.addEventListener('resize', () => {
  if (engine instanceof KuroCatEngine3D) engine.resize();
});

function configureKeyboard(): void {
  engine.showKeyBubbles = practicing;
  engine.setTailKeyConfig(practicing ? 'smart' : 'off', []);
}

function practice(enabled: boolean): void {
  releasePaw();
  engine.clearKeyboardFeedback();
  practicing = enabled;
  configureKeyboard();
}

function key(vk: number, down: boolean, repeating: boolean): void {
  if (!practicing) return;
  if (down) engine.onKeyDown(vk, repeating);
  else engine.onKeyUp(vk);
}

function tap(): void {
  if (practicing) return;
  // Fixed drawing targets alternate regardless of which physical key was pressed.
  releasePaw();
  alternateTarget = !alternateTarget;
  // The two fixed targets sit on opposite sides of the original compact keyboard.
  lastTarget = alternateTarget ? 0x46 : 0x4a;
  engine.onKeyDown(lastTarget, false, false);
  release = window.setTimeout(releasePaw, 80);
}

// Test the drawing itself so the clear area around a sleeping or moving cat stays click-through.
function hit(x: number, y: number): boolean {
  if (x < 0 || y < 0 || x >= 1 || y >= 1) return false;
  if (engine instanceof KuroCatEngine3D) return engine.hitsCat(x, y);
  const ctx = canvas2D.getContext('2d');
  return Boolean(ctx && ctx.getImageData(Math.floor(x * canvas2D.width), Math.floor(y * canvas2D.height), 1, 1).data[3] > 96);
}

interface PointerSample {
  moved: boolean;
  nx: number;
  ny: number;
  rx: number;
  ry: number;
  buttons: number;
  before: number;
  leftClick: boolean;
  rightClick: boolean;
  scrolled: boolean;
}

function pointer(sample: PointerSample): void {
  if (sample.moved) {
    engine.onGlobalMouseMove(sample.nx, sample.ny);
    if (engine === classic) classic.onPointerSpeedSample(sample.nx, sample.ny);
    const overCat = Math.hypot((sample.rx - 0.5) / 0.16, (sample.ry - 0.46) / 0.23) <= 1;
    engine.onWindowCursor(sample.rx, sample.ry, overCat);
  }
  const buttons = ['left', 'right', 'middle'] as const;
  for (const [index, button] of buttons.entries()) {
    const mask = 1 << index;
    const wasDown = Boolean(sample.before & mask);
    const isDown = Boolean(sample.buttons & mask);
    const clicked = (index === 0 && sample.leftClick) || (index === 1 && sample.rightClick);
    if ((!wasDown && isDown) || clicked) engine.onMouseDown(button);
    if ((wasDown || clicked) && !isDown) engine.onMouseUp(button);
  }
  if (sample.scrolled) engine.onMouseWheel();
}

Object.assign(window, { pet: { appearance, practice, key, tap, pointer, hit, skins: HAND_DRAWN_CATS.map(({id, name}) => ({id, name})) } });
