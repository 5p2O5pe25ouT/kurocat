import { resolve } from 'node:path';

const [three, output] = process.argv.slice(2);
const result = await Bun.build({
  entrypoints: ['./offline-macos/renderer.ts'],
  outdir: output,
  naming: 'pet.js',
  format: 'iife',
  target: 'browser',
  minify: true,
  define: { KUROCAT_CATS_ONLY: 'true' },
  loader: { '.png': 'dataurl' },
  plugins: [{
    name: 'locked-three',
    setup(build) {
      build.onResolve({ filter: /^three$/ }, () => ({ path: resolve(three, 'build/three.module.js') }));
    },
  }],
});
if (!result.success) {
  for (const message of result.logs) console.error(message);
  process.exit(1);
}
