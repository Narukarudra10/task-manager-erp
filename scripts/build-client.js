const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

function copyFolderRecursiveSync(source, target) {
  if (!fs.existsSync(target)) {
    fs.mkdirSync(target, { recursive: true });
  }

  if (fs.lstatSync(source).isDirectory()) {
    const files = fs.readdirSync(source);
    files.forEach((file) => {
      const curSource = path.join(source, file);
      const curTarget = path.join(target, file);
      if (fs.lstatSync(curSource).isDirectory()) {
        copyFolderRecursiveSync(curSource, curTarget);
      } else {
        fs.copyFileSync(curSource, curTarget);
      }
    });
  }
}

// Check if we should skip building the client
const isVercel = process.env.VERCEL === '1' || process.env.VERCEL === 'true' || process.env.NOW_BUILDER === '1';
let hasFlutter = false;
try {
  execSync('flutter --version', { stdio: 'ignore' });
  hasFlutter = true;
} catch (e) {
  hasFlutter = false;
}

const targetDir = path.join(__dirname, '..', 'public');
const hasPrebuiltClient = fs.existsSync(path.join(targetDir, 'index.html')) && fs.existsSync(path.join(targetDir, 'main.dart.js'));

if (isVercel || !hasFlutter) {
  console.log('--- Flutter Environment Status ---');
  console.log(`VERCEL environment detected: ${isVercel}`);
  console.log(`Flutter CLI available: ${hasFlutter}`);
  console.log(`Pre-built client assets found: ${hasPrebuiltClient}`);
  
  if (hasPrebuiltClient) {
    console.log('Skipping Flutter Web Client build and using pre-built client assets in public/.');
    process.exit(0);
  } else {
    console.error('Error: Flutter is not installed/available, and no pre-built client assets were found in public/.');
    console.error('Please build the client locally first with "npm run build:client" and commit the public/ directory files.');
    process.exit(1);
  }
}

try {
  console.log('Building Flutter Web Client...');
  execSync('flutter build web --release', {
    cwd: path.join(__dirname, '..', 'task_manager_app'),
    stdio: 'inherit',
  });
  console.log('Flutter Web Client build complete!');

  const sourceDir = path.join(__dirname, '..', 'task_manager_app', 'build', 'web');

  console.log(`Copying client files from ${sourceDir} to ${targetDir}...`);
  copyFolderRecursiveSync(sourceDir, targetDir);
  console.log('Client files copied successfully!');
} catch (error) {
  console.error('Error building and copying client:', error);
  process.exit(1);
}
