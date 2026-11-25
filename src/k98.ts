import type { KeySpec } from './keyboardLayout';

const teal = new Set(['esc', 'space', 'enter', 'np_ent', 'left', 'down', 'up', 'right']);
const charcoal = new Set(('f5 f6 f7 f8 del prt scr home end bs ins pgup pgdn caps tab lshift rshift ' +
  'lctrl lwin lalt ralt rctrl numlk np_div np_mul np_sub np_add').split(' '));
const omit = new Set(['pau', 'm_mute', 'm_vdown', 'm_vup', 'm_calc', 'rwin', 'menu']);
const moved: Record<string, [number, number]> = {
  del: [0,15], prt: [0,16.25], scr: [0,17.25], home: [0,18.25], end: [0,19.25],
  ins: [1,15.1], pgup: [2,15.1], pgdn: [3,15.1], up: [4,14], left: [5,13], down: [5,14],
  right: [5,15], rctrl: [5,11.25],
};
const labels: Record<string,string> = {
  ralt: 'Fn', lshift:'Shift', rshift:'Shift', bs:'Backspace', del:'Delete', scr:'Scroll',
  prt:'Print', caps:'Caps', tab:'Tab', enter:'Enter', np_ent:'Enter', numlk:'Lock',
  pgup:'PgUp', pgdn:'PgDn', np_div:'÷', np_mul:'×',
};

export function k98Keys(full: KeySpec[]): KeySpec[] {
  return full.filter(key => !omit.has(key.id)).map(key => {
    const [row, col] = moved[key.id] ?? [key.row, key.uStart];
    return {
      ...key, row, rowY: row === 0 ? 0 : row + 0.22,
      uStart: key.id.startsWith('np_') || key.id === 'numlk' ? key.uStart - 18.7 + 16.25 : col,
      uWidth: key.id === 'rshift' ? 1.75 : key.uWidth,
      label: labels[key.id] ?? key.label,
      accent: teal.has(key.id) ? 'orange' : charcoal.has(key.id) ? 'mod' : 'normal',
    };
  });
}

export const k98Colors = {
  base: { top: '#eeeDE7', side: '#bbbcb5', legend: '#298c8b' },
  mod: { top: '#626364', side: '#38393a', legend: '#f3f2ed' },
  orange: { top: '#41bcb3', side: '#23877e', legend: '#f4fffa' },
};

// Coordinates follow the top of the shell, with the thumb rest on the left.
export function drawDeskMouse(
  ctx: CanvasRenderingContext2D, x: number, y: number, catFacing: boolean,
  leftPress: number, rightPress: number, scroll: number,
): void {
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate((catFacing ? Math.PI : 0) - 0.16 + (leftPress - rightPress) * 0.055);
  ctx.scale(1, 1 - Math.max(leftPress, rightPress) * 0.06);
  const shell = new Path2D('M -15 -19 C -13 -30 6 -31 14 -19 C 20 -9 25 12 19 23 C 15 32 -10 34 -20 24 Q -27 19 -22 10 Q -15 1 -15 -19 Z');
  const body = ctx.createLinearGradient(-22, -16, 19, 25);
  body.addColorStop(0, '#535457'); body.addColorStop(0.43, '#37383b'); body.addColorStop(1, '#242528');
  ctx.fillStyle = body; ctx.fill(shell);
  ctx.strokeStyle = '#202124'; ctx.lineWidth = 1.4; ctx.stroke(shell);
  ctx.fillStyle = '#45464a';
  ctx.fill(new Path2D('M -16 -8 Q -11 1 -8 13 Q -11 23 -20 23 Q -26 21 -22 13 Z'));
  ctx.strokeStyle = '#202123'; ctx.lineWidth = 1.2;
  ctx.stroke(new Path2D('M -1 -27 Q 2 -17 4 -8 L 1 -5 M -13 -11 Q -3 -1 11 -4 L 14 -9'));
  ctx.fillStyle = '#232427'; ctx.beginPath(); ctx.roundRect(-2.5,-21,7,13,3); ctx.fill();
  const wheel = ctx.createLinearGradient(-2,-15,4,-15);
  wheel.addColorStop(0,'#76777a'); wheel.addColorStop(.4,'#ededeb'); wheel.addColorStop(1,'#818388');
  ctx.fillStyle = wheel; ctx.beginPath(); ctx.roundRect(-1.7,-20.5,5.6,10,2.5); ctx.fill();
  ctx.strokeStyle = scroll > 0.25 ? '#39b4aa' : '#797b7f';
  ctx.lineWidth = 0.65;
  for(let k=-19; k < -11; k+=2) { ctx.beginPath();ctx.moveTo(-1.1,k);ctx.lineTo(3.6,k);ctx.stroke(); }
  ctx.save(); ctx.translate(-12.4,-3);ctx.rotate(.52);
  ctx.fillStyle='#b9bab9';ctx.beginPath();ctx.roundRect(-4.4,-2.2,8.8,4.4,1.6);ctx.fill();
  ctx.strokeStyle='#737478';
  for(let k=-3;k<4;k+=1.7){ctx.beginPath();ctx.moveTo(k,-1.8);ctx.lineTo(k,1.8);ctx.stroke();}
  ctx.restore();
  ctx.restore();
}
