// Optional authoring dependency: npm install --no-save sharp
// Run from the repository root: node dev/branding/build-icons.cjs
// Resize/pad the approved PNG only. Never overwrite or redraw the original.
const fs = require('node:fs/promises');
const sharp = require('sharp');

async function main() {
  await fs.mkdir('pkgdown/assets', { recursive: true });
  const outputs = [
    [16, 'favicon-16x16.png'],
    [32, 'favicon-32x32.png'],
    [96, 'favicon-96x96.png'],
    [180, 'apple-touch-icon.png']
  ];
  for (const [size, filename] of outputs) {
    await sharp('man/figures/logo.png')
      .resize(size, size, { fit: 'contain', background: '#ffffff' })
      .png()
      .toFile(`pkgdown/assets/${filename}`);
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
