const fs = require('node:fs');
const path = require('node:path');
const { Resvg } = require('@resvg/resvg-js');

const sizes = [16, 20, 24, 32, 48, 64, 128, 256];
const source = fs.readFileSync(path.join(__dirname, 'CameraSquare.svg'), 'utf8');
const images = sizes.map(size => new Resvg(source, {
    fitTo: { mode: 'width', value: size },
    font: { loadSystemFonts: true, defaultFontFamily: 'Arial' }
}).render().asPng());

const directory = Buffer.alloc(6 + sizes.length * 16);
directory.writeUInt16LE(1, 2);
directory.writeUInt16LE(sizes.length, 4);
let imageOffset = directory.length;
for (let index = 0; index < sizes.length; index++) {
    const entry = 6 + index * 16;
    directory[entry] = sizes[index] === 256 ? 0 : sizes[index];
    directory[entry + 1] = directory[entry];
    directory.writeUInt16LE(1, entry + 4);
    directory.writeUInt16LE(32, entry + 6);
    directory.writeUInt32LE(images[index].length, entry + 8);
    directory.writeUInt32LE(imageOffset, entry + 12);
    imageOffset += images[index].length;
}

const icon = Buffer.concat([directory, ...images]);
const iconPath = path.join(__dirname, 'PrintScreen.ico');
if (!fs.existsSync(iconPath) || !fs.readFileSync(iconPath).equals(icon)) {
    fs.writeFileSync(iconPath, icon);
}
